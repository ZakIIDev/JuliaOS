module StrategiesHandlers

using HTTP

using ..JuliaOSServer
using ..Agents: Agents, Triggers

@registerStrategiesApi function list_strategies(req::HTTP.Request;)::Vector{StrategySummary}
    @info "Triggered endpoint: GET /strategies"
    strategies = Vector{StrategySummary}()
    for (name, spec) in Agents.Strategies.STRATEGY_REGISTRY
        push!(strategies, StrategySummary(name))
    end
    return strategies
end

end # module JuliaOSV1Server