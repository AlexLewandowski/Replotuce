using JLD2: @save
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
        title = "Average return" * config_title
        xlabel = "Number of gradient steps"
        ylabel = "Average return"
    elseif metric_key == "train_buffer_loss"
        title = "Training buffer loss" * config_title
        xlabel = "Number of gradient steps"
        ylabel = "Training loss"
    elseif metric_key == "estimate_value"
        title = "Estimated value" * config_title
        xlabel = "Number of gradient steps"
        ylabel = "Estimated value"
    elseif metric_key == "mean_weights"
        title = "Mean weights" * config_title
        xlabel = "Number of gradient steps"
        ylabel = "Mean weights"
    elseif metric_key == "online_returns"
        title = "Average return" * config_title
        xlabel = "Number of gradient steps"
        ylabel = "Average return"
    end

    return title, xlabel, ylabel
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
        get_dicts(results_dir = results_dir, primary_metric_key = primary_metric_key)
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
            profiler = profiler,
            profiler_name = profiler_name,
            top_n = top_n,
        )
    end
end

function get_dicts(; results_dir = "_results/", primary_metric_key = "rollout_returns")
    dict_path = joinpath(results_dir, "dicts.jld2")

    if isfile(dict_path)

        println(dict_path, " found and loaded")
        all_dicts = load(dict_path)

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
            primary_metric_key = primary_metric_key,
        )

        auc_score_dict = gen_scores(
            sweep_dict = sweep_dict,
            primary_metric_key = primary_metric_key,
            AUC = true,
            MAX = false,
        )

        end_score_dict = gen_scores(
            sweep_dict = sweep_dict,
            primary_metric_key = primary_metric_key,
            AUC = false,
            MAX = false,
        )

        max_score_dict = gen_scores(
            sweep_dict = sweep_dict,
            primary_metric_key = primary_metric_key,
            AUC = false,
            MAX = true,
        )

        @save joinpath(dict_path) sweep_dict auc_score_dict end_score_dict max_score_dict key_list metric_keys
    end
    return sweep_dict, auc_score_dict, end_score_dict, max_score_dict, key_list, metric_keys
end
