#' @title Load or update parameters
#' @aliases update_pars 
#' @description Load or update parameters in \code{\link{om-class}} object. Each parameter should be provided as a \code{\link{distribution-class}}.
#' @param value named list object containing parameter distributions. 
#' @include om-class.R distribution-class.R dot-el.R
#' @importFrom cli cli_alert_info cli_alert_warning
#' @export
#{{{
setGeneric("load_pars", function(object, value, ...) standardGeneric("load_pars"))
setMethod("load_pars", signature = c("om", "list"), function(object, value, ...) {
    
    # check names
    lapply(names(value), function(a) stopifnot(a %in% names(object@pars)))
    
    # assign
    for (i in 1:length(value)) {
        if (is(value[[i]], 'distribution')) {
            if (names(value)[i] %in% names(object@pars)) {
                object@pars[[which(names(object@pars) %in% names(value)[i])]] <- value[[i]]
            } else {
                stop(paste0("'", names(value)[i], "' not assigned"))
            }
        } else {
            stop("value must be of class 'distribution'")
        }
    }
    
    # calculate r
    if (is(object@pars[["m"]], "distribution") & is(object@pars[["s"]], "distribution") & is(object@pars[["b"]], "distribution") & is(object@pars[["l"]], "distribution")) {
        
		object@pars[["r"]] <- NA_real_
		
        lambda_values <- numeric(1e4)
        
        for (i in 1:length(lambda_values)) {
            
            m_sample <- sample(object@pars[["m"]])
            s_sample <- sample(object@pars[["s"]])
            b_sample <- sample(object@pars[["b"]])
            l_sample <- sample(object@pars[["l"]])
            
            lambda_values[i] <- .solve_lambda(m = m_sample, s = s_sample, s0 = s_sample * l_sample, b = b_sample)
        }
        
        r_values <- log(lambda_values)
            
        if (sum(lambda_values >= 1) < 1e4) {
            cli_alert_warning(paste0(round(100 * (1 - sum(lambda_values >= 1) / 1e4), 2), "% of samples yield a lambda < 1"))
        }
        
        # calculate normal pars
        # from r ~ N(mu, sigma)
        r_dist <- distribution(values = r_values, density = "normal")
        object@pars[["r"]] <- distribution(pars = r_dist@pars, density = "normal", name = "intrinsic growth rate")
    }
    
    # return
    return(object)
})



#}}}
#' @export
#' @rdname load_pars
#{{{
setGeneric("update_pars", function(object, value, ...) standardGeneric("update_pars"))
setMethod("update_pars", signature = c("om", "list"), function(object, value, ...) {
    
    # check names
    lapply(names(value), function(a) stopifnot(a %in% names(object@pars)))
    
    # assign
    if (any(c("m", "s", "l", "b") %in% names(value))) {
        
        object <- load_pars(object, value)
    
        cli_alert_info("re-calculated 'r'")
        
    } else {
        
        for (i in 1:length(value)) {
            if (is(value[[i]], 'distribution')) {
                if (names(value)[i] %in% names(object@pars)) {
                    object@pars[[which(names(object@pars) %in% names(value)[i])]] <- value[[i]]
                } else {
                    stop(paste0("'", names(value)[i], "' not assigned"))
                }
            } else {
                stop("value must be of class 'distribution'")
            }
        }
    }
    
    # return
    return(object)
})
#}}}




