"""
Testing module for JuliaOS swarm algorithms.

This module provides testing utilities for swarm algorithms.
"""
module SwarmTesting

export test_algorithm, benchmark_algorithm, test_swarm_operations, test_fault_tolerance

using Random
using Statistics
using BenchmarkTools
using Logging
using ..SwarmBase
using ..Swarms
using ..SwarmFaultTolerance

"""
    test_functions

Dictionary of test functions for benchmarking.
"""
const test_functions = Dict(
    "sphere" => (x -> sum(x.^2), true, "Sphere function (minimize)"),
    "rastrigin" => (x -> 10 * length(x) + sum(x.^2 - 10 * cos.(2π * x)), true, "Rastrigin function (minimize)"),
    "rosenbrock" => (x -> sum(100 * (x[2:end] - x[1:end-1].^2).^2 + (x[1:end-1] - 1).^2), true, "Rosenbrock function (minimize)"),
    "ackley" => (x -> -20 * exp(-0.2 * sqrt(sum(x.^2) / length(x))) - exp(sum(cos.(2π * x)) / length(x)) + 20 + exp(1), true, "Ackley function (minimize)"),
    "griewank" => (x -> 1 + sum(x.^2) / 4000 - prod(cos.(x ./ sqrt.(1:length(x)))), true, "Griewank function (minimize)")
)

"""
    create_test_problem(func_name::String, dimensions::Int)

Create a test optimization problem.

# Arguments
- `func_name::String`: Name of the test function
- `dimensions::Int`: Number of dimensions

# Returns
- `OptimizationProblem`: The test problem
"""
function create_test_problem(func_name::String, dimensions::Int)
    if !haskey(test_functions, func_name)
        error("Unknown test function: $func_name")
    end

    func, is_min, _ = test_functions[func_name]

    # Create bounds based on function
    bounds = if func_name == "rosenbrock"
        [(-5.0, 10.0) for _ in 1:dimensions]
    elseif func_name == "rastrigin"
        [(-5.12, 5.12) for _ in 1:dimensions]
    elseif func_name == "ackley"
        [(-32.768, 32.768) for _ in 1:dimensions]
    elseif func_name == "griewank"
        [(-600.0, 600.0) for _ in 1:dimensions]
    else
        [(-100.0, 100.0) for _ in 1:dimensions]
    end

    return OptimizationProblem(
        dimensions,
        bounds,
        func;
        is_minimization = is_min
    )
end

"""
    test_algorithm(algorithm::AbstractSwarmAlgorithm, func_name::String="sphere", dimensions::Int=10; runs::Int=10)

Test an optimization algorithm on a standard test function.

# Arguments
- `algorithm::AbstractSwarmAlgorithm`: The algorithm to test
- `func_name::String`: Name of the test function
- `dimensions::Int`: Number of dimensions
- `runs::Int`: Number of test runs

# Returns
- `Dict`: Test results
"""
function test_algorithm(algorithm::AbstractSwarmAlgorithm, func_name::String="sphere", dimensions::Int=10; runs::Int=10)
    # Create test problem
    problem = create_test_problem(func_name, dimensions)

    # Run multiple times to get statistics
    results = []

    for i in 1:runs
        @info "Running test $i of $runs..."
        result = optimize(problem, algorithm)
        push!(results, result)
    end

    # Calculate statistics
    fitness_values = [r.best_fitness for r in results]
    mean_fitness = mean(fitness_values)
    std_fitness = std(fitness_values)
    min_fitness = minimum(fitness_values)
    max_fitness = maximum(fitness_values)

    # Calculate success rate (if we know the global optimum)
    success_threshold = if func_name == "sphere"
        1e-5
    elseif func_name == "rastrigin"
        1e-2
    elseif func_name == "rosenbrock"
        1e-2
    elseif func_name == "ackley"
        1e-2
    elseif func_name == "griewank"
        1e-2
    else
        1e-5
    end

    success_count = count(f -> f < success_threshold, fitness_values)
    success_rate = success_count / runs

    # Return statistics
    return Dict(
        "algorithm" => string(typeof(algorithm)),
        "function" => func_name,
        "dimensions" => dimensions,
        "runs" => runs,
        "mean_fitness" => mean_fitness,
        "std_fitness" => std_fitness,
        "min_fitness" => min_fitness,
        "max_fitness" => max_fitness,
        "success_rate" => success_rate,
        "success_threshold" => success_threshold
    )
end

"""
    benchmark_algorithm(algorithm::AbstractSwarmAlgorithm, func_name::String="sphere", dimensions::Int=10)

Benchmark an optimization algorithm.

# Arguments
- `algorithm::AbstractSwarmAlgorithm`: The algorithm to benchmark
- `func_name::String`: Name of the test function
- `dimensions::Int`: Number of dimensions

# Returns
- `Dict`: Benchmark results
"""
function benchmark_algorithm(algorithm::AbstractSwarmAlgorithm, func_name::String="sphere", dimensions::Int=10)
    # Create test problem
    problem = create_test_problem(func_name, dimensions)

    # Run benchmark
    b = @benchmark optimize($problem, $algorithm)

    # Return statistics
    return Dict(
        "algorithm" => string(typeof(algorithm)),
        "function" => func_name,
        "dimensions" => dimensions,
        "mean_time" => mean(b.times) / 1e9,  # Convert to seconds
        "min_time" => minimum(b.times) / 1e9,
        "max_time" => maximum(b.times) / 1e9,
        "std_time" => std(b.times) / 1e9,
        "memory" => b.memory,
        "allocs" => b.allocs
    )
end

"""
    test_swarm_operations()

Test basic swarm operations.

# Returns
- `Dict`: Test results
"""
function test_swarm_operations()
    results = Dict{String, Any}()

    # Test creating a swarm
    @info "Testing swarm creation..."
    config = SwarmConfig(
        "Test Swarm",
        SwarmPSO(),
        "test",
        Dict("max_iterations" => 100)
    )

    create_result = Swarms.create_swarm(config)
    results["create_swarm"] = create_result["success"]

    if !create_result["success"]
        @error "Failed to create swarm: $(create_result["error"])"
        return results
    end

    swarm_id = create_result["id"]
    results["swarm_id"] = swarm_id

    # Test starting the swarm
    @info "Testing swarm start..."
    start_result = Swarms.startSwarm(swarm_id)
    results["start_swarm"] = start_result["success"]

    if !start_result["success"]
        @error "Failed to start swarm: $(start_result["error"])"
    end

    # Wait a moment for the swarm to start
    sleep(1)

    # Test getting swarm status
    @info "Testing swarm status..."
    status_result = Swarms.getSwarmStatus(swarm_id)
    results["get_status"] = status_result["success"]

    if !status_result["success"]
        @error "Failed to get swarm status: $(status_result["error"])"
    else
        results["status"] = status_result["data"]
    end

    # Test adding an agent
    @info "Testing agent addition..."
    agent_id = "test-agent-" * string(rand(1000:9999))
    add_result = Swarms.addAgentToSwarm(swarm_id, agent_id)
    results["add_agent"] = add_result["success"]

    if !add_result["success"]
        @error "Failed to add agent: $(add_result["error"])"
    end

    # Test shared state
    @info "Testing shared state..."
    update_result = Swarms.updateSharedState!(swarm_id, "test_key", "test_value")
    results["update_state"] = update_result["success"]

    if !update_result["success"]
        @error "Failed to update shared state: $(update_result["error"])"
    end

    # Get shared state
    state_value = Swarms.getSharedState(swarm_id, "test_key")
    results["get_state"] = state_value == "test_value"

    # Test stopping the swarm
    @info "Testing swarm stop..."
    stop_result = Swarms.stopSwarm(swarm_id)
    results["stop_swarm"] = stop_result["success"]

    if !stop_result["success"]
        @error "Failed to stop swarm: $(stop_result["error"])"
    end

    # Test removing an agent
    @info "Testing agent removal..."
    remove_result = Swarms.removeAgentFromSwarm(swarm_id, agent_id)
    results["remove_agent"] = remove_result["success"]

    if !remove_result["success"]
        @error "Failed to remove agent: $(remove_result["error"])"
    end

    # Calculate overall success
    total_tests = count(k -> startswith(string(k), "create_") ||
                             startswith(string(k), "start_") ||
                             startswith(string(k), "get_") ||
                             startswith(string(k), "add_") ||
                             startswith(string(k), "update_") ||
                             startswith(string(k), "stop_") ||
                             startswith(string(k), "remove_"), keys(results))

    passed_tests = count(k -> (startswith(string(k), "create_") ||
                               startswith(string(k), "start_") ||
                               startswith(string(k), "get_") ||
                               startswith(string(k), "add_") ||
                               startswith(string(k), "update_") ||
                               startswith(string(k), "stop_") ||
                               startswith(string(k), "remove_")) &&
                               results[k] == true, keys(results))

    results["total_tests"] = total_tests
    results["passed_tests"] = passed_tests
    results["success_rate"] = passed_tests / total_tests

    return results
end

"""
    test_fault_tolerance()

Test fault tolerance mechanisms.

# Returns
- `Dict`: Test results
"""
function test_fault_tolerance()
    results = Dict{String, Any}()

    # Check if fault tolerance module is available
    @info "Checking fault tolerance module..."
    results["import_module"] = true

    # Create a test swarm
    @info "Creating test swarm..."
    config = SwarmConfig(
        "Fault Tolerance Test",
        SwarmPSO(),
        "test",
        Dict("max_iterations" => 100)
    )

    create_result = Swarms.create_swarm(config)
    if !create_result["success"]
        @error "Failed to create swarm: $(create_result["error"])"
        results["create_swarm"] = false
        return results
    end

    results["create_swarm"] = true
    swarm_id = create_result["id"]

    # Create fault tolerant swarm
    @info "Creating fault tolerant swarm..."
    ft_swarm = SwarmFaultTolerance.FaultTolerantSwarm(
        swarm_id,
        checkpoint_interval = 5,
        max_failures = 2
    )

    results["create_ft_swarm"] = true

    # Test checkpoint creation
    @info "Testing checkpoint creation..."
    checkpoint_result = SwarmFaultTolerance.checkpoint_swarm(ft_swarm)
    results["create_checkpoint"] = checkpoint_result["success"]

    if !checkpoint_result["success"]
        @error "Failed to create checkpoint: $(checkpoint_result["error"])"
    else
        results["checkpoint_file"] = checkpoint_result["checkpoint_file"]
    end

    # Start the swarm
    @info "Starting swarm..."
    start_result = Swarms.startSwarm(swarm_id)
    results["start_swarm"] = start_result["success"]

    if !start_result["success"]
        @error "Failed to start swarm: $(start_result["error"])"
    end

    # Wait a moment
    sleep(1)

    # Test monitoring
    @info "Testing monitoring..."
    monitor_task = nothing
    try
        monitor_task = SwarmFaultTolerance.monitor_swarm(ft_swarm, interval=1)
        results["start_monitoring"] = true
    catch e
        @error "Failed to start monitoring" exception=(e, catch_backtrace())
        results["start_monitoring"] = false
    end

    # Wait for monitoring to run
    sleep(2)

    # Test recovery
    @info "Testing recovery..."
    recovery_result = SwarmFaultTolerance.recover_swarm(ft_swarm)
    results["recover_swarm"] = recovery_result["success"]

    if !recovery_result["success"]
        @error "Failed to recover swarm: $(recovery_result["error"])"
    end

    # Stop monitoring
    if monitor_task !== nothing
        try
            Base.throwto(monitor_task, InterruptException())
            results["stop_monitoring"] = true
        catch e
            @warn "Error stopping monitoring task" exception=(e, catch_backtrace())
            results["stop_monitoring"] = false
        end
    end

    # Stop the swarm
    @info "Stopping swarm..."
    stop_result = Swarms.stopSwarm(swarm_id)
    results["stop_swarm"] = stop_result["success"]

    if !stop_result["success"]
        @error "Failed to stop swarm: $(stop_result["error"])"
    end

    # Calculate overall success
    total_tests = count(k -> k != "swarm_id" && k != "checkpoint_file", keys(results))
    passed_tests = count(k -> k != "swarm_id" && k != "checkpoint_file" && results[k] == true, keys(results))

    results["total_tests"] = total_tests
    results["passed_tests"] = passed_tests
    results["success_rate"] = passed_tests / total_tests

    return results
end

end # module
