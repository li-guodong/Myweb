using Pkg,Distributions,TensorToolbox,LinearAlgebra,DelimitedFiles,SparseArrays,CSV,DataFrames,Distributions;
include("EstimationFunctions/ALS_MLR.jl");
include("EstimationFunctions/RidgeSelect.jl");
include("EstimationFunctions/RRR_select.jl");
include("EstimationFunctions/permutation.jl");
include("EstimationFunctions/ALS_RRR.jl");
include("EstimationFunctions/SHORR.jl");
include("EstimationFunctions/NN_VAR.jl");
include("EstimationFunctions/lasso_ortho_admm.jl");

# commanline arguments: file_path, P, r1, r2, r3, ttratio
df = CSV.File(ARGS[1]; header=false) |> DataFrame
N,T = size(df)
y_normed = Matrix(df)

# hyper parameter
P = parse(Int, ARGS[2])
r1 = parse(Int, ARGS[3])
r2 = parse(Int, ARGS[4])
r3 = parse(Int, ARGS[5])

ttratio =parse(Float64, ARGS[6])
trainsz = Int(trunc(T * ttratio))

# rank selection
# nn = MNN_VAR(y_normed[:,1:trainsz],P,30);
# nn_select = matten(nn.A[findmin(nn.AIC)[2]]',[1],[2,3],[N,N,P]);

# ranks = RidgeRankSelect(nn_select,sqrt(N*P*log(trainsz)/(10*trainsz)))
# print(ranks)


# record errors 
err_MLR = zeros(T-trainsz,2)
err_SHORR = zeros(T-trainsz,2)
log_likelihood_MLR = zeros(T-trainsz)
log_likelihood_SHORR = zeros(T-trainsz)

y_hat_MLR = zeros(T-trainsz,N)
y_true_MLR = zeros(T-trainsz,N)
y_hat_SHORR = zeros(T-trainsz,N)
y_true_SHORR = zeros(T-trainsz,N)

@time begin
    for t = (trainsz+1):T-15
        # print(t)
        y_target = y_normed[:,t]
        local y = y_normed[:,1:t-1]
        x = reshape(reverse(y[:,t-P:t-1],dims=2),N*P,1)

        MLR = ALS_MLR(y,P,[r1,r2,r3]);
        MLR_est = reshape(MLR.A,N,N*P);
        forecast_MLR = MLR_est * x
        # print(forecast_MLR)
        err_MLR[t-trainsz,1] = norm(forecast_MLR-y_target)
        err_MLR[t-trainsz,2] = norm(forecast_MLR-y_target, 1)
        y_hat_MLR[t-trainsz,:] = forecast_MLR
        y_true_MLR[t-trainsz,:] = y_target
                # likelihood
        residual = MLR.resid
        residual_centered = residual .- mean(residual, dims=2)
        global cov_matrix_MLR = residual_centered * transpose(residual_centered) / (t - 1)

        shorr = SHORR(y,P,[r1,r2,r3],10);
        shorr_select = shorr.A[findmin(shorr.BIC)[2]];
        forecast_SHORR = reshape(shorr_select,N,N*P) * x
        # print(forecast_SHORR)
        err_SHORR[t-trainsz,1] = norm(forecast_SHORR-y_target)
        err_SHORR[t-trainsz,2] = norm(forecast_SHORR-y_target, 1)
        y_hat_SHORR[t-trainsz,:] = forecast_SHORR
        y_true_SHORR[t-trainsz,:] = y_target
        # likelihood
        residual = shorr.residual[findmin(shorr.BIC)[2]];
        residual_centered = residual .- mean(residual, dims=2)
        global cov_matrix_SHORR = residual_centered * transpose(residual_centered) / (t - 1)
    end
end

for t = (trainsz+1):T-15
    # U = eigvecs(cov_matrix)
    dist = Distributions.MvNormal(vec(y_hat_MLR[t-trainsz,:]), cov_matrix_MLR)
    log_likelihood_MLR[t-trainsz] = logpdf(dist,vec(y_true_MLR[t-trainsz,:]))

    dist = Distributions.MvNormal(vec(y_hat_SHORR[t-trainsz,:]), cov_matrix_SHORR)
    log_likelihood_SHORR[t-trainsz] = logpdf(dist,vec(y_true_SHORR[t-trainsz,:]))
end

writedlm( "result/" * ARGS[7] * "/Y_hat_MLR.csv",  y_hat_MLR, ',')
writedlm( "result/" * ARGS[7] * "/Loglikelihood_MLR.csv",  log_likelihood_MLR, ',')
writedlm( "result/" * ARGS[7] * "/Y_hat_SHORR.csv",  y_hat_SHORR, ',')
writedlm( "result/" * ARGS[7] * "/Loglikelihood_SHORR.csv",  log_likelihood_SHORR, ',')

print("MLR: ",mean(err_MLR,dims=1))
print("SHORR: ",mean(err_SHORR,dims=1))