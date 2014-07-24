%=================================
% Models
%=================================
% 1 pop.
%       k1
%    S1 --> S2
%
%
% 2 pop.
%       k2     k3
%    S1 --> S3 --> S4
% k1 |
%    v
%    S2
%
%
% 3 pop.
%       k2     k4     k5
%    S1 --> S3 --> S5 --> S6
% k1 |   k3 |
%    v      v
%    S2     S4
%
%
% 4 pop.
%       k2     k4     k6     k7
%    S1 --> S3 --> S5 --> S7 --> S8
% k1 |   k3 |   k5 |
%    v      v      V
%    S2     S4     S6

% Francois Aguet (last modified 01/23/2012)

function A = getStateMatrix(p, k)
switch p
    case 1
        A = [-k(1) 0;
            k(1) 0];
    case 2
        A = [-(k(1)+k(2)) 0 0 0;
            k(1) 0 0 0;
            k(2) 0 -k(3) 0;
            0 0 k(3) 0];
    case 3
        A = [-(k(1)+k(2)) 0 0 0 0 0;
            k(1) 0 0 0 0 0;
            k(2) 0 -(k(3)+k(4)) 0 0 0;
            0 0 k(3) 0 0 0;
            0 0 k(4) 0 -k(5) 0;
            0 0 0 0 k(5) 0];
    case 4
        A = [-(k(1)+k(2)) 0 0 0 0 0 0 0;
            k(1) 0 0 0 0 0 0 0;
            k(2) 0 -(k(3)+k(4)) 0 0 0 0 0;
            0 0 k(3) 0 0 0 0 0;
            0 0 k(4) 0 -(k(5)+k(6)) 0 0 0;
            0 0 0 0 k(5) 0 0 0;
            0 0 0 0 k(6) 0 -k(7) 0;
            0 0 0 0 0 0 k(7) 0];
end