# default population dynamics functions
# (can use any values returned by get_values() and get_dim())
.aspm <- function() {
    
    n    <- array(dim = c(nages, ntime))
    bmat <- vector("numeric", length = ntime)
    bexp <- vector("numeric", length = ntime)
    hr   <- vector("numeric", length = ntime)
    p    <- vector("numeric", length = nages)
    
    trim <- function(x) min(max(x, 0), 1)
    
    # set up equilibrium population
    p[1] <- 1
    for(a in 2:nages)
        p[a] <- p[a-1] * exp(-M[a - 1])
    p[nages] <- p[nages] / (1 - exp(-M[nages]))
    rho <- sum(p * maturity * mass)
    R0 <- B0 / rho
    
    n[,1]   <- R0 * p
    bmat[1] <- sum(n[,1] * maturity * mass)
    bexp[1] <- sum(n[,1] * selectivity * mass)
    hr[1]   <- trim(catch[1] / bexp[1])
    
    # set up S-R parameters
    # (alpha)
    alp <- (4 * h * R0) / (5 * h - 1)
    # (beta)
    bet <- B0 * (1 - h) / (5 * h - 1)
    
    for(y in 2:ntime) {
        
        n[1, y] <- alp * bmat[y - 1] / (bet + bmat[y - 1])
        for(a in 2:nages) {
            n[a, y] <- n[a - 1, y - 1] * exp(-M[a - 1]) * (1 - selectivity[a - 1] * hr[y - 1])
        }
        n[nages, y] <- n[nages, y] + n[nages, y - 1] * exp(-M[a - 1]) * (1 - selectivity[nages] * hr[y - 1])
        bexp[y]     <- sum(n[, y] * selectivity * mass)
        hr[y]       <- trim(catch[y] / bexp[y])
        bmat[y]     <- sum(n[, y] * maturity * mass)
    }
    
    # return numbers at age
    return(array(n, dim = dim(n), dimnames = list(age = ages, time = time)))
}

.logistic <- function() {
    
    x    <- numeric(ntime)
    x[1] <- 1
    
    for (t in 2:ntime) {
        
        x[t] <- x[t - 1] + rmax * x[t - 1] * (1 - x[t - 1]) - catch[t - 1] / K    
    }
    
    # record catches and depletion
    # in parent environment
    assign('catch',                  catch, envir = parent.frame(1))
    assign('depletion',                  x, envir = parent.frame(1))
    assign('harvest_rate', catch / (x * K), envir = parent.frame(1))
    
    # return cohort aggregated numbers
    return(array(x, dim = c(1, ntime), dimnames = list(age = NA_character_, time = time)))
}
#}

