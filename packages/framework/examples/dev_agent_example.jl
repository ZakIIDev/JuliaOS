using JuliaOS

# Connect to the JuliaOS backend
println("Connecting to JuliaOS backend...")
JuliaOS.Bridge.connect()

if JuliaOS.Bridge.isConnected()
    println("Connected to JuliaOS backend!")
else
    println("Failed to connect to JuliaOS backend. Using local implementation.")
end

# Create a development agent
println("\nCreating a development agent...")
dev_config = JuliaOS.DevAgent.DevAgentConfig(
    "Example Dev Agent",
    languages=["python", "javascript", "julia"],
    frameworks=["react", "tensorflow", "flask"],
    specialties=["web", "ai", "blockchain"],
    code_style="clean"
)
agent = JuliaOS.DevAgent.createDevAgent(dev_config)
println("Created development agent: $(agent.name) ($(agent.id))")

# Start the agent
println("\nStarting the agent...")
JuliaOS.Agents.startAgent(agent.id)
println("Agent started!")

# Get agent status
println("\nGetting agent status...")
status = JuliaOS.Agents.getAgentStatus(agent.id)
println("Agent status: $status")

# Write code
println("\nWriting code...")
code_spec = Dict{String, Any}(
    "description" => "Create a simple React component that displays cryptocurrency prices from an API",
    "language" => "javascript",
    "framework" => "react",
    "requirements" => [
        "Fetch data from CoinGecko API",
        "Display prices for BTC, ETH, and SOL",
        "Update prices every 30 seconds",
        "Include error handling"
    ]
)
result = JuliaOS.DevAgent.writeCode(agent, code_spec)
println("Code result: $result")

# Review code
println("\nReviewing code...")
code_to_review = Dict{String, Any}(
    "content" => """
    import React, { useState, useEffect } from 'react';
    import axios from 'axios';

    function CryptoPrices() {
      const [prices, setPrices] = useState({});
      const [loading, setLoading] = useState(true);
      const [error, setError] = useState(null);
      
      useEffect(() => {
        const fetchPrices = async () => {
          try {
            setLoading(true);
            const response = await axios.get(
              'https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum,solana&vs_currencies=usd'
            );
            setPrices(response.data);
            setError(null);
          } catch (err) {
            setError('Failed to fetch prices');
            console.error(err);
          } finally {
            setLoading(false);
          }
        };
        
        fetchPrices();
        const interval = setInterval(fetchPrices, 30000);
        
        return () => clearInterval(interval);
      }, []);
      
      if (loading) return <div>Loading...</div>;
      if (error) return <div>Error: {error}</div>;
      
      return (
        <div className="crypto-prices">
          <h2>Cryptocurrency Prices</h2>
          <ul>
            {prices.bitcoin && <li>Bitcoin: ${prices.bitcoin.usd}</li>}
            {prices.ethereum && <li>Ethereum: ${prices.ethereum.usd}</li>}
            {prices.solana && <li>Solana: ${prices.solana.usd}</li>}
          </ul>
        </div>
      );
    }
    
    export default CryptoPrices;
    """,
    "language" => "javascript",
    "framework" => "react"
)
review_result = JuliaOS.DevAgent.reviewCode(agent, code_to_review)
println("Code review result: $review_result")

# Get code history
println("\nGetting code history...")
history = JuliaOS.DevAgent.getCodeHistory(agent, limit=5)
println("Code history: $history")

# Create a swarm of dev agents
println("\nCreating a development swarm...")
swarm_config = JuliaOS.Swarms.SwarmConfig(
    "Example Dev Swarm",
    JuliaOS.Swarms.GA(population=50, crossover_rate=0.8, mutation_rate=0.1),
    "optimize_code_quality",
    Dict{String, Any}(
        "project_type" => "web_application",
        "optimization_metrics" => ["performance", "maintainability", "security"],
        "collaboration_model" => "parallel"
    )
)
swarm = JuliaOS.Swarms.create_swarm(swarm_config)
println("Created swarm: $(swarm.name) ($(swarm.id))")

# Add agent to swarm
println("\nAdding agent to swarm...")
JuliaOS.Swarms.addAgentToSwarm(swarm.id, agent.id)
println("Agent added to swarm!")

# Create additional dev agents with different specialties
println("\nCreating additional dev agents...")
for (idx, specialty) in enumerate([
    ("frontend", ["javascript", "typescript"], ["react", "vue"]),
    ("backend", ["python", "node"], ["django", "express"]),
    ("blockchain", ["solidity", "rust"], ["web3", "anchor"])
])
    name, langs, frameworks = specialty
    config = JuliaOS.DevAgent.DevAgentConfig(
        "$(name)_specialist",
        languages=langs,
        frameworks=frameworks,
        specialties=[name],
        code_style="optimized"
    )
    specialist = JuliaOS.DevAgent.createDevAgent(config)
    println("Created specialist agent: $(specialist.name) ($(specialist.id))")
    
    # Start the agent
    JuliaOS.Agents.startAgent(specialist.id)
    
    # Add to swarm
    JuliaOS.Swarms.addAgentToSwarm(swarm.id, specialist.id)
    println("Added $(specialist.name) to swarm!")
end

# Start the swarm
println("\nStarting the swarm...")
JuliaOS.Swarms.startSwarm(swarm.id)
println("Swarm started!")

# Get swarm status
println("\nGetting swarm status...")
swarm_status = JuliaOS.Swarms.getSwarmStatus(swarm.id)
println("Swarm status: $swarm_status")

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
