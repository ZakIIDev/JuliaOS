module JuliaOSBackend


include("agents/CommonTypes.jl")
include("resources/Resources.jl")
include("agents/Agents.jl")
include("api/JuliaOSV1Server.jl")

using .Resources
using .CommonTypes
using .Agents
using .JuliaOSV1Server

end