module Tools

export TOOL_REGISTRY

include("tool_example_adder.jl")

using ..CommonTypes: ToolSpecification

const TOOL_REGISTRY = Dict{String, ToolSpecification}()

function register_tool(tool_name::String, tool_spec::ToolSpecification)
    if haskey(TOOL_REGISTRY, tool_name)
        error("Tool with name '$tool_name' is already registered.")
    end
    TOOL_REGISTRY[tool_name] = tool_spec
end

# All tools to be used by agents must be registered here:

register_tool("adder", TOOL_EXAMPLE_ADDER_SPECIFICATION)

end