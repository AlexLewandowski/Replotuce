function get_dict(; primary_metric_key = "returns", sweep_key = Nothing, sweep_val = Nothing)
    sweep_keys = keys(parsefile("imputation_config.toml")["sweep_args"])
    sweep_dict = Dict()
    key_list = []
    for key in sweep_keys
        if key != "seed"
            push!(key_list, key)
        end
    end
    for (r, ds, fs) in walkdir("results/data/")
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
            cand = mean(primary_metric)

            metric_keys = collect(keys(data["cb_dict"]))
            secondary_metric_keys = filter!(x -> x != primary_metric_key, metric_keys)

            sweep_param = []

            for key in sweep_keys
                if key != "seed"
                    push!(sweep_param, parsed[key])
                end
                if key == sweep_key
                    if parsed[key] == sweep_val
                        corr_key_val = true
                    end
                end
            end

            if corr_key_val == true
                info = Dict([
                    ("seed", parsed["seed"]),
                    ("settings", settings),
                    (primary_metric_key, primary_metric),
                ])
                for secondary_metric_key in secondary_metric_keys
                    info[secondary_metric_key] = mean(data["cb_dict"][secondary_metric_key])
                end
                push_dict!(sweep_dict, sweep_param, info)
            end

        end
    end
    return sweep_dict, key_list
end

function get_scores(; primary_metric_key = "returns", sweep_key = Nothing, sweep_val = Nothing)
    sweep_dict, key_list = get_dict(sweep_key = sweep_key, sweep_val = sweep_val)
    sweep_keys = collect(keys(sweep_dict))

    primary_dict = Dict()
    for key in sweep_keys
        infos = sweep_dict[key]
        sum_of_means = 0
        n = 0
        for info in infos
            sum_of_means += mean(info[primary_metric_key])
            n += 1
        end
        mean_of_means = sum_of_means / n
        push_dict!(primary_dict, mean_of_means, key)
    end
    primary_dict, sweep_dict, key_list
end



