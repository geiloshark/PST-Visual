#' @title Access or assign phi parameter
#' @description Access or assign the \eqn{\phi} value used to tune the PST reference point. 
#' @export
setGeneric("phi", function(object, ...) standardGeneric("phi"))
# accessor function
#' @rdname phi
setMethod("phi", signature = c(object = "om"), function(object, ...) {
    object@pst$phi
})
# assignment function
#' @rdname phi
#' @export
setGeneric("phi<-", function(object, ..., value) standardGeneric("phi<-"))
#' @rdname phi
setMethod("phi<-",
          signature(object = "om", value = "numeric"),
          function(object, value) {
              
              if (length(value) != 1) {
                  stop("'value' should be of length '1'")
              }
              if (any(value < 0)) {
                  stop("'value' must be >0")
              }
              
              object@pst$phi <- value  
              
              return(object)
          }
)
#}}
