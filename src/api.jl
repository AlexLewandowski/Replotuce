using JLD2: @save


function get_config_data(results_dir)
    data_dir = joinpath(results_dir, "data")

    conf = readdir(results_dir)
    filter!(i -> i[1:6] == "config", conf)

    @assert length(conf) == 1

    config_file = joinpath(results_dir, conf[1])

    return config_file, data_dir
end

function get_plots(;
    results_dir = "_results/",
    primary_metric_key = "rollout_returns",
    top_n = 3,
    profiler = [[[]]],
    AUC = true,
)
    sweep_dict, auc_score_dict, best_score_dict, key_list, metric_keys =
        get_dicts(results_dir = results_dir, primary_metric_key = primary_metric_key)
    if AUC
        score_dict = auc_score_dict
    else
        score_dict = best_score_dict
    end
    for metric_key in metric_keys
        get_plot(
            sweep_dict = sweep_dict,
            score_dict = score_dict,
            key_list = key_list,
            metric_key = metric_key,
            results_dir = results_dir,
            primary_metric_key = primary_metric_key,
            profiler = profiler,
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
        best_score_dict = all_dicts["best_score_dict"]
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
        )

        best_score_dict = gen_scores(
            sweep_dict = sweep_dict,
            primary_metric_key = primary_metric_key,
            AUC = false,
        )

        @save joinpath(dict_path) sweep_dict auc_score_dict best_score_dict key_list metric_keys
    end
    return sweep_dict, auc_score_dict, best_score_dict, key_list, metric_keys
end
