
.el <- function(lambda, m, b, s, s0) {
    lambda^(m + 1) - lambda^m * s - (b / 2) * s0 * s^m
}

.solve_lambda <- function(m, s, s0, b, ...) {
    uniroot(f = .el, m = m, b = b, s = s, s0 = s0, interval = c(0, 10), ...)$root
}

.solve_s0 <- function(lambda, m, s, b, ...) {
    uniroot(f = .el, lambda = lambda, m = m, b = b, s = s, interval = c(0, 1), ...)$root
}

.solve_b <- function(lambda, m, s, s0, ...) {
    uniroot(f = .el, lambda = lambda, m = m, s = s, s0 = s0, interval = c(0, 10), ...)$root
}
