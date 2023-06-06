module Conjoint

#
# experiments with Conjoint marginal probabilities
#

# Graham, this is the dataframe of marginal probabilities of choice. 
# These can just be averaged (nb not summed) to give you the probability of choice of any bundle of different attributes. 

using 
    CairoMakie, 
    CSV, 
    DataFrames, 
    HypertextLiteral,
    Measurements, 
    Mustache, 
    Parameters, 
    Pluto, 
    PlutoUI,

    ScottishTaxBenefitModel
    using ScottishTaxBenefitModel.GeneralTaxComponents
    using ScottishTaxBenefitModel.STBParameters
    using ScottishTaxBenefitModel.Runner: do_one_run
    using ScottishTaxBenefitModel.RunSettings
    using .Utils
    using .Monitor: Progress
    using .ExampleHelpers
    using .STBOutput: make_poverty_line, summarise_inc_frame, 
        dump_frames, summarise_frames!, make_gain_lose
    
export 
    calc_conjoint_total,
    doonerun,
    feature_to_radio,
    Factors

const PROJECT_DIR = dirname( Base.current_project() )
const MPROBS = CSV.File( "$PROJECT_DIR/data/marginalprobabilities.csv" ) |> DataFrame
const CHANGE_BREAKS = [-0.5,-0.25,-0.1,-0.05,0,0.05,0.10,0.25,0.5]
const LIFE_BREAKS = [-5,-3,-1,0,1,3,5]


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
    # println(levels)
    ln = size(levels)[1]
    @assert levels[begin] <= n <= levels[end]
    og = nothing
    for i in 2:ln
        og = ogap( n, levels[i-1],levels[i])
        # println(og)
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
    # println(level1, level2)
    # println( MPROBS[(MPROBS.feature .== "Poverty"),:level][1])
    v1 = MPROBS[(MPROBS.level .== level1).&(MPROBS.feature .== feature ), :estimate][1] * og.d1
    v2 = MPROBS[(MPROBS.level .== level2).&(MPROBS.feature .== feature ), :estimate][1] * og.d2
    return v1+v2
end


function mental_health()
    # TODO
end 

function life_expectancy() 
    # TODO
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

function calc_conjoint_total( factors :: Factors{T} ) :: T where T <: AbstractFloat
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
    ineq = find_range( "Inequality", factors.inequality )
    pov = find_range( "Poverty", factors.poverty )
    return (lev+tx+fun+lxp+mh+elig+mt+cit+pov+ineq)/10.0
end

function load_system(; scotland = false )::TaxBenefitSystem
    sys = load_file( joinpath( Definitions.MODEL_PARAMS_DIR, "sys_2022-23.jl"))
    if ! scotland 
        load_file!( sys, joinpath( Definitions.MODEL_PARAMS_DIR, "sys_2022-23_ruk.jl"))
    end
    weeklyise!( sys )
    return sys
end


function map_features!( tb :: TaxBenefitSystem, facs :: Factors )
    tb.ubi.abolished = false
    if facs.level ==
        "Child - £0; Adult - £63; Pensioner - £190"
        tb.ubi.adult_amount = 63
        tb.ubi.child_amount = 0
        tb.ubi.universal_pension = 190
    elseif facs.level ==
        "Child - £41; Adult - £63; Pensioner - £190"
        tb.ubi.adult_amount = 63
        tb.ubi.child_amount = 41
        tb.ubi.universal_pension = 190
    elseif facs.level ==
        "Child - £0; Adult - £145; Pensioner - £190"
        tb.ubi.adult_amount = 145
        tb.ubi.child_amount = 0
        tb.ubi.universal_pension = 190
    elseif facs.level ==
        "Child - £41; Adult - £145; Pensioner - £190"
        tb.ubi.adult_amount = 145
        tb.ubi.child_amount = 41
        tb.ubi.universal_pension = 190
    elseif facs.level ==
        "Child - £63; Adult - £145; Pensioner - £190"
        tb.ubi.adult_amount = 145
        tb.ubi.child_amount = 63
        tb.ubi.universal_pension = 190
    elseif facs.level ==
        "Child - £63; Adult - £190; Pensioner - £190"
        tb.ubi.adult_amount = 190
        tb.ubi.child_amount = 63
        tb.ubi.universal_pension = 190
    elseif facs.level ==
        "Child - £95; Adult - £190; Pensioner - £230"
        tb.ubi.adult_amount = 190
        tb.ubi.child_amount = 95
        tb.ubi.universal_pension = 230
    elseif facs.level ==
        "Child - £41; Adult - £230; Pensioner - £230"
        tb.ubi.adult_amount = 230
        tb.ubi.child_amount = 41
        tb.ubi.universal_pension = 230
    elseif facs.level ==
        "Child - £95; Adult - £230; Pensioner - £230"
        tb.ubi.adult_amount = 230
        tb.ubi.child_amount = 95
        tb.ubi.universal_pension = 230
    else
        @assert false "non mapped facs.level: $(facs.level)"
    end 

    if facs.tax == 
        "Basic rate - 20%; Higher rate - 40%; Additional rate - 45%"
        tb.it.non_savings_rates = [0.2, 0.4, 0.45 ]
    elseif facs.tax == 
        "Basic rate - 23%; Higher rate - 43%; Additional rate - 48%"
        tb.it.non_savings_rates = [0.23, 0.43, 0.48 ]    
    elseif facs.tax == 
        "Basic rate - 30%; Higher rate - 50%; Additional rate - 60%"
        tb.it.non_savings_rates = [0.3, 0.5, 0.6 ]    
    elseif facs.tax == 
        "Basic rate - 40%; Higher rate - 60%; Additional rate - 70%"
        tb.it.non_savings_rates = [0.4, 0.6, 0.7 ]    
    elseif facs.tax == 
        "Basic rate - 48%; Higher rate - 68%; Additional rate - 78%"
        tb.it.non_savings_rates = [0.48, 0.68, 0.78 ]    
    elseif facs.tax == 
        "Basic rate - 50%; Higher rate - 70%; Additional rate - 80%"
        tb.it.non_savings_rates = [0.5, 0.7, 0.8 ]    
    elseif facs.tax == 
        "Basic rate - 65%; Higher rate - 85%; Additional rate - 95%"
        tb.it.non_savings_rates = [0.65, 0.85, 0.95 ]    
    else
        @assert false "non mapped facs.tax: $(facs.tax)"
    end

    if facs.funding ==
        "Removal of income tax-free personal allowance"
        tb.it.personal_allowance = 0.0
    elseif facs.funding in [
        "Increased government borrowing",
        "Corporation tax increase",
        "Tax for businesses based on carbon emissions",
        "Tax for individuals based on carbon emissions",
        "Tax on wealth",
        "VAT increase"]
        # TODO nothing yet
    else
        @assert false "non mapped facs.funding: $(facs.funding)"
    end

    ## TODO facs.eligibility
    ## TODO facs.citizenship
    ## TODO facs.means_testing 

    make_ubi_pre_adjustments!( tb )
end

function doonerun( facs :: Factors )
    settings = Settings()
    obs = Observable( Progress(settings.uuid,"",0,0,0,0))
    settings.do_marginal_rates = false
    sys1 = load_system( scotland=false ) 
    sys2 = deepcopy(sys1)
    map_features!( sys2, facs )
    sys = [sys1,sys2]
    ## , get_system( year=2019, scotland=true )]
    results = do_one_run( settings, sys, obs )
    settings.poverty_line = make_poverty_line( results.hh[1], settings )
    summaries = summarise_frames!( results, settings ) 

    facs.poverty = summaries.poverty[2].headcount - summaries.poverty[1].headcount
    facs.inequality = summaries.inequality[2].gini - summaries.inequality[1].gini
    pop = calc_conjoint_total( facs )
    return( ; pop, summaries, facs )
end

# const
RADIO_TMPL_M = mt"""
<input class='form-check-input' {{checked}} type='radio' name='{{feature}}' id='{{feature}}-{{id}}' value='{{level}}' {{disabled}} />
<label class="form-check-label" for='{{feature}}'>
  {{level}}
</label>

"""


function renderrow( id, level, checked, disabled, feature )
    fid = "$(id)-$(feature)"
    @htl("""
    <input class='form-check-input' $(checked) type='radio' name='$(feature)' id='$(fid)' value='$(level)'  />
    <label class='form-check-label' for='$(feature)'>
      $level
    </label>
    
    """ )
end

function feature_to_radio( feature :: String; selected = nothing, disabled=false ) :: String
    s = ""
    levels = MPROBS[MPROBS.feature.== feature ,:level]
    id = 1
    disstr = disabled ? "disabled" : ""
    for level in levels 
        checked = if isnothing( selected )
            if id == 1
                "checked"
            else
                ""
            end
        else
            if l == selected 
                "checked"
            else
               "" 
            end
        end
        s *= renderrow( id, level, checked, disabled, feature )
            # RADIO_TMPL, Dict(["feature"=>feature,"level"=>l,"id"=>id, "disabled"=>disstr, "checked"=>checked]))
        id += 1
    end
    return s
end

end # module