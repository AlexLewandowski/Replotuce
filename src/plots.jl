function get_styles(n)
    lines = Plots.supported_styles()
    L = length(lines)
    styles = []
    for i = 1:n
        styles = vcat(styles, lines[1+i%L])
    end
    return reshape(styles, 1, n)
end

function format_config(config, join_str = ",")
    formatted_config = []
    key_list = collect(keys(config))
    for key in key_list
        if key == "lr"
        else
            val = config[key]
            if isa(val, Union{AbstractFloat,Int})
                val = round(val, sigdigits = 3)
            end
            push!(formatted_config, string(key) * "=" * string(val))
        end
    end
    return join(formatted_config, join_str)
end

function get_plot(;
    score_dict,
    sweep_dict,
    key_list,
    results_dir,
    metric_key,
    title,
    xlabel,
    ylabel,
    primary_metric_key,
    profiler = [[[]]],
    profiler_name,
    top_n = 3,
)
    println(profiler)
    k = collect(keys(score_dict))
    if length(profiler[1][1]) > 0
        top_keys = []
        for profile in profiler
            new_ks = copy(k)
            local_top_keys = []
            for setting in profile
                filter!(x -> x[setting[1]] == setting[2], new_ks)
            end
            for new_k in new_ks
                push!(local_top_keys, new_k)
            end
            sort!(local_top_keys, by=x->score_dict[x][1][1], rev = true)
            if length(local_top_keys) < top_n
                println("top_n is too high! top_n = " * string(top_n))
                println("This profile is: " * string(profile))
                println("And it only yields: " * string(length(local_top_keys)))
                throw("Error!!")
            end
            push!(top_keys, local_top_keys[1:top_n]...)
        end
    else
        sorted_keys = sort(k, by=x->score_dict[x][1][1], rev = true)
        top_keys = sorted_keys[1:top_n]
    end

    num_lines = length(top_keys)

    y_to_plot = []
    σs = []
    labels = []

    for key in top_keys
        score = score_dict[key][1][1]
        config = key

        standard_dev = score_dict[key][1][2]
        formatted_config = format_config(config)

        println(config)
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

        if metric_key == primary_metric_key
            println(" | ", format_config(config, ", "), " | ")
            print(" | score:  ", score)
            print(" | score std err:  ", standard_dev)
            println()
            print(" | final performance: ", y_data[end])
            println(" | final std err: ", σ[end], " | ")
            println()
        end
        push!(y_to_plot, y_data[2:end])
        push!(σs, σ)
    end

    T = length(y_to_plot[1])

    labels = reshape(labels, 1, :)

    fnt = Plots.font("Helvetica", 10)
    legend_fnt = Plots.font("Helvetica", 7)
    default(titlefont = fnt, guidefont = fnt, tickfont = fnt, legendfont = legend_fnt)

    x = 1:T
    plot(
        100*x,
        y_to_plot,
        ribbon = σs,
        fillalpha = 0.5,
        label = labels,
        linestyle = get_styles(num_lines),
        title = title,
        legend = :topleft,
        background_color_legend = nothing,
    )

    xlabel!(xlabel)
    ylabel!(ylabel)

    plots_dir = joinpath(results_dir, "plots")
    mkpath(plots_dir)

    fig_name = joinpath(plots_dir, metric_key * "-" * profiler_name * ".pdf")
    savefig(fig_name)

end
