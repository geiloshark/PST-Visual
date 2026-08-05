#' @title Calculate shape
#' 
#' @description Calculates shape parameter given assumed depletion at MNPL.
#' @param object \code{om} class object
#' @param depletion Assumed depletion of breeding-age individuals at MNPL
#' @param stochastic logical value indicating whether stochastic production function should be calculated (defaults to value in \code{settings$ref_points})
#' @param time equilibrium time horizon over which values are calculated (defaults to value in \code{settings$ref_points})
#' @param iterations numeric value indicating number of iterations for when \code{stochastic = TRUE} (defaults to value in \code{settings$ref_points})
#' @param verbose logical value indicating whether values \code{stochastic}, \code{time} or \code{iterations} should be printed
#' @param safe logical value indicating whether RTMB model should be recompiled with each sample (resulting in a more stable estimation)
#' @seealso \code{\link{rp}}
#' @export
#' @include om-class.R dot-pdyn.R dot-check.R dot-logit.R dot-survivorship.R
#' @import RTMB
#' @importFrom cli cli_progress_step cli_progress_update
#{{{ shape()
# wrapper for execution of population
# dynamics function
setGeneric("shape", function(object, depletion, ...) standardGeneric("shape"))
setMethod("shape", signature = c(object = "om", depletion = "numeric"), function(object, depletion, stochastic, time, iterations, verbose = FALSE, safe = TRUE, ...) {
    
    # current environment
    ENV <- environment()
    
    # check and update object with
    # function arguments
    object <- .check_rp(object, stochastic, time, iterations, verbose)
    
    # load time, age and
    # iteration dimensions
    # into function environment
    get_dim(object, ref_points = TRUE, env = ENV)
    
	# recompile model for each sample?
	SAFE <- ifelse(safe, TRUE, FALSE)
	
    # get seeds
    get_seeds(object, env = ENV)
    
    # check pars
    for (a in c("m", "s", "l", "b", "v")) {
        if (isTRUE(is.na(object@pars[[a]]))) {
            stop("'", a, "' is missing from 'object@pars'")
        }
    }
    
    # re-set targets
    object@targets$captures     <- rep(NA_real_, NITER)
    object@targets$harvest_rate <- rep(NA_real_, NITER)
    object@targets$depletion    <- rep(NA_real_, NITER)
    
    # create container(s)
    shape_values <- numeric(NITER)
    h_values     <- numeric(NITER)
	
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
	# function
	# for harvest rate at
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
		
		# get values
		m <- as.integer(getValues(m))
		v <- as.integer(getValues(v))
		
		# spin spinner
        cli_progress_update(.envir = ENV)
		
		# deterministic dynamics
        n <- do.call(".pdyn", list(h = h, shape = shape, survivorship = s[1,], multiplier = l, fecundity = b, epsilon = e[1,], maturity = m, selectivity = v, lambda = exp(r), env = ENV))
		
		# objective function
		objective <- -1 * log(sum(n[(v + 1):dim(n)[1], dim(n)[2]] * h))
		
		# return lambda
		return(objective)
	}
	
	# set up objective
	# function
	# for depletion at 
	# target 
	# (deterministic)
	obj2 <- function(x) {
	    
		shape  <- exp(x[1])
		h      <- 1 / (1 + exp(-h2(x[1]))) # internal estimation of h_mnpl given shape
		target <- x[2]
		
		# get pars
		m <- DataEval(get_m)
		r <- DataEval(get_r)
		s <- DataEval(get_s)
		l <- DataEval(get_l)
		e <- DataEval(get_e)
		v <- DataEval(get_v)
		b <- DataEval(get_b)
		
		# get values
		m <- as.integer(getValues(m))
		v <- as.integer(getValues(v))
		
		# spin spinner
        cli_progress_update(.envir = ENV)
			
		# deterministic dynamics
        n <- do.call(".pdyn", list(h = h, shape = shape, survivorship = s[1,], multiplier = l, fecundity = b, epsilon = e[1,], maturity = m, selectivity = v, lambda = exp(r), env = ENV))
		
		# objective function
		#objective <- -1 * dnorm(sum(n[(m + 2):dim(n)[1], dim(n)[2]]), target, 0.01, log = TRUE)
        objective <- -1 * dnorm(sum(n[2:dim(n)[1], dim(n)[2]]), target, 0.01, log = TRUE)
		
		# return objective
		return(objective)
	}
	
    if (STOCHASTIC) {
        
        # progress message
        cli_progress_step("Estimating the stochastic shape parameter ...", spinner = TRUE, msg_done = "Estimated shape = {round(mean(shape_values, na.rm = TRUE), 2)}, with max. harvest rate = {round(mean(h_values, na.rm = TRUE), 2)}")
        
        # set up objective
        # function and tape
        # for harvest rate at
        # maximum sustainable 
        # catch
        obj3 <- function(x) {
            
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
		
			# get values
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
        
        # set up objective
        # function and tape
        # for depletion at 
        # target 
        obj4 <- function(x) {
            
            shape  <- exp(x[1])
            h      <- 1 / (1 + exp(-h2(x[1]))) # internal estimation of h_mnpl given shape
            target <- x[2]
            
			# get pars
			m <- DataEval(get_m)
			r <- DataEval(get_r)
			s <- DataEval(get_s)
			l <- DataEval(get_l)
			e <- DataEval(get_e)
			v <- DataEval(get_v)
			b <- DataEval(get_b)
		
			# get values
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
                #objective <- objective - dnorm(mean(apply(n[(m + 2):dim(n)[1], loc], 2, sum)), target, 0.01, log = TRUE)
                objective <- objective - dnorm(mean(apply(n[2:dim(n)[1], loc], 2, sum)), target, 0.01, log = TRUE)
            }
            
            # return objective
            return(objective)
        }
        
    } else {
        
        # progress message
        cli_progress_step("Estimating the deterministic shape parameter ...", spinner = TRUE, msg_done = "Estimated shape = {round(mean(shape_values, na.rm = TRUE), 2)}, with max. harvest rate = {round(mean(h_values, na.rm = TRUE), 2)}")
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
	l <- pars_sample$l
	s <- pars_sample$s
	v <- pars_sample$v
	b <- pars_sample$b
    
	s <- .survivorship(s, env = ENV)
	e <- .epsilon(env = ENV)
	
    # function to estimate h_mnpl
    # given shape
    h1 <- MakeTape(obj1, c(.logit(r / 2), log(1)))
    h2 <- h1$newton(1)

    # function to estimate
    # shape given depletion target
    i1 <- MakeTape(obj2, c(log(1), 0.5))
    i2 <- i1$newton(1)
    
    # record initial 
	# deterministic estimates
	shape_log_init <- i2(depletion)
	h_logit_init   <- h2(shape_log_init)
	
	if (STOCHASTIC) {
	
		# tidy up
		rm(h1, h2, i1, i2)
		
	    # simulate stochastic
		# survivorship
	    s <- .survivorship(pars_sample$s, object@settings$cv$survivorship, env = ENV)
	    
		# stochastic birth
		# deviation
		e <- .epsilon(object@settings$cv$birth, env = ENV)
		    
		# recompile with 
		# initial values
		h1 <- MakeTape(obj3, c(h_logit_init, shape_log_init))
		h2 <- h1$newton(1)
		i1 <- MakeTape(obj4, c(shape_log_init, depletion))
		i2 <- i1$newton(1)
		
		# record estimate
		shape_values[1] <- exp(i2(depletion))
		h_values[1]     <- .ilogit(h2(log(shape_values[1])))
		
	} else {
	
		shape_values[1] <- exp(shape_log_init)
		h_values[1]     <- .ilogit(h2(log(shape_values[1])))
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
			
			########################################
			# IN SAFE MODE THE MODEL IS RECOMPILED #
			# WITH EACH SAMPLE - THIS HELPS WHEN   #
			# THERE IS UNCERTAINTY IN EITHER       #
			# m OR v - OTHERWISE IT IS NOT         #
			# NECESSARY                            #
			########################################
			if (SAFE) {
			    
			    s <- .survivorship(s, env = ENV)
			    e <- .epsilon(env = ENV)
			    
    			# function to estimate h_mnpl
    			# given shape
    			h1 <- MakeTape(obj1, c(.logit(r / 2), log(1)))
    			h2 <- h1$newton(1)
    			
    			# function to estimate
    			# shape given depletion target
    			i1 <- MakeTape(obj2, c(log(1), 0.5))
    			i2 <- i1$newton(1)
    			#i2$force.update()
    			
    			# record initial 
    			# deterministic estimates
    			shape_log_init <- i2(depletion)
    			h_logit_init   <- h2(shape_log_init)
    			
    			if (STOCHASTIC) {
    			    
    			    # simulate stochastic
    			    # survivorship
    			    s <- .survivorship(pars_sample$s, object@settings$cv$survivorship, env = ENV)
    			    
    			    # stochastic birth
    			    # deviation
    			    e <- .epsilon(object@settings$cv$birth, env = ENV)
    			    
    			    # recompile with 
    			    # initial values
    			    h1 <- MakeTape(obj3, c(h_logit_init, shape_log_init))
    			    h2 <- h1$newton(1)
    			    i1 <- MakeTape(obj4, c(shape_log_init, depletion))
    			    i2 <- i1$newton(1)
    			    
    			    # record estimate
    			    shape_values[i] <- exp(i2(depletion))
    			    h_values[i]     <- .ilogit(h2(log(shape_values[i])))
    			    
    			} else {
    			    
    			    shape_values[i] <- exp(shape_log_init)
    			    h_values[i]     <- .ilogit(h2(log(shape_values[i])))
    			}
			} else {
			    
			    s <- .survivorship(s, ifelse(STOCHASTIC, object@settings$cv$survivorship, 0), env = ENV)
			    e <- .epsilon(ifelse(STOCHASTIC, object@settings$cv$birth, 0), env = ENV)
			    
			    h2$force.update()
			    i2$force.update()
			    
			    # record estimate
			    shape_values[i] <- exp(i2(depletion))
			    h_values[i]     <- .ilogit(h2(log(shape_values[i])))
			}
        }
    }
    
    # shape per sample
    object@shape <- shape_values
    
    # record harvest rates
    object@targets$harvest_rate <- h_values
    
    # return
    return(object)
})
# accessor function
#' @rdname shape
setMethod("shape", signature = c(object = "om"), function(object, ...) {
    object@shape
})
# assignment function
#' @rdname shape
#' @export
setGeneric("shape<-", function(object, ..., value) standardGeneric("shape<-"))
#' @rdname shape
setMethod("shape<-",
          signature(object = "om", value = "numeric"),
          function(object, value) {
              
			  if (length(value) < object@samples) {
				if (length(value) == 1) {
					value <- rep(value, object@samples)
				} else {
					stop("'value' should be of length '1' or 'object@samples'")
				}
			  } else {
				if (length(value) > object@samples) {
					stop("'value' should be of length '1' or 'object@samples'")
				}
			  }
              if (any(value <= 0)) {
                  stop('Assigned value must be >0')
              }

              object@shape <- value  
              
              return(object)
          }
)
#}}
