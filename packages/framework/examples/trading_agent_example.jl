using JuliaOS

# Connect to the JuliaOS backend
println("Connecting to JuliaOS backend...")
JuliaOS.Bridge.connect()

if JuliaOS.Bridge.isConnected()
    println("Connected to JuliaOS backend!")
else
    println("Failed to connect to JuliaOS backend. Using local implementation.")
end

# Create a trading agent
println("\nCreating a trading agent...")
trading_config = JuliaOS.TradingAgent.TradingAgentConfig(
    "Example Trading Agent",
    chains=["ethereum", "polygon"],
    risk_level="medium",
    max_position_size=1000.0,
    take_profit=0.05,
    stop_loss=0.03,
    trading_pairs=["ETH/USDC", "MATIC/USDC"],
    strategies=["momentum", "mean_reversion"]
)
agent = JuliaOS.TradingAgent.createTradingAgent(trading_config)
println("Created trading agent: $(agent.name) ($(agent.id))")

# Start the agent
println("\nStarting the agent...")
JuliaOS.Agents.startAgent(agent.id)
println("Agent started!")

# Get agent status
println("\nGetting agent status...")
status = JuliaOS.Agents.getAgentStatus(agent.id)
println("Agent status: $status")

# Execute a trade
println("\nExecuting a trade...")
trade = Dict{String, Any}(
    "pair" => "ETH/USDC",
    "side" => "buy",
    "amount" => 0.1,
    "price" => 2000.0,
    "type" => "limit"
)
result = JuliaOS.TradingAgent.executeTrade(agent, trade)
println("Trade result: $result")

# Get portfolio
println("\nGetting portfolio...")
portfolio = JuliaOS.TradingAgent.getPortfolio(agent)
println("Portfolio: $portfolio")

# Create a swarm
println("\nCreating a swarm...")
swarm_config = JuliaOS.Swarms.SwarmConfig(
    "Example Trading Swarm",
    JuliaOS.Swarms.PSO(particles=30, c1=2.0, c2=2.0, w=0.7),
    "maximize_profit",
    Dict{String, Any}(
        "market" => "crypto",
        "timeframe" => "1h",
        "max_positions" => 5
    )
)
swarm = JuliaOS.Swarms.create_swarm(swarm_config)
println("Created swarm: $(swarm.name) ($(swarm.id))")

# Add agent to swarm
println("\nAdding agent to swarm...")
JuliaOS.Swarms.addAgentToSwarm(swarm.id, agent.id)
println("Agent added to swarm!")

# Start the swarm
println("\nStarting the swarm...")
JuliaOS.Swarms.startSwarm(swarm.id)
println("Swarm started!")

# Get swarm status
println("\nGetting swarm status...")
swarm_status = JuliaOS.Swarms.getSwarmStatus(swarm.id)
println("Swarm status: $swarm_status")

# List available algorithms
println("\nListing available swarm algorithms...")
algorithms = JuliaOS.Swarms.list_algorithms()
if algorithms["success"]
    println("Available algorithms:")
    for algo in algorithms["data"]["algorithms"]
        println("- $(algo["name"]): $(algo["description"])")
    end
else
    println("Failed to list algorithms: $(algorithms["error"])")
end

# Stop the swarm
println("\nStopping the swarm...")
JuliaOS.Swarms.stopSwarm(swarm.id)
println("Swarm stopped!")

# Stop the agent
println("\nStopping the agent...")
JuliaOS.Agents.stopAgent(agent.id)
println("Agent stopped!")

# Disconnect from the backend
println("\nDisconnecting from JuliaOS backend...")
JuliaOS.Bridge.disconnect()
println("Disconnected from JuliaOS backend!")
