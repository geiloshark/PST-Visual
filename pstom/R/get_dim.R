#' @title Get dimensions and values
#' @aliases get_values
#' @description
#' Extract dimensions and/or values from \code{\link{om-class}} object for use within a function call.
#' @include om-class.R
#' @export
get_dim <- function(object, ...) UseMethod("get_dim")
#' @rdname get_dim
#' @export
get_dim.om <- function(object, projection = TRUE, ref_points = !projection, env = environment()) {
    
    ages   <- object@ages
    time   <- object@time
    
    NITER  <- object@samples
    SITER  <- ifelse(is.na(object@settings$projection$iterations), 1L, object@settings$projection$iterations)
    
    NAGES  <- length(ages)
    NTIME  <- length(time)
    
    STOCHASTIC <- object@settings$projection$stochastic
    
    if (ref_points) {
        
        NTIME <- object@settings$ref_points$time
        SITER <- ifelse(is.na(object@settings$ref_points$iterations), 1L, object@settings$ref_points$iterations)
        
        STOCHASTIC <- object@settings$ref_points$stochastic
    }
    
    if (is.environment(env)) {
        lapply(c("ages", "time", "NITER", "SITER", "NAGES", "NTIME", "STOCHASTIC"), function(x) assign(x, get(x), envir = env))
    } else {
        warning("not a valid environment!")    
    }
    
    invisible()
}
#' @export
get_values <- function(object, ...) UseMethod("get_values")
#' @rdname get_dim
#' @export
get_values.om <- function(object, iter = 1, env = environment()) {
    
    ll <- object@pars
    
    rm(object)
    
    if (is.environment(env)) {
        lapply(names(ll), function(x) assign(x, ll[[x]][, iter], envir = env))
    } else {
        warning("not a valid environment!")    
    }
    
    invisible()
}
#' @export
get_fixed <- function(object, ...) UseMethod("get_fixed")
#' @rdname get_dim
#' @export
get_fixed.om <- function(object, env = environment()) {
    
    if (is.environment(env)) {
        lapply(names(object@fixed), function(x) assign(x, slot(get("object"), "fixed")[[x]], envir = env))
    } else {
        warning("not a valid environment!")    
    }
    
    invisible()
}
#' @export
get_seeds <- function(object, ...) UseMethod("get_seeds")
#' @rdname get_dim
#' @export
get_seeds.om <- function(object, env = environment()) {
    
    if (is.environment(env)) {
        assign("rng_seed", slot(get("object"), "seeds"), envir = env)
    } else {
        warning("not a valid environment!")    
    }
    
    invisible()
}

#' @export
get_shape <- function(object, ...) UseMethod("get_shape")
#' @rdname get_dim
#' @export
get_shape.om <- function(object, env = environment()) {
    
    if (is.environment(env)) {
        assign("shape", slot(get("object"), "shape"), envir = env)
    } else {
        warning("not a valid environment!")    
    }
    
    invisible()
}

