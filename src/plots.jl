function get_styles(n)
    lines = Plots.supported_styles()
    L = length(lines)
    styles = []
    for i = 1:n
        styles = vcat(styles, lines[1+i%L])
    end
    return reshape(styles, 1, n)
end

function get_plot(;primary_metric_key = "returns", sweep_key = Nothing, sweep_val = Nothing)
    primary_dict, sweep_dict, key_list =
        get_scores(primary_metric_key = primary_metric_key, sweep_key = sweep_key, sweep_val = sweep_val)
    sorted_scores = sort(collect(keys(primary_dict)), rev = true)

    top_n = 3
    top_scores = sorted_scores[1:top_n]
    println(top_scores)

    y_to_plot = []
    σs = []
    labels = []
    for score in top_scores
        config = primary_dict[score]
        if length(config) > 1
            print("There are multiple configurations with the same score: ", config)
            break
        end
        config = config[1]
        formatted_config = []
        for c in config
            if isa(c, Number)
                push!(formatted_config, round(c, sigdigits = 3))
            else
                push!(formatted_config, c)
            end
        end
        labels = push!(labels, formatted_config)
        primary_metrics = sweep_dict[config]
        data = []
        for primary_metric in primary_metrics
            push!(data, primary_metric[primary_metric_key])
        end
        N = size(data)[1]
        data = mean(hcat(data...), dims = 2)
        σ = 1.96 * std(hcat(data...), dims = 2) / sqrt(N)
        push!(y_to_plot, data)
        push!(σs, σ)
    end

    T = length(y_to_plot[1])
    key_list = map(x -> *(x, " = "), key_list)
    print(labels)
    labels = map(x -> join(map(join, collect(zip(key_list, x))), ", "), labels)
    labels = reshape(labels, 1, :)
    println(labels)
    plot(
        1:T,
        y_to_plot,
        ribbon = σs,
        fillalpha = 0.5,
        label = labels,
        linestyle = get_styles(top_n),
        title = "Average Return over number of policy improvements",
        legend = :bottomright,
    )
    xlabel!("Number of Policy Improvements")
    ylabel!("Average Return")
    savefig("results/plot.pdf")
end

function get_plots()
    sweep_keys = keys(parsefile("imputation_config.toml")["sweep_args"])
    get_plot(sweep_key = "loss", sweep_val = "policygradient")
end
