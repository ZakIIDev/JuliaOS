using .CommonTypes: Agent, AgentBlueprint, AgentContext, AgentState, InstantiatedTool, InstantiatedStrategy, CommonTypes

const AGENTS = Dict{String, Agent}()

function create_agent(
    id::String,
    blueprint::AgentBlueprint,
)::Agent
    # Check if the agent with the given ID already exists
    if haskey(AGENTS, id)
        error("Agent with ID '$id' already exists.")
    end

    # Instantiate tools from the blueprint
    tools = Vector{InstantiatedTool}()
    for tool_blueprint in blueprint.tools
        tool = instantiate_tool(tool_blueprint)
        push!(tools, tool)
    end

    # Create the agent context
    context = AgentContext(
        tools,
        Vector{String}()
    )

    # Create the instantiated strategy
    strategy = instantiate_strategy(blueprint.strategy)

    # Create the agent
    agent = Agent(
        id,
        context,
        strategy,
        blueprint.trigger,
        CommonTypes.CREATED_STATE
    )

    AGENTS[id] = agent

    return agent
end

function delete_agent(
    id::String,
)::Nothing
    # Check if the agent with the given ID exists
    if !haskey(AGENTS, id)
        error("Agent with ID '$id' does not exist.")
    end

    # Remove the agent from the registry
    delete!(AGENTS, id)

    return nothing
end

function set_agent_state(
    agent::Agent,
    new_state::AgentState,
)
    # TODO: actually make sure the transition is valid and realized fully
    agent.state = new_state

    return nothing
end

function run(
    agent::Agent,
    input::Any=nothing,
)
    if agent.state != CommonTypes.RUNNING_STATE
        error("Agent with ID '$(agent.id)' is not in RUNNING state.")
    end

    @info "Executing strategy of agent $(agent.id)"
    return agent.strategy.run(agent.strategy.config, agent.context, input)
end