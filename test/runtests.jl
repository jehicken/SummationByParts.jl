using SummationByParts
using SummationByParts.OrthoPoly
using SummationByParts.Cubature
using SummationByParts.SymCubatures
using FactCheck
using ArrayViews
using ODLCommonTools

include("test_orthopoly.jl")
include("test_symcubatures.jl")
include("test_cubature.jl")
include("test_buildfaceoperators.jl")
include("test_buildoperators.jl")
include("test_useoperators.jl")
include("test_usefaceoperators.jl")
include("test_utils.jl")

FactCheck.exitstatus()