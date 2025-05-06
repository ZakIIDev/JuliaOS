#!/usr/bin/env julia

# Add the JuliaBridge package to the environment if it's not already there
import Pkg
if !haskey(Pkg.project().dependencies, "JuliaBridge")
    Pkg.develop(path="../")
end

using JuliaBridge
using Dates

println("JuliaOS Bridge Example - Backend Communication")
println("---------------------------------------------")

# Define colors for prettier output
const GREEN = "\e[32m"
const RED = "\e[31m"
const YELLOW = "\e[33m"
const RESET = "\e[0m"
const BLUE = "\e[34m"

function printStatus(message, success)
    status = success ? "$(GREEN)✓$(RESET)" : "$(RED)✗$(RESET)"
    println("$(status) $message")
end

function printSection(title)
    println("\n$(BLUE)$title$(RESET)")
    println(repeat("-", length(title)))
end

# 1. Connect to the backend
printSection("1. Connecting to JuliaOS Backend")

# Default configuration (localhost:8052)
println("Connecting with default configuration...")
connected = connect()
printStatus("Connection to JuliaOS backend", connected)

if !connected
    # Try custom configuration if default fails
    printSection("Trying custom configuration...")
    config = BridgeConfig(
        host = "localhost", 
        port = 8052,
        timeout = 5  # shorter timeout for example
    )
    
    connected = connect(config)
    printStatus("Connection with custom config", connected)
end

# If still not connected, exit
if !connected
    println("\n$(RED)Could not connect to JuliaOS backend.$(RESET)")
    println("Please ensure the backend server is running with:")
    println("  cd julia && ./start.sh")
    exit(1)
end

# 2. Health Check
printSection("2. Performing Health Check")

health = healthCheck()
printStatus("Health check", health.success)

if health.success
    println("  Server status: $(health.data.status)")
    println("  Server version: $(health.data.version)")
    println("  Timestamp: $(health.data.timestamp)")
else
    println("  Error: $(health.error)")
end

# 3. Execute an Agent System Function
printSection("3. Executing AgentSystem.createAgent")

# Create parameters for an agent
agent_params = Dict(
    "name" => "monitoring_agent",
    "type" => "Monitor",
    "config" => Dict(
        "chains" => ["Ethereum", "Polygon"],
        "refresh_interval" => 60,
        "alert_threshold" => 0.05
    )
)

# Execute the function
println("Creating a monitoring agent...")
agent_response = execute("AgentSystem.createAgent", agent_params)
printStatus("Agent creation", agent_response.success)

if agent_response.success
    println("  Agent ID: $(agent_response.data.id)")
    println("  Agent Name: $(agent_response.data.name)")
    println("  Agent Status: $(agent_response.data.status)")
else
    println("  Error: $(agent_response.error)")
end

# 4. Execute a Swarm System Function
printSection("4. Executing SwarmManager.create_swarm")

# Create parameters for a swarm
swarm_params = Dict(
    "name" => "trading_swarm",
    "algorithm" => "PSO",
    "config" => Dict(
        "particles" => 30,
        "iterations" => 100,
        "objective" => "maximize_profit"
    ),
    "agent_ids" => ["agent_1", "agent_2"]  # These would be actual agent IDs in real use
)

# Execute the function
println("Creating a trading swarm...")
swarm_response = execute("SwarmManager.create_swarm", swarm_params)
printStatus("Swarm creation", swarm_response.success)

if swarm_response.success
    println("  Swarm ID: $(swarm_response.data.id)")
    println("  Swarm Name: $(swarm_response.data.name)")
    println("  Algorithm: $(swarm_response.data.algorithm)")
else
    println("  Error: $(swarm_response.error)")
end

# 5. Error Handling Example
printSection("5. Error Handling Example")

println("Executing non-existent function...")
error_response = execute("NonExistentModule.nonExistentFunction", Dict())
printStatus("Non-existent function call", !error_response.success) # We expect this to fail

if !error_response.success
    println("  Error properly handled: $(error_response.error)")
else
    println("  $(YELLOW)Warning: Expected an error but got success$(RESET)")
end

# 6. Disconnection
printSection("6. Disconnecting from Backend")

println("Disconnecting from JuliaOS backend...")
disconnected = disconnect()
printStatus("Disconnection", disconnected)

println("\n$(GREEN)JuliaOS Bridge Example Completed$(RESET)")
println("---------------------------------------------") 