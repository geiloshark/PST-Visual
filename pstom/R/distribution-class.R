#' @title Class containing a probability distribution
#' @description 
#' This is an S4 object class that includes both a numeric vector for storage of values generated using Monte Carlo methods, and a list of parameters describing the associated parameteric distribution. 
#' @details
#' The inputs determine how the distribution is initialised. If a vector of values are contained these are stored. If a distribution is named then parameters for this distribution are estimated. If the name of the distribution and parameters are given but no values then values are simulated. 
#' @seealso \code{\link{sample}}
#' @slot .Data numeric vector of derived values
#' @slot iter integer value
#' @slot pars  distribution parameter values
#' @importFrom logitnorm rlogitnorm momentsLogitnorm logit
#' @importFrom crayon blue
#' @export
setClass("distribution", contains = "numeric", slots = list(iter = "integer", name = "character", pars = "numeric", density = "character"))

setMethod("initialize", "distribution", function(.Object, ...) {
    
    .Object@.Data         <- numeric()
    .Object@iter          <- 0L
    .Object@density       <- "unspecified"
    .Object@pars          <- c(NA_real_, NA_real_)
    .Object@name          <- character()
    
    x <- list(...)
    
    if (!missing(x)) {
        
        f1 <- function(x) if(isTRUE(sum(x) > 0))  x else NA
        f2 <- function(x, y) if(!is.null(x)) x else y
        
        # assignments
        .Object@.Data        <- f2(x[[f1(which(unlist(lapply(names(x), function(y) grepl("^value?", y) & is.numeric(x[[y]])))))]], .Object@.Data)
        .Object@iter         <- f2(x[[f1(which(unlist(lapply(names(x), function(y) grepl("^iter*", y)  & is.numeric(x[[y]])))))]], .Object@iter) |> as.integer()
        .Object@density      <- f2(x[[f1(which(unlist(lapply(names(x), function(y) grepl("^dens*", y)  & is.character(x[[y]])))))]], .Object@density)
        .Object@pars         <- f2(x[[f1(which(unlist(lapply(names(x), function(y) grepl("^par?", y)   & is.numeric(x[[y]]) & length(x[[y]]) == 2))))]], .Object@pars)
        .Object@name         <- f2(x[[f1(which(unlist(lapply(names(x), function(y) grepl("^name?", y)  & is.character(x[[y]])))))]], .Object@name)
        
        # checks
        if (length(.Object@.Data) > 0 & .Object@iter == 0) {
            .Object@iter <- as.integer(length(.Object@.Data))    
        }
        
        if (any(is.na(.Object@.Data))) {
            
            .Object@.Data <- .Object@.Data[!is.na(.Object@.Data)]
            
            if (.Object@iter > length(.Object@.Data)) {
                .Object@iter <- length(.Object@.Data)    
            }
        }
    }
    
    # if data and density then estimate pars
    EST_PARS <- length(.Object@.Data) > 0 & length(.Object@density) > 0 & all(is.na(.Object@pars))
    if (EST_PARS) {
        
        if (grepl("^uniform", .Object@density)) {
            .Object@pars <- .calc_uniform_pars(.Object@.Data)    
        }
        
        if (grepl("^beta", .Object@density)) {
            .Object@pars <- .calc_beta_pars(.Object@.Data)    
        }
        
        if (grepl("^normal", .Object@density)) {
            .Object@pars <- .calc_normal_pars(.Object@.Data)    
        }
        
        if (grepl("^zt?.normal", .Object@density)) {
            .Object@pars <- .calc_ztnormal_pars(.Object@.Data)    
        }
        
        if (grepl("^log?.normal", .Object@density)) {
            .Object@pars <- .calc_lognormal_pars(.Object@.Data)    
        }
        
        if (grepl("^gamma", .Object@density)) {
            .Object@pars <- .calc_gamma_pars(.Object@.Data)    
        }
        
        if (grepl("^logit?.normal", .Object@density)) {
            .Object@pars <- .calc_logitnormal_pars(.Object@.Data)    
        }
    }
    
    # if distribution and pars then simulate values
    SIM_VALUES <- length(.Object@.Data) == 0 & length(.Object@density) > 0 & !any(is.na(.Object@pars)) & .Object@iter > 0
    if (SIM_VALUES) {
        
        if (grepl("^uniform", .Object@density)) {
            .Object@.Data <- runif(.Object@iter, min = .Object@pars[1], max = .Object@pars[2])    
        }
        
        if (grepl("^beta", .Object@density)) {
            .Object@.Data <- rbeta(.Object@iter, shape1 = .Object@pars[1], shape2 = .Object@pars[2])    
        }
        
        if (grepl("^normal", .Object@density)) {
            .Object@.Data <- rnorm(.Object@iter, mean = .Object@pars[1], sd = .Object@pars[2])    
        }
        
        if (grepl("^zt?.normal", .Object@density)) {
            .Object@.Data <- .Object@pars[1] + .Object@pars[2] * qnorm(runif(.Object@iter, pnorm((0 - .Object@pars[1]) / .Object@pars[2]), pnorm(Inf))) 
        }
        
        if (grepl("^log?.normal", .Object@density)) {
            .Object@.Data <- rlnorm(.Object@iter, meanlog = .Object@pars[1], sdlog = .Object@pars[2])    
        }
        
        if (grepl("^gamma", .Object@density)) {
            .Object@.Data <- rgamma(.Object@iter, shape = .Object@pars[1], scale = .Object@pars[2])    
        }
        
        if (grepl("^logit?.normal", .Object@density)) {
            .Object@.Data <- rlogitnorm(.Object@iter, mu = .Object@pars[1], sigma = .Object@pars[2])    
        }
    }
    
    return(.Object)
})

# {{{
setMethod("show", "distribution",
          function(object) {
              message(blue("distribution object class"))
              message("iter: ", object@iter)
              message("density: ", object@density)
              message("pars: ", paste(round(object@pars, 3), collapse = ", "))
              message("values: ", if (length(object@.Data) == 0 | all(is.na(object@.Data))) red("EMPTY") else if (length(object@.Data) > 14) paste0(c(round(object@.Data[1:12], 3), "...", round(object@.Data[length(object@.Data)], 3)), collapse = ", ") else paste0(round(object@.Data, 3), collapse = ", "))
              message("name: ", if (length(object@name) == 0) "--" else object@name)
              message("\t")
        })
# }}}

#' @exportS3Method base::summary
summary.distribution <- function(object) {
    
    if (grepl("^unspecified", object@density))  return(.show_unspecified_moments(object@.Data))
    if (grepl("^uniform", object@density))      return(.show_uniform_moments(object@pars))
    if (grepl("^beta", object@density))         return(.show_beta_moments(object@pars))
    if (grepl("^normal", object@density))       return(.show_normal_moments(object@pars))
    if (grepl("^zt?.normal", object@density))   return(.show_ztnormal_moments(object@pars))
    if (grepl("^log?normal", object@density))   return(.show_lognormal_moments(object@pars))
    if (grepl("^gamma", object@density))        return(.show_gamma_moments(object@pars))
    if (grepl("^logit?normal", object@density)) return(.show_logitnormal_moments(object@pars))
}

#' @export
expectation <- function(...) UseMethod("expectation")
#' @exportS3Method
expectation.distribution <- function(object) {
    summary(object)['E[x]']
}

# distribution-specific functions
# {{{
.calc_uniform_pars <- function(x) {
    
    # 
    a <- min(x)
    b <- max(x)
    
    # return
    return(c(a, b))
}

.show_uniform_moments <- function(x) {
    
    a <- x[1]
    b <- x[2]
    
    # return
    c('E[x]' = round((a + b) / 2, 5), 'VAR[x]' = round(((b - a)^2) / 12, 5), 'CV[x]' = round(sqrt(((b - a)^2) / 12) / ((a + b) / 2), 5))
}

.calc_beta_pars <- function(x) {
    
    # 
    xbar <- mean(x)
    xvar <- var(x)
    
    a <- xbar * (xbar * (1 - xbar) / xvar - 1) 
    b <- (1 - xbar) * (xbar * (1 - xbar) / xvar - 1)
    
    # 
    if (xvar > xbar * (1 - xbar)) {
        stop("variance of input values is too high for estimation of beta distribution parameters using the method-of-moments")    
    }
    
    # return
    return(c(a, b))
}

.show_beta_moments <- function(x) {
    
    a <- x[1]
    b <- x[2]
    
    # return
    c('E[x]' = round(a / (a + b), 5), 'VAR[x]' = round(a * b / ((a + b)^2 * (a + b + 1)), 5), 'CV[x]' = round(sqrt(a * b / ((a + b)^2 * (a + b + 1))) / (a / (a + b)), 5))
}

.calc_normal_pars <- function(x) {
    
    # estimate parameters of
    # normal distribution
    mu     <- mean(x)
    sigma  <- sd(x)
    
    # return
    return(c(mu, sigma))
}

.show_normal_moments <- function(x) {
    
    mu     <- x[1]
    sigma  <- x[2]
    sigma2 <- sigma^2
    
    # return
    c('E[x]' = round(mu, 5), 'SD[x]' = round(sigma, 5), 'VAR[x]' = round(sigma2, 5), 'CV[x]' = round(sigma / mu, 5))
}

.calc_ztnormal_pars <- function(x) {
    
    mu     <- mean(x)
    sigma  <- sd(x)
    
    # return
    return(c(mu, sigma))
}

.show_ztnormal_moments <- function(x) {
    
    mu     <- x[1]
    sigma  <- x[2]
    
    # return
    c('E[x]' = round(mu / (1 - pnorm(0, mu, sigma)), 5), 'VAR[x]' = round(NA_real_, 5), 'CV[x]' = round(NA_real_, 5))
}

.calc_lognormal_pars <- function(x) {
    
    # transform to normal
    y <- log(x)
    
    # estimate parameters of
    # normal distribution log(x)
    mu     <- mean(y)
    sigma  <- sd(y)
    
    # return
    return(c(mu, sigma))
}

.show_lognormal_moments <- function(x) {
    
    mu     <- x[1]
    sigma  <- x[2]
    sigma2 <- sigma^2
    
    theta <- exp(mu + sigma2/2)
    nu    <- exp(2*mu + sigma2)*(exp(sigma2) - 1)
    cv    <- sqrt(exp(sigma2) - 1)
    
    # return
    c('E[log(x)]' = round(mu, 5), 'SD[log(x)]' = round(sigma, 5), 'E[x]' = round(theta, 5), 'VAR[x]' = round(nu, 5), 'CV[x]' = round(cv, 5))
}

.calc_gamma_pars <- function(x) {
    
    # 
    ln.x   <- log(x)
    x.ln.x <- x * log(x) 
    
    theta <- mean(x.ln.x) - mean(x) * mean(ln.x)
    alpha <- mean(x) / theta
    
    # return
    return(c(alpha, theta))
}

.show_gamma_moments <- function(x) {
    
    alpha  <- x[1]
    theta  <- x[2]
    
    # return
    c('E[x]' = round(alpha * theta, 5), 'VAR[x]' = round(alpha * theta^2, 5), 'CV[x]' = round(sqrt(alpha * theta^2) / alpha * theta, 5))
}

.show_unspecified_moments <- function(x) {
    
    # return
    c('E[x]' = round(mean(x), 5), 'MIN[x]' = round(min(x), 5), 'MAX[x]' = round(max(x), 5))
}

.calc_logitnormal_pars <- function(x) {
    
    # transform form 
    # to (0, 1) to (-Inf,Inf)
    y <- logit(x)
    
    # estimate parameters of
    # normal distribution logit(x)
    mu     <- mean(y)
    sigma  <- sd(y)
    
    # return
    return(c(mu, sigma))
}

.show_logitnormal_moments <- function(x) {
    
    mu     <- x[1]
    sigma  <- x[2]
    
    theta <- as.numeric(momentsLogitnorm(mu, sigma)[1])
    nu    <- as.numeric(momentsLogitnorm(mu, sigma)[2])
    cv    <- sqrt(nu) / theta
    
    # return
    c('E[logit(x)]' = round(mu, 5), 'SD[logit(x)]' = round(sigma, 5), 'E[x]' = round(theta, 5), 'VAR[x]' = round(nu, 5), 'CV[x]' = round(cv, 5))
}

# }}}
