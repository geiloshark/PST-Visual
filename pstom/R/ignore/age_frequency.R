#' @title biomass
#' 
#' @description Reconstruct biomass trajectory based on input data
#' 
#' 
#' @include om-class.R
#' 
#{{{ biomass()
setGeneric("age_frequency", function(object, ...) standardGeneric("age_frequency"))
setMethod("age_frequency", signature = "om", function(object, type, ...) {
    
    if(!(length(object@.Data) > 0)) {
        object <- pdyn(object)
	}

    n <- object@.Data

    selectivity <- as.matrix(object@fishing$selectivity)
    
    niter <- object@iter
    
    age_frequency <- n

    for(i in 1:niter) {
        age_frequency[,,i] <- apply(sweep(n[,,i], 1:2, selectivity[,i], '*' ), 2, function(x) rmultinom(1, size = 1e3, prob = x)[,1])
    }
    
    return(age_frequency)
})
