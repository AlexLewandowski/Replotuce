function get_styles(n)
    lines = Plots.supported_styles()
    L = length(lines)
    styles = []
    for i = 1:n
        styles = vcat(styles, lines[1+i%L])
    end
    return reshape(styles, 1, n)
end

function format_config(config)
    formatted_config = []
    for c in config
        if isa(c, Number)
            push!(formatted_config, round(c, sigdigits = 3))
        else
            push!(formatted_config, c)
        end
    end
    return formatted_config
end

function get_plot(;
    primary_dict,
    sweep_dict,
    key_list,
    results_dir,
    metric_key,
)
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
        formatted_config = format_config(config)

        labels = push!(labels, formatted_config)

        info_dicts = sweep_dict[config]
        data = []
        for info_dict in info_dicts
            push!(data, info_dict[metric_key])
        end

        N = size(data)[1]

        stacked_data = hcat(data...)

        y_data = mean(stacked_data, dims = 2)
        σ = 1.96 * std(stacked_data, dims = 2) / sqrt(N)

        push!(y_to_plot, y_data)
        push!(σs, σ)
    end

    T = length(y_to_plot[1])

    print(labels)

    key_list = map(x -> *(x, " = "), key_list)
    labels = map(x -> join(map(join, collect(zip(key_list, x))), ", "), labels)
    labels = reshape(labels, 1, :)

    println(labels)

    fnt = Plots.font("Helvetica", 10)
    legend_fnt = Plots.font("Helvetica", 7)
    default(titlefont=fnt, guidefont=fnt, tickfont=fnt, legendfont=legend_fnt)

    plot(
        1:T,
        y_to_plot,
        ribbon = σs,
        fillalpha = 0.5,
        label = labels,
        linestyle = get_styles(top_n),
        title = "Average Return over number of policy improvements",
        legend = :topleft,
        #foreground_color_legend = nothing,
        background_color_legend = nothing,
    )

    xlabel!("Number of Policy Improvements")
    ylabel!("Average Return")
    mkpath(results_dir*"plots/")
    savefig(results_dir*"plots/"*metric_key*".pdf")

end

