#!/usr/bin/env julia

# Add the Swarms package to the environment if it's not already there
import Pkg
if !haskey(Pkg.project().dependencies, "Swarms")
    Pkg.develop(path="../")
end

using Swarms
using Dates

println("JuliaOS Swarms Example - Arbitrage Swarm Creation")
println("------------------------------------------------")

# Define the optimization objective
objective = "maximize_profit_across_exchanges"

println("\n1. Creating a PSO swarm for cross-exchange arbitrage")
println("----------------------------------------------------")

# Configure PSO algorithm
pso_algorithm = PSO(
    particles=40,
    c1=1.5,  # Cognitive coefficient (individual learning)
    c2=2.0,  # Social coefficient (swarm learning)
    w=0.8    # Inertia weight
)

# Create arbitrage swarm configuration
config = SwarmConfig(
    "cross_exchange_arbitrage",
    pso_algorithm,
    objective,
    Dict(
        "exchanges" => ["Binance", "Coinbase", "Kraken", "KuCoin"],
        "trading_pairs" => ["BTC/USDT", "ETH/USDT", "SOL/USDT"],
        "min_profit_threshold" => 0.005,  # 0.5%
        "max_position_size" => 1.0,       # BTC/ETH/SOL
        "execution_speed" => "high",
        "risk_level" => "medium",
        "rebalance_interval" => 60,       # seconds
        "use_historical_data" => true
    )
)

# Create the swarm
println("\nCreating arbitrage swarm...")
swarm = create_swarm(config)
println("✓ Created swarm: $(swarm.id) ($(swarm.name))")
println("  Algorithm: $(typeof(swarm.algorithm))")
println("  Objective: $(swarm.config.objective)")
println("  Status: $(swarm.status)")
println("  Created: $(swarm.created)")

# Simulated agent creation (in a real implementation, these would be actual agents)
println("\nCreating and adding arbitrage agents to swarm...")
agent_ids = ["agent_$(rand(1000:9999))" for _ in 1:5]

for agent_id in agent_ids
    success = addAgentToSwarm(swarm.id, agent_id)
    println("✓ Added agent $agent_id to swarm")
end

# Start the swarm
println("\nStarting swarm...")
success = startSwarm(swarm.id)
if success
    println("✓ Swarm started successfully")
else
    println("✗ Failed to start swarm")
end

# Check swarm status
println("\nChecking swarm status...")
status = getSwarmStatus(swarm.id)
println("✓ Swarm status: $(status["status"])")
println("  Agent count: $(status["agent_count"])")
println("  Iterations: $(status["iterations"])")
println("  Convergence: $(status["convergence"])")
println("  Current best objective value: $(status["objective_value"])")

# Simulate the swarm running for a while
println("\nSwarm is running (simulated)...")
println("Agents are searching for arbitrage opportunities across exchanges...")
sleep(3)

# Get updated status
println("\nUpdated swarm status after running:")
status = getSwarmStatus(swarm.id)
println("✓ Swarm status: $(status["status"])")
println("  Agent count: $(status["agent_count"])")
println("  Iterations: $(status["iterations"])")
println("  Convergence: $(status["convergence"])")
println("  Current best objective value: $(status["objective_value"])")

# Stop the swarm
println("\nStopping swarm...")
stopSwarm(swarm.id)
println("✓ Swarm stopped")

println("\n------------------------------------------------")
println("Arbitrage swarm example completed") 