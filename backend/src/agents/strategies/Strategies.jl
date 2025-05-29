module Strategies

export STRATEGY_REGISTRY

include("strategy_example_adder.jl")

using ..CommonTypes: StrategySpecification

const STRATEGY_REGISTRY = Dict{String, StrategySpecification}()

function register_strategy(strategy_name::String, strategy_spec::StrategySpecification)
    if haskey(STRATEGY_REGISTRY, strategy_name)
        error("Strategy with name '$strategy_name' is already registered.")
    end
    STRATEGY_REGISTRY[strategy_name] = strategy_spec
end

# All strategies to be used by agents must be registered here:

register_strategy("adder", STRATEGY_EXAMPLE_ADDER_SPECIFICATION)

end