# Example implementation of a strategy. The STRATEGY_EXAMPLE_ADDER_SPECIFICATION struct encapsulates the implementation and is the part added to the registry in Strategy.jl.

using ..CommonTypes: StrategyConfig, AgentContext, StrategySpecification

Base.@kwdef struct StrategyExampleAdderConfig <: StrategyConfig
    times_to_add::Int
end

function strategy_example_adder(cfg::StrategyExampleAdderConfig, ctx::AgentContext, input::Any) # TODO: input needs to be more generic
    if !isa(input, Int)
        push!(ctx.logs, "ERROR: Input must be an integer.")
        return
    end

    value = input

    adder_tool_index = findfirst(tool -> tool.metadata.name == "adder", ctx.tools)
    if adder_tool_index === nothing
        push!(ctx.logs, "ERROR: Adder tool not found in context tools.")
        return
    end
    adder_tool = ctx.tools[adder_tool_index]

    for _ in 1:cfg.times_to_add
        value = adder_tool.execute(adder_tool.config, value)
        push!(ctx.logs, "Adder tool result: $value")
    end
    return ctx
end

const STRATEGY_EXAMPLE_ADDER_SPECIFICATION = StrategySpecification(
    strategy_example_adder,
    StrategyExampleAdderConfig
)