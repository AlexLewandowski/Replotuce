module Replotuce

using Plots
import Pkg.TOML: parsefile
import FileIO
import StatsBase: mean, std


include("helper_functions.jl")
include("parse.jl")
include("plots.jl")


export get_results, get_dicts
include("api.jl")

end # module
