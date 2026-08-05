#' @export
#' @importFrom logitnorm twCoefLogitnormMLEFlat momentsLogitnorm momentsLogitnorm dlogitnorm
solveLogitNormal <- function(expected_value, sigma, plot = FALSE) {
    
    z <- list()
    
    sigma_max <- as.numeric(twCoefLogitnormMLEFlat(expected_value)[2])
    
    if (sigma > sigma_max) {
        sigma <- sigma_max
        warning("'sigma' is too high for a uni-modal distribution; reduced to sigma <- ", round(sigma, 3))    
    }
    
    mu    <- uniroot(f = function(x) momentsLogitnorm(x, sigma = sigma)[1] - expected_value, interval = c(-10, 10))$root
    sigma <- sigma
    mmt   <- momentsLogitnorm(mu, sigma)
    
    z$mu     <- round(as.numeric(mu), 3)
    z$sigma  <- round(as.numeric(sigma), 3)
    z$mean   <- round(as.numeric(mmt[1]), 3)
    z$var    <- round(as.numeric(mmt[2]), 3)
    z$cv     <- round(as.numeric(sqrt(mmt[2]) / mmt[1]), 3)
    
    if (plot) {
        curve(dlogitnorm(x, mu, sigma), yaxt = 'n', ylab = '')
        mtext(paste("E[x] =", round(mmt[1], 2)), adj = 0, padj = -1)
        abline(v = mmt[1], col = 2)
    }
    
    return(z)
}
