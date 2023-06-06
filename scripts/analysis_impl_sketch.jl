

using CSV,DataFrames,GLM,CairoMakie,MixedModelsMakie

#=
ResponseID	ResponseSet	Name	ExternalDataReference	EmailAddress	IPAddress	Status	StartDate	EndDate	Finished

V1	V2	V3	V4	V5	V6	V7	V8	V9	V10
=#

function fs( d :: DataFrame ) :: Vector{Symbol}
    out = []
    for f in names(d)
        println( "testing $f")
        if ! isnothing(match(r"^F\-.*", f ))
            println( "$f matches")
            push!(out, Symbol(f))
        end
    end
    out
end


const NUM_TESTS_PER_USER = 5
const NUM_CANDITATES = 2
const NUM_QUESTIONS = 8

function parse_input( d :: DataFrame )
    groups = Dict()
    for r in eachrow( d )
        for t in 1:NUM_TESTS_PER_USER
            for c in 1:NUM_CANDITATES
                for q in 1:NUM_QUESTIONS
                    gcol = Symbol( "F-$t-$q"); 
                    qcol = Symbol( "F-$t-$c-$q")
                    group = r[gcol]
                    if ! ismissing(group)
                        var = r[qcol]
                        # println( "t=$t r=$r q=$q ;var=$var group=$group")
                        if haskey( groups, group )
                            push!( groups[group], var )
                        else
                            groups[group] = [var]                       
                        end
                    end
                end
            end
        end
    end
    for k in keys( groups )
        u = unique( groups[k])
        groups[k] = u
    end
    println( "got groups as $groups")
    nmissing = size(ind[ismissing.(ind."F-1-1"),:])[1]
    #
    # create output dataframe
    #
    no = (size( d )[1]-nmissing)*NUM_TESTS_PER_USER*NUM_CANDITATES
    out = DataFrame(
        user = fill( 0, no ),
        choice_set = fill( 0, no ),
        candidate = fill( 0, no ),
        bchoice = Array{Union{Bool,Missing}}( missing, no ),
        ichoice = Array{Union{Int,Missing}}( missing, no ),
    )
    for k in keys( groups )
        qs = groups[k]
        for q in qs
            sq = Symbol(q)
            out[!, sq] = zeros( no )
        end
    end
    # load the data
    rno = 0
    outcol = 0
    for r in eachrow( d )
        rno += 1
        # outcome of 1st test
        which = r[:"Q2.3"]
        if ! ismissing( which )
            println( "which = $which")
            out[outcol+1, :bchoice] = which == "1" ? true : false
            out[outcol+2, :bchoice] = which == "2" ? true : false
        end
        which = r[:"Q2.5_1"]
        if ! ismissing( which )
            out[outcol+1, :ichoice] = parse( Int, which )
        end
        which = r[:"Q2.5_2"]
        if ! ismissing( which )
            out[outcol+2, :ichoice] = parse( Int, which )
        end
        which = r[:"Q2.7"]
        if ! ismissing( which )
            println( "which = $which")
            out[outcol+3, :bchoice] = which == "1" ? true : false
            out[outcol+4, :bchoice] = which == "2" ? true : false
        end

        for t in 1:NUM_TESTS_PER_USER
            for c in 1:NUM_CANDITATES                
                println( "rno = $rno t=$t c=$c outcol=$outcol")                                   
                gcol = Symbol( "F-1-1"); 
                group = r[gcol]
                if ! ismissing(group)
                    outcol += 1
                    for q in 1:NUM_QUESTIONS
                        qcol = Symbol( "F-$t-$c-$q")
                        out[outcol,:user] = rno
                        out[outcol,:candidate] = c
                        out[outcol,:choice_set] = t                        
                        qcol = Symbol( "F-$t-$c-$q")
                        var = r[qcol]
                        out[outcol,var] = 1.0
                    end
                end
            end
        end
    end


    (groups, out)
end



function cofile_to_frame( name :: String ) :: Tuple
    d = DataFrame()
    ind = CSV.File( name; header=2 ) |> DataFrame
    vars = fs(ind)
    othervars = setdiff(Symbol.(names(ind)), vars )
    println( vars )
    ind = stack( ind, NOT(othervars) )
    variables = []
    
    groups = Symbol.(unique(ind[ .! isnothing.(match.(r"^F\-[0-9]\-[0-9]$",String.(ind.variable))),[:value]]))[:,1]

    for v in vars

    end

    println( "groups $groups")
    vars_by_groups = Dict{Symbol}{Vector{Symbol}}()
    nr = size(ind)[1]
    i = 0
    while i < nr
        i += 1
        println( "on row $i")
        r = ind[i,:]
        println( "looking at value $(r.value)")
        if Symbol(r.value) in groups
            println( "group $(r.value)")
            for j in 1:2
                i += 1
                v = ind[i,:]
                println( "variable $(v.value)")
            end
        end
    end
    d,ind
end
