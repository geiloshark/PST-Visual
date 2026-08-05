#' @title Surplus production function
#' @description Extracts data frame containing relationships between the depletion, sustainable captures and the harvest rate. Depletion is measured using the breeding age classes.
#' @details This function is designed to facilitate the easy creation of plots of the production function, that can be used to validate operating model assumptions regarding the depletion and harvest rate at MNPL. The production function is calculated assuming either deterministic or stochastic reference point calculations, depending on the setting stored in \code{object@settings$ref_points}.
#' @param harvest_rate numeric vector of harvest rates over which surplus production should be calculated 
#' @param stochastic logical value indicating whether stochastic production function should be calculated (defaults to value in \code{settings$ref_points})
#' @param time equilibrium time horizon over which values are calculated (defaults to value in \code{settings$ref_points})
#' @param iterations numeric value indicating number of iterations for when \code{stochastic = TRUE} (defaults to value in \code{settings$ref_points})
#' @param verbose logical value indicating whether values \code{stochastic}, \code{time} or \code{iterations} should be printed
#' @return A data frame containing depletion, sustainable captures and the harvest rate, for each of the input harvest rate values. If life-history inputs are uncertain, iterations are sampled. These iterations do not represent any process error, only uncertainty in the operating model conditioning. 
#' @include dot-pdyn.R dot-survivorship.R
#' @importFrom dplyr bind_rows
#' @importFrom cli cli_progress_step cli_progress_update
#' @importFrom glue glue
#' @export
setGeneric("spf", function(object, harvest_rate, ...) standardGeneric("spf"))
#' @rdname spf
#' @export
setMethod("spf", signature = c(object = "om", harvest_rate = "numeric"), function(object, harvest_rate, stochastic, time, iterations, verbose = FALSE, ...) {
    
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
    
    # output
    out <- list()
    
    #######################
    # monte-carlo samples #
    # from life-history   #
    # distributions       #
    #######################
	
	msg <- ""
    cli_progress_step("Calculating surplus production function{msg}", spinner = TRUE, msg_done = "Calculated production function", .envir = ENV)
			
    for (i in 1:NITER) {
        
        # set seed
        set.seed(rng_seed[i])
        
		# progress sample
        msg <- ifelse(NITER > 1, glue(", sample {i}/", NITER), " ...")
			
        # sample pars
        pars_sample <- lapply(object@pars, sample, n = 1)
        
        # assign pars
		m <- pars_sample$m
		r <- pars_sample$rmax
		s <- pars_sample$s
		l <- pars_sample$l
		v <- pars_sample$v
		b <- pars_sample$b
		
		#print(.solve_lambda(m = m, s = S, s0 = S * l, b = pars_sample$b))
        
        dvalue <- numeric(length(harvest_rate))
        cvalue <- numeric(length(harvest_rate))
        pvalue <- numeric(length(harvest_rate))
        
        if (STOCHASTIC) {
            
            s <- .survivorship(s, object@settings$cv$survivorship, env = ENV)
			e <- .epsilon(object@settings$cv$birth, env = ENV)
            
            for (j in 1:length(harvest_rate)) {
                
                tmp <- .ff2(harvest_rate[j], shape = object@shape[i], survivorship = s, multiplier = l, fecundity = b, epsilon = e, maturity = m, selectivity = v, lambda = exp(r), env = ENV)
                
                cvalue[j] <- tmp$captures
                dvalue[j] <- tmp$depletion
                pvalue[j] <- tmp$production
                
                # spin spinner
                cli_progress_update(.envir = ENV)
            }
            
        } else {
            
            s <- .survivorship(s, env = ENV)
			e <- .epsilon(env = ENV)
            
            for (j in 1:length(harvest_rate)) {
                
                tmp <- .ff(harvest_rate[j], shape = object@shape[i], survivorship = s, multiplier = l, fecundity = b, epsilon = e, maturity = m, selectivity = v, lambda = exp(r), env = ENV)
                
                cvalue[j] <- tmp$captures
                dvalue[j] <- tmp$depletion
                pvalue[j] <- tmp$production
				
				# spin spinner
                cli_progress_update(.envir = ENV)
            }
        }
        
        out[[i]] <- data.frame(harvest_rate = harvest_rate, captures = cvalue, depletion = dvalue, productivity = pvalue)
    }
    
    # return
    return(bind_rows(out, .id = "sample"))
})


