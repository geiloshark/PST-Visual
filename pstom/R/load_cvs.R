#' @title Load coefficients of variation 
#' @aliases load_cv
#' @description Load coefficients of variation into \code{\link{om-class}} object for stochastic projection and (optionally) reference point estimation.
#' @param value named list object containing values for \code{survivorship}, \code{birth}, \code{observation}, \code{mortality}
#' @param ... (not used)
#' @include om-class.R
#' @export
#{{{
setGeneric("load_cvs", function(object, value, ...) standardGeneric("load_cvs"))
setMethod("load_cvs", signature = c("om", "list"), function(object, value, ...) {
    
	# assign
    for (i in names(object@settings$cv)) {
        if (i %in% names(value)) {
            object@settings$cv[[i]] <- value[[i]]
        }
    }
    
    # don't assign
    for (i in names(value)) {
        if (!(i %in% names(object@settings$cv))) {
            warning("'", i, "' ignored")    
        }
    }
    
    # return
    return(object)
})
#}}}


