function[varargout]=polysmooth(varargin)
%POLYSMOOTH  Smoothing scattered 2D data with local polynomial fitting.
%
%   POLYSMOOTH generates a map from scattered data in two dimensions---
%   either on the plane or on the sphere---using a local least squares fit 
%   to a polynomial. 
%
%   A numerically efficient algorithm is used that avoids explicit loops. 
%   Also, the data are pre-sorted so that different mapping parameters can 
%   be tried out at little computational expense.
%
%   For algorithm details, see Lilly and Lagerloef (2018).
%   __________________________________________________________________
%
%   Smoothing on the plane
%
%   Let's say we have an array Z of data is at locations X,Y, where X,Y, 
%   and Z are all arrays of the same size.  The problem is to obtain a 
%   mapped field ZHAT on some regular grid specified by arrays XO and YO.
%
%   Calling POLYSMOOTH is a two-step process: 
%
%       [DS,XS,YS,ZS]=TWODSORT(X,Y,Z,XO,YO,CUTOFF);
%       ZHAT=POLYSMOOTH(DS,XS,YS,ZS,B,P);
%
%   Firstly, TWODSORT which returns ZS, a 3D array of data values at each 
%   grid point, sorted by increasing distance DS, and the corresponding 
%   positions XS and YS. Here XO and YO are arrays specifying the bin 
%   center locations of the grid.  See TWODSORT for more details.
%  
%   Here CUTOFF determines the maximum distance included in the sorting 
%   and should be chosen to be greater than B.  
%
%   Secondly, POLYSMOOTH fits a Pth order polynomial at each gridpoint 
%   within a neighborhood specified by the "bandwidth" B.  
%
%   Data and grid point locations are presumed to have the same units as
%   the bandwidth B (e.g., kilometers).
%
%   P may be chosen as P=0 (fit to a constant), P=1 (fit to a plane), or
%   else P=2 (fit to a parabolic surface).  
%
%   POLYSMOOTH can also be used for data on the sphere, as described next.
%   __________________________________________________________________
%
%   Smoothing on the sphere
%
%   POLYSMOOTH supports a local polynomial fit on the sphere.  As before 
%   this is a two-step process:
%
%       [DS,XS,YS,ZS]=SPHERESORT(LAT,LON,Z,LATO,LONO,CUTOFF);
%       ZHAT=POLYSMOOTH(DS,XS,YS,ZS,B,P,'sphere') 
%
%   Firstly one calls SPHERESORT, which is the analogue of TWODSORT for the 
%   sphere.  LATO and LONO are arrays specifying the bin center locations 
%   of the grid.  See SPHERESORT for more details.
%
%   Secondly, POLYSMOOTH fits a Pth order polynomial at each gridpoint 
%   within a neighborhood specified by the "bandwidth" B.  The bandwidth 
%   here should have units of kilometers. 
%
%   Note that SPHERESORT and POLYSMOOTH both assume the sphere to be the 
%   radius of the earth, as specified by the function RADEARTH.
%   __________________________________________________________________
%
%   Multiple bandwidths
%
%   Note that the bandwidth B may be an array, in which case ZHAT, as well
%   as the other output fields described below, will have LENGTH(B) 'pages'
%   along their third dimensions.
%
%   This can result in a significant speed improvement compared with 
%   calling POLYSMOOTH by looping over multiple bandwith values.  The 
%   reason is that POLYSMOOTH performs a computationally expensive initial
%   sort to remove non-finite values from the grid.  In calling POLYSMOOTH
%   with an array-valued B, this sort only need to be performed one time.
%   __________________________________________________________________
%
%   Additional options
%   
%   A number of different options are possible, as descibed below.  These  
%   are specified with trailing string arguments, which can be given in any
%   order provided they are after the numeric arguments.
%   __________________________________________________________________
%
%   Choice of weighting function or kernel
%
%   POLYSMOOTH(...,STR) weights the data points in the vicinity of each
%   grid point by some decaying function of distance called the kernel
%   or weighting function, specified by STR. 
%
%   All choices of weighting function are set to vanish for DS>B.
%
%   POLYSMOOTH(...,'gau'), the default behavior, uses a Gaussian kernel
%   with a standard deviation of B/3, W=EXP(-1/2*(3*DS/B)^2). 
%
%   POLYSMOOTH(...,'epa') uses the Epanechnikov kernel W=1-(DS/B)^2. 
%
%   POLYSMOOTH(...,'bis') uses the bisquare kernel W=(1-(DS/B)^2)^2.
%
%   POLYSMOOTH(...,'tri') uses the tricubic kernel W=(1-(DS/B)^3)^3.
%
%   POLYSMOOTH(...,'uni') uses the uniform kernel, W=1.
%
%   POLYSMOOTH(...,'ker',K) uses the kernel specified by the vector K. The
%   kernel values are linearly interpolated from K, with K(1) corresponding
%   to DS/B=0 and K(end) to DS/B=1.
%   __________________________________________________________________
%
%   Additional output arguments
%
%   [ZHAT,R,N,T,C]=POLYSMOOTH(...) returns the weighted mean distance R to
%   all the data points used at each grid point, the number N of such data
%   points, the total weight T, and the matrix condition number C.  All are
%   the same size as ZHAT.
%
%   R is computed using the same weighting function as for the mapping. 
%   Large R values mean that a typical data point contribution was far from
%   the current grid point, indicated that ZHAT is potentially biased.   
%
%   For uniform data spacing with the Epanechnikov kernel, the weighted 
%   mean radius R is 0.533*B, while for the Gaussian kernel it is 0.410*B.
%
%   Small numbers N of enclosed data points means that little averaging was
%   involved, indicating that the values of ZHAT may be more subject to
%   variance, and/or less representative, than at points where N is large.
%
%   T is the sum over all weights used at each grid point, another way to 
%   describe the way data was used at each grid point.
%
%   Note that R and T include the effect of the additional weighting 
%   factor, if input as described below, whereas N does not.
%
%   The matrix condition number C is computed by COND.  At points where C
%   is large, the least squares solution may be unstable, and one should 
%   consider reverting to a lower-order solution.  Note that for zeroth-
%   order fit with P=0, the matrix condition number is equal to one. 
%   __________________________________________________________________
%
%   Estimated derivatives
%
%   As a part of the least squares problem, derivatives of order P and
%   lower are estimated as a part of the Pth-order fit. 
%
%   [ZHAT,R,N,T,C,ZX,ZY]=POLYSMOOTH(...) with P>1 returns the estimated X 
%   and Y, or zonal and meridional, derivatives of Z. 
%
%   [ZHAT,R,N,T,C,ZX,ZY,ZXX,ZXY,ZYY]=POLYSMOOTH(...) with P=2 similarly
%   returns the estimated second partial derivatives of Z.
%
%   Derivative fields are set to values of NaNs if they are not explicitly
%   computed, so for example, [ZHAT,R,N,T,C,ZX,ZY]=POLYSMOOTH(...) with P=0 
%   will lead to ZX and ZY being arrays of NaNs of the same size as ZHAT.
%   __________________________________________________________________
%
%   Fixed population
%
%   ZHAT=POLYSMOOTH(...,N,P,'population') varies the bandwidth such that it
%   is just large enough at each grid point to encompass N points. This is 
%   known as the 'fixed population' or 'variable bandwidth' algorithm.
%
%   [ZHAT,R,B,T,C]=POLYSMOOTH(...,N,P,'population') returns as its third 
%   output argument the bandwidth B at each gridpoint rather than the total
%   number of data points N, which is held fixed in this case.
%
%   The fixed population algorithm can give good results when the data
%   spacing is highly uneven, particularly when used with a higher-order
%   (P=1 or P=2) fit.  
%
%   Derivative fields may also be output in this case, as described above.
%
%   When using the fixed population method, check the length of the third
%   dimension of the fields output by SPHERESORT or TWODSORT.  It must be
%   at least N. If it is greater than N, it should be truncated to exactly 
%   N, thus reducing the size of those fields and speeding up calculations.
%   __________________________________________________________________
%
%   Weighted data points
%
%   POLYSMOOTH can incorporate an additional weighting factor on the data
%   points. Let W be an array of positive values the same size as the data 
%   array Z.  Each data point is then treated as if it were W data points.
%
%   To use weighted data points, call TWODSORT or SPHERESORT with W added:
%
%       [DS,XS,YS,ZS,WS]=TWODSORT(X,Y,Z,W,XO,YO,CUTOFF);           
%    or [DS,XS,YS,ZS,WS]=SPHERESORT(LAT,LON,Z,W,LATO,LONO,CUTOFF); 
%    
%   followed by    ZHAT=POLYSMOOTH(DS,XS,YS,ZS,WS,B,P);
%            or    ZHAT=POLYSMOOTH(DS,XS,YS,ZS,WS,B,P,'sphere');
%
%   for data distributed on the plane or on the sphere, respectively.
%
%   For very large datasets, this may be useful in first condensing the 
%   data into a manageable size, or alternatively it may be used to weight
%   observations according to a measure of their presumed quality.
%   __________________________________________________________________
%
%   Algorithms 
%
%   POLYSMOOTH has several algorithm choices for optimal performance, both  
%   of which give identical answers.
%
%   1) Speed optimization
%
%   The default algorithm is optimized for speed but uses a great deal of 
%   memory.  It solves the least squares problem for all grid points
%   simultaneously (by directly solving matrix inversions---see MATINV.)
%
%   This can be greater than an order of magnitude faster than the obvious 
%   approach of looping over the grid points, algorithm #3 below. 
% 
%   2) Parallelization
%
%   ZHAT=POLYSMOOTH(...,'parallel') parallelizes the computation using a 
%   PARFOR loop, by calling the default speed-optimized algorithm on each 
%   latitude (or matrix row) separately.  This can speed things up greatly. 
%
%   Be aware of your memory use when using this option.  If the memory use 
%   becomes too large, the parallel method will become very slow.  If this
%   happens, try calling POLYSMOOTH only on a subset of the data. 
%
%   Alternatively, it may sometimes be preferable to use the default
%   algorithm but to parallelize an external call to POLYSMOOTH.
%
%   This requires that Matlab's Parallel Computing toolbox be installed.
%
%   3) Memory optimization
%
%   ZHAT=POLYSMOOTH(...,'memory') performs an explicit loop.  This is 
%   mostly used for testing purposes, but may also be useful if the dataset
%   is so large that memory becomes a limiting factor.
%   __________________________________________________________________
%
%   'polysmooth --t' runs some tests.
%   'polysmooth --f' generates some sample figures.
%
%   Usage:  [ds,xs,ys,zs]=twodsort(x,y,z,xo,yo,cutoff);  
%           zhat=polysmooth(ds,xs,ys,zs,B,P);
%           [zhat,R,N,T,C]=polysmooth(ds,xs,ys,zs,B,P);
%   --or--
%           [ds,xs,ys,zs]=spheresort(lat,lon,z,w,lato,lono,cutoff); 
%           [zhat,R,N,T,C]=polysmooth(ds,xs,ys,zs,B,P,'sphere');
%   __________________________________________________________________
%   This is part of JLAB --- type 'help jlab' for more information
%   (C) 2008--2018 J.M. Lilly --- type 'help jlab_license' for details
 
%   This is not helping.  

%   'polysmooth --f2' with jData installed generates the figure shown
%       above, which may require a relatively powerful computer.

if strcmpi(varargin{1}, '--t')
    polysmooth_test,return
elseif strcmpi(varargin{1}, '--f')
    type makefigs_polysmooth
    makefigs_polysmooth;
    return
elseif strcmpi(varargin{1}, '--f2')
    type makefigs_polysmooth2
    makefigs_polysmooth2;
    return
end

str='speed';
kernstr='gaussian';
%kernstr='epanechnikov';
geostr='cartesian';
varstr='constant';


for i=1:5
    if ischar(varargin{end})
        tempstr=varargin{end};
        if strcmpi(tempstr(1:3),'epa')||strcmpi(tempstr(1:3),'gau')||...
                strcmpi(tempstr(1:3),'bis')||strcmpi(tempstr(1:3),'tri')||strcmpi(tempstr(1:3),'uni')
            kernstr=tempstr;
        elseif strcmpi(tempstr(1:3),'car')||strcmpi(tempstr(1:3),'sph')
            geostr=tempstr;
        elseif strcmpi(tempstr(1:3),'spe')||strcmpi(tempstr(1:3),'loo')||strcmpi(tempstr(1:3),'mem')||strcmpi(tempstr(1:3),'par')
            str=tempstr;
        elseif strcmpi(tempstr(1:3),'con')||strcmpi(tempstr(1:3),'pop')
            varstr=tempstr;
        end
        varargin=varargin(1:end-1);
    elseif ischar(varargin{end-1})
        if strcmpi(varargin{end-1}(1:3),'ker')||strcmpi(varargin{end-1}(1:3),'gau')
            %In this case, kernstr is not a string
            kernstr=varargin{end};
            varargin=varargin(1:end-2);
        end
    end
end

R=varargin{end};
B=varargin{end-1};

na=length(varargin)-2;

if strcmpi(str(1:3),'spe')||strcmpi(str(1:3),'mem')||strcmpi(str(1:3),'par')
    d=varargin{1};
    x=varargin{2};
    y=varargin{3};
    z=varargin{4};
    if na==5
        w=varargin{5};
    else
        w=ones(size(z));
    end
elseif strcmpi(str(1:3),'loo')
    x=varargin{1};
    y=varargin{2};
    z=varargin{3};
    if na==5
        w=ones(size(z));
        xo=varargin{4};
        yo=varargin{5};
    elseif na==6
        w=varargin{4};
        xo=varargin{5};
        yo=varargin{6};
    end
end

%Set distance to nan for missing data; also swap infs for nans
d(~isfinite(z))=nan;

%--------------------------------------------------------------------------
%This can speed things up if you have a lot of missing data. If you don't 
%sort, then you end up doing a lot of extra operations, because you can't 
%truncate the matrix.

%bool will be true if current point is finite, but previous is not
bool1=isnan(z);
bool2=isnan(vshift(z,-1,3));bool2(:,:,1)=false;
bool=(sum(~bool1&bool2,3)>0)&~(sum(bool1,3)==size(bool1,3));

if anyany(bool)&&~strcmpi(str(1:3),'loo')
    disp('Detecting NaNs in Z...  sorting to exclude these points.')
    [d,kk]=sort(d,3);
    ii=vrep(vrep([1:size(d,1)]',size(d,2),2),size(d,3),3);
    jj=vrep(vrep([1:size(d,2)],size(d,1),1),size(d,3),3);
    index=sub2ind(size(d),ii,jj,kk);
    x=x(index);y=y(index);z=z(index);w=w(index);
    disp('Sorting complete.')
end
%--------------------------------------------------------------------------

%This is for correctly handling the case that the input B is the same size
%as the grid we want to map to, thus specifying a spatially varying B
ismatB=allall(size(B)==size(d(:,:,1)))&&~strcmpi(str(1:3),'loo');
if ~ismatB
    L=length(B);
else
    L=1;
end

for i=1:L
    if ~ismatB
        Bi=B(i);
    else
        Bi=B;
    end
    if strcmpi(varstr(1:3),'pop')
        %For fixed population, we don't need to pass the whole array
        kk=1:maxmax(Bi);
        if strcmpi(str(1:3),'loo')
            [beta,rbar,Bmat,numpoints,C,W]=polysmooth_loop(x,y,z,w,xo,yo,Bi,R,varstr,kernstr,geostr);
        elseif strcmpi(str(1:3),'spe')
            [beta,rbar,Bmat,numpoints,C,W]=...
                polysmooth_fast(d(:,:,kk),x(:,:,kk),y(:,:,kk),z(:,:,kk),w(:,:,kk),Bi,R,varstr,kernstr);
        elseif strcmpi(str(1:3),'par')
            [beta,rbar,Bmat,numpoints,C,W]=...
                polysmooth_parallel(d(:,:,kk),x(:,:,kk),y(:,:,kk),z(:,:,kk),w(:,:,kk),Bi,R,varstr,kernstr);
        elseif strcmpi(str(1:3),'mem')
            [beta,rbar,Bmat,numpoints,C,W]=...
                polysmooth_memory(d(:,:,kk),x(:,:,kk),y(:,:,kk),z(:,:,kk),w(:,:,kk),Bi,R,varstr,kernstr);
        else
            error(['Algorithm type ' str ' is not supported.'])
        end
    else
        if strcmpi(str(1:3),'loo')
            [beta,rbar,Bmat,numpoints,C,W]=polysmooth_loop(x,y,z,w,xo,yo,Bi,R,varstr,kernstr,geostr);
        elseif strcmpi(str(1:3),'spe')
            [beta,rbar,Bmat,numpoints,C,W]=polysmooth_fast(d,x,y,z,w,Bi,R,varstr,kernstr);
        elseif strcmpi(str(1:3),'par')
            [beta,rbar,Bmat,numpoints,C,W]=polysmooth_parallel(d,x,y,z,w,Bi,R,varstr,kernstr);
        elseif strcmpi(str(1:3),'mem')
            [beta,rbar,Bmat,numpoints,C,W]=polysmooth_memory(d,x,y,z,w,Bi,R,varstr,kernstr);
        else
            error(['Algorithm type ' str ' is not supported.'])
        end
    end
    %Adjustment for complex-valued data
    if ~allall(isreal(z))
        beta(isnan(real(beta(:))))=nan+sqrt(-1)*nan;
    end
    varargout{1}(:,:,i)=beta(:,:,1);
    varargout{2}(:,:,i)=rbar;
    if strcmpi(varstr(1:3),'con')
        varargout{3}(:,:,i)=numpoints;
    else
        varargout{3}(:,:,i)=Bmat;
    end
    varargout{4}(:,:,i)=W;
    varargout{5}(:,:,i)=C;
    if size(beta,3)>=3
        varargout{6}(:,:,i)=beta(:,:,2);
        varargout{7}(:,:,i)=beta(:,:,3);
    else
        varargout{6}(:,:,i)=beta(:,:,1)*nan;
        varargout{7}(:,:,i)=beta(:,:,1)*nan;
    end
    if size(beta,3)>=6
        varargout{8}(:,:,i)=beta(:,:,4);
        varargout{9}(:,:,i)=beta(:,:,5);
        varargout{10}(:,:,i)=beta(:,:,6);
    else
        varargout{8}(:,:,i)=beta(:,:,1)*nan;
        varargout{9}(:,:,i)=beta(:,:,1)*nan;
        varargout{10}(:,:,i)=beta(:,:,1)*nan;
    end
end


function[B]=polysmooth_bandwidth(varstr,B,M,N,d,w)

if strcmpi(varstr(1:3),'con')
    if ~ismatrix(d)  %Only do this for the 'fast' algorithm
        if length(B)==1
            B=B+zeros(size(d(:,:,1)));
        end
    end
    if minmin(B)<=0
        error('With fixed bandwidth algorithm, bandwidth must be positive.')
    end
else
    %Convert number of points input to equivalent bandwidth
    N=ceil(B);%What I've actually input is the number of points we want to keep
    
    if minmin(N)<=1
        error('With fixed population algorithm, population must be greater than one.')
    end
    %If a matrix-valued number of points was entered, need to replicate
    %the matrix along the third dimension to make the rest of the code work
    
    %size(d),size(N)
    if ~ismatrix(d)
        if aresame(size(N),size(d(:,:,1)))
            N=vrep(N,size(d,3),3);
        end
    end
    
    w(~isfinite(d))=0; %Important line, makes us handle missing data correctly
    %Compute number of data points with potential for weighted points
    if  ismatrix(d) %false if ndims>=3
        B=nan;
        cumw=cumsum(double(w),1);
        index=find(cumw>=N,1,'first');
        if ~isempty(index)
            B=squeeze(d(index));
        end
    else  %Only do this for the 'fast' algorithm
        B=nan*zeros(size(d,1),size(d,2));
        cumw=cumsum(double(w),3);
        %vsize(d,B,cumw,N) 
        d(cumw<N)=nan;
        B=min(d,[],3);  %Loopless way to find bandwith
%         %This is the same as the above  
%         for i=1:size(d,1)
%             for j=1:size(d,2)
%                 index=find(cumw(i,j,:)>=N,1,'first');
%                 if ~isempty(index)
%                     B(i,j)=squeeze(d(i,j,index));
%                 end
%             end
%         end
    end
end
function[beta,rbar,B,numpoints,C,W]=polysmooth_parallel(ds,xs,ys,zs,ws,B0,R,varstr,kernstr)


M=size(xs,1);
N=size(xs,2);

P=sum(0:R+1);

beta=nan*zeros(M,N,P);
[rbar,C,B,W]=vzeros(M,N,nan);
numpoints=zeros(M,N);

%This way is actually slower than the fast method
parfor i=1:M
  [beta(i,:,:),rbar(i,:),B(i,:),numpoints(i,:),C(i,:),W(i,:)]=...
      polysmooth_fast(ds(i,:,:),xs(i,:,:),ys(i,:,:),zs(i,:,:),ws(i,:,:),B0,R,varstr,kernstr)
end

% This way tends to make things crash
% pool=gcp;
% Nworkers=pool.NumWorkers;
% for i=1:Nworkers
%     index{i}=i:Nworkers:N;
% end
% 
% Nworkers
% parfor i=1:length(index)
%      jj=index{i};
%      [beta(i,:,:),rbar(i,:),B(i,:),numpoints(i,:),C(i,:)]=...
%          polysmooth_fast(ds(:,jj,:),xs(:,jj,:),ys(:,jj,:),zs(:,jj,:),ws(:,jj,:),B0,R,varstr,kernstr);
% end

function[beta,rbar,B,numpoints,C,Wsum]=polysmooth_fast_experimental(ds,xs,ys,zs,ws,B,R,varstr,kernstr)
%Additional modifications here to prevent needless multiplications, but the
%effect appears minimal.  Not worth the trouble.  But I'm leaving this
%here as a reminder to myself that I tried it. 

M=size(xs,1);
N=size(xs,2);

B=polysmooth_bandwidth(varstr,B,M,N,ds,ws); 
B=vrep(B,size(xs,3),3);

P=sum(0:R+1);

beta=nan*zeros(M,N,P);
[rbar,C,Wsum]=vzeros(M,N,nan);
numpoints=zeros(M,N);

%Initial search to exclude right away points too far away
ds(ds>B)=nan;
numgood=squeeze(sum(sum(isfinite(ds),2),1));
index=find(numgood~=0,1,'last');

if ~isempty(index)
    vindex(ds,xs,ys,zs,ws,B,1:index,3);
    if anyany(ws~=1)
        W=polysmooth_kern_dist(ds,B,kernstr).*ws;  %ws for weighted data points
    else
        W=polysmooth_kern_dist(ds,B,kernstr); 
    end
    
    Wsum=sum(W,3,'omitnan');
    numpoints=sum((W>0)&~isnan(W),3);
    rbar=sum(W.*ds,3,'omitnan')./Wsum;

    vswap(ds,xs,ys,zs,W,0,nan);
    
    Wmat=vrep(W,P,4);
    bool=~isnan(Wmat);
    X=polysmooth_xmat(xs,ys,R);    
    XtimesW=X(bool).*Wmat(bool);  
    %Only need to keep that part of XtimesW for which there are good values
    
    %vsize(X,W,XtimesW)
    
    mat=zeros(M,N,P,P);
    vect=zeros(M,N,P);

    for i=1:size(X,4)
        Xmat=vrep(X(:,:,:,i),P,4);
        temp=nan*zeros(size(Xmat));
        temp(bool)=XtimesW.*Xmat(bool);
        mat(:,:,:,i)=sum(temp,3,'omitnan');
        %mat(:,:,:,i)=sum(XtimesW.*vrep(X(:,:,:,i),P,4),3);
   end
    
    zsmat=vrep(zs,P,4);
    temp=nan*zeros(size(zsmat));
    temp(bool)=XtimesW.*zsmat(bool);
    vect=sum(temp,3,'omitnan');
    %vect=sum(XtimesW.*vrep(zs,P,4),3);
    
    vect=permute(vect,[1 2 4 3]);
    for i=1:N
        for j=1:M
            C(j,i)=cond(squeeze(mat(j,i,:,:)));
        end
    end
    C(isinf(C))=nan;
    
    if P==1
        vswap(mat,0,nan);
        beta=vect./mat;
    else 
        beta=matmult(matinv(mat),vect,3);
    end
end
B=B(:,:,1);


function[beta,rbar,B,numpoints,C,Wsum]=polysmooth_fast(ds,xs,ys,zs,ws,B,R,varstr,kernstr)
 
M=size(xs,1);
N=size(xs,2);
 
B=polysmooth_bandwidth(varstr,B,M,N,ds,ws); 
B=vrep(B,size(xs,3),3);
 
P=sum(0:R+1);
 
beta=nan*zeros(M,N,P);
[rbar,C,Wsum]=vzeros(M,N,nan);
numpoints=zeros(M,N);
 
%Initial search to exclude right away points too far away
ds(ds>B)=nan;
numgood=squeeze(sum(sum(isfinite(ds),2),1));
index=find(numgood~=0,1,'last');
 
if ~isempty(index)
    vindex(ds,xs,ys,zs,ws,B,1:index,3);
    W=polysmooth_kern_dist(ds,B,kernstr).*ws;  %ws for weighted data points
    vswap(ds,xs,ys,zs,W,nan,0);%okay
    Wsum=sum(W,3);
    rbar=sum(W.*ds,3)./Wsum;
    numpoints=sum((W>0),3);
     
    X=polysmooth_xmat(xs,ys,R);
     
    XtimesW=X.*vrep(W,P,4);
    mat=zeros(M,N,P,P);
    vect=zeros(M,N,P);
 
    %size(mat),size(W),size(X)
    %vsize(ds,B,X,W,XtimesW,P),
    for i=1:size(X,4)
        mat(:,:,:,i)=sum(XtimesW.*vrep(X(:,:,:,i),P,4),3);
    end
    vect=sum(XtimesW.*vrep(zs,P,4),3);
    vect=permute(vect,[1 2 4 3]);
    for i=1:N
        for j=1:M
            C(j,i)=cond(squeeze(mat(j,i,:,:)));
        end
    end
    C(isinf(C))=nan;
     
    if P==1
        vswap(mat,0,nan);
        beta=vect./mat;
    else        
        beta=matmult(matinv(mat),vect,3);
    end
end
B=B(:,:,1);
 


function[beta,rbar,B,numpoints,C,Wsum]=polysmooth_memory(d,x,y,z,w,B,R,varstr,kernstr)

%tol=1e-10;
P=sum(0:R+1);

M=size(x,1);
N=size(x,2);

B=polysmooth_bandwidth(varstr,B,M,N,d,w);

beta=nan*zeros(M,N,P);
[rbar,C]=vzeros(M,N,nan);
[Wsum,numpoints]=vzeros(M,N);

for j=1:M
    %disp(['Polysmooth computing map for row ' int2str(j) '.'])
    for i=1:N
        [dist,xd,yd,zd,wd]=vsqueeze(d(j,i,:),x(j,i,:),y(j,i,:),z(j,i,:),w(j,i,:));
        
        W=polysmooth_kern_dist(dist,B(j,i),kernstr);
        
        index=find(W~=0&~isnan(zd));
        if ~isempty(index)
            vindex(xd,yd,zd,wd,index,1);
            
            Wsum(j,i)=sum(W(index).*wd);
            rbar(j,i)=sum(W(index).*dist(index).*wd)./Wsum(j,i);
            numpoints(j,i)=sum(W(index)>0);
            W=diag(W(index).*wd);  %Times wd for weighted data points
            X=squeeze(polysmooth_xmat(xd,yd,R));
            
            XW=conj(X')*W;
            mat=XW*X;
            C(j,i)=cond(mat);
            %if C(j,i)>tol;
                %beta(j,i,:)=inv(mat)*XW*zd;
            beta(j,i,:)=mat\(XW*zd);  %Following Checkcode's suggestion
            %end
        end
    end
end


function[beta,rbar,B,numpoints,C,Wsum]=polysmooth_loop(x,y,z,w,xo,yo,B0,R,varstr,kernstr,geostr)

%Explicit loop without pre-sorting, for testing purposes only
M=length(yo);
N=length(xo);

vsize(x,y,z,xo,yo,B0,R);

%tol=1e-10;
P=sum(0:R+1);

beta=nan*zeros(M,N,P);
[rbar,B,C]=vzeros(M,N,nan);
[Wsum,numpoints]=vzeros(M,N);

for j=1:M
    %Note that the slow method loops over the other direction for sphere
    %than the memory method
    %disp(['Polysmooth computing map for row ' int2str(j) '.'])
    for i=1:N
        if strcmpi(geostr(1:3),'sph')
            [xd,yd,dist]=latlon2xy(x,y,xo(i),yo(j));
            dist(dist>radearth*pi/2)=nan;  %Just in case
        else
            xd=x-xo(i);
            yd=y-yo(j);
            dist=sqrt(xd.^2+yd.^2);
        end
        zd=z;
        wd=w;

        [sortdist,sorter]=sort(dist);
        %%There are some confusing 0 distances coming from +/- 90 lat
        %if sortdist(2)==0
        %    figure,plot(x,y,'.')
        %    hold on, plot(xo(i),yo(j),'mo')
        %    hold on,plot(x(dist==0),y(dist==0),'g+')
        %end
        %sortdist(1:20)'
        
        %size(wd),size(sortdist)
        %size(polysmooth_bandwidth(varstr,B0,1,1,sortdist,wd(sorter)))
        B(j,i)=polysmooth_bandwidth(varstr,B0,1,1,sortdist,wd(sorter));
                
        %Correct for weird effect or repeated distances giving more than B0
        %points, which appears to be happening near the poles
        if strcmpi(varstr(1:3),'pop')
             if length(sortdist)>=B0
                sorter=sorter(1:B0);
             else
                %If not enough data points, set all to nan
                wd=nan.*wd;
             end
        end
             
        vindex(xd,yd,zd,wd,dist,sorter,1);
        W=polysmooth_kern_dist(dist,B(j,i),kernstr);
        X=squeeze(polysmooth_xmat(xd,yd,R));
        
        Wsum(j,i)=sum(W.*wd);
        rbar(j,i)=sum(W.*dist.*wd,'omitnan')./Wsum(j,i);
        %rbar(j,i)=sum();
        numpoints(j,i)=sum(W>0);
        
        W=diag(W.*wd);  %Times wd for weighted data points
        
        XW=conj(X')*W;
        mat=XW*X;
        if anyany(isnan(mat(:)))
            C(j,i)=nan;
        else
            C(j,i)=cond(mat);
        end
        C(isinf(C))=nan;
        beta(j,i,:)=mat\(XW*zd); %Following Checkcode's suggestion
    end
end



if strcmpi(geostr(1:3),'sph')
    beta=permute(beta,[2 1 3]);
    rbar=permute(rbar,[2 1]);
    numpoints=permute(numpoints,[2 1]);
    B=permute(B,[2 1]);
    C=permute(C,[2 1]);
    Wsum=permute(Wsum,[2 1]);
end

function[X]=polysmooth_xmat(x,y,R)
P=sum(0:R+1);
X=ones(size(x,1),size(x,2),size(x,3),P);
if R>0
    X(:,:,:,2)=x;
    X(:,:,:,3)=y;
end
if R>1
    X(:,:,:,4)=frac(1,2)*x.^2;   %See writeup
    X(:,:,:,5)=x.*y;
    X(:,:,:,6)=frac(1,2)*y.^2;   %See writeup
end


% function[W]=polysmooth_kern_xy(x,y,Binv,kernstr);
%
%
% if size(Binv,4)==1
%     xp=Binv.*x;
%     yp=Binv.*y;
% elseif size(Binv,4)==2
%     xp=Binv(:,:,:,1).*x;
%     yp=Binv(:,:,:,2).*y;
% %elseif size(Binv,3))==4
% %    xp=Binv(1,1).*x+Binv(1,2).*y;
%  %   yp=Binv(2,1).*x+Binv(2,2).*y;
% end
%
% distsquared=abs(xp).^2+abs(yp).^2;
%
% if strcmpi(kernstr(1:3),'epa')
%    W=frac(2,pi).*(1-distsquared).*(1+sign(1-sqrt(distsquared)));
% elseif strcmpi(lower(kernstr(1:3)),'gau')
%    W=frac(2,pi).*exp(-frac(distsquared,2));%Not right, should have frac(1,sigx*sigy)
% end

function[W]=polysmooth_kern_dist(dist,B,kernstr)

% if iscell(B)
%     N=B{2};
%     B=B{1};
% else
%     N=3;
% end
%vsize(dist,B)

dist=frac(dist,B);
W=zeros(size(dist));
bool=dist<1;
dist=dist(bool);

if ischar(kernstr)
    if strcmpi(kernstr(1:3),'epa')
        W(bool)=1-dist.^2;
    elseif strcmpi(kernstr(1:3),'gau')
        W(bool)=exp(-frac((3*dist).^2,2));
    elseif strcmpi(kernstr(1:3),'bis')
        W(bool)=(1-dist.^2).^2;
    elseif strcmpi(kernstr(1:3),'tri')
        W(bool)=(1-dist.^3).^3;
    elseif strcmpi(kernstr(1:3),'uni')
        W(bool)=1;
    end
elseif length(kernstr)==1
    %Variable Gaussian kernel
%    W(bool)=exp(-(1/2)*(dist.*kernstr).^2)-exp(-(1/2)*(kernstr).^2);
    W(bool)=exp(-(1/2)*(dist.*kernstr).^2);
else
    %Custom kernel
    K=kernstr(:);
    W(bool)=interp1((0:length(K)-1)'./(length(K)-1),K,dist);
end

%elseif iscell(kernstr)
%   if strcmpi(kernstr{1}(1:3),'hyb')
%   %Hybrid Gaussian kernel
%          W(bool)=exp(-(1/2)*(dist.*kernstr).^2)-exp(-(1/2)*(kernstr).^2);
%   elseif strcmpi(kernstr{1}(1:3),'mor')
%   %Morse kernel
%g=exp(-(1/2)*(x./(1/3)).^2);
% x=[0:0.01:1];
% sigma=1./[1:.5:10]';
% for i=1:length(sigma)
%     G(:,i)=exp(-(1/2)*(x./sigma(i)).^2)-exp(-(1/2)*(1./sigma(i)).^2);
%     G(:,i)=G(:,i)./max(G(:,i));
% end
%figure,plot(x,G)

% if strcmpi(kernstr(1:3),'epa')
%     %W=frac(2,pi).*(1-dist.^2).*(1+sign(1-dist));
%     W=(1-dist.^2).*(1+sign(1-dist));
% elseif strcmpi(kernstr(1:3),'gau')
%     %W=frac(2,pi.*B.^2).*exp(-frac(dist.^2,2)).*(1+sign(1-dist./N));
%     W=exp(-frac((3*dist).^2,2)).*(1+sign(1-dist));
% elseif strcmpi(kernstr(1:3),'bis')
%     W=((1-dist.^2).^2).*(1+sign(1-dist));
% elseif strcmpi(kernstr(1:3),'tri')
%     W=((1-dist.^3).^3).*(1+sign(1-dist));
% end

W=vswap(W,nan,0);

function[]=polysmooth_test

% x1=[-2:.001:2];
% [xg,yg]=meshgrid(x1,x1);
% r=sqrt(squared(xg)+squared(yg));
% W1=polysmooth_kern_dist(r,1,'epa');
% mean(W1(W1>0).*r(W1>0))./mean(W1(W1>0))
% W2=polysmooth_kern_dist(r,1,'gau');
% mean(W2(W2>0).*r(W2>0))./mean(W2(W2>0))
%figure,plot(W1*pi/2)
%polysmooth_test_cartesian;
tstart=tic;polysmooth_test_sphere;toc(tstart)
%polysmooth_test_tangentplane;

function[]=polysmooth_test_tangentplane

%Testing tangent plane equations from Lilly and Lagerloef
load goldsnapshot
use goldsnapshot

phip=vshift(lat,-1,1);
phin=vshift(lat,1,1);
thetap=vshift(lon,-1,1);
thetan=vshift(lon,1,1);

[long,latg]=meshgrid(lon,lat);
[thetapg,phipg]=meshgrid(thetap,phip);
[thetang,phing]=meshgrid(thetan,phin);

xp=radearth*cosd(lat).*sind(thetapg-long);
xn=radearth*cosd(lat).*sind(thetang-long);
yp=radearth*(cosd(latg).*sind(phipg)-sind(latg).*cosd(phipg));%.*cosd(thetapg-long));
yn=radearth*(cosd(latg).*sind(phing)-sind(latg).*cosd(phing));%.*cosd(thetang-long));

for i=1:4
    if i==1
        ssh=latg;
    elseif i==2
        ssh=squared(latg);
    elseif i==3
        ssh=squared(long);
    elseif i==4
        ssh=goldsnapshot.ssh;
    end
    
    sshp=vshift(ssh,-1,2);
    sshn=vshift(ssh,1,2);
    dZdx=frac(sshn-sshp,xn-xp);
    
    sshp=vshift(ssh,-1,1);
    sshn=vshift(ssh,1,1);
    dZdy=frac(sshn-sshp,yn-yp);
    
    [fx,fy]=spheregrad(lat,lon,ssh);
    fx=fx*1000;fy=fy*1000;
 
    %figure,
    %subplot(1,3,1),jpcolor(fx),caxis([-1 1]/5)
    %subplot(1,3,2),jpcolor(dZdx),caxis([-1 1]/5)
    %subplot(1,3,3),jpcolor(fx-dZdx),caxis([-1 1]/1000/1000/5)
    
    %figure
    %subplot(1,3,1),jpcolor(fy),caxis([-1 1]/5)
    %subplot(1,3,2),jpcolor(dZdy),caxis([-1 1]/5)
    %subplot(1,3,3),jpcolor(fy-dZdy),caxis([-1 1]/1000/1000/5)
    
    %Gradients agree to like one part in one million
    
    del2=spherelap(lat,lon,ssh)*1000*1000;
    
    sshp=vshift(ssh,-1,2);
    sshn=vshift(ssh,1,2);
    %d2Zdx2=frac(2,xn-xp).*(frac(sshn-ssh,xn)-frac(ssh-sshp,-xp));
    d2Zdx2=frac(1,squared((xn-xp)/2)).*(sshn+sshp-2*ssh);
    
    sshp=vshift(ssh,-1,1);
    sshn=vshift(ssh,1,1);
    %d2Zdy2=frac(2,yn-yp).*(frac(sshn-ssh,yn)-frac(ssh-sshp,-yp));
    d2Zdy2=frac(1,squared((yn-yp)/2)).*(sshn+sshp-2*ssh);
    
    del2hat=d2Zdx2+d2Zdy2-frac(tand(lat),radearth).*dZdy;
    %del2hat=d2Zdx2+d2Zdy2;%-frac(tand(lat),radearth).*dZdy;
        
    if i==1
        index=find(abs(latg)<89.5);
        bool=allall(log10(abs(del2hat(index)-del2(index))./abs(del2(index)))<-5);
        reporttest('POLYSMOOTH Laplacian of linear function of y',bool)
    elseif i==2
        %figure,plot(lat,log10(abs(del2))),hold on,plot(lat,log10(abs(del2-del2hat)))
        index=find(abs(latg)<88.5);
        bool=allall(log10(abs(del2hat(index)-del2(index)))<-8);
        reporttest('POLYSMOOTH Laplacian of quadratic function of y',bool)
    elseif i==3
        %figure, plot(lon,log10(abs(del2-del2hat)./abs(del2))')
        index=find(abs(long)<179);
        bool=allall(log10(abs(del2hat(index)-del2(index))./abs(del2(index)))<-5.99);
        reporttest('POLYSMOOTH Laplacian of quadratic function of x',bool)
    elseif i==4
        xx=log10(abs(fx-dZdx)./abs(fx));
        index=find(isfinite(xx));
        bool=allall(xx(index)<-6);
        reporttest('POLYSMOOTH longitude gradient of GOLDSNAPSHOT',bool)
        yy=log10(abs(fy-dZdy)./abs(fy));
        index=find(isfinite(yy));
        bool=allall(yy(index)<-6);
        reporttest('POLYSMOOTH latitude gradient of GOLDSNAPSHOT',bool)
        %figure
        %subplot(1,3,1),jpcolor(log10(abs(del2))),caxis([-3 0])
        %subplot(1,3,2),jpcolor(log10(abs(del2hat))),caxis([-3 0])
        %subplot(1,3,3),jpcolor(log10(abs(del2-del2hat))),caxis([-3 0])
    end
end

function[]=polysmooth_test_cartesian
% %Use peaks for testing... random assortment
% [x,y,z]=peaks;
% index=randperm(length(z(:)));
% [xdata,ydata,zdata]=vindex(x(:),y(:),z(:),index,1);
% 
% xo=(-3:.1:3);
% yo=(-3:.1:3);
% 
% B=1/4;
% 
% [ds,xs,ys,zs]=twodsort(xdata,ydata,zdata,xo,yo,B);    
% tic;z1=polysmooth(xdata,ydata,zdata,xo,yo,B,0,'epan','loop');etime1=toc;
% 

%Use peaks for testing... random assortment
[x,y,z]=peaks;
index=randperm(length(z(:)));
index=index(1:200);
[xdata,ydata,zdata]=vindex(x(:),y(:),z(:),index,1);

xo=(-3:.5:3);
yo=(-3:.6:3);

B=2;

[ds,xs,ys,zs]=twodsort(xdata,ydata,zdata,xo,yo,B);    
tic;[z1,R1,N1,T1,C1]=polysmooth(xdata,ydata,zdata,xo,yo,B,0,'epan','loop');etime1=toc;
tic;[z2,R2,N2,T2,C2]=polysmooth(ds,xs,ys,zs,B,0,'epan','memory');etime2=toc;
tic;[z3,R3,N3,T3,C3]=polysmooth(ds,xs,ys,zs,B,0,'epan','speed');etime3=toc;
tic;[z4,R4,N4,T4,C4]=polysmooth(ds,xs,ys,zs,B,0,'epan','parallel');etime4=toc;

disp(['POLYSMOOTH was ' num2str(etime1./etime3) ' times faster than loop, zeroth-order fit.'])
disp(['POLYSMOOTH was ' num2str(etime2./etime3) ' times faster than memory method, zeroth-order fit.'])
%disp(['POLYSMOOTH was ' num2str(etime3./etime4) ' times faster with parallelization, zeroth-order fit.'])

tol=1e-8;
b1=aresame(z1,z3,tol)&&aresame(R1,R3,tol)&&aresame(N1,N3,tol)&&aresame(C1,C3,tol)&&aresame(T1,T3,tol);
b2=aresame(z2,z3,tol)&&aresame(R2,R3,tol)&&aresame(N2,N3,tol)&&aresame(C2,C3,tol)&&aresame(T2,T3,tol);
b3=aresame(z4,z3,tol)&&aresame(R4,R3,tol)&&aresame(N4,N3,tol)&&aresame(C4,C3,tol)&&aresame(T4,T3,tol);

reporttest('POLYSMOOTH output size matches input size',aresame(size(z1),[size(xs,1) size(xs,2)]))
reporttest('POLYSMOOTH speed and loop methods are identical for zeroth-order fit',b1)
reporttest('POLYSMOOTH speed and memory methods are identical for zeroth-order fit',b2)
reporttest('POLYSMOOTH speed and parallel methods are identical for zeroth-order fit',b3)

tic;[z1,R1,N1,T1,C1,zx1,zy1]=polysmooth(xdata,ydata,zdata,xo,yo,B,1,'epan','loop');etime1=toc;
tic;[z2,R2,N2,T2,C2,zx2,zy2]=polysmooth(ds,xs,ys,zs,B,1,'epan','memory');etime2=toc;
tic;[z3,R3,N3,T3,C3,zx3,zy3]=polysmooth(ds,xs,ys,zs,B,1,'epan','speed');etime3=toc;
tic;[z4,R4,N4,T4,C4,zx4,zy4]=polysmooth(ds,xs,ys,zs,B,1,'epan','parellel');etime4=toc;

disp(['POLYSMOOTH was ' num2str(etime1./etime3) ' times faster than loop, linear fit.'])
disp(['POLYSMOOTH was ' num2str(etime2./etime3) ' times faster than memory method, linear fit.'])

tol=1e-8;
b1=aresame(z1,z3,tol)&&aresame(R1,R3,tol)&&aresame(N1,N3,tol)&&aresame(C1,C3,tol)&&aresame(T1,T3,tol)&&aresame(zx1,zx3,tol)&&aresame(zy1,zy3,tol);
b2=aresame(z2,z3,tol)&&aresame(R2,R3,tol)&&aresame(N2,N3,tol)&&aresame(C2,C3,tol)&&aresame(T2,T3,tol)&&aresame(zx2,zx3,tol)&&aresame(zy2,zy3,tol);
b3=aresame(z4,z3,tol)&&aresame(R4,R3,tol)&&aresame(N4,N3,tol)&&aresame(C4,C3,tol)&&aresame(T4,T3,tol)&&aresame(zx4,zx3,tol)&&aresame(zy4,zy3,tol);


reporttest('POLYSMOOTH speed and loop methods are identical for linear fit',b1)
reporttest('POLYSMOOTH speed and memory methods are identical for linear fit',b2)
reporttest('POLYSMOOTH speed and parallel methods are identical for linear fit',b3)


function[]=polysmooth_test_sphere
 
%Use peaks for testing... random assortment
[x,y,z]=peaks;
index=randperm(length(z(:)));
index=index(1:200);

%Convert to Lat and Longitude
lon=x.*60;
lat=y.*30;

[latdata,londata,zdata]=vindex(lat(:),lon(:),z(:),index,1);
wdata=10*abs(rand(size(zdata)));  %For heavy data point test

lono=(-180:20:180);
lato=(-90:20:90);

B=2000;

[ds,xs,ys,zs,ws]=spheresort(latdata,londata,zdata,wdata,lato,lono,B,'loop');

tic;[z1,R1,N1,T1,C1]=polysmooth(latdata,londata,zdata,lato,lono,B,0,'epan','sphere','loop');etime1=toc;
tic;[z2,R2,N2,T2,C2]=polysmooth(ds,xs,ys,zs,B,0,'epan','memory');etime2=toc;
tic;[z3,R3,N3,T3,C3]=polysmooth(ds,xs,ys,zs,B,0,'epan','speed');etime3=toc;
tic;[z4,R4,N4,T4,C4]=polysmooth(ds,xs,ys,zs,B,0,'epan','parallel');etime4=toc;

disp(['POLYSMOOTH was ' num2str(etime1./etime3) ' times faster than loop, zeroth-order fit on a sphere.'])
disp(['POLYSMOOTH was ' num2str(etime2./etime3) ' times faster than memory method, zeroth-order fit on a sphere.'])

tol=1e-8;
b1=aresame(z1,z3,tol)&&aresame(R1,R3,tol)&&aresame(N1,N3,tol)&&aresame(C1,C3,tol)&&aresame(T1,T3,tol);
b2=aresame(z2,z3,tol)&&aresame(R2,R3,tol)&&aresame(N2,N3,tol)&&aresame(C2,C3,tol)&&aresame(T2,T3,tol);
b3=aresame(z4,z3,tol)&&aresame(R4,R3,tol)&&aresame(N4,N3,tol)&&aresame(C4,C3,tol)&&aresame(T4,T3,tol);

reporttest('POLYSMOOTH output size matches input size on a sphere',aresame(size(z1),[size(xs,1) size(xs,2)]))
reporttest('POLYSMOOTH speed and loop methods are identical for zeroth-order fit on a sphere',b1)
reporttest('POLYSMOOTH speed and memory methods are identical for zeroth-order fit on a sphere',b2)
reporttest('POLYSMOOTH speed and parallel methods are identical for zeroth-order fit on a sphere',b3)


tic;[z1,R1,N1,T1,C1]=polysmooth(latdata,londata,zdata,wdata,lato,lono,B,0,'epan','sphere','loop');etime1=toc;
tic;[z2,R2,N2,T2,C2]=polysmooth(ds,xs,ys,zs,ws,B,0,'epan','memory');etime2=toc;
tic;[z3,R3,N3,T3,C3]=polysmooth(ds,xs,ys,zs,ws,B,0,'epan','speed');etime3=toc;
tic;[z4,R4,N4,T4,C4]=polysmooth(ds,xs,ys,zs,ws,B,0,'epan','parallel');etime4=toc;

tol=1e-8;
b1=aresame(z1,z3,tol)&&aresame(R1,R3,tol)&&aresame(N1,N3,tol)&&aresame(C1,C3,tol)&&aresame(T1,T3,tol);
b2=aresame(z2,z3,tol)&&aresame(R2,R3,tol)&&aresame(N2,N3,tol)&&aresame(C2,C3,tol)&&aresame(T2,T3,tol);
b3=aresame(z4,z3,tol)&&aresame(R4,R3,tol)&&aresame(N4,N3,tol)&&aresame(C4,C3,tol)&&aresame(T4,T3,tol);

reporttest('POLYSMOOTH speed and loop methods are identical with heavy data points',b1)
reporttest('POLYSMOOTH speed and memory methods are identical with heavy data points',b2)
reporttest('POLYSMOOTH speed and parallel methods are identical with heavy data points',b3)

B0=10;


[ds,xs,ys,zs]=spheresort(latdata,londata,zdata,lato,lono,radearth*pi/2-1e-3);

tic;[z1,R1,N1,T1,C1]=polysmooth(latdata,londata,zdata,lato,lono,B0,0,'epan','sphere','population','loop');etime1=toc;
tic;[z2,R2,N2,T2,C2]=polysmooth(ds,xs,ys,zs,B0,0,'epan','memory','population');etime2=toc;
tic;[z3,R3,N3,T3,C3]=polysmooth(ds,xs,ys,zs,B0,0,'epan','speed','population');etime3=toc;
tic;[z4,R4,N4,T4,C4]=polysmooth(ds,xs,ys,zs,B0,0,'epan','parallel','population');etime4=toc;

disp(['POLYSMOOTH was ' num2str(etime1./etime3) ' times faster than loop, zeroth-order 10-point fit on a sphere.'])
disp(['POLYSMOOTH was ' num2str(etime2./etime3) ' times faster than memory method, zeroth-order 10-point fit on a sphere.'])

tol=1e-8;
b1=aresame(z1,z3,tol)&&aresame(R1,R3,tol)&&aresame(N1,N3,tol)&&aresame(C1,C3,tol)&&aresame(T1,T3,tol);
b2=aresame(z2,z3,tol)&&aresame(R2,R3,tol)&&aresame(N2,N3,tol)&&aresame(C2,C3,tol)&&aresame(T2,T3,tol);
b3=aresame(z4,z3,tol)&&aresame(R4,R3,tol)&&aresame(N4,N3,tol)&&aresame(C4,C3,tol)&&aresame(T4,T3,tol);
%figure,plot(z1,'b'),hold on,plot(z3,'r.')

reporttest('POLYSMOOTH output size matches input size on a sphere',aresame(size(z1),[size(xs,1) size(xs,2)]))
reporttest('POLYSMOOTH speed and loop methods are identical for zeroth-order 10-point fit on a sphere',b1)
reporttest('POLYSMOOTH speed and memory methods are identical for zeroth-order 10-point fit on a sphere',b2)
reporttest('POLYSMOOTH speed and parallel methods are identical for zeroth-order 10-point fit on a sphere',b3)

% %Zeroth-order fit at 200~km radius
% [zhat0,rbar,beta,b]=polysmooth(ds,xs,ys,zs,200,0,'sphere');
% 
% figure
% contourf(lono,lato,zhat0,[0:1/2:50]),nocontours,caxis([0 45]),
% latratio(30),[h,h2]=secondaxes;topoplot continents,
% title('Standard Deviation of SSH from TPJAOS.MAT, mapped using 200~km smoothing')
% hc=colorbar('EastOutside');axes(hc);ylabel('SSH Standard Deviation (cm)')
% set(h,'position',get(h2,'position'))
% 
% currentdir=pwd;
% cd([whichdir('jlab_license') '/figures'])
% print -dpng alongtrack_std_constant
% crop alongtrack_std.png
% cd(currentdir)