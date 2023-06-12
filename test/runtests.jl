using Conjoint
using Test

@testset "Conjoint.jl" begin
    # Write your tests here.
    f = Factors{Float64}()
    p1 = calc_conjoint_total(f)
    f.poverty = 0.2 # 20% higher
    p2 = calc_conjoint_total(f)
    @test p1.avg > p2.avg
    f.poverty = -0.2 # 20% higher
    p3 = calc_conjoint_total(f)
    @test p3.avg > p1.avg # less pov better    
end
