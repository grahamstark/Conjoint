#
# experiments with Conjoint marginal probabilities
#


# Graham, this is the dataframe of marginal probabilities of choice. 
# These can just be averaged (nb not summed) to give you the probability of choice of any bundle of different attributes. 


using 
    CairoMakie, 
    CSV, 
    DataFrames, 
    Measurements, 
    Mustache, 
    Parameters, 
    Pluto, 
    ScottishTaxBenefitModel

const MPROBS = CSV.File( "data/marginalprobabilities.csv" ) |> DataFrame
const CHANGE_BREAKS = [-0.5,-0.25,-0.1,-0.05,0,0.05,0.10,0.25,0.5]
const LIFE_BREAKS = [-5,-3,-1,0,1,3,5]

#=
feats = groupby( MPROBS, :feature )

for f in feats
    println(f.level)
end

struct F
    level  :: String
    weight :: Float64
end
=# 

@enum Diff neg zer pos oor

function ogap( v, n1, n2 )
    if !(n1 <= v <= n2)
        return (vl=oor,d1=-1,d2=-1)
    end
    @assert n1 <= n2
    if v ≈ 0
        return (vl=zero,d1=1,d2=0)
    end
    d0 = n1 - n2
    d1 = (v - (n2))/d0
    d2 = (n1 - v)/d0
    vl = if v ≈ 0
        zero
    elseif v < 0
        neg
    else
        pos
    end
    @assert d1+d2 ≈ 1
     ( vl=vl, d1=d1, d2=d2, n1=n1, n2=n2 )
end

function make_levels( feature::AbstractString, n :: Number ) # :: Vector{F}
    levels = feature == "Life.expectancy" ? LIFE_BREAKS : CHANGE_BREAKS
    println(levels)
    ln = size(levels)[1]
    @assert levels[begin] <= n <= levels[end]
    og = nothing
    for i in 2:ln
        og = ogap( n, levels[i-1],levels[i])
        println(og)
        if og.vl != oor
            break;
        end
    end
    @assert ! isnothing( og )
    og
end

const PCT_TMPLS = [mt"Unchanged.", mt"{{pn}} by {{pct}}%." ]
const CASE_TMPLS = [mt"Same number of cases", mt"{{pct}}% {{pn}} cases" ]
const LIFE_TMPLS = [mt"0 more or less years on average", mt"{{yrs}} {{pn}} year{{pl}} on average" ]

function find_range( feature :: AbstractString, n :: Number )
    tmpls = PCT_TMPLS
    more = "Increased"
    less = "Decreased"
    if feature == "Mental.health" 
        tmpls = CASE_TMPLS 
        more = "more"
        less = "fewer"
    elseif feature == "Life.expectancy"
        tmpls = LIFE_TMPLS
        more = "more"
        less = "fewer"
    end
    og = make_levels( feature, n )
    level1 = level2 = ""
    if og.vl == zero
        level1 = level2 = render( tmpls[1])
    else
        ml = og.vl == pos ? more : less
        if feature == "Life.expectancy"
            pl = abs( og.n1 ) > 1 ? "s" : ""
            s1 = abs( og.n1 )
            s2 = abs( og.n2 )
            level1 = render( tmpls[2], Dict(["yrs"=>s1, "pl"=>pl, "pn"=>ml ] ))
            pl = abs( og.n2 ) > 1 ? "s" : ""
            level2 = render( tmpls[2], Dict(["yrs"=>s2, "pl"=>pl, "pn"=>ml ] ))
        else
            s1 = "$(Int(abs(og.n1)*100))"
            s2 = "$(Int(abs(og.n2)*100))"
            level1 = render( tmpls[2], Dict(["pn"=>ml, "pct"=>s1] ))
            level2 = render( tmpls[2], Dict(["pn"=>ml, "pct"=>s2] ))
        end
    end
    println(level1, level2)
    v1 = MPROBS[(MPROBS.level .== level1).&(MPROBS.feature .== feature ), :estimate][1] * og.d1
    v2 = MPROBS[(MPROBS.level .== level2).&(MPROBS.feature .== feature ), :estimate][1] * og.d2
    return v1+v2
end


function mental_health()

end 

function life_expectancy() 

end

@with_kw mutable struct  Factors{T <: AbstractFloat }
    level = "Child - £0; Adult - £63; Pensioner - £190"
    tax = "Basic rate - 20%; Higher rate - 40%; Additional rate - 45%"
    funding= "Removal of income tax-free personal allowance"
    life_expectancy = zero(T)
    mental_health = zero(T)
    eligibility  = "People in and out of work are entitled"
    means_testing = "People with any or no amount of income are entitled to the full benefit"
    citizenship = "Only citizens are entitled"
    poverty = zero(T)
    inequality = zero(T)
end

function conjoint_total( factors :: Factors{T} ) :: T where T <: AbstractFloat
    # ±
    # TODO error bars 
    lev = MPROBS[MPROBS.level .== factors.level,:estimate][1]
    tx = MPROBS[MPROBS.level .== factors.tax,:estimate][1]
    fun = MPROBS[MPROBS.level .== factors.funding, :estimate][1]
    lxp = find_range( "Life.expectancy", factors.life_expectancy )
    mh = find_range( "Mental.health", factors.life_expectancy )
    elig = MPROBS[MPROBS.level .== factors.eligibility, :estimate][1]
    mt = MPROBS[MPROBS.level .== factors.means_testing, :estimate][1]
    cit = MPROBS[MPROBS.level .== factors.citizenship, :estimate][1]
    pov = find_range( "Poverty", factors.poverty )
    ineq = find_range( "Inequality", factors.inequality )
    return (lev+tx+fun+lxp+mh+elig+mt+cit+pov+ineq)/10.0
end