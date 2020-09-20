module Replotuce

using Plots
import Pkg.TOML: parsefile
import FileIO
import StatsBase: mean, std


include("helper_functions.jl")
include("parse.jl")
include("plots.jl")


export get_plots, get_dicts, get_summaries
include("api.jl")

end # module
