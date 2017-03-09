__precompile__(false)
module SummationByParts

using ArrayViews
using ODLCommonTools
import ODLCommonTools.sview

include("orthopoly.jl")
include("symcubatures.jl")
include("cubature.jl")

using .OrthoPoly
using .SymCubatures
using .Cubature

export AbstractSBP, TriSBP, TetSBP, SparseTriSBP, SparseTetSBP
export AbstractFace, TriFace, TetFace
export Boundary, Interface

export calcnodes, calcminnodedistance
export weakdifferentiate!, weakDifferentiateElement!
export weakdifferentiate_rev!, weakDifferentiateElement_rev!
export differentiate!, differentiateElement!
export directionalDifferentiateElement!
export volumeintegrate!, volumeIntegrateElement!
export calcMappingJacobian!, calcMappingJacobianElement!, mappingjacobian!
export calcMappingJacobianRevDiff!
export facenormal!, calcFaceNormals!
export boundaryinterpolate!, boundaryFaceInterpolate!
export interiorfaceinterpolate!, interiorFaceInterpolate!
export integratefunctional!, integrateBoundaryFunctional!
export integratefunctional_rev!
export boundaryintegrate!, boundaryFaceIntegrate!
export interiorfaceintegrate!, interiorFaceIntegrate!
export edgestabilize!, permuteinterface!

@doc """
### SBP.AbstractSBP

`AbstractSBP` is a parametric abstract type that defines summation-by-parts
finite-difference operators.

"""->
abstract AbstractSBP{T<:Number}
#abstract AbstractSBP{T<:AbstractFloat}

@doc """
### SBP.TriSBP

Defines diagonal-norm SBP first-derivative operators on a right-triangle.

**Fields**

* `degree` : maximum polynomial degree for which the derivatives are exact
* `numnodes` : number of nodes in the triangle required for these operators
* `numbndry` : number of boundary nodes for the operators
* `numfacenodes` : number of nodes on an individual face of the domain
* `facenodes` : indices of the nodes that lie on each face (no longer used)
* `facenormal` : unit normal to the faces, in reference space (no longer used)
* `cub` : a symmetric cubature type for triangles
* `vtx` : vertices of the reference element in computational space
* `w` : cubature weights, i.e. the diagonal SBP norm, stored as an array
* `wface` : mass matrix (dense) for the faces (no longer used)
* `Q[:,:,i]` : discrete stiffness matrix operator in ith coordinate direction

"""->
immutable TriSBP{T} <: AbstractSBP{T}
  degree::Int
  numnodes::Int
  numbndry::Int
  numfacenodes::Int
  facenodes::Array{Int,2}
  facenormal::Array{T,2}
  cub::TriSymCub{T}
  vtx::Array{T,2}
  w::Array{T,1}
  wface::Array{T,2}
  Q::Array{T,3}
  reorder::Bool

  function TriSBP(;degree::Int=1, faceorder::Array{Int,1}=[1;2;3], 
                  bubble::Int=-1, reorder=false, internal=false, vertices=true)
    @assert( degree >= 1 && degree <= 4 )
    cub, vtx = tricubature(2*degree-1, T, internal=internal, vertices=vertices)
    numnodes = cub.numnodes
    numbndry = SymCubatures.getnumboundarynodes(cub)
    numfacenodes = SymCubatures.getnumfacenodes(cub)
    wface = zeros(T,(1,1))
    facenodes = zeros(Int, (1,1))
    facenormal = T[0 -1; 1 1; -1 0].'
    Q = zeros(T, (numnodes, numnodes, 2))
    if bubble < 0
      w, Q = SummationByParts.buildoperators(cub, vtx, degree, internal=internal)
    else
      w, Q = SummationByParts.buildoperators(cub, vtx, degree, bubble)
    end
    if reorder
      # reorder the nodes
      perm, faceperm = SummationByParts.getnodepermutation(cub, degree)
      w = w[perm]
      Q[:,:,1] = Q[perm,perm,1]
      Q[:,:,2] = Q[perm,perm,2]
      perminv = invperm(perm)
      wface, facenodes = boundarymassmatrix(cub, vtx, degree)
      for k = 1:3
        facenodes[:,k] = perminv[facenodes[:,k]]
      end
      wface = wface[faceperm,faceperm]
      # reorder the faces
      facenodes[:,:] = facenodes[faceperm,faceorder]
      facenormal = facenormal[:,faceorder]
    end

    new(degree, numnodes, numbndry, numfacenodes, facenodes, facenormal, cub,
        vtx, w, wface, Q, reorder)
  end
end

@doc """
### SBP.SparseTriSBP

Defines diagonal-norm SBP first-derivative operators on a right-triangle using a
cubature rule that is greater than 2*p-1.  This provides additional flexiblity
in the SBP operator that is used to make a sparse S.

**Fields**

* `degree` : maximum polynomial degree for which the derivatives are exact
* `numnodes` : number of nodes in the triangle required for these operators
* `numbndry` : number of boundary nodes for the operators
* `numfacenodes` : number of nodes on an individual face of the domain
* `facenodes` : indices of the nodes that lie on each face (no longer used)
* `facenormal` : unit normal to the faces, in reference space (no longer used)
* `cub` : a symmetric cubature type for triangles
* `vtx` : vertices of the reference element in computational space
* `w` : cubature weights, i.e. the diagonal SBP norm, stored as an array
* `wface` : mass matrix (dense) for the faces (no longer used)
* `Q[:,:,i]` : discrete stiffness matrix operator in ith coordinate direction

"""->
immutable SparseTriSBP{T} <: AbstractSBP{T}
  degree::Int
  numnodes::Int
  numbndry::Int
  numfacenodes::Int
  facenodes::Array{Int,2}
  facenormal::Array{T,2}
  cub::TriSymCub{T}
  vtx::Array{T,2}
  w::Array{T,1}
  wface::Array{T,2}
  Q::Array{T,3}
  reorder::Bool

  function SparseTriSBP(;degree::Int=1, faceorder::Array{Int,1}=[1;2;3], 
                        internal=false, reorder=false, vertices=true,
                        cubdegree::Int=2*degree+1)
    @assert( degree >= 1 && degree <= 4 )
    cub, vtx = tricubature(cubdegree, T, internal=internal, vertices=vertices)
    numnodes = cub.numnodes
    numbndry = SymCubatures.getnumboundarynodes(cub)
    numfacenodes = SymCubatures.getnumfacenodes(cub)
    wface = zeros(T,(1,1))
    facenodes = zeros(Int, (1,1))
    facenormal = T[0 -1; 1 1; -1 0].'
    Q = zeros(T, (numnodes, numnodes, 2))
    w, Q = SummationByParts.buildsparseoperators(cub, vtx, degree,
                                                 internal=internal)
    if reorder
      # reorder the nodes
      perm, faceperm = SummationByParts.getnodepermutation(cub, degree)
      w = w[perm]
      Q[:,:,1] = Q[perm,perm,1]
      Q[:,:,2] = Q[perm,perm,2]
      perminv = invperm(perm)
      wface, facenodes = boundarymassmatrix(cub, vtx, degree)
      for k = 1:3
        facenodes[:,k] = perminv[facenodes[:,k]]
      end
      wface = wface[faceperm,faceperm]
      # reorder the faces
      facenodes[:,:] = facenodes[faceperm,faceorder]
      facenormal = facenormal[:,faceorder]
    end

    new(degree, numnodes, numbndry, numfacenodes, facenodes, facenormal, cub,
        vtx, w, wface, Q, reorder)
  end
end

@doc """
### SBP.TetSBP

Defines diagonal-norm SBP first-derivative operators on a right-tetrahedron.

**Fields**

* `degree` : maximum polynomial degree for which the derivatives are exact
* `numnodes` : number of nodes in the tetrahedron required for these operators
* `numbndry` : number of boundary nodes for the operators 
* `numfacenodes` : number of nodes on an individual face of the domain
* `facenodes` : indices of the nodes that lie on each face
* `facenormal` : unit normal to the faces, in reference space
* `cub` : a symmetric cubature type for tetrahedra
* `vtx` : vertices of the reference element in computational space
* `w` : cubature weights, i.e. the diagonal SBP norm, stored as an array
* `wface` : mass matrix (dense) for the faces
* `Q[:,:,i]` : discrete stiffness matrix operator in ith coordinate direction

"""->
immutable TetSBP{T} <: AbstractSBP{T}
  degree::Int
  numnodes::Int
  numbndry::Int
  numfacenodes::Int
  facenodes::Array{Int,2}
  facenormal::Array{T,2}
  cub::TetSymCub{T}
  vtx::Array{T,2}
  w::Array{T,1}
  wface::Array{T,2}
  Q::Array{T,3}
  reorder::Bool

  function TetSBP(;degree::Int=1, faceorder::Array{Int,1}=[1;2;3;4],
                  reorder=false, internal=false)
    @assert( degree >= 1 && degree <= 4 )
    cub, vtx = tetcubature(2*degree-1, T, internal=internal)
    numnodes = cub.numnodes
    numbndry = SymCubatures.getnumboundarynodes(cub)
    numfacenodes = SymCubatures.getnumfacenodes(cub)
    wface = zeros(T,(1,1))
    facenodes = zeros(Int, (1,1))
    facenormal = T[0 0 -1; 0 -1 0; 1 1 1; -1 0 0].'
    Q = zeros(T, (numnodes, numnodes, 3))
    w, Q = SummationByParts.buildoperators(cub, vtx, degree, internal=internal)
    if reorder
      # reorder the nodes
      perm, faceperm = SummationByParts.getnodepermutation(cub, degree)
      w = w[perm]
      Q[:,:,1] = Q[perm,perm,1]
      Q[:,:,2] = Q[perm,perm,2]
      Q[:,:,3] = Q[perm,perm,3]
      perminv = invperm(perm)
      wface, facenodes = boundarymassmatrix(cub, vtx, degree)
      for k = 1:4
        facenodes[:,k] = perminv[facenodes[:,k]]
      end
      wface = wface[faceperm,faceperm]
      # reorder the faces
      facenodes[:,:] = facenodes[faceperm,faceorder]
      facenormal = facenormal[:,faceorder]
    end

    new(degree, numnodes, numbndry, numfacenodes, facenodes, facenormal, cub,
        vtx, w, wface, Q, reorder)
  end
end

@doc """
### SBP.SparseTetSBP

Defines diagonal-norm SBP first-derivative operators on a right-tetrahedron
using a cubature rule that is greater than 2*p-1.  This provides additional
flexiblity in the SBP operator that is used to make a sparse S.

**Fields**

* `degree` : maximum polynomial degree for which the derivatives are exact
* `numnodes` : number of nodes in the tetrahedron required for these operators
* `numbndry` : number of boundary nodes for the operators 
* `numfacenodes` : number of nodes on an individual face of the domain
* `facenodes` : indices of the nodes that lie on each face
* `facenormal` : unit normal to the faces, in reference space
* `cub` : a symmetric cubature type for tetrahedra
* `vtx` : vertices of the reference element in computational space
* `w` : cubature weights, i.e. the diagonal SBP norm, stored as an array
* `wface` : mass matrix (dense) for the faces
* `Q[:,:,i]` : discrete stiffness matrix operator in ith coordinate direction

"""->
immutable SparseTetSBP{T} <: AbstractSBP{T}
  degree::Int
  numnodes::Int
  numbndry::Int
  numfacenodes::Int
  facenodes::Array{Int,2}
  facenormal::Array{T,2}
  cub::TetSymCub{T}
  vtx::Array{T,2}
  w::Array{T,1}
  wface::Array{T,2}
  Q::Array{T,3}
  reorder::Bool

  function SparseTetSBP(;degree::Int=1, faceorder::Array{Int,1}=[1;2;3;4],
                        reorder=false, internal=false, cubdegree::Int=2*degree-1)
    @assert( degree >= 1 && degree <= 3 )
    cub, vtx = tetcubature(cubdegree, T, internal=internal)
    numnodes = cub.numnodes
    numbndry = SymCubatures.getnumboundarynodes(cub)
    numfacenodes = SymCubatures.getnumfacenodes(cub)
    wface = zeros(T,(1,1))
    facenodes = zeros(Int, (1,1))
    facenormal = T[0 0 -1; 0 -1 0; 1 1 1; -1 0 0].'
    Q = zeros(T, (numnodes, numnodes, 3))
    w, Q = SummationByParts.buildsparseoperators(cub, vtx, degree,
                                                 internal=internal)
    if reorder
      # reorder the nodes
      perm, faceperm = SummationByParts.getnodepermutation(cub, degree)
      w = w[perm]
      Q[:,:,1] = Q[perm,perm,1]
      Q[:,:,2] = Q[perm,perm,2]
      Q[:,:,3] = Q[perm,perm,3]
      perminv = invperm(perm)
      wface, facenodes = boundarymassmatrix(cub, vtx, degree)
      for k = 1:4
        facenodes[:,k] = perminv[facenodes[:,k]]
      end
      wface = wface[faceperm,faceperm]
      # reorder the faces
      facenodes[:,:] = facenodes[faceperm,faceorder]
      facenormal = facenormal[:,faceorder]
    end

    new(degree, numnodes, numbndry, numfacenodes, facenodes, facenormal, cub,
        vtx, w, wface, Q, reorder)
  end
end

@doc """
### SBP.AbstractFace

`AbstractFace` is a parametric abstract type that defines face-based data and
operations (e.g. volume-to-face reconstruction, face integration, etc) for
summation-by-parts finite-difference operators.

"""->
abstract AbstractFace{T<:Number}

@doc """
### SBP.TriFace

Defines a face between two TriSBP operators with the same cubature nodes

**Fields**

* `degree` : face integration is exact for polys of degree 2*`degree`
* `numnodes` : number of cubature nodes
* `stencilsize` : number of nodes in the reconstruction stencil
* `dstencilsize` : number of nodes in the derivative operator stencils
* `cub` : a symmetric cubature type for triangle faces (i.e. edges)
* `vtx` : the vertices of the face in reference space, [-1,1]
* `wface` : mass matrix (quadrature) for the face
* `interp[:,:]` : volume-to-face-nodes reconstruction operator
* `perm[:,:]` : permutation for volume nodes so `interp` can be used on all sides
* `deriv[:,:]` : derivative operators for face-based coordinate system
* `dperm[:,:]` : permutation for volume nodes so `deriv` can be used on all sides
* `nbrperm[:,:]` : permutation for face nodes on neighbour element

"""->
immutable TriFace{T} <: AbstractFace{T}
  degree::Int
  numnodes::Int
  stencilsize::Int
  dstencilsize::Int
  cub::LineSymCub{T}
  vtx::Array{T,2}
  wface::Array{T,1}
  normal::Array{T,2}
  interp::Array{T,2}
  perm::Array{Int,2}
  deriv::Array{T,3}
  dperm::Array{Int,2}
  nbrperm::Array{Int,2}
  function TriFace(degree::Int, volcub::TriSymCub{T}, vtx::Array{T,2})
    @assert( degree >= 1 && degree <= 5 )
    facecub, facevtx = quadrature(2*degree, T, internal=true)
    normal = T[0 -1; 1 1; -1 0].'
    R, perm = SummationByParts.buildfacereconstruction(facecub, volcub, vtx,
                                                       degree)
    D, Dperm = SummationByParts.buildfacederivatives(facecub, volcub, vtx,
                                                     degree)
    nbrperm = SymCubatures.getneighbourpermutation(facecub)
    wface = SymCubatures.calcweights(facecub)
    stencilsize = size(R,2)
    dstencilsize = size(D,1)
    new(degree, facecub.numnodes, stencilsize, dstencilsize, facecub, facevtx, 
        wface, normal, R.', perm, D, Dperm, nbrperm)
  end
end

@doc """
### SBP.TetFace

Defines a face between two TetSBP operators with the same cubature nodes

**Fields**

* `degree` : face integration is exact for polys of degree 2*`degree`
* `numnodes` : number of cubature nodes
* `stencilsize` : number of nodes in the reconstruction stencil
* `dstencilsize` : number of nodes in the derivative operator stencils
* `cub` : a symmetric cubature type for tetrahedral faces (i.e. triangles)
* `vtx` : the vertices of the face in the reference space of the face
* `wface` : mass matrix (quadrature) for the face
* `interp[:,:]` : volume-to-face-nodes reconstruction operator
* `perm[:,:]` : permutation for volume nodes so `interp` can be used on all sides
* `deriv[:,:]` : derivative operators for face-based coordinate system
* `dperm[:,:]` : permutation for volume nodes so `deriv` can be used on all sides
* `nbrperm[:,:]` : permutation for face nodes on neighbour element

"""->
immutable TetFace{T} <: AbstractFace{T}
  degree::Int
  numnodes::Int
  stencilsize::Int
  #dstencilsize::Int
  cub::TriSymCub{T}
  vtx::Array{T,2}
  wface::Array{T,1}
  normal::Array{T,2}
  interp::Array{T,2}
  perm::Array{Int,2}
  #deriv::Array{T,3}
  #dperm::Array{Int,2}
  nbrperm::Array{Int,2}
  function TetFace(degree::Int, volcub::TetSymCub{T}, vtx::Array{T,2})
    @assert( degree >= 1 && degree <= 4 )
    facecub, facevtx = tricubature(2*degree, T, internal=true)
    normal = T[0 0 -1; 0 -1 0; 1 1 1; -1 0 0].'
    R, perm = SummationByParts.buildfacereconstruction(facecub, volcub, vtx,
                                                       degree)
    #D, Dperm = SummationByParts.buildfacederivatives(facecub, volcub, vtx,
    #                                                 degree)
    nbrperm = SymCubatures.getneighbourpermutation(facecub)
    wface = SymCubatures.calcweights(facecub)
    stencilsize = size(R,2)
    #dstencilsize = size(D,1)
    #new(degree, facecub.numnodes, stencilsize, dstencilsize, facecub, wface,
    #    normal, R.', perm, D, Dperm, nbrperm)
    new(degree, facecub.numnodes, stencilsize, facecub, facevtx, wface, normal,
        R.', perm, nbrperm)
  end
end

@doc """
### SBP.UnaryFunctor

`UnaryFunctor` is abstract type that is used to specify different types of
residual updates in the useoperators.jl and usefaceoperators.jl files

"""->
abstract UnaryFunctor

@doc """
### SBP.Add

`Add` is basically an identity operator.  It is needed as a default
UnaryFunctor.

"""->
type Add <: UnaryFunctor
end
function call(update::Add, scalar)
  return scalar
end

@doc """
### SBP.Subtract

`Subtract` is used to negate values, which is useful in residual updates

"""->
type Subtract <: UnaryFunctor
end
function call(update::Subtract, scalar)
  return -scalar
end

include("buildfaceoperators.jl") #<--- functions related to building face operators
include("buildoperators.jl") #<--- functions related to building SBP operators
include("weakdifferentiate.jl") #<--- functions for weak differentiation
include("weakdifferentiate_rev.jl") #<--- functions for weak differentiation
include("differentiate.jl") #<--- functions for strong differentiation
include("directionaldifferentiate.jl") #<--- directional differentiation
include("volumeintegrate.jl") #<--- volume integration against test functions
include("facenormal.jl") #<--- functions to compute scaled face normals
include("mappingjacobian.jl") #<--- functions to compute the mapping jacobian
include("mappingjacobianrevdiff.jl") #<--- reverse-mode diff. of mappingjacobian
include("faceinterpolate.jl") #<--- functions to interpolate data to faces
include("faceintegrate.jl") #<--- functions for integration over faces
include("faceintegrate_rev.jl") #<--- reverse mode of faceintegrate.jl
include("edgestabilize.jl") #<--- functions related to edge stabilization
include("utils.jl") # <--- miscillaneous functions

end # module
