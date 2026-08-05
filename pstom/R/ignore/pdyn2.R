#' @title Population dynamics function
#' 
#' @description The population dynamics function is called per-iteration.
#' 
#' @export
#' @include om-class.R
#' @import RTMB
#{{{ pdyn()
# wrapper for execution of population
# dynamics function
# -- executes object@pdyn for each monte-carlo sample
setGeneric("pdyn", function(object, ...) standardGeneric("pdyn"))
setMethod("pdyn", signature = "om", function(object, ...) {
    
    # current environment
    ENV <- environment()
    
    # make sure harvest rate
    # function has correct
    # environment
    environment(object@harvest_rate) <- ENV
    
    # load time, age and
    # iteration dimensions
    # into function environment
    get_dim(object, env = ENV)
    
    # get data
    get_data(object, env = ENV)
    
    # setup numbers array
    if (all(is.na(ages))) {
        N <- array(dim = c(niter, 1, ntime))
    } else {
        N <- array(dim = c(niter, nages, ntime))
    }
    
    # error term
    sigmap <- sqrt(log(1 + cv_dynamics^2))
    
    # setup diagnostics
    # (catch)
    object@diagnostics$catch <- matrix(NA_real_, nrow = iter, ncol = ntime)
    # (depletion)
    object@diagnostics$depletion <- matrix(NA_real_, nrow = iter, ncol = ntime)
    # (harvest rate)
    object@diagnostics$harvest_rate <- matrix(NA_real_, nrow = iter, ncol = ntime)
    
    # pst
    object@pst$value <- matrix(NA_real_, nrow = iter, ncol = ntime)
    
    # progress
    msg <- ""
    cli_progress_step("Projecting dynamics{msg}", spinner = TRUE, msg_done = "Projected dynamics")
    
    # {{{
    # PT model
    if (all(is.na(object@ages)) | !(length(object@ages) > 1)) {
        
        for (i in 1:niter) {
            
            # spin spinner
            cli_progress_update()
            
            # set seed
            set.seed(rng_seed[i])
            
            # progress iteration
            msg <- glue(", iteration {i}/", niter)
            
            # spin spinner
            cli_progress_update()
            
            # sample
            perr <- matrix(rnorm(ntime * equ_iter, 0 - (sigmap^2) / 2, sigmap), nrow = equ_iter, ncol = ntime)
            pars <- unlist(lapply(object@pars, sample, n = 1))
            
            # spin spinner
            cli_progress_update()
            
            # project under harvest rate
            # function
            # {{{
            b <- matrix(NA_real_, nrow = equ_iter, ncol = ntime)
            K <- exp(pars[1])
            r <- exp(pars[2])
            h <- matrix(NA_real_, nrow = equ_iter, ncol = ntime)
            
            # dynamics
            for (j in 1:equ_iter) {
                
                b[j, 1] <- (K * initial_depletion) * exp(perr[j, 1])
                
                for (k in 2:ntime) {
                    
                    h[j, k - 1] <- object@harvest_rate(object, i)
                    
                    b[j, k] <- (b[j, k - 1] + r / shape * b[j, k - 1] * (1 - (b[j, k - 1] / K)^shape) - h[j, k - 1] * b[j, k - 1]) * exp(perr[j, k])  
                }
            }
            #}}}
            
            # spin spinner
            cli_progress_update()
            
            # update diagnostics
            # (catch)
            object@diagnostics$catch[i,] <- apply(b * h, 2, mean)
            # (depletion)
            object@diagnostics$depletion[i,] <- apply(b / K, 2, mean)
            # (harvest rate)
            object@diagnostics$harvest_rate[i,] <- apply(h, 2, mean)
            
            # spin spinner
            cli_progress_update()
            
            # population
            N[i, 1, ] <- apply(b, 2, mean)
            
            # pst
            object@pst$value[i, ] <- (1 / 2) * object@pst$phi * object@pst$rmax[i] * N[i, 1, ]
        }
    } else {
    # {{{
    # AGE-STRUCTURED MODEL
        
        # vectors from age = 0 to age = nages - 1
        mat    <- c(rep(0, age_mat + 1), rep(1, nages - age_mat - 1))
        pat    <- c(rep(0, age_pat + 1), rep(1, nages - age_pat - 1))
        sel    <- c(rep(0, age_sel + 1), rep(1, nages - age_sel - 1))
        S      <- c(S0, rep(S1, nages - 1))
        M      <- -log(S)
        
        # set-up arrays
        n <- array(dim = c(nages, ntime))
        p <- vector("numeric", length = nages)
        
        proj_h         <- array(dim = c(equ_iter, ntime))
        proj_catch     <- array(dim = c(equ_iter, ntime))
        proj_depletion <- array(dim = c(equ_iter, ntime))
        proj_n         <- array(dim = c(equ_iter, nages, ntime))
        
        # set-up birth function
        birth <- function(y) {
            0.5 * sum(pat[-1] * n[-1,y]) * (b_eq + (b_max - b_eq) * (1 - (sum(n[-1,y]) / sum(k[-1]))^shape)) 
        }
        
        # set up unexploited 
        # equilibrium female
        # population
        p[1] <- 0.5
        for(a in 2:nages) {
            p[a] <- p[a-1] * exp(-M[a - 1])
        }
        p[nages] <- p[nages] / (1 - exp(-M[nages]))
        
        # loop over monte-carlo
        # samples from 'pars'
        for (i in 1:niter) {
            
            # set seed
            set.seed(rng_seed[i])
            
            # progress iteration
            msg <- glue(", iteration {i}/", niter)
            
            # spin spinner
            cli_progress_update()
            
            # sample
            perr <- matrix(rnorm(ntime * equ_iter, 0 - (sigmap^2) / 2, sigmap), nrow = equ_iter, ncol = ntime)
            pars <- unlist(lapply(object@pars, sample, n = 1))
            
            # project under harvest rate
            # function
            # {{{
            
            # monte-carlo
            # inputs
            K <- exp(pars[1])
            r <- exp(pars[2])
            e <- perr
            
            # productivity for estimation
            # of b_max
            lambda <- exp(r)
            
            # replacement birth rate
            # per female
            b_eq  <- 1 / sum(pat * p)
            
            # maximum birth rate
            # per female
            b_max <- 2 * (lambda^(age_pat) - S1 * lambda^(age_pat - 1)) / (S0 * S1^(age_pat - 1))
            
            # initialise population
            # at equilibrium
            n_init <- b_eq * p
            
            # initial conditions
            # (1+ depletion = 1)
            k <- K * n_init / sum(n_init[-1])
            
            # loop over process
            # error iterations
            for (j in 1:equ_iter) {
                
                # initialise
                n[, 1] <- initial_depletion * k * exp(e[j, 1]) 
                
                # project
                for (y in 2:ntime) {
                    
                    proj_h[j, y - 1] <- object@harvest_rate(object, i)
                    
                    for (a in 2:nages) {
                        
                        n[a, y] <- (n[a - 1, y - 1] * exp(-1 * M[a - 1]) * (1 - sel[a - 1] * proj_h[j, y - 1])) * exp(e[j, y])  
                    }
                    
                    # plus group
                    n[nages, y] <- n[nages, y] + (n[nages, y - 1] * exp(-1 * M[nages]) * (1 - sel[nages] * proj_h[j, y - 1])) * exp(e[j, y]) 
                    
                    # birth
                    n[1, y] <- birth(y)
                }
                
                # values per-year
                proj_catch[j,]     <- apply(sweep(n, 1, sel, "*"), 2, sum) * proj_h[j,]
                proj_depletion[j,] <- apply(n[-1,], 2, sum) / sum(k[-1])
                proj_n[j,,]        <- n
                
                # spin spinner
                cli_progress_update()
            }
            
            # update targets
            # (catch)
            object@diagnostics$catch[i,] <- apply(proj_catch, 2, mean)
            # (depletion)
            object@diagnostics$depletion[i,] <- apply(proj_depletion, 2, mean)
            # (harvest rate)
            object@diagnostics$harvest_rate[i,] <- apply(proj_h, 2, mean)
            
            # numbers
            N[i,,] <- apply(proj_n, 2:3, mean)
            
            # pst
            object@pst$value[i,] <- (1 / 2) * object@pst$phi * object@pst$rmax[i] * apply(sweep(N[i,,], 1, mat, "*"), 2, sum)
            
            # spin spinner
            cli_progress_update()
        }
    }

    # calculate objectives as the probability
    # of a desirable outcome
    p_higher <- function(x, y) ifelse(x > y, 1, ifelse(x < y, 0, 0.5))
    p_lower  <- function(x, y) ifelse(x < y, 1, ifelse(x > y, 0, 0.5))
    # (prob. that catch is less than that required to meet MNPL)
    object@objectives$catch        <- apply(sweep(object@diagnostics$catch,        1, object@targets$catch, p_lower),        1, mean, na.rm = TRUE)
    # (prob. that depletion is greater than the depletion at MNPL)
    object@objectives$depletion    <- apply(sweep(object@diagnostics$depletion,    1, object@targets$depletion, p_higher),   1, mean, na.rm = TRUE)
    # (prob. that harvest rate is less than that required to meet MNPL)
    object@objectives$harvest_rate <- apply(sweep(object@diagnostics$harvest_rate, 1, object@targets$harvest_rate, p_lower), 1, mean, na.rm = TRUE)
    
    # dimnames (after calculations)
    dimnames(N) <- list(iter = 1:niter, age = ages, time = time)
    
    # assign data
    object@.Data <- N
    
    # return
    return(object)
})
#}}}
