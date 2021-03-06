%% mfoldcv_penv
% Select the dimension of the partial envelope subspace using m-fold cross validation.

%% Syntax
%         SelectOutput = mfoldcv_penv(X, Y, m)
%         SelectOutput = mfoldcv_penv(X, Y, m, Opts)

%% Input
%
% *X*: A list containing the value of X1 and X2.
% 
% * X.X1: Predictors of main interest. An n by p1 matrix, n is the number of 
% observations, and p1 is the number of main predictors. The
% predictors can be univariate or multivariate, discrete or continuous.
% * X.X2: Covariates, or predictors not of main interest.  An n by p2 matrix,
% p2 is the number of covariates.
%
% *Y*: Multivariate responses. An n by r matrix, r is the number of
% responses and n is number of observations. The responses must be 
% continuous variables.
%
% *m*: A positive integer that is used to indicate m-fold cross validation.
% 
% *Opts*: A list containing the optional input parameters. If one or
% several (even all) fields are not defined, the default settings are used.
% 
% * Opts.verbose: Flag to print out dimension selection process, 
% logical 0 or 1. Default value: 0.
% * Opts.table: Flag to tabulate the results, which contains cross 
% validation error for each u.  Logical 0 or 1. Default value: 0.
% * Opts.perm: A positive integer indicating number permutations of the observations, 
% m-fold cross validation is run on each permutation. If not specified, the
% division is based on the sequential order of the observations.
% * Opts.seed: A real number that set the seeds for permutations. Default
% value is 1. 

%% Output
% 
% *SelectOutput*: A list containing the results of the selection.
% 
% * SelectOutput.u: The dimension of the partial envelope subspace selected by 
% m-fold cross validation.  An integer between 0 and r.
% * SelectOutput.PreErr: A vector containing prediction errors for each u 
% if Opts.perm is not specified, or a matrix with the element in the ith 
% row and jth column containing the prediction error for u=j-1 and ith 
% permutation of the observations.

%% Description
% This function implements m-fold cross validation to select the dimension
% of the partial envelope space, based on prediction performance.  For each u, the
% data is partitioned into m parts, each part is in turn used for testing 
% for the prediction performance while the rest m-1 parts are used for 
% training.  The dimension is selected as the one that minimizes the average 
% prediction errors. As Y is multivariate, the identity inner product is 
% used for computing the prediction errors.

%% Example
% 
%         load fiberpaper.dat
%         Y = fiberpaper(:, 1 : 4);
%         X.X1 = fiberpaper(:, 7);
%         X.X2 = fiberpaper(:, 5 : 6);
%         Opts.table = 1; % Print out the table of average prediction error for each u
%         SelectOutput = mfoldcv_penv(X, Y, 5, Opts);
%         SelectOutput.u
% 
%         Opts.perm = 10; % Run 5-fold CV on 10 permutations
%         Opts.seed = 3; % Set seed for the permutations
%         Opts.table = 1;
%         SelectOutput = mfoldcv_penv(X, Y, 5, Opts);
%         SelectOutput.PreErr
%         mean(SelectOutput.PreErr) % Compute the average of prediction errors for each u
%         std(SelectOutput.PreErr) % Compute the standard deviations of the prediction errors for each u

function SelectOutput = mfoldcv_penv(X, Y, m, Opts)

if nargin < 3
    error('Inputs: X, Y, and m should be specified!');
elseif nargin == 3
    Opts = [];
end

if isfield(Opts, 'table')
    if (Opts.table ~= 1)
        tableFlag = 0;
    else
        tableFlag = 1;
    end
else
    tableFlag = 0;
end

X.X1 = double(X.X1);
X.X2 = double(X.X2);
Y = double(Y);

X1 = X.X1;
X2 = X.X2;

[n, r] = size(Y);


Opts = make_opts(Opts);
printFlag = Opts.verbose;
Opts.verbose = 0;

tempInd = min(floor((m - 1) * n / m) - 1, r);

if isfield(Opts, 'perm')

    if Opts.perm <= 0
        error('Number of permutations should be a positive integer!');
    end
    
    if isfield(Opts, 'seed')
        seed = ceil(Opts.seed);
    else
        seed = 1;
    end
    
    perm = ceil(Opts.perm);
    PreErr = zeros(perm, tempInd + 1);
    pe = zeros(perm,1);
    
    for k = 1 : perm
        
        rand('state', seed + k)
        ind = randsample(1 : n, n);
        X1 = X1(ind, :);
        X2 = X2(ind, :);
        Y = Y(ind, :); 
        
        for j = 0 : tempInd

            if printFlag == 1
                fprintf(['Current dimension ' int2str(j + 1) '\n']);
            end

            for i = 1 : m

                index = true(n, 1);
                index((floor((i - 1) * n / m) + 1) : floor(i * n / m)) = 0;
                tempX.X1 = X1(index, :);
                tempX.X2 = X2(index, :);
                tempY = Y(index, :);
                ModelTemp = penv(tempX, tempY, j);

                testX.X1 = X1(logical(1 - index), :);
                testX.X2 = X2(logical(1 - index), :);
                testY = Y(logical(1 - index), :);
                testN = size(testY, 1);
                resi = testY - ones(testN, 1) * ModelTemp.alpha' - testX.X1 * ModelTemp.beta1' - testX.X2 * ModelTemp.beta2';
                PreErr(k, j + 1) = PreErr(k, j + 1) + trace(resi * resi');

            end

        end
        
    end
    
    PreErr = sqrt(PreErr / n);
    
    pe = mean(PreErr);
    [~, ind] = min(pe);
    u = ind - 1;

    SelectOutput.u = u;
    SelectOutput.PreErr = PreErr;
    
    if tableFlag == 1

        fprintf('\n u      CV error      \n');
        fprintf('------------------------\n');
        for i = 0 : tempInd
            fprintf('%2d %12.3f\n', i, pe(i + 1));
        end
        fprintf('------------------------\n');

    end
    
    fprintf('\n');
    disp('The rows of PreErr corresponds to permutations, and the columns of PreErr corresponds to u.');
    fprintf('\n');    
    
else

    PreErr = zeros(1, tempInd + 1);

    for j = 0 : tempInd

        if printFlag == 1
            fprintf(['Current dimension ' int2str(j + 1) '\n']);
        end

        for i = 1 : m

            index = true(n, 1);
            index((floor((i - 1) * n / m) + 1) : floor(i * n / m)) = 0;
            tempX.X1 = X1(index, :);
            tempX.X2 = X2(index, :);
            tempY = Y(index, :);
            ModelTemp = penv(tempX, tempY, j);

            testX.X1 = X1(logical(1 - index), :);
            testX.X2 = X2(logical(1 - index), :);
            testY = Y(logical(1 - index), :);
            testN = size(testY, 1);
            resi = testY - ones(testN, 1) * ModelTemp.alpha' - testX.X1 * ModelTemp.beta1' - testX.X2 * ModelTemp.beta2';
            PreErr(j + 1) = PreErr(j + 1) + trace(resi * resi');

        end

        PreErr(j + 1) = sqrt(PreErr(j + 1) / n);
    end


    [~, ind] = min(PreErr);
    u = ind - 1;

    SelectOutput.u = u;
    SelectOutput.PreErr = PreErr;
    
    if tableFlag == 1

        fprintf('\n u      CV error      \n');
        fprintf('------------------------\n');
        for i = 0 : tempInd
            fprintf('%2d %12.3f\n', i, PreErr(i + 1));
        end
        fprintf('------------------------\n');

    end
    
end