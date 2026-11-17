function m = eval_metrics(y_true, y_pred, p)
% EVAL_METRICS Compute regression accuracy metrics cleanly.
%   y_true : N x 1 observed target vector
%   y_pred : N x 1 predicted target vector
%   p      : optional number of predictors for Adjusted R^2 (default 0)

if nargin < 3
    p = 0;
end

y_true = y_true(:);
y_pred = y_pred(:);
n = numel(y_true);

resid = y_true - y_pred;
sse = sum(resid.^2);
sst = sum((y_true - mean(y_true)).^2);

m = struct();
m.n = n;
m.rmse = sqrt(sse / n);
m.mae = mean(abs(resid));
m.r2 = 1 - sse / sst;
if p > 0 && n > p + 1
    m.adj_r2 = 1 - (1 - m.r2) * (n - 1) / (n - p - 1);
else
    m.adj_r2 = m.r2;
end
m.mape_pct = mean(abs(resid ./ y_true)) * 100;
m.max_abs_err = max(abs(resid));
end
