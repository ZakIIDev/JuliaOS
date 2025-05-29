module Agents

include("CommonTypes.jl")
include("tools/Tools.jl")
include("strategies/Strategies.jl")

using .CommonTypes, .Tools, .Strategies

include("utils.jl")
include("agent_management.jl")

export create_agent

end