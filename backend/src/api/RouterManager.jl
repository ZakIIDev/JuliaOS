module RouterManager

using HTTP
using JSON3
using OpenAPI
using Reexport
using OpenAPI
using Oxygen

include("../../config/config.jl");@reexport using .Config: load
MainAppConfig = Config
# Load the main application configuration once
const APP_CONFIG = load(joinpath(@__DIR__, "..", "..", "config", "config.toml"))

include("../resources/Resources.jl")
include("../agents/CommonTypes.jl")
include("../agents/Triggers.jl")
include("../agents/Agents.jl")

include("server/src/JuliaOSServer.jl");  @reexport using .JuliaOSServer

include("AgentHandlers.jl")
include("StrategiesHandlers.jl")
include("ToolHandlers.jl")

using .Resources
using .CommonTypes
using .Triggers
using .Agents

using .AgentHandlers
using .StrategiesHandlers

@get "/ping" function ping(req::HTTP.Request)
    @info "Triggered endpoint: GET /ping"
    return "pong"
end


function logging_middleware(handler)
    return function(req::HTTP.Request)
        t = time()
        @info "Request: $(req.method) $(req.target)"
        response = handler(req)
        duration = round((time() - t) * 1000, digits=2)
        @info "Response: $(response.status) ($(duration)ms)"
        return response
    end
end


# API Key Authentication Middleware
function auth_middleware(handler)
    return function(req::HTTP.Request)
        auth_enabled = MainAppConfig.get_value(APP_CONFIG, "security.enable_authentication", true)
        @info "AuthMiddleware: auth_enabled = $auth_enabled"
        
        if !auth_enabled
            return handler(req) # Authentication is disabled, proceed
        end

        api_key_header = HTTP.header(req, "X-API-Key", "")
        
        if isempty(api_key_header)
            @warn "AuthMiddleware: Missing X-API-Key header"
            return HTTP.Response(401, ["Content-Type" => "application/json"], body=JSON3.write(Dict("error" => "Unauthorized: Missing API Key")))
        end

        valid_keys = MainAppConfig.get_value(APP_CONFIG, "security.api_keys", ["default-secret-key-please-change"])
        if !(valid_keys isa AbstractVector)
            @error "AuthMiddleware: 'security.api_keys' in config is not a list. Denying access."
            return HTTP.Response(500, ["Content-Type" => "application/json"], body=JSON3.write(Dict("error" => "Server configuration error")))
        end

        if !(api_key_header in valid_keys)
            @warn "AuthMiddleware: Invalid API Key provided"
            return HTTP.Response(403, ["Content-Type" => "application/json"], body=JSON3.write(Dict("error" => "Forbidden: Invalid API Key")))
        end
        
        return handler(req)
    end
end


allowed_origins = [ "Access-Control-Allow-Origin" => "*" ]

cors_headers = [
    allowed_origins...,
    "Access-Control-Allow-Headers" => "*",
    "Access-Control-Allow-Methods" => "GET, POST"
]

function cors_middleware(handle)
    return function (req::HTTP.Request)
        # return headers on OPTIONS request
        if HTTP.method(req) == "OPTIONS"
            return HTTP.Response(200, cors_headers)
        else
            r = handle(req)
            append!(r.headers, allowed_origins)
            return r
        end
    end
end

end # module RouterManager 