#' @title catchability
#' 
#' @description Calculate catchability using empirical abundance data and reconstructed exploitable biomass trajectory
#' 
#' 
#' @include om-class.R
#' 
#{{{ catchability()
setGeneric("catchability", function(object, ...) standardGeneric("catchability"))
setMethod("catchability", signature = "om", function(object, ...) {
    
    if(!(length(object@n) > 0)) {
        object <- pdyn(object)
    }

    bexp <- biomass(object, type = 'exploitable')

    index <- object@fishing$index

    nidx  <- dim(object@fishing$index)[2]
    niter <- object@iter

    q <- array(dim = c(nidx,niter))

    for(i in 1:nidx) {
        index.tmp <- matrix(rep(index[,i], niter), ncol = niter)
        q[i,] <- apply(sweep(index.tmp, 1:2, bexp, '/'), 2, function(x) exp(mean(log(x), na.rm=TRUE)))
    }

    dimnames(q) <- list(index = 1:nidx, iter = 1:niter)
    
    object@q <- q
    
    return(object)
})
    