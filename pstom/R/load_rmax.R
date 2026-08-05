#' @title load rmax
#' 
#' @description Load \eqn{r_{max}} into the \code{pars} slot of an \code{om-class} object.
#' @details The intrinsic growth rate is assumed to have normal distribution. It is converted to a zero-truncated normal on assignment because the maximum growth rate is always assumed to be greater than zero (i.e., \eqn{\lambda > 1}). 
#' @include om-class.R distribution-class.R sample.distribution.R
#' @importFrom cli cli_alert_danger
#' @export
#{{{ load rmax into om object
setGeneric("load_rmax", function(object, value, ...) standardGeneric("load_rmax"))
#{{ distribution object
setMethod("load_rmax", signature = c("om", "distribution"), function(object, value, ...) {

    # checks
    if (value@density != "unspecified") {
        if (value@density != "normal" & value@density != "zt-normal") {
            cli_alert_danger("input distribution is not 'normal' or 'zt-normal'")
        } else {
            value@density <- "zt-normal"
        }
    }
    
    # assign zt-density distribution
    object@pars$rmax      <- value
    object@pars$rmax@name <- "max. intrinsic growth rate"
    
    # return    
    return(object)
})
setMethod("load_rmax", signature = c("om", "missing"), function(object, value, ...) {
    
    # use 'r' by default
    value <- object@pars$r 

    # return    
    return(load_rmax(object, value))
})
