#' @title Access outputs from operating model object. 
#' @aliases targets diagnostics pst objectives pars numbers settings
#' @description Access outputs stored in \code{\link{om-class}} object following call to \code{\link{pdyn}}.
#' @param object \code{\link{om-class}} object. 
#' @importFrom crayon blue
#' @importFrom dplyr bind_rows
#' @include om-class.R get_dim.R array2dfr.R
#{{{
#' @export
setGeneric("targets", function(object, ...) standardGeneric("targets"))
# accessor function
#' @rdname targets
setMethod("targets", signature = c("om"), function(object) {
    get_dim(object, env = environment())
    #message(blue("::: management target :::"))
    lapply(object@targets, function(x) { y <- data.frame(sample = 1:NITER, value = x);  as_tibble(y) })  
})
#}}}
#{{{
#' @export
setGeneric("diagnostics", function(object, ...) standardGeneric("diagnostics"))
# accessor function
#' @rdname targets
setMethod("diagnostics", signature = c("om"), function(object) {
    get_dim(object, env = environment())
    #message(blue("::: operating model output :::"))
    lapply(object@diagnostics, function(x) array2dfr(x, dim.names = list(sample = 1:dim(x)[1], iteration = 1:dim(x)[2], time = object@time)))
})
#}}}
#{{{
#' @export
setGeneric("pst", function(object, ...) standardGeneric("pst"))
# accessor function
#' @rdname targets
setMethod("pst", signature = c("om"), function(object) {
    get_dim(object, env = environment())
    #message(blue("::: operating model output :::"))
    array2dfr(object@pst$value, dim.names = list(sample = 1:NITER, iteration = 1:SITER, time = object@time))
})
#}}}

#{{{
#' @export
setGeneric("objectives", function(object, ...) standardGeneric("objectives"))
# accessor function
#' @rdname targets
setMethod("objectives", signature = c("om"), function(object) {
    get_dim(object, env = environment())
    #message(blue("::: probability of reaching management target :::"))
    lapply(object@objectives,  function(x) array2dfr(x, dim.names = list(sample = 1:NITER, time = object@time)))
})
#}}}

#{{{
#' @export
setGeneric("pars", function(object, ...) standardGeneric("pars"))
# accessor function
#' @rdname targets
setMethod("pars", signature = c("om"), function(object) {
    object@pars
})
#}}}
#{{{
#' @export
setGeneric("settings", function(object, ...) standardGeneric("settings"))
# accessor function
#' @rdname targets
setMethod("settings", signature = c("om"), function(object) {
    lapply(lapply(object@settings, bind_rows), data.frame)
})
#}}}
#{{{
#' @export
setGeneric("numbers", function(object, ...) standardGeneric("numbers"))
# accessor function
#' @rdname targets
setMethod("numbers", signature = c("om"), function(object) {
    get_dim(object, env = environment())
    array2dfr(object@.Data, dim.names = list(sample = 1:NITER, iteration = 1:SITER, time = object@time))
})
#}}}

