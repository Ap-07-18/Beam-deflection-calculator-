% beam_deflection.m
% Arjan Pant
%
% Calculates the deflection of a straight beam from its length, material,
% cross-section and load. Prints the max deflection and bending stress and
% plots the deflected shape + the bending moment diagram.
%
% Cases covered (all loads act downward):
%   1) simply supported, point load P at midspan
%   2) simply supported, uniform load w over the whole span
%   3) cantilever, point load P at the free end
%   4) cantilever, uniform load w over the whole span
%
% Units: SI only (m, N, N/m, Pa)
% Needs MATLAB R2016b or newer because the functions are at the bottom
% of the script.

clear; clc; close all;

%% 1. INPUTS - change these -------------------------------------------

L        = 4;            % beam length [m]
support  = 'simply';     % 'simply' or 'cantilever'
loadType = 'udl';        % 'point' or 'udl'
loadMag  = 10e3;         % P [N] for point load, w [N/m] for udl

material = 'steel';      % steel, aluminum, titanium, copper, wood, concrete
                         % (or type E in Pa, like 150e9)

sectionType = 'rect';    % rect, circle, hollowrect, hollowcircle, i
dims = [0.10 0.20];      % rect: [b h]   (see getSection for the others)

doValidation = true;     % compare against hand calcs at the end
savePlot     = true;     % saves deflection_plot.png

%% 2. MATERIAL + SECTION ----------------------------------------------

E = getE(material);
[I, c] = getSection(sectionType, dims);   % I = moment of inertia, c = dist. to extreme fiber
EI = E * I;

%% 3. DEFLECTION + MOMENT ---------------------------------------------

x = linspace(0, L, 1001)';                % 1001 points along the beam
y = deflectionCurve(support, loadType, loadMag, L, x, EI);
M = momentCurve(support, loadType, loadMag, L, x);

[maxDefl, k] = max(abs(y));
xMax   = x(k);
Mmax   = max(abs(M));
sigma  = Mmax * c / I;                    % bending stress, sigma = M*c/I

%% 4. RESULTS ---------------------------------------------------------

fprintf('\n---------- BEAM DEFLECTION RESULTS ----------\n');
fprintf('Support / load    : %s / %s\n', support, loadType);
fprintf('Length            : %.3f m\n', L);
fprintf('Load              : %.4g (N or N/m)\n', loadMag);
fprintf('E                 : %.4g GPa\n', E/1e9);
fprintf('I                 : %.4e m^4\n', I);
fprintf('Max deflection    : %.4f mm at x = %.3f m\n', maxDefl*1e3, xMax);
fprintf('Max moment        : %.4g N*m\n', Mmax);
fprintf('Max bending stress: %.3f MPa\n', sigma/1e6);
fprintf('Span / deflection : L/%.0f\n', L/maxDefl);
fprintf('----------------------------------------------\n\n');

%% 5. PLOT ------------------------------------------------------------

figure('Position', [100 100 800 600]);

subplot(2,1,1);
plot(x, y*1e3, 'b', 'LineWidth', 2); hold on;
plot(x, zeros(size(x)), 'k--');           % undeflected beam
plot(xMax, y(k)*1e3, 'ro', 'MarkerFaceColor', 'r');
text(xMax, y(k)*1e3, sprintf('  max = %.3f mm', maxDefl*1e3), ...
     'VerticalAlignment', 'top');
grid on;
xlabel('x along beam [m]');
ylabel('Deflection [mm]');
title(sprintf('%s beam, %s load', support, loadType));

subplot(2,1,2);
area(x, M/1e3, 'FaceAlpha', 0.3);
grid on;
xlabel('x along beam [m]');
ylabel('Moment [kN*m]');
title('Bending moment diagram (sagging = positive)');

if savePlot
    saveas(gcf, 'deflection_plot.png');
end

%% 6. VALIDATION ------------------------------------------------------

if doValidation
    runValidation();
end


%% ====================== FUNCTIONS ===================================

function E = getE(material)
    % Young's modulus in Pa. Values are typical textbook numbers.
    if isnumeric(material)
        E = material;
        return
    end
    switch lower(material)
        case 'steel',    E = 200e9;
        case 'aluminum', E = 69e9;
        case 'titanium', E = 110e9;
        case 'copper',   E = 117e9;
        case 'wood',     E = 11e9;     % softwood, along the grain
        case 'concrete', E = 30e9;
        otherwise
            error('Unknown material "%s". Enter E in Pa as a number instead.', material);
    end
end

function [I, c] = getSection(type, d)
    % Returns I (m^4) about the bending axis and c (m) = distance from
    % the neutral axis to the outer fiber.
    switch lower(type)
        case 'rect'            % d = [b h]
            b = d(1);  h = d(2);
            I = b*h^3/12;
            c = h/2;
        case 'circle'          % d = [diameter]
            D = d(1);
            I = pi*D^4/64;
            c = D/2;
        case 'hollowrect'      % d = [b h wallThickness]
            b = d(1);  h = d(2);  t = d(3);
            I = (b*h^3 - (b-2*t)*(h-2*t)^3)/12;
            c = h/2;
        case 'hollowcircle'    % d = [outerDiameter wallThickness]
            Do = d(1);  t = d(2);
            Di = Do - 2*t;
            I = pi*(Do^4 - Di^4)/64;
            c = Do/2;
        case 'i'               % d = [flangeWidth flangeThk webHeight webThk]
            bf = d(1);  tf = d(2);  hw = d(3);  tw = d(4);
            H = hw + 2*tf;
            I = (bf*H^3 - (bf-tw)*hw^3)/12;
            c = H/2;
        otherwise
            error('Unknown section type "%s".', type);
    end
end

function M = momentCurve(support, loadType, q, L, x)
    % Bending moment along the beam. Sagging is positive.
    % For cantilevers the fixed end is at x = 0.
    switch [lower(support) '-' lower(loadType)]
        case 'simply-point'
            M = (q/2) * min(x, L - x);
        case 'simply-udl'
            M = q*x.*(L - x)/2;
        case 'cantilever-point'
            M = -q*(L - x);
        case 'cantilever-udl'
            M = -q*(L - x).^2/2;
        otherwise
            error('Combination "%s / %s" is not supported.', support, loadType);
    end
end

function y = deflectionCurve(support, loadType, q, L, x, EI)
    % Elastic curve from the beam deflection tables.
    % y is positive UP, so a beam that sags has negative y.
    switch [lower(support) '-' lower(loadType)]
        case 'simply-point'
            xs = min(x, L - x);      % curve is symmetric about midspan
            y = -q*xs.*(3*L^2 - 4*xs.^2)/(48*EI);
        case 'simply-udl'
            y = -q*x.*(L^3 - 2*L*x.^2 + x.^3)/(24*EI);
        case 'cantilever-point'
            y = -q*x.^2.*(3*L - x)/(6*EI);
        case 'cantilever-udl'
            y = -q*x.^2.*(6*L^2 - 4*L*x + x.^2)/(24*EI);
        otherwise
            error('Combination "%s / %s" is not supported.', support, loadType);
    end
end

function y = integrateDeflection(support, L, x, M, EI)
    % Second way of getting y: integrate EI*y'' = M twice with trapz,
    % then use the boundary conditions. Used as a cross-check only.
    slope = cumtrapz(x, M/EI);
    y = cumtrapz(x, slope);
    if strcmpi(support, 'simply')
        y = y - (x/L)*y(end);        % force y(0) = y(L) = 0
    end
    % cantilever: y(0) = 0 and y'(0) = 0 already built in
end

function runValidation()
    % Hand calcs use a steel beam, 0.10 m x 0.20 m rectangle:
    %   I  = b*h^3/12 = 0.10*0.20^3/12 = 6.6667e-5 m^4
    %   EI = 200e9 * 6.6667e-5 = 13.333e6 N*m^2
    %
    % Hand results (formulas from the beam tables, worked out on paper):
    %   simply + udl   : 5wL^4/(384EI) = 5(10e3)(4^4)/(384*13.333e6) = 2.500 mm
    %   simply + point : PL^3/(48EI)   = (20e3)(4^3)/(48*13.333e6)    = 2.000 mm
    %   cant   + point : PL^3/(3EI)    = (5e3)(2^3)/(3*13.333e6)      = 1.000 mm
    %   cant   + udl   : wL^4/(8EI)    = (2e3)(2^4)/(8*13.333e6)      = 0.300 mm

    %      support       load     L    magnitude   hand [mm]
    tests = {
        'simply',      'udl',    4,   10e3,       2.500
        'simply',      'point',  4,   20e3,       2.000
        'cantilever',  'point',  2,    5e3,       1.000
        'cantilever',  'udl',    2,    2e3,       0.300
    };

    EI = getE('steel') * getSection('rect', [0.10 0.20]);

    fprintf('------------------------------ VALIDATION ------------------------------\n');
    fprintf('%-11s %-6s %9s %11s %9s %12s %9s\n', ...
        'support', 'load', 'hand[mm]', 'script[mm]', 'err[%]', 'numeric[mm]', 'err[%]');

    worst = 0;
    for i = 1:size(tests, 1)
        support  = tests{i,1};
        loadType = tests{i,2};
        L        = tests{i,3};
        q        = tests{i,4};
        hand     = tests{i,5};

        x = linspace(0, L, 1001)';
        y1 = deflectionCurve(support, loadType, q, L, x, EI);      % table formula
        M  = momentCurve(support, loadType, q, L, x);
        y2 = integrateDeflection(support, L, x, M, EI);            % numerical

        d1 = max(abs(y1))*1e3;
        d2 = max(abs(y2))*1e3;
        err1 = abs(d1 - hand)/hand*100;
        err2 = abs(d2 - hand)/hand*100;
        worst = max([worst, err1, err2]);

        fprintf('%-11s %-6s %9.3f %11.4f %9.4f %12.4f %9.4f\n', ...
            support, loadType, hand, d1, err1, d2, err2);
    end

    fprintf('------------------------------------------------------------------------\n');
    fprintf('Matches hand calculation within %.4f%% error\n\n', worst);
end
