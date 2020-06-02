function get_config_data(results_dir)
    data_dir = results_dir * "data/"
    config_dir = results_dir * "settings/"

    conf = readdir(config_dir)
    filter!(i -> i[1:6] == "config", conf)

    @assert length(conf) == 1

    config_file = config_dir * conf[1]

    return config_file, data_dir
end

function get_plots(; results_dir = "_results/", primary_metric_key = "rollout_returns", top_n = 3, profiler = [])
    ENV["GKSwstype"] = "nul"
    sweep_dict, score_dict, key_list, metric_keys = get_dicts(results_dir = results_dir, primary_metric_key = primary_metric_key)
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
    config_file, data_dir = get_config_data(results_dir)
    sweep_keys = keys(parsefile(config_file)["sweep_args"])
    sweep_dict, key_list, metric_keys =
        gen_dict(sweep_keys = sweep_keys, data_dir = data_dir, primary_metric_key = primary_metric_key)
    score_dict = gen_scores(sweep_dict = sweep_dict, primary_metric_key = primary_metric_key)
    return sweep_dict, score_dict, key_list, metric_keys
end
