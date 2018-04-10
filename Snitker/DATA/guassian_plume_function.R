##install packages
#install.packages("raster")
#install.packages("~/Downloads/rgdal_0.8-16.tgz", repos = NULL)

##initaiate libraries
library("raster")
library("rgdal")

rm(list = ls())

## Constants
Cy = 0.21
Cz = 0.12
n = 0.25
m = n/(4-(2 * n))
Qo = 100000
e = exp(1)
pp = 0.5 # particle density for avg charcoal particle (g cm^-3) 
pf = 0.00127 # Fluid density for air (g cm^-3 )
v = 0.142 # kinematic viscosity for air (cm^2 sec^-1) 
g = 981 # Accel. due to gravity (cm sec^-2).

######### Charcoal model equation
disperse.x.y.u.h.d = function(x, y, u, h, d){
  
  ## Settling Velocity equation (Stokes' Law)
  settle.vel = function(r){
    dcent = 0.0001 * d
    vg = ((pp-pf)*g*(dcent^2))/(18*v)
    return(vg)
  }
  
  vg = settle.vel(r)
  
  ##Gamma function linear equivalent
  f = function(t) {exp(-t)*(t^((-m)-1))}
  xi = (h^2)/(x^(2-n)*(Cz^2))
  z = integrate(f, lower = xi, upper = 10000000000000000000)
  
  ## Qx function
  Qx = Qo*(exp(((4*vg)/(n*u*Cz*(sqrt(pi)))) * (((-x^(n/2))*(exp(-xi))) + ((h/Cz)^(2*m)) * (-m*z$value))))
  
  ## Dipsersal function
  dispersal = (((2*vg*Qx)/(u*pi*Cy*Cz*(x^(2-n))))*(exp((-y^2)/((Cy^2)*(x^(2-n)))))*(exp((-h^2)/((Cz^2)*(x^(2-n))))))/Qo
  return(dispersal)
}


