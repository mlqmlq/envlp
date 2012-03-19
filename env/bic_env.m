%% bic_env
% Select the dimension of the envelope subspace using Bayesian information
% criterion.

%% Usage
% u=bic_env(X,Y)
%
% Input
%
% * X: Predictors. An n by p matrix, p is the number of predictors and n 
% is the number of observations. The predictors can be univariate or 
% multivariate, discrete or continuous.
% * Y: Multivariate responses. An n by r matrix, r is the number of
% responses. The responses must be continuous variables.
%
% Output
%
% * u: Dimension of the envelope. An integer between 0 and r.

%% Description
% This function implements the Bayesian information criteria (BIC) to select
% the dimension of the envelope subspace.  

function u=bic_env(X,Y)

[n r]=size(Y);
    
stat=env(X,Y,r);
ic=-2*stat.l+log(n)*stat.np;
u=r;


for i=0:r-1
%     i
        stat=env(X,Y,i);
        temp=-2*stat.l+log(n)*stat.np;
        if (temp<ic)
           u=i;
           ic=temp;
        end
end