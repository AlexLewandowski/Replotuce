import JLD2
import BSON
using Pkg.TOML


function get_config_data(results_dir)
    data_dir = joinpath(results_dir, "data")

    conf = readdir(results_dir)
    filter!(s -> occursin("config", s), conf)

    @assert length(conf) == 1

    config_file = joinpath(results_dir, conf[1])

    return config_file, data_dir
end

function get_titles_labels(metric_key, profiler_name, top_n)
    config_title = " (top " * string(top_n) * ", " * profiler_name * " configurations)"
    if metric_key == "rollout_returns"
        title = "Average return" #* config_title
        xlabel = "Number of gradient steps"
        ylabel = "Average return"
    elseif metric_key == "average_returns"
        title = "Average Return" #* config_title
        xlabel = "Number of gradient steps"
        ylabel = "Average return"
    elseif metric_key == "train_buffer_loss"
        title = "Training Buffer Loss"# * config_title
        xlabel = "Number of gradient steps"
        ylabel = "Training loss"
    elseif metric_key == "estimate_value"
        title = "Mean Estimated Value in Training Buffer"# * config_title
        xlabel = "Number of gradient steps"
        ylabel = "Estimated value"
    elseif metric_key == "estimate_startvalue"
        title = "Estimated Value at Start State"# * config_title
        xlabel = "Number of gradient steps"
        ylabel = "Estimated value"
    elseif metric_key == "mean_weights"
        title = "Mean of Recurrent Weights"# * config_title
        xlabel = "Number of gradient steps"
        ylabel = "Mean weight"
    elseif metric_key == "online_returns"
        title = "Online Return"# * config_title
        xlabel = "Number of gradient steps"
        ylabel = "Average return"
    elseif metric_key == "action_gap"
        title = "Average Action-Gap"# * config_title
        xlabel = "Number of gradient steps"
        ylabel = "Action gap"
    else
        title = metric_key
        xlabel = "Number of gradient steps"
        ylabel = metric_key
    end
    return title, xlabel, ylabel
end

function get_top_keys(score_dict, profiler, top_n, rev)
    k = collect(keys(score_dict))
    if length(profiler[1][1]) > 0
        top_keys = []
        for profile in profiler
            new_ks = copy(k)
            local_top_keys = []
            for setting in profile
                filter!(x -> x[setting[1]] == setting[2], new_ks)
            end
            for new_k in new_ks
                push!(local_top_keys, new_k)
            end
            println(rev)
            sort!(local_top_keys, by=x->score_dict[x][1][1], rev = rev)
            if length(local_top_keys) < top_n
                println("top_n is too high! top_n = " * string(top_n))
                println("This profile is: " * string(profile))
                println("And it only yields: " * string(length(local_top_keys)))
                throw("Error!!")
            end
            push!(top_keys, local_top_keys[1:top_n]...)
        end
    else
        sorted_keys = sort(k, by=x->score_dict[x][1][1], rev = rev)
        top_keys = sorted_keys[1:top_n]
    end

    return top_keys
end

function load_model(;
    results_dir = "_results/",
    primary_metric_key = "rollout_returns",
    top_n = 3,
    profiler = [[[]]],
    profiler_name = "all",
    AUC = false,
    MAX = false,
)
    sweep_dict, auc_score_dict, end_score_dict, max_score_dict, key_list, metric_keys =
        get_dicts(results_dir = results_dir)
    if AUC
        score_dict = auc_score_dict
    elseif MAX
        score_dict = max_score_dict
    else
        score_dict = end_score_dict
    end

    if typeof(profiler) == String
        config_file, _ = get_config_data(results_dir)
        vals = eval(TOML.parsefile(config_file)["sweep_args"][profiler])
        try
            vals = eval(Meta.parse(TOML.parsefile(config_file)["sweep_args"][profiler]))
        catch
            vals = eval(TOML.parsefile(config_file)["sweep_args"][profiler])
        end

        temp_profiler = []
        for val in vals
            entry = [[[profiler, val]]]
            append!(temp_profiler, entry)
        end
        profiler_name = profiler
        profiler = temp_profiler
    end

    println(profiler)

    filter!(x -> x != "xs", metric_keys)

    if primary_metric_key == "og_buffer_loss"
        rev = false
    else
        rev = true
    end

    score_dict = score_dict[primary_metric_key]
    top_keys = get_top_keys(score_dict, profiler, top_n, rev)

    key = top_keys[1]
    seed = 1
    path = sweep_dict[key][seed]["settings"]["parsed_args"]["_SAVE"]
    agent_num = string(100)
    return joinpath(path, "agent-"*agent_num*".bson")

end

function get_plots(;
    results_dir = "_results/",
    primary_metric_key = "rollout_returns",
    top_n = 3,
    profiler = [[[]]],
    profiler_name = "all",
    AUC = false,
    MAX = false,
)
    sweep_dict, auc_score_dict, end_score_dict, max_score_dict, key_list, metric_keys =
        get_dicts(results_dir = results_dir)
    if AUC
        score_dict = auc_score_dict
    elseif MAX
        score_dict = max_score_dict
    else
        score_dict = end_score_dict
    end

    if typeof(profiler) == String
        config_file, _ = get_config_data(results_dir)
        vals = eval(TOML.parsefile(config_file)["sweep_args"][profiler])
        try
            vals = eval(Meta.parse(TOML.parsefile(config_file)["sweep_args"][profiler]))
        catch
            vals = eval(TOML.parsefile(config_file)["sweep_args"][profiler])
        end

        temp_profiler = []
        for val in vals
            entry = [[[profiler, val]]]
            append!(temp_profiler, entry)
        end
        profiler_name = profiler
        profiler = temp_profiler
    end

    println(profiler)

    filter!(x -> x != "xs", metric_keys)

    if primary_metric_key == "og_buffer_loss"
        rev = false
    else
        rev = true
    end

    score_dict = score_dict[primary_metric_key]
    top_keys = get_top_keys(score_dict, profiler, top_n, rev)

    for metric_key in metric_keys
        title, xlabel, ylabel = get_titles_labels(metric_key, profiler_name, top_n)

        get_plot(
            sweep_dict = sweep_dict,
            score_dict = score_dict,
            key_list = key_list,
            metric_key = metric_key,
            title = title,
            xlabel = xlabel,
            ylabel = ylabel,
            results_dir = results_dir,
            primary_metric_key = primary_metric_key,
            profiler_name = profiler_name,
            top_keys = top_keys,
            top_n = top_n,
            rev = rev,
        )
    end
end

function get_dicts(; results_dir = "_results/")
    dict_path = joinpath(results_dir, "dicts.jld2")

    if isfile(dict_path)

        println(dict_path, " found and loaded")
        all_dicts = FileIO.load(dict_path)

        sweep_dict = all_dicts["sweep_dict"]
        end_score_dict = all_dicts["end_score_dict"]
        max_score_dict = all_dicts["max_score_dict"]
        auc_score_dict = all_dicts["auc_score_dict"]
        key_list = all_dicts["key_list"]
        metric_keys = all_dicts["metric_keys"]
    else
        config_file, data_dir = get_config_data(results_dir)
        sweep_keys = keys(parsefile(config_file)["sweep_args"])

        sweep_dict, key_list, metric_keys = gen_dict(
            sweep_keys = sweep_keys,
            data_dir = data_dir,
        )

        auc_score_dict = gen_scores(
            sweep_dict = sweep_dict,
            metric_keys = metric_keys,
            AUC = true,
            MAX = false,
        )

        end_score_dict = gen_scores(
            sweep_dict = sweep_dict,
            metric_keys = metric_keys,
            AUC = false,
            MAX = false,
        )

        max_score_dict = gen_scores(
            sweep_dict = sweep_dict,
            metric_keys = metric_keys,
            AUC = false,
            MAX = true,
        )

        JLD2.@save joinpath(dict_path) sweep_dict auc_score_dict end_score_dict max_score_dict key_list metric_keys
    end
    return sweep_dict, auc_score_dict, end_score_dict, max_score_dict, key_list, metric_keys
end
