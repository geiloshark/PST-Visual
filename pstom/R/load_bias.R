#' @title Load bias 
#' @aliases load_biases
#' @description Load bias into \code{\link{om-class}} object for stochastic projection.
#' @param value named list object containing values for \code{observation} or \code{mortality}. 
#' @param ... (not used)
#' @include om-class.R
#' @export
#{{{
setGeneric("load_bias", function(object, value, ...) standardGeneric("load_bias"))
setMethod("load_bias", signature = c("om", "list"), function(object, value, ...) {
    
    # assign
    for (i in names(object@settings$bias)) {
        if (i %in% names(value)) {
            object@settings$bias[[i]] <- value[[i]]
        }
    }
    
    # don't assign
    for (i in names(value)) {
        if (!(i %in% names(object@settings$bias))) {
            warning("'", i, "' ignored")    
        }
    }
    
    # return
    return(object)
})
#}}}


