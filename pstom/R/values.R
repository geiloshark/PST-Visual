#' @title Values calculated by the population dynamics function
#' 
#' @description Extracts values generated internally for projection by \code{\link{pdyn}}. 
#' 
#' @export
#' @importFrom tibble as_tibble
#' @include pdyn.R
#{{{ values()
setGeneric("values", function(object, ...) standardGeneric("values"))
setMethod("values", signature = "om", function(object, stochastic, iterations, ...) {
    
    if (all(unlist(lapply(lapply(object@values, is.na), all)))) {
	    values <- suppressMessages(pdyn(object, stochastic, iterations, time = 1, initial_depletion = 1.0, verbose = FALSE, ...))
    } else {
        values <- object
    }
    
	return(as_tibble(data.frame(sample = 1:object@samples, values@values)))
})

