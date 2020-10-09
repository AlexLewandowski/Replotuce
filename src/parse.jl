function gen_dict(;
    sweep_keys,
    data_dir,
    sweep_key = Nothing,
    sweep_val = Nothing,
    dict_name = "online_dict"
)
    sweep_dict = Dict()
    key_list = []
    metric_keys_global = []

    for key in sweep_keys
        if key != "seed" && key != "uniqueID"
            push!(key_list, key)
        end
    end

    if !isdir(data_dir)
        @error data_dir " does not exist!"
    end

    for (r, ds, fs) in walkdir(data_dir)
        if isempty(fs)
        else
            if sweep_key == Nothing
                corr_key_val = true
            else
                corr_key_val = false
            end

            data = FileIO.load(string(r, "/", "data.jld2"))
            settings = FileIO.load(string(r, "/", "settings.jld2"))

            parsed = data["parsed"]


            metric_keys = collect(keys(data[dict_name]))
            metric_keys_global = copy(metric_keys)

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
                info = Dict[]
                info = Dict([
                    ("settings", settings),
                    (metric_keys[1], data[dict_name][metric_keys[1]])
                ])
                for metric_key in metric_keys[2:end]
                    info[metric_key] = data[dict_name][metric_key]
                end
                push_dict!(sweep_dict, sweep_param, info)
                # close(data)
                # close(settings)
            end
        end
    end
    return sweep_dict, key_list, metric_keys_global
end

function gen_scores(; sweep_dict, metric_keys, AUC = false, MAX = false)
    sweep_keys = collect(keys(sweep_dict))
    all_score_dict = Dict()

    for metric_key in metric_keys
        score_dict = Dict()

        for key in sweep_keys
            infos = sweep_dict[key]
            per_seed = []
            for info in infos
                stat = map(x-> x[1], info[metric_key])
                per_seed = push!(per_seed, stat)
            end
            per_seed_mat = hcat(per_seed...)
            if AUC
                statistic = mean(per_seed_mat)
                std_per_seed = std(mean(per_seed_mat, dims = 1))
                max_per_seed = maximum(mean(per_seed_mat, dims = 1))
                min_per_seed = minimum(mean(per_seed_mat, dims = 1))
            elseif MAX
                ind = argmax(mean(per_seed_mat, dims = 2))[1]
                statistic = mean(per_seed_mat[ind, :])
                std_per_seed = std(per_seed_mat[ind, :])
                max_per_seed = maximum(per_seed_mat[ind, :])
                min_per_seed = minimum(per_seed_mat[ind, :])
            else
                statistic = mean(per_seed_mat[end, :])
                std_per_seed = std(per_seed_mat[end, :])
                max_per_seed = maximum(per_seed_mat[end, :])
                min_per_seed = minimum(per_seed_mat[end, :])
            end
            num_seeds = length(per_seed)
            mean_per_seed = mean(per_seed)
            se_per_seed = 1.96 * std_per_seed / sqrt(num_seeds)
            push_dict!(score_dict, key, [statistic, se_per_seed, max_per_seed, min_per_seed])
        end
        all_score_dict[metric_key] = score_dict
    end
    return all_score_dict
end
