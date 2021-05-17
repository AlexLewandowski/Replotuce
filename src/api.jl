import JLD2
import BSON
using Pkg.TOML


function get_config_data(results_dir)
    data_dir = joinpath(results_dir, "data")

    println(results_dir)
    results_dir = results_dir * "/settings"
    conf = readdir(results_dir)
    filter!(s -> occursin("config_", s), conf)
    ind = argmax(ctime.(results_dir .* conf))

    config_file = joinpath(results_dir, conf[ind])

    return config_file, data_dir
end

##
## Register metrics in this function
##

function get_metric_local(metric_key, profiler_name, top_n)
    config_title = " (top " * string(top_n) * ", " * profiler_name * " configurations)"

    higher_is_better = false

    if metric_key == "rollout_returns"
        title = "Average return" #* config_title
        xlabel = "Number of epochs"
        ylabel = "Average return"
        higher_is_better = true
    elseif metric_key == "average_returns"
        title = "Average Return" #* config_title
        xlabel = "Number of epochs"
        ylabel = "Average return"
        higher_is_better = true
    elseif metric_key == "estimate_value"
        title = "Mean Estimated Value in Training Buffer"# * config_title
        xlabel = "Number of epochs"
        ylabel = "Estimated value"
        higher_is_better = true
    elseif metric_key == "train_buffer_loss"
        title = "Training Buffer Loss"# * config_title
        xlabel = "Number of epochs"
        ylabel = "Training loss"
    elseif metric_key == "estimate_startvalue"
        title = "Estimated Value at Start State"# * config_title
        xlabel = "Number of epochs"
        ylabel = "Estimated value"
        higher_is_better = true
    elseif metric_key == "mean_weights"
        title = "Mean of Recurrent Weights"# * config_title
        xlabel = "Number of epochs"
        ylabel = "Mean weight"
    elseif metric_key == "online_returns"
        title = "Online Return"# * config_title
        xlabel = "Number of epochs"
        ylabel = "Average return"
        higher_is_better = true
    elseif metric_key == "action_gap"
        title = "Average Action-Gap"# * config_title
        xlabel = "Number of epochs"
        ylabel = "Action gap"
    elseif occursin("accuracy", metric_key)
        title = metric_key
        xlabel = "Number of epochs"
        ylabel = metric_key
        higher_is_better = true
    else
        title = metric_key
        xlabel = "Number of epochs"
        ylabel = metric_key
    end
    return title, xlabel, ylabel, higher_is_better
end

function get_top_keys(score_dict, profiler, top_n, higher_is_better)
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
            sort!(local_top_keys, by = x -> score_dict[x][1][1], rev = higher_is_better)
            if length(local_top_keys) < top_n
                println("top_n is too high! top_n = " * string(top_n))
                println("This profile is: " * string(profile))
                println("And it only yields: " * string(length(local_top_keys)))
                throw("Error!!")
            end
            push!(top_keys, local_top_keys[1:top_n]...)
        end
    else
        sorted_keys = sort(k, by = x -> score_dict[x][1][1], rev = higher_is_better)
        top_keys = sorted_keys[1:top_n]
    end

    return top_keys
end

function get_dicts(results_dir = "_results/", dict_name = "online_dict"; recompute = false)
    dict_path = joinpath(results_dir, dict_name * ".jld2")

    if isfile(dict_path) && !recompute
        println()
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

        sweep_dict, key_list, metric_keys =
            gen_dict(sweep_keys = sweep_keys, data_dir = data_dir, dict_name = dict_name)

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

function get_results(;
    results_dir = "_results/",
    primary_metric_key = "rollout_returns",
    plot_results = false,
    print_summary = false,
    top_n = 3,
    profiler = [[[]]],
    profiler_name = "all",
    AUC = false,
    MAX = false,
    dict_name = "online_dict",
    X_lim = 0.0,
)
    sweep_dict, auc_score_dict, end_score_dict, max_score_dict, key_list, metric_keys =
        get_dicts(results_dir, dict_name)
    if AUC
        score_dict = auc_score_dict
    elseif MAX
        score_dict = max_score_dict
    else
        score_dict = end_score_dict
    end

    if isempty(sweep_dict)
        @warn "The dictionary is empty: " dict_name
        return
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

    println("Profiling results based on: ", profiler)

    filter!(x -> x != "xs", metric_keys)
    println("Primary metric key before is: ", primary_metric_key)
    println("metric keys: ", metric_keys)
    if primary_metric_key ∉ metric_keys
        # primary_metric_key = 1
        primary_metric_key = "online_returns"
    end
    if typeof(primary_metric_key) <: Int
        primary_metric_key = metric_keys[primary_metric_key]
    end

    println("Primary metric key is: ", primary_metric_key)


    _, _, _, higher_is_better = get_metric_local(primary_metric_key, profiler_name, top_n)
    top_keys =
        get_top_keys(score_dict[primary_metric_key], profiler, top_n, higher_is_better)

    println()
    println("Dictionary being used: ", dict_name)
    println()
    for metric_key in metric_keys
        get_plot(
            sweep_dict = sweep_dict,
            score_dict = score_dict,
            key_list = key_list,
            metric_key = metric_key,
            results_dir = results_dir,
            primary_metric_key = primary_metric_key,
            profiler_name = profiler_name,
            top_keys = top_keys,
            top_n = top_n,
            X_lim = X_lim,
            plot_results = plot_results,
            print_summary = print_summary,
        )
    end
end
