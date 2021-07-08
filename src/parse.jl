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

function stack_data(sweep_dict, config_key, metric_key)
    L = length(sweep_dict[config_key])
    [sweep_dict[config_key][i][metric_key] for i = 1:L]
end

function gen_scores(; sweep_dict, metric_keys, criteria = :auc, prop = 0.0)
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
                stat = info[metric_key]
                per_seed = push!(per_seed, info[metric_key])
                if any(isnan.(stat))
                    println("NaN in loss for metric_key: "*metric_key)
                end
            end
            per_seed_mat = hcat(per_seed...)
            L = size(per_seed_mat)[1]

            if criteria == :auc
                select_mat = [mean(trim(per_seed_mat[i, :], prop = prop)) for i = 1:L]
            elseif criteria == :max
                per_seed_mat_trimmed = [mean(trim(per_seed_mat[i, :], prop = prop)) for i = 1:L]
                ind = argmax(per_seed_mat_trimmed)
                select_mat = trim(per_seed_mat[ind, :], prop = prop)
            elseif criteria == :end
                select_mat = trim(per_seed_mat[end,:], prop = prop)
            end

            statistic = mean(select_mat)
            std_per_seed = std(select_mat)
            max_per_seed = maximum(select_mat)
            min_per_seed = minimum(select_mat)
            num_seeds = length(per_seed)
            mean_per_seed = mean(per_seed)
            se_per_seed = 1.96 * std_per_seed / sqrt(num_seeds)
            push_dict!(score_dict, key, [statistic, se_per_seed, max_per_seed, min_per_seed])
            all_score_dict[metric_key] =score_dict
        end
    end
    return all_score_dict
end
