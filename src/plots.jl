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
    primary_metric_key,
    profiler_name,
    top_keys,
    top_n = 3,
    X_lim = 1,
    plot_results = false,
    print_summary = false,
)
    println("Plotting for metric key: ", metric_key)
    println()
    title, xlabel, ylabel, higher_is_better = get_metric_local(metric_key, profiler_name, top_n)

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
        print_summary = print_summary,
    )

    if plot_results
        # fnt = Plots.font("Helvetica", 10)
        # legend_fnt = Plots.font("Helvetica", 7)
        # default(titlefont = fnt, guidefont = fnt, tickfont = fnt, legendfont = legend_fnt)

        L = Int(floor(length(xs)*X_lim)) + 1
        y_to_plot_trunc = []
        σ_to_plot_trunc = []
        xs_trunc = xs[L:end]
        for (y, σ) in zip(y_to_plot, σs)
            push!(y_to_plot_trunc, y[L:end])
            push!(σ_to_plot_trunc, σ[L:end])
        end

        if sum(vcat([isnan.(y) for y in y_to_plot_trunc]...)) > 0
            println("Aborting - NaN in loss for metric_key: "*metric_key)
            return
        end

        plot(
            xs_trunc,
            y_to_plot_trunc,
            ribbon = σ_to_plot_trunc,
            fillalpha = 0.5,
            label = labels,
            linestyle = get_styles(num_plots),
            marker = get_markers(num_plots),
            title = title,
            xlims = (xs_trunc[1] - 1,xs_trunc[end]+1),
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
    higher_is_better,
    top_n = 3,
    X_lim = 1.0,
    print_summary = true,
)

    y_to_plot = []
    σs = []
    labels = []

    xs = nothing
    for key in top_keys

        formatted_config = format_config(key)
        labels = push!(labels, formatted_config)

        stacked_data = stack_data(sweep_dict, key, metric_key)

        metric_keys = collect(keys(sweep_dict[key][1]))
        X_key = metric_keys[occursin.("_metric_count", metric_keys)][1]
        xs = sweep_dict[key][1][X_key]

        N = length(stacked_data)

        y_data = mean(stacked_data)
        σ = (1.96 * std(stacked_data) / sqrt(N))

        score = score_dict[metric_key][key][1][1]
        standard_dev = score_dict[metric_key][key][1][2]
        if print_summary
            println(" | ", format_config(key, ", "), " | ")
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
    return y_to_plot, σs, xs, labels
end
