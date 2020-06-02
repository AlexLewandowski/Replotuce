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
    key_list = collect(keys(config))
    for key in key_list
        val = config[key]
        if isa(val, Number)
            val = round(val, sigdigits = 3)
        end
        push!(formatted_config, string(key)*"="*string(val))
    end
    return join(formatted_config, ",")
end

function get_plot(;
    score_dict,
    sweep_dict,
    key_list,
    results_dir,
    metric_key,
    primary_metric_key,
    profiler::Array = [[[]]],
    top_n = 3,
)
    if length(profiler[1][1]) > 0
        reverse_score_list = Dict(value => key for (key, value) in score_dict)
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
        config = score_dict[score]
        if length(config) > 1
            println("There are multiple configurations with the same score: ", config)
            println(score)
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
        σ =  1.96*std(stacked_data, dims = 2) / sqrt(N)

        if metric_key == primary_metric_key
            print(format_config(config))
            print(" | "*string(y_data[end]))
            println(" | "*string(σ[end]))
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
    mkpath(results_dir * "plots/")
    savefig(results_dir * "plots/" * metric_key * ".pdf")

end
