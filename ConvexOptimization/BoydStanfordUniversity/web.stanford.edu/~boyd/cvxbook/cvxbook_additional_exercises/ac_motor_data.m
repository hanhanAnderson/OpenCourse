% data file for AC motor problem
clear all;
omega = 1000;
V_supply = 640;
tau_des = 100;
N = 360;
h = pi/180;
R = [
   0.793000   0.000000   0.000000 ;
   0.000000   0.793000   0.000000 ;
   0.000000   0.000000   0.793000 ;
];
L = [
   0.003860   0.000000   0.000000 ;
   0.000000   0.003860   0.000000 ;
   0.000000   0.000000   0.003860 ;
];
K = conv(min(max(sind(-24:N+24), -0.7), 0.7), ones(1, 50)/50, 'valid');
K = [K; K([(N/3+1):N, 1:N/3]); K([(2*N/3+1):N, 1:(2*N/3)])];
