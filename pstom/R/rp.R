#' @title Stochastic reference point calculation
#' @description 
#' Calculate the Maximum Net Productivity reference points.
#' @param object \code{om} class object
#' @param stochastic logical value indicating whether stochastic production function should be calculated (defaults to value in \code{settings$ref_points})
#' @param time equilibrium time horizon over which values are calculated (defaults to value in \code{settings$ref_points})
#' @param iterations numeric value indicating number of iterations for when \code{stochastic = TRUE} (defaults to value in \code{settings$ref_points})
#' @param verbose logical value indicating whether values \code{stochastic}, \code{time} or \code{iterations} should be printed
#' @note This function would typically be preceded by a call to [shape()], which estimates the shape parameter necessary for definition of the production function. 
#' @seealso \code{\link{shape}} \code{\link{targets}}
#' @export
#' @include om-class.R distribution-class.R distribution.R sample.distribution.R dot-pdyn.R dot-check.R dot-logit.R dot-survivorship.R
#' @import RTMB
#' @importFrom cli cli_progress_step cli_progress_update
#{{{ rp()
# wrapper for execution of function
setGeneric("rp", function(object, ...) standardGeneric("rp"))
setMethod("rp", signature = "om", function(object, stochastic, time, iterations, verbose = FALSE, ...) {
    
    # current environment
    ENV <- environment()
    
    # check and update object with
    # function arguments
    object <- .check_rp(object, stochastic, time, iterations, verbose)
    
    # load time, age and
    # iteration dimensions
    # into function environment
    get_dim(object, ref_points = TRUE, env = ENV)
    
    # get seeds
    get_seeds(object, env = ENV)
    
    # check pars
    for (a in c("m", "s", "l", "b", "v")) {
        if (isTRUE(is.na(object@pars[[a]]))) {
            stop("'", a, "' is missing from 'object@pars'")
        }
    }
    
    # reset targets
    # (catch)
    object@targets$captures <- rep(NA_real_, NITER)
    # (depletion)
    object@targets$depletion <- rep(NA_real_, NITER)
    # (harvest rate)
    if (all(is.na(object@targets$harvest_rate))) {
        # no previous estimation
        # of h_mnpl
        # -> estimate h_mnpl and
        # ref. points for all 
        # samples
        ESTIMATE_HMNPL <- TRUE
        object@targets$harvest_rate <- rep(NA_real_, NITER)
    } else {
        # previous estimation of
        # h_mnpl with possibility 
        # of failure
        # -> estimate ref. points
        # for samples with valid
        # h_mnpl estimate
    	ESTIMATE_HMNPL <- FALSE		
    }
    
    # PT model
    # {{{
    if (all(is.na(object@ages)) | !(length(object@ages) > 1)) {
        
    # }}}
    } else {
    # AGE-STRUCTURED MODEL    
    # {{{
        
        # specify projection function
        fast_forward <- if (STOCHASTIC) .ff2 else .ff
        
		# function to extract real values
		# from advector-type
		# (https://github.com/kaskr/RTMB/blob/master/RTMB/R/RcppExports.R)
		getValues <- function(x) {
			.Call("_RTMB_getValues", x, PACKAGE = "RTMB")
		}

		# accessor functions
        get_m <- function() get("m", envir = ENV)
        get_r <- function() get("r", envir = ENV)
        get_s <- function() get("s", envir = ENV)
		get_l <- function() get("l", envir = ENV)
		get_e <- function() get("e", envir = ENV)
		get_v <- function() get("v", envir = ENV)
		get_b <- function() get("b", envir = ENV)
		
        # set up objective
        # function to estimate
        # harvest rate at 
        # maximum sustainable 
        # catch
        # (deterministic)
        obj1 <- function(x) {
            
            h     <- 1 / (1 + exp(-x[1]))
            shape <- exp(x[2])
            
            # get pars
            m <- DataEval(get_m)
            r <- DataEval(get_r)
            s <- DataEval(get_s)
			l <- DataEval(get_l)
			e <- DataEval(get_e)
			v <- DataEval(get_v)
			b <- DataEval(get_b)
		
			# get selectivity
			m <- as.integer(getValues(m))
			v <- as.integer(getValues(v))
            
            # deterministic dynamics
            n <- do.call(".pdyn", list(h = h, shape = shape, survivorship = s[1,], multiplier = l, fecundity = b, epsilon = e[1,], maturity = m, selectivity = v, lambda = exp(r), env = ENV))
            
            # objective function
            objective <- -1 * log(sum(n[(v + 1):dim(n)[1], dim(n)[2]] * h))
            
            # return
            return(objective)
        }
        
        if (STOCHASTIC) {
            
            # set up objective
            # function to estimate
            # harvest rate at 
            # maximum sustainable 
            # catch
            obj2 <- function(x) {
                
                h     <- 1 / (1 + exp(-x[1]))
                shape <- exp(x[2])
                
				# get pars
				m <- DataEval(get_m)
				r <- DataEval(get_r)
				s <- DataEval(get_s)
				l <- DataEval(get_l)
				e <- DataEval(get_e)				
				v <- DataEval(get_v)
				b <- DataEval(get_b)
		
				# get selectivity
				m <- as.integer(getValues(m))
				v <- as.integer(getValues(v))
            
                objective <- 0
                
                for (i in 1:dim(s)[1]) {
                    
                    # spin spinner
                    cli_progress_update(.envir = ENV)
                    
                    # stochastic dynamics
                    n <- do.call(".pdyn2", list(h = h, shape = shape, survivorship = s[i,], multiplier = l, fecundity = b, epsilon = e[i,], maturity = m, selectivity = v, lambda = exp(r), env = ENV))
                    
                    # recent time
                    loc <- ceiling((2 / 3) * dim(n)[2]):dim(n)[2]
                    
                    # log of the equilibrium catch
                    # per iteration
                    objective <- objective - log(sum(n[(v + 1):dim(n)[1], loc] * h) / length(loc))
                }
                
                # return
                return(objective)
            }
        
        }
        
        ###################
        # first iteration #
        ###################
        
        # set seed
        set.seed(rng_seed[1])
        
        # sample pars
        pars_sample <- lapply(object@pars, sample, n = 1)
		
		# assign pars
        m <- pars_sample$m
        r <- pars_sample$rmax
		s <- pars_sample$s
        l <- pars_sample$l
        v <- pars_sample$v
		b <- pars_sample$b
		
		s <- .survivorship(s, env = ENV)
		e <- .epsilon(env = ENV)
		
		#print(paste("r:", round(pars_sample$r, 5)))
		#print(paste("rmax:", round(pars_sample$rmax, 5)))
		#print(paste("rest:", round(log(.solve_lambda(m, S, S * l, b)), 5)))
        
        # progress message
        if (ESTIMATE_HMNPL) {
            if (STOCHASTIC) {
                cli_progress_step("Estimating stochastic reference points ...", spinner = TRUE, msg_done = "Estimated stochastic reference points", .envir = ENV)
            } else {
                cli_progress_step("Estimating deterministic reference points ...", spinner = FALSE, msg_done = "Estimated deterministic reference points", .envir = ENV)
            }
        }
        
        # check shape exists
        stopifnot(length(object@shape) > 0)
        
		if (ESTIMATE_HMNPL) {
		
			# function to estimate h_mnpl
			# given shape
			h1 <- MakeTape(obj1, c(.logit(r / 2), log(object@shape[1])))
			h2 <- h1$newton(1)
			
			# record initial 
			# deterministic estimates
			h_logit_init <- h2(c(log(object@shape[1])))
        }
		
        if (STOCHASTIC) {
            
            s <- .survivorship(pars_sample$s, object@settings$cv$survivorship, env = ENV)
			e <- .epsilon(object@settings$cv$birth, env = ENV)
            
            # estimate h_mnpl only
            # if not already estimated
            if (ESTIMATE_HMNPL) {
				
				# tidy up
				rm(obj1, h1, h2)
                
				# function to estimate
                # stochastic h_mnpl
                h1 <- MakeTape(obj2, c(h_logit_init, log(object@shape[1])))
                h2 <- h1$newton(1)
                
                # record stochastic estimate
                object@targets$harvest_rate[1] <- .ilogit(h2(c(log(object@shape[1]))))
            }
            
        } else {
            
            # record deterministic estimate only
            # if not already estimated
            if (ESTIMATE_HMNPL) {
                object@targets$harvest_rate[1] <- .ilogit(h_logit_init)
            }
        
        }
        
        if (!is.na(object@targets$harvest_rate[1])) {
            object@targets$captures[1]  <- fast_forward(object@targets$harvest_rate[1], shape = object@shape[1], survivorship = s, multiplier = l, fecundity = b, epsilon = e, maturity = m, selectivity = v, lambda = exp(r), env = ENV)$captures
            object@targets$depletion[1] <- fast_forward(object@targets$harvest_rate[1], shape = object@shape[1], survivorship = s, multiplier = l, fecundity = b, epsilon = e, maturity = m, selectivity = v, lambda = exp(r), env = ENV)$depletion    
        }
        
        #######################
        # monte-carlo samples #
        # from life-history   #
        # distributions       #
        #######################
        if (NITER > 1) {
            for (i in 2:NITER) {
                
                # set seed
                set.seed(rng_seed[i])
                
                # sample pars
                pars_sample <- lapply(object@pars, sample, n = 1)
				
				# assign pars
				m <- pars_sample$m
				r <- pars_sample$rmax
				s <- pars_sample$s
				l <- pars_sample$l
				v <- pars_sample$v
				b <- pars_sample$b
				
				#print(paste("r:", round(pars_sample$r, 5)))
				#print(paste("rmax:", round(pars_sample$rmax, 5)))
				#print(paste("rest:", round(log(.solve_lambda(m, S, S * l, b)), 5)))
				            
				s <- .survivorship(s, ifelse(STOCHASTIC, object@settings$cv$survivorship, 0), env = ENV)
				e <- .epsilon(ifelse(STOCHASTIC, object@settings$cv$birth, 0), env = ENV)
				
                # record estimate if
                # necessary
                if (ESTIMATE_HMNPL) {
                    
					h2$force.update()
                    
                    object@targets$harvest_rate[i] <- .ilogit(h2(log(object@shape[i])))
                }
				
				if (!is.na(object@targets$harvest_rate[i])) {
				    
				    object@targets$captures[i]  <- fast_forward(object@targets$harvest_rate[i], shape = object@shape[i], survivorship = s, multiplier = l, fecundity = b, epsilon = e, maturity = m, selectivity = v, lambda = exp(r), env = ENV)$captures
				    object@targets$depletion[i] <- fast_forward(object@targets$harvest_rate[i], shape = object@shape[i], survivorship = s, multiplier = l, fecundity = b, epsilon = e, maturity = m, selectivity = v, lambda = exp(r), env = ENV)$depletion    
				}
            }
        }
        
        #for (i in 1:NITER) {
        #    
        #    # check and reject
        #    if (round(object@targets$depletion[i], 1) != round(mean(object@targets$depletion, na.rm = TRUE), 1)) {
        #        warning("failed to converge on target depletion of ", round(mean(object@targets$depletion, na.rm = TRUE), 1), " for 'sample = ", i, "'")    
        #        object@targets$captures[i]     <- NA_real_
        #        object@targets$harvest_rate[i] <- NA_real_
        #        object@targets$depletion[i]    <- NA_real_
        #    }
        #}
        
    # }}}
    }
    
    # return
    return(object)
})
#}}}


