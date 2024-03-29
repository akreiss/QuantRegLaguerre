% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/functions.R
\name{optimal_quantile_covariance}
\alias{optimal_quantile_covariance}
\title{Compute the Optimal Variance for a Give Quantile-Regression Problem}
\usage{
optimal_quantile_covariance(
  sample,
  tau,
  beta_tau,
  Sigma,
  f_TX,
  f_CX,
  F_TX,
  F_CX,
  Tbounds,
  Cbounds,
  K
)
}
\arguments{
\item{sample}{A function that samples for the model of interest. The function
should not take any arguments and has to return a vector with the first
entr< being the realisation of Y, the second entry the realisation of
Delta, and the remaining p entries contain a realisation of X.}

\item{tau}{Quantile of interest: a number between 0 and 1}

\item{beta_tau}{The true quantile parameter: a p-dimensional vector}

\item{Sigma}{The true second moment matrix of X, i.e., E(XX')}

\item{f_TX, F_TX}{Conditional density and distribution function of T given X.
Both functions have to allow for exactly two arguments: `t` and `X`. `t` is
a vector of the points at which the density or distribution function is
evaluated. `X` is a single realization of X on which the density or the
distribution function is conditioned. The output of both functions must be
a vector of the same lenght as `t` that contains the evaluations of the
density/distribution function of the corresponding entries of `t`
conditionally on `X`.}

\item{f_CX, F_CX}{Conditional density and distribution function of C given X.
Their syntax must be the same as the sybtax described for `f_TX` and
`F_TX`.}

\item{Tbounds, Cbounds}{Vectors of length 2 which contain the support
endpoints of T and C, respectively. That is, T is guaranteed to lie in the
bounds provided in `Tbounds` and similarly for `Cbounds`. It is allowed to
provide `Inf` and `-Inf` as endpoints.}

\item{K}{Number of Monte Carlo repetitions used to approximate the
expectation.}
}
\value{
The function returns a list containing two elements: `var` and `sd`.
  `var` is the estimate for the covariance matrix. `sd` is a matrix of the
  same dimension as `var`. Its entries contain the standard deviations of the
  corresponding entries in `var` due to the Monte Carlo approximation.
}
\description{
`optimal_quantile_covariance` computes the optimal covariance matrix for a
given quantile regression problem in the sense of the convolution theorem in
the framework of semi-parametric efficiency.
}
\details{
The theory on which the implementation is based is provided in Corollary 3.6
of the paper. The expectation is approximated by using Monte Carlo
simulations. The functions also output the variance of these estimates.
Increasing the number of repetitions `K` should increase the precision. See
the description of the output for details. Th function is therefore
stochastic and different runs yield different results if one does not control
for the random seed.
}
\examples{
beta <- c(2,1) # True quantile parameter
tau <- 0.5 # True quantile
Sigma <- matrix(c(1,0,0,1),ncol=2)

## This samples from DGP 4 of the paper
sample <- function() {
 X <- c(1,rnorm(1))
 nu <- 4*(1+exp(1.5*X[2]))
 epsilon <- rt(1,df=nu)-qt(tau,df=nu)
 T <- beta[1]+X[2]*beta[2]+0.5*epsilon
 C <- runif(1,min=0,max=7)
 Y <- min(c(T,C))
 if(T<=C) {
   Delta <- 1
 } else {
   Delta <- 0
 }
 return(c(Y,Delta,X))
}

## Distribution of T given X
f_TX <- function(t,X) {
 Xbeta <- sum(X*beta)
 nu <- 4*(1+exp(1.5*X[2]))
 return(2*dt(2*(t-Xbeta),df=nu))
}
F_TX <- function(t,X) {
 Xbeta <- sum(X*beta)
 nu <- 4*(1+exp(1.5*X[2]))
 return(pt(2*(t-Xbeta),df=nu))
}
Tbounds <- c(-Inf,Inf)
## Distribution of C given X
f_CX <- function(t,X) {
 return(dunif(t,min=0,max=7))
}
F_CX <- function(t,X) {
 return(punif(t,min=0,max=7))
}
Cbounds <- c(0,7)

## Compute optimal variance
out <- optimal_quantile_covariance(sample,tau,beta,Sigma,f_TX,f_CX,F_TX,F_CX,Tbounds,Cbounds,K=10000)
cat("Estimated Covariance Matrix:\n")
print(out$var)

n <- 200
cat("Estimated Optimal Standard Deviations for n=200:\n")
estimated_sds <- sqrt(diag(out$var)/n)
print(estimated_sds)

cat("SD for above estimates for n=200:\n")
SDs <- diag(out$sd)*sqrt(1/(4*n*diag(out$var)))
print(SDs)

alpha <- 0.01
q <- qnorm(1-alpha/2)
cat("Confidence areas: \n")
print(estimated_sds-q*SDs)
print(estimated_sds+q*SDs)

}
