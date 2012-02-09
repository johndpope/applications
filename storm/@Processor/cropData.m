function cropData(obj,roiPosRel,roiSize)

obj.data.roiSize = roiSize;
obj.data.roiPosition = roiPosRel+min(obj.data.points,[],1);

% Disable Z-cropping if size is 0
if obj.data.roiSize(3) == 0
    roiPosition = obj.data.roiPosition;
    roiPosition(3) = min(obj.data.points(:,3));
    roiSize = obj.data.roiSize;
    roiSize(3) = max(obj.data.points(:,3))-min(obj.data.points(:,3));
else
    roiPosition = obj.data.roiPosition;
    roiSize = obj.data.roiSize;
end

% Crop with KD-tree (slower)
% indices = KDTreeRangeQuery(obj.data.points,roiPosition+roiSize/2,roiSize);

% Direct crop
indices = {find(obj.data.points(:,1) >= roiPosition(1) & ...
    obj.data.points(:,2) >= roiPosition(2) & ...
    obj.data.points(:,3) >= roiPosition(3) & ...
    obj.data.points(:,1) <= (roiPosition(1)+roiSize(1)) & ...
    obj.data.points(:,2) <= (roiPosition(2)+roiSize(2)) & ...
    obj.data.points(:,3) <= (roiPosition(3)+roiSize(3)))};

obj.data.points = obj.data.points(indices{1},:);
obj.data.intensity = obj.data.intensity(indices{1},:);
obj.data.frame = obj.data.frame(indices{1},:);

% Display the number of points in the region
disp(['Process: Number of points in the ROI: ' num2str(obj.data.nPoints)]);

disp('Process: Data cropped!');

end

