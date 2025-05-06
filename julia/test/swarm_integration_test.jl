"""
    swarm_integration_test.jl

Integration tests for the Swarms module.
"""

using Test
using Random
using Statistics

# Add the parent directory to the load path
push!(LOAD_PATH, joinpath(@__DIR__, ".."))

# Import the modules
include("../src/swarm/SwarmBase.jl")
include("../src/swarm/Swarms.jl")

using .SwarmBase
using .Swarms

# Test functions
function test_functions()
    # Define test functions
    sphere(x) = sum(x.^2)
    rastrigin(x) = 10 * length(x) + sum(x.^2 - 10 * cos.(2π * x))
    rosenbrock(x) = sum(100 * (x[2:end] - x[1:end-1].^2).^2 + (x[1:end-1] - 1).^2)

    return Dict(
        "sphere" => sphere,
        "rastrigin" => rastrigin,
        "rosenbrock" => rosenbrock
    )
end

# Test all algorithms on a simple problem
function test_all_algorithms()
    println("Testing all algorithms on a simple problem...")

    # Define a simple problem
    dimensions = 10
    bounds = [(-5.0, 5.0) for _ in 1:dimensions]
    funcs = test_functions()

    # Create optimization problem
    problem = OptimizationProblem(
        dimensions,
        bounds,
        funcs["sphere"];
        is_minimization = true
    )

    # Define algorithms to test
    algorithms = [
        ("PSO", SwarmPSO(particles=30, max_iterations=100)),
        ("DE", SwarmDE(population=30, max_iterations=100)),
        ("GWO", SwarmGWO(wolves=30, max_iterations=100)),
        ("ACO", SwarmACO(ants=30, max_iterations=100)),
        ("GA", SwarmGA(population=30, max_iterations=100)),
        ("WOA", SwarmWOA(whales=30, max_iterations=100)),
        ("DEPSO", SwarmDEPSO(population=30, max_iterations=100))
    ]

    # Test each algorithm
    results = Dict()

    for (name, algorithm) in algorithms
        println("  Testing $name...")
        try
            # Set random seed for reproducibility
            Random.seed!(42)

            # Run optimization
            result = optimize(problem, algorithm)

            # Store results
            results[name] = result

            # Print results
            println("    Best fitness: $(result.best_fitness)")
            println("    Evaluations: $(result.evaluations)")

            # Test that the result is reasonable
            @test result.best_fitness < 1.0
            @test length(result.best_position) == dimensions
            @test length(result.convergence_curve) > 0
            @test result.success == true
        catch e
            println("    Error: $e")
            @test false
        end
    end

    return results
end

# Test swarm lifecycle management
function test_swarm_lifecycle()
    println("Testing swarm lifecycle management...")

    # Create a swarm configuration
    config = SwarmConfig(
        "Test Swarm",
        SwarmPSO(),
        "test",
        Dict("max_iterations" => 100)
    )

    # Create the swarm
    create_result = Swarms.create_swarm(config)
    @test create_result["success"] == true
    swarm_id = create_result["id"]
    println("  Created swarm: $swarm_id")

    # Get the swarm
    swarm = Swarms.getSwarm(swarm_id)
    @test swarm !== nothing
    @test swarm.name == "Test Swarm"
    @test swarm.status == Swarms.CREATED

    # Start the swarm
    start_result = Swarms.startSwarm(swarm_id)
    @test start_result["success"] == true
    println("  Started swarm")

    # Wait a moment for the swarm to start
    sleep(1)

    # Get swarm status
    status_result = Swarms.getSwarmStatus(swarm_id)
    @test status_result["success"] == true
    @test status_result["data"]["status"] == "RUNNING"
    println("  Swarm status: $(status_result["data"]["status"])")

    # Stop the swarm
    stop_result = Swarms.stopSwarm(swarm_id)
    @test stop_result["success"] == true
    println("  Stopped swarm")

    # Wait a moment for the swarm to stop
    sleep(1)

    # Get swarm status again
    status_result = Swarms.getSwarmStatus(swarm_id)
    @test status_result["success"] == true
    @test status_result["data"]["status"] == "STOPPED"
    println("  Swarm status: $(status_result["data"]["status"])")

    return swarm_id
end

# Test agent membership
function test_agent_membership(swarm_id)
    println("Testing agent membership...")

    # Add an agent to the swarm
    agent_id = "test-agent-" * string(rand(1000:9999))
    add_result = Swarms.addAgentToSwarm(swarm_id, agent_id)
    @test add_result["success"] == true
    println("  Added agent: $agent_id")

    # Get the swarm
    swarm = Swarms.getSwarm(swarm_id)
    @test agent_id in swarm.agent_ids

    # Remove the agent from the swarm
    remove_result = Swarms.removeAgentFromSwarm(swarm_id, agent_id)
    @test remove_result["success"] == true
    println("  Removed agent: $agent_id")

    # Get the swarm again
    swarm = Swarms.getSwarm(swarm_id)
    @test !(agent_id in swarm.agent_ids)

    return agent_id
end

# Test shared state
function test_shared_state(swarm_id)
    println("Testing shared state...")

    # Update shared state
    update_result = Swarms.updateSharedState!(swarm_id, "test_key", "test_value")
    @test update_result["success"] == true
    println("  Updated shared state: test_key = test_value")

    # Get shared state
    value = Swarms.getSharedState(swarm_id, "test_key")
    @test value == "test_value"
    println("  Retrieved shared state: test_key = $value")

    # Update shared state with a complex value
    complex_value = Dict("a" => 1, "b" => [1, 2, 3], "c" => Dict("d" => 4))
    update_result = Swarms.updateSharedState!(swarm_id, "complex_key", complex_value)
    @test update_result["success"] == true
    println("  Updated shared state with complex value")

    # Get complex shared state
    value = Swarms.getSharedState(swarm_id, "complex_key")
    @test value["a"] == 1
    @test value["b"] == [1, 2, 3]
    @test value["c"]["d"] == 4
    println("  Retrieved complex shared state successfully")
end

# Test task allocation
function test_task_allocation(swarm_id, agent_id)
    println("Testing task allocation...")

    # Add the agent back to the swarm
    add_result = Swarms.addAgentToSwarm(swarm_id, agent_id)
    @test add_result["success"] == true
    println("  Added agent: $agent_id")

    # Allocate a task
    task = Dict("type" => "test_task", "data" => "test_data")
    allocate_result = Swarms.allocateTask(swarm_id, task)
    @test allocate_result["success"] == true
    task_id = allocate_result["task_id"]
    println("  Allocated task: $task_id")

    # Claim the task
    claim_result = Swarms.claimTask(swarm_id, task_id, agent_id)
    @test claim_result["success"] == true
    println("  Claimed task")

    # Complete the task
    result = Dict("status" => "completed", "result" => "test_result")
    complete_result = Swarms.completeTask(swarm_id, task_id, agent_id, result)
    @test complete_result["success"] == true
    println("  Completed task")

    # Get swarm metrics
    metrics_result = Swarms.getSwarmMetrics(swarm_id)
    @test metrics_result["success"] == true
    @test metrics_result["data"]["task_stats"]["completed"] >= 1
    println("  Task statistics: $(metrics_result["data"]["task_stats"])")
end

# Test coordination
function test_coordination(swarm_id)
    println("Testing coordination...")

    # Add multiple agents to the swarm
    agents = []
    for i in 1:3
        agent_id = "test-agent-" * string(rand(1000:9999))
        add_result = Swarms.addAgentToSwarm(swarm_id, agent_id)
        @test add_result["success"] == true
        push!(agents, agent_id)
    end
    println("  Added $(length(agents)) agents")

    # Elect a leader
    elect_result = Swarms.electLeader(swarm_id)
    @test elect_result["success"] == true
    leader_id = elect_result["leader_id"]
    println("  Elected leader: $leader_id")

    # Check that the leader is stored in shared state
    leader = Swarms.getSharedState(swarm_id, "leader_id")
    @test leader == leader_id

    # Remove the leader and check that a new one is elected
    remove_result = Swarms.removeAgentFromSwarm(swarm_id, leader_id)
    @test remove_result["success"] == true
    println("  Removed leader")

    # Check that leader_id is now null in shared state
    leader = Swarms.getSharedState(swarm_id, "leader_id")
    @test leader === nothing

    # Clean up
    for agent_id in agents
        if agent_id != leader_id  # Leader was already removed
            remove_result = Swarms.removeAgentFromSwarm(swarm_id, agent_id)
            @test remove_result["success"] == true
        end
    end
    println("  Removed all agents")
end

# Test fault tolerance
function test_fault_tolerance(swarm_id)
    println("Testing fault tolerance...")

    # Create a fault tolerant swarm
    ft_swarm = Swarms.FaultTolerantSwarm(
        swarm_id,
        checkpoint_interval = 5,
        max_failures = 2
    )
    println("  Created fault tolerant swarm")

    # Create a checkpoint
    checkpoint_result = Swarms.checkpoint_swarm(ft_swarm)
    @test checkpoint_result["success"] == true
    println("  Created checkpoint: $(checkpoint_result["checkpoint_file"])")

    # Start monitoring
    monitor_task = nothing
    try
        monitor_task = Swarms.monitor_swarm(ft_swarm, interval=1)
        println("  Started monitoring")
    catch e
        println("  Error starting monitoring: $e")
        @test false
    end

    # Wait a moment
    sleep(2)

    # Test recovery
    recovery_result = Swarms.recover_swarm(ft_swarm)
    @test recovery_result["success"] == true
    println("  Recovered swarm")

    # Stop monitoring
    if monitor_task !== nothing
        try
            Base.throwto(monitor_task, InterruptException())
            println("  Stopped monitoring")
        catch e
            println("  Error stopping monitoring: $e")
        end
    end
end

# Test security
function test_security(swarm_id)
    println("Testing security...")

    # Create a security policy
    policy = Swarms.SwarmSecurityPolicy(
        authentication_required = true,
        encryption_required = false
    )
    println("  Created security policy")

    # Create a secure swarm
    secure_swarm = Swarms.SecureSwarm(swarm_id, policy)
    println("  Created secure swarm")

    # Initialize security
    init_result = Swarms.initialize_security(secure_swarm)
    @test init_result["success"] == true
    println("  Initialized security")

    # Add an agent
    agent_id = "test-agent-" * string(rand(1000:9999))
    add_result = Swarms.addAgentToSwarm(swarm_id, agent_id)
    @test add_result["success"] == true
    println("  Added agent: $agent_id")

    # Authenticate the agent
    credentials = Dict("key" => "secret-key")
    auth_result = Swarms.authenticate_agent(secure_swarm, agent_id, credentials)
    @test auth_result["success"] == true
    token = auth_result["token"]
    println("  Authenticated agent: $agent_id")

    # Authorize an action
    auth_result = Swarms.authorize_action(secure_swarm, agent_id, "read_state", token)
    @test auth_result["success"] == true
    @test auth_result["authorized"] == true
    println("  Authorized action: read_state")

    # Encrypt a message
    message = Dict("type" => "command", "action" => "explore")
    encrypted = Swarms.encrypt_message(message, "shared-key")
    @test encrypted["encrypted"] == true
    println("  Encrypted message")

    # Decrypt the message
    decrypted = Swarms.decrypt_message(encrypted, "shared-key")
    @test decrypted["type"] == "command"
    @test decrypted["action"] == "explore"
    println("  Decrypted message")

    # Clean up
    remove_result = Swarms.removeAgentFromSwarm(swarm_id, agent_id)
    @test remove_result["success"] == true
    println("  Removed agent: $agent_id")
end

# Test communication
function test_communication(swarm_id)
    println("Testing communication...")

    # Add multiple agents to the swarm
    agents = []
    for i in 1:5
        agent_id = "test-agent-" * string(rand(1000:9999))
        add_result = Swarms.addAgentToSwarm(swarm_id, agent_id)
        @test add_result["success"] == true
        push!(agents, agent_id)
    end
    println("  Added $(length(agents)) agents")

    # Create a hierarchical communication pattern
    pattern = Swarms.HierarchicalPattern(swarm_id, levels=2, branching_factor=2)
    println("  Created hierarchical communication pattern")

    # Set up the pattern
    setup_result = Swarms.setup_communication_pattern(swarm_id, pattern)
    @test setup_result["success"] == true
    println("  Set up communication pattern")

    # Send a message
    message = Dict("type" => "command", "action" => "explore", "direction" => "down")
    send_result = Swarms.send_message(swarm_id, agents[1], message, pattern)
    @test send_result["success"] == true
    println("  Sent message")

    # Clean up
    for agent_id in agents
        remove_result = Swarms.removeAgentFromSwarm(swarm_id, agent_id)
        @test remove_result["success"] == true
    end
    println("  Removed all agents")
end

# Run all tests
function run_all_tests()
    println("Running all integration tests...")

    # Test all algorithms
    algorithm_results = test_all_algorithms()

    # Test swarm lifecycle
    swarm_id = test_swarm_lifecycle()

    # Test agent membership
    agent_id = test_agent_membership(swarm_id)

    # Test shared state
    test_shared_state(swarm_id)

    # Test task allocation
    test_task_allocation(swarm_id, agent_id)

    # Test coordination
    test_coordination(swarm_id)

    # Test fault tolerance
    test_fault_tolerance(swarm_id)

    # Test security
    test_security(swarm_id)

    # Test communication
    test_communication(swarm_id)

    println("All tests completed successfully!")
end

# Run the tests
run_all_tests()
