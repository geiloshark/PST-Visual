#' @title load_life_history
#' 
#' @description Load life-history data into \code{om-class} object from \code{lhmSimple-class} object. If required, the maximum intrinsic growth is calculated. 
#' @details The \code{lhmSimple-class} object can store any relevant information necessary for the operating model projection. Once loaded, these values are accessible within the \code{populations_dynamics} function stored in the \code{om-class} object.

#' @import lhmSimple
#' 
#' @include om-class.R
#' @export
#{{{ load life history data into om object
setGeneric("load_life_history", function(object, value, ...) standardGeneric("load_life_history"))
#{{ lhmSimple object
setMethod("load_life_history", signature = c("om", "lhmSimple"), function(object, value, ...) {
    
    if (!any(is.na(object@ages))) {
        
        loc <- match(object@ages, value@ages)
        stopifnot(!any(is.na(loc)))
        
        object@life_history <- lapply(value@.Data, function(x) {
            if (nrow(x) > 1) {
                x[loc,]
            } else {
                x
            }})
    }
    
    if (is.na(object@iter)) {
        object@iter <- as.integer(value@iter)
    } else {
        if (object@iter != value@iter) {
            stop("'iter' does not match")
        } else {
            object@iter <- as.integer(value@iter)
        }
    }
	
	# calculate rmax and 
    # add dimensions to 
    # reference point
	object@pst$rmax  <- rCalc(value)@.Data
	object@pst$value <- if (all(is.na(object@time))) matrix(NA_real_, nrow = 1, ncol = object@iter) else matrix(NA_real_, nrow = length(object@time), ncol = object@iter)
	
	# return    
    return(object)
})

#{{ distribution object
setMethod("load_life_history", signature = c("om", "distribution"), function(object, value, ...) {
    
    if (is.na(object@iter)) {
        object@iter     <- as.integer(value@iter)
        object@pst$rmax <- value@.Data
    } else {
        if (object@iter == value@iter) {
            object@pst$rmax <- value@.Data
        } else {
            if (value@iter == 1) {
                object@pst$rmax <- rep(value@.Data, object@iter)
            } else {
                stop("'iter' does not match")
            }
        }
    }
    
    # add dimensions to 
    # reference point
    #object@pst$value <- if (all(is.na(object@time))) matrix(NA_real_, nrow = 1, ncol = object@iter) else matrix(NA_real_, nrow = length(object@time), ncol = object@iter)
    
    # return    
    return(object)
})

