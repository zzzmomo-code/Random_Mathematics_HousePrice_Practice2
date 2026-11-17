function [Phi, term_names] = build_poly_features(Z, feature_names, mode)
% BUILD_POLY_FEATURES Construct polynomial design matrix from standardized features Z.
%   mode = 'purequadratic': [Z, Z.^2] (2*p features)
%   mode = 'quadratic'    : [Z, Z.^2, Z_i.*Z_j (i<j)] (2*p + p*(p-1)/2 features)

[~, p] = size(Z);
switch lower(mode)
    case 'purequadratic'
        Phi = [Z, Z.^2];
        sq_names = cell(1, p);
        for j = 1:p
            sq_names{j} = [feature_names{j}, '^2'];
        end
        term_names = [feature_names, sq_names];
    case 'quadratic'
        n_inter = p * (p - 1) / 2;
        Inter = zeros(size(Z, 1), n_inter);
        inter_names = cell(1, n_inter);
        idx = 1;
        for i = 1:(p - 1)
            for j = (i + 1):p
                Inter(:, idx) = Z(:, i) .* Z(:, j);
                inter_names{idx} = [feature_names{i}, '*', feature_names{j}];
                idx = idx + 1;
            end
        end
        sq_names = cell(1, p);
        for j = 1:p
            sq_names{j} = [feature_names{j}, '^2'];
        end
        Phi = [Z, Z.^2, Inter];
        term_names = [feature_names, sq_names, inter_names];
    otherwise
        error('Unsupported polynomial mode: %s', mode);
end
end
