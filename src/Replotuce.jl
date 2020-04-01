module Replotuce

using Plots
import Pkg.TOML: parsefile
import FileIO: load
import StatsBase: mean, std

ENV["GKSwstype"] = "nul"

include("helper_functions.jl")

export get_dict
include("parse.jl")

export get_plots, get_plot
include("plots.jl")

end # module
