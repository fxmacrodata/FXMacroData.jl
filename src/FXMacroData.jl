module FXMacroData

using Dates
using HTTP
using JSON3

export APIError,
       Client,
       DEFAULT_BASE_URL,
       announcements,
       commodity,
       cot,
       data_catalogue,
       forex,
       get_data,
       get_json,
       health,
       release_calendar,
       resolve_api_key,
       ping

const DEFAULT_BASE_URL = "https://fxmacrodata.com/api"
const DEFAULT_TIMEOUT_SECONDS = 30
const API_KEY_ENV_VARS = ("FXMACRODATA_API_KEY", "FXMD_API_KEY")

"""An unsuccessful FXMacroData HTTP response."""
struct APIError <: Exception
    status::Int
    detail::Any
end

function Base.showerror(io::IO, error::APIError)
    print(io, "FXMacroData API error ", error.status, ": ", error.detail)
end

"""A small REST client with optional query-parameter API-key authentication."""
struct Client
    base_url::String
    api_key::Union{Nothing,String}
    timeout_seconds::Int
    request::Function
end

"""Return an explicit key or the first non-empty supported environment variable."""
function resolve_api_key(api_key::Union{Nothing,AbstractString}=nothing)
    if api_key !== nothing && !isempty(strip(api_key))
        return String(api_key)
    end
    for variable in API_KEY_ENV_VARS
        value = get(ENV, variable, "")
        if !isempty(strip(value))
            return value
        end
    end
    return nothing
end

function Client(
    ;
    api_key::Union{Nothing,AbstractString}=nothing,
    base_url::AbstractString=DEFAULT_BASE_URL,
    timeout_seconds::Integer=DEFAULT_TIMEOUT_SECONDS,
    request::Function=HTTP.get
)
    isempty(strip(base_url)) && throw(ArgumentError("base_url must not be empty"))
    timeout_seconds > 0 || throw(ArgumentError("timeout_seconds must be positive"))
    return Client(
        rstrip(String(base_url), '/'),
        resolve_api_key(api_key),
        Int(timeout_seconds),
        request,
    )
end

function _percent_encode(value)
    io = IOBuffer()
    for byte in codeunits(string(value))
        if (UInt8('A') <= byte <= UInt8('Z')) ||
           (UInt8('a') <= byte <= UInt8('z')) ||
           (UInt8('0') <= byte <= UInt8('9')) ||
           byte in (UInt8('-'), UInt8('.'), UInt8('_'), UInt8('~'))
            write(io, byte)
        else
            print(io, '%', uppercase(string(byte, base=16, pad=2)))
        end
    end
    return String(take!(io))
end

function _url(client::Client, path::AbstractString, params::AbstractDict{String,<:Any})
    normalized_path = startswith(path, "/") ? path : "/" * path
    isempty(params) && return client.base_url * normalized_path
    query = join(
        (_percent_encode(key) * "=" * _percent_encode(value) for (key, value) in params),
        "&",
    )
    return client.base_url * normalized_path * "?" * query
end

function _params(
    client::Client,
    params::AbstractDict{String,<:Any},
    include_api_key::Bool
)
    normalized = Dict{String,Any}(key => value for (key, value) in params if value !== nothing)
    if include_api_key && client.api_key !== nothing
        normalized["api_key"] = client.api_key
    end
    return normalized
end

"""Return the decoded JSON object for an API path."""
function get_json(
    client::Client,
    path::AbstractString;
    params::AbstractDict{String,<:Any}=Dict{String,Any}(),
    include_api_key::Bool=true
)
    url = _url(client, path, _params(client, params, include_api_key))
    response = client.request(
        url;
        status_exception=false,
        retry=false,
        readtimeout=client.timeout_seconds,
    )
    payload = try
        JSON3.read(String(response.body), Dict{String,Any})
    catch
        Dict{String,Any}("detail" => String(response.body))
    end
    response.status >= 400 && throw(APIError(response.status, payload))
    return payload
end

"""Return the top-level `data` array, or an empty vector when it is absent."""
function get_data(client::Client, path::AbstractString; kwargs...)
    payload = get_json(client, path; kwargs...)
    data = get(payload, "data", Any[])
    data isa AbstractVector || throw(ArgumentError("FXMacroData response data must be an array"))
    return data
end

_date_text(value::Date) = Dates.format(value, dateformat"yyyy-mm-dd")
_date_text(value) = string(value)

"""Fetch data-catalogue metadata for one currency."""
function data_catalogue(client::Client, currency::AbstractString; indicator=nothing)
    return get_json(
        client,
        "/v1/data_catalogue/" * lowercase(currency);
        params=Dict("indicator" => indicator),
    )
end

"""Fetch macroeconomic release rows, optionally including all source revisions."""
function announcements(
    client::Client,
    currency::AbstractString,
    indicator::AbstractString;
    start_date=nothing,
    end_date=nothing,
    limit::Integer=100,
    offset::Integer=0,
    revisions::AbstractString="latest"
)
    1 <= limit <= 100 || throw(ArgumentError("limit must be between 1 and 100"))
    offset >= 0 || throw(ArgumentError("offset must be non-negative"))
    return get_data(
        client,
        "/v1/announcements/" * lowercase(currency) * "/" * lowercase(indicator);
        params=Dict(
            "start_date" => start_date === nothing ? nothing : _date_text(start_date),
            "end_date" => end_date === nothing ? nothing : _date_text(end_date),
            "limit" => limit,
            "offset" => offset,
            "revisions" => revisions,
        ),
    )
end

"""Fetch release-calendar events for one currency."""
function release_calendar(
    client::Client,
    currency::AbstractString;
    indicator=nothing,
    start_date=nothing,
    end_date=nothing
)
    return get_data(
        client,
        "/v1/calendar/" * lowercase(currency);
        params=Dict(
            "indicator" => indicator,
            "start_date" => start_date === nothing ? nothing : _date_text(start_date),
            "end_date" => end_date === nothing ? nothing : _date_text(end_date),
        ),
    )
end

"""Fetch daily FX reference-rate history for one currency pair."""
function forex(
    client::Client,
    base::AbstractString,
    quote_currency::AbstractString;
    start_date=nothing,
    end_date=nothing
)
    return get_data(
        client,
        "/v1/forex/" * lowercase(base) * "/" * lowercase(quote_currency);
        params=Dict(
            "start_date" => start_date === nothing ? nothing : _date_text(start_date),
            "end_date" => end_date === nothing ? nothing : _date_text(end_date),
        ),
    )
end

"""Fetch CFTC commitment-of-traders rows for one currency."""
function cot(client::Client, currency::AbstractString; start_date=nothing, end_date=nothing)
    return get_data(
        client,
        "/v1/cot/" * lowercase(currency);
        params=Dict(
            "start_date" => start_date === nothing ? nothing : _date_text(start_date),
            "end_date" => end_date === nothing ? nothing : _date_text(end_date),
        ),
    )
end

"""Fetch a commodity time series."""
function commodity(client::Client, indicator::AbstractString; start_date=nothing, end_date=nothing)
    return get_data(
        client,
        "/v1/commodities/" * lowercase(indicator);
        params=Dict(
            "start_date" => start_date === nothing ? nothing : _date_text(start_date),
            "end_date" => end_date === nothing ? nothing : _date_text(end_date),
        ),
    )
end

"""Read the public API health endpoint without attaching an API key."""
health(client::Client) = get_json(client, "/v1/health"; include_api_key=false)

"""Read the public API ping endpoint without attaching an API key."""
ping(client::Client) = get_json(client, "/v1/ping"; include_api_key=false)

end
