# SummationByParts.jl uses the following (very small) Package, which is not
# listed in the METADATA; therefore, it must be added explicitly
pkg_dict = Pkg.installed()
start_dir = pwd()
deps_path = joinpath(Pkg.dir("SummationByParts"), "deps")
cd(deps_path)
if !haskey(pkg_dict, "ODLCommonTools")
  run(`./download.sh`)
  Pkg.build("ODLCommonTools")
end
