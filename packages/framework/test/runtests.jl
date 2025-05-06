using Test
using JuliaOS

@testset "JuliaOS Framework Tests" begin
    @testset "Bridge Tests" begin
        # Test bridge connection
        @test_nowarn JuliaOS.Bridge.connect()
        @test JuliaOS.Bridge.isConnected()
    end

    @testset "Agents Tests" begin
        # Test agent creation
        agent_config = JuliaOS.Agents.AgentConfig(
            "Test Agent",
            JuliaOS.Agents.AgentType.TRADING,
            abilities=["trading", "analysis"],
            chains=["ethereum", "polygon"],
            parameters=Dict("key" => "value"),
            llm_config=Dict("provider" => "openai", "model" => "gpt-4"),
            memory_config=Dict("max_size" => 1000)
        )
        agent = JuliaOS.Agents.createAgent(agent_config)
        @test agent.name == "Test Agent"
        @test agent.type == JuliaOS.Agents.AgentType.TRADING
        
        # Test agent retrieval
        retrieved_agent = JuliaOS.Agents.getAgent(agent.id)
        @test retrieved_agent !== nothing
        @test retrieved_agent.id == agent.id
        
        # Test agent listing
        agents = JuliaOS.Agents.listAgents()
        @test length(agents) > 0
        @test any(a -> a.id == agent.id, agents)
    end

    @testset "Swarms Tests" begin
        # Test swarm creation
        swarm_config = JuliaOS.Swarms.SwarmConfig(
            "Test Swarm",
            JuliaOS.Swarms.PSO(particles=30, c1=2.0, c2=2.0, w=0.7),
            "minimize",
            Dict("dimensions" => 10, "bounds" => [(-10.0, 10.0) for _ in 1:10])
        )
        swarm = JuliaOS.Swarms.create_swarm(swarm_config)
        @test swarm.name == "Test Swarm"
        
        # Test swarm listing
        swarms = JuliaOS.Swarms.listSwarms()
        @test isa(swarms, Vector)
        
        # Test algorithm listing
        algorithms = JuliaOS.Swarms.list_algorithms()
        @test isa(algorithms, Dict)
        @test haskey(algorithms, "success")
        @test algorithms["success"] == true
    end

    @testset "Specialized Agent Tests" begin
        # Test TradingAgent
        trading_config = JuliaOS.TradingAgent.TradingAgentConfig(
            "Test Trading Agent",
            chains=["ethereum", "polygon"],
            risk_level="medium",
            max_position_size=1000.0,
            take_profit=0.05,
            stop_loss=0.03,
            trading_pairs=["ETH/USDC", "MATIC/USDC"],
            strategies=["momentum", "mean_reversion"]
        )
        trading_agent = JuliaOS.TradingAgent.createTradingAgent(trading_config)
        @test trading_agent.name == "Test Trading Agent"
        @test trading_agent.type == JuliaOS.Agents.AgentType.TRADING
        
        # Test ResearchAgent
        research_config = JuliaOS.ResearchAgent.ResearchAgentConfig(
            "Test Research Agent",
            research_areas=["market", "technology"],
            data_sources=["web", "api"],
            analysis_methods=["statistical", "nlp"],
            output_formats=["text", "json"]
        )
        research_agent = JuliaOS.ResearchAgent.createResearchAgent(research_config)
        @test research_agent.name == "Test Research Agent"
        @test research_agent.type == JuliaOS.Agents.AgentType.RESEARCH
        
        # Test DevAgent
        dev_config = JuliaOS.DevAgent.DevAgentConfig(
            "Test Dev Agent",
            languages=["python", "javascript", "julia"],
            frameworks=["react", "tensorflow", "flask"],
            specialties=["web", "ai", "blockchain"],
            code_style="clean"
        )
        dev_agent = JuliaOS.DevAgent.createDevAgent(dev_config)
        @test dev_agent.name == "Test Dev Agent"
        @test dev_agent.type == JuliaOS.Agents.AgentType.DEV
    end
end
