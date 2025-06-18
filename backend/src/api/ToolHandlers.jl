module ToolsHandlers

using HTTP

using ..JuliaOSServer
using ..Agents: Agents, Triggers

@registerToolApi function list_tools(req::HTTP.Request;)::Vector{ToolSummary}
    @info "Triggered endpoint: GET /tools"
    tools = Vector{ToolSummary}()
    for (name, tool) in Agents.Tools.TOOL_REGISTRY
        push!(tools, ToolSummary(name, ToolSummaryMetadata(tool.metadata.description)))
    end
    return tools
end

end # module JuliaOSV1Server