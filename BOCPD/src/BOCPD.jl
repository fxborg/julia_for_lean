module BOCPD
using Distributions
using LinearAlgebra

""" Student's T Type """
mutable struct StudentT
    alpha_0::Float64
    beta_0::Float64
    kappa_0::Float64
    mu_0::Float64

    alpha_n::Array{Float64,1}
    beta_n::Array{Float64,1}
    kappa_n::Array{Float64,1}
    mu_n::Array{Float64,1}

    x_sum::Array{Float64,1}
    x2_sum::Array{Float64,1}
end

""" Constructor """ 
function StudentT(a::Float64,b::Float64,k::Float64,mu::Float64)  
    StudentT(a,b,k,mu,[a],[b],[k],[mu],[0.0],[0.0])
end
function bayes_pdf(d::StudentT,x::Float64)
    dist = LocationScale.(
        d.mu_n,
        sqrt.(d.beta_n .* (d.kappa_n .+ 1.0) ./ (d.alpha_n .* d.kappa_n)),
        TDist.(2.0 .* d.alpha_n)
    )
   pdf.(dist, x)    
    
end
""" baysian update """
function update!(d::StudentT, x::Float64)
    d.x_sum=vcat(0.0,d.x_sum .+ x)
    d.x2_sum=vcat(0.0,d.x2_sum .+ (x^2))
    d.kappa_n = vcat(d.kappa_0,d.kappa_n .+ 1.0)    
    d.alpha_n = vcat(d.alpha_0, d.alpha_n .+ 0.5)
    d.mu_n = ( (d.kappa_0 * d.mu_0) .+ d.x_sum) ./ d.kappa_n
    d.beta_n = d.beta_0 .+ 0.5 .* (d.mu_0.^2 .* d.kappa_0 .+ d.x2_sum .- d.mu_n .^ 2 .* d.kappa_n)
end
    
"""Prunes memory before t."""
function prune!(d::StudentT, to::Int64)
    d.mu_n = d.mu_n[1:to]
    d.kappa_n = d.kappa_n[1:to]
    d.alpha_n = d.alpha_n[1:to]
    d.beta_n = d.beta_n[1:to]
    d.x_sum = d.x_sum[1:to]
    d.x2_sum = d.x2_sum[1:to]
end


"""Prunes memory by condition."""
function prune!(d::StudentT, cond::Array{Bool,1})
    d.mu_n = d.mu_n[cond]
    d.kappa_n = d.kappa_n[cond]
    d.alpha_n = d.alpha_n[cond]
    d.beta_n = d.beta_n[cond]
    d.x_sum = d.x_sum[cond]
    d.x2_sum = d.x2_sum[cond]
end

""" detection """
function detect(run_length::Array{Int64,1}, test_size::Int64)::Bool
    if(length(run_length) < test_size) return false end
    n = run_length[end]
    from = n - test_size + 1
    if(from < 1) return false end

    tester = collect(range(from, stop=n,length=test_size)) 
    run_length[end-test_size+1:end] == tester             
end

""" calculate """
function calculate(
        x::Float64,
        dist::StudentT,
        probs::Array{Float64,1},
        hazard::Float64
    )::Array{Float64,1}
    
    p_x = bayes_pdf(dist, x)

    p_rx_x = (probs .* p_x ).* (1.0 - hazard) 
    p_r0_x = hazard .* dot(p_x, probs)

    update!(dist,x)

    tmp = vcat(p_r0_x, p_rx_x)
    tmp ./ sum(tmp)

end

end # module
