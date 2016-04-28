classdef OrientationSpaceResponse < handle
    %SteerableVanGinkelResponse Response object for SteerableVanGinkelFilter
    %
    %
    
    properties
        filter
        angularResponse
        n
    end
    
    properties (Transient)
        matrix
        idx
        angularGaussians
    end
    
    properties (Transient, Access = protected)
        cache
    end
    
    properties (Dependent)
        res
        nms
        nlms
        nlms_mip
        theta
        a
        NMS
    end
    
    
    
    methods
        function obj = OrientationSpaceResponse(filter,angularResponse)
            if(~nargin)
                return;
            end
            obj.filter = filter;
            obj.angularResponse = angularResponse;
            obj.n = size(angularResponse,3);
        end
        
        % Response, defaults to maximum response with initial basis
        function set.res(obj,res)
            obj.cache.res = res;
        end
        function res = get.res(obj)
            if(~isfield(obj.cache,'res') || isempty(obj.cache.res))
                obj.cache.res = getMaxResponse(obj);
            end
            res = obj.cache.res;
        end
        
        % Non-Maximal Suppression, defaults to nms based on initial basis
        function set.nms(obj,nms)
            obj.cache.nms = nms;
        end
        function nms = get.nms(obj)
            if(~isfield(obj.cache,'nms') || isempty(obj.cache.nms))
                [obj.cache.nms] = nonMaximumSuppression(real(obj.res),real(obj.theta)) + ...
                                   + 1j .* nonMaximumSuppression(imag(obj.res),imag(obj.theta));
            end
            nms = obj.cache.nms;
        end
        function NMS = get.NMS(obj)
            NMS = OrientationSpaceNMS(obj);
        end
        
        function nlms = get.nlms(obj)
            if(~isfield(obj.cache,'nlms') || isempty(obj.cache.nlms))
                [obj.cache.nlms] = nonLocalMaximaSuppression(obj);
            end
            nlms = obj.cache.nlms;
        end
        
        function nlms_mip = get.nlms_mip(obj)
            nlms_mip = max(real(obj.nlms),[],3) + 1j*max(abs(imag(obj.nlms)),[],3);
        end
        
        % Orientation, defaults to best orientation from basis
        function set.theta(obj,theta)
            obj.cache.theta = theta;
        end
        function theta = get.theta(obj)
            if(~isfield(obj.cache,'theta') || isempty(obj.cache.theta))
                [~,obj.cache.theta] = getMaxResponse(obj);
            end
            theta = obj.cache.theta;
        end
        
        % Shortcut for angularResponse
        function set.a(obj,a)
            obj.angularResponse = a;
        end
        function a = get.a(obj)
            a = obj.angularResponse;
        end
        function idx = get.idx(obj)
            if(isempty(obj.idx))
                obj.idx = orientationSpace.OrientationSpaceResponseIndex(obj);
            end
            idx = obj.idx;
        end
        
        function nlms = nonLocalMaximaSuppression(obj, theta, suppressionValue)
            A = real(obj.angularResponse);
            if(nargin < 2)
                theta = 0:obj.n-1;
                theta = theta*pi/obj.n;
            elseif(isscalar(theta))
                if(~mod(theta,1))
                    % integer value
                    A = orientationSpace.upsample(A,pi/theta);
                else
                    A = orientationSpace.upsample(A,theta);
                end
            end
            if(nargin < 3)
                suppressionValue = 0;
            end
            nlms = nonLocalMaximaSuppression(A,theta, suppressionValue);
        end
               
        function A = getAngularGaussians(obj)
            if(isempty(obj.angularGaussians))
                N = obj.n;
                x = 0:N-1;
                xx = bsxfun(@minus,x,x');
                xx = wraparoundN(xx,-N/2,N/2);
                obj.angularGaussians = exp(-xx.^2/2);
            end
            A = obj.angularGaussians;
        end
        function M = getMatrix(obj)
            if(isempty(obj.matrix))
                A = obj.getAngularGaussians;
                aR = obj.angularResponse;
                obj.matrix = reshape(aR,size(aR,1)*size(aR,2),size(aR,3))/A;
            end
            M = obj.matrix;
        end
        function [response,samples] = getResponseAtPoint(obj,r,c,samples)
            if(nargin < 4)
                samples = obj.n;
            end
            siz = size(obj.angularResponse);
            if(nargin > 2)
                linIdx = sub2ind(siz([1 2]),r,c);
            else
                linIdx = r;
            end
            if(isscalar(samples) && samples == obj.n)
                a = reshape(obj.angularResponse,[],obj.n);
                response = squeeze(a(linIdx,:));
                samples = (0:samples-1)'*obj.n/samples;
            else
                if(isscalar(samples))
                    if(mod(samples,1) == 0)
                        samples = (0:samples-1)'*obj.n/samples;
                    else
                        samples = pi/samples;
                        samples = (0:samples-1)'*obj.n/samples;
                    end
                end
                M = obj.getMatrix;
                sampling = bsxfun(@minus,0:obj.n-1,samples);
                sampling = wraparoundN(sampling,-obj.n/2,obj.n/2)';
                sampling = exp(-sampling.^2/2);
                response = M(linIdx,:)*sampling;
            end
        end
        function response = getResponseAtOrientation(obj,angle)
        %getResponseAtOrientation(orientationAngle)
            % Returns the response image plane at the orientation specified
            % in radians
            M = obj.getMatrix;
            if(isinteger(angle) && angle ~= 0)
                %do nothing
                angle = double(angle);
            else
                angle = double(angle)/pi*obj.n;
            end
            xt = bsxfun(@minus,0:obj.n-1,angle)';
            xt = wraparoundN(xt,-obj.n/2,obj.n/2);
            response = M*exp(-xt.^2/2);
            response = reshape(response,size(obj.angularResponse,1),size(obj.angularResponse,2));
            if(abs(wraparoundN(angle,-pi,pi))/pi > 0.5)
                response = real(response) - 1j*imag(response);
            end
        end
        function [response,theta] = getMaxResponse(obj,nn)
            if(nargin < 2)
                nn = obj.n;
            end
            if(isfinite(nn))
                [response,theta] = obj.getMaxFiniteResponse(nn);
            else
                [theta,response] = orientationSpace.maxima(obj.angularResponse);
            end
        end
        function [response,theta] = getMaxFiniteResponse(obj,nn)
            a = obj.angularResponse;
            if(obj.n ~= nn)
                orientationSpace.upsample(a,pi/nn);
            end
            [response,theta] = max(real(a),[],3);
            [response_i,theta_i] = max(cat(3,imag(a),-imag(a)),[],3);
            response = response +1j*response_i;
            theta = theta + 1j*theta_i;
            
            outAnglesRidge = wraparoundN(0:  nn-1,-nn/2,nn/2) * pi/nn;
            outAnglesEdge  = wraparoundN(0:2*nn-1,-nn,  nn)   * pi/nn;
            
            if(nargout > 1)
                theta = outAnglesRidge(real(theta)) + 1j*outAnglesEdge(imag(theta));
            end
        end
        function Response = getResponseAtOrder(obj,Kf_new)
            assert(~mod(Kf_new*2,1), ...
                'OrientationSpaceResponse:getResponseAtOrder', ...
                'Kf_new*2 must be an integer value');
            if(~isscalar(obj))
                Response(numel(obj)) = OrientationSpaceResponse;
                for o=1:numel(obj)
                    Response(o) = obj(o).getResponseAtOrder(Kf_new);
                end
                Response = reshape(Response,size(obj));
                return;
            end
%             A = obj.getAngularGaussians;
            % Calculate new number of angles at new order
            n_new = 2*Kf_new+1;
            scaleFactor = obj.n / n_new;
            % Do we need to wraparound twice?
            queryPts = wraparoundN((0:n_new-1)*scaleFactor,[-obj.n obj.n]/2);
            tt = wraparoundN(bsxfun(@minus,queryPts,(0:obj.n-1)'),[-obj.n obj.n]/2);
            T = exp(-tt.^2/2/(scaleFactor*scaleFactor));
            % Calculate new angular response at Kf_new order
            M = obj.getMatrix();
            angularResponseSize = size(obj.angularResponse);
            angularResponse_new = real(M) * T;
            angularResponse_new = reshape(angularResponse_new,[angularResponseSize([1 2]) n_new]);
            % Deal with edge response if it exists
            if(~isreal(M))
                imagM = imag(cat(3,obj.angularResponse,-obj.angularResponse));
                imagResponse = OrientationSpaceResponse(obj.filter,imagM);
                imagResponse = imagResponse.getResponseAtOrder(Kf_new*2+0.5);
                angularResponse_new = angularResponse_new + 1j * imagResponse.angularResponse(:,:,1:end/2);
            end
            % Create objects and return
            filter_new = OrientationSpaceFilter(obj.filter.f_c,obj.filter.b_f,Kf_new);
            Response = OrientationSpaceResponse(filter_new,angularResponse_new);
        end
        function h = imshow(obj,varargin)
            normalize = false;
            if(~isempty(varargin) && isempty(varargin{1}) && numel(obj) > 1)
                    normalize = true;
            end
            outI = cell(size(obj));
            for o=1:numel(obj)
                outI{o} = obj(o).getMaxResponse;
                if(normalize)
                    outI{o} = mat2gray(real(outI{o}));
                end
            end
            h = imshow(cell2mat(outI),varargin{:});
        end
        function h = imshowpair(A,B)
            if(nargin > 1)
                if(isa(B,'OrientationSpaceResponse'))
                    B = real(B.res);
                end
            else
                B = imag(A.res);
            end
            if(isa(A,'OrientationSpaceResponse'))
                A = real(A.res);
            end
            h = imshowpair(A,B);
        end
        function h = plot(obj,angles,r,c,varargin)
            holdState = ishold;
            hold on;
            for o=1:numel(obj)
                [Y,samples] = obj(o).getResponseAtPoint(r,c,angles);
                h = plot(samples/obj(o).n,Y,varargin{:});
            end
            if(~holdState)
                hold off;
            end
        end
        function h = polar(obj,angles,r,c,varargin)
            holdState = ishold;
            for o = 1:numel(obj)
                [Y,samples] = obj(o).getResponseAtPoint(r,c,angles);
                samples = [samples ; samples+obj(o).n];
                Y = [ Y Y ];
                h = polar(samples'/obj(o).n*pi,Y,varargin{:});
                hold on;
                select = Y < 0;
                if(any(select))
                    addBreaks = diff(select) == 1;
                    select(addBreaks) = true;
                    Y(addBreaks) = NaN;
                    h(2) = polar(samples(select)'/obj(o).n*pi,Y(select),varargin{:});
                    set(h(2),'LineStyle','--','Color','w');
                end
            end
            if(~holdState)
                hold off;
            end
        end
        function A = getArraySpace(obj,varargin)
            % Useful if using a multiscale filter array
            % Concatenate along the next available dimension
            d = ndims(obj(1).a)+1;
            A = cat(d,obj.a);
            sA = size(A);
            A = reshape(A,[sA(1:d-1) size(obj)]);
            A = A(varargin{:});
        end
    end
    
end
