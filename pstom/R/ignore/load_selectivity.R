#' @title load_selectivity
#' 
#' @description Load selectivity ogives into \code{om-class} object.
#' 
#' 
#' @include om-class.R
#' 
#{{{ load selectivity assumption into om object
setGeneric("load_selectivity", function(object,x, ...) standardGeneric("load_selectivity"))
setMethod("load_selectivity", signature = c("om", "matrix"), function(object, x, ...) {
    
    get_dims(object)
    
    # check age dimension
    x <- apply(x, 2, function(y) { if(length(y) < nages) y[(length(y) + 1):nages] <- y[length(y)]; y}) 
    
    # check iteration dimension
    if(dim(x)[2] < niter) {
        if(dim(x)[2] > 1) {
            stop('conflict between selectivity dimension and number of mc-samples\n')
        } else {
            x <- matrix(rep(x, niter), ncol = niter)
        } 
    }
    
    dimnames(x) <- list(age = ages, iter = 1:niter)
    
    object@fishing$selectivity <- x
    
    return(object)
})
#}}}
