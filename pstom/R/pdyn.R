#' @title Population dynamics function
#' @description Project the population dynamics foward in time.
#' @param object an \code{om} class object
#' @param stochastic logical value
#' @param iterations number of stochastic iterations
#' @param time number of time steps (can be used to override value stored in object)
#' @param initial_depletion starting depletion (must be >0 and <= 1)
#' @param verbose logical value
#' @param use_rmax logical value
#' @details Reference points are always estimated using \eqn{r_{max}}, meaning that projections that use \eqn{r_{max}} have better behavioural properties when examined relative to reference point values. This is because the \eqn{\theta} shape parameter has been estimated per sample and will therefore be correctly correlated with the samples from the distribution of \eqn{r_{max}} values. However, it is also possible to project the dynamics using \eqn{r}, which is provided as a separate and independent distribution to the dynamics equation. This is helpful for robustness testing when it may be assumed that the population is currently not in it's optimal state, meaning that \eqn{r < r_{max}}. Note however, that the PST is always calculated using \eqn{r_{max}}, and if \eqn{r} is used for the population dynamics, then the this will decouple the assumed \eqn{r_{max}} from the true \eqn{r} value.   
#' @export
#' @include om-class.R get_dim.R dot-survivorship.R
#' @import RTMB
#' @importFrom cli cli_progress_step cli_progress_update cli_alert_warning
#' @importFrom logitnorm rlogitnorm
#' @importFrom stats rlnorm rnorm
#' @importFrom glue glue
#{{{ pdyn()
setGeneric("pdyn", function(object, ...) standardGeneric("pdyn"))
setMethod("pdyn", signature = "om", function(object, stochastic, iterations, time, initial_depletion = 1.0, verbose = FALSE, use_rmax = TRUE, ...) {
    
    # current environment
    ENV <- environment()
    
    # make sure harvest rate
    # function has correct
    # environment
    environment(object@harvest_rate) <- ENV
    
    # check and update object with
    # function arguments
    object <- .check_pdyn(object, stochastic, time, iterations, verbose, use_rmax)
    
    # load time, age and
    # iteration dimensions
    # into function environment
    get_dim(object, projection = TRUE, env = ENV)
    
    # get seeds
    get_seeds(object, env = ENV)
    
    # get shape
    get_shape(object, env = ENV)
    
    # check pars
    for (a in names(object@pars)) {
        if (isTRUE(is.na(object@pars[[a]]))) {
            stop("'", a, "' is missing from 'object@pars'")
        }
    }
    
    # setup numbers array
    # [life-history samples, process-error samples, ages, time]
    if (all(is.na(ages))) {
        N <- array(dim = c(NITER, SITER, 1, NTIME))
    } else {
        N <- array(dim = c(NITER, SITER, NAGES, NTIME))
    }
    
    # setup diagnostics
    # (catch)
    object@diagnostics$captures <- array(dim = c(NITER, SITER, NTIME - 1))
    # (depletion)
    object@diagnostics$depletion <- array(dim = c(NITER, SITER, NTIME)) 
    # (harvest rate)
    object@diagnostics$harvest_rate <- array(dim = c(NITER, SITER, NTIME - 1))
    
    # pst
    object@pst$value <- array(dim = c(NITER, SITER, NTIME))
	
	# setup values to 
    # store pars iterations
	object@values$rmax  <- rep(NA_real_, NITER)
    object@values$r     <- rep(NA_real_, NITER)
	object@values$shape <- rep(NA_real_, NITER)
    object@values$s     <- rep(NA_real_, NITER)
	object@values$l     <- rep(NA_real_, NITER)
    object@values$b     <- rep(NA_real_, NITER)
	object@values$beq   <- rep(NA_real_, NITER)
	object@values$bstar <- rep(NA_real_, NITER)
    object@values$m     <- rep(NA_real_, NITER)
    object@values$o     <- rep(NA_real_, NITER)
    object@values$v     <- rep(NA_real_, NITER)
    object@values$K     <- rep(NA_real_, NITER)
        
    # define log-normal numbers observation error function
    # using: cv, quantile (qn) and/or bias
    if (STOCHASTIC & object@settings$cv$numbers > 0) {
        if (object@settings$qn$numbers[1] > 0) {
            if (is.na(object@settings$qn$numbers[2])) {
                object@settings$qn$numbers[2] <- object@settings$cv$numbers
            }
            if (object@settings$bias$numbers != 1.0) {
                .obs_error <- function(a, cv = object@settings$cv$numbers, qn = object@settings$qn$numbers, bias = object@settings$bias$numbers) {
                    bias * exp(log(a / sqrt(1 + cv^2)) + rnorm(1) * sqrt(log(1 + cv^2))) / exp(abs(qnorm(qn[1])) * sqrt(log(1 + (qn[2])^2)))
                }
            } else {
                .obs_error <- function(a, cv = object@settings$cv$numbers, qn = object@settings$qn$numbers) {
                    exp(log(a / sqrt(1 + cv^2)) + rnorm(1) * sqrt(log(1 + cv^2))) / exp(abs(qnorm(qn[1])) * sqrt(log(1 + (qn[2])^2)))
                }
            }
        } else {
            if (object@settings$bias$numbers != 1.0) {
                .obs_error <- function(a, cv = object@settings$cv$numbers, bias = object@settings$bias$numbers) {
                    bias * exp(log(a / sqrt(1 + cv^2)) + rnorm(1) * sqrt(log(1 + cv^2)))
                }
            } else {
                .obs_error <- function(a, cv = object@settings$cv$numbers) {
                    exp(log(a / sqrt(1 + cv^2)) + rnorm(1) * sqrt(log(1 + cv^2)))
                }
            }
        }
    } else {
        if (object@settings$bias$numbers != 1.0) {
            .obs_error <- function(a, bias = object@settings$bias$numbers) {
                bias * a
            }
        } else {
            .obs_error <- function(a) {
                a
            }
        }
    }
    
    # define logit-normal harvest rate
    # error function
    if (STOCHASTIC & object@settings$cv$harvest_rate > 0) {
        if (object@settings$cv$harvest_rate > 0.3) {
            cli_alert_warning("Recommend reducing CV[harvest rate] to less than 0.3")
        }
        if (object@settings$bias$harvest_rate != 1.0) {
            .harvest_error <- function(a, cv = object@settings$cv$harvest_rate, bias = object@settings$bias$harvest_rate) {
                bias * rlogitnorm(1, mu = a, sigma = cv * a)
            }
        } else {
            .harvest_error <- function(a, cv = object@settings$cv$harvest_rate) {
                rlogitnorm(1, mu = a, sigma = cv * a)
            }
        }
    } else {
        if (object@settings$bias$harvest_rate != 1.0) {
            .harvest_error <- function(a, bias = object@settings$bias$harvest_rate) {
                bias * a
            }
        } else {
            .harvest_error <- function(a) {
                a
            }
        }
    }
    
    # define log-normal capture
    # error function
    if (STOCHASTIC & object@settings$cv$capture > 0) {
        if (object@settings$bias$capture != 1.0) {
            .capture_error <- function(a, cv = object@settings$cv$capture, bias = object@settings$bias$capture) {
                bias * exp(log(a / sqrt(1 + cv^2)) + rnorm(1) * sqrt(log(1 + cv^2)))
            }
        } else {
            .capture_error <- function(a, cv = object@settings$cv$capture) {
                exp(log(a / sqrt(1 + cv^2)) + rnorm(1) * sqrt(log(1 + cv^2)))
            }
        }
    } else {
        if (object@settings$bias$capture != 1.0) {
            .capture_error <- function(a, bias = object@settings$bias$capture) {
                bias * a
            }
        } else {
            .capture_error <- function(a) {
                a
            }
        }
    }
    
    # define zt-normal rmax
    # error function
    if (STOCHASTIC & object@settings$cv$rmax > 0) {
        if (object@settings$bias$rmax != 1.0) {
            .rmax_error <- function(a, cv = object@settings$cv$rmax, bias = object@settings$bias$rmax) {
                bias * (a + (cv * a) * qnorm(runif(1, pnorm((0 - a) / (cv * a)), pnorm(Inf))))
            }
        } else {
            .rmax_error <- function(a, cv = object@settings$cv$rmax) {
                a + (cv * a) * qnorm(runif(1, pnorm((0 - a) / (cv * a)), pnorm(Inf)))
            }
        }
    } else {
        if (object@settings$bias$rmax != 1.0) {
            .rmax_error <- function(a, bias = object@settings$bias$rmax) {
                bias * a
            }
        } else {
            .rmax_error <- function(a) {
                a
            }
        }
    }
    
    if (verbose) {
        message("harvest rate function:")
        message(writeLines(deparse(object@harvest_rate)))
        message("harvest rate error function:")
        message(writeLines(deparse(.harvest_error)))
        message("capture error function:")
        message(writeLines(deparse(.capture_error)))
        message("numbers observation error function:")
        message(writeLines(deparse(.obs_error)))
        message("rmax error function:")
        message(writeLines(deparse(.rmax_error)))
    }
    
    # progress
    msg <- ""
    cli_progress_step("Projecting dynamics{msg}", spinner = TRUE, msg_done = "Projected dynamics")

    # {{{
    # PT model
    if (all(is.na(object@ages)) | !(length(object@ages) > 1)) {
        
    } else {
    # {{{
    # AGE-STRUCTURED MODEL
        
        # objective function for
        # estimation of h at
        # initial depletion
        obj_fun <- function(x, shape, target) {
            
            h <- 1 / (1 + exp(-x[1]))
            n <- matrix(k, nrow = NAGES, ncol = 2)
            
            # equilibrium age
            # structure
            for (l in 2:1e3) {
                
                n[, 1] <- n[, 2]
                for(a in 2:NAGES) {
                    n[a, 2] <- n[a - 1, 1] * S[a - 1] * (1 - sel[a - 1] * h)
                }
                n[a, 2] <- n[a, 2] + n[a, 1] * S[a] * (1 -  sel[a] * h)
                n[1, 2] <- 0.5 * sum(pat[-1] * n[-1, 2]) * (b_eq + (b_max - b_eq) * (1 - (sum(n[-1, 2]))^shape))
            }
                
            # log of the equilibrium depletion
            objective <- -1 * dnorm(sum(n[-1, 2]), target, 0.01, log = TRUE)
            
            # return
            return(objective)
        }
        
        # set-up arrays
        n   <- array(dim = c(NAGES, NTIME))
        p   <- vector("numeric", length = NAGES)
        pst <- vector("numeric", length = NTIME)
        h   <- vector("numeric", length = NTIME - 1)
        
        proj_n         <- array(dim = c(SITER, NAGES, NTIME))
        proj_h         <- array(dim = c(SITER, NTIME - 1))
        proj_catch     <- array(dim = c(SITER, NTIME - 1))
        proj_depletion <- array(dim = c(SITER, NTIME))
        proj_pst       <- array(dim = c(SITER, NTIME))
        
        # set-up birth function
        birth <- function(y) {
			0.5 * sum(pat[-1] * n[-1,y]) * (b_eq + (b_max - b_eq) * (1 - (sum(n[-1,y]) / sum(k[-1]))^shape[i]))			
        }
        
        # pst observation function
        pst_calc <- function(numbers, observation) {
            (1 / 2) * object@pst$phi * .rmax_error(rmax_sample) * .obs_error(sum(numbers * observation))
        }
        
        # harvest rate calculation
        # from captures
        hr_calc <- function(capture, numbers, selectivity) {
            ifelse(sum(numbers * selectivity) > 0, min(sum(numbers * selectivity), .capture_error(capture) / sum(numbers * selectivity)), NA_real_)
        }
    
        #######################
        # monte-carlo samples #
        # from life-history   #
        # distributions       #
        #######################
        for (i in 1:NITER) {
            
            # set seed
            set.seed(rng_seed[i])
            
            # progress iteration
            msg <- ifelse(NITER > 1, glue(", sample {i}/", NITER), " ...")
            
            # sample
            pars_sample <- lapply(object@pars, sample, n = 1)
            rmax_sample <- pars_sample$rmax
                
            # spin spinner
            cli_progress_update()
            
            # assign pars
            m <- pars_sample$m
            r <- ifelse(use_rmax, pars_sample$rmax, pars_sample$r)
            s <- pars_sample$s
            l <- pars_sample$l
            v <- pars_sample$v
            o <- pars_sample$o
            K <- pars_sample$K
            b <- pars_sample$b
            
            #lambda_i <- .solve_lambda(m = m, s = S, s0 = S * l, b = b)
            #print(paste("r:",    round(pars_sample$r, 5)))
            #print(paste("rmax:", round(pars_sample$rmax, 5)))
            #print(paste("rest:", round(log(.solve_lambda(m, s, s * l, b)), 5)))
            
            # transcribe
            #S <- c(rep(s * l, m), rep(s, NAGES - m))
            S <- c(s * l, rep(s, NAGES - 1))
            
            age_mat <- as.integer(m)
            age_pat <- age_mat + 1L
            age_sel <- as.integer(v)
            age_obs <- as.integer(o)
        
            mat <- c(rep(0, age_mat), rep(1, NAGES - age_mat))
            pat <- c(rep(0, age_pat), rep(1, NAGES - age_pat))
            sel <- c(rep(0, age_sel), rep(1, NAGES - age_sel))
            obs <- c(rep(0, age_obs), rep(1, NAGES - age_obs))
            
            lambda <- exp(r)
            
            # set up unexploited 
            # equilibrium female
            # population
            p[1] <- 0.5
            for(a in 2:NAGES) {
                p[a] <- p[a - 1] * S[a - 1]
            }
            p[a] <- p[a] / (1 - S[a])
            
            # replacement birth rate
            # per female
            b_eq  <- 1 / sum(pat * p)
            
            # maximum birth rate
            # per female
            b_max <- 2 * (lambda^(age_mat + 1) - S[age_mat + 1] * lambda^(age_mat)) / prod(S[1:(age_mat + 1)])
            
            # check and reject
            if (b_max < b_eq) {
                warning("'b_max < b_eq' for 'sample = ", i, "'")    
                next
            }
            
            # initialise population
            # at equilibrium
            k_prime <- b_eq * p
            
            # initial conditions
            # (sum(k1+) = 1)
            k <- k_prime / sum(k_prime[-1])
            
            # initial conditions
            if (initial_depletion < 1) {
                
                # get initial value
                x <- seq(-10, 0, length = 101)
                y <- unlist(lapply(x, obj_fun, shape = shape[i], target = initial_depletion))
                z <- x[which.min(y)]
                
                # minimise
                h_init <- .ilogit(optimise(obj_fun, interval = c(z - 1, z + 1), shape = shape[i], target = initial_depletion)$minimum)
                
                n_init <- matrix(k, nrow = NAGES, ncol = 2)
                for (l in 2:1e3) {
                    
                    n_init[, 1] <- n_init[, 2]
                    for(a in 2:NAGES) {
                        n_init[a, 2] <- n_init[a - 1, 1] * S[a - 1] * (1 - sel[a - 1] * h_init)
                    }
                    n_init[a, 2] <- n_init[a, 2] + n_init[a, 1] * S[a] * (1 -  sel[a] * h_init)
                    n_init[1, 2] <- 0.5 * sum(pat[-1] * n_init[-1, 2]) * (b_eq + (b_max - b_eq) * (1 - (sum(n_init[-1, 2]))^shape[i]))
                }
                
            } else {
                
                n_init <- matrix(k, nrow = NAGES, ncol = 2)
                for (l in 2:1e3) {
                    
                    n_init[, 1] <- n_init[, 2]
                    for(a in 2:NAGES) {
                        n_init[a, 2] <- n_init[a - 1, 1] * S[a - 1]
                    }
                    n_init[a, 2] <- n_init[a, 2] + n_init[a, 1] * S[a]
                    n_init[1, 2] <- 0.5 * sum(pat[-1] * n_init[-1, 2]) * (b_eq + (b_max - b_eq) * (1 - (min(1, sum(n_init[-1, 2])))^shape[i]))
                }
            }
            
            # check and reject
            if (round(sum(n_init[-1, 2]), 1) != initial_depletion) {
                warning("failed to estimate initial depletion for 'sample = ", i, "'")    
                next
            }
            
            # construct survivorship
            # array
            if (STOCHASTIC) {
                survivorship <- .survivorship(pars_sample$s, object@settings$cv$survivorship, env = ENV)
                epsilon      <- .epsilon(object@settings$cv$birth, env = ENV)
            } else {
                survivorship <- .survivorship(pars_sample$s, env = ENV)
                epsilon      <- .epsilon(env = ENV)
            }
            
            # (sum(k1+) = K)
            k <- k * K
            
            # loop over stochastic
            # process error
            for (j in 1:SITER) {
                
                # initialise
                n[, 1] <- n_init[,2] * K
                
                # survivorship matrix
                s <- matrix(survivorship[j,], ncol = NTIME, nrow = NAGES, byrow = TRUE)
                #s <- (sweep(s, 1, 1 - mat, "*") * pars_sample$l) + sweep(s, 1, mat, "*")
                s[1,] <- s[1,] * pars_sample$l
                
                # birth rate deviation
                e <- epsilon[j,]
                
                # apply
                n[, 1] <- n[, 1] * e[1]
                
                # observe initial pst
                pst[1] <- pst_calc(n[, 1], obs)
                    
                # project under harvest rate
                # function
                # {{{
                for (y in 2:NTIME) {
                    
                    # calculate harvest rate
                    h[y - 1] <- object@harvest_rate(numbers = n[, y - 1], selectivity = sel, pst = pst[y - 1], i)
                    
                    # apply harvest rate
                    # and mortality
                    for (a in 2:NAGES) {
                        n[a, y] <- n[a - 1, y - 1] * s[a - 1, y - 1] * (1 - sel[a - 1] * h[y - 1]) 
                    }
                    
                    # plus group
                    n[a, y] <- n[a, y] + n[a, y - 1] * s[a, y - 1] * (1 - sel[a] * h[y - 1])
                    
                    # birth
                    n[1, y] <- birth(y) * e[y]
                    
                    # observe pst
                    pst[y] <- pst_calc(n[, y], obs)
                }
                
                # values per-year
                proj_h[j,]         <- h
                proj_catch[j,]     <- apply(sweep(n, 1, sel, "*"), 2, sum)[-NTIME] * h
                proj_depletion[j,] <- apply(n[-1,], 2, sum) / sum(k[-1])
                proj_n[j,,]        <- n
                proj_pst[j,]       <- pst
                
                # spin spinner
                cli_progress_update()
            }
            
            # update time series diagnostics
            # (catch)
            object@diagnostics$captures[i,,]     <- proj_catch
            # (depletion)
            object@diagnostics$depletion[i,,]    <- proj_depletion
            # (harvest rate)
            object@diagnostics$harvest_rate[i,,] <- proj_h
            
            # numbers
            N[i,,,] <- proj_n
            
            # pst
            object@pst$rmax[i]    <- rmax_sample
            object@pst$value[i,,] <- proj_pst
            
            # spin spinner
            cli_progress_update()
            
            # record values
            object@values$rmax[i]  <- pars_sample$rmax
			object@values$r[i]     <- pars_sample$r
			object@values$shape[i] <- shape[i]
            object@values$s[i]     <- pars_sample$s
            object@values$l[i]     <- pars_sample$l
			object@values$b[i]     <- pars_sample$b
            object@values$beq[i]   <- b_eq
			object@values$bstar[i] <- b_max
            object@values$m[i]     <- pars_sample$m
            object@values$o[i]     <- pars_sample$o
            object@values$v[i]     <- pars_sample$v
            object@values$K[i]     <- pars_sample$K
        }
    }

    # calculate objectives as the probability
    # of a desirable outcome
    p_higher <- function(x, y) ifelse(x > y, 1, ifelse(x < y, 0, 0.5))
    p_lower  <- function(x, y) ifelse(x < y, 1, ifelse(x > y, 0, 0.5))
    
    # (prob. that catch is less than that required to meet MNPL)
    object@objectives$captures     <- array(dim = c(NITER, NTIME - 1))
    # (prob. that depletion is greater than the depletion at MNPL)
    object@objectives$depletion    <- array(dim = c(NITER, NTIME))
    # (prob. that harvest rate is less than that required to meet MNPL)
    object@objectives$harvest_rate <- array(dim = c(NITER, NTIME - 1))
    
    for (i in 1:NITER) {
        
        object@objectives$captures[i,]     <- apply(sweep(matrix(object@diagnostics$captures[i,,], nrow = SITER),     1, object@targets$captures[i], p_lower),     2, mean, na.rm = TRUE)
        object@objectives$depletion[i,]    <- apply(sweep(matrix(object@diagnostics$depletion[i,,], nrow = SITER),    1, object@targets$depletion[i], p_higher),   2, mean, na.rm = TRUE)
        object@objectives$harvest_rate[i,] <- apply(sweep(matrix(object@diagnostics$harvest_rate[i,,], nrow = SITER), 1, object@targets$harvest_rate[i], p_lower), 2, mean, na.rm = TRUE)
    }
    
    # assign numbers (sum of 1+ age classes)
    # [life-history samples, process error iterations, time]
    object@.Data <- apply(N[,,-1,, drop = FALSE], c(1,2,4), sum)
    
    # return
    return(object)
})
#}}}
