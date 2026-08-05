#' 
#' @rdname distribution-class
#' 
#' @param values vector of values
#' @param name label for parameter
#' @param pars parameters for distriution (of length 2)
#' @param density density distribution (i.e., beta, uniform, normal, lognormal, logitnormal or gamma)
#' 
#' @examples
#' # create object containing
#' # vector of values
#' iter <- 1e5
#' cv <- 0.2
#' sd <- sqrt(log(1 + cv^2))
#' mu <- log(1) - sd^2/2
#' x <- rlnorm(iter, mu, sd)
#' y <- distribution(value = x, density = "lognormal")
#' 
#' # show
#' y
#' 
#' # plot histogram
#' hist(y)
#' abline(v = mean(y), col = 2)
#' 
#' # summarise
#' summary(y)
#' 
#' # create object
#' # without values
#' y <- distribution(pars = c(mu, sd), density = "lognormal")
#' summary(y)
#' 
#' # parametric sampling
#' hist(om::sample(y, n = 1e5))
#' 
#' # non-parametric sampling
#' y <- distribution(values = 0:10, density = "unspecified")
#' om::sample(y)
#'  
#' @include distribution-class.R sample.distribution.R
#' 
#' @export
distribution <- function(...) UseMethod("distribution")
#' @export
distribution.numeric <- function(...) new("distribution", ...)
#' @export
distribution.character <- function(...) new("distribution", ...)
    
# functionality
# add vector plus distribution -> calculate parameters
# add distribution plus pars <- simulate vector

