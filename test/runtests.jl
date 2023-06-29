using Conjoint
using Test
using Observables
using ScottishTaxBenefitModel
using .Monitor: Progress
using .RunSettings

@testset "find_range" begin
    for breakdown in keys(Conjoint.BREAKDOWNS)
        bvals = Conjoint.BREAKDOWNS[breakdown]
        for bv in bvals
            for feature in ["Life.expectancy", "Mental.health", "Inequality", "Poverty"]
                range = -0.40:0.01:0.40
                if feature == "Life.expectancy" 
                    range = -5:0.5:5 
                end
                for val in range
                    print( "breakdown = $breakdown ; bval=$bv ; feature $feature val $val")
                    levels = Conjoint.make_levels( feature, val )
                    println( "levels $levels")
                    v = Conjoint.find_range( bv, feature, val )
                    println( "v => $v")
                end
            end
        end # bvals
    end # breakdown
end

@testset "calc_conjoint_total" begin
    for breakdown in keys(Conjoint.BREAKDOWNS)
        bvals = Conjoint.BREAKDOWNS[breakdown]
        for bv in bvals
            f = Factors{Float64}()
            p1 = calc_conjoint_total(bv, f)
            f.poverty = 0.2 # 20% higher
            p2 = calc_conjoint_total(bv, f)
            @test p1.avg > p2.avg
            f.poverty = -0.2 # 20% lower
            p3 = calc_conjoint_total(bv, f)
            @test p3.avg > p1.avg # less pov better    
            f.mental_health = -0.2
            p4 = calc_conjoint_total(bv, f)
            @test p4.avg > p1.avg # less mh better
        end
    end
end

