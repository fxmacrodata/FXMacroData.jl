# FXMacroData.jl

`FXMacroData.jl` is a small Julia client for the FXMacroData REST API. It is
intended for research, release-aware backtests, and event-driven systems such
as Fastback.jl; it does not place trades, modify accounts, or bundle any
Fastback source code.

## Status

FXMacroData.jl is distributed directly from GitHub and is not published to the
Julia General registry.

## Install after publication

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

`Client()` reads `FXMACRODATA_API_KEY` and `FXMD_API_KEY` from the environment.
The key is sent only as the API's `api_key` query parameter. USD public data
can be queried without a key within the API's public-history window; protected
currencies and extended history need a key.

## Release-aware research

Macro rows expose `announcement_datetime`, and `announcements(...;
revisions="all")` preserves revision epochs returned by the API. Backtests must
not use a release or revision before its source timestamp.

## Development

```julia
julia --project -e 'using Pkg; Pkg.instantiate(); Pkg.test()'
```

Tests inject a fake HTTP request function and do not make live API calls.
