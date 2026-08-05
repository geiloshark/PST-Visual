#' @title Operating model class
#' 
#' @description 
#' Operating model class definition.
#' @slot ages integer vector of ages assumed by operating model. Set to \code{NA} when a cohort aggregated model is assumed.
#' @slot time integer vector of times used for operating model projection or single value giving the number of time steps.
#' @slot samples integer value indicating number of samples from the input value distributions specified in \code{pars}.
#' @slot settings list of settings used to for reference point evaluation with \code{\link{shape}} and \code{\link{rp}}. 
#' @slot pars list of input parameter distributions used by the operating model. See \code{\link{load_pars}}.
#' @slot shape numeric vector of shape values estimated or specified using \code{\link{shape}}.
#' @slot harvest_rate function containing the harvest rate function.
#' @slot pst list containing \code{phi}, \code{rmax} and \code{value} elements related to the PST threshold reference point.
#' @slot targets list containing \code{capture}, \code{depletion} and \code{harvest_rate} target reference points estimated using \code{\link{rp}}.
#' @slot objectives list containing probability values indicating whether management target has been reached (i.e., the realised objective values). 
#' 
#' @importFrom crayon blue red
#{{{
# class definition
setClass("om", contains = "array", slots = list(ages = 'integer', samples = 'integer', time = 'numeric', shape = 'numeric', settings = 'list', pars = 'list', values = 'list', harvest_rate = 'function', pst = 'list', targets = 'list', diagnostics = 'list', objectives = 'list', seeds = 'integer'))
#}}}
#{{{
# initialisation function
setMethod("initialize", "om", function(.Object, ages, harvest_function, samples = 1, time, shape = 1, phi = 1, ...) {
    
    if(missing(harvest_function) | missing(ages)) {
        .Object@harvest_rate <- function() NA_real_
    } else {
        .Object@harvest_rate <- harvest_function
    }
    
    if (!grepl("object", deparse1(harvest_function))) stop("'harvest_function' must contain 'object' as its first argument")
    
    if(missing(samples)) {
        stop("'samples' is a required input")
    } else {
        .Object@samples <- as.integer(samples)
    }
    
    if(missing(time)) {
        stop("'time' is a required input")
    } else {
        if (length(time) > 1) {
            .Object@time <- time
        } else {
            .Object@time <- 0:(time - 1)
        }
    }
    
    if(missing(ages) | is.null(ages)) {
        .Object@ages <- NA_integer_
		stop("no 'ages' supplied: cohort aggregated model is not currently supported")
    } else {
		if (length(ages) > 1) {
			if (min(ages) == 0) {
				.Object@ages <- ages
			} else {
				stop("minimum age must be zero")
			}
		} else {
			.Object@ages <- 0:ages
		}
    }
    
    # setup settings required
    # for reference point
    # estimation and projection
    .Object@settings$ref_points <- list(stochastic = NA, iterations = NA_integer_, time = NA_integer_)
    .Object@settings$projection <- list(stochastic = NA, iterations = NA_integer_, time = length(.Object@time))
    .Object@settings$cv         <- list(survivorship = 0.0, birth = 0.0, numbers = 0.0, harvest_rate = 0.0, capture = 0.0, rmax = 0.0)
    .Object@settings$qn         <- list(numbers = c(0.0, NA_real_))
    .Object@settings$bias       <- list(numbers = 1.0, harvest_rate = 1.0, capture = 1.0, rmax = 1.0)
    
    # setup PST limit
    # reference point
    .Object@pst$phi   <- phi
    .Object@pst$rmax  <- rep(NA_real_, samples)
    .Object@pst$value <- NA_real_
    
    # setup pars
    # (intrinsic growth)
    .Object@pars$r <- NA_real_ 
    # (max. intrinsic growth)
    .Object@pars$rmax <- NA_real_ 
    # (adult female survivorship)
    .Object@pars$s <- NA_real_
    # (age-zero survivorship multiplier)
    .Object@pars$l <- NA_real_
    # (annual births per adult female)
    .Object@pars$b <- NA_real_
    # (age at female maturity)
    .Object@pars$m <- NA_real_
    # (age at observation)
    .Object@pars$o <- NA_real_
    # (age at selectivity)
    .Object@pars$v <- NA_real_
    # (carrying capacity)
    .Object@pars$K <- distribution(value = 1, name = "K")
    
    # setup values to 
    # store pars iterations
	.Object@values$rmax  <- NA_real_
    .Object@values$r     <- NA_real_
	.Object@values$shape <- NA_real_
    .Object@values$s     <- NA_real_
	.Object@values$l     <- NA_real_
    .Object@values$b     <- NA_real_
	.Object@values$beq   <- NA_real_
	.Object@values$bstar <- NA_real_
    .Object@values$m     <- NA_real_
    .Object@values$o     <- NA_real_
    .Object@values$v     <- NA_real_
    .Object@values$K     <- NA_real_
    
    # setup management
    # target reference points
    # (estimated or assumed MNPL values)
    .Object@targets$captures     <- NA_real_
    .Object@targets$harvest_rate <- NA_real_
    .Object@targets$depletion    <- NA_real_
    
    # set up diagnostics
    .Object@diagnostics$captures     <- NA_real_
    .Object@diagnostics$depletion    <- NA_real_
    .Object@diagnostics$harvest_rate <- NA_real_
    
    # set up objectives
    .Object@objectives$captures     <- NA_real_
    .Object@objectives$depletion    <- NA_real_
    .Object@objectives$harvest_rate <- NA_real_

    # record rng seeds
    seeds <- floor((runif(samples)) * 1e7)
    if (any(duplicated(seeds))) warning(sum(duplicated(seeds)), "/", samples, " (approx. ", round(100 * sum(duplicated(seeds)) / samples), "%) of seeds are duplicated")
    if (any(is.na(as.integer(seeds)))) warning(sum(is.na(as.integer(seeds))), "/", samples, " seeds are 'NA' values")
    .Object@seeds <- as.integer(seeds)
    
    # return
    return(.Object)
})
#}}}
# {{{
setMethod("show", "om",
          function(object) {
              message(blue("om-class object"))
              message("time: ", if (length(object@time) > 8) paste0(c(object@time[1:6], "...", object@time[length(object@time)]), collapse = ", ") else paste0(object@time, collapse = ", "))
              message("ages: ", if (length(object@ages) > 14) paste0(c(object@ages[1:12], "...", object@ages[length(object@ages)]), collapse = ", ") else paste0(object@ages, collapse = ", "))
              message("\t")
              message("ntime: ", if (all(is.na(object@time))) NA_character_ else length(object@time))
              message("nages: ", if (all(is.na(object@ages))) NA_character_ else length(object@ages))
              message("niter: ", object@samples, " (samples)")
              message("siter: ", object@settings$ref_points$iterations, " (ref. points)")
			  message("siter: ", object@settings$projection$iterations, " (projections)")
              #message("pars: ", if (length(object@pars) > 0) paste0(names(object@pars), collapse = ", ") else red("EMPTY"))
              message("shape: ", if (length(object@shape) > 0) { if (length(object@shape) > 14) { paste0(c(round(object@shape[1:12], 2), "...", round(object@shape[length(object@shape)], 2)), collapse = ", ") } else { paste0(round(object@shape, 2), collapse = ", ") }} else red("EMPTY"))
              message("\nharvest rate function:")
              message(writeLines(deparse(object@harvest_rate)))
              message("rmax:")
              show(object@pars$rmax)
          })
# }}}

