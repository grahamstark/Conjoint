using Dash
using DashBootstrapComponents
using DataFrames
using Formatting
using HTTP
using HttpCommon
using JSON3
using Logging, LoggingExtras
using Markdown
using Observables
using PlotlyJS
using StatsBase


const CJ_DATA = CSV.File( "data/amces.csv") |> DataFrame


