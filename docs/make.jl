using Conjoint
using Documenter

DocMeta.setdocmeta!(Conjoint, :DocTestSetup, :(using Conjoint); recursive=true)

makedocs(;
    modules=[Conjoint],
    authors="Graham Stark",
    repo="https://github.com/grahamstark/Conjoint.jl/blob/{commit}{path}#{line}",
    sitename="Conjoint.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://grahamstark.github.io/Conjoint.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/grahamstark/Conjoint.jl",
    devbranch="main",
)
