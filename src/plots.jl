function get_styles(n)
    lines = Plots.supported_styles()[2:end]
    L = length(lines)
    styles = []
    for i = 1:n
        styles = vcat(styles, lines[1+i%L])
    end
    return reshape(styles, 1, n)
end

function get_markers(n)
    markers = Plots.supported_markers()[3:end]
    L = length(markers)
    styles = []
    for i = 1:n
        styles = vcat(styles, markers[1+i%L])
    end
    return reshape(styles, 1, n)
end

function format_config(config, join_str = ",")
    formatted_config = []
    key_list = collect(keys(config))
    for key in key_list
        if key == "lsr"
        else
            val = config[key]
            if isa(val, Union{AbstractFloat,Int})
                val = round(val, sigdigits = 3)
            end
            if string(key) == "predict_window"
                key = "temporal_window"
                val += 1
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
    profiler_name,
    top_keys,
    top_n = 3,
    higher_is_better = true,
    X_lim = 1,
)

    num_plots = length(top_keys)

    y_to_plot, σs, xs, labels = get_summary(
        sweep_dict = sweep_dict,
        score_dict = score_dict,
        key_list = key_list,
        metric_key = metric_key,
        title = title,
        xlabel = xlabel,
        ylabel = ylabel,
        results_dir = results_dir,
        primary_metric_key = primary_metric_key,
        profiler_name = profiler_name,
        top_keys = top_keys,
        top_n = top_n,
        higher_is_better = higher_is_better,
        X_lim = X_lim,
    )

    fnt = Plots.font("Helvetica", 10)
    legend_fnt = Plots.font("Helvetica", 7)
    default(titlefont = fnt, guidefont = fnt, tickfont = fnt, legendfont = legend_fnt)

    plot(
        xs,
        y_to_plot,
        ribbon = σs,
        fillalpha = 0.5,
        label = labels,
        linestyle = get_styles(num_plots),
        marker = get_markers(num_plots),
        title = title,
        xlims = (0,Inf),
        ylims = [-Inf,Inf],
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

function get_summary(;
    score_dict,
    sweep_dict,
    key_list,
    results_dir,
    metric_key,
    title,
    xlabel,
    ylabel,
    primary_metric_key,
    profiler_name,
    top_keys,
    top_n = 3,
    higher_is_better = true,
    X_lim = 1.0,
)

    y_to_plot = []
    σs = []
    labels = []

    xs = nothing
    for key in top_keys
        score = score_dict[key][1][1]
        config = key

        standard_dev = score_dict[key][1][2]
        formatted_config = format_config(config)

        labels = push!(labels, formatted_config)

        info_dicts = sweep_dict[config]
        data = []
        for info_dict in info_dicts
            ys = map(x-> x[1], info_dict[metric_key])
            push!(data, ys)
        end

        xs = map(x-> x[2], info_dicts[1][metric_key])
        L = Int(floor(length(xs)*X_lim))
        xs = xs[1:L]

        N = size(data)[1]

        stacked_data = hcat(data...)

        y_data = mean(stacked_data, dims = 2)[1:L]
        σ = (1.96 * std(stacked_data, dims = 2) / sqrt(N))[1:L]

        if metric_key == primary_metric_key
            println(" | ", format_config(config, ", "), " | ")
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
    labels = reshape(labels, 1, :)
    xs[end] += 1
    return y_to_plot, σs, xs, labels
end
