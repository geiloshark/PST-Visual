#' @title Plot function for distribution class
#' @importFrom logitnorm dlogitnorm
#' @exportS3Method base::plot
plot.distribution <- function(x, y = "missing", ...) {
    
    pars   <- x@pars
    dens   <- x@density
    values <- x@.Data
    
    # plot density
    if (grepl("^uniform", dens))       curve(dunif(x, pars[1], pars[2]), from = pars[1], to = pars[2], col = 2, yaxt = "n", xlab = "x", ylab = "uniform density", lwd = 2, ...)
    if (grepl("^normal", dens))        curve(dnorm(x, pars[1], pars[2]), from = pars[1] - 3 * pars[2], to = pars[1] + 3 * pars[2], col = 2, yaxt = "n", xlab = "x", ylab = "normal density", lwd = 2, ...)
    if (grepl("^zt?.normal", dens))    curve(dnorm(x, pars[1], pars[2]), from = max(0, pars[1] - 3 * pars[2]), to = pars[1] + 3 * pars[2], col = 2, yaxt = "n", xlab = "x", ylab = "zt-normal density", lwd = 2, ...)
    if (grepl("^log?.normal", dens))   curve(dlnorm(x, pars[1], pars[2]), from = exp(pars[1] - 3 * pars[2]), to = exp(pars[1] + 3 * pars[2]), col = 2, yaxt = "n", xlab = "x", ylab = "log-normal density", lwd = 2, ...)
    if (grepl("^gamma", dens))         curve(dgamma(x, shape = pars[1], scale = pars[2]), from = max(0, pars[1] * pars[2] - 3 * sqrt(pars[1] * pars[2]^2)), to = pars[1] * pars[2] + 3 * sqrt(pars[1] * pars[2]^2), col = 2, yaxt = "n", xlab = "x", ylab = "Gamma density", lwd = 2, ...)
    if (grepl("^logit?.normal", dens)) curve(dlogitnorm(x, pars[1], pars[2]), from = invlogit(pars[1] - 3 * pars[2]), to = invlogit(pars[1] + 3 * pars[2]), col = 2, yaxt = "n", xlab = "x", ylab = "logit-normal density", lwd = 2, ...)
    
    # add first moment
    mmts <- summary(x)
    abline(v = mmts['E[x]'], col = 2, lty = 2)
    mtext(paste("E[x] =", round(mmts['E[x]'], 2)), adj = 0, padj = -1)
    
    # add values if present
    if (length(values[!is.na(values)]) > 0) {
        hist(values[!is.na(values)], probability = TRUE, add = TRUE, col = NA)
    }
}

