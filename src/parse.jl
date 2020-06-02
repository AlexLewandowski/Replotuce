function gen_dict(;
    sweep_keys,
    data_dir,
    primary_metric_key,
    sweep_key = Nothing,
    sweep_val = Nothing,
)
    sweep_dict = Dict()
    key_list = []
    metric_keys_global = []

    for key in sweep_keys
        if key != "seed" && key != "uniqueID"
            push!(key_list, key)
        end
    end

    for (r, ds, fs) in walkdir(data_dir)
        if isempty(fs)
        else
            if sweep_key == Nothing
                corr_key_val = true
            else
                corr_key_val = false
            end

            data = load(string(r, "/", "data.jld2"))
            settings = load(string(r, "/", "settings.jld2"))
            parsed = data["parsed"]

            primary_metric = data["cb_dict"][primary_metric_key]

            metric_keys = collect(keys(data["cb_dict"]))
            metric_keys_global = copy(metric_keys)
            secondary_metric_keys = filter!(x -> x != primary_metric_key, metric_keys)

            sweep_param = Dict()

            for key in sweep_keys

                if key != "seed" && key != "uniqueID"
                    sweep_param[key] = parsed[key]
                end
                if key == sweep_key
                    if parsed[key] == sweep_val
                        corr_key_val = true
                    end
                end
            end

            if corr_key_val == true
                info = Dict([
                    ("settings", settings),
                    (primary_metric_key, primary_metric),
                ])
                for secondary_metric_key in secondary_metric_keys
                    info[secondary_metric_key] = data["cb_dict"][secondary_metric_key]
                end
                push_dict!(sweep_dict, sweep_param, info)
            end

        end
    end
    return sweep_dict, key_list, metric_keys_global
end

function gen_scores(; sweep_dict, primary_metric_key = "returns", AUC = false)
    sweep_keys = collect(keys(sweep_dict))
    score_dict = Dict()

    for key in sweep_keys
        infos = sweep_dict[key]
        per_seed = []
        for info in infos
            if AUC
                statistic = mean(info[primary_metric_key])
            else
                statistic = info[primary_metric_key][end]
            end
            per_seed = push!(per_seed, statistic)
        end
        mean_per_seed = mean(per_seed)
        std_per_seed = std(per_seed)
        push_dict!(score_dict, mean_per_seed, key)
    end
    return score_dict
end
