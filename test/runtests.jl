using Test
using Dates
using FXMacroData

struct FakeResponse
    status::Int
    body::Vector{UInt8}
end

mutable struct FakeRequest
    urls::Vector{String}
    headers::Vector{Any}
end

FakeRequest(urls::Vector{String}) = FakeRequest(urls, Any[])

function (request::FakeRequest)(url; headers=Pair{String,String}[], kwargs...)
    push!(request.urls, url)
    push!(request.headers, headers)
    return FakeResponse(200, Vector{UInt8}(codeunits("{\"data\":[{\"date\":\"2025-01-01\",\"val\":1.5}]}")))
end

@testset "FXMacroData client" begin
    request = FakeRequest(String[])
    client = Client(api_key="key with spaces", request=request)

    rows = announcements(
        client,
        "USD",
        "inflation";
        start_date=Date(2025, 1, 1),
        end_date="2025-02-01",
        revisions="all",
    )

    @test rows[1]["val"] == 1.5
    @test occursin("/v1/announcements/usd/inflation?", request.urls[1])
    @test occursin("revisions=all", request.urls[1])

    # The key travels in the header, never the URL: query strings are logged by
    # every proxy, CDN and access log between the caller and the API.
    @test !occursin("api_key", request.urls[1])
    @test ("X-API-Key" => "key with spaces") in request.headers[1]

    health(client)
    @test endswith(request.urls[2], "/v1/health")
    @test !occursin("api_key", request.urls[2])
    @test isempty(request.headers[2])
end

@testset "query auth mode remains available" begin
    request = FakeRequest(String[])
    client = Client(api_key="key with spaces", auth_mode=:query, request=request)

    announcements(client, "USD", "inflation")
    @test occursin("api_key=key%20with%20spaces", request.urls[1])
    @test isempty(request.headers[1])
end

@testset "auth_mode is validated" begin
    @test_throws ArgumentError Client(api_key="k", auth_mode=:bearer)
end

@testset "API errors" begin
    client = Client(
        request=(url; kwargs...) -> FakeResponse(
            401,
            Vector{UInt8}(codeunits("{\"detail\":\"denied\"}")),
        ),
    )
    error = try
        forex(client, "EUR", "USD")
        nothing
    catch caught
        caught
    end
    @test error isa APIError
    @test error.status == 401
end
