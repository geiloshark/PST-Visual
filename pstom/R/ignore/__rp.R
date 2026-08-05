#' @title Reference point calculation
#' @description 
#' Calculate the stochastic Maximum Net Productivity reference points.
#' 
#' @export
#' @include om-class.R distribution-class.R distribution.R sample.distribution.R
#' @import RTMB
#' @import cli
#' @importFrom glue glue
#{{{ rp()
# wrapper for execution of function
setGeneric("rp", function(object, ...) standardGeneric("rp"))
setMethod("rp", signature = "om", function(object, ...) {
    
    # current environment
    ENV <- environment()
    
    # check environment for function call is
    # consistent with current environment
    #environment(object@population_dynamics) <- environment()
    
    # load time, age and
    # iteration dimensions
    # into function environment
    get_dim(object, env = ENV)
    
    # load data inputs stored
    # in object@data
    get_data(object, env = ENV)
    
    # reset targets
    # (catch)
    object@targets$catch <- c()
    # (depletion)
    object@targets$depletion <- c()
    # (harvest rate)
    object@targets$harvest_rate <- c()
    
    # log-normal process error term
    sigmap <- sqrt(log(1 + cv_dynamics^2))
    
    # initial values
    # (process error)
    perr <- matrix(rnorm(equ_time * equ_iter, 0 - (sigmap^2) / 2, sigmap), nrow = equ_iter, ncol = equ_time)
    # (parameter values - check order)
    pars <- unlist(lapply(object@pars, sample, n = 1))
    
    # accessor functions
    get_K    <- function() exp(get("pars", envir = ENV)[1])
    get_r    <- function() exp(get("pars", envir = ENV)[2])
    get_perr <- function() get("perr", envir = ENV)
    
    # PT model
    # {{{
    if (all(is.na(object@ages)) | !(length(object@ages) > 1)) {
        
        # AD objective function
        obj_fun <- function(x) { 
            
            # parameter 
            # value
            h <- exp(x)
    
            # monte-carlo
            # inputs
            r <- DataEval(get_r)
            K <- DataEval(get_K)
            e <- DataEval(get_perr)
            
            # AD matrix
            b <- AD(matrix(nrow = equ_iter, ncol = equ_time))
            
            # stochastic 
            # dynamics
            for (i in 1:equ_iter) {
                b[i, 1] <- (K * (1 / (shape + 1))^(1 / shape)) * exp(e[i, 1])
                for (j in 2:equ_time) {
                    b[i, j] <- (b[i, j - 1] + r / shape * b[i, j - 1] * (1 - (b[i, j - 1] / K)^shape) - h * b[i, j - 1]) * exp(e[i, j])  
                }
            }
            
            # mean equilibrium catch
            # over most recent 10%
            # of the projection period
            recent_time <- ceiling(0.9 * equ_time):equ_time
            catch <- mean(b[, recent_time] * h)
            
            # return catch with penalty if
            # harvest rate is greater than 
            # deterministic rate
            return(-1 * catch + max(x - log(r / (shape + 1)), 0))
        }
        
        # progress message
        cli_progress_message("Compiling model...")
        
        # initialise with 
        # parameter value
        g <- MakeTape(obj_fun, object@pars$log_r@pars[1] - log(object@data$shape + 1))
        # function to 
        # estimate minimum
        # over first argument
        # (harvest rate)
        ff <- g$newton(1)
    
        # progress message
        msg <- ""
        cli_progress_step("Estimating the harvest rate at MNPL{msg}", spinner = TRUE, msg_done = "Estimated MNPL reference points")
    
        # loop over monte-carlo
        # samples
        for (i in 1:niter) {
            
            # set seed
            set.seed(rng_seed[i])
            
            # progress iteration
            msg <- glue(", iteration {i}/", niter)
            
            # spin spinner
            cli_progress_update()
            
            # sample
            perr <- matrix(rnorm(equ_time * equ_iter, 0 - (sigmap^2) / 2, sigmap), nrow = equ_iter, ncol = equ_time)
            pars <- unlist(lapply(object@pars, sample, n = 1))
    
            # estimate stochastic h_mnpl
            # per monte-carlo sample
            h_mnpl <- exp(ff(numeric()))
            
            # spin spinner
            cli_progress_update()
            
            # project under harvest rate
            # at MNPL
            # {{{
            b <- matrix(nrow = equ_iter, ncol = equ_time)
            K <- exp(pars[1])
            r <- exp(pars[2])
            
            # dynamics
            for (j in 1:equ_iter) {
                
                b[j, 1] <- (K * (1 / (shape + 1))^(1 / shape)) * exp(perr[j, 1])
                
                for (k in 2:equ_time) {
                    b[j, k] <- (b[j, k - 1] + r / shape * b[j, k - 1] * (1 - (b[j, k - 1] / K)^shape) - h_mnpl * b[j, k - 1]) * exp(perr[j, k])  
                }
            }
            #}}}
            
            # spin spinner
            cli_progress_update()
            
            # update targets
            recent_time <- ceiling(0.9 * equ_time):equ_time
            # (catch)
            object@targets$catch <- c(object@targets$catch, mean(b[, recent_time] * h_mnpl))
            # (depletion)
            object@targets$depletion <- c(object@targets$depletion, mean(b[, recent_time] / K)) 
            # (harvest rate)
            object@targets$harvest_rate <- c(object@targets$harvest_rate, h_mnpl)
            
            # spin spinner
            cli_progress_update()
        }
    # }}}
    } else {
    # AGE-STRUCTURED MODEL    
    # {{{
        
        # vectors from age = 0 to age = nages - 1
        mat    <- c(rep(0, age_mat + 1), rep(1, nages - age_mat - 1))
        pat    <- c(rep(0, age_pat + 1), rep(1, nages - age_pat - 1))
        sel    <- c(rep(0, age_sel + 1), rep(1, nages - age_sel - 1))
        S      <- c(S0, rep(S1, nages - 1))
        M      <- -log(S)
        
        # objective function
        obj_fun <- function(x) {
            
            h <- exp(x)

            b_eq  <- AD(numeric(1))
            b_max <- AD(numeric(1))
            
            n <- AD(array(dim = c(nages, equ_time)))
            p <- AD(vector("numeric", length = nages))
            
            birth <- function(y) {
                0.5 * sum(pat[-1] * n[-1,y]) * (b_eq + (b_max - b_eq) * (1 - (sum(n[-1,y]) / sum(k[-1]))^shape)) 
            }
            
            # monte-carlo
            # inputs
            r <- DataEval(get_r)
            K <- DataEval(get_K)
            e <- DataEval(get_perr)
            
            # productivity for estimation
            # of b_max
            lambda <- exp(r)
            
            # set up unexploited 
            # equilibrium female
            # population
            p[1] <- 0.5
            for(a in 2:nages) {
                p[a] <- p[a-1] * exp(-M[a - 1])
            }
            p[nages] <- p[nages] / (1 - exp(-M[nages]))
            
            # replacement birth rate
            # per female
            b_eq[]  <- 1 / sum(pat * p)
            
            # maximum birth rate
            # per female
            b_max[] <- 2 * (lambda^(age_pat) - S1 * lambda^(age_pat - 1)) / (S0 * S1^(age_pat - 1))
            
            # initilise population
            # at equilibrium
            n_init <- b_eq * p
            
            # carrying capacity
            # (1+ depletion = 1)
            k <- K * n_init / sum(n_init[-1])
            
            objective <- 0
            
            recent_time <- ceiling(0.9 * equ_time):equ_time
            
            # loop over process
            # error
            for (i in 1:equ_iter) {
                
                # initialise
                # at K / 2
                n[, 1] <- 0.5 * k * exp(e[i, 1]) 
                
                # project
                for (y in 2:equ_time) {
                    
                    for (a in 2:nages) {
                        
                        n[a, y] <- (n[a - 1, y - 1] * exp(-1 * M[a - 1]) * (1 - sel[a - 1] * h)) * exp(e[i, y]) 
                    }
                    
                    # plus group
                    n[nages, y] <- n[nages, y] + (n[nages, y - 1] * exp(-1 * M[nages]) * (1 - sel[nages] * h)) * exp(e[i, y]) 
                    
                    # birth
                    n[1, y] <- birth(y)
                }
                
                # log of the equilibrium catch
                objective <- objective - log(sum(sweep(n[, recent_time], 1, sel, "*") * h) / length(recent_time))
            }
            
            # return
            return(objective)
        }
        
        # progress message
        cli_progress_message("Compiling model...")
        
        # initialise with 
        # parameter value
        g <- MakeTape(obj_fun, object@pars$log_r@pars[1] - log(object@data$shape + 1))
        # function to 
        # estimate minimum
        # over first argument
        # (harvest rate)
        ff <- g$newton(1)
        
        # progress message
        msg <- ""
        cli_progress_step("Estimating the harvest rate at MNPL{msg}", spinner = TRUE, msg_done = "Estimated MNPL reference points")
        
        # set-up arrays
        n <- array(dim = c(nages, equ_time))
        p <- vector("numeric", length = nages)
        
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
            perr <- matrix(rnorm(equ_time * equ_iter, 0 - (sigmap^2) / 2, sigmap), nrow = equ_iter, ncol = equ_time)
            pars <- unlist(lapply(object@pars, sample, n = 1))
            
            # estimate stochastic h_mnpl
            # per monte-carlo sample
            h_mnpl <- exp(ff(numeric()))
            
            # spin spinner
            cli_progress_update()
            
            # project under harvest rate
            # at MNPL
            # {{{
            
            # monte-carlo
            # inputs
            K <- exp(pars[1])
            r <- exp(pars[2])
            e <- perr
            
            # productivity for estimation
            # of b_max
            lambda <- exp(r)
            
            # birth rates
            # per female
            b_eq  <- 1 / sum(pat * p)
            b_max <- 2 * (lambda^(age_pat) - S1 * lambda^(age_pat - 1)) / (S0 * S1^(age_pat - 1))
            
            # initilise population
            # at equilibrium
            n_init <- b_eq * p
            
            # carrying capacity
            # (1+ depletion = 1)
            k <- K * n_init / sum(n_init[-1])
            
            recent_time <- ceiling(0.9 * equ_time):equ_time
            
            equ_catch     <- numeric(equ_iter)
            equ_depletion <- numeric(equ_iter)
            
            # loop over process
            # error iterations
            for (i in 1:equ_iter) {
                
                # initialise
                # at K / 2
                n[, 1] <- 0.5 * k * exp(e[i, 1]) 
                
                # project
                for (y in 2:equ_time) {
                    
                    for (a in 2:nages) {
                        
                        n[a, y] <- (n[a - 1, y - 1] * exp(-1 * M[a - 1]) * (1 - sel[a - 1] * h_mnpl)) * exp(e[i, y])  
                    }
                    
                    # plus group
                    n[nages, y] <- n[nages, y] + (n[nages, y - 1] * exp(-1 * M[nages]) * (1 - sel[nages] * h_mnpl)) * exp(e[i, y]) 
                    
                    # birth
                    n[1, y] <- birth(y)
                }
                
                # equilibrium values
                equ_catch[i]     <- sum(sweep(n[, recent_time], 1, sel, "*") * h_mnpl) / length(recent_time)
                equ_depletion[i] <- mean(apply(n[-1, recent_time], 2, sum) / sum(k[-1]))
                
                # spin spinner
                cli_progress_update()
            }
            
            # update targets
            # (catch)
            object@targets$catch <- c(object@targets$catch, mean(equ_catch))
            # (depletion)
            object@targets$depletion <- c(object@targets$depletion, mean(equ_depletion)) 
            # (harvest rate)
            object@targets$harvest_rate <- c(object@targets$harvest_rate, h_mnpl)
            
            # spin spinner
            cli_progress_update()
        }
    # }}}
    }
    
    # return
    return(object)
})
#}}}
