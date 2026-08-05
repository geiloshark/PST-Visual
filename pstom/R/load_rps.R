#' @title Load reference point targets. 
#' 
#' @description Load management targets into \code{\link{om-class}} object. These can be the Maximum Net Productivity Level (MNPL) and corresponding harvest rate and depletion values. 
#' @param value named list object containing target reference points. List elements can be all or one of \code{captures}, \code{depletion} and \code{harvest_rate}.
#' @details Targets are assumed to be known without error, and used to measure outcome of the population projection. 
#' @seealso See \code{\link{rp}} for reference point estimation. 
#' @include om-class.R
#' @export
#{{{
setGeneric("load_rps", function(object, value, ...) standardGeneric("load_rps"))
# assignment function
#' @rdname load_rps
setMethod("load_rps", signature = c("om", "list"), function(object, value) {
    
    # check names
    lapply(names(value), function(a) stopifnot(a %in% names(object@targets)))
    
    # match length
    # to object@samples
    value <- lapply(value, function(x) {
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
        return(value)
    })
    
    # assign
    for (i in 1:length(value)) {
        if (names(value)[i] %in% names(object@targets)) {
            object@targets[[which(names(object@targets) %in% names(value)[i])]] <- value[[i]]
        } else {
            stop(paste0("'", names(value)[i], "' not assigned"))
        }
    }
    
    # return
    return(object)
})
#}}}



