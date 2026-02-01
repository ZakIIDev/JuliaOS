"""
EnhancedPSO.jl - Enhanced Particle Swarm Optimization Algorithm with Early Stopping and Inertia Decay
"""
module EnhancedPSOAlgorithm

using Logging
using ..SwarmBase

export EnhancedPSO

mutable struct Particle
    position::Vector{Float64}
    velocity::Vector{Float64}
    best_position::Vector{Float64}
    best_fitness::Float64
    current_fitness::Float64

    Particle(dims::Int) = new(zeros(dims), zeros(dims), zeros(dims), Inf, Inf)
end

mutable struct EnhancedPSO <: AbstractSwarmAlgorithm
    num_particles::Int
    inertia_weight::Float64
    inertia_decay::Float64  # Factor to reduce inertia over time
    min_inertia::Float64
    cognitive_coeff::Float64 # c1
    social_coeff::Float64    # c2
    particles::Vector{Particle}
    global_best_position::Vector{Float64}
    global_best_fitness::Float64
    stagnation_counter::Int
    max_stagnation::Int      # Early stopping threshold
    prev_best_fitness::Float64
    velocity_clamping_factor::Float64

    function EnhancedPSO(; 
        num_particles::Int=30, 
        inertia::Float64=0.9, 
        decay::Float64=0.99,
        min_inertia::Float64=0.4,
        c1::Float64=1.5, 
        c2::Float64=1.5, 
        max_stagnation::Int=20,
        vel_clamp_factor::Float64=0.2
    )
        return new(
            num_particles, inertia, decay, min_inertia, c1, c2,
            Vector{Particle}(), Vector{Float64}(), Inf,
            0, max_stagnation, Inf, vel_clamp_factor
        )
    end
end

function SwarmBase.initialize!(alg::EnhancedPSO, problem::OptimizationProblem, agents::Vector{String}, config_params::Dict)
    alg.particles = [Particle(problem.dimensions) for _ in 1:alg.num_particles]
    alg.global_best_position = zeros(problem.dimensions)
    alg.global_best_fitness = problem.is_minimization ? Inf : -Inf
    alg.prev_best_fitness = alg.global_best_fitness

    for p in alg.particles
        for d in 1:problem.dimensions
            p.position[d] = problem.bounds[d][1] + rand() * (problem.bounds[d][2] - problem.bounds[d][1])
        end
        p.velocity .= 0.0
        p.best_position = copy(p.position)
        p.current_fitness = problem.objective_function(p.position)
        p.best_fitness = p.current_fitness

        if (problem.is_minimization && p.best_fitness < alg.global_best_fitness) ||
           (!problem.is_minimization && p.best_fitness > alg.global_best_fitness)
            alg.global_best_fitness = p.best_fitness
            alg.global_best_position = copy(p.best_position)
        end
    end
    @info "EnhancedPSO initialized."
end

function SwarmBase.step!(alg::EnhancedPSO, problem::OptimizationProblem, agents::Vector{String}, current_iter::Int, shared_data::Dict, config_params::Dict)::Vector{Vector{Float64}}
    # Decay inertia weight
    alg.inertia_weight = max(alg.min_inertia, alg.inertia_weight * alg.inertia_decay)
    
    new_positions = Vector{Vector{Float64}}(undef, alg.num_particles)

    for (idx, p) in enumerate(alg.particles)
        r1, r2 = rand(), rand()
        cog = alg.cognitive_coeff * r1 * (p.best_position - p.position)
        soc = alg.social_coeff * r2 * (alg.global_best_position - p.position)
        p.velocity = alg.inertia_weight * p.velocity + cog + soc

        # Velocity clamping
        for d in 1:problem.dimensions
            v_max = alg.velocity_clamping_factor * (problem.bounds[d][2] - problem.bounds[d][1])
            p.velocity[d] = clamp(p.velocity[d], -v_max, v_max)
        end

        p.position += p.velocity
        
        # Clamp to bounds
        for d in 1:problem.dimensions
            p.position[d] = clamp(p.position[d], problem.bounds[d][1], problem.bounds[d][2])
        end
        new_positions[idx] = copy(p.position)
    end
    return new_positions
end

function SwarmBase.should_terminate(alg::EnhancedPSO, current_iter::Int, max_iter::Int, best_solution::Union{SwarmSolution,Nothing}, target_fitness::Union{Float64,Nothing}, problem::OptimizationProblem)::Bool
    if isnothing(best_solution) return current_iter >= max_iter end
    
    # Target fitness check
    if !isnothing(target_fitness)
        if (problem.is_minimization && best_solution.fitness <= target_fitness) ||
           (!problem.is_minimization && best_solution.fitness >= target_fitness)
            @info "EnhancedPSO: Target reached."
            return true
        end
    end

    # Stagnation check (Early Stopping)
    if abs(best_solution.fitness - alg.prev_best_fitness) < 1e-6
        alg.stagnation_counter += 1
    else
        alg.stagnation_counter = 0
    end
    alg.prev_best_fitness = best_solution.fitness

    if alg.stagnation_counter >= alg.max_stagnation
        @info "EnhancedPSO: Early stopping due to stagnation."
        return true
    end

    return current_iter >= max_iter
end

end # module
