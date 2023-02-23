#' Laguerre Estimator
#'
#' `laguerre_estimator` computes the Laguerre estimator for given degrees m, m_tilde and M. For a detailed description of how the optimisation works we refer to the documentation pdf.
#'
#' @param m,m_tilde Integers which specify the model dimension in the density
#' @param M Integer which specifies the degree of the heteroskedasticity that is estimated (\code{"M=0"}, the default, fits a homoskedastic model)
#' @param Cov Matrix with covariates: Every row corresponds to an observation, each column corresponds to a covariate. No column of Cov is allowed to be constant, the intercept is added automatically. If no covariates shall be used, this should be set to NULL, the default.
#' @param Y Vector of responses, \code{"length(Y)"} must equal \code{"nrow(Cov)"}
#' @param Delta Vector of censoring indicators, \code{"Delta[i]=1"} means that observation i is not censored, \code{"length(Delta)"} must equal \code{"length(Y)"}
#' @param sigma0 Intercept that is added to the heteroskedasticity function, default is 0.2.
#' @param tau Quantile of interest, element of (0,1)
#' @param starting_beta If provided this is the initial value for beta used for the optimization routine, if FALSE, the default, a starting value is computed by letting \code{"m=m_tilde=0"}
#' @param trials Number of random starting points for theta, theta_tilde and lambda in the optimization (default is 32)
#'
#' @return The function returns a list with the five elements "objective" (optimal value of likelihood), "beta" (estimator for beta), "theta", "theta_tilde", "lambda" (estimates for the corresponding parameters).
#'
#' @examples
#' epsilon <- rnorm(500,mean=0,sd=1)
#' x     <- runif(500,0-1,1)
#' T     <- 3+5*x+epsilon
#' C     <- runif(500,min=0,max=7)
#' Y     <- pmin(T,C)
#' Delta <- as.numeric(T==Y)
#' laguerre_estimator(m=0,m_tilde=0,M=0,Cov=x,Y=Y,Delta=Delta,sigma0=0.1,tau=0.5,starting_beta=FALSE,trials=32)
#'
#' @export
laguerre_estimator <- function(m,m_tilde,M=0,Cov=NULL,Y,Delta,sigma0=0.2,tau,starting_beta=FALSE,trials=32) {
  ## Read data
  n <- length(Y)

  ## Add intercept to covariates
  if(is.null(Cov)) {
    X <- matrix(1,ncol=1,nrow=n)
    p <- 0
  } else if(is.null(dim(Cov))) {
    X <- matrix(1,ncol=2,nrow=n)
    X[,2] <- Cov
    p <- 1
  } else {
    X <- cbind(1,Cov)
    p <- dim(Cov)[2]
  }

  ## Compute Initial value for beta
  if(isFALSE(starting_beta)==TRUE) {
    starting_beta <- rep(0,p+1)
  } else if (length(starting_beta)!=p+1) {
    stop("Starting value has wrong dimension\n")
  }
  opts <- list(algorithm="NLOPT_LD_LBFGS",print_level=0,xtol_rel=0.000001,maxeval=20000)
  out <- nloptr::nloptr(x0=starting_beta,eval_f=likelihood_wrapper_beta_only,opts=opts,X=X,Y=Y,Delta=Delta,sigma0=sigma0,tau=tau)
  beta_no_lag <- out$solution

  ## If m=m_tilde=p*M=0 that was it already
  if(m==0 & m_tilde==0 & p*M==0) {
    return(list("objective"=-out$objective,"beta"=beta_no_lag,"theta"=1,"theta_tilde"=1))
  }

  ## Create random grid for theta and theta_tilde
  starting_values <- matrix(0,nrow=trials,ncol=p+1+m+m_tilde+p*M)

  ## Beta is the same for all starting values
  starting_values[,1:(p+1)] <- matrix(beta_no_lag,ncol=p+1,nrow=trials,byrow = TRUE)

  ## Add trials many random points for theta and theta_tilde
  if(m!=0) {
    grid <- matrix(runif(trials*m),nrow=trials)
    starting_values[,(p+2):(p+1+m)] <- pi*grid
  }
  if(m_tilde!=0) {
    grid <- matrix(runif(trials*m_tilde),nrow=trials)
    starting_values[,(p+m+2):(p+1+m+m_tilde)] <- pi*grid
  }
  if(p*M!=0) {
    grid <- matrix(runif(trials*p*M),nrow=trials)
    starting_values[,(p+m+m_tilde+2):(p+1+m+m_tilde+p*M)] <- pi*grid
  }

  ## Do the optimization for each of the points in the grid
  dims <- c(p+1,m,m_tilde,p*M)
  result <- matrix(0,nrow=trials,ncol=1+sum(dims))
  opts <- list(algorithm="NLOPT_LD_LBFGS",print_level=0,xtol_rel=0.000001,maxeval=20000)

  for(i in 1:trials) {
    ## Choose appropriate wrapper
    if(m==0 & m_tilde>0 & p*M==0) {
      function_to_optimize <- likelihood_wrapper_bt
    }
    if(m==0 & m_tilde>0 & p*M>0) {
      function_to_optimize <- likelihood_wrapper_btM
    }
    if(m==0 & m_tilde==0 & p*M>0) {
      function_to_optimize <- likelihood_wrapper_bM
    }
    if(m>0 & m_tilde==0 & p*M==0) {
      function_to_optimize <- likelihood_wrapper_bm
    }
    if(m>0 & m_tilde==0 & p*M>0) {
      function_to_optimize <- likelihood_wrapper_bmM
    }
    if(m>0 & m_tilde>0 & p*M==0) {
      function_to_optimize <- likelihood_wrapper_bmt
    }
    if(m>0 & m_tilde>0 & p*M>0) {
      function_to_optimize <- likelihood_wrapper_bmtM
    }

    ## Perform Likelihood optimisation
    out <- nloptr::nloptr(x0=starting_values[i,],eval_f=function_to_optimize,lb=c(rep(-Inf,p+1),rep(0,sum(dims)-p-1)),ub=c(rep(Inf,p+1),rep(pi,sum(dims)-p-1)),opts=opts,X=X,Y=Y,Delta=Delta,sigma0=sigma0,tau=tau,p=p,m=m,m_tilde=m_tilde,M=M)

    ## Save results
    result[i,1] <- out$objective
    result[i,2:(sum(dims)+1)] <- out$solution
  }


  ## Choose the best value
  opt <- min(which(result[,1]==min(result[,1])))
  beta_est <- result[opt,2:(p+2)]
  if(m!=0) {
    theta_est <- SphericalCubature::polar2rect(1,result[opt,(p+3):(p+2+m)])
  } else {
    theta_est <- 1
  }
  if(m_tilde!=0) {
    theta_tilde_est <- SphericalCubature::polar2rect(1,result[opt,(p+3+m):(p+2+m+m_tilde)])
  } else {
    theta_tilde_est <- 1
  }
  if(p*M!=0) {
    lambda_est <- matrix(NA,ncol=p,nrow=M+1)
    for(k in 1:p) {
      lambda_est[,k] <- SphericalCubature::polar2rect(1,result[opt,(p+3+m+m_tilde+(k-1)*M):(p+2+m+m_tilde+k*M)])
    }
  } else {
    if(p==0) {
      lambda_est=NA
    } else {
      lambda_est <- matrix(1,ncol=p,nrow=1)
    }
  }

  L <- -result[opt,1]

  ## Return
  return(list("objective"=L,"beta"=beta_est,"theta"=theta_est,"theta_tilde"=theta_tilde_est,"lambda"=lambda_est))
}

#' Likelihood for Spherical Coordinates
#'
#' `likelihood_polar` computes the likelihood at the provided parameter values (the values are given as angle of spherical coordinates). Optionally the derivatives will be computed too.
#'
#' @param tau Quantile of interest from the interval (0,1)
#' @param beta Value for the beta parameter (always in Cartesian coordinates)
#' @param theta_polar,theta_tilde_polar,lambda_polar Angles in spherical coordinates for the corresponding parameters. The radius is always equal to one. If the 1-dim Cartesion coordinate 1 is shall be used, the corresponding parameter has to be set to FALSE.
#' @param X Matrix containing covariates to be used, first column must be an intercept. Each row corresponds to an observation, each column corresponds to a covariate. The number of columns must equal the length of beta.
#' @param Y Scalar vector of observations, its lenght must equal the number of rows in X.
#' @param Delta Vector of zeros and ones of the same length as Y. A one indicates that the corresponding observation is uncensored.
#' @param sigma0 Value to be added to te heteroskedasticity function.
#' @param derivative If TRUE the derivatives with respect to beta and all variables are returned which do not equal FALSE
#'
#' @return If \code{"derivative=FALSE"} the value of the likelihood is returned. Otherwise a list is returned with the element "objective" which contains the likelihood and a vector "gradient" which concatenates all gradients beginning with beta, theta, theta_tilde, lambda. If some variable is specified as FALSE, it is ommited in the gradient.
#'
#' @examples epsilon <- rnorm(500,mean=0,sd=1)
#' x     <- runif(500,0-1,1)
#' T     <- 3+5*x+epsilon
#' C     <- runif(500,min=0,max=7)
#' Y     <- pmin(T,C)
#' Delta <- as.numeric(T==Y)
#' likelihood_polar(0.5,c(3,5),runif(2,0,pi),runif(3,0,pi),runif(1,0,pi),cbind(1,x),Y,Delta,0.1,TRUE)
#'
#' @export
likelihood_polar <- function(tau,beta,theta_polar,theta_tilde_polar,lambda_polar,X,Y,Delta,sigma0,derivative=FALSE) {
  p <- length(beta)-1
  ## Compute Cartesian coordinates
  if(isFALSE(theta_polar)) {
    theta <- 1
    m <- 0
  } else {
    theta <- SphericalCubature::polar2rect(1,theta_polar)
    m <- length(theta_polar)
  }
  if(isFALSE(theta_tilde_polar)) {
    theta_tilde <- 1
    m_tilde <- 0
  } else {
    theta_tilde <- SphericalCubature::polar2rect(1,theta_tilde_polar)
    m_tilde <- length(theta_tilde_polar)
  }
  if(isFALSE(lambda_polar)) {
    lambda <- rep(1,p)
    M <- 0
  } else {
    if(is.null(dim(lambda_polar))) {
      lambda_polar <- matrix(lambda_polar,ncol=1)
    }
    lambda <- apply(lambda_polar,2,SphericalCubature::polar2rect,r=1)
    M <- dim(lambda_polar)[1]
  }

  out <- .Call("likelihood",Y,X,as.integer(Delta),beta,sigma0,lambda,tau,theta,theta_tilde)

  if(isFALSE(derivative)) {
    return(out[[1]])
  } else {
    dim_grad <- p+1+m+m_tilde+p*M
    grad <- rep(NA,dim_grad)

    ## Add derivative with respect to beta
    grad[1:(p+1)] <- out[[2]]

    ## Derivative with respect to theta
    if(m>0) {
      DT <- polar_derivative(theta_polar)
      grad[(p+2):(p+1+m)] <- t(DT)%*%out[[3]]
    }

    ## Derivative with respect to theta_tilde
    if(m_tilde>0) {
      DT <- polar_derivative(theta_tilde_polar)
      grad[(p+1+m+1):(p+1+m+m_tilde)] <- t(DT)%*%out[[4]]
    }

    ## Derivative with respect to lambda
    if(p*M>0) {
      for(k in 1:p) {
        DT <- polar_derivative(lambda_polar[,k])
        grad[(p+1+m+m_tilde+(k-1)*M+1):(p+1+m+m_tilde+k*M)] <- t(DT)%*%out[[5]]
      }
    }

    return(list("objective"=out[[1]],"gradient"=grad))
  }
}





#' Cross-Validation Criterion
#'
#' `cv_criterion` Computes the cross-validation criterion for given model dimensions m, m_tilde and M.
#'
#' Note that the splitting of the data is random and happens in this function. Therefore consecutive calls of this function will yield different results.
#'
#' @param m,m_tilde Integers which specify the model dimension in the density.
#' @param M Integer which specifies the degree of the heteroskedasticity that is estimated (\code{"M=0"} fits a homoskedastic model)
#' @param Cov Matrix with covariates: Every row corresponds to an observation, each column corresponds to a covariate. No column of Cov is allowed to be constant, the intercept is added automatically. If no covariates shall be used, this should be set to NULL.
#' @param Y Vector of responses, \code{"length(Y)"} must equal \code{"nrow(Cov)"}
#' @param Delta Vector of censoring indicators, \code{"Delta[i]=1"} means that observation i is not censored, \code{"length(Delta)"} must equal \code{"length(Y)"}
#' @param sigma0 Intercept that is added to the heteroskedasticity function.
#' @param tau Quantile of interest, element of (0,1)
#' @param starting_beta If provided this is the initial value for beta used for the optimization routine, if FALSE, a starting value is computed by letting \code{"m=m_tilde=0"}
#' @param trials Number of random starting points for theta, theta_tilde and lambda in the optimization
#' @param nfolds The number of folds to be used in the cross-validation.
#'
#' @return The value of the cross-validation criterion divided by \code{"nfolds"}.
#'
#' @examples epsilon <- rnorm(500,mean=0,sd=1)
#' x     <- runif(500,0-1,1)
#' T     <- 3+5*x+epsilon
#' C     <- runif(500,min=0,max=7)
#' Y     <- pmin(T,C)
#' Delta <- as.numeric(T==Y)
#' CV_criterion(2,2,2,x,Y,Delta,0.1,0.5,FALSE,32,5)
#'
#' @export
CV_criterion <- function(m,m_tilde,M,Cov,Y,Delta,sigma0,tau,starting_beta,trials,nfolds) {
  ## Find random folds an save their indices
  if(nfolds==1) {
    stop("Need at least two folds, for regular estimation use laguerre_estimator")
  }
  if(is.null(Cov)) {
    p <- 0
  } else if(is.null(dim(Cov))) {
    Cov <- matrix(Cov,ncol=1)
    p <- 1
  } else {
    p <- dim(Cov)[2]
  }
  n <- length(Y)
  K <- ceiling(n/nfolds)
  fold_indices <- matrix(0,ncol=K,nrow=nfolds)
  ind <- sample(1:n,n)
  for(i in 1:(nfolds-1)) {
    fold_indices[i,1:K] <- ind[((i-1)*K+1):(i*K)]
  }
  fold_indices[nfolds,1:(n-(nfolds-1)*K)] <- ind[((nfolds-1)*K+1):n]

  ## Compute Estimates by Leaving out the folds step by step
  beta_est <- matrix(0,nrow=nfolds,ncol=p+1)
  for(i in 1:nfolds) {
    ## Find indices of fold
    current_indices <- setdiff(1:n,fold_indices[i,])

    ## Compute estimate
    out <- laguerre_estimator(m,m_tilde,M,Cov[current_indices,],Y[current_indices],Delta[current_indices],sigma0,tau,starting_beta,trials)
    beta_est[i,] <- out$beta
  }

  ## Compute Cross-Validation Criterion
  CVcrit <- 0
  for(i in 1:nfolds) {
    test_indices <- fold_indices[i,which(Delta[fold_indices[i,]]==1)]
    if(is.null(Cov)) {
      CVcrit <- CVcrit+sum(check_function(Y[test_indices]-beta_est[i,1],tau))/length(test_indices)
    } else {
      CVcrit <- CVcrit+sum(check_function(Y[test_indices]-beta_est[i,1]-as.matrix(Cov[test_indices,])%*%beta_est[i,2:(p+1)],tau))/length(test_indices)
    }

  }
  CVcrit <- CVcrit/nfolds

  return(CVcrit)
}

#' Cross Validation
#'
#' `laguerre_cross_validation` performs Cross-Validation for the dimensions of the approximation m, m_tilde and M.
#'
#' The function [laguerre_estimator()] is repeatedly called with different values for \code{"m"}, \code{"m_tilde"} and \code{"M"}. The other values are always the same as specified in the call of this function. Note that the data splitting itself happens in the function [CV_criterion()] as described there. This functions is just an optimization algorithm for \code{"CV_criterion"}.
#'
#' @param Y Vector of responses, \code{"length(Y)"} must equal \code{"nrow(Cov)"}
#' @param Delta Vector of censoring indicators, \code{"Delta[i]=1"} means that observation i is not censored, \code{"length(Delta)"} must equal \code{"length(Y)"}
#' @param tau Quantile of interest, element of (0,1)
#' @param sigma0 Intercept that is added to the heteroskedasticity function.
#' @param print.level If 0 (the default) no status information is printed, for all other values the current step is printed.
#' @param maxdim Integer dimension at which the optimisation shall stop at the latest: If either m, m_tilde or M gets larger than maxdim, the optimisation is stopped and the current values of m, m_tilde and M are returned. The default is 10.
#' @param Cov Matrix with covariates: Every row corresponds to an observation, each column corresponds to a covariate. No column of \code{"Cov"} is allowed to be constant, the intercept is added automatically. If no covariates shall be used, this should be set to NULL (the default).
#' @param starting_beta If provided this is the initial value for beta used for the optimization routine, if FALSE (the default), a starting value is computed by letting \code{"m=m_tilde=0"}
#' @param trials Number of random starting points for theta, theta_tilde and lambda in the optimization (the default is 32).
#' @param nfolds The number of folds to be used in the cross-validation (the default is 5).
#'
#' @return List of five elements: m, m_tilde and M contain the found degrees and est contains the output of \code{"laguerre_estimator"} for these degrees. The element path is a matrix od four columns: The first three columns contain values of m, m_tilde and M and the fourth column show the corresponding value of the cross-validation criterion.
#'
#' @examples epsilon <- rnorm(500,mean=0,sd=1)
#' x     <- runif(500,0-1,1)
#' T     <- 3+5*x+epsilon
#' C     <- runif(500,min=0,max=7)
#' Y     <- pmin(T,C)
#' Delta <- as.numeric(T==Y)
#' laguerre_cross_validation(Y,Delta,0.5,0.1,1,Cov=x)
#'
#' @export
laguerre_cross_validation <- function(Y,Delta,tau,sigma0,print.level=0,maxdim=10,Cov=NULL,starting_beta=FALSE,trials=32,nfolds=5) {
  ## Make sure that Cov is a matrix
  if(!is.null(Cov)) {
    if(is.null(dim(Cov))) {
      Cov <- matrix(Cov,ncol=1)
    }
  }

  ## Compute initial values of CV criterion
  m <- 0
  m_tilde <- 0
  M <- 0

  current_CV       <- CV_criterion(m  ,m_tilde  ,M  ,Cov,Y,Delta,sigma0,tau,starting_beta,trials,nfolds)
  m_advance_CV     <- CV_criterion(m+1,m_tilde  ,M  ,Cov,Y,Delta,sigma0,tau,starting_beta,trials,nfolds)
  tilde_advance_CV <- CV_criterion(m  ,m_tilde+1,M  ,Cov,Y,Delta,sigma0,tau,starting_beta,trials,nfolds)
  M_advance_CV     <- CV_criterion(m  ,m_tilde  ,M+1,Cov,Y,Delta,sigma0,tau,starting_beta,trials,nfolds)

  ## Save the beginning of the cross-validation path
  path <- matrix(0,ncol=4,nrow=4)
  colnames(path) <- c("m","tilde_m","M","CV")
  path[1,] <- c(0,0,0,current_CV)
  path[2,] <- c(1,0,0,m_advance_CV)
  path[3,] <- c(0,1,0,tilde_advance_CV)
  path[4,] <- c(0,0,1,M_advance_CV)

  ## Check if no model is already the best
  READY_FLAG <- FALSE
  if(current_CV<=min(c(m_advance_CV,tilde_advance_CV,M_advance_CV))) {
    READY_FLAG <- TRUE
  }

  ## Increase the dimension until minimum or maximum dimension is reached
  while(!READY_FLAG) {
    ## Print status
    if(print.level>0) {
      cat("Consider dimension m=",m,", m_tilde=",m_tilde,", M=",M,".\n")
    }

    ## Check in which direction to proceed
    if(m_advance_CV<min(c(tilde_advance_CV,M_advance_CV))) {
      m <- m+1
      current_CV <- m_advance_CV
    } else if(tilde_advance_CV<min(c(m_advance_CV,M_advance_CV))) {
      m_tilde <- m_tilde+1
      current_CV <- tilde_advance_CV
    } else {
      M <- M+1
      current_CV <- M_advance_CV
    }

    ## Compute next step
    m_advance_CV     <- CV_criterion(m+1,m_tilde  ,M  ,Cov,Y,Delta,sigma0,tau,starting_beta,trials,nfolds)
    tilde_advance_CV <- CV_criterion(m  ,m_tilde+1,M  ,Cov,Y,Delta,sigma0,tau,starting_beta,trials,nfolds)
    M_advance_CV     <- CV_criterion(m  ,m_tilde  ,M+1,Cov,Y,Delta,sigma0,tau,starting_beta,trials,nfolds)

    ## Save progress of Cross-validation Path
    path <- rbind(path,c(m+1,m_tilde  ,M  ,m_advance_CV))
    path <- rbind(path,c(m  ,m_tilde+1,M  ,tilde_advance_CV))
    path <- rbind(path,c(m  ,m_tilde  ,M+1,M_advance_CV))


    ## Check if convergence is reached
    if(current_CV<=min(c(m_advance_CV,tilde_advance_CV,M_advance_CV))) {
      READY_FLAG <- TRUE
    }
    ## Or if the maximum dimension has been reached
    if(max(c(m,m_tilde,M)>=maxdim)) {
      READY_FLAG <- TRUE
    }
  }

  ## Compute estimate using all observations
  est <- laguerre_estimator(m,m_tilde,M,Cov,Y,Delta,sigma0,tau,starting_beta,trials)

  return(list(m=m,m_tilde=m_tilde,M=M,est=est,path=path))
}






## Wrappers for likelihood
likelihood_wrapper_beta_only <- function(beta,X,Y,Delta,sigma0,tau) {
  out <- .Call("likelihood",Y,X,as.integer(Delta),beta,sigma0,1,tau,1,1)
  return(list("objective"=-out[[1]],"gradient"=-out[[2]]))
}
likelihood_wrapper_bm <- function(par,X,Y,Delta,sigma0,tau,p,m,m_tilde,M) {
  beta <- par[1:(p+1)]
  theta_polar <- par[(p+2):(p+1+m)]
  theta_tilde_polar <- FALSE
  lambda_polar <- FALSE

  out <- likelihood_polar(tau,beta,theta_polar,theta_tilde_polar,lambda_polar,X,Y,Delta,sigma0,derivative=TRUE)

  return(list("objective"=-out$objective,"gradient"=-out$gradient))
}
likelihood_wrapper_btM <- function(par,X,Y,Delta,sigma0,tau,p,m,m_tilde,M) {
  beta <- par[1:(p+1)]
  theta_polar <- FALSE
  theta_tilde_polar <- par[(p+2):(p+1+m_tilde)]
  lambda_polar <- par[(p+2+m_tilde):(p+1+m_tilde+p*M)]

  out <- likelihood_polar(tau,beta,theta_polar,theta_tilde_polar,lambda_polar,X,Y,Delta,sigma0,derivative=TRUE)

  return(list("objective"=-out$objective,"gradient"=-out$gradient))
}
likelihood_wrapper_bM <- function(par,X,Y,Delta,sigma0,tau,p,m,m_tilde,M) {
  beta <- par[1:(p+1)]
  theta_polar <- FALSE
  theta_tilde_polar <- FALSE
  lambda_polar <- par[(p+2):(p+1+p*M)]

  out <- likelihood_polar(tau,beta,theta_polar,theta_tilde_polar,lambda_polar,X,Y,Delta,sigma0,derivative=TRUE)

  return(list("objective"=-out$objective,"gradient"=-out$gradient))
}
likelihood_wrapper_bt <- function(par,X,Y,Delta,sigma0,tau,p,m,m_tilde,M) {
  beta <- par[1:(p+1)]
  theta_polar <- FALSE
  theta_tilde_polar <- par[(p+2):(p+1+m_tilde)]
  lambda_polar <- FALSE

  out <- likelihood_polar(tau,beta,theta_polar,theta_tilde_polar,lambda_polar,X,Y,Delta,sigma0,derivative=TRUE)

  return(list("objective"=-out$objective,"gradient"=-out$gradient))
}
likelihood_wrapper_bmM <- function(par,X,Y,Delta,sigma0,tau,p,m,m_tilde,M) {
  beta <- par[1:(p+1)]
  theta_polar <- par[(p+2):(p+1+m)]
  theta_tilde_polar <- FALSE
  lambda_polar <- par[(p+2+m):(p+1+m+p*M)]

  out <- likelihood_polar(tau,beta,theta_polar,theta_tilde_polar,lambda_polar,X,Y,Delta,sigma0,derivative=TRUE)

  return(list("objective"=-out$objective,"gradient"=-out$gradient))
}
likelihood_wrapper_bmt <- function(par,X,Y,Delta,sigma0,tau,p,m,m_tilde,M) {
  beta <- par[1:(p+1)]
  theta_polar <- par[(p+2):(p+1+m)]
  theta_tilde_polar <- par[(p+2+m):(p+1+m+m_tilde)]
  lambda_polar <- FALSE

  out <- likelihood_polar(tau,beta,theta_polar,theta_tilde_polar,lambda_polar,X,Y,Delta,sigma0,derivative=TRUE)

  return(list("objective"=-out$objective,"gradient"=-out$gradient))
}
likelihood_wrapper_bmtM <- function(par,X,Y,Delta,sigma0,tau,p,m,m_tilde,M) {
  beta <- par[1:(p+1)]
  theta_polar <- par[(p+2):(p+1+m)]
  theta_tilde_polar <- par[(p+2+m):(p+1+m+m_tilde)]
  lambda_polar <- par[(p+2+m+m_tilde):(p+1+m+m_tilde+p*M)]

  out <- likelihood_polar(tau,beta,theta_polar,theta_tilde_polar,lambda_polar,X,Y,Delta,sigma0,derivative=TRUE)

  return(list("objective"=-out$objective,"gradient"=-out$gradient))
}





################################################################################
## The functions below are used internally in the functions above. In most    ##
## cases the user will not need to call these functions directly.             ##
################################################################################

## Computes the derivative of the polar coordinate transform for r=1 and set of
## angles phi
polar_derivative <- function(phi) {
  m <- length(phi)
  deriv <- matrix(0,ncol=m,nrow=m+1)
  for(i in 1:m) {
    shift <- rep(0,m)
    shift[i] <- pi/2
    deriv[i:(m+1),i] <- SphericalCubature::polar2rect(1,phi+shift)[i:(m+1)]
  }

  return(deriv)
}

## Implementation of the check function
check_function <- function(z,tau) {
  return(z*(tau-as.numeric(z<=0)))
}