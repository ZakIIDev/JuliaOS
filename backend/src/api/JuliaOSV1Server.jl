# Main entry point and server configuration for the Julia backend application.
using Oxygen
using HTTP
using JSON3
using Reexport

include("RouterManager.jl"); @reexport using .RouterManager: logging_middleware,cors_middleware,auth_middleware
include("server/src/JuliaOSServer.jl");  @reexport using .JuliaOSServer

"""
    start_server(; api_host::String="0.0.0.0", api_port::Int=8000)

Configures and starts the Oxygen HTTP server for the API.
"""
function start_server(; api_host::String="0.0.0.0", api_port::Int=8052)
    # api_host = MainAppConfig.get_value(APP_CONFIG, "api.host", api_host)
    # api_port = MainAppConfig.get_value(APP_CONFIG, "api.port", api_port)
    @info "Initializing API server on $api_host:$api_port..."
    @info "Using API host: $api_host and port: $api_port"

    server_middleware = [
        logging_middleware,
        cors_middleware,
        auth_middleware,
    ]
    try
        JuliaOSServer.serve(; host=api_host, port=api_port, async=false, middleware=server_middleware, serialize=false)
        @info "API server stopped."
    catch e
        @error "API server failed to start or crashed." exception=(e, catch_backtrace())
    end
end


function main()
    @info "Starting Julia Agent Backend System..."

    try
        start_server()
    catch e
        @error "Failed to start the API server or server crashed." exception=(e, catch_backtrace())
    end

    @info "Julia Agent Backend has shut down."
end

# Run the main function if this script is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
else
    @info "Backend modules loaded. Call main() to start the server."
end 