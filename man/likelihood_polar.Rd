% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/functions.R
\name{likelihood_polar}
\alias{likelihood_polar}
\title{Likelihood for Spherical Coordinates}
\usage{
likelihood_polar(
  tau,
  beta,
  theta_polar,
  theta_tilde_polar,
  lambda_polar,
  X,
  Y,
  Delta,
  sigma0,
  derivative = FALSE
)
}
\arguments{
\item{tau}{Quantile of interest from the interval (0,1)}

\item{beta}{Value for the beta parameter (always in Cartesian coordinates)}

\item{theta_polar, theta_tilde_polar, lambda_polar}{Angles in spherical
coordinates for the corresponding parameters. The radius is always equal to
one. If the 1-dim Cartesian coordinate 1 shall be used, the corresponding
parameter has to be set to FALSE.}

\item{X}{Matrix containing covariates to be used, first column must be an
intercept. Each row corresponds to an observation, each column corresponds
to a covariate. The number of columns must equal the length of beta.}

\item{Y}{Scalar vector of observations, its lenght must equal the number of
rows in X.}

\item{Delta}{Vector of zeros and ones of the same length as Y. A one
indicates that the corresponding observation is uncensored.}

\item{sigma0}{Value to be added to te heteroskedasticity function.}

\item{derivative}{If TRUE the derivatives with respect to beta and all
variables are returned which do not equal FALSE}
}
\value{
If \code{"derivative=FALSE"} the value of the likelihood is returned.
  Otherwise a list is returned with the element "objective" which contains
  the likelihood and a vector "gradient" which concatenates all gradients
  beginning with beta, theta, theta_tilde, lambda. If some variable is
  specified as FALSE, it is ommited in the gradient.
}
\description{
`likelihood_polar` computes the likelihood at the provided parameter values
(the values are given as angle of spherical coordinates). Optionally the
derivatives will be computed too.
}
\examples{
epsilon <- rnorm(500,mean=0,sd=1)
x     <- runif(500,0-1,1)
T     <- 3+5*x+epsilon
C     <- runif(500,min=0,max=7)
Y     <- pmin(T,C)
Delta <- as.numeric(T==Y)
likelihood_polar(0.5,c(3,5),runif(2,0,pi),runif(3,0,pi),runif(1,0,pi),cbind(1,x),Y,Delta,0.1,TRUE)

}
