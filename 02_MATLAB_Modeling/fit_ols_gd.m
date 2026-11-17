function gd = fit_ols_gd(X_train, y_train, lr, max_iter, tol)
% FIT_OLS_GD Fit Multivariate OLS via manual Batch Gradient Descent on Z-scored features.
%   Strictly computes standardization parameters (mu, sigma) from X_train only.
%   Loss function: J(w, b) = (1 / (2*N)) * sum((Z*w + b - y).^2)
%   Maps standardized weights back to raw-scale coefficients for direct
%   equivalence verification against Normal Equation and fitlm.

if nargin < 3 || isempty(lr), lr = 0.05; end
if nargin < 4 || isempty(max_iter), max_iter = 2000; end
if nargin < 5 || isempty(tol), tol = 1e-12; end

[n, p] = size(X_train);
mu = mean(X_train, 1);
sigma = std(X_train, 0, 1);
sigma(sigma == 0) = 1;
Z = (X_train - mu) ./ sigma;

w = zeros(p, 1);
b = 0;

mse_history = zeros(max_iter, 1);
grad_norm_history = zeros(max_iter, 1);
actual_iter = max_iter;

for iter = 1:max_iter
    y_hat = Z * w + b;
    err = y_hat - y_train;

    mse_val = mean(err.^2);
    mse_history(iter) = mse_val;

    grad_w = (Z' * err) / n;
    grad_b = mean(err);
    gnorm = sqrt(sum(grad_w.^2) + grad_b^2);
    grad_norm_history(iter) = gnorm;

    w = w - lr * grad_w;
    b = b - lr * grad_b;

    if iter > 1 && gnorm < tol
        actual_iter = iter;
        break;
    end
end

mse_history = mse_history(1:actual_iter);
grad_norm_history = grad_norm_history(1:actual_iter);

% Map standardized parameters back to raw feature scale:
%   y_hat = b + sum_j w_j * (x_j - mu_j) / sigma_j
%         = (b - sum_j w_j * mu_j / sigma_j) + sum_j (w_j / sigma_j) * x_j
beta_raw_slopes = w ./ sigma';
beta_raw_intercept = b - sum(beta_raw_slopes .* mu');

gd = struct();
gd.lr = lr;
gd.max_iter = max_iter;
gd.tol = tol;
gd.iterations = actual_iter;
gd.mu = mu;
gd.sigma = sigma;
gd.w_std = w;
gd.b_std = b;
gd.beta_raw = [beta_raw_intercept; beta_raw_slopes];
gd.mse_history = mse_history;
gd.rmse_history = sqrt(mse_history);
gd.grad_norm_history = grad_norm_history;
gd.final_mse = mse_history(end);
gd.final_rmse = sqrt(mse_history(end));
end
