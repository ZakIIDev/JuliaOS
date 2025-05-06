using JuliaOS

# Connect to the JuliaOS backend
println("Connecting to JuliaOS backend...")
JuliaOS.Bridge.connect()

if JuliaOS.Bridge.isConnected()
    println("Connected to JuliaOS backend!")
else
    println("Failed to connect to JuliaOS backend. Using local implementation.")
end

# Create a research agent
println("\nCreating a research agent...")
research_config = JuliaOS.ResearchAgent.ResearchAgentConfig(
    "Example Research Agent",
    research_areas=["market", "technology", "sentiment"],
    data_sources=["web", "api", "database"],
    analysis_methods=["statistical", "nlp", "trend"],
    output_formats=["text", "json", "chart"]
)
agent = JuliaOS.ResearchAgent.createResearchAgent(research_config)
println("Created research agent: $(agent.name) ($(agent.id))")

# Start the agent
println("\nStarting the agent...")
JuliaOS.Agents.startAgent(agent.id)
println("Agent started!")

# Get agent status
println("\nGetting agent status...")
status = JuliaOS.Agents.getAgentStatus(agent.id)
println("Agent status: $status")

# Conduct research
println("\nConducting research...")
research = Dict{String, Any}(
    "topic" => "Ethereum Layer 2 Solutions",
    "depth" => "medium",
    "focus" => ["technology", "adoption", "performance"],
    "timeframe" => "last_6_months",
    "sources" => ["academic", "news", "social_media"]
)
result = JuliaOS.ResearchAgent.conductResearch(agent, research)
println("Research result: $result")

# Get research history
println("\nGetting research history...")
history = JuliaOS.ResearchAgent.getResearchHistory(agent, limit=5)
println("Research history: $history")

# Create a swarm of research agents
println("\nCreating a research swarm...")
swarm_config = JuliaOS.Swarms.SwarmConfig(
    "Example Research Swarm",
    JuliaOS.Swarms.ACO(ants=20, alpha=1.0, beta=2.0, rho=0.5),
    "maximize_information_gain",
    Dict{String, Any}(
        "research_domain" => "blockchain",
        "collaboration_method" => "consensus",
        "diversity_factor" => 0.7
    )
)
swarm = JuliaOS.Swarms.create_swarm(swarm_config)
println("Created swarm: $(swarm.name) ($(swarm.id))")

# Add agent to swarm
println("\nAdding agent to swarm...")
JuliaOS.Swarms.addAgentToSwarm(swarm.id, agent.id)
println("Agent added to swarm!")

# Create additional research agents with different specialties
println("\nCreating additional research agents...")
for (idx, area) in enumerate(["defi", "nft", "governance"])
    config = JuliaOS.ResearchAgent.ResearchAgentConfig(
        "$(area)_specialist",
        research_areas=[area, "market"],
        data_sources=["web", "api"],
        analysis_methods=["statistical", "nlp"],
        output_formats=["text", "json"]
    )
    specialist = JuliaOS.ResearchAgent.createResearchAgent(config)
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
