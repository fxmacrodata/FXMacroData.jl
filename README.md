# FXMacroData.jl

`FXMacroData.jl` is a small Julia client for the FXMacroData REST API. It is
intended for research, release-aware backtests, and event-driven systems such
as Fastback.jl; it does not place trades, modify accounts, or bundle any
Fastback source code.

## Install

FXMacroData.jl is distributed directly from GitHub and is not published to the
Julia General registry, so install it by URL:

```julia
using Pkg
Pkg.add(url="https://github.com/fxmacrodata/FXMacroData.jl")
```

## Use

```julia
using Dates
using FXMacroData

client = Client()
inflation = announcements(
    client,
    "USD",
    "inflation";
    start_date=Date(2025, 1, 1),
    end_date=Date(2025, 12, 31),
    revisions="all",
)
calendar = release_calendar(client, "USD")
```

## Authentication

`Client()` reads `FXMACRODATA_API_KEY` then `FXMD_API_KEY` from the environment,
or takes an explicit `api_key=`.

The key is sent as an `X-API-Key` request header. That is deliberate: a key in
the query string is recorded by every proxy, CDN and server access log along the
request path, and leaks through `Referer` headers. If something between you and
the API cannot forward the header, opt in explicitly:

```julia
client = Client(auth_mode=:query)
```

USD data can be queried without a key within the API's public-history window;
other currencies and extended history need one.

## Release-aware research

Macro rows expose `announcement_datetime`, and `announcements(...;
revisions="all")` preserves revision epochs returned by the API. Backtests must
not use a release or revision before its source timestamp.

## Development

```julia
julia --project -e 'using Pkg; Pkg.instantiate(); Pkg.test()'
```

Tests inject a fake HTTP request function and do not make live API calls.
