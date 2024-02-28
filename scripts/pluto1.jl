### A Pluto.jl notebook ###
# v0.19.32

using Markdown
using InteractiveUtils

# ╔═╡ 1228ec30-039c-11ee-2bb6-21d4b26399e6
begin
    import Pkg
    # activate the shared project environment
    Pkg.activate("..")
    # instantiate, i.e. make sure that all packages are downloaded
    Pkg.instantiate()
    using 
		Conjoint, 
		CairoMakie,
		CSV,
		DataFrames,
		Measurements, 
		PlutoUI
end


# ╔═╡ 1dd421a1-6e8b-4282-b6fe-55a09dd0477f
begin
	using ScottishTaxBenefitModel
end

# ╔═╡ ebac2f55-d504-48ca-8702-19cf2b0224e8
begin
	f = Factors{Float64}()
	calc_conjoint_total(f)
	
end

# ╔═╡ c2d48c6d-ce25-4920-96f9-2a360f8f4b85
begin
	f.poverty = 0.2
	calc_conjoint_total(f)
end

# ╔═╡ Cell order:
# ╠═1228ec30-039c-11ee-2bb6-21d4b26399e6
# ╠═1dd421a1-6e8b-4282-b6fe-55a09dd0477f
# ╠═ebac2f55-d504-48ca-8702-19cf2b0224e8
# ╠═c2d48c6d-ce25-4920-96f9-2a360f8f4b85
