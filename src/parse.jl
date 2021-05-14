function gen_dict(;
    sweep_keys,
    data_dir,
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

            data = FileIO.load(string(r, "/", "data.jld2"))
            settings = FileIO.load(string(r, "/", "settings.jld2"))

            parsed = data["parsed"]

            if isempty(data[dict_name])
                @warn "Dictionary is empty: " dict_name
                break
            end

            metric_keys = collect(keys(data[dict_name]))

            metric_keys_global = copy(metric_keys)

            sweep_param = Dict()

            for key in sweep_keys
                if key != "seed" && key != "uniqueID"
                    sweep_param[key] = parsed[key]
                end
            end

            info = Dict([
                ("settings", settings),
                (metric_keys[1], data[dict_name][metric_keys[1]])
            ])
            for metric_key in metric_keys[2:end]
                info[metric_key] = data[dict_name][metric_key]
            end
            info["metric_keys"] = metric_keys
            push_dict!(sweep_dict, sweep_param, info)
        end
    end
    return sweep_dict, key_list, metric_keys_global
end

function gen_scores(; sweep_dict, metric_keys, AUC = false, MAX = false)
    sweep_keys = collect(keys(sweep_dict))
    all_score_dict = Dict()

    for key in sweep_keys
        metric_keys = sweep_dict[key][1]["metric_keys"]
        for metric_key in metric_keys
            if metric_key in keys(all_score_dict)
                score_dict = all_score_dict[metric_key]
            else
                score_dict = Dict()
            end

            infos = sweep_dict[key]
            per_seed = []
            for info in infos
                stat = map(x-> x[1], info[metric_key])
                per_seed = push!(per_seed, stat)
                if sum(isnan.(stat)) != 0
                    println("NaN in loss for metric_key: "*metric_key)
                end
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
            all_score_dict[metric_key] =score_dict
        end
    end
    return all_score_dict
end
