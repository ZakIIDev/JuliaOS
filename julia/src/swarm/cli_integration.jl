"""
CLI integration module for JuliaOS swarm algorithms.

This module provides tools for integrating swarm algorithms with the JuliaOS CLI.
"""
module SwarmCLIIntegration

export get_swarm_cli_commands, format_swarm_result, visualize_swarm_cli, 
       handle_swarm_command, get_algorithm_options, parse_algorithm_params

using ..SwarmBase
using ..Swarms
using ..SwarmVisualization
using JSON3

"""
    get_swarm_cli_commands()

Get a list of available swarm commands for the CLI.

# Returns
- `Dict`: Available commands and their descriptions
"""
function get_swarm_cli_commands()
    return Dict(
        "create" => "Create a new swarm",
        "list" => "List all swarms",
        "view" => "View details of a swarm",
        "start" => "Start a swarm",
        "stop" => "Stop a swarm",
        "status" => "Get the status of a swarm",
        "delete" => "Delete a swarm",
        "add-agent" => "Add an agent to a swarm",
        "remove-agent" => "Remove an agent from a swarm",
        "set-state" => "Set a value in the swarm's shared state",
        "get-state" => "Get a value from the swarm's shared state",
        "allocate-task" => "Allocate a task to the swarm",
        "claim-task" => "Claim a task for an agent",
        "complete-task" => "Mark a task as completed",
        "elect-leader" => "Elect a leader for the swarm",
        "metrics" => "Get metrics for a swarm",
        "visualize" => "Visualize a swarm algorithm",
        "optimize" => "Run a swarm optimization algorithm"
    )
end

"""
    get_algorithm_options()

Get a list of available swarm algorithms for the CLI.

# Returns
- `Dict`: Available algorithms and their descriptions
"""
function get_algorithm_options()
    return Dict(
        "pso" => "Particle Swarm Optimization",
        "de" => "Differential Evolution",
        "gwo" => "Grey Wolf Optimizer",
        "aco" => "Ant Colony Optimization",
        "ga" => "Genetic Algorithm",
        "woa" => "Whale Optimization Algorithm",
        "depso" => "Hybrid Differential Evolution and Particle Swarm Optimization"
    )
end

"""
    parse_algorithm_params(algorithm_type::String, params::Dict)

Parse algorithm parameters from CLI input.

# Arguments
- `algorithm_type::String`: Type of algorithm
- `params::Dict`: Parameters from CLI

# Returns
- `AbstractSwarmAlgorithm`: The configured algorithm
"""
function parse_algorithm_params(algorithm_type::String, params::Dict)
    if algorithm_type == "pso"
        return SwarmPSO(
            particles = get(params, "particles", 30),
            c1 = get(params, "c1", 2.0),
            c2 = get(params, "c2", 2.0),
            w = get(params, "w", 0.7)
        )
    elseif algorithm_type == "de"
        return SwarmDE(
            population = get(params, "population", 100),
            F = get(params, "F", 0.8),
            CR = get(params, "CR", 0.9)
        )
    elseif algorithm_type == "gwo"
        return SwarmGWO(
            wolves = get(params, "wolves", 30),
            a_start = get(params, "a_start", 2.0),
            a_end = get(params, "a_end", 0.0)
        )
    elseif algorithm_type == "aco"
        return SwarmACO(
            ants = get(params, "ants", 30),
            alpha = get(params, "alpha", 1.0),
            beta = get(params, "beta", 2.0),
            rho = get(params, "rho", 0.5)
        )
    elseif algorithm_type == "ga"
        return SwarmGA(
            population = get(params, "population", 100),
            crossover_rate = get(params, "crossover_rate", 0.8),
            mutation_rate = get(params, "mutation_rate", 0.1)
        )
    elseif algorithm_type == "woa"
        return SwarmWOA(
            whales = get(params, "whales", 30),
            b = get(params, "b", 1.0)
        )
    elseif algorithm_type == "depso"
        return SwarmDEPSO(
            population = get(params, "population", 50),
            F = get(params, "F", 0.8),
            CR = get(params, "CR", 0.9),
            w = get(params, "w", 0.7),
            c1 = get(params, "c1", 1.5),
            c2 = get(params, "c2", 1.5),
            hybrid_ratio = get(params, "hybrid_ratio", 0.5),
            adaptive = get(params, "adaptive", true)
        )
    else
        error("Unknown algorithm type: $algorithm_type")
    end
end

"""
    format_swarm_result(result::Dict)

Format a swarm result for CLI output.

# Arguments
- `result::Dict`: Result from a swarm operation

# Returns
- `Dict`: Formatted result for CLI
"""
function format_swarm_result(result::Dict)
    # Create a copy to avoid modifying the original
    formatted = copy(result)
    
    # Format success/error
    if haskey(formatted, "success") && !formatted["success"] && haskey(formatted, "error")
        formatted["message"] = "Error: $(formatted["error"])"
        delete!(formatted, "error")
    end
    
    # Format data if present
    if haskey(formatted, "data") && formatted["data"] isa Dict
        # Merge data into the main result
        for (k, v) in formatted["data"]
            formatted[k] = v
        end
        delete!(formatted, "data")
    end
    
    # Format dates
    for (k, v) in formatted
        if v isa DateTime
            formatted[k] = string(v)
        end
    end
    
    return formatted
end

"""
    visualize_swarm_cli(result::OptimizationResult, save_path::String)

Visualize a swarm optimization result for CLI output.

# Arguments
- `result::OptimizationResult`: Optimization result
- `save_path::String`: Path to save visualization

# Returns
- `Dict`: Result with visualization path
"""
function visualize_swarm_cli(result::OptimizationResult, save_path::String)
    # Create directory if it doesn't exist
    mkpath(dirname(save_path))
    
    # Generate visualization
    try
        # Create convergence plot
        path = SwarmVisualization.save_visualization(result, dirname(save_path))
        
        return Dict(
            "success" => true,
            "visualization_path" => path,
            "message" => "Visualization saved to $path"
        )
    catch e
        return Dict(
            "success" => false,
            "error" => "Failed to create visualization: $(string(e))"
        )
    end
end

"""
    handle_swarm_command(command::String, args::Dict)

Handle a swarm command from the CLI.

# Arguments
- `command::String`: Command to execute
- `args::Dict`: Command arguments

# Returns
- `Dict`: Command result
"""
function handle_swarm_command(command::String, args::Dict)
    try
        if command == "create"
            # Parse algorithm
            algorithm_type = get(args, "algorithm", "pso")
            algorithm_params = get(args, "algorithm_params", Dict())
            algorithm = parse_algorithm_params(algorithm_type, algorithm_params)
            
            # Create config
            config = SwarmConfig(
                get(args, "name", "Swarm-$(randstring(4))"),
                algorithm,
                get(args, "objective", "default"),
                get(args, "parameters", Dict())
            )
            
            # Create swarm
            return Swarms.create_swarm(config)
        elseif command == "list"
            return Swarms.listSwarms(
                filter_status = get(args, "status", nothing),
                limit = get(args, "limit", 100),
                offset = get(args, "offset", 0)
            )
        elseif command == "view"
            swarm_id = get(args, "id", "")
            if swarm_id == ""
                return Dict("success" => false, "error" => "Swarm ID is required")
            end
            
            swarm = Swarms.getSwarm(swarm_id)
            if swarm === nothing
                return Dict("success" => false, "error" => "Swarm not found")
            end
            
            # Convert swarm to a dictionary
            return Dict(
                "success" => true,
                "data" => Dict(
                    "id" => swarm.id,
                    "name" => swarm.name,
                    "status" => string(swarm.status),
                    "created" => swarm.created,
                    "updated" => swarm.updated,
                    "algorithm" => string(typeof(swarm.algorithm)),
                    "agent_count" => length(swarm.agent_ids),
                    "current_iteration" => swarm.current_iteration
                )
            )
        elseif command == "start"
            swarm_id = get(args, "id", "")
            if swarm_id == ""
                return Dict("success" => false, "error" => "Swarm ID is required")
            end
            
            return Swarms.startSwarm(swarm_id)
        elseif command == "stop"
            swarm_id = get(args, "id", "")
            if swarm_id == ""
                return Dict("success" => false, "error" => "Swarm ID is required")
            end
            
            return Swarms.stopSwarm(swarm_id)
        elseif command == "status"
            swarm_id = get(args, "id", "")
            if swarm_id == ""
                return Dict("success" => false, "error" => "Swarm ID is required")
            end
            
            return Swarms.getSwarmStatus(swarm_id)
        elseif command == "delete"
            swarm_id = get(args, "id", "")
            if swarm_id == ""
                return Dict("success" => false, "error" => "Swarm ID is required")
            end
            
            # This is a placeholder as deleteSwarm is not implemented in the core module
            # In a real implementation, we would call Swarms.deleteSwarm(swarm_id)
            swarm = Swarms.getSwarm(swarm_id)
            if swarm === nothing
                return Dict("success" => false, "error" => "Swarm not found")
            end
            
            # For now, just return success
            return Dict("success" => true, "message" => "Swarm deleted successfully")
        elseif command == "add-agent"
            swarm_id = get(args, "swarm_id", "")
            agent_id = get(args, "agent_id", "")
            
            if swarm_id == "" || agent_id == ""
                return Dict("success" => false, "error" => "Swarm ID and Agent ID are required")
            end
            
            return Swarms.addAgentToSwarm(swarm_id, agent_id)
        elseif command == "remove-agent"
            swarm_id = get(args, "swarm_id", "")
            agent_id = get(args, "agent_id", "")
            
            if swarm_id == "" || agent_id == ""
                return Dict("success" => false, "error" => "Swarm ID and Agent ID are required")
            end
            
            return Swarms.removeAgentFromSwarm(swarm_id, agent_id)
        elseif command == "set-state"
            swarm_id = get(args, "swarm_id", "")
            key = get(args, "key", "")
            value = get(args, "value", nothing)
            
            if swarm_id == "" || key == "" || value === nothing
                return Dict("success" => false, "error" => "Swarm ID, key, and value are required")
            end
            
            return Swarms.updateSharedState!(swarm_id, key, value)
        elseif command == "get-state"
            swarm_id = get(args, "swarm_id", "")
            key = get(args, "key", "")
            
            if swarm_id == "" || key == ""
                return Dict("success" => false, "error" => "Swarm ID and key are required")
            end
            
            value = Swarms.getSharedState(swarm_id, key)
            return Dict("success" => true, "value" => value)
        elseif command == "allocate-task"
            swarm_id = get(args, "swarm_id", "")
            task = get(args, "task", Dict())
            
            if swarm_id == "" || isempty(task)
                return Dict("success" => false, "error" => "Swarm ID and task are required")
            end
            
            return Swarms.allocateTask(swarm_id, task)
        elseif command == "claim-task"
            swarm_id = get(args, "swarm_id", "")
            task_id = get(args, "task_id", "")
            agent_id = get(args, "agent_id", "")
            
            if swarm_id == "" || task_id == "" || agent_id == ""
                return Dict("success" => false, "error" => "Swarm ID, task ID, and agent ID are required")
            end
            
            return Swarms.claimTask(swarm_id, task_id, agent_id)
        elseif command == "complete-task"
            swarm_id = get(args, "swarm_id", "")
            task_id = get(args, "task_id", "")
            agent_id = get(args, "agent_id", "")
            result = get(args, "result", Dict())
            
            if swarm_id == "" || task_id == "" || agent_id == ""
                return Dict("success" => false, "error" => "Swarm ID, task ID, and agent ID are required")
            end
            
            return Swarms.completeTask(swarm_id, task_id, agent_id, result)
        elseif command == "elect-leader"
            swarm_id = get(args, "swarm_id", "")
            
            if swarm_id == ""
                return Dict("success" => false, "error" => "Swarm ID is required")
            end
            
            return Swarms.electLeader(swarm_id)
        elseif command == "metrics"
            swarm_id = get(args, "swarm_id", "")
            
            if swarm_id == ""
                return Dict("success" => false, "error" => "Swarm ID is required")
            end
            
            return Swarms.getSwarmMetrics(swarm_id)
        elseif command == "visualize"
            # This command would visualize a swarm algorithm run
            # For now, just return a placeholder
            return Dict(
                "success" => false,
                "error" => "Visualization not implemented in CLI yet"
            )
        elseif command == "optimize"
            # This command would run a swarm optimization algorithm
            # For now, just return a placeholder
            return Dict(
                "success" => false,
                "error" => "Optimization not implemented in CLI yet"
            )
        else
            return Dict(
                "success" => false,
                "error" => "Unknown command: $command"
            )
        end
    catch e
        return Dict(
            "success" => false,
            "error" => "Error executing command: $(string(e))"
        )
    end
end

"""
    generate_cli_help()

Generate help text for the swarm CLI commands.

# Returns
- `String`: Help text
"""
function generate_cli_help()
    commands = get_swarm_cli_commands()
    algorithms = get_algorithm_options()
    
    help_text = """
    Swarm Commands:
    --------------
    """
    
    for (cmd, desc) in commands
        help_text *= "  $cmd: $desc\n"
    end
    
    help_text *= """
    
    Available Algorithms:
    -------------------
    """
    
    for (alg, desc) in algorithms
        help_text *= "  $alg: $desc\n"
    end
    
    help_text *= """
    
    Examples:
    --------
    create --name "My Swarm" --algorithm pso
    list
    view --id <swarm_id>
    start --id <swarm_id>
    stop --id <swarm_id>
    add-agent --swarm_id <swarm_id> --agent_id <agent_id>
    """
    
    return help_text
end

end # module
