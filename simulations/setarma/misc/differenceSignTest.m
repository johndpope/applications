function [H,errFlag] = differenceSignTest(traj,significance)
%DIFFERENCESIGNTEST tests the hypothesis that a time series is IID by checking whether it has any linear trend.

%SYNOPSIS [H,errFlag] = differenceSignTest(traj,significance)
%
%INPUT  traj        : Trajectory to be tested. An array of structures
%                     with the field "observations". Missing data points
%                     in a trajectory should be indicated with NaN.
%       significance: Significance level of hypothesis test. Default: 0.95.
%
%OUTPUT H       : 1 if hypothesis can be rejected, 0 otherwise.
%       errFlag : 0 if function executes normally, 1 otherwise.
%
%REMARK This test is taken from Brockwell and Davis, "Introduction to Time
%       Series and Forecasting", p.37. It can be used to detect linear
%       trends in a time series. However, it cannot detect any cyclic
%       element. Use with caution where there are missing observations.
%
%Khuloud Jaqaman, August 2004

%initialize output
H = [];
errFlag = 0;

%check input data
if nargin < 1
    disp('--differenceSignTest: You should at least input time series to be analyzed!');
    errFlag = 1;
    return
end

%check that trajectories are column vectors and get their overall length
numTraj = length(traj);
trajLength = 0;
for i=1:numTraj
    nCol = size(traj(i).observations,2);
    if nCol > 1
        disp('--turningPointTest: Each trajectory should be a column vector!');
        errFlag = 1;
    else
        trajLength = trajLength + length(find(~isnan(traj(i).observations)));
    end
end

%assign default value of significance, if needed
if nargin < 2
    significance = 0.95;
end

%calculate number of points where x(t) > x(t-1)
numIncPoints = 0;
for i = 1:numTraj
    numIncPoints = numIncPoints + length(find((traj(i).observations(2:end)...
        -traj(i).observations(1:end-1))>0));
end

%calculate mean and standard deviation of distribution
meanIncPoints = (trajLength-numTraj)/2;
stdIncPoints = sqrt((trajLength+1)/12);

%calculate the test statistic
testStatistic = (numIncPoints-meanIncPoints)/stdIncPoints;

%get the p-value of the test statistic assuming a standard normal distribution
pValue = 1 - normcdf(abs(testStatistic),0,1);

if pValue < (1-significance)/2 %if p-value is smaller than limit
    H = 1; %reject hypothesis that series is IID => there is linear trend
else %if p-value is larger than limit
    H = 0; %cannot reject hypothesis
end

