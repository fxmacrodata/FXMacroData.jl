using Test
using Dates
using FXMacroData

struct FakeResponse
    status::Int
    body::Vector{UInt8}
end

mutable struct FakeRequest
    urls::Vector{String}
end

function (request::FakeRequest)(url; kwargs...)
    push!(request.urls, url)
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
    @test occursin("api_key=key%20with%20spaces", request.urls[1])
    @test occursin("revisions=all", request.urls[1])

    health(client)
    @test endswith(request.urls[2], "/v1/health")
    @test !occursin("api_key", request.urls[2])
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
