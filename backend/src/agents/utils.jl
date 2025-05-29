using .CommonTypes: InstantiatedTool, InstantiatedStrategy, StrategyBlueprint, ToolBlueprint

function deserialize_object(object_type::DataType, data::Dict{String, Any})
    expected_fields = fieldnames(object_type)
    provided_fields = Symbol.(keys(data))

    unexpected_fields = setdiff(provided_fields, expected_fields)
    missing_fields = setdiff(expected_fields, provided_fields)

    if !isempty(missing_fields)
        @warn "Missing fields in data: $(missing_fields)"
    end
    if !isempty(unexpected_fields)
        @warn "Unexpected fields in data: $(unexpected_fields)"
    end

    #@info "Deserializing object of type $(object_type) with data: $(data)"
    symbolic_data = Dict(Symbol(k) => v for (k, v) in data)
    return object_type(; symbolic_data...)
end

function instantiate_tool(blueprint::ToolBlueprint)::InstantiatedTool
    if !haskey(Tools.TOOL_REGISTRY, blueprint.name)
        error("Tool '$(blueprint.name)' is not registered.")
    end

    tool_spec = Tools.TOOL_REGISTRY[blueprint.name]

    tool_config = deserialize_object(tool_spec.config_type, blueprint.config_data)

    return InstantiatedTool(tool_spec.execute, tool_config, tool_spec.metadata)
end


function instantiate_strategy(blueprint::StrategyBlueprint)::InstantiatedStrategy
    if !haskey(Strategies.STRATEGY_REGISTRY, blueprint.name)
        error("Strategy '$(blueprint.name)' is not registered.")
    end

    strategy_spec = Strategies.STRATEGY_REGISTRY[blueprint.name]

    strategy_config = deserialize_object(strategy_spec.config_type, blueprint.config_data)

    return InstantiatedStrategy(strategy_spec.run, strategy_config)
end