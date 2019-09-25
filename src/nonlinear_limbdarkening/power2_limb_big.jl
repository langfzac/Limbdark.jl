  ci,fmod =   2
# Can we approximate power-2 limb-darkening with polynomial?

using PyPlot
#include("/Users/ericagol/Computer/Julia/regress.jl")
include("get_coeff.jl")

alpha = big.([0.2,0.25,0.3,0.35,0.4,0.45,0.5,0.55,0.6,0.65,0.7,0.75,0.8,0.85,0.9,0.95,0.99,1.01,1.05,1.1,1.15,1.2,1.25,1.3,1.35,1.4,1.45,1.5,1.55,1.6,1.65,1.7,1.75,1.8])
nmu = 100; mu = logspace(-big(3.0),big(0.0),nmu)
nalpha = length(alpha)
#nmu = 1000; mu = linspace(1e-3,1.0,nmu)
nord = 50
coeff = zeros(BigFloat,nalpha,nord,nord-1)
scat = zeros(BigFloat,nalpha,nord)
for ialpha=1:nalpha
  fnon = mu.^alpha[ialpha]-mu
  for i=2:nord
    fmod = zeros(BigFloat,nmu)
    ci,fmod = get_coeff!(mu,fnon,i,nmu)
    clf()
    plot(mu,convert(Array{Float64,1},fnon))
    plot(mu,convert(Array{Float64,1},fmod))
    plot(mu,convert(Array{Float64,1},fmod-fnon))
    scat[ialpha,i]=convert(Float64,std(fmod-fnon))
    coeff[ialpha,i,1:i-1]=convert(Array{Float64,1},ci)
    println("alpha: ",convert(Float64,alpha[ialpha])," i: ",i," scatter: ",scat[ialpha,i]," max: ",maximum(abs,convert(Array{Float64,1},fmod-fnon)))
  end
end
