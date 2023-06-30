module Conjoint

#
# experiments with Conjoint marginal probabilities
#

# Graham, this is the dataframe of marginal probabilities of choice. 
# These can just be averaged (nb not summed) to give you the probability of choice of any bundle of different attributes. 

using 
    CSV, 
    Observables,
    DataFrames, 
    HypertextLiteral,
    Measurements, 
    Mustache, 
    Parameters, 
    StatsBase
    
export 
    calc_conjoint_total,
    # doonerun!,
    feature_to_radio,
    Factors

const FILES = ["totalmm.csv", "leftrightmm.csv", "agemm.csv", "finances3mm.csv", "gendermm.csv", "labourtorydnvmm.csv"]

const PROJECT_DIR = joinpath(dirname(pathof(Conjoint)),".." ) 

function loadprobs() :: DataFrame
    d = CSV.File("$PROJECT_DIR/data/$(FILES[1])")|>DataFrame
    for f in 2:length(FILES)
        fname = "$PROJECT_DIR/data/$(FILES[f])"
        println( "loading $fname")
        dd = CSV.File(fname)|>DataFrame
        d = vcat( d, dd )
    end
    d
end

const MPROBS = loadprobs() 

function createbreakdowns() :: Dict
    d = Dict()
    bd = string.(unique( MPROBS.breakdown ))
    for b in bd
        bdvalues = string.(unique( MPROBS[MPROBS.breakdown .== b,:BY] ))
        d[b] = bdvalues
    end
    d
end

const BREAKDOWNS = createbreakdowns()

const CHANGE_BREAKS = [-0.5,-0.25,-0.1,-0.05,0,0.05,0.10,0.25,0.5]
const LIFE_BREAKS = [-5,-3,-1,0,1,3,5]

@enum Diff negative zer positive out_of_range # can't use 'zero' 

"""
for interpolating a gap
"""
function ogap( v, n1, n2 )
    if !(n1 <= v <= n2)
        return (vl=out_of_range,d1=-1,d2=-1)
    end
    @assert n1 <= n2
    if v ≈ 0
        return (vl=zero,d1=1,d2=0)
    end
    d0 = n1 - n2
    d1 = (v - (n2))/d0
    d2 = (n1 - v)/d0
    vl = if v ≈ 0
        zer
    elseif v < 0
        negative
    else
        positive
    end
    @assert d1+d2 ≈ 1
     (; vl, d1, d2, n1, n2 )
end

function make_levels( feature::AbstractString, n :: Number ) # :: Vector{F}
    levels = feature == "Life.expectancy" ? LIFE_BREAKS : CHANGE_BREAKS
    ln = size(levels)[1]
    @assert levels[begin] <= n <= levels[end] "$n is out-of-range of $(levels[begin]) $(levels[end])"
    og = nothing
    for i in 2:ln
        og = ogap( n, levels[i-1],levels[i])
        # println(og)
        if og.vl != out_of_range
            break;
        end
    end
    @assert ! isnothing( og )
    og
end

const PCT_TMPLS = [mt"Unchanged.", mt"{{pn}} by {{pct}}%." ]
const CASE_TMPLS = [mt"Same number of cases", mt"{{pct}}% {{pn}} cases" ]
const LIFE_TMPLS = [mt"0 more or less years on average", mt"{{yrs}} {{pn}} year{{pl}} on average" ]

"""
Find the 2 nearest in the dataframe for the given feature and value `val`
FIXME Refactor the Fuck out of this.
TODO add ranges
"""
function find_range( by :: AbstractString, feature :: AbstractString, val :: Number )
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
    og = make_levels( feature, val )
    level1 = level2 = ""
    if og.vl == zero
        level1 = level2 = render( tmpls[1])
    else
        ml = og.vl == positive ? more : less
        if feature == "Life.expectancy"
            pl = ""
            tmpl = tmpls[2]
            if abs( og.n1 ) > 1 
                pl = "s"
            elseif og.n1 == -1
                # HORRIBLE
                ml = "less"
            elseif og.n1 == 0
                tmpl = tmpls[1]
            end                
            s1 = abs( og.n1 )
            s2 = abs( og.n2 )
            level1 = render( tmpl, Dict(["yrs"=>s1, "pl"=>pl, "pn"=>ml ] ))
            pl = ""
            tmpl = tmpls[2]
            if abs( og.n2 ) > 1 
                pl = "s"
            elseif og.n2 == -1
                # HORRIBLE
                ml = "less"
            elseif og.n2 == 0
                tmpl = tmpls[1]
            end 
            level2 = render( tmpl, Dict(["yrs"=>s2, "pl"=>pl, "pn"=>ml ] ))
        else
            if og.n1 == 0
                level1 = render( tmpls[1])
            else
                s1 = "$(Int(abs(og.n1)*100))"
                level1 = render( tmpls[2], Dict(["pn"=>ml, "pct"=>s1] ))
            end
            if og.n2 == 0
                level2 = render( tmpls[1])
            else
                s2 = "$(Int(abs(og.n2)*100))"
                level2 = render( tmpls[2], Dict(["pn"=>ml, "pct"=>s2] ))
            end
        end
    end
    println("BY=$by level1='$level1' level2='$level2' feature='$feature' ")
    v1 = MPROBS[(MPROBS.BY .== by).&(MPROBS.level .== level1).&(MPROBS.feature .== feature ), :estimate][1] * og.d1
    v2 = MPROBS[(MPROBS.BY .== by).&(MPROBS.level .== level2).&(MPROBS.feature .== feature ), :estimate][1] * og.d2
    return v1+v2
end


@with_kw mutable struct Factors{T <: AbstractFloat }
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

function calc_conjoint_total( by :: AbstractString, factors :: Factors{T} ) :: NamedTuple where T <: AbstractFloat
    # ±
    # TODO error bars 
    
    lev = MPROBS[(MPROBS.BY .== by).&(MPROBS.level .== factors.level),:estimate][1]
    tx = MPROBS[(MPROBS.BY .== by).&(MPROBS.level .== factors.tax),:estimate][1]
    fun = MPROBS[(MPROBS.BY .== by).&(MPROBS.level .== factors.funding), :estimate][1]
    lxp = find_range( by, "Life.expectancy", factors.life_expectancy )
    mh = find_range( by, "Mental.health", factors.mental_health )
    elig = MPROBS[(MPROBS.BY .== by).&(MPROBS.level .== factors.eligibility), :estimate][1]
    mt = MPROBS[(MPROBS.BY .== by).&(MPROBS.level .== factors.means_testing), :estimate][1]
    cit = MPROBS[(MPROBS.BY .== by).&(MPROBS.level .== factors.citizenship), :estimate][1]
    println( "factors.inequality = $(factors.inequality)")
    ineq = find_range( by, "Inequality", factors.inequality )
    pov = find_range( by, "Poverty", factors.poverty )
    avg = (lev+tx+fun+lxp+mh+elig+mt+cit+pov+ineq)/10.0
    components = (; lev, tx, fun, lxp, mh, elig, mt, cit, pov, ineq )
    return (; avg, components )
end


function renderrow( id, level, checked, disabled, feature )
    fid = "$(feature)-$(id)"
    @htl("""
    <div class="form-check">
        <input class='form-check-input' checked=$(checked) disabled=$(disabled) type='radio' name='$(feature)' id='$(fid)' value='$(level)'  />
        <label class='form-check-label' for='$(fid)'>$level</label>
    </div>
    """ )
end

function feature_to_radio( feature :: AbstractString; selected = nothing, disabled=false ) :: HypertextLiteral.Result
    levels = MPROBS[MPROBS.feature.== feature ,:level]
    id = 1
    params = []   
    for level in levels
        checked = false 
        if isnothing( selected ) && id == 1
            checked = true
        elseif level == selected 
            checked = true
        end
        push!( params, ( id, level, checked, disabled, feature ) )
        id += 1
    end
    # see: https://github.com/JuliaPluto/HypertextLiteral.jl
    return @htl("""
        $((renderrow(b...) for b in params))
    """)
end

end # module
