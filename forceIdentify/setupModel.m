%This script file set up the model including the geometry, the mesh, the 
% coefficient functions in the equation and the boundary condition.

fprintf(1,'Set up the model : ');

localStartTime = cputime;

%Load parameters
%run([modelPath 'modelPar']);
run([resultPath 'setPar']);

load([modelPath 'recGeom']); %You get: 'recPGx', 'recPGy', ...
                  % 'recPGVI', 'bfDomPGx', 'bfDomPGy' and 'bfDomPGVI'.
%Get preprocessed experimental data: 'rawDispV', 'corLen', 'gridPx', 
% 'gridPy', 'gridU1', 'gridU2', 'sDataU1' and 'sDataU2'
load([resultPath 'dispField']); 

%Create the geometry for recovery from 'recPGx' and 'recPGy'. Since we need
% fine mesh for the myosin contraction region bounded by 'bfDomPG'. So, 
% we use 'rectmesh' and then define geometry with mesh as geometry.
if strcmp(meshType,'rectMesh')
   curvL = [recPGx(recPGVI(1):recPGVI(2)) recPGy(recPGVI(1):recPGVI(2))].';
   curvT = [recPGx(recPGVI(2):recPGVI(3)) recPGy(recPGVI(2):recPGVI(3))].';
   curvR = [recPGx(recPGVI(3):recPGVI(4)) recPGy(recPGVI(3):recPGVI(4))].';
   curvB = [recPGx(recPGVI(4):end) recPGy(recPGVI(4):end)].';
   %msh   = rectmesh(curvL,curvB,curvT,curvR,50,[0:0.025:0.5 0.6:0.1:1]);
   msh   = rectmesh(curvL,curvT,curvR,curvB,recHin,recVin);

   %vertEI   = find(msh.e(3,:)==0); 
   %numEdges = length(vertEI);
   numEdges = max(msh.e(5,:));
elseif strcmp(meshType,'femMesh')
   curve = geomspline([recPGx recPGy].', ...
      'splinemethod','centripetal','closed','auto');
   geom = geomcoerce('solid',{curve});
   numEdges = geominfo(geom,'Out',{'nbs'});
end

%Group subdomains and boundaries.
ind    = 1;
bndInd = 1:numEdges;

%Specify the boundary traction force.
fn.BndDispx  = cell(1,numEdges);
fn.BndDispy  = cell(1,numEdges);
fp.BndDispx  = cell(1,numEdges);
fp.BndDispy  = cell(1,numEdges);
fn.BndTracFx = cell(1,numEdges);
fn.BndTracFy = cell(1,numEdges);
fp.BndTracFx = cell(1,numEdges);
fp.BndTracFy = cell(1,numEdges);

for k = 1:numEdges
   %Specify zero boundary displacement initially.
   fn.BndDispx{k} = 0;
   fn.BndDispy{k} = 0;

   %Set up link to boundary traction force function.
   fn.BndTracFx{k} = 'spBndTF';
   fn.BndTracFy{k} = 'spBndTF';
   fp.BndTracFx{k} = {{'s'} {0}};
   fp.BndTracFy{k} = {{'s'} {0}};

   %Specify the type of boundary conditions.
   BCTypes{k} = 'Dirichlet';
end

options = elOptionsSet('EPType','YModulPRatio','BCType', ...
   BCTypes);

%Specify the body force.
fn.BodyFx = 'femBodyF';
fn.BodyFy = 'femBodyF';
fp.BodyFx = {{'x' 'y'} {[] 0}};
fp.BodyFy = {{'x' 'y'} {[] 0}};
   
if strcmp(fwdOpComputed,'fem') == 0
   clear fem; %Clear the 'fem' from simulation or the old 'fem'.
   if strcmp(meshType,'rectMesh') == 1
      fem = elModelAssemble([],msh,options,fn,fp,ind,bndInd);
   elseif strcmp(meshType,'femMesh') == 1
      if exist('domMeshPar') == 1
         fem = elModelAssemble(geom,domMeshPar,options,fn,fp,ind,bndInd);
      else
         fem = elModelAssemble(geom,[],options,fn,fp,ind,bndInd);
      end
      msh = fem.mesh;
   end

   save([modelPath 'femId'],'fem');
else
   load([modelPath 'femId'],'fem');
   msh = fem.mesh;
end

%Points where the forward computed displacements and raw displacements are
%compared for optimal fit can be either the raw data points or the
% interpolated grid points or both.
dataU1 = cell(numTimeSteps,1);
dataU2 = cell(numTimeSteps,1);
if strcmp(forceToIdentify,'tf') == 1
   load([resultPath 'dispId']);
   dataU1 = dataUC1;
   dataU2 = dataUC2;
elseif strcmp(dataToUse,'raw') == 1
   dataU1 = rawDataU1;
   dataU2 = rawDataU2;
elseif strcmp(dataToUse,'smooth') == 1
   dataU1 = sDataU1;
   dataU2 = sDataU2;
elseif strcmp(dataToUse,'simul') == 1
   load([resultPath 'simField']);
   dataPx{:} = simDataPx;
   dataPy{:} = simDataPy;

   %simulU1 = simulU1.*(1+noiseA*randn(size(simulU1)));
   %simulU2 = simulU2.*(1+noiseA*randn(size(simulU2)));
   numRealization = 50;
   nDataU1 = zeros(length(simulU1),numRealization);
   nDataU2 = zeros(length(simulU2),numRealization);

   dataU1{:} = (zeros(size(simulU1))).';
   dataU2{:} = (zeros(size(simulU2))).';

   simulUL = sqrt(simulU1.^2+simulU2.^2);
   for k = 1:numRealization
      nDataU1(:,k) = (simulU1+noiseA*simulUL.*randn(size(simulU1))).';
      nDataU2(:,k) = (simulU2+noiseA*simulUL.*randn(size(simulU2))).';
      dataU1{:} = dataU1{:}+nDataU1(:,k); 
      dataU2{:} = dataU2{:}+nDataU2(:,k); 
   end
   dataU1{:} = dataU1{:}/numRealization;
   dataU2{:} = dataU2{:}/numRealization;
else
   error('Unknown value for ''dataToUse''.');
end

%The data points must also be inside the target recovery region.
numDP = zeros(numTimeSteps,1);
for jj = 1:numTimeSteps
   [is,pe] = postinterp(fem,[dataPx{jj} dataPy{jj}].');
   dataPx{jj}(pe) = []; % 'pe': index of points outside 'msh'.
   dataPy{jj}(pe) = [];
   dataU1{jj}(pe) = [];
   dataU2{jj}(pe) = [];

   numDP(jj) = length(dataPx{jj});
end

%Calculate the displacements of the boundary elements of 'msh'. See
% 'help meshinit' for information about the MESH structure in FEMLAB.
% The geometry and mesh, 'msh' created by 'rectmesh' has four boundary edges
% parameterized by arclength. So, first identify the four edges.
% 'vertEI': Index into 'msh.e(3,:)' whose arclength is 0. It identifies the
% vertex of the edge.
% 'edgeI'   : Index into 'msh.p' to get the real coordinates of boundary points.
% 'bndEI'   : The index of boundary elements that belong to one edge.
% 'edgEndI  : The index of the boundary element that is at the end of one
%             edge.
% 'edgeP'   : The coordinates of boundary points on each edge.
% 'edgeU'   : The coordinates of the base and the point end of the displacement
%             vectors on each edge in the formate [x0 y0 x1 y1].
% 'edgeU1'  : The first and 
% 'edgeU2'  : the second components of the displacement vectors on each edge.
% 'edgeUC1' : For debugging. Has the same structure as 'edgeU1'.
% 'edgeUC2' : For debugging. Has the same structure as 'edgeU2'.
% 'edgeS'   : The arclength parameters of the boundary points on each edge.
% 'edgePPx' : The pp-form of the spline interpolation.

edgeS   = cell(1,numEdges);
edgeP   = cell(1,numEdges);
edgeU   = cell(1,numEdges);
edgArcLen = zeros(1,numEdges);
for k = 1:numEdges
   %Extract the arclenth parameters.
   bndEI = find(msh.e(5,:)==k);
   edgeS{k} = msh.e(3,bndEI);
   [edgeS{k},sortI] = sort(edgeS{k});
   edgEndI = bndEI(sortI(end));
   edgeS{k} = [edgeS{k} msh.e(4,edgEndI)];
   edgArcLen(k) = edgeS{k}(end);

   %Get the index of the boundary points.
   edgeI = msh.e(1,bndEI);
   edgeI = [edgeI(sortI) msh.e(2,edgEndI)];

   edgeP{k}  = [msh.p(1,edgeI); msh.p(2,edgeI)];
end

edgeU1  = cell(numTimeSteps,numEdges);
edgeU2  = cell(numTimeSteps,numEdges);
edgeUC1 = cell(numTimeSteps,numEdges);
edgeUC2 = cell(numTimeSteps,numEdges);
edgePPx = cell(numTimeSteps,numEdges);
edgePPy = cell(numTimeSteps,numEdges);
for jj = 1:numTimeSteps
   for k = 1:numEdges
      edgeU{k}  = vectorFieldSparseInterp(rawDispV{jj}, ...
         edgeP{k}(2:-1:1,:).',2*edgCorLen,edgCorLen,[]);
      %edgeU{k}  = vectorFieldInterp(rawDispV{jj}, ...
      %   edgeP{k}(2:-1:1,:).',edgCorLen,[]);
      edgeU1{jj,k} = edgeU{k}(:,4) - edgeU{k}(:,2);
      edgeU2{jj,k} = edgeU{k}(:,3) - edgeU{k}(:,1);

      %For debugging:
      %edgeU1{jj,k} = edgeU1{jj,k}/2; 
      %edgeU2{jj,k} = edgeU2{jj,k}/2;

      %Create spline interpolation of the edge displacement using arclength
      % parameter stored in 'msh.e(3:4,:)'.
      edgePPx{jj,k} = spline(edgeS{k}, edgeU1{jj,k}.');
      edgePPy{jj,k} = spline(edgeS{k}, edgeU2{jj,k}.');
   end
end

%Save the displacements on the boundary.
save([resultPath 'edgeDisp'],'numEdges','edgePPx','edgePPy', ...
   'edgeS','edgeP','edgeU1','edgeU2');

%Save the displacements on the data points.
save([resultPath 'dataDisp'],'dataPx','dataPy','dataU1','dataU2', ...
   'speckleP');

fprintf(1,'%f sec.\n', cputime-localStartTime);
