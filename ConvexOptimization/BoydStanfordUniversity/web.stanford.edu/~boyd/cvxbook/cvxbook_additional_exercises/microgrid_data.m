% EE364a microgrid problem setup script
% This script generates data for the micro-grid problem

clc; clear; close all;

PLOT_FIGURES = 1; % make >0 to have figures plotted

% Number of periods in the day (so each period is 15 min)
N = 96; 

% #########################################
% Price data generation - price values and intervals based off of
% PG&E Time Of Use plans
% #########################################
partial_peak_start = 34;
peak_start = 48;
peak_end = 72;
partial_peak_end = 86;

off_peak_inds = [1:partial_peak_start, partial_peak_end+1:N];
partial_peak_inds = [partial_peak_start+1:peak_start, peak_end+1:partial_peak_end];
peak_inds = [peak_start+1:peak_end];

% rates, in $/ kWh
off_peak_buy = 0.14;
partial_peak_buy = 0.25;
peak_buy = 0.45;

off_peak_perc_cut = 0.20;
partial_peak_perc_cut = 0.12;
peak_perc_cut = 0.11;

off_peak_sell = (1 - off_peak_perc_cut) * off_peak_buy;
partial_peak_sell = (1 - partial_peak_perc_cut) * partial_peak_buy;
peak_sell = (1 - peak_perc_cut) * peak_buy;

% Combine buy and sell prices into price vectors
R_buy = ones(N, 1);
R_buy(off_peak_inds) = off_peak_buy;
R_buy(partial_peak_inds) = partial_peak_buy;
R_buy(peak_inds) = peak_buy;

R_sell = ones(N, 1);
R_sell(off_peak_inds) = off_peak_sell;
R_sell(partial_peak_inds) = partial_peak_sell;
R_sell(peak_inds) = peak_sell;

if PLOT_FIGURES > 0
    figure();
    hold('on');
    plot(R_buy);
    plot(R_sell);
    title('Energy Prices ($/kWh)');
    ylabel('Price ($/kWh)');
    xlabel('Interval');
    legend('Buy Price', 'Sell Price');
end

%
% #########################################
% Solar Data Generation
% #########################################
% Something simple: a shifted cosine wave, squared to smooth 
% edges, peak at noon (a +1 and +2 here or there to make it match
% the python implementation exactly)
shift = N/2 + 1;
p_pv = cos(((1:N) - shift) * 2 * pi / N).^2';
scale_factor = 35;
p_pv = p_pv * scale_factor;
p_pv = max(p_pv,0);
p_pv(1:round(shift/2)) = 0;
p_pv(N-round(shift/2)+2:N) = 0;

if PLOT_FIGURES > 0
    figure();
    plot(p_pv);
    title('PV Curve (kW)');
    ylabel('Power (kW)');
    xlabel('Interval');
end

%
% #########################################
% Load data generation (using cvx)
% #########################################
% Fit a curve to some handpicked points and constrain the end
% poitns to match and the derivative at the end to be the same at
% the beginning, then minimize the 2nd order difference of the
% function

% points to fit to
points = [
    [1, 7],
    [11, 8],
    [21, 10],
    [29, 15],
    [37, 21],
    [46, 23],
    [53, 21],
    [57, 18],
    [61, 22.5],
    [67, 24.3],
    [71, 25],
    [74, 24],
    [84, 19],
    [96, 7],
];

cvx_begin quiet
    variable p_ld(N);
    variable obj_val(N + length(points));
    minimize(sum(obj_val));
    subject to
        % Constrain the end poitns to match, and their
        % derivatives to match
        p_ld(1) == p_ld(N);
        (p_ld(2) - p_ld(1)) == (p_ld(N) - p_ld(N-1));
        
        % Add a squared fitting error to the objective
        for i=1:length(points)
            obj_val(i) >= square(p_ld(points(i,1)) - points(i,2));
        end
        
        % Add the second order difference to the objective
        for i=2:N-1
            obj_val(i+length(points)) >= 100*square(p_ld(i+1) - 2*p_ld(i) + p_ld(i-1));
        end
        
        obj_val(1+length(points)) >= 100*square(p_ld(2) - 2*p_ld(1) + p_ld(N));
        obj_val(N+length(points)) >= 100*square(p_ld(1) - 2*p_ld(N) + p_ld(N-1));
        
cvx_end

if PLOT_FIGURES > 0
    figure();
    plot(p_ld);
    title('LoadCurve (kW)');
    ylabel('Power (kW)');
    xlabel('Interval');
end

% #########################################
% Battery and Grid Line Constraint Values
% #########################################
% Max charge and discharge rates
D = 10;   % Max discharge rate (kW)
C = 8;    % Max charge rate (kW)
Q = 27;   % Max energy (kWh)

clearvars -except N R_buy R_sell p_pv p_ld D C Q P

% Final list of values generated:
% N (scalar): number of intervals we split the day into
% R_buy (vector, $/kWh): prices one can buy energy at from grid in given interval
% R_sell (vector, $/kWh): prices one can sell energy at to grid in given interval
% p_pv (vector, kW): power generated by solar
% p_ld (vector, kW): power demands of load
% D (scalar, kW): max discharge rate of battery
% C (scalar, kW): max charge rate of battery
% Q (scalar, kWh): max energy of battery