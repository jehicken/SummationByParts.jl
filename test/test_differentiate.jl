facts("Testing SummationByParts Module (differentiate methods)...") do

  for TSBP = (getLineSegSBPLobbato, getLineSegSBPLegendre)
    @eval begin
      context("Testing differentiate! ("string($TSBP)" scalar field method)") do
        # verify the accuracy of the differentiation operators
        for d = 1:4
          sbp = ($TSBP)(degree=d)
          vtx = sbp.vtx
          x = calcnodes(sbp, vtx)
          x = reshape(x, (sbp.numnodes,1))
          for i = 0:d
            u = x.^i
            dudx = i.*x.^max(0,i-1)
            res = zeros(u)
            differentiate!(sbp, 1, u, res)
            @fact res --> roughly(dudx, atol=5e-13)
          end
        end
      end 
    end
  end

  for TSBP = (getTriSBPGamma, getTriSBPOmega, getTriSBPDiagE)
    @eval begin
      context("Testing differentiate! ("string($TSBP)" scalar field method)") do
        # verify the accuracy of the differentiation operators
        for d = 1:4
          sbp = ($TSBP)(degree=d)
          vtx = sbp.vtx
          xy = calcnodes(sbp, vtx)
          x = zeros(Float64, (sbp.numnodes,1))
          y = zeros(x)
          x[:,1] = vec(xy[1,:]); y[:,1] = vec(xy[2,:])
          for r = 0:d
            for j = 0:r
              i = r-j
              u = (x.^i).*(y.^j)
              dudx = (i.*x.^max(0,i-1)).*(y.^j)          
              dudy = (x.^i).*(j.*y.^max(0,j-1))
              res = zeros(u)
              differentiate!(sbp, 1, u, res)
              @fact res --> roughly(dudx, atol=5e-13)
              res = zeros(u)
              differentiate!(sbp, 2, u, res)
              @fact res --> roughly(dudy, atol=5e-13)
            end
          end
        end
      end 
    end
  end

  for TSBP = (getTetSBPGamma, getTetSBPOmega, getTetSBPDiagE)
    @eval begin
      context("Testing differentiate! ("string($TSBP)" scalar field method)") do
        # verify the accuracy of the differentiation operators
        for d = 1:4
          sbp = ($TSBP)(degree=d)
          vtx = sbp.vtx
          xyz = calcnodes(sbp, vtx)
          x = zeros(Float64, (sbp.numnodes,1))
          y = zeros(x)
          z = zeros(x)
          x[:,1] = vec(xyz[1,:]); y[:,1] = vec(xyz[2,:]); z[:,1] = vec(xyz[3,:])
          for r = 0:d
            for k = 0:r
              for j = 0:r-k
                i = r-j-k
                u = (x.^i).*(y.^j).*(z.^k)
                dudx = (i.*x.^max(0,i-1)).*(y.^j).*(z.^k)
                dudy = (x.^i).*(j.*y.^max(0,j-1)).*(z.^k)
                dudz = (x.^i).*(y.^j).*(k.*z.^max(0,k-1))
                res = zeros(u)
                differentiate!(sbp, 1, u, res)
                @fact res --> roughly(dudx, atol=5e-12)
                res = zeros(u)
                differentiate!(sbp, 2, u, res)
                @fact res --> roughly(dudy, atol=5e-12)
                res = zeros(u)
                differentiate!(sbp, 3, u, res)
                @fact res --> roughly(dudz, atol=5e-12)
              end
            end
          end
        end
      end
    end
  end

  for TSBP = (getLineSegSBPLobbato, getLineSegSBPLegendre)
    @eval begin
      context("Testing differentiate! ("string($TSBP)" vector field method)") do
        # build a two element grid, and verify that Dxi*1 = 0.0 and Dxi*x^p =
        # p*x^(p-1)
        for d = 1:4
          sbp = ($TSBP)(degree=d)
          vtx = reshape([0.0; 1.0], (2,1))
          x = ones(Float64, (2,sbp.numnodes,2))
          x[2,:,1] = calcnodes(sbp, vtx)          
          vtx = reshape([1.0; 2.0], (2,1))
          x[2,:,2] = calcnodes(sbp, vtx)
          for i = 0:d
            u = x.^i
            dudx = i.*x.^max(0,i-1)
            res = zeros(u)
            differentiate!(sbp, 1, u, res)
            # account for mapping Jacobian
            scale!(res, 2.0)
            @fact res[1,:,1] --> roughly(zeros(sbp.numnodes), atol=5e-13)
            @fact res[2,:,1] --> roughly(dudx[2,:,1], atol=5e-13)
            @fact res[1,:,2] --> roughly(zeros(sbp.numnodes), atol=5e-13)
            @fact res[2,:,2] --> roughly(dudx[2,:,2], atol=5e-13)
          end
        end
      end 
    end
  end
  
  for TSBP = (getTriSBPGamma, getTriSBPOmega, getTriSBPDiagE)
    @eval begin
      context("Testing differentiate! ("string($TSBP)" vector field method)") do      
        # build a two element grid, and verify that Dxi*x = 0.5 or 0, depending on
        # orientation of local coordinates
        for p = 1:4
          sbp = ($TSBP)(degree=p)
          vtx = [0. 0.; 1. 0.; 0. 1.]
          x = zeros(Float64, (2,sbp.numnodes,2))
          x[:,:,1] = calcnodes(sbp, vtx)
          vtx = [1. 0.; 1. 1.; 0. 1.]
          x[:,:,2] = calcnodes(sbp, vtx)
          di = 1
          res = zeros(x)
          differentiate!(sbp, di, x, res)
          @fact vec(res[1,:,1]) --> roughly(0.5.*ones(sbp.numnodes), atol=5e-13)
          @fact vec(res[2,:,1]) --> roughly(zeros(sbp.numnodes), atol=5e-13)
          @fact vec(res[1,:,2]) --> roughly(zeros(sbp.numnodes), atol=5e-13)
          @fact vec(res[2,:,2]) --> roughly(0.5.*ones(sbp.numnodes), atol=5e-13)
        end
      end
    end
  end

  for TSBP = (getTetSBPGamma, getTetSBPOmega, getTetSBPDiagE)
    @eval begin
      context("Testing differentiate! ("string($TSBP)" vector field method)") do
        # build a single element grid, and verify that Dxi * x = 0.5 or 0, depending
        # on orientation of local coordinates
        for p = 1:4
          sbp = ($TSBP)(degree=p)
          vtx = [0. 0. 0.; 1. 0. 0.; 0. 1. 0.; 0. 0. 1.]
          x = zeros(Float64, (3,sbp.numnodes,1))
          x[:,:,1] = calcnodes(sbp, vtx)
          di = 1
          res = zeros(x)
          differentiate!(sbp, di, x, res)
          @fact vec(res[1,:,1]) --> roughly(0.5.*ones(sbp.numnodes), atol=5e-12)
          @fact vec(res[2,:,1]) --> roughly(zeros(sbp.numnodes), atol=5e-12)
          @fact vec(res[3,:,1]) --> roughly(zeros(sbp.numnodes), atol=5e-12)
        end
      end
    end
  end

  for TSBP = (getLineSegSBPLobbato, getLineSegSBPLegendre)
    @eval begin
      context("Testing differentiateElement! ("string($TSBP)" scalar field method)") do
        # verify the accuracy of the element level differentiation operators
        for d = 1:4
          sbp = ($TSBP)(degree=d)
          vtx = sbp.vtx
          x = calcnodes(sbp, vtx)
          x = reshape(x, (sbp.numnodes,1))
          for i = 0:d
            u = x.^i
            dudx = i.*x.^max(0,i-1)
            res = zeros(u)
            differentiateElement!(sbp, 1, view(u,:,1), view(res,:,1))
            @fact res --> roughly(dudx, atol=5e-13)
          end
        end
      end 
    end
  end

  for TSBP = (getTriSBPGamma, getTriSBPOmega, getTriSBPDiagE)
    @eval begin
      context("Testing differentiateElement! ("string($TSBP)" scalar field method)") do
        # verify the accuracy of the element level differentiation methods
        for d = 1:4
          sbp = ($TSBP)(degree=d)
          cub, vtx = getTriCubatureGamma(2*d-1, Float64)
          xy = calcnodes(sbp, vtx)
          x = zeros(Float64, (sbp.numnodes,1))
          y = zeros(x)
          x[:,1] = vec(xy[1,:]); y[:,1] = vec(xy[2,:])
          for r = 0:d
            for j = 0:r
              i = r-j
              u = (x.^i).*(y.^j)
              dudx = (i.*x.^max(0,i-1)).*(y.^j)          
              dudy = (x.^i).*(j.*y.^max(0,j-1))
              res = zeros(u)
              differentiateElement!(sbp, 1, view(u,:,1), view(res,:,1))
              @fact res --> roughly(dudx, atol=5e-13)
              res = zeros(u)
              differentiateElement!(sbp, 2, view(u,:,1), view(res,:,1))
              @fact res --> roughly(dudy, atol=5e-13)
            end
          end
        end
      end
    end
  end

  for TSBP = (getTetSBPGamma, getTetSBPOmega, getTetSBPDiagE)
    @eval begin
      context("Testing differentiateElement! ("string($TSBP)" scalar field method)") do
        # verify the accuracy of the differentiation operators
        for d = 1:4
          sbp = ($TSBP)(degree=d)
          vtx = sbp.vtx
          xyz = calcnodes(sbp, vtx)
          x = zeros(Float64, (sbp.numnodes,1))
          y = zeros(x)
          z = zeros(x)
          x[:,1] = vec(xyz[1,:]); y[:,1] = vec(xyz[2,:]); z[:,1] = vec(xyz[3,:])
          for r = 0:d
            for k = 0:r
              for j = 0:r-k
                i = r-j-k
                u = (x.^i).*(y.^j).*(z.^k)
                dudx = (i.*x.^max(0,i-1)).*(y.^j).*(z.^k)
                dudy = (x.^i).*(j.*y.^max(0,j-1)).*(z.^k)
                dudz = (x.^i).*(y.^j).*(k.*z.^max(0,k-1))
                res = zeros(u)
                differentiateElement!(sbp, 1, view(u,:,1), view(res,:,1))
                @fact res --> roughly(dudx, atol=5e-12)
                res = zeros(u)
                differentiateElement!(sbp, 2, view(u,:,1), view(res,:,1))
                @fact res --> roughly(dudy, atol=5e-12)
                res = zeros(u)
                differentiateElement!(sbp, 3, view(u,:,1), view(res,:,1))
                @fact res --> roughly(dudz, atol=5e-12)
              end
            end
          end
        end
      end
    end
  end

  for TSBP = (getLineSegSBPLobbato, getLineSegSBPLegendre)
    @eval begin
      context("Testing differentiateElement! ("string($TSBP)" vector field method)") do
        # verify the accuracy of the element level differentiation operators
        for d = 1:4
          sbp = ($TSBP)(degree=d)
          vtx = reshape([0.0; 1.0], (2,1))
          x = ones(Float64, (2,sbp.numnodes,2))
          x[2,:,1] = calcnodes(sbp, vtx)          
          vtx = reshape([1.0; 2.0], (2,1))
          x[2,:,2] = calcnodes(sbp, vtx)
          for i = 0:d
            u = x.^i
            dudx = i.*x.^max(0,i-1)
            res = zeros(u)
            differentiateElement!(sbp, 1, view(u,:,:,1), view(res,:,:,1))
            differentiateElement!(sbp, 1, view(u,:,:,2), view(res,:,:,2))
            # account for mapping Jacobian
            scale!(res, 2.0)
            @fact res[1,:,1] --> roughly(zeros(sbp.numnodes), atol=5e-13)
            @fact res[2,:,1] --> roughly(dudx[2,:,1], atol=5e-13)
            @fact res[1,:,2] --> roughly(zeros(sbp.numnodes), atol=5e-13)
            @fact res[2,:,2] --> roughly(dudx[2,:,2], atol=5e-13)
          end
        end
      end 
    end
  end

  for TSBP = (getTriSBPGamma, getTriSBPOmega, getTriSBPDiagE)
    @eval begin
      context("Testing differentiateElement! ("string($TSBP)" vector field method)") do
        # build a two element grid, and verify that Dxi*x = 0.5 or 0, depending on
        # orientation of local coordinates
        for p = 1:4
          sbp = ($TSBP)(degree=p)
          vtx = [0. 0.; 1. 0.; 0. 1.]
          x = zeros(Float64, (2,sbp.numnodes,2))
          x[:,:,1] = calcnodes(sbp, vtx)
          vtx = [1. 0.; 1. 1.; 0. 1.]
          x[:,:,2] = calcnodes(sbp, vtx)
          di = 1
          res = zeros(x)
          differentiateElement!(sbp, di, view(x,:,:,1), view(res,:,:,1))
          differentiateElement!(sbp, di, view(x,:,:,2), view(res,:,:,2))
          @fact vec(res[1,:,1]) --> roughly(0.5.*ones(sbp.numnodes), atol=5e-13)
          @fact vec(res[2,:,1]) --> roughly(zeros(sbp.numnodes), atol=5e-13)
          @fact vec(res[1,:,2]) --> roughly(zeros(sbp.numnodes), atol=5e-13)
          @fact vec(res[2,:,2]) --> roughly(0.5.*ones(sbp.numnodes), atol=5e-13)
        end
      end
    end
  end

  for TSBP = (getTetSBPGamma, getTetSBPOmega, getTetSBPDiagE)
    @eval begin
      context("Testing differentiateElement! ("string($TSBP)" vector field method)") do
        # build a single element grid, and verify that Dxi * x = 0.5 or 0, depending
        # on orientation of local coordinates
        for p = 1:4
          sbp = ($TSBP)(degree=p)
          vtx = [0. 0. 0.; 1. 0. 0.; 0. 1. 0.; 0. 0. 1.]
          x = zeros(Float64, (3,sbp.numnodes,1))
          x[:,:,1] = calcnodes(sbp, vtx)
          di = 1
          res = zeros(x)
          differentiateElement!(sbp, di, view(x,:,:,1), view(res,:,:,1))
          @fact vec(res[1,:,1]) --> roughly(0.5.*ones(sbp.numnodes), atol=5e-12)
          @fact vec(res[2,:,1]) --> roughly(zeros(sbp.numnodes), atol=5e-12)
          @fact vec(res[3,:,1]) --> roughly(zeros(sbp.numnodes), atol=5e-12)
        end
      end
    end
  end

end
