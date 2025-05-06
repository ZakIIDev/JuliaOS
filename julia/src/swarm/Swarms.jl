# --- Swarms.jl ---

# Define stubs for Agents module if it's not available
module AgentsStub
    struct Agent end
    getAgent(id) = nothing
    module Swarm
        subscribe_swarm!(agent_id, topic) = @warn "Agents.Swarm unavailable: Cannot subscribe $agent_id to $topic"
        publish_to_swarm(sender_id, topic, msg) = @warn "Agents.Swarm unavailable: Cannot publish to $topic"
        unsubscribe_swarm!(agent_id, topic) = @warn "Agents.Swarm unavailable: Cannot unsubscribe $agent_id from $topic"
    end
end

module Swarms

export Swarm, SwarmConfig, SwarmStatus, create_swarm, getSwarm, listSwarms, startSwarm, stopSwarm,
       getSwarmStatus, addAgentToSwarm, removeAgentFromSwarm, getSharedState, updateSharedState!,
       electLeader, allocateTask, claimTask, completeTask, getSwarmMetrics,
       list_algorithms, Algorithm, SwarmPSO, SwarmGWO, SwarmACO, SwarmGA, SwarmWOA, SwarmDE, SwarmDEPSO,
       MultiObjective, ParetoFront, WeightedSum, EpsilonConstraint, NSGA2Config, # Re-export from MultiObjective
       # Re-export from MultiObjectiveDEPSO
       MultiObjectiveHybridDEPSO,
       # Re-export from ConstrainedDEPSO
       ConstrainedHybridDEPSO, PenaltyMethod, FeasibilityRules, ConstraintHandlingMethod,
       # Re-export from SwarmVisualization
       visualize_convergence, visualize_swarm, visualize_particles, save_visualization,
       # Re-export from SwarmFaultTolerance
       FaultTolerantSwarm, monitor_swarm, recover_swarm, checkpoint_swarm, restore_swarm,
       # Re-export from SwarmCommunication
       MessageSchema, CommunicationPattern, HierarchicalPattern, MeshPattern, RingPattern, BroadcastPattern, send_message, register_handler,
       # Re-export from SwarmSecurity
       SwarmSecurityPolicy, SecureSwarm, authenticate_agent, authorize_action, encrypt_message, decrypt_message,
       # Re-export from SwarmTesting
       test_algorithm, benchmark_algorithm, test_swarm_operations, test_fault_tolerance,
       # Re-export from SwarmPerformance
       profile_algorithm, optimize_algorithm, parallel_swarm, cached_objective, adaptive_swarm,
       # Re-export from SwarmCLIIntegration
       get_swarm_cli_commands, format_swarm_result, visualize_swarm_cli, handle_swarm_command, get_algorithm_options, parse_algorithm_params

using Dates, Random, UUIDs, Logging, Base.Threads
using JSON3

# Try to use the real Agents module, fall back to stubs if not available
try
    using ..Agents
    using ..Agents.Config: get_config # Use the same config module as Agents
    using ..Agents.Metrics: record_metric # Use the same metrics module
    @info "Successfully loaded Agents module"
catch e
    @error "Failed to load Agents module or its submodules. Ensure Agents.jl is accessible." exception=(e,catch_backtrace())
    # Use the stub module
    using .AgentsStub
    # Define dummy config/metrics if needed
    get_config(key, default) = default
    record_metric(args...; kwargs...) = nothing
    @warn "Swarms module will operate with stubbed Agent interactions."
end


# Include base modules
include("SwarmBase.jl")
using .SwarmBase

# Include algorithm modules
include("algorithms/MultiObjective.jl")
using .MultiObjective

# --- Configuration ---
# Uses the Config module loaded via Agents.jl
const SWARM_STORE_PATH = get_config("storage.swarm_path", joinpath(@__DIR__, "..", "..", "db", "swarms_state.json")) # Configurable path
const SWARM_AUTO_PERSIST = get_config("storage.auto_persist", true)
#----------------------

@enum SwarmStatus begin
    CREATED = 1
    RUNNING = 2
    STOPPED = 3
    ERROR = 4
end

"""
    Algorithm

Abstract type for swarm algorithms
"""
abstract type Algorithm end

# --- Algorithm Struct Definitions (Copied from your provided code) ---
struct SwarmPSO <: Algorithm
    particles::Int
    c1::Float64  # Cognitive coefficient
    c2::Float64  # Social coefficient
    w::Float64   # Inertia weight
    SwarmPSO(; particles=30, c1=2.0, c2=2.0, w=0.7) = new(particles, c1, c2, w)
end
struct SwarmGWO <: Algorithm
    wolves::Int
    a_start::Float64  # Control parameter start
    a_end::Float64    # Control parameter end
    SwarmGWO(; wolves=30, a_start=2.0, a_end=0.0) = new(wolves, a_start, a_end)
end
struct SwarmACO <: Algorithm
    ants::Int
    alpha::Float64  # Pheromone importance
    beta::Float64   # Heuristic importance
    rho::Float64    # Evaporation rate
    SwarmACO(; ants=30, alpha=1.0, beta=2.0, rho=0.5) = new(ants, alpha, beta, rho)
end
struct SwarmGA <: Algorithm
    population::Int
    crossover_rate::Float64
    mutation_rate::Float64
    SwarmGA(; population=100, crossover_rate=0.8, mutation_rate=0.1) = new(population, crossover_rate, mutation_rate)
end
struct SwarmWOA <: Algorithm
    whales::Int
    b::Float64  # Spiral shape constant
    SwarmWOA(; whales=30, b=1.0) = new(whales, b)
end
struct SwarmDE <: Algorithm
    population::Int
    F::Float64  # Differential weight
    CR::Float64 # Crossover probability
    SwarmDE(; population=100, F=0.8, CR=0.9) = new(population, F, CR)
end
struct SwarmDEPSO <: Algorithm
    population::Int
    F::Float64       # DE differential weight
    CR::Float64      # DE crossover probability
    w::Float64       # PSO inertia weight
    c1::Float64      # PSO cognitive coefficient
    c2::Float64      # PSO social coefficient
    hybrid_ratio::Float64  # Ratio of DE to PSO (0-1)
    adaptive::Bool   # Whether to use adaptive parameter control
    SwarmDEPSO(; population=50, F=0.8, CR=0.9, w=0.7, c1=1.5, c2=1.5, hybrid_ratio=0.5, adaptive=true) =
        new(population, F, CR, w, c1, c2, hybrid_ratio, adaptive)
end
# --- End Algorithm Struct Definitions ---

"""
    SwarmConfig

Configuration for creating a new swarm. Needs to be mutable if defaults are adjusted.
"""
mutable struct SwarmConfig
    name::String
    algorithm::Algorithm
    objective::String # Description or identifier for the objective function
    parameters::Dict{String, Any} # Other params like max_iterations, target_value etc.
end

"""
    Swarm

Represents a swarm in the JuliaOS system. Mutable to allow status changes etc.
"""
mutable struct Swarm
    id::String
    name::String
    status::SwarmStatus
    created::DateTime
    updated::DateTime
    algorithm::Algorithm
    agent_ids::Vector{String}
    config::SwarmConfig
    # Runtime state (optional, could be managed elsewhere)
    current_iteration::Int
    best_known_solution::Any # Store the best solution found so far
    swarm_task::Union{Task, Nothing} # Handle to the background task running the algorithm
    # Shared state accessible by all agents in the swarm
    shared_state::Dict{String, Any}
    # Task management
    pending_tasks::Dict{String, Dict{String, Any}}
    assigned_tasks::Dict{String, Dict{String, Any}}
    completed_tasks::Dict{String, Dict{String, Any}}
end

# --- Global State & Persistence ---
const SWARMS = Dict{String, Swarm}()
const SWARMS_LOCK = ReentrantLock()

# Persistence functions (similar to Agents.jl)
function _save_swarms_state()
    SWARM_AUTO_PERSIST || return # Only save if enabled
    lock(SWARMS_LOCK) do
        data_to_save = Dict{String, Any}()
        for (id, swarm) in SWARMS
             # Exclude non-serializable fields like the Task
             swarm_dict = Dict(
                 "id" => swarm.id,
                 "name" => swarm.name,
                 "status" => Int(swarm.status),
                 "created" => string(swarm.created),
                 "updated" => string(swarm.updated),
                 # TODO: Need robust serialization for algorithm structs and config
                 # For now, storing type name and converting parameters
                 "algorithm_type" => string(typeof(swarm.algorithm)),
                 "algorithm_params" => Dict(string(f) => getfield(swarm.algorithm, f) for f in fieldnames(typeof(swarm.algorithm))),
                 "agent_ids" => swarm.agent_ids,
                 "config_name" => swarm.config.name,
                 "config_objective" => swarm.config.objective,
                 "config_parameters" => swarm.config.parameters,
                 "current_iteration" => swarm.current_iteration,
                 "best_known_solution" => swarm.best_known_solution, # Hope this is serializable
                 "shared_state" => swarm.shared_state,
                 "pending_tasks" => swarm.pending_tasks,
                 "assigned_tasks" => swarm.assigned_tasks,
                 "completed_tasks" => swarm.completed_tasks
             )
             data_to_save[id] = swarm_dict
        end

        temp_path = SWARM_STORE_PATH * ".tmp"
        try
            store_dir = dirname(SWARM_STORE_PATH)
            ispath(store_dir) || mkpath(store_dir)
            open(temp_path, "w") do io
                JSON3.write(io, data_to_save)
            end
            mv(temp_path, SWARM_STORE_PATH; force=true)
            @debug "Saved swarm state to $SWARM_STORE_PATH"
        catch e
            @error "Failed to save swarm state to $SWARM_STORE_PATH" exception=(e, catch_backtrace())
            isfile(temp_path) && rm(temp_path; force=true)
        end
    end # unlock
end

function _load_swarms_state()
    isfile(SWARM_STORE_PATH) || return 0
    local raw_data
    try
        raw_data = JSON3.read(open(SWARM_STORE_PATH, "r"))
    catch e
        @error "Error reading or parsing swarm state file $SWARM_STORE_PATH: $e" stacktrace=catch_backtrace()
        # TODO: Handle corrupt file (e.g., rename, backup)
        return 0
    end

    loaded_count = 0
    lock(SWARMS_LOCK) do
        empty!(SWARMS) # Clear current state
        for (id, data) in raw_data
            try
                # Reconstruct Algorithm (basic example, needs improvement)
                algo_type_str = data["algorithm_type"]
                algo_params = data["algorithm_params"]
                # TODO: This needs a more robust way to map string back to type and call constructor
                # This is a simplified placeholder
                algo_type = try
                    eval(Meta.parse(algo_type_str))
                catch
                    @warn "Could not parse algorithm type '$algo_type_str' for swarm $id. Skipping algorithm."
                    nothing
                end

                algo_instance = nothing
                if algo_type !== nothing && isconcretetype(algo_type) && algo_type <: Algorithm
                     # Convert param keys back to symbols if needed by constructor, or use keywords
                     kw_params = Pair{Symbol, Any}[Symbol(k) => v for (k, v) in algo_params]
                     try
                         algo_instance = algo_type(; kw_params...)
                     catch cons_err
                         @warn "Could not reconstruct algorithm $algo_type_str for swarm $id" exception=(cons_err,)
                     end
                end
                algo_instance === nothing && (@warn "Using default algorithm for swarm $id"; algo_instance = SwarmPSO()) # Default fallback

                # Reconstruct Config
                config = SwarmConfig(
                    data["config_name"],
                    algo_instance, # Algorithm instance reconstructed above
                    data["config_objective"],
                    data["config_parameters"]
                )

                # Reconstruct Swarm
                swarm = Swarm(
                    data["id"],
                    data["name"],
                    SwarmStatus(get(data, "status", Int(STOPPED))), # Default to STOPPED
                    DateTime(data["created"]),
                    DateTime(data["updated"]),
                    algo_instance, # Use the reconstructed algorithm
                    get(data, "agent_ids", String[]), # Load agent IDs
                    config,
                    get(data, "current_iteration", 0),
                    get(data, "best_known_solution", nothing),
                    nothing, # swarm_task is runtime only, always starts as nothing
                    get(data, "shared_state", Dict{String, Any}()),
                    get(data, "pending_tasks", Dict{String, Dict{String, Any}}()),
                    get(data, "assigned_tasks", Dict{String, Dict{String, Any}}()),
                    get(data, "completed_tasks", Dict{String, Dict{String, Any}}())
                )
                SWARMS[id] = swarm
                loaded_count += 1
            catch e
                @error "Error loading swarm $id from state" exception=(e, catch_backtrace())
            end
        end # end for loop
    end # end lock
    @info "Loaded $loaded_count swarms from $SWARM_STORE_PATH"
    return loaded_count
end

# --- Public API Functions ---

"""
    create_swarm(config::SwarmConfig)
Create a new swarm with the specified configuration.
"""
function create_swarm(config::SwarmConfig)
    swarm_id = "swarm-" * randstring(8) # Generate a random ID
    now_time = now()

    swarm = Swarm(
        swarm_id,
        config.name,
        CREATED,
        now_time,
        now_time,
        config.algorithm,
        String[],  # No agents initially
        config,
        0,         # Initial iteration
        nothing,   # No solution yet
        nothing,   # No task yet
        Dict{String, Any}(),  # Empty shared state
        Dict{String, Dict{String, Any}}(),  # Empty pending tasks
        Dict{String, Dict{String, Any}}(),  # Empty assigned tasks
        Dict{String, Dict{String, Any}}()   # Empty completed tasks
    )

    lock(SWARMS_LOCK) do
        SWARMS[swarm_id] = swarm
    end
    @info "Created swarm $(config.name) ($swarm_id)"
    _save_swarms_state() # Persist immediately
    return Dict("success"=>true, "id"=>swarm_id, "swarm"=>swarm) # Return dict matching expected API format
end

"""
    getSwarm(id::String)
Retrieve a swarm instance by its ID.
"""
function getSwarm(id::String)::Union{Swarm, Nothing}
     lock(SWARMS_LOCK) do
        return get(SWARMS, id, nothing)
    end
end

"""
    listSwarms(; filter_status=nothing, limit=100, offset=0)
List available swarms, optionally filtered by status.
"""
function listSwarms(; filter_status=nothing, limit=100, offset=0)
    all_swarms = lock(SWARMS_LOCK) do
        collect(values(SWARMS))
    end

    # Apply filters
    filtered_swarms = filter(all_swarms) do swarm
        status_match = isnothing(filter_status) || swarm.status == filter_status
        # Add more filters here if needed (e.g., by algorithm type, name contains)
        return status_match
    end

    # Apply pagination
    total = length(filtered_swarms)
    limit = min(max(1, limit), 1000)
    offset = max(0, offset)
    paginated_swarms = if offset < total
        end_idx = min(offset + limit, total)
        filtered_swarms[offset+1:end_idx]
    else
        Swarm[]
    end

    # Format for response
    result_data = Dict(
        "swarms" => paginated_swarms,
        "pagination" => Dict(
            "total" => total,
            "limit" => limit,
            "offset" => offset
        )
    )
    return Dict("success" => true, "data" => result_data)
end

"""
    startSwarm(id::String)
Start a swarm's algorithm execution task.
"""
function startSwarm(id::String)::Dict
    swarm = getSwarm(id)
    if swarm === nothing
        return Dict("success" => false, "error" => "Swarm $id not found")
    end

    if swarm.status == RUNNING && swarm.swarm_task !== nothing && !istaskdone(swarm.swarm_task)
        @warn "Swarm $id is already running."
        return Dict("success" => true, "message" => "Swarm already running", "status" => swarm.status)
    end

    # Set status
    swarm.status = RUNNING
    swarm.updated = now()

    # --- Start the background task for the algorithm ---
    swarm.swarm_task = @task begin
        try
            @info "Starting algorithm task for swarm $(swarm.name) ($id)"
            # TODO: Implement the main loop for the specific swarm.algorithm
            # This involves:
            # 1. Initialization (e.g., particle positions, pheromones)
            # 2. Iteration loop (until max iterations or convergence)
            # 3. Inside loop:
            #    - Request agent actions (e.g., evaluate objective) via publish_to_swarm
            #    - Wait for/collect agent responses (agents might publish to a result topic or A2A)
            #    - Update algorithm state (e.g., move particles, update pheromones)
            #    - Update swarm.best_known_solution
            #    - Update swarm.current_iteration
            #    - Check termination conditions
            #    - Sleep/yield briefly
            @warn "Algorithm execution for $(typeof(swarm.algorithm)) in swarm $id not implemented yet."
            # Example placeholder loop:
            max_iter = get(swarm.config.parameters, "max_iterations", 100)
            for i in 1:max_iter
                 # Check if stopped externally
                 if swarm.status != RUNNING break end
                 swarm.current_iteration = i
                 @debug "Swarm $id iteration $i"
                 # Publish a dummy task request
                 try
                     Agents.Swarm.publish_to_swarm(id, "swarm.$(id).broadcast", Dict("type"=>"dummy_task", "iter"=>i))
                 catch e
                     @warn "Failed to publish dummy task" exception=(e, catch_backtrace())
                 end
                 sleep(2) # Simulate work/waiting
            end

        catch e
            @error "Swarm task for $id crashed!" exception=(e, catch_backtrace())
            swarm.status = ERROR
        finally
            # Ensure status is STOPPED if task finishes normally
            if swarm.status == RUNNING
                swarm.status = STOPPED
            end
            swarm.updated = now()
            @info "Algorithm task for swarm $(swarm.name) ($id) finished with status $(swarm.status)."
            swarm.swarm_task = nothing # Clear task handle
             _save_swarms_state() # Save final state
        end
    end
    schedule(swarm.swarm_task)
    # --------------------------------------------

    @info "Swarm $id started."
    _save_swarms_state()
    return Dict("success" => true, "status" => swarm.status)
end

"""
    stopSwarm(id::String)
Signal a running swarm's algorithm task to stop.
"""
function stopSwarm(id::String)::Dict
    swarm = getSwarm(id)
    if swarm === nothing
        return Dict("success" => false, "error" => "Swarm $id not found")
    end

    if swarm.status == STOPPED || swarm.status == CREATED || swarm.status == ERROR
        @warn "Swarm $id is not running."
        return Dict("success" => true, "message" => "Swarm not running", "status" => swarm.status)
    end

    # Signal the swarm to stop
    swarm.status = STOPPED
    swarm.updated = now()
    @info "Signaled swarm $id to stop."

    # Optional: Wait for the task to finish (can block)
    # if swarm.swarm_task !== nothing && !istaskdone(swarm.swarm_task)
    #     @info "Waiting for swarm $id task to finish..."
    #     try; wait(swarm.swarm_task); catch e; @warn "Error waiting for swarm task $id" exception=e; end
    #     @info "Swarm $id task finished."
    # end

    _save_swarms_state()
    return Dict("success" => true, "status" => swarm.status)
end

"""
    getSwarmStatus(id::String)
Get the current status and basic metrics of a swarm.
"""
function getSwarmStatus(id::String)::Dict
    swarm = getSwarm(id)
    if swarm === nothing
        return Dict("success" => false, "error" => "Swarm $id not found")
    end

    # TODO: Add more dynamic metrics if available from the running task/algorithm state
    status_data = Dict(
        "id" => swarm.id,
        "name" => swarm.name,
        "status" => string(swarm.status),
        "algorithm" => string(typeof(swarm.algorithm)),
        "agent_count" => length(swarm.agent_ids),
        "current_iteration" => swarm.current_iteration,
        "last_updated" => string(swarm.updated)
        # Add best_known_solution if needed (might be large)
    )
    return Dict("success" => true, "data" => status_data)
end

# --- Shared State Management ---

"""
    getSharedState(swarm_id::String, key::String, default=nothing)

Get a value from the swarm's shared state.

# Arguments
- `swarm_id::String`: Swarm ID
- `key::String`: Key to retrieve
- `default`: Default value if key not found

# Returns
- Value associated with key, or default if not found
"""
function getSharedState(swarm_id::String, key::String, default=nothing)
    swarm = getSwarm(swarm_id)
    swarm === nothing && return default
    get(swarm.shared_state, key, default)
end

"""
    updateSharedState!(swarm_id::String, key::String, value)

Update a value in the swarm's shared state.

# Arguments
- `swarm_id::String`: Swarm ID
- `key::String`: Key to update
- `value`: New value

# Returns
- `Bool`: true if successful, false otherwise
"""
function updateSharedState!(swarm_id::String, key::String, value)::Dict
    swarm = getSwarm(swarm_id)
    if swarm === nothing
        return Dict("success" => false, "error" => "Swarm $swarm_id not found")
    end

    # Update the state
    swarm.shared_state[key] = value
    swarm.updated = now()

    # Optionally broadcast state change to agents
    try
        Agents.Swarm.publish_to_swarm(swarm_id, "swarm.$(swarm_id).state_change",
                                    Dict("key" => key, "value" => value))
    catch e
        @warn "Failed to broadcast state change" exception=(e, catch_backtrace())
    end

    _save_swarms_state()
    return Dict("success" => true, "key" => key, "value" => value)
end

# --- Agent Membership Management ---

"""
    addAgentToSwarm(swarm_id::String, agent_id::String)

Add an agent to a swarm.

# Arguments
- `swarm_id::String`: Swarm ID
- `agent_id::String`: Agent ID to add

# Returns
- `Dict`: Result with success status
"""
function addAgentToSwarm(swarm_id::String, agent_id::String)::Dict
    swarm = getSwarm(swarm_id)
    if swarm === nothing
        return Dict("success" => false, "error" => "Swarm $swarm_id not found")
    end

    # Check if agent exists
    agent = nothing
    try
        agent = Agents.getAgent(agent_id)
    catch e
        @warn "Error checking agent existence" exception=(e, catch_backtrace())
    end

    if agent === nothing
        return Dict("success" => false, "error" => "Agent $agent_id not found or not accessible")
    end

    # Check if agent is already in swarm
    if agent_id in swarm.agent_ids
        return Dict("success" => true, "message" => "Agent already in swarm")
    end

    # Add agent to swarm
    push!(swarm.agent_ids, agent_id)
    swarm.updated = now()

    # Subscribe agent to swarm topics
    try
        Agents.Swarm.subscribe_swarm!(agent_id, "swarm.$(swarm_id).broadcast")
        Agents.Swarm.subscribe_swarm!(agent_id, "swarm.$(swarm_id).state_change")
        Agents.Swarm.subscribe_swarm!(agent_id, "swarm.$(swarm_id).task_available")
    catch e
        @warn "Failed to subscribe agent to swarm topics" exception=(e, catch_backtrace())
    end

    # Notify other agents about new member
    try
        Agents.Swarm.publish_to_swarm(swarm_id, "swarm.$(swarm_id).member_joined",
                                    Dict("agent_id" => agent_id))
    catch e
        @warn "Failed to broadcast member joined event" exception=(e, catch_backtrace())
    end

    _save_swarms_state()
    return Dict("success" => true, "message" => "Agent added to swarm")
end

"""
    removeAgentFromSwarm(swarm_id::String, agent_id::String)

Remove an agent from a swarm.

# Arguments
- `swarm_id::String`: Swarm ID
- `agent_id::String`: Agent ID to remove

# Returns
- `Dict`: Result with success status
"""
function removeAgentFromSwarm(swarm_id::String, agent_id::String)::Dict
    swarm = getSwarm(swarm_id)
    if swarm === nothing
        return Dict("success" => false, "error" => "Swarm $swarm_id not found")
    end

    # Check if agent is in swarm
    if !(agent_id in swarm.agent_ids)
        return Dict("success" => true, "message" => "Agent not in swarm")
    end

    # Remove agent from swarm
    filter!(id -> id != agent_id, swarm.agent_ids)
    swarm.updated = now()

    # Unsubscribe agent from swarm topics
    try
        Agents.Swarm.unsubscribe_swarm!(agent_id, "swarm.$(swarm_id).broadcast")
        Agents.Swarm.unsubscribe_swarm!(agent_id, "swarm.$(swarm_id).state_change")
        Agents.Swarm.unsubscribe_swarm!(agent_id, "swarm.$(swarm_id).task_available")
    catch e
        @warn "Failed to unsubscribe agent from swarm topics" exception=(e, catch_backtrace())
    end

    # Notify other agents about member leaving
    try
        Agents.Swarm.publish_to_swarm(swarm_id, "swarm.$(swarm_id).member_left",
                                    Dict("agent_id" => agent_id))
    catch e
        @warn "Failed to broadcast member left event" exception=(e, catch_backtrace())
    end

    # If this was the leader, trigger re-election
    leader_id = getSharedState(swarm_id, "leader_id")
    if leader_id == agent_id
        updateSharedState!(swarm_id, "leader_id", nothing)
        try
            Agents.Swarm.publish_to_swarm(swarm_id, "swarm.$(swarm_id).leader_needed", Dict())
        catch e
            @warn "Failed to broadcast leader needed event" exception=(e, catch_backtrace())
        end
    end

    _save_swarms_state()
    return Dict("success" => true, "message" => "Agent removed from swarm")
end

# --- Coordination Protocols ---

"""
    electLeader(swarm_id::String, criteria::Function=nothing)

Elect a leader for the swarm based on the provided criteria function.
If no criteria function is provided, the first agent is selected as leader.

# Arguments
- `swarm_id::String`: Swarm ID
- `criteria::Function`: Function that takes an agent and returns a score (higher is better)

# Returns
- `Dict`: Result with success status and leader ID
"""
function electLeader(swarm_id::String, criteria::Function=nothing)::Dict
    swarm = getSwarm(swarm_id)
    if swarm === nothing
        return Dict("success" => false, "error" => "Swarm $swarm_id not found")
    end

    if isempty(swarm.agent_ids)
        return Dict("success" => false, "error" => "No agents in swarm")
    end

    # Get all agent details
    agent_details = []
    for agent_id in swarm.agent_ids
        agent = nothing
        try
            agent = Agents.getAgent(agent_id)
        catch e
            @warn "Error getting agent $agent_id" exception=(e, catch_backtrace())
            continue
        end
        agent === nothing && continue
        push!(agent_details, (id=agent_id, agent=agent))
    end

    # Apply criteria function to select leader
    if isempty(agent_details)
        return Dict("success" => false, "error" => "No valid agents found in swarm")
    end

    leader_id = if criteria === nothing
        # Default: select first agent
        agent_details[1].id
    else
        # Apply criteria function
        try
            best_idx = argmax(i -> criteria(agent_details[i].agent), 1:length(agent_details))
            agent_details[best_idx].id
        catch e
            @warn "Error applying leader criteria function" exception=(e, catch_backtrace())
            # Fallback to first agent
            agent_details[1].id
        end
    end

    # Update swarm state and notify agents
    result = updateSharedState!(swarm_id, "leader_id", leader_id)
    if !result["success"]
        return Dict("success" => false, "error" => "Failed to update leader in shared state")
    end

    # Broadcast leader election result
    try
        Agents.Swarm.publish_to_swarm(swarm_id, "swarm.$(swarm_id).leader_elected",
                                    Dict("leader_id" => leader_id))
    catch e
        @warn "Failed to broadcast leader election result" exception=(e, catch_backtrace())
    end

    return Dict("success" => true, "leader_id" => leader_id)
end

# --- Task Allocation ---

"""
    allocateTask(swarm_id::String, task::Dict)

Allocate a task to the swarm.

# Arguments
- `swarm_id::String`: Swarm ID
- `task::Dict`: Task data

# Returns
- `Dict`: Result with success status and task ID
"""
function allocateTask(swarm_id::String, task::Dict)::Dict
    swarm = getSwarm(swarm_id)
    if swarm === nothing
        return Dict("success" => false, "error" => "Swarm $swarm_id not found")
    end

    if isempty(swarm.agent_ids)
        return Dict("success" => false, "error" => "No agents in swarm")
    end

    # Generate a unique task ID
    task_id = string(uuid4())
    task_data = merge(Dict("task_id" => task_id, "created_at" => now()), task)

    # Store task in swarm state
    swarm.pending_tasks[task_id] = task_data
    swarm.updated = now()

    # Publish task to swarm
    try
        Agents.Swarm.publish_to_swarm(swarm_id, "swarm.$(swarm_id).task_available",
                                    Dict("task_id" => task_id, "task" => task_data))
    catch e
        @warn "Failed to broadcast task availability" exception=(e, catch_backtrace())
    end

    _save_swarms_state()
    return Dict("success" => true, "task_id" => task_id)
end

"""
    claimTask(swarm_id::String, task_id::String, agent_id::String)

Claim a task for an agent.

# Arguments
- `swarm_id::String`: Swarm ID
- `task_id::String`: Task ID
- `agent_id::String`: Agent ID

# Returns
- `Dict`: Result with success status and task data
"""
function claimTask(swarm_id::String, task_id::String, agent_id::String)::Dict
    swarm = getSwarm(swarm_id)
    if swarm === nothing
        return Dict("success" => false, "error" => "Swarm $swarm_id not found")
    end

    # Check if agent is in swarm
    if !(agent_id in swarm.agent_ids)
        return Dict("success" => false, "error" => "Agent not in swarm")
    end

    # Check if task exists and is pending
    if !haskey(swarm.pending_tasks, task_id)
        return Dict("success" => false, "error" => "Task not found or already claimed")
    end

    # Claim task
    task = swarm.pending_tasks[task_id]
    delete!(swarm.pending_tasks, task_id)

    # Add to assigned tasks
    task = merge(task, Dict("assigned_to" => agent_id, "assigned_at" => now()))
    swarm.assigned_tasks[task_id] = task
    swarm.updated = now()

    # Notify swarm
    try
        Agents.Swarm.publish_to_swarm(swarm_id, "swarm.$(swarm_id).task_claimed",
                                    Dict("task_id" => task_id, "agent_id" => agent_id))
    catch e
        @warn "Failed to broadcast task claim" exception=(e, catch_backtrace())
    end

    _save_swarms_state()
    return Dict("success" => true, "task" => task)
end

"""
    completeTask(swarm_id::String, task_id::String, agent_id::String, result::Dict)

Mark a task as completed.

# Arguments
- `swarm_id::String`: Swarm ID
- `task_id::String`: Task ID
- `agent_id::String`: Agent ID
- `result::Dict`: Task result data

# Returns
- `Dict`: Result with success status
"""
function completeTask(swarm_id::String, task_id::String, agent_id::String, result::Dict)::Dict
    swarm = getSwarm(swarm_id)
    if swarm === nothing
        return Dict("success" => false, "error" => "Swarm $swarm_id not found")
    end

    # Check if task exists and is assigned to this agent
    if !haskey(swarm.assigned_tasks, task_id)
        return Dict("success" => false, "error" => "Task not found or not assigned")
    end

    task = swarm.assigned_tasks[task_id]
    if get(task, "assigned_to", "") != agent_id
        return Dict("success" => false, "error" => "Task not assigned to this agent")
    end

    # Move task to completed
    delete!(swarm.assigned_tasks, task_id)
    task = merge(task, Dict("completed_at" => now(), "result" => result))
    swarm.completed_tasks[task_id] = task
    swarm.updated = now()

    # Notify swarm
    try
        Agents.Swarm.publish_to_swarm(swarm_id, "swarm.$(swarm_id).task_completed",
                                    Dict("task_id" => task_id, "agent_id" => agent_id, "result" => result))
    catch e
        @warn "Failed to broadcast task completion" exception=(e, catch_backtrace())
    end

    _save_swarms_state()
    return Dict("success" => true, "task" => task)
end

# --- Swarm Monitoring ---

"""
    getSwarmMetrics(swarm_id::String)

Get comprehensive metrics for a swarm.

# Arguments
- `swarm_id::String`: Swarm ID

# Returns
- `Dict`: Metrics data
"""
function getSwarmMetrics(swarm_id::String)::Dict
    swarm = getSwarm(swarm_id)
    if swarm === nothing
        return Dict("success" => false, "error" => "Swarm $swarm_id not found")
    end

    # Collect basic metrics
    metrics = Dict(
        "agent_count" => length(swarm.agent_ids),
        "uptime" => Dates.value(now() - swarm.created) / 1000,  # seconds
        "status" => string(swarm.status),
        "iterations" => swarm.current_iteration,
        "task_stats" => Dict(
            "pending" => length(swarm.pending_tasks),
            "assigned" => length(swarm.assigned_tasks),
            "completed" => length(swarm.completed_tasks)
        )
    )

    # Add algorithm-specific metrics
    if swarm.status == RUNNING
        # These would depend on the specific algorithm implementation
        if isa(swarm.algorithm, SwarmPSO)
            metrics["convergence"] = getSharedState(swarm_id, "convergence", 0.0)
            metrics["global_best_fitness"] = getSharedState(swarm_id, "global_best_fitness", Inf)
        elseif isa(swarm.algorithm, SwarmGA)
            metrics["best_fitness"] = getSharedState(swarm_id, "best_fitness", Inf)
            metrics["population_diversity"] = getSharedState(swarm_id, "diversity", 0.0)
        end
        # Add more algorithm-specific metrics as needed
    end

    # Add agent performance metrics
    active_agents = 0
    for agent_id in swarm.agent_ids
        agent = nothing
        try
            agent = Agents.getAgent(agent_id)
            if agent !== nothing && get(agent, :status, "") == "active"  # Assuming agent has a status field
                active_agents += 1
            end
        catch e
            @warn "Error getting agent status" exception=(e, catch_backtrace())
        end
    end
    metrics["active_agents"] = active_agents

    return Dict("success" => true, "data" => metrics)
end

# --- Include Additional Modules ---
include("visualization.jl")
include("fault_tolerance.jl")
include("communication.jl")
include("security.jl")
include("testing.jl")
include("performance.jl")
include("cli_integration.jl")
include("algorithms/de.jl")
include("algorithms/pso.jl")
include("algorithms/gwo.jl")
include("algorithms/aco.jl")
include("algorithms/ga.jl")
include("algorithms/woa.jl")
include("algorithms/DEPSO.jl")
include("algorithms/MultiObjectiveDEPSO.jl")
include("algorithms/ConstrainedDEPSO.jl")

# Re-export modules
using .SwarmVisualization
using .SwarmFaultTolerance
using .SwarmCommunication
using .SwarmSecurity
using .SwarmTesting
using .SwarmPerformance
using .SwarmCLIIntegration
using .DE
using .PSO
using .GWO
using .ACO
using .GA
using .WOA
using .DEPSO
using .MultiObjectiveDEPSO
using .ConstrainedDEPSO

# --- Algorithm Functions ---

# list_algorithms function
function list_algorithms()
    try
        # Return the list of available algorithms with real implementations
        algorithms = [
            Dict(
                "id" => "pso",
                "name" => "Particle Swarm Optimization",
                "description" => "A computational method that optimizes a problem by iteratively trying to improve a candidate solution with regard to a given measure of quality.",
                "type" => "swarm",
                "parameters" => [
                    Dict("name" => "population_size", "type" => "number", "default" => 30, "description" => "Number of particles"),
                    Dict("name" => "max_iterations", "type" => "number", "default" => 100, "description" => "Maximum number of iterations"),
                    Dict("name" => "c1", "type" => "number", "default" => 2.0, "description" => "Cognitive parameter"),
                    Dict("name" => "c2", "type" => "number", "default" => 2.0, "description" => "Social parameter"),
                    Dict("name" => "w", "type" => "number", "default" => 0.7, "description" => "Inertia weight")
                ]
            ),
            Dict(
                "id" => "de",
                "name" => "Differential Evolution",
                "description" => "A stochastic population-based method that is useful for global optimization problems.",
                "type" => "evolutionary",
                "parameters" => [
                    Dict("name" => "population_size", "type" => "number", "default" => 50, "description" => "Population size"),
                    Dict("name" => "max_iterations", "type" => "number", "default" => 100, "description" => "Maximum number of iterations"),
                    Dict("name" => "crossover_rate", "type" => "number", "default" => 0.7, "description" => "Crossover rate"),
                    Dict("name" => "mutation_factor", "type" => "number", "default" => 0.5, "description" => "Mutation factor")
                ]
            ),
            Dict(
                "id" => "gwo",
                "name" => "Grey Wolf Optimizer",
                "description" => "A meta-heuristic algorithm inspired by the leadership hierarchy and hunting mechanism of grey wolves.",
                "type" => "swarm",
                "parameters" => [
                    Dict("name" => "population_size", "type" => "number", "default" => 30, "description" => "Number of wolves"),
                    Dict("name" => "max_iterations", "type" => "number", "default" => 100, "description" => "Maximum number of iterations")
                ]
            ),
            Dict(
                "id" => "aco",
                "name" => "Ant Colony Optimization",
                "description" => "A probabilistic technique for solving computational problems which can be reduced to finding good paths through graphs.",
                "type" => "swarm",
                "parameters" => [
                    Dict("name" => "population_size", "type" => "number", "default" => 30, "description" => "Number of ants"),
                    Dict("name" => "max_iterations", "type" => "number", "default" => 100, "description" => "Maximum number of iterations"),
                    Dict("name" => "alpha", "type" => "number", "default" => 1.0, "description" => "Pheromone importance"),
                    Dict("name" => "beta", "type" => "number", "default" => 2.0, "description" => "Heuristic importance"),
                    Dict("name" => "evaporation_rate", "type" => "number", "default" => 0.1, "description" => "Pheromone evaporation rate")
                ]
            ),
            Dict(
                "id" => "ga",
                "name" => "Genetic Algorithm",
                "description" => "A search heuristic that is inspired by Charles Darwin's theory of natural evolution.",
                "type" => "evolutionary",
                "parameters" => [
                    Dict("name" => "population_size", "type" => "number", "default" => 50, "description" => "Population size"),
                    Dict("name" => "max_iterations", "type" => "number", "default" => 100, "description" => "Maximum number of iterations"),
                    Dict("name" => "crossover_rate", "type" => "number", "default" => 0.8, "description" => "Crossover rate"),
                    Dict("name" => "mutation_rate", "type" => "number", "default" => 0.1, "description" => "Mutation rate")
                ]
            ),
            Dict(
                "id" => "woa",
                "name" => "Whale Optimization Algorithm",
                "description" => "A nature-inspired meta-heuristic optimization algorithm which mimics the hunting behavior of humpback whales.",
                "type" => "swarm",
                "parameters" => [
                    Dict("name" => "population_size", "type" => "number", "default" => 30, "description" => "Number of whales"),
                    Dict("name" => "max_iterations", "type" => "number", "default" => 100, "description" => "Maximum number of iterations"),
                    Dict("name" => "b", "type" => "number", "default" => 1.0, "description" => "Spiral constant")
                ]
            ),
            Dict(
                "id" => "depso",
                "name" => "Differential Evolution Particle Swarm Optimization",
                "description" => "A hybrid algorithm that combines Differential Evolution and Particle Swarm Optimization.",
                "type" => "hybrid",
                "parameters" => [
                    Dict("name" => "population_size", "type" => "number", "default" => 40, "description" => "Population size"),
                    Dict("name" => "max_iterations", "type" => "number", "default" => 100, "description" => "Maximum number of iterations"),
                    Dict("name" => "c1", "type" => "number", "default" => 1.5, "description" => "Cognitive parameter"),
                    Dict("name" => "c2", "type" => "number", "default" => 1.5, "description" => "Social parameter"),
                    Dict("name" => "w", "type" => "number", "default" => 0.7, "description" => "Inertia weight"),
                    Dict("name" => "crossover_rate", "type" => "number", "default" => 0.7, "description" => "Crossover rate"),
                    Dict("name" => "mutation_factor", "type" => "number", "default" => 0.5, "description" => "Mutation factor")
                ]
            )
        ]
        return Dict("success" => true, "data" => Dict("algorithms" => algorithms))
    catch e
        @error "Error listing algorithms" exception=(e, catch_backtrace())
        return Dict("success" => false, "error" => "Error listing algorithms: $(string(e))")
    end
end


# --- Initialization ---
function __init__()
    # Load existing swarms when the module is first loaded
    _load_swarms_state()

    # Optional: Automatically restart swarms that were previously running?
    # lock(SWARMS_LOCK) do
    #     for (id, swarm) in SWARMS
    #         if swarm.status == RUNNING
    #             @info "Attempting auto-restart of swarm $id"
    #             startSwarm(id) # Be careful about potential infinite loops if start fails
    #         end
    #     end
    # end
end

end # module Swarms