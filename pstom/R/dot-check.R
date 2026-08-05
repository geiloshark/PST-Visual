#' @importFrom cli cli_alert_info
.check_rp <- function(object, stochastic, time, iterations, verbose) {
 
    object_settings <- object@settings$ref_points
    
    if (missing(stochastic)) {
        if (is.na(object_settings$stochastic)) {
            stop("'stochastic' argument unspecified")    
        } else {
            if (object@settings$cv$survivorship == 0 & object@settings$cv$birth == 0) {
                object_settings$stochastic <- FALSE
            }
            if (verbose) {
                cli_alert_info(paste0("'stochastic' = ", ifelse(object_settings$stochastic, "TRUE", "FALSE")))
            }
        }
    } else {
        if (is.logical(stochastic)) {
            if (!is.na(object_settings$stochastic) & object_settings$stochastic != stochastic) {
                if (verbose) {
                    cli_alert_info("'stochastic' argument updates value in 'object@settings$ref_points'")
                }
            }
            if (object@settings$cv$survivorship == 0 & object@settings$cv$birth == 0) {
                if (stochastic) {
                    stochastic <- FALSE
                    if (verbose) {
                        cli_alert_info("'stochastic' argument updated to 'FALSE'")
                    }
                }
            }
            object_settings$stochastic <- stochastic
        } else {
            stop("'stochastic' is not logical")    
        }
    }
    if (missing(time)) {
        if (is.na(object_settings$time)) {
            stop("'time' argument unspecified")    
        } else {
            if (verbose) {
                cli_alert_info(paste0("'time' = ", object_settings$time))
            }
        }
    } else {
        if (time %% 1 == 0) {
            time <- as.integer(time)
            if (!is.na(object_settings$time) & object_settings$time != time) {
                if (verbose) {
                    cli_alert_info("'time' argument updates value in 'object@settings$ref_points'")
                }
            }
            object_settings$time <- time
        } else {
            stop("'time' is not an integer")    
        }
    }
    if (missing(iterations)) {
        if (is.na(object_settings$iterations) & object_settings$stochastic) {
            stop("'iterations' argument unspecified for stochastic model")    
        } else {
            if (object_settings$stochastic) {
                if (verbose) {
                    cli_alert_info(paste0("'iterations' = ", object_settings$iterations))
                }
            } else {
                object_settings$iterations <- NA_integer_
            }
        }
    } else {
        if (iterations %% 1 == 0) {
            iterations <- as.integer(iterations)
            if (!is.na(object_settings$iterations) & !object_settings$stochastic) {
                cli_alert_warning("'iterations' argument specified but model is not stochastic")
                iterations <- NA_integer_
            }
            if (!is.na(object_settings$iterations) & object_settings$iterations != iterations) {
                if (verbose) {
                    cli_alert_info("'iterations' argument updates value in 'object@settings$ref_points'")
                }
            }
            object_settings$iterations <- iterations
        } else {
            stop("'iterations' is not an integer")    
        }
    }
    object@settings$ref_points <- object_settings
    
    return(object)   
}

.check_pdyn <- function(object, stochastic, time, iterations, verbose, use_rmax) {
    
    object_settings <- object@settings$projection
    
    if (missing(stochastic)) {
        if (is.na(object_settings$stochastic)) {
            stop("'stochastic' argument unspecified")    
        } else {
            if (all(unlist(lapply(object@settings$cv, function(x) x == 0)))) {
                object_settings$stochastic <- FALSE
            }
            if (verbose) {
                cli_alert_info(paste0("'stochastic' = ", ifelse(object_settings$stochastic, "TRUE", "FALSE")))
            }
        }
    } else {
        if (is.logical(stochastic)) {
            if (!is.na(object_settings$stochastic) & object_settings$stochastic != stochastic) {
                if (verbose) {
                    cli_alert_info("'stochastic' argument updates value in 'object@settings$projection'")
                }
            }
            if (all(unlist(lapply(object@settings$cv, function(x) x == 0)))) {
                object_settings$stochastic <- FALSE
                if (stochastic) {
                    if (verbose) {
                        cli_alert_info("'stochastic' argument updated to 'FALSE'")
                    }
                }
            }
            object_settings$stochastic <- stochastic
        } else {
            stop("'stochastic' is not logical")    
        }
    }
    if (missing(time)) {
        if (any(is.na(object@time))) {
            stop("'time' argument unspecified")    
        }
    } else {
        if (length(time) == 1) {
            if (time > 0) {
                time <- as.integer(0:time)
            } else {
                stop("'time' must be >0")
            }
        } else {
            time <- as.integer(time)    
        }
        if (!all(object@time %in% time) | !all(time %in% object@time)) {
            if (verbose) {
                cli_alert_info("'time' argument updates values in 'object@time'")
            }
        }
        object@time          <- time
        object_settings$time <- length(time)
    }
    if (missing(iterations)) {
        if (is.na(object_settings$iterations) & object_settings$stochastic) {
            cli_abort("'iterations' argument unspecified for stochastic model")    
        } else {
            if (object_settings$stochastic) {
                if (verbose) {
                    cli_alert_info(paste0("'iterations' = ", object_settings$iterations))
                }
            } else {
                object_settings$iterations <- NA_integer_
            }
        }
    } else {
        if (iterations %% 1 == 0) {
            iterations <- as.integer(iterations)
            if (!is.na(object_settings$iterations) & !object_settings$stochastic) {
                cli_alert_warning("'iterations' argument specified but model is not stochastic")
                iterations <- NA_integer_
            }
            if (!is.na(object_settings$iterations) & object_settings$iterations != iterations) {
                if (verbose) {
                    cli_alert_info("'iterations' argument updates value in 'object@settings$projection'")
                }
            }
            object_settings$iterations <- iterations
        } else {
            stop("'iterations' is not an integer")    
        }
    }
	if (verbose & use_rmax) {
		cli_alert_info("running with 'r = rmax' (this is helpful when testing reference point estimates)")
	}
	
	# assign
    object@settings$projection <- object_settings
    
    return(object)   
}



