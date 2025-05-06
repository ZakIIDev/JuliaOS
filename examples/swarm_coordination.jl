"""
Swarm Coordination Example

This example demonstrates how to use JuliaOS swarm functionality for coordinating multiple agents.
"""

# Add the parent directory to the load path
push!(LOAD_PATH, joinpath(@__DIR__, ".."))

# Import required modules
using Pkg
Pkg.add("Plots")
Pkg.add("Colors")
Pkg.add("Statistics")

using Plots
using Colors
using Statistics
using Random
using Dates
using UUIDs

# Import JuliaOS modules
using julia.src.swarm.Swarms

# Set random seed for reproducibility
Random.seed!(42)

"""
    Agent

Structure representing an agent in the swarm.

# Fields
- `id::String`: Agent ID
- `position::Vector{Float64}`: Current position
- `velocity::Vector{Float64}`: Current velocity
- `sensor_range::Float64`: Sensor range
- `communication_range::Float64`: Communication range
- `battery::Float64`: Battery level (0-100)
- `state::Symbol`: Current state (:idle, :moving, :working, :charging)
- `task::Union{Dict, Nothing}`: Current task
"""
mutable struct Agent
    id::String
    position::Vector{Float64}
    velocity::Vector{Float64}
    sensor_range::Float64
    communication_range::Float64
    battery::Float64
    state::Symbol
    task::Union{Dict, Nothing}
    
    function Agent(id::String, position::Vector{Float64}; 
                  sensor_range=10.0, communication_range=20.0)
        new(
            id,
            position,
            zeros(length(position)),
            sensor_range,
            communication_range,
            100.0,  # Full battery
            :idle,
            nothing
        )
    end
end

"""
    Environment

Structure representing the environment for the swarm.

# Fields
- `size::Vector{Float64}`: Environment size
- `obstacles::Vector{Dict}`: Obstacles in the environment
- `targets::Vector{Dict}`: Targets in the environment
- `charging_stations::Vector{Dict}`: Charging stations
"""
mutable struct Environment
    size::Vector{Float64}
    obstacles::Vector{Dict}
    targets::Vector{Dict}
    charging_stations::Vector{Dict}
    
    function Environment(size::Vector{Float64}; 
                        num_obstacles=5, num_targets=10, num_charging_stations=3)
        # Create obstacles
        obstacles = []
        for _ in 1:num_obstacles
            push!(obstacles, Dict(
                "position" => rand(length(size)) .* size,
                "radius" => 2.0 + rand() * 5.0
            ))
        end
        
        # Create targets
        targets = []
        for _ in 1:num_targets
            push!(targets, Dict(
                "position" => rand(length(size)) .* size,
                "value" => 10.0 + rand() * 90.0,
                "discovered" => false,
                "completed" => false
            ))
        end
        
        # Create charging stations
        charging_stations = []
        for _ in 1:num_charging_stations
            push!(charging_stations, Dict(
                "position" => rand(length(size)) .* size,
                "capacity" => 3,  # Number of agents that can charge simultaneously
                "current_agents" => 0
            ))
        end
        
        new(size, obstacles, targets, charging_stations)
    end
end

"""
    create_agents(num_agents::Int, env_size::Vector{Float64})

Create a set of agents in the environment.

# Arguments
- `num_agents::Int`: Number of agents to create
- `env_size::Vector{Float64}`: Environment size

# Returns
- `Vector{Agent}`: Created agents
"""
function create_agents(num_agents::Int, env_size::Vector{Float64})
    agents = []
    for i in 1:num_agents
        agent_id = "agent-$(lpad(i, 3, '0'))"
        position = rand(length(env_size)) .* env_size
        push!(agents, Agent(agent_id, position))
    end
    return agents
end

"""
    distance(a::Vector{Float64}, b::Vector{Float64})

Calculate Euclidean distance between two points.

# Arguments
- `a::Vector{Float64}`: First point
- `b::Vector{Float64}`: Second point

# Returns
- `Float64`: Distance
"""
function distance(a::Vector{Float64}, b::Vector{Float64})
    return sqrt(sum((a - b).^2))
end

"""
    get_neighbors(agent::Agent, agents::Vector{Agent})

Get neighboring agents within communication range.

# Arguments
- `agent::Agent`: Agent to find neighbors for
- `agents::Vector{Agent}`: All agents

# Returns
- `Vector{Agent}`: Neighboring agents
"""
function get_neighbors(agent::Agent, agents::Vector{Agent})
    neighbors = []
    for other in agents
        if other.id != agent.id && distance(agent.position, other.position) <= agent.communication_range
            push!(neighbors, other)
        end
    end
    return neighbors
end

"""
    detect_targets(agent::Agent, environment::Environment)

Detect targets within sensor range.

# Arguments
- `agent::Agent`: Agent
- `environment::Environment`: Environment

# Returns
- `Vector{Dict}`: Detected targets
"""
function detect_targets(agent::Agent, environment::Environment)
    detected = []
    for (i, target) in enumerate(environment.targets)
        if !target["completed"] && distance(agent.position, target["position"]) <= agent.sensor_range
            # Mark target as discovered
            environment.targets[i]["discovered"] = true
            push!(detected, merge(target, Dict("index" => i)))
        end
    end
    return detected
end

"""
    find_nearest_charging_station(agent::Agent, environment::Environment)

Find the nearest charging station.

# Arguments
- `agent::Agent`: Agent
- `environment::Environment`: Environment

# Returns
- `Tuple`: (index, station, distance)
"""
function find_nearest_charging_station(agent::Agent, environment::Environment)
    nearest_idx = 0
    nearest_station = nothing
    min_dist = Inf
    
    for (i, station) in enumerate(environment.charging_stations)
        dist = distance(agent.position, station["position"])
        if dist < min_dist
            min_dist = dist
            nearest_idx = i
            nearest_station = station
        end
    end
    
    return (nearest_idx, nearest_station, min_dist)
end

"""
    move_agent!(agent::Agent, target_position::Vector{Float64}, environment::Environment; speed=1.0)

Move an agent towards a target position.

# Arguments
- `agent::Agent`: Agent to move
- `target_position::Vector{Float64}`: Target position
- `environment::Environment`: Environment
- `speed::Float64`: Movement speed

# Returns
- `Bool`: Whether the agent reached the target
"""
function move_agent!(agent::Agent, target_position::Vector{Float64}, environment::Environment; speed=1.0)
    # Calculate direction
    direction = target_position - agent.position
    dist = norm(direction)
    
    # Check if we've reached the target
    if dist < 0.1
        agent.velocity = zeros(length(agent.position))
        return true
    end
    
    # Normalize direction
    direction = direction / dist
    
    # Set velocity
    agent.velocity = direction * speed
    
    # Update position
    new_position = agent.position + agent.velocity
    
    # Check for collisions with obstacles
    collision = false
    for obstacle in environment.obstacles
        if distance(new_position, obstacle["position"]) <= obstacle["radius"]
            collision = true
            break
        end
    end
    
    # Check for environment boundaries
    for i in 1:length(new_position)
        if new_position[i] < 0 || new_position[i] > environment.size[i]
            collision = true
            break
        end
    end
    
    # Update position if no collision
    if !collision
        agent.position = new_position
    else
        # Random direction if collision
        agent.velocity = randn(length(agent.position))
        agent.velocity = agent.velocity / norm(agent.velocity) * speed
        
        # Try new position
        new_position = agent.position + agent.velocity
        
        # Check if new position is valid
        valid = true
        for obstacle in environment.obstacles
            if distance(new_position, obstacle["position"]) <= obstacle["radius"]
                valid = false
                break
            end
        end
        
        for i in 1:length(new_position)
            if new_position[i] < 0 || new_position[i] > environment.size[i]
                valid = false
                break
            end
        end
        
        # Update position if valid
        if valid
            agent.position = new_position
        end
    end
    
    # Consume battery
    agent.battery = max(0.0, agent.battery - 0.1)
    
    return false
end

"""
    update_agent!(agent::Agent, agents::Vector{Agent}, environment::Environment, swarm_id::String)

Update an agent's state and behavior.

# Arguments
- `agent::Agent`: Agent to update
- `agents::Vector{Agent}`: All agents
- `environment::Environment`: Environment
- `swarm_id::String`: Swarm ID
"""
function update_agent!(agent::Agent, agents::Vector{Agent}, environment::Environment, swarm_id::String)
    # Check battery level
    if agent.battery < 20.0 && agent.state != :charging
        # Find nearest charging station
        _, station, dist = find_nearest_charging_station(agent, environment)
        
        if dist < 0.1
            # At charging station
            agent.state = :charging
            agent.velocity = zeros(length(agent.position))
        else
            # Move to charging station
            agent.state = :moving
            move_agent!(agent, station["position"], environment)
        end
        return
    end
    
    # If charging, continue until full
    if agent.state == :charging
        agent.battery = min(100.0, agent.battery + 1.0)
        
        if agent.battery >= 100.0
            agent.state = :idle
        end
        return
    end
    
    # If agent has a task, continue it
    if agent.task !== nothing
        if agent.state == :moving
            # Moving to target
            target_pos = agent.task["position"]
            reached = move_agent!(agent, target_pos, environment)
            
            if reached
                agent.state = :working
                agent.task["progress"] = 0.0
            end
        elseif agent.state == :working
            # Working on target
            agent.task["progress"] += 5.0
            
            # Consume more battery when working
            agent.battery = max(0.0, agent.battery - 0.2)
            
            if agent.task["progress"] >= 100.0
                # Task completed
                target_idx = agent.task["index"]
                environment.targets[target_idx]["completed"] = true
                
                # Publish task completion to swarm
                try
                    Swarms.updateSharedState!(swarm_id, "completed_targets", 
                                             get(Swarms.getSharedState(swarm_id, "completed_targets", []), 
                                                 target_idx))
                catch e
                    println("Error updating shared state: $e")
                end
                
                agent.task = nothing
                agent.state = :idle
            end
        end
        return
    end
    
    # If idle, look for targets
    if agent.state == :idle
        # Detect targets
        detected = detect_targets(agent, environment)
        
        if !isempty(detected)
            # Find highest value target
            best_target = nothing
            best_value = -Inf
            
            for target in detected
                if !target["completed"] && target["value"] > best_value
                    best_target = target
                    best_value = target["value"]
                end
            end
            
            if best_target !== nothing
                # Assign task
                agent.task = best_target
                agent.state = :moving
                return
            end
        end
        
        # If no targets detected, explore randomly
        explore_position = rand(length(environment.size)) .* environment.size
        move_agent!(agent, explore_position, environment; speed=0.5)
    end
end

"""
    run_simulation(num_agents::Int, env_size::Vector{Float64}, num_steps::Int)

Run a swarm coordination simulation.

# Arguments
- `num_agents::Int`: Number of agents
- `env_size::Vector{Float64}`: Environment size
- `num_steps::Int`: Number of simulation steps

# Returns
- `Dict`: Simulation results
"""
function run_simulation(num_agents::Int, env_size::Vector{Float64}, num_steps::Int)
    # Create environment
    environment = Environment(env_size)
    
    # Create agents
    agents = create_agents(num_agents, env_size)
    
    # Create swarm
    config = SwarmConfig(
        "Exploration Swarm",
        SwarmPSO(),
        "exploration",
        Dict("max_iterations" => num_steps)
    )
    
    swarm_result = Swarms.create_swarm(config)
    if !swarm_result["success"]
        error("Failed to create swarm: $(swarm_result["error"])")
    end
    
    swarm_id = swarm_result["id"]
    
    # Add agents to swarm
    for agent in agents
        Swarms.addAgentToSwarm(swarm_id, agent.id)
    end
    
    # Initialize shared state
    Swarms.updateSharedState!(swarm_id, "discovered_targets", [])
    Swarms.updateSharedState!(swarm_id, "completed_targets", [])
    
    # Initialize visualization
    if length(env_size) == 2
        p = plot(
            xlim=(0, env_size[1]),
            ylim=(0, env_size[2]),
            title="Swarm Coordination",
            xlabel="X",
            ylabel="Y",
            aspect_ratio=:equal,
            legend=:topright
        )
        
        # Plot obstacles
        for obstacle in environment.obstacles
            circle = [(obstacle["position"][1] + obstacle["radius"] * cos(t), 
                       obstacle["position"][2] + obstacle["radius"] * sin(t)) 
                      for t in range(0, 2π, length=100)]
            plot!(p, first.(circle), last.(circle), color=:gray, fill=true, alpha=0.5, label=nothing)
        end
        
        # Plot charging stations
        for station in environment.charging_stations
            scatter!(p, [station["position"][1]], [station["position"][2]], 
                    color=:green, marker=:square, markersize=8, label=nothing)
        end
        
        # Plot targets
        for target in environment.targets
            scatter!(p, [target["position"][1]], [target["position"][2]], 
                    color=:red, marker=:star, markersize=6, label=nothing)
        end
        
        # Plot agents
        agent_positions = [[agent.position[1] for agent in agents], 
                          [agent.position[2] for agent in agents]]
        scatter!(p, agent_positions[1], agent_positions[2], 
                color=:blue, marker=:circle, markersize=4, label="Agents")
        
        # Save initial state
        savefig(p, "swarm_coordination_initial.png")
    end
    
    # Run simulation
    println("Running simulation for $num_steps steps...")
    
    # Store metrics
    discovered_targets = []
    completed_targets = []
    avg_battery = []
    
    # Run steps
    for step in 1:num_steps
        if step % 10 == 0
            println("Step $step/$num_steps")
        end
        
        # Update each agent
        for agent in agents
            update_agent!(agent, agents, environment, swarm_id)
        end
        
        # Calculate metrics
        num_discovered = count(t -> t["discovered"], environment.targets)
        num_completed = count(t -> t["completed"], environment.targets)
        avg_batt = mean([agent.battery for agent in agents])
        
        push!(discovered_targets, num_discovered)
        push!(completed_targets, num_completed)
        push!(avg_battery, avg_batt)
        
        # Visualize every 10 steps
        if length(env_size) == 2 && step % 10 == 0
            p = plot(
                xlim=(0, env_size[1]),
                ylim=(0, env_size[2]),
                title="Swarm Coordination - Step $step",
                xlabel="X",
                ylabel="Y",
                aspect_ratio=:equal,
                legend=:topright
            )
            
            # Plot obstacles
            for obstacle in environment.obstacles
                circle = [(obstacle["position"][1] + obstacle["radius"] * cos(t), 
                           obstacle["position"][2] + obstacle["radius"] * sin(t)) 
                          for t in range(0, 2π, length=100)]
                plot!(p, first.(circle), last.(circle), color=:gray, fill=true, alpha=0.5, label=nothing)
            end
            
            # Plot charging stations
            for station in environment.charging_stations
                scatter!(p, [station["position"][1]], [station["position"][2]], 
                        color=:green, marker=:square, markersize=8, label=nothing)
            end
            
            # Plot targets with different colors based on status
            for target in environment.targets
                if target["completed"]
                    color = :green
                elseif target["discovered"]
                    color = :orange
                else
                    color = :red
                end
                
                scatter!(p, [target["position"][1]], [target["position"][2]], 
                        color=color, marker=:star, markersize=6, label=nothing)
            end
            
            # Plot agents with different colors based on state
            for agent in agents
                if agent.state == :idle
                    color = :blue
                elseif agent.state == :moving
                    color = :purple
                elseif agent.state == :working
                    color = :orange
                elseif agent.state == :charging
                    color = :green
                end
                
                scatter!(p, [agent.position[1]], [agent.position[2]], 
                        color=color, marker=:circle, markersize=4, label=nothing)
                
                # Draw communication range
                if rand() < 0.2  # Only draw for some agents to avoid clutter
                    circle = [(agent.position[1] + agent.communication_range * cos(t), 
                               agent.position[2] + agent.communication_range * sin(t)) 
                              for t in range(0, 2π, length=100)]
                    plot!(p, first.(circle), last.(circle), color=color, alpha=0.1, label=nothing)
                end
            end
            
            # Add legend for agent states
            scatter!(p, [], [], color=:blue, marker=:circle, label="Idle")
            scatter!(p, [], [], color=:purple, marker=:circle, label="Moving")
            scatter!(p, [], [], color=:orange, marker=:circle, label="Working")
            scatter!(p, [], [], color=:green, marker=:circle, label="Charging")
            
            # Add legend for target states
            scatter!(p, [], [], color=:red, marker=:star, label="Undiscovered")
            scatter!(p, [], [], color=:orange, marker=:star, label="Discovered")
            scatter!(p, [], [], color=:green, marker=:star, label="Completed")
            
            # Save visualization
            savefig(p, "swarm_coordination_step_$(lpad(step, 4, '0')).png")
        end
    end
    
    # Plot metrics
    p_metrics = plot(
        1:num_steps,
        [discovered_targets, completed_targets],
        title="Swarm Performance",
        xlabel="Step",
        ylabel="Number of Targets",
        label=["Discovered" "Completed"],
        linewidth=2
    )
    
    p_battery = plot(
        1:num_steps,
        avg_battery,
        title="Average Battery Level",
        xlabel="Step",
        ylabel="Battery (%)",
        linewidth=2,
        legend=false
    )
    
    # Save metrics plots
    savefig(p_metrics, "swarm_metrics.png")
    savefig(p_battery, "swarm_battery.png")
    
    # Final visualization
    if length(env_size) == 2
        p = plot(
            xlim=(0, env_size[1]),
            ylim=(0, env_size[2]),
            title="Swarm Coordination - Final State",
            xlabel="X",
            ylabel="Y",
            aspect_ratio=:equal,
            legend=:topright
        )
        
        # Plot obstacles
        for obstacle in environment.obstacles
            circle = [(obstacle["position"][1] + obstacle["radius"] * cos(t), 
                       obstacle["position"][2] + obstacle["radius"] * sin(t)) 
                      for t in range(0, 2π, length=100)]
            plot!(p, first.(circle), last.(circle), color=:gray, fill=true, alpha=0.5, label=nothing)
        end
        
        # Plot charging stations
        for station in environment.charging_stations
            scatter!(p, [station["position"][1]], [station["position"][2]], 
                    color=:green, marker=:square, markersize=8, label=nothing)
        end
        
        # Plot targets with different colors based on status
        for target in environment.targets
            if target["completed"]
                color = :green
            elseif target["discovered"]
                color = :orange
            else
                color = :red
            end
            
            scatter!(p, [target["position"][1]], [target["position"][2]], 
                    color=color, marker=:star, markersize=6, label=nothing)
        end
        
        # Plot agents with different colors based on state
        for agent in agents
            if agent.state == :idle
                color = :blue
            elseif agent.state == :moving
                color = :purple
            elseif agent.state == :working
                color = :orange
            elseif agent.state == :charging
                color = :green
            end
            
            scatter!(p, [agent.position[1]], [agent.position[2]], 
                    color=color, marker=:circle, markersize=4, label=nothing)
        end
        
        # Add legend for agent states
        scatter!(p, [], [], color=:blue, marker=:circle, label="Idle")
        scatter!(p, [], [], color=:purple, marker=:circle, label="Moving")
        scatter!(p, [], [], color=:orange, marker=:circle, label="Working")
        scatter!(p, [], [], color=:green, marker=:circle, label="Charging")
        
        # Add legend for target states
        scatter!(p, [], [], color=:red, marker=:star, label="Undiscovered")
        scatter!(p, [], [], color=:orange, marker=:star, label="Discovered")
        scatter!(p, [], [], color=:green, marker=:star, label="Completed")
        
        # Save final visualization
        savefig(p, "swarm_coordination_final.png")
    end
    
    # Print final statistics
    println("Simulation completed!")
    println("Final statistics:")
    println("  Discovered targets: $(discovered_targets[end])/$(length(environment.targets))")
    println("  Completed targets: $(completed_targets[end])/$(length(environment.targets))")
    println("  Average battery level: $(round(avg_battery[end], digits=2))%")
    
    # Return results
    return Dict(
        "environment" => environment,
        "agents" => agents,
        "swarm_id" => swarm_id,
        "metrics" => Dict(
            "discovered_targets" => discovered_targets,
            "completed_targets" => completed_targets,
            "avg_battery" => avg_battery
        )
    )
end

# Run the example if this file is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    # Run a 2D simulation with 10 agents for 100 steps
    run_simulation(10, [100.0, 100.0], 100)
end
