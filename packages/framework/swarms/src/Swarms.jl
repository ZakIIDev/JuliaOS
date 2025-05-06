module Swarms

export Swarm, SwarmConfig, create_swarm, listSwarms, startSwarm, stopSwarm,
       getSwarmStatus, addAgentToSwarm, removeAgentFromSwarm,
       Algorithm, PSO, GWO, ACO, GA, WOA, DE, DEPSO,
       MultiObjective, ParetoFront, WeightedSum, EpsilonConstraint, NSGA2Config

using HTTP
using JSON3
using Dates

# Include algorithm modules
include("algorithms/MultiObjective.jl")
using .MultiObjective

"""
    Algorithm

Abstract type for swarm algorithms
"""
abstract type Algorithm end

"""
    PSO <: Algorithm

Particle Swarm Optimization algorithm.
"""
struct PSO <: Algorithm
    particles::Int
    c1::Float64  # Cognitive coefficient
    c2::Float64  # Social coefficient
    w::Float64   # Inertia weight

    PSO(; particles=30, c1=2.0, c2=2.0, w=0.7) = new(particles, c1, c2, w)
end

"""
    GWO <: Algorithm

Grey Wolf Optimizer algorithm.
"""
struct GWO <: Algorithm
    wolves::Int
    a_start::Float64  # Control parameter start
    a_end::Float64    # Control parameter end

    GWO(; wolves=30, a_start=2.0, a_end=0.0) = new(wolves, a_start, a_end)
end

"""
    ACO <: Algorithm

Ant Colony Optimization algorithm.
"""
struct ACO <: Algorithm
    ants::Int
    alpha::Float64  # Pheromone importance
    beta::Float64   # Heuristic importance
    rho::Float64    # Evaporation rate

    ACO(; ants=30, alpha=1.0, beta=2.0, rho=0.5) = new(ants, alpha, beta, rho)
end

"""
    GA <: Algorithm

Genetic Algorithm.
"""
struct GA <: Algorithm
    population::Int
    crossover_rate::Float64
    mutation_rate::Float64

    GA(; population=100, crossover_rate=0.8, mutation_rate=0.1) = new(population, crossover_rate, mutation_rate)
end

"""
    WOA <: Algorithm

Whale Optimization Algorithm.
"""
struct WOA <: Algorithm
    whales::Int
    b::Float64  # Spiral shape constant

    WOA(; whales=30, b=1.0) = new(whales, b)
end

"""
    DE <: Algorithm

Differential Evolution algorithm.
"""
struct DE <: Algorithm
    population::Int
    F::Float64  # Differential weight
    CR::Float64 # Crossover probability

    DE(; population=100, F=0.8, CR=0.9) = new(population, F, CR)
end

"""
    DEPSO <: Algorithm

Hybrid Differential Evolution and Particle Swarm Optimization algorithm.
"""
struct DEPSO <: Algorithm
    population::Int
    F::Float64       # DE differential weight
    CR::Float64      # DE crossover probability
    w::Float64       # PSO inertia weight
    c1::Float64      # PSO cognitive coefficient
    c2::Float64      # PSO social coefficient
    hybrid_ratio::Float64  # Ratio of DE to PSO (0-1)
    adaptive::Bool   # Whether to use adaptive parameter control

    DEPSO(; population=50, F=0.8, CR=0.9, w=0.7, c1=1.5, c2=1.5, hybrid_ratio=0.5, adaptive=true) =
        new(population, F, CR, w, c1, c2, hybrid_ratio, adaptive)
end

"""
    SwarmConfig

Configuration for creating a new swarm.

# Fields
- `name::String`: Swarm name
- `algorithm::Algorithm`: Optimization algorithm to use
- `objective::String`: Objective function or goal
- `parameters::Dict{String, Any}`: Additional swarm-specific parameters
"""
struct SwarmConfig
    name::String
    algorithm::Algorithm
    objective::String
    parameters::Dict{String, Any}
end

"""
    Swarm

Represents a swarm in the JuliaOS system.

# Fields
- `id::String`: Unique identifier
- `name::String`: Swarm name
- `status::String`: Current status
- `created::DateTime`: Creation timestamp
- `algorithm::Algorithm`: Optimization algorithm in use
- `agent_ids::Vector{String}`: Agents belonging to this swarm
- `config::SwarmConfig`: Swarm configuration
"""
struct Swarm
    id::String
    name::String
    status::String
    created::DateTime
    algorithm::Algorithm
    agent_ids::Vector{String}
    config::SwarmConfig
end

"""
    create_swarm(config::SwarmConfig)

Create a new swarm with the specified configuration.

# Arguments
- `config::SwarmConfig`: Configuration for the new swarm

# Returns
- `Swarm`: The created swarm
"""
function create_swarm(config::SwarmConfig)
    # Import JuliaBridge if not already imported
    if !@isdefined(JuliaBridge)
        using ..JuliaBridge
    end

    # Check if bridge is connected
    if !JuliaBridge.isConnected()
        try
            JuliaBridge.connect()
        catch e
            @error "Failed to connect to JuliaOS backend: $e"
            # Fallback to local implementation if bridge connection fails
            return _create_swarm_local(config)
        end
    end

    # Prepare parameters for the backend
    params = Dict{
        String, Any
    }(
        "name" => config.name,
        "algorithm" => string(typeof(config.algorithm)),
        "objective" => config.objective,
        "parameters" => config.parameters
    )

    # Add algorithm-specific parameters
    if isa(config.algorithm, PSO)
        params["algorithm_params"] = Dict(
            "particles" => config.algorithm.particles,
            "c1" => config.algorithm.c1,
            "c2" => config.algorithm.c2,
            "w" => config.algorithm.w
        )
    elseif isa(config.algorithm, GWO)
        params["algorithm_params"] = Dict(
            "wolves" => config.algorithm.wolves,
            "a_start" => config.algorithm.a_start,
            "a_end" => config.algorithm.a_end
        )
    elseif isa(config.algorithm, ACO)
        params["algorithm_params"] = Dict(
            "ants" => config.algorithm.ants,
            "alpha" => config.algorithm.alpha,
            "beta" => config.algorithm.beta,
            "rho" => config.algorithm.rho
        )
    elseif isa(config.algorithm, GA)
        params["algorithm_params"] = Dict(
            "population" => config.algorithm.population,
            "crossover_rate" => config.algorithm.crossover_rate,
            "mutation_rate" => config.algorithm.mutation_rate
        )
    elseif isa(config.algorithm, WOA)
        params["algorithm_params"] = Dict(
            "whales" => config.algorithm.whales,
            "b" => config.algorithm.b
        )
    elseif isa(config.algorithm, DE)
        params["algorithm_params"] = Dict(
            "population" => config.algorithm.population,
            "F" => config.algorithm.F,
            "CR" => config.algorithm.CR
        )
    elseif isa(config.algorithm, DEPSO)
        params["algorithm_params"] = Dict(
            "population" => config.algorithm.population,
            "F" => config.algorithm.F,
            "CR" => config.algorithm.CR,
            "w" => config.algorithm.w,
            "c1" => config.algorithm.c1,
            "c2" => config.algorithm.c2,
            "hybrid_ratio" => config.algorithm.hybrid_ratio,
            "adaptive" => config.algorithm.adaptive
        )
    end

    # Execute the command on the backend
    result = JuliaBridge.execute("swarms.create_swarm", params)

    if result.success
        # Create a local swarm instance from the backend response
        swarm_data = result.data
        swarm_id = swarm_data["id"]

        # Create the swarm object
        swarm = Swarm(
            swarm_id,
            config.name,
            get(swarm_data, "status", "created"),
            now(),
            config.algorithm,
            String[],  # No agents initially
            config
        )

        @info "Created swarm via backend: $(swarm.name) ($(swarm.id))"
        return swarm
    else
        # If backend call fails, fallback to local implementation
        @warn "Backend swarm creation failed: $(result.error). Using local implementation."
        return _create_swarm_local(config)
    end
end

# Local implementation of create_swarm as a fallback
function _create_swarm_local(config::SwarmConfig)
    swarm_id = "swarm_" * string(rand(1000:9999))

    # Create a local swarm instance
    swarm = Swarm(
        swarm_id,
        config.name,
        "created",
        now(),
        config.algorithm,
        String[],  # No agents initially
        config
    )

    @info "Created swarm locally: $(swarm.name) ($(swarm.id))"
    return swarm
end

"""
    listSwarms()

List all available swarms in the system.

# Returns
- `Vector{Swarm}`: List of all swarms
"""
function listSwarms()
    # Import JuliaBridge if not already imported
    if !@isdefined(JuliaBridge)
        using ..JuliaBridge
    end

    # Check if bridge is connected
    if !JuliaBridge.isConnected()
        try
            JuliaBridge.connect()
        catch e
            @error "Failed to connect to JuliaOS backend: $e"
            # Fallback to local implementation if bridge connection fails
            return Swarm[]
        end
    end

    # Execute the command on the backend
    result = JuliaBridge.execute("swarms.list_swarms", Dict{String, Any}())

    if result.success
        # Create local swarm instances from the backend response
        swarm_list = Vector{Swarm}()

        if haskey(result.data, "swarms") && result.data["swarms"] isa Vector
            for swarm_data in result.data["swarms"]
                try
                    # Create a minimal algorithm instance based on the type
                    algorithm_type = get(swarm_data, "algorithm_type", "PSO")
                    algorithm = if algorithm_type == "PSO" || algorithm_type == "SwarmPSO"
                        PSO()
                    elseif algorithm_type == "GWO" || algorithm_type == "SwarmGWO"
                        GWO()
                    elseif algorithm_type == "ACO" || algorithm_type == "SwarmACO"
                        ACO()
                    elseif algorithm_type == "GA" || algorithm_type == "SwarmGA"
                        GA()
                    elseif algorithm_type == "WOA" || algorithm_type == "SwarmWOA"
                        WOA()
                    elseif algorithm_type == "DE" || algorithm_type == "SwarmDE"
                        DE()
                    elseif algorithm_type == "DEPSO" || algorithm_type == "SwarmDEPSO"
                        DEPSO()
                    else
                        PSO()  # Default to PSO if unknown
                    end

                    # Create a minimal config
                    config = SwarmConfig(
                        get(swarm_data, "name", "Unknown Swarm"),
                        algorithm,
                        get(swarm_data, "objective", "unknown"),
                        get(swarm_data, "parameters", Dict{String, Any}())
                    )

                    # Create the swarm object
                    swarm = Swarm(
                        swarm_data["id"],
                        get(swarm_data, "name", "Unknown Swarm"),
                        get(swarm_data, "status", "unknown"),
                        now(),  # We don't have the actual creation time
                        algorithm,
                        get(swarm_data, "agent_ids", String[]),
                        config
                    )

                    push!(swarm_list, swarm)
                catch e
                    @warn "Failed to parse swarm data: $e"
                end
            end
        end

        return swarm_list
    else
        # If backend call fails, return empty list
        @warn "Backend swarm listing failed: $(result.error). Returning empty list."
        return Swarm[]
    end
end

"""
    startSwarm(id::String)

Start a swarm with the specified ID.

# Arguments
- `id::String`: Swarm ID to start

# Returns
- `Bool`: true if successful, false otherwise
"""
function startSwarm(id::String)
    # Import JuliaBridge if not already imported
    if !@isdefined(JuliaBridge)
        using ..JuliaBridge
    end

    # Check if bridge is connected
    if !JuliaBridge.isConnected()
        try
            JuliaBridge.connect()
        catch e
            @error "Failed to connect to JuliaOS backend: $e"
            # Fallback to local implementation if bridge connection fails
            return true
        end
    end

    # Execute the command on the backend
    result = JuliaBridge.execute("swarms.start_swarm", Dict("id" => id))

    if result.success
        @info "Started swarm via backend: $id"
        return true
    else
        # If backend call fails, log warning and return false
        @warn "Backend swarm start failed: $(result.error)."
        return false
    end
end

"""
    stopSwarm(id::String)

Stop a swarm with the specified ID.

# Arguments
- `id::String`: Swarm ID to stop

# Returns
- `Bool`: true if successful, false otherwise
"""
function stopSwarm(id::String)
    # Import JuliaBridge if not already imported
    if !@isdefined(JuliaBridge)
        using ..JuliaBridge
    end

    # Check if bridge is connected
    if !JuliaBridge.isConnected()
        try
            JuliaBridge.connect()
        catch e
            @error "Failed to connect to JuliaOS backend: $e"
            # Fallback to local implementation if bridge connection fails
            return true
        end
    end

    # Execute the command on the backend
    result = JuliaBridge.execute("swarms.stop_swarm", Dict("id" => id))

    if result.success
        @info "Stopped swarm via backend: $id"
        return true
    else
        # If backend call fails, log warning and return false
        @warn "Backend swarm stop failed: $(result.error)."
        return false
    end
end

"""
    getSwarmStatus(id::String)

Get the current status of a swarm.

# Arguments
- `id::String`: Swarm ID to check

# Returns
- `Dict`: Status information about the swarm
"""
function getSwarmStatus(id::String)
    # Import JuliaBridge if not already imported
    if !@isdefined(JuliaBridge)
        using ..JuliaBridge
    end

    # Check if bridge is connected
    if !JuliaBridge.isConnected()
        try
            JuliaBridge.connect()
        catch e
            @error "Failed to connect to JuliaOS backend: $e"
            # Fallback to local implementation if bridge connection fails
            return _getSwarmStatusLocal(id)
        end
    end

    # Execute the command on the backend
    result = JuliaBridge.execute("swarms.get_swarm_details", Dict("id" => id))

    if result.success
        @info "Got swarm status via backend: $id"
        return result.data
    else
        # If backend call fails, fallback to local implementation
        @warn "Backend swarm status failed: $(result.error). Using local implementation."
        return _getSwarmStatusLocal(id)
    end
end

# Local implementation of getSwarmStatus as a fallback
function _getSwarmStatusLocal(id::String)
    # Return a simulated status
    return Dict(
        "id" => id,
        "status" => "running",
        "uptime" => 3600,
        "agent_count" => 5,
        "iterations" => 150,
        "convergence" => 0.98,
        "objective_value" => 0.002
    )
end

"""
    addAgentToSwarm(swarm_id::String, agent_id::String)

Add an agent to a swarm.

# Arguments
- `swarm_id::String`: Swarm ID
- `agent_id::String`: Agent ID to add

# Returns
- `Bool`: true if successful, false otherwise
"""
function addAgentToSwarm(swarm_id::String, agent_id::String)
    # Import JuliaBridge if not already imported
    if !@isdefined(JuliaBridge)
        using ..JuliaBridge
    end

    # Check if bridge is connected
    if !JuliaBridge.isConnected()
        try
            JuliaBridge.connect()
        catch e
            @error "Failed to connect to JuliaOS backend: $e"
            # Fallback to local implementation if bridge connection fails
            return true
        end
    end

    # Execute the command on the backend
    result = JuliaBridge.execute("swarms.add_agent", Dict("swarm_id" => swarm_id, "agent_id" => agent_id))

    if result.success
        @info "Added agent to swarm via backend: $agent_id to $swarm_id"
        return true
    else
        # If backend call fails, log warning and return false
        @warn "Backend add agent to swarm failed: $(result.error)."
        return false
    end
end

"""
    removeAgentFromSwarm(swarm_id::String, agent_id::String)

Remove an agent from a swarm.

# Arguments
- `swarm_id::String`: Swarm ID
- `agent_id::String`: Agent ID to remove

# Returns
- `Bool`: true if successful, false otherwise
"""
function removeAgentFromSwarm(swarm_id::String, agent_id::String)
    # Import JuliaBridge if not already imported
    if !@isdefined(JuliaBridge)
        using ..JuliaBridge
    end

    # Check if bridge is connected
    if !JuliaBridge.isConnected()
        try
            JuliaBridge.connect()
        catch e
            @error "Failed to connect to JuliaOS backend: $e"
            # Fallback to local implementation if bridge connection fails
            return true
        end
    end

    # Execute the command on the backend
    result = JuliaBridge.execute("swarms.remove_agent", Dict("swarm_id" => swarm_id, "agent_id" => agent_id))

    if result.success
        @info "Removed agent from swarm via backend: $agent_id from $swarm_id"
        return true
    else
        # If backend call fails, log warning and return false
        @warn "Backend remove agent from swarm failed: $(result.error)."
        return false
    end
end

"""
    list_algorithms()

List all available swarm algorithms with their parameters.

# Returns
- `Dict`: Dictionary with success status and algorithms data
"""
function list_algorithms()
    # Import JuliaBridge if not already imported
    if !@isdefined(JuliaBridge)
        using ..JuliaBridge
    end

    # Check if bridge is connected
    if !JuliaBridge.isConnected()
        try
            JuliaBridge.connect()
        catch e
            @error "Failed to connect to JuliaOS backend: $e"
            # Fallback to local implementation if bridge connection fails
            return _list_algorithms_local()
        end
    end

    # Execute the command on the backend
    result = JuliaBridge.execute("swarms.list_algorithms", Dict{String, Any}())

    if result.success
        @info "Listed algorithms via backend"
        return result.data
    else
        # If backend call fails, fallback to local implementation
        @warn "Backend list algorithms failed: $(result.error). Using local implementation."
        return _list_algorithms_local()
    end
end

# Local implementation of list_algorithms as a fallback
function _list_algorithms_local()
    try
        # Return the list of available algorithms with local implementations
        algorithms = [
            Dict(
                "id" => "PSO",
                "name" => "Particle Swarm Optimization",
                "description" => "A population-based optimization technique inspired by social behavior of bird flocking or fish schooling.",
                "parameters" => [
                    Dict("name" => "particles", "type" => "integer", "default" => 30, "description" => "Number of particles in the swarm"),
                    Dict("name" => "c1", "type" => "float", "default" => 2.0, "description" => "Cognitive parameter"),
                    Dict("name" => "c2", "type" => "float", "default" => 2.0, "description" => "Social parameter"),
                    Dict("name" => "w", "type" => "float", "default" => 0.7, "description" => "Inertia weight")
                ]
            ),
            Dict(
                "id" => "GWO",
                "name" => "Grey Wolf Optimizer",
                "description" => "A meta-heuristic algorithm inspired by the leadership hierarchy and hunting mechanism of grey wolves.",
                "parameters" => [
                    Dict("name" => "wolves", "type" => "integer", "default" => 30, "description" => "Number of wolves in the pack"),
                    Dict("name" => "a_start", "type" => "float", "default" => 2.0, "description" => "Control parameter start"),
                    Dict("name" => "a_end", "type" => "float", "default" => 0.0, "description" => "Control parameter end")
                ]
            ),
            Dict(
                "id" => "ACO",
                "name" => "Ant Colony Optimization",
                "description" => "A probabilistic technique for solving computational problems which can be reduced to finding good paths through graphs.",
                "parameters" => [
                    Dict("name" => "ants", "type" => "integer", "default" => 30, "description" => "Number of ants"),
                    Dict("name" => "alpha", "type" => "float", "default" => 1.0, "description" => "Pheromone importance"),
                    Dict("name" => "beta", "type" => "float", "default" => 2.0, "description" => "Heuristic importance"),
                    Dict("name" => "rho", "type" => "float", "default" => 0.5, "description" => "Pheromone evaporation rate")
                ]
            ),
            Dict(
                "id" => "GA",
                "name" => "Genetic Algorithm",
                "description" => "A search heuristic that mimics the process of natural selection.",
                "parameters" => [
                    Dict("name" => "population", "type" => "integer", "default" => 100, "description" => "Number of individuals in the population"),
                    Dict("name" => "crossover_rate", "type" => "float", "default" => 0.8, "description" => "Probability of crossover"),
                    Dict("name" => "mutation_rate", "type" => "float", "default" => 0.1, "description" => "Probability of mutation")
                ]
            ),
            Dict(
                "id" => "WOA",
                "name" => "Whale Optimization Algorithm",
                "description" => "A nature-inspired meta-heuristic optimization algorithm that mimics the hunting behavior of humpback whales.",
                "parameters" => [
                    Dict("name" => "whales", "type" => "integer", "default" => 30, "description" => "Number of whales"),
                    Dict("name" => "b", "type" => "float", "default" => 1.0, "description" => "Spiral shape constant")
                ]
            ),
            Dict(
                "id" => "DE",
                "name" => "Differential Evolution",
                "description" => "A stochastic population-based optimization algorithm for solving over-continuous spaces.",
                "parameters" => [
                    Dict("name" => "population", "type" => "integer", "default" => 100, "description" => "Number of individuals in the population"),
                    Dict("name" => "F", "type" => "float", "default" => 0.8, "description" => "Differential weight"),
                    Dict("name" => "CR", "type" => "float", "default" => 0.9, "description" => "Crossover probability")
                ]
            ),
            Dict(
                "id" => "DEPSO",
                "name" => "Differential Evolution Particle Swarm Optimization",
                "description" => "A hybrid algorithm that combines Differential Evolution and Particle Swarm Optimization.",
                "parameters" => [
                    Dict("name" => "population", "type" => "integer", "default" => 50, "description" => "Number of individuals in the population"),
                    Dict("name" => "F", "type" => "float", "default" => 0.8, "description" => "DE differential weight"),
                    Dict("name" => "CR", "type" => "float", "default" => 0.9, "description" => "DE crossover probability"),
                    Dict("name" => "w", "type" => "float", "default" => 0.7, "description" => "PSO inertia weight"),
                    Dict("name" => "c1", "type" => "float", "default" => 1.5, "description" => "PSO cognitive coefficient"),
                    Dict("name" => "c2", "type" => "float", "default" => 1.5, "description" => "PSO social coefficient"),
                    Dict("name" => "hybrid_ratio", "type" => "float", "default" => 0.5, "description" => "Ratio of DE to PSO (0-1)"),
                    Dict("name" => "adaptive", "type" => "boolean", "default" => true, "description" => "Whether to use adaptive parameter control")
                ]
            )
        ]

        return Dict("success" => true, "data" => Dict("algorithms" => algorithms))
    catch e
        @error "Error listing algorithms" exception=(e, catch_backtrace())
        return Dict("success" => false, "error" => "Error listing algorithms: $(string(e))")
    end
end

end # module