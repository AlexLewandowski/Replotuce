function get_styles(n)
    lines = Plots.supported_styles()
    L = length(lines)
    styles = []
    for i = 1:n
        styles = vcat(styles, lines[1+i%L])
    end
    return reshape(styles, 1, n)
end

function format_config(config, join_str=",")
    formatted_config = []
    key_list = collect(keys(config))
    for key in key_list
        val = config[key]
        if isa(val, Union{AbstractFloat, Int})
            val = round(val, sigdigits = 3)
        end
        push!(formatted_config, string(key)*"="*string(val))
    end
    return join(formatted_config, join_str)
end

function get_plot(;
    score_dict,
    sweep_dict,
    key_list,
    results_dir,
    metric_key,
    primary_metric_key,
    profiler = [[[]]],
    top_n = 3,
)
    println(profiler)
    if length(profiler[1][1]) > 0
        reverse_score_list = Dict(value[1] => key for (key, value) in score_dict)
        k = collect(keys(reverse_score_list))
        top_scores = []
        for profile in profiler
            new_ks = copy(k)
            local_top_scores = []
            for setting in profile
                filter!(x -> x[1][setting[1]] == setting[2], new_ks)
            end
            for new_k in new_ks
                push!(local_top_scores, reverse_score_list[new_k])
            end
            sort!(local_top_scores, rev=true)
            if length(local_top_scores) < top_n
                println("top_n is too high! top_n = " *string(top_n))
                println("This profile is: " *string(profile))
                println("And it only yields: " *string(length(local_top_scores)))
                throw("Error!!")
            end
            push!(top_scores, local_top_scores[1:top_n]...)
        end
    else
        sorted_scores = sort(collect(keys(score_dict)), rev = true)
        top_scores = sorted_scores[1:top_n]
    end

    y_to_plot = []
    σs = []
    labels = []

    for score in top_scores
        configs = score_dict[score]
        if length(configs) > 1
            println(score)
            println("There are multiple configurations with the same score: ", configs)
            println("Using only: ", configs[1][1])
        end

        config = configs[1][1]
        standard_dev = configs[1][2]
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
        σ =  1.96*std(stacked_data, dims = 2) / sqrt(N)

        if metric_key == primary_metric_key
            println(" | ",format_config(config, ", "), " | ")
            print(" | score:  ", score)
            print(" | score std err:  ", standard_dev)
            println()
            print(" | final performance: ", y_data[end])
            println(" | final std err: ", σ[end], " | ")
            println()
        end
        push!(y_to_plot, y_data)
        push!(σs, σ)
    end

    T = length(y_to_plot[1])

    labels = reshape(labels, 1, :)

    fnt = Plots.font("Helvetica", 10)
    legend_fnt = Plots.font("Helvetica", 7)
    default(titlefont = fnt, guidefont = fnt, tickfont = fnt, legendfont = legend_fnt)

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

    plots_dir = joinpath(results_dir, "plots")
    mkpath(plots_dir)

    fig_name = joinpath(plots_dir, metric_key*".pdf")
    savefig(fig_name)

end
