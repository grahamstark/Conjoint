using Conjoint
using Test

@testset "Conjoint.jl" begin
    # Write your tests here.
    f = Factors{Float64}()
    p1 = calc_conjoint_total(f)
    f.poverty = 0.2 # 20% higher
    p2 = calc_conjoint_total(f)
    @test p1 > p2
    f.poverty = -0.2 # 20% higher
    p3 = calc_conjoint_total(f)
    @test p3 > p1 # less pov better    
end
