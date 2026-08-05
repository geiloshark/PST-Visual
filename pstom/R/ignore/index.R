#' @title index
#' 
#' @description Generate simualated abundance index values
#' 
#' 
#' @include om-class.R catchability.R biomass.R
#' 
#{{{ index()
# generate simulated index observations
setGeneric("index", function(object, ...) standardGeneric("index"))
setMethod("index", signature = "om", function(object, stochastic = FALSE, ...) {
    
    if(!(length(object@q) > 0)) {
        object <- catchability(object)
    }
	
    index  <- object@fishing$index
    sigmao <- object@fishing$sigmao
 
    bexp <- biomass(object, type = 'exploitable')
    
    q     <- object@q
    
    time  <- object@fishing$time
    tmax  <- length(object@fishing$time)
    nidx  <- dim(object@fishing$index)[2]
    niter <- object@iter
    
    predicted_index <- array(dim = c(tmax,nidx,niter), dimnames = list(time=time, index=1:nidx, iter=1:niter))
    
    # scale exploitable biomass by catchability
    for(i in 1:nidx) {
        predicted_index[,i,] <- sweep(bexp, 2, q[i,], '*')
    }
    
    # apply stochastic observation error
    if (stochastic) {
        for (i in 1:nidx) {
            if (niter > 1) {
                residual_error  <- sweep(predicted_index[,i,], 1, index[,i], function(x,y) log(x/y))
                simulated_error <- apply(residual_error, 2, function(x) .simulate_residual_error(x, sigmao[,i]))
            } else {
                residual_error  <- log(predicted_index[,i,]/index[,i])
                simulated_error <- .simulate_residual_error(residual_error, sigmao[,i])
            }
            predicted_index[,i,] <- predicted_index[,i,] * exp(-simulated_error)
        }
    }
    
    # check missing data is cleaned out
    # (should not be necessary when stochastic = TRUE)
    for (i in 1:nidx) {
        missing_data <- object@empirical_data$index[,i]
        missing_data[!is.na(missing_data)] <- 1
        if (niter > 1) {
            predicted_index[,i,] <- sweep(predicted_index[,i,], 1, missing_data,'*')
        } else {
            predicted_index[,i,] <- predicted_index[,i,] * missing_data
        }
    }
    
    object@.Data <- predicted_index
    
    return(object)
    
})
#}}}
#{
# simulation function for log-residual error
.simulate_residual_error <- function(x, sigma) {
    
    ##########################################
    # FIT AR1 MODEL TO OBERVATION ERROR      #
    # RESIDUALS AND SIMULATE NEW RESIDUALS   # 
    # WITH BIAS AND AUTO-CORRELATION IN THE  #
    # RESIDUAL PREDICTION ERROR              #
    ##########################################
    #
    ## fit auto-regressive model
    #x.fit <- ar(x, order.max = 1, na.action = na.exclude)
    #
    ## extract first-order autoregression
    ## coefficient if significant
    #if(x.fit$order>0) {
    #    x.alpha <- x.fit$ar[1]
    #} else x.alpha <- 0
    #
    ## residual prediction error
    #x.sd <- sqrt(x.fit$var.pred)
    #
    ## location of non-NA values
    #loc <- which(!is.na(x))
    #
    ## non-NA time series
    #x.loc <- x[loc] 
    #
    ## simulate forward using AR0 or AR1 process
    #x.loc[1] <- x.loc[1] + rnorm(1, x.alpha * x.loc[1], x.sd)
    #for(i in 2:length(x.loc))
    #    x.loc[i] <- x.loc[i] + rnorm(1, x.alpha * x.loc[i-1], x.sd)
    #
    ## re-assign to input vector
    #x[loc] <- x.loc
    
    #######################################
    # GENERATE UNBIASED RESIDUALS WITH NO #
    # OBSERVATION ERROR STRUCTURE         #
    #######################################
    
    # residual prediction error
    x.sd <- sigma
    
    # location of non-NA values
    loc <- which(!is.na(x))
    
    # non-NA time series
    x.loc <- x[loc] 
	x.sd  <- x.sd[loc]
    
    # simulate observation error residuals
    x.loc <- rnorm(length(x.loc), -(x.sd^2)/2, x.sd)
    
    # re-assign to input vector
    x[loc] <- x.loc
    
    #########
    return(x)
    
}
#}



