function dJv_seriesdk(k2::T,v::Int64) where {T <: Real}
# Use series expansion to compute J_v:
nmax = 100
n = 1; error = Inf; if k2 < 1; tol = eps(k2); else; tol = eps(inv(k2)); end
# Computing leading coefficient (n=0):
#coeff = 3pi/(2^(2+v)*factorial(v+2))
if k2 < 1
  coeff = .75*pi/exp(lfact(v+2))
#  println("coefficient: ",coeff)
# multiply by (2v-1)!!
  for i=1:v
    coeff *= (2i-1)/2
  end
# Add leading term to J_v:
  Jv = one(k2)*coeff
  dJvdk = one(k2)*coeff*(2v+1)
# Now, compute higher order terms until desired precision is reached:
  while n < nmax && abs(error) > tol
    coeff *= (2n-1)*(2(n+v)-1)/(2n*(2n+2v+4))*k2
    Jv += coeff
    dJvdk += coeff*(2n+2v+1)
#    error = coeff/Jv
    error = coeff
    n += 1
  end
  dJvdk *= k2^v
  Jv *= k2^v*sqrt(k2)
#  println("Jv: ",Jv," dJv/dk: ",dJvdk)
  return Jv,dJvdk
else # k^2 >= 1
  coeff = convert(typeof(k2),pi)
  # Compute (2v-1)!!/(2^v v!):
  for i=1:v
#    coeff *= 1.-.5/i 
    coeff *= (2i-1)/(2i)
  end
  Jv = one(k2)*coeff
  dJvdk = zero(k2)
  k2inv = inv(k2); n=2
  while n < nmax && abs(error) > tol
#    coeff *= (1.-2.5/n)*(1.-.5/(n+v))*k2inv
    coeff *= (n-5)*(n+2v-1)/(n*(n+2v))
    coeff *= k2inv
    Jv += coeff
    dJvdk -= n*coeff
#    error = coeff/Jv
    error = coeff
    n += 2
  end
  dJvdk /= sqrt(k2)
  return Jv,dJvdk
end
end
