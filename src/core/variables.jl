###############################################################################
#   Variable initialization and updating for all distirbuted OPF algorithms    #
###############################################################################

# Template for variable shared
"initialize shared variable dictionary"
function initialize_shared_variable(data::Dict{String, <:Any}, model_type::DataType, from::Int64 ,to::Vector{Int64}, dics_name::String="shared_variable", initialization_method::String="flat")
    bus_variables_name, branch_variables_name = variable_shared_names(model_type)
    shared_bus, shared_branch = get_shared_component(data, from)

    if initialization_method in ["previous", "previous_solution", "warm", "warm_start"]
        if !haskey(data, dics_name)
            error("no previous solutions exist to use warm start")
        else
            variables_dics = data[dics_name]
        end
    else
        variables_dics = Dict{String, Any}([
            string(area) => Dict{String, Any}(
                vcat(
                    [variable => Dict{String, Any}([string(idx) => initial_value(variable, initialization_method) for idx in shared_bus[area]]) for variable in bus_variables_name],
                    [variable => Dict{String, Any}([string(idx) => initial_value(variable, initialization_method) for idx in shared_branch[area]]) for variable in branch_variables_name]
                )
            )
        for area in to])
    end

    return variables_dics
end

function initialize_shared_variable(data::Dict{String, <:Any}, model_type::DataType, from::Int64 ,to::Int64, dics_name::String="shared_variable", initialization_method::String="flat")
    bus_variables_name, branch_variables_name = variable_shared_names(model_type)
    shared_bus, shared_branch = get_shared_component(data, from)

    initialize_shared_variable(data, model_type, from, [to], dics_name, initialization_method)
end

"""
    initial_value(data::Dict{String, <:Any}, var::String, idx::Int, initialization_method::String="flat")

assign initial value based on initialization method

# Arguments:
- variable::String : variable names
- initialization_method::String : ("flat", "previous_solution")
"""
function initial_value(variable::String, initialization_method::String="flat")::Float64
    if initialization_method in ["flat" , "flat_start"] && variable in ["vm", "w", "wr"]
        return 1
    else
        return 0
    end
end

"""
    initialize_all_variable(data::Dict{String, <:Any}, model_type::DataType)

return a dictionary contains all the problem variables. Can be used to store the last solution

# Arguments:
- data::Dict{String, <:Any} : dictionary contains case in PowerModel format
- model_type::DataType : power flow formulation (PowerModel type)
"""
function initialize_all_variable(data::Dict{String, <:Any}, model_type::DataType, dics_name::String="solution", initialization_method::String="flat")
    bus_variables_name, branch_variables_name, gen_variables_name = variable_names(model_type)

    if initialization_method in ["previous", "previous_solution", "warm", "warm_start"]
        if !haskey(data, dics_name)
            error("no previous solutions exist to use warm start")
        else
            all_variables = data[dics_name]
        end
    else
        all_variables = Dict{String, Dict}()
        for variable in bus_variables_name
            all_variables[variable] = Dict([idx => initial_value(variable, initialization_method) for idx in keys(data["bus"])])
        end
        for variable in branch_variables_name
            all_variables[variable] = Dict([idx => initial_value(variable, initialization_method) for idx in keys(data["branch"])])
        end
        for variable in gen_variables_name
            all_variables[variable] = Dict([idx => initial_value(variable, initialization_method) for idx in keys(data["gen"])])
        end
    end
    return all_variables
end

function initialize_solution!(data::Dict{String, <:Any}, model_type::DataType, dics_name::String="solution", initialization_method::String="flat")
    data["solution"] = initialize_all_variable(data, model_type, dics_name, initialization_method)
end

"return JuMP variable object from PowerModel object"
function _var(pm::AbstractPowerModel, key::String, idx::String)
    bus_variables_name, branch_variables_name, gen_variables_name = variable_names(typeof(pm))
    idx = parse(Int64,idx)
    if key in bus_variables_name || key in gen_variables_name
        var = _PM.var(pm, Symbol(key), idx)
    elseif key in branch_variables_name
        branch = _PM.ref(pm, :branch, idx)
        f_bus = branch["f_bus"]
        t_bus = branch["t_bus"]

        if key in ["pf", "qf"]
            var = _PM.var(pm, Symbol(key[1]),  (idx, f_bus, t_bus))
        elseif key in ["pt", "qt"]
            var = _PM.var(pm, Symbol(key[1]),  (idx, t_bus, f_bus))
        else
            var = _PM.var(pm, Symbol(key), (f_bus, t_bus))
        end
    end

    return var
end

"idinifiy the shared bus and branch variables names"
function variable_shared_names(model_type::DataType)
    if model_type <: Union{DCPPowerModel, DCMPPowerModel}
        return ["va"], ["pf"]
    elseif model_type <: NFAPowerModel
        return [], ["pf"]
    elseif model_type <: DCPLLPowerModel
        return ["va"], ["pf", "pt"]
    elseif model_type <: LPACCPowerModel
        return ["va", "phi"], ["pf", "pt", "qf", "qt", "cs"]
    elseif model_type <: ACPPowerModel
        return ["va", "vm"], ["pf", "pt", "qf", "qt"]
    elseif model_type <: ACRPowerModel
        return ["vr", "vi"], ["pf", "pt", "qf", "qt"]
    elseif model_type <: ACTPowerModel
        return ["w", "va"], ["pf", "pt", "qf", "qt", "wr", "wi"]
    elseif model_type <: Union{SOCWRPowerModel, SOCWRConicPowerModel, SDPWRMPowerModel, SparseSDPWRMPowerModel }
        return ["w"], ["pf", "pt", "qf", "qt", "wr", "wi"]
    elseif model_type <: QCRMPowerModel
        return ["vm", "va" , "w"], ["pf", "pt", "qf", "qt", "wr", "wi", "vv", "ccm", "cs", "si", "td"]
    else
        error("PowerModel type is not supported yet!")
    end
end

"idinifiy all the variables names"
function variable_names(model_type::DataType)
    if model_type <: Union{DCPPowerModel, DCMPPowerModel}
        return ["va"], ["pf"], ["pg"]
    elseif model_type <: NFAPowerModel
        return [], ["pf"], ["pg"]
    elseif model_type <: DCPLLPowerModel
        return ["va"], ["pf", "pt"], ["pg"]
    elseif model_type <: LPACCPowerModel
        return ["va", "phi"], ["pf", "pt", "qf", "qt", "cs"], ["pg", "qg"]
    elseif model_type <: ACPPowerModel
        return ["va", "vm"], ["pf", "pt", "qf", "qt"], ["pg", "qg"]
    elseif model_type <: ACRPowerModel
        return ["vr", "vi"], ["pf", "pt", "qf", "qt"], ["pg", "qg"]
    elseif model_type <: ACTPowerModel
        return ["w", "va"], ["pf", "pt", "qf", "qt", "wr", "wi"], ["pg", "qg"]
    elseif model_type <: Union{SOCWRPowerModel, SOCWRConicPowerModel, SDPWRMPowerModel, SparseSDPWRMPowerModel }
        return ["w"], ["pf", "pt", "qf", "qt", "wr", "wi"], ["pg", "qg"]
    elseif model_type <: QCRMPowerModel
        return ["vm", "va" , "w"], ["pf", "pt", "qf", "qt", "wr", "wi", "vv", "ccm", "cs", "si", "td"], ["pg", "qg"]
    elseif model_type <: AbstractPowerModel
        error("PowerModel type is not supported yet!")
    else
        error("model_type $model_type is not PowerModel type!")
    end
end