# Computes I_v(k) and I_v(k) vectors from Luger et al. (2018), along
# the derivatives with respect to k using recursion.
include("transit_structure.jl")
include("cel_bulirsch.jl")

#using GSL
using SpecialFunctions

function Iv_series!(t::Transit_Struct{T}) where {T <: Real}
# Use series expansion to compute I_v with pre-computed
# coefficients for v.max:
k2 = t.k2
if k2 < 1
  tol = eps(k2)
else
  println("k2 > 1 in Iv_series: error")
  return zero(T)
end
# Add leading term to I_v:
Iv = t.Iv_coeff[1]
# Now, compute higher order terms until desired precision is reached:
k2n = one(T)   # k^{2n}
term = zero(T)
for n =1:t.nmax-1
  k2n *= k2
  term = k2n*t.Iv_coeff[n+1]
  Iv += term
  if abs(term) < tol
    break
  end 
end
return Iv*k2^t.v_max*t.k
end

function Iv_series(k2::T,v::Int64) where {T <: Real}
# Use series expansion to compute I_v:
nmax = 100
n = 2; if k2 < 1; tol = eps(k2); else; tol = eps(inv(k2)); end
# Computing leading coefficient (n=0):
coeff = 2/(2v+1)
# Add leading term to I_v:
Iv = convert(T,coeff)
# Now, compute higher order terms until desired precision is reached:
for n =2:2:nmax
  coeff *= (n-1)*(n+2v-1)
  coeff /= n*(n+2v+1)
  coeff *= k2
  Iv += coeff
  if abs(coeff) < tol
   break
  end 
end
return Iv*k2^v*sqrt(k2)
end

# Compute I_v with hypergeometric function (this requires GSL library,
# which can't use BigFloat or ForwardDiff types):
function Iv_hyp(k2::T,v::Int64) where {T <: Real}
a = 0.5*one(k2); b=v+0.5*one(k2); c=v+1.5*one(k2);  fac = 2/(1+2v)
return sqrt(k2)*k2^v*fac*hypergeom([a,b],c,k2)
end

# Compute J_v with hypergeometric function:
function Jv_hyp(k2::T,v::Int64) where {T <: Real}
if k2 < 1
  a = 0.5; b=v+0.5; c=v+3.0;  fac = 3pi/(4*(v+1)*(v+2))
  @inbounds for i=2:2:2v
    fac *= (i-1)/i
  end
  return sqrt(k2)*k2^v*fac*hypergeom([a,b],c,k2)
else # k^2 >=1
  k2inv = inv(k2)
  # Found a simpler expression than the one in paper (and perhaps more stable for large k^2):
  return  sqrt(pi)*gamma(v+.5)*(sf_hyperg_2F1_renorm(-.5,v+.5,v+1.,k2inv)-(.5+v)*k2inv*sf_hyperg_2F1_renorm(-.5,v+1.5,v+2.,k2inv))
end
end

function Jv_series!(t::Transit_Struct{T},v::Int64) where {T <: Real}
# Use series expansion to compute J_v:
# Check which set of series coefficients to use:
k2 = t.k2
if v == t.v_max
  j = 1
elseif v == t.v_max-1
  j = 2
else 
  # In the (rare) case that we need to compute for v_max < v_max-1,
  # then we just call the series sum:
  return Jv_series(k2,v)
end
# Computing leading coefficient (n=0):
if k2 < 1
  tol = eps(k2)
# Add leading term to J_v:
  Jv = t.Jv_coeff[1,j,1]
# Now, compute higher order terms until desired precision is reached:
  k2n = one(T)   # k^{2n}
  term = zero(T)
  for n =1:t.nmax-1
    k2n *= k2
    term = k2n*t.Jv_coeff[1,j,n+1]
    Jv += term
    if abs(term) < tol
      break
    end
  end
  return Jv*k2^v*sqrt(k2)
else # k^2 >= 1
  tol = eps(inv(k2))
  Jv = t.Jv_coeff[2,j,1]
  k2inv = inv(k2)
  k2n = one(T); term = zero(T)
  @inbounds for n = 1:t.nmax-1
    k2n *= k2inv 
    term = k2n*t.Jv_coeff[2,j,n+1]
    Jv += term
    if abs(term) < tol
      break
    end
  end
  return Jv
end
end

# Use series expansion to compute J_v:
function Jv_series(k2::T,v::Int64) where {T <: Real}
nmax = 100
n = 2; if k2 < 1; tol = eps(k2); else; tol = eps(inv(k2)); end
# Computing leading coefficient (n=0):
if k2 < 1
# Add leading term to J_v:
  coeff = 0.75*convert(T,pi)/exp(lfactorial(v+2))
# multiply by (2v-1)!!
  @inbounds for i=2:2:2v
    coeff *= (i-1)/2
  end
  Jv = convert(T,coeff)
# Now, compute higher order terms until desired precision is reached:
  for n=2:2:nmax
    coeff *= (n-1)*(n+2v-1)
    coeff /= n*(n+2v+4)
    coeff *= k2
    Jv += coeff
    if abs(coeff) < tol
      break
    end
  end
  return Jv*k2^v*sqrt(k2)
else # k^2 >= 1
  coeff = convert(typeof(k2),pi)
  # Compute (2v-1)!!/(2^v v!):
  @inbounds for i=2:2:2v
    coeff *= (i-1)/i
  end
  Jv = convert(T,coeff)
  k2inv = inv(k2)
  @inbounds for n =2:2:nmax
    coeff *= (n-5)*(n+2v-1)
    coeff /= k2*(n*(n+2v))  # This line takes about 27% of run time!
    Jv += coeff
    if abs(coeff) < tol
      break
    end
  end
  return Jv
end
end

# Use series expansion to compute J_v and dJ_v/dk, with pre-computed coefficients:
function dJv_seriesdk!(t::Transit_Struct{T},v::Int64) where {T <: Real}
# Check which set of series coefficients to use:
k2 = t.k2
if v == t.v_max
  j = 1
elseif v == t.v_max-1
  j = 2
else
  # In the (rare) case that we need to compute for v_max < v_max-1,
  # then we just call the series sum:
  return dJv_seriesdk(k2,v)
end
if k2 < 1
  tol = eps(k2)
# Add leading term to J_v and dJ_v/dk:
  Jv = t.Jv_coeff[1,j,1]
  dJvdk = t.dJvdk_coeff[1,j,1]
# Now, compute higher order terms until desired precision is reached:
  k2n = one(T)   # k^{2n} for n=0
  term = zero(T); dtermdk = zero(T)
  for n =1:t.nmax-1
    k2n *= k2
    term = k2n*t.Jv_coeff[1,j,n+1]
    Jv += term
    dtermdk = k2n*t.dJvdk_coeff[1,j,n+1]
    dJvdk += dtermdk
    if abs(term) < tol
      break
    end
  end
  dJvdk *= k2^v
  Jv *= k2^v*sqrt(k2)
  return Jv,dJvdk
else # k^2 >= 1
  tol = eps(inv(k2))
  Jv = t.Jv_coeff[2,j,1]
  k2inv = inv(k2)
  k2n = one(T); term = zero(T)
  dJvdk = zero(T)
  @inbounds for n = 1:t.nmax-1
    k2n *= k2inv
    term = k2n*t.Jv_coeff[2,j,n+1]
    Jv += term
    dtermdk = k2n*t.dJvdk_coeff[2,j,n+1]
    dJvdk += dtermdk
    if abs(term) < tol
      break
    end
  end
  dJvdk /= sqrt(k2)
  return Jv,dJvdk
end
end

function dJv_seriesdk(k2::T,v::Int64) where {T <: Real}
# Use series expansion to compute J_v:
nmax = 100
n = 2; if k2 < 1; tol = eps(k2); else; tol = eps(inv(k2)); end
# Computing leading coefficient (n=0):
coeff = zero(k2)
if k2 < 1
  coeff = 0.75*pi/exp(lfactorial(v+2))
# multiply by (2v-1)!!
  @inbounds for i=2:2:2v
    coeff *= (i-1)/2
  end
# Add leading term to J_v:
  Jv = convert(T,coeff)
  dJvdk = Jv*(2v+1)
# Now, compute higher order terms until desired precision is reached:
  @inbounds for n=2:2:nmax
    coeff *= (n-1)*(n+2v-1)
    coeff /= n*(n+2v+4)
    coeff *= k2
    Jv += coeff
    dJvdk += coeff*(n+2v+1)
    if abs(coeff) < tol
      break
    end
  end
  dJvdk *= k2^v
  Jv *= k2^v*sqrt(k2)
  return Jv,dJvdk
else # k^2 >= 1
  coeff = convert(T,pi)
  # Compute (2v-1)!!/(2^v v!):
  @inbounds for i=2:2:2v
    coeff *= (i-1)/i
  end
  Jv = convert(T,coeff)
  dJvdk = zero(T)
  k2inv = inv(k2)
  for n = 2:2:nmax
    coeff *= (n-5)*(n+2v-1)
    coeff /= (n*(n+2v))
    coeff *= k2inv

    Jv += coeff
    dJvdk -= n*coeff
    if abs(coeff) < tol
      break
    end
  end
  dJvdk /= sqrt(k2)
  return Jv,dJvdk
end
end

function IJv_raise!(t::Transit_Struct{T})  where {T <: Real}
kc = t.kc; k=t.k; k2 = t.k2; kc2 = t.kc2; kck=t.kck; kap=t.kap0; Eofk=t.Eofk; Em1mKdm=t.Em1mKdm
# This function needs debugging. [ ]
# Compute I_v, J_v for 0 <= v <= v_max = l_max+2
# Define k:
k = sqrt(k2)
# Iterate upwards in v:
v = t.v_max
# Compute I_v via upward iteration on v:
if k2 < 1
# First, compute value for v=0:
  t.Iv[1] = kap
# Next, iterate upwards in v:
  f0 = kck
  v = 1
# Loop over v, computing I_v and J_v from higher v:
  @inbounds for v=1:t.v_max
    t.Iv[v+1]=((2v-1)*t.Iv[v]/2-f0)/v
    f0 *= k2
  end
else # k^2 >= 1
  # Compute v=0
  t.Iv[1] = pi
  @inbounds for v=1:t.v_max
    t.Iv[v+1]=t.Iv[v]*(1-1/(2v))
  end
end
# Need to compute J_v for v=0, 1:
v= 0
if k2 < 1
  # Use cel_bulirsch:
  if k2 > 0
    t.Jv[v+1]=2/(3k)*((3k2-2)*Em1mKdm+Eofk)
    t.Jv[v+2]= 2/(15k)*((4-3k2)*Eofk+(9k2-8)*Em1mKdm)
  else
    t.Jv[v+1]= 0.0
    t.Jv[v+2]= 0.0
  end
else # k^2 >=1
  k2inv = inv(k2)
  t.Jv[v+1]=t.twothird*((3-2*k2inv)*Eofk+k2inv*Em1mKdm)
  t.Jv[v+2]=0.4*t.third*((-3+4*k2inv)*Em1mKdm+(9-8k2inv)*Eofk)
end
Jv1 = t.Jv[1]; Jv2 = zero(T)
@inbounds for v = 2:t.v_max
  Jv2 = t.Jv[v]
  t.Jv[v+1] = (-k2*(2v-3)*Jv1+2*(v+1+(v-1)*k2)*Jv2)/(2v+3)
  Jv1 = Jv2
end
return
end

function dIJv_raise_dk!(t::Transit_Struct{T})  where {T <: Real}
kc = t.kc; k=t.k; k2 = t.k2; kc2 = t.kc2; kck=t.kck; kap=t.kap0; Eofk=t.Eofk; Em1mKdm=t.Em1mKdm
# Compute I_v, J_v for 0 <= v <= v_max = l_max+2
# Define k:
k = sqrt(k2)
# Iterate upwards in v:
v = t.v_max
# Compute I_v via upward iteration on v:
if k2 < 1
# First, compute value for v=0:
  t.Iv[1] = kap
# Try something else:
# Next, iterate upwards in v:
  f0 = kck
  
# Loop over v, computing I_v and J_v from higher v:
  @inbounds for v=1:t.v_max
    t.Iv[v+1]=((2v-1)*t.Iv[v]*0.5-f0)/v
    f0 *= k2
  end
  if t.grad
    # Now compute compute derivatives:
    t.dIvdk[1] = 2/kc
    @inbounds for v=1:t.v_max
      t.dIvdk[v+1] = k2*t.dIvdk[v]
    end
  end
else # k^2 >= 1
  # Compute v=0
  t.Iv[1] = pi
  @inbounds for v=1:t.v_max
    t.Iv[v+1]=t.Iv[v]*(1-1/(2v))
  end
  if t.grad
    # Derivatives of I_v are zero:
    fill!(t.dIvdk,zero(k2))
  end
end
# Need to compute J_v for v=0, 1:
v= 0
if k2 < 1
  # Use cel_bulirsch:
  if k2 > 0
    t.Jv[v+1]=2/(3k2*k)*(k2*(3k2-2)*Em1mKdm+k2*Eofk)
    t.Jv[v+2]= 2/(15k2*k)*(k2*(4-3k2)*Eofk+k2*(9k2-8)*Em1mKdm)
    if t.grad
      t.dJvdk[v+1] = 2/k2*(-Eofk+2*Em1mKdm)
      t.dJvdk[v+2] = -3*t.Jv[v+2]/k+k2*t.dJvdk[v+1]
    end
  else
    t.Jv[v+1]= 0.0
    t.Jv[v+2]= 0.0
    if t.grad
      t.dJvdk[v+1] = 0.0
      t.dJvdk[v+2] = 0.0
    end
  end
else # k^2 >=1
  k2inv = inv(k2)
  t.Jv[v+1]=t.twothird*((3-2*k2inv)*Eofk+k2inv*Em1mKdm)
  t.Jv[v+2]=0.4*t.third*((-3+4*k2inv)*Em1mKdm+(9-8k2inv)*Eofk)
  if t.grad
    t.dJvdk[v+1] = 2/(k2*k)*(2*Eofk-Em1mKdm)
    t.dJvdk[v+2] = -3*t.Jv[v+2]/k+k2*t.dJvdk[v+1]
  end
end
@inbounds for v=2:t.v_max
  t.Jv[v+1] = (2*(v+1+(v-1)*k2)*t.Jv[v]-k2*(2v-3)*t.Jv[v-1])/(2v+3)
  if t.grad
    t.dJvdk[v+1] = -3*t.Jv[v+1]/k+k2*t.dJvdk[v]
  end
end
return
end

function IJv_lower!(t::Transit_Struct{T})  where {T <: Real}
kc = t.kc; k=t.k; k2 = t.k2; kc2 = t.kc2; kck=t.kck; kap=t.kap0; Eofk=t.Eofk; Em1mKdm=t.Em1mKdm
# Compute I_v, J_v for 0 <= v <= v_max = l_max+2
# Define k:
k = sqrt(k2)
# Iterate downwards in v:
v = t.v_max
# Add in k2 > 1 cases [ ]
# First, compute approximation for large v:
if k2 < 1
#  t.Iv[v+1]=Iv_series(k2,v)
  t.Iv[v+1]=Iv_series!(t)
  while t.Iv[v+1] == zero(T) && v > 0
    v -= 1
    t.Iv[v+1] = Iv_series(k2,v)
  end
# Next, iterate downwards in v:
  f0 = k2^(v-1)*kck
# Loop over v, computing I_v and J_v from higher v:
  @inbounds while v >= 2
    t.Iv[v] = 2/(2v-1)*(v*t.Iv[v+1]+f0)
    f0 /= k2
    v -= 1
  end
  t.Iv[1] = kap
else # k^2 >= 1
  # Compute v=0 (no need to iterate downwards in this case):
  t.Iv[1] = pi
  @inbounds for v=1:t.v_max
    t.Iv[v+1]=t.Iv[v]*(1-.5/v)
  end
end
v= t.v_max
# Need to compute top two for J_v:
#t.Jv[v]=Jv_series(k2,v-1); t.Jv[v+1]=Jv_series(k2,v)
t.Jv[v]=Jv_series!(t,v-1); t.Jv[v+1]=Jv_series!(t,v)
# Iterate downwards in v (lower):
@inbounds for v=t.v_max:-1:2
  f2 = k2*(2v-3); f1 = 2*(v+1+(v-1)*k2); f3 = (2v+3)
  t.Jv[v-1] = (f1*t.Jv[v]-f3*t.Jv[v+1])/f2
end
# Compute first two exactly:
v= 0
if k2 >= 1
  k2inv = inv(k2)
  t.Jv[v+1]=t.twothird*((3-2*k2inv)*Eofk+k2inv*Em1mKdm)
  t.Jv[v+2]=0.4*t.third*((-3+4*k2inv)*Em1mKdm+(9-8k2inv)*Eofk)
end
return
end

function dIJv_lower_dk!(t::Transit_Struct{T})  where {T <: Real}
kc = t.kc; k=t.k; k2 = t.k2; kc2 = t.kc2; kck=t.kck; kap=t.kap0; Eofk=t.Eofk; Em1mKdm=t.Em1mKdm
# Compute I_v, J_v for 0 <= v <= v_max = l_max+2
# Define k:
k = sqrt(k2)
# Iterate downwards in v:
v = t.v_max
# Add in k2 > 1 cases [ ]
# First, compute approximation for large v:
if k2 < 1
#  t.Iv[v+1]=Iv_series(k2,v)
  t.Iv[v+1]=Iv_series!(t)
  @inbounds while t.Iv[v+1] == zero(T) && v > 0
    v -= 1
    t.Iv[v+1] = Iv_series(k2,v)
  end
# Next, iterate downwards in v:
  f0 = k2^(v-1)*kck
# Loop over v, computing I_v and J_v from higher v:
  @inbounds while v >= 2
#  @inbounds for v=t.v_max:-1:2
    t.Iv[v] = 2/(2v-1)*(v*t.Iv[v+1]+f0)
    f0 /= k2
    v -= 1
  end
  t.Iv[1] = kap
  # Now compute compute derivatives:
  if t.grad
    t.dIvdk[1] = 2/kc
    @inbounds for v=1:t.v_max
      t.dIvdk[v+1] = k2*t.dIvdk[v]
    end
  end
else # k^2 >= 1
  # Compute v=0 (no need to iterate downwards in this case):
  t.Iv[1] = pi
  @inbounds for v=1:t.v_max
    t.Iv[v+1]=t.Iv[v]*(1-.5/v)
  end
  # Derivatives of I_v are zero:
  if t.grad
    fill!(t.dIvdk,zero(k2))
  end
end
v= t.v_max
# Need to compute top two for J_v:
dJvdk0 = zero(T); dJvdk1 = zero(T)
t.Jv[v],dJvdk0 = dJv_seriesdk!(t,v-1); t.Jv[v+1],dJvdk1=dJv_seriesdk!(t,v)
@inbounds while t.Jv[v+1] == 0.0 && v > 2 # Loop downward in v until we get a non-zero Jv[v]
  v -=1
  t.Jv[v],dJvdk0 = dJv_seriesdk(k2,v-1); t.Jv[v+1],dJvdk1=dJv_seriesdk(k2,v)
end
if t.grad
  t.dJvdk[v] = dJvdk0; t.dJvdk[v+1] = dJvdk1
end
# Iterate downwards in v (lower):
@inbounds while v >= 2
  f2 = k2*(2v-3); f1 = 2*(v+1+(v-1)*k2); f3 = (2v+3)
  t.Jv[v-1] = (f1*t.Jv[v]-f3*t.Jv[v+1])/f2
  if t.grad
    t.dJvdk[v-1] = (t.dJvdk[v]+3/k*t.Jv[v])/k2
  end
  v -= 1
end
# Compute first two exactly:
v= 0
if k2 >= 1
  k2inv = inv(k2)
#  t.Jv[v+1]=2/3*cel_bulirsch(k2inv,kc,one(k2),3-k2inv,3-5k2inv+2k2inv^2)
#  t.Jv[v+2]=cel_bulirsch(k2inv,kc,one(k2),12-8*k2inv,2*(9-8k2inv)*(1-k2inv))/15
  t.Jv[v+1]=t.twothird*((3-2*k2inv)*Eofk+k2inv*Em1mKdm)
  t.Jv[v+2]=0.4*t.third*((-3+4*k2inv)*Em1mKdm+(9-8k2inv)*Eofk)
end
return
end
