#' @title load.empirical_data
#' 
#' @description Load empirical catch and abundance data into om object
#' 
#' 
#' @include om-class.R
#' 
#{{{ load empirical data into om object
setGeneric("load_empirical_data", function(object,x, ...) standardGeneric("load_empirical_data"))
#{{ list object
setMethod("load_empirical_data", signature=c("om", "list"),function(object, x, ...) {
  
    if(is.list(x)) {
        loc <- match('index', names(x))
        if(!is.na(loc)) {
            object@fishing$index <- as.matrix(x[[loc]])
            object@fishing$index[object@fishing$index <= 0] <- NA
        }
        loc <- match('sigmao', names(x))
        if(!is.na(loc)) {
            object@fishing$sigmao <- as.matrix(x[[loc]])
			object@fishing$sigmao[object@fishing$sigmao <= 0] <- NA
        }
        loc <- match('harvest', names(x))
        if(!is.na(loc)) {
            object@fishing$harvest <- as.numeric(x[[loc]])
        }
        loc <- match('time', names(x))
        if(!is.na(loc)) {
            object@time <- as.integer(x[[loc]])
        } else object@time <- 1:length(object@fishing$harvest)
    } else  
        stop('empirical data should be a list of harvest and index values\n')
    
    return(object)
})
    