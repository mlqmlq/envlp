%% henv
% Fit the heteroscedastic envelope model.

%% Syntax
%         ModelOutput = henv(X, Y, u)
%         ModelOutput = henv(X, Y, u, Opts)
%
%% Input
%
% *X*: Group indicators. A matrix with n rows.  X can only have p unique
%  rows, where p is the number of groups. For example, if there 
% are two groups, X can only have 2 different kinds of rows, such as (0, 1)
% and (1, 0), or (1, 0, 10) and (0, 5, 6).  The number of columns is not
% restricted, as long as X only has p unique rows.
%
% *Y*: Multivariate responses. An n by r matrix, r is the number of
% responses and n is number of observations. The responses must be 
% continuous variables.
%
% *u*: Dimension of the envelope. An integer between 0 and r.
%
% *Opts*: A list containing the optional input parameters, to control the
% iterations in sg_min. If one or several (even all) fields are not
% defined, the default settings are used.
% 
% * Opts.maxIter: Maximum number of iterations.  Default value: 300.
% * Opts.ftol: Tolerance parameter for F.  Default value: 1e-10. 
% * Opts.gradtol: Tolerance parameter for dF.  Default value: 1e-7.
% * Opts.verbose: Flag for print out Grassmann manifold optimization 
% process, logical 0 or 1. Default value: 0.
% * Opts.init: The initial value for the heteroscedastic envelope subspace. An r by u matrix. Default
% value is the one generated by function get_Init4henv. 
%
%% Output
% 
% *ModelOutput*: A list that contains the maximum likelihood estimators and some
% statistics.
% 
% * ModelOutput.mu: The heteroscedastic envelope estimator of the grand mean. A r
% by 1 vector.
% * ModelOutput.mug: The heteroscedastic envelope estimator of the group mean. A r
% by p matrix, the ith column of the matrix contains the mean for the ith
% group.
% * ModelOutput.Yfit: A n by r matrix, the ith row gives the group mean of the
% group that the ith observation belongs to.  As X is just a group
% indicator, and is not ordinal, ModelOutput.mug alone does not tell which
% group corresponds to which group mean.
% * ModelOutput.Gamma: The orthogonal basis of the envelope subspace. An r by u
% semi-orthogonal matrix.
% * ModelOutput.Gamma0: The orthogonal basis of the complement of the envelope
% subspace.  An r by r-u semi-orthogonal matrix.
% * ModelOutput.beta: The heteroscedastic envelope estimator of the group main
% effect. An r by p matrix, the ith column of the matrix contains the
% main effect for the ith group.
% * ModelOutput.groupInd: A matrix containing the unique values of group
% indicators. The matrix has p rows.  The group mean of the ith row is
% stored in the ith column of ModelOutput.mug.
% * ModelOutput.Sigma: The heteroscedastic envelope estimator of the error
% covariance matrix.  A three dimensional matrix with dimension r, r and p,
% ModelOutput.Sigma(:, :, i) contains the estimated covariance matrix for the ith
% group.
% * ModelOutput.eta: The coordinates of $$\beta$ with respect to Gamma. An u by p
% matrix, the ith column contains the coordinates of the main effect of the
% ith group with respect to Gamma.
% * ModelOutput.Omega: The coordinates of Sigma with respect to Gamma. An u by u
% by p matrix, ModelOutput.Omega(:, :, i) contains the coordinates of the covariance
% matrix of the ith group with respect to Gamma.
% * ModelOutput.Omega0: The coordinates of Sigma with respect to Gamma0. An r - u by r - u
% matrix.
% * ModelOutput.l: The maximized log likelihood function.  A real number.
% * ModelOutput.paramNum: The number of parameters in the heteroscedastic envelope
% model.  A positive integer.
% * ModelOutput.covMatrix: The asymptotic covariance of ($$\mu$', vec($$\beta$'))'.  An r(p + 1) by
% r(p + 1) matrix.  The covariance matrix returned are asymptotic.  For the
% actual standard errors, multiply by 1 / n.
% * ModelOutput.asySE: The asymptotic standard errors for elements in $$\beta$
% under the heteroscedastic envelope model. An r by p matrix.  The standard errors returned are
% asymptotic, for actual standard errors, multiply by 1 / sqrt(n).
% * ModelOutput.ratio: The asymptotic standard error ratio of the standard multivariate 
% linear regression estimator over the heteroscedastic envelope estimator.
% An r by p matrix, the (i, j)th element in ModelOutput.ratio is the elementwise standard
% error ratio for the ith element in the jth group mean effect.
% * ModelOutput.ng: The number of observations in each group.  A p by 1 vector.

%% Description
% This function fits the heteroscedastic envelope model to the responses and predictors,
% using the maximum likelihood estimation.  When the dimension of the
% envelope is between 1 and r-1, we implemented the algorithm in Su and Cook (2013).
% When the dimension is r, then the envelope model degenerates
% to the standard multivariate linear model for comparing group means.  When the dimension is 0,
% it means there is not any group effect, and the fitting is different.

%% References
% 
% # The codes are implemented based on the algorithm in Section 2.2 of Su
% and Cook (2013).
% # The Grassmann manifold optimization step calls the package sg_min 2.4.3
% by Ross Lippert (http://web.mit.edu/~ripper/www.sgmin.html).

%% Example
%
% The following codes produce the results of the water strider example in Su
% and Cook (2013).
% 
%         load waterstrider.mat
%         u = lrt_henv(X, Y, 0.01)
%         ModelOutput = henv(X, Y, u)
%         ModelOutput.ratio

function ModelOutput = henv(X, Y, u, Opts)

if nargin < 3
    error('Inputs: X, Y and u should be specified!');
elseif nargin == 3
    Opts = [];
end

X = double(X);
Y = double(Y);

n = size(X, 1);
[n1, r] = size(Y);

if n ~= n1
    error('The number of observations in X and Y should be equal!');
end

% if p > r
%     error(['When the number of responses is less than the number of ' ...
% 			'groups, the heteroscedastic envelope model cannot be applied.']);
% end

u = floor(u);
if u < 0 || u > r
    error('u should be an integer between [0, r]!');
end

Opts = make_opts(Opts);

if isfield(Opts, 'init')
    [r2, u2] = size(Opts.init);

    if r ~= r2 || u ~= u2
        error('The size of the initial value should be r by u!');
    end

    if rank(Opts.init) < u2
        error('The initial value should be full rank!');
    end
end


DataParameter = make_parameter(X, Y, 'henv');

p = DataParameter.p;
r = DataParameter.r;
n = DataParameter.n;
ng = DataParameter.ng;
ncum = DataParameter.ncum;
mY = DataParameter.mY;
mYg = DataParameter.mYg;
sigRes = DataParameter.sigRes;
sigY = DataParameter.sigY;
ind = DataParameter.ind;
logDetSigY = DataParameter.logDetSigY;

minNg = min(ng);
if minNg < r
    error('Some groups have sample sizes smaller than the number of responses, therefore the group covariance matrix cannot be estimated.');
end

if u == 0
    
    Gamma = [];
    Gamma0 = eye(r);
    Sigma = sigY;
    mu = mY;
    mug = mY * ones(1, p);
    beta = zeros(r, p);
    eta = [];
    Omega = [];
    Omega0 = sigY;
    l = - n * r / 2 * (1 + log(2 * pi)) - n / 2 * logDetSigY;
    
    ModelOutput.mu = mu;
    ModelOutput.mug = mug;
    ModelOutput.Yfit = zeros(n, r);
    ModelOutput.Gamma = Gamma;
    ModelOutput.Gamma0 = Gamma0;
    ModelOutput.beta = beta;
    ModelOutput.groupInd = sortrows(unique(X, 'rows'));
    ModelOutput.Sigma = Sigma;
    ModelOutput.eta = eta;
    ModelOutput.Omega = Omega;
    ModelOutput.Omega0 = Omega0;
    ModelOutput.l = l;
    ModelOutput.paramNum = (r - u) + u * (r - u + p) + p * u * (u + 1) / 2 + (r - u) * (r - u + 1) / 2;
    ModelOutput.covMatrix = Sigma;
    ModelOutput.asySE = [];
    ModelOutput.ratio = ones(r, p);    
    ModelOutput.ng = ng';
    
elseif u == r
    
    Gamma = eye(r);
    Gamma0 = [];
    Sigma = sigRes;
    mu = mY;
    mug = mYg;
    beta = mug - mu * ones(1, p);
    eta = beta;
    Omega = sigRes;
    Omega0 = [];
    l = - n * r / 2 * (1 + log(2 * pi));
    for i = 1 : p
        eigtem = eig(sigRes(:, :, i));
        l = l - ng(i) / 2 * log(prod(eigtem(eigtem > 0)));
    end
    Yfit = zeros(n, r);
    for i = 1 : p
        if i > 1
            Yfit(ind(ncum(i - 1) + 1 : ncum(i)), :) = ones(ng(i), 1) * mug(:, i)';
        else
            Yfit(ind(1 : ncum(1)), :) = ones(ng(1), 1) * mug(:, 1)';
        end
    end
    
    fracN = ng / n;
    J = zeros(p * r + p * r * (r + 1) / 2);

    for i = 1 : p - 1
        for j = 1 : p - 1
            J((i - 1) * r + 1 : i * r, (j - 1) * r + 1 : j * r)...
                = fracN(j) * fracN(i) / fracN(p) * eye(r) / Sigma(:, :, p);
        end
        J((i - 1) * r + 1 : i * r, (i - 1) * r + 1 : i * r)...
                = fracN(i) / Sigma(:, :, i) + fracN(i) ^ 2 / fracN(p) / Sigma(:, :, p);
    end
    for i = 1 : p
        J(r * (p - 1) + 1 + (i - 1) * r * (r + 1) / 2 : r * (p - 1) + i * r * (r + 1) / 2,  ...
        r * (p - 1) + 1 + (i - 1) * r * (r + 1) / 2 : r * (p - 1) + i * r * (r + 1) / 2) ...
		= 0.5 * fracN(i) * Expan(r)' * kron(inv(Sigma(:, :, i)), inv(Sigma(:, :, i))) * Expan(r);
    end
    J(r + 1 : end, r + 1 : end) ...
		= J(1 : (p - 1) * r + p * r * (r + 1) / 2, 1 : (p - 1) * r + p * r * (r + 1) / 2);
    J(1 : r, :) = 0;
    J(r + 1 : end, 1 : r) = 0;
    for i = 1 : p
        J(1 : r, 1 : r) = J(1 : r, 1 : r) + fracN(i) / Sigma(:, :, i);
    end
    for i = 1 : p - 1
        J(1 : r, i * r + 1 : (i + 1) * r) = fracN(i) * (inv(Sigma(:, :, p)) - inv(Sigma(:, :, i)));
        J(i * r + 1 : (i + 1) * r, 1 : r) = J(1 : r, i * r + 1 : (i + 1) * r);
    end
    temp = inv(J);
    tempA = kron(ones(1, p - 1), eye(r));
    varGroupp = tempA * temp(r + 1 : r * p, r + 1 : r * p) * tempA';
    covMatrix = zeros(r * (p + 1), r * (p + 1));
    covMatrix(1 : r * p, 1 : r * p) = temp(1 : r * p, 1 : r * p);
    covMatrix(r * p + 1 : r * (p + 1), r * p + 1 : r * (p + 1)) = varGroupp;
    for i = 1 : p - 1
        covMatrix(r * p + 1 : r * (p + 1), i * r + 1 : (i + 1) * r) ...
			= - tempA * temp(r + 1 : r * p, i * r + 1 : (i + 1) * r);
    end
    covMatrix(r + 1 : p * r, r * p + 1 : r * (p + 1)) ...
		= covMatrix(r * p + 1 : r * (p + 1), r + 1 : p * r)';
    covMatrix(r * p + 1 : r * (p + 1), 1 : r) = - tempA * temp(r + 1 : r * p, 1 : r);
    covMatrix(1 : r, r * p + 1 : r * (p + 1)) = covMatrix(r * p + 1 : r * (p + 1), 1 : r)';
    asyFm = reshape(sqrt(diag(covMatrix(r + 1 : end, r + 1 : end))), r, p);
    
    ModelOutput.mu = mu;
    ModelOutput.mug = mug;
    ModelOutput.Yfit = Yfit;
    ModelOutput.Gamma = Gamma;
    ModelOutput.Gamma0 = Gamma0;
    ModelOutput.beta = beta;
    ModelOutput.groupInd = sortrows(unique(X, 'rows'));
    ModelOutput.Sigma = Sigma;
    ModelOutput.eta = eta;
    ModelOutput.Omega = Omega;
    ModelOutput.Omega0 = Omega0;
    ModelOutput.l = l;
    ModelOutput.paramNum = (r - u) + u * (r - u + p) ...
		+ p * u * (u + 1) / 2 + (r - u) * (r - u + 1) / 2;
    ModelOutput.covMatrix = covMatrix;
    ModelOutput.asySE = asyFm;
    ModelOutput.ratio = ones(r, p);
    ModelOutput.ng = ng';
    
else
    
    mu=mY;
 
    F = make_F(@F4henv, DataParameter);
    dF = make_dF(@dF4henv, DataParameter);
    
    maxIter = Opts.maxIter;
	ftol = Opts.ftol;
	gradtol = Opts.gradtol;
    
	if (Opts.verbose == 0) 
        verbose = 'quiet';
    else
        verbose = 'verbose';
    end
    
    if ~isfield(Opts, 'init') 
        init = get_Init4henv(F, u, DataParameter);
    else
        init = Opts.init;
    end
    
    
    [l, Gamma] = sg_min(F, dF, init, maxIter, 'prcg', verbose, ftol, gradtol);

    Gamma0 = grams(nulbasis(Gamma'));
    Omega0 = Gamma0' * sigY * Gamma0;
    eta = Gamma' * (mYg - mu * ones(1, p));
    beta = Gamma * eta;
    mug = mu * ones(1, p) + beta;
    Omega = zeros(u, u, p);
    Sigma = zeros(r, r, p);
    for i = 1 : p
        Omega(:, :, i) = Gamma' * sigRes(:, :, i) * Gamma;
        Sigma(:, :, i) = Gamma * Omega(:, :, i) * Gamma' + Gamma0 * Omega0 * Gamma0';
    end
    
    Yfit = zeros(n, r);
    for i = 1 : p
        if i > 1
            Yfit(ind(ncum(i - 1) + 1 : ncum(i)), :) = ones(ng(i), 1) * mug(:, i)';
        else
            Yfit(ind(1 : ncum(1)), :) = ones(ng(1), 1) * mug(:, 1)';
        end
    end

    fracN = ng / n;
    J = zeros(p * r + p * r * (r + 1) / 2);
    for i = 1 : p - 1
        for j = 1 : p - 1
            J((i - 1) * r + 1 : i * r, (j - 1) * r + 1 : j * r) ...
				= fracN(j) * fracN(i) / fracN(p) * eye(r) / Sigma(:, :, p);
        end
        J((i - 1) * r + 1 : i * r, (i - 1) * r + 1 : i * r) ...
			= fracN(i) * eye(r) / Sigma(:, :, i) + fracN(i) ^ 2 / fracN(p) * eye(r) / Sigma(:, :, p);
    end
    for i = 1 : p
        J(r * (p - 1) + 1 + (i - 1) * r * (r + 1) / 2 : r * (p - 1) + i * r * (r + 1) / 2,  ...
        	r * (p - 1) + 1 + (i - 1) * r * (r + 1) / 2 : r * (p - 1) + i * r * (r + 1) / 2) ...
			= 0.5 * fracN(i) * Expan(r)' * kron(inv(Sigma(:, :, i)), inv(Sigma(:, :, i))) * Expan(r);
    end
    J(r + 1 : end, r + 1 : end) ...
		= J(1 : (p - 1) * r + p * r * (r + 1) / 2, 1 : (p - 1) * r + p * r * (r + 1) / 2);
    J(1 : r, :) = 0;
    J(r + 1 : end, 1 : r) = 0;
    for i = 1 : p
        J(1 : r, 1 : r) = J(1 : r, 1 : r) + fracN(i) * eye(r) / Sigma(:, :, i);
    end
    for i = 1 : p - 1
        J(1 : r, i * r + 1 : (i + 1) * r) ...
			= fracN(i) * (inv(Sigma(:, :, p)) - inv(Sigma(:, :, i)));
        J(i * r + 1 : (i + 1) * r, 1 : r) = J(1 : r, i * r + 1 : (i + 1) * r);
    end
    
    J1 = zeros(p * r + p * r * (r + 1) / 2);
    for i = 1 : p - 1
        for j = 1 : p - 1
            J1((i - 1) * r + 1 : i * r, (j - 1) * r + 1 : j * r) ...
				= fracN(j) * fracN(i) / fracN(p) * eye(r) / sigRes(:, :, p);
        end
        J1((i - 1) * r + 1 : i * r, (i - 1) * r + 1 : i * r) ...
			= fracN(i) * eye(r) / sigRes(:, :, i) + fracN(i) ^ 2 / fracN(p) * eye(r) / sigRes(:, :, p);
    end
    for i = 1 : p
        J1(r * (p - 1) + 1 + (i - 1) * r * (r + 1) / 2 : r * (p - 1) + i * r * (r + 1) / 2,  ...
        	r * (p - 1) + 1 + (i - 1) * r * (r + 1) / 2 : r * (p - 1) + i * r * (r + 1) / 2) ...
			= 0.5 * fracN(i) * Expan(r)' * kron(inv(sigRes(:, :, i)), inv(sigRes(:, :, i))) * Expan(r);
    end
    J1(r + 1 : end, r + 1 : end) ...
		= J1(1 : (p - 1) * r + p * r * (r + 1) / 2, 1 : (p - 1) * r + p * r * (r + 1) / 2);
    J1(1 : r, :) = 0;
    J1(r + 1 : end, 1 : r) = 0;
    for i = 1 : p
        J1(1 : r, 1 : r) = J1(1 : r, 1 : r) + fracN(i) * eye(r) / sigRes(:, :, i);
    end
    for i = 1 : p - 1
        J1(1 : r, i * r + 1 : (i + 1) * r) ...
			= fracN(i) * (inv(sigRes(:, :, p)) - inv(sigRes(:, :, i)));
        J1(i * r + 1 : (i + 1) * r, 1 : r) = J1(1 : r, i * r + 1 : (i + 1) * r);
    end
    temp1 = inv(J1);
    asyFm = reshape(sqrt(diag(temp1(1 : r * p, 1 : r * p))), r, p);
    
    H = zeros(p * r + p * r * (r + 1) / 2,  ...
    	r + u * (r + p - 1 - u) + p * u * (u + 1) / 2 + (r - u) * (r - u + 1) / 2);
    for i = 1 : p - 1
        H((i - 1) * r + 1 : i * r, (i - 1) * u + 1 : i * u) = Gamma;
        H((i - 1) * r + 1 : i * r, (p - 1) * u + 1 : u * (r + p - 1 - u)) = kron(eta(:, i)', Gamma0);
    end
    for i = 1 : p 
        H(r * (p - 1) + (i - 1) * r * (r + 1) / 2 + 1 : r * (p - 1) + i * r * (r + 1) / 2,  ...
        	(p - 1) * u + 1 : u * (r + p - 1 - u)) ...
			= 2 * Contr(r) * (kron(Gamma * Omega(:, :, i), Gamma0) - kron(Gamma, Gamma0 * Omega0));
        H(r * (p - 1) + (i - 1) * r * (r + 1) / 2 + 1 : r * (p - 1) + i * r * (r + 1) / 2,  ...
        	u * (r + p - 1 - u) + (i - 1) * u * (u + 1) / 2 + 1 : u * (r + p - 1 - u) + i * u * (u + 1) / 2) ...
			= Contr(r) * kron(Gamma, Gamma) * Expan(u);
        H(r * (p - 1) + (i - 1) * r * (r + 1) / 2 + 1 : r * (p - 1) + i * r * (r + 1) / 2, ...
         	u * (r + p - 1 - u) + p * u * (u + 1) / 2 + 1 : u * (r + p - 1 - u) + p * u * (u + 1) / 2  ...
         	+ (r - u) * (r - u + 1) / 2) = Contr(r) * kron(Gamma0, Gamma0) * Expan(r - u);
    end
    H(r + 1 : end, r + 1 : end) ...
		= H(1 : (p - 1) * r + p * r * (r + 1) / 2,  ...
		1 : u * (r + p - 1 - u) + p * u * (u + 1) / 2 + (r - u) * (r - u + 1) / 2);
    H(1 : r, r + 1 : end) = 0;
    H(r + 1 : end, 1 : r) = 0;
    H(1 : r, 1 : r) = eye(r);
    temp = H / (H' * J * H) * H';
    tempA = kron(ones(1, p - 1), eye(r));
    varGroupp = tempA * temp(r + 1 : r * p, r + 1 : r * p) * tempA';
    covMatrix = zeros(r * (p + 1), r * (p + 1));
    covMatrix(1 : r * p, 1 : r * p) = temp(1 : r * p, 1 : r * p);
    covMatrix(r * p + 1 : r * (p + 1), r * p + 1 : r * (p + 1)) = varGroupp;
    for i = 1 : p - 1
        covMatrix(r * p + 1 : r * (p + 1), i * r + 1 : (i + 1) * r) = - tempA * temp(r + 1 : r * p, i * r + 1 : (i + 1) * r);
    end
    covMatrix(r + 1 : p * r, r * p + 1 : r * (p + 1)) = covMatrix(r * p + 1 : r * (p + 1), r + 1 : p * r)';
    covMatrix(r * p + 1 : r * (p + 1), 1 : r) = - tempA * temp(r + 1 : r * p, 1 : r);
    covMatrix(1 : r, r * p + 1 : r * (p + 1)) = covMatrix(r * p + 1 : r * (p + 1), 1 : r)';
    asySE = reshape(sqrt(diag(covMatrix(r + 1 : end, r + 1 : end))), r, p);
    
    ModelOutput.mu = mu;
    ModelOutput.mug = mug;
    ModelOutput.Yfit = Yfit;
    ModelOutput.Gamma = Gamma;
    ModelOutput.Gamma0 = Gamma0;
    ModelOutput.beta = beta;
    ModelOutput.groupInd = sortrows(unique(X, 'rows'));
    ModelOutput.Sigma = Sigma;
    ModelOutput.eta = eta;
    ModelOutput.Omega = Omega;
    ModelOutput.Omega0 = Omega0;
    ModelOutput.paramNum = (r - u) + u * (r - u + p) + p * u * (u + 1) / 2 + (r - u) * (r - u + 1) / 2;
    ModelOutput.l = - 0.5 * l;   
    ModelOutput.covMatrix = covMatrix;
    ModelOutput.asySE = asySE;
    ModelOutput.ratio = asyFm ./ asySE;
    ModelOutput.ng = ng';
    
end