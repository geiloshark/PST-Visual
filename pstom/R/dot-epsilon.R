
.epsilon <- function(cv = 0, env) {

	NTIME <- get("NTIME", envir = env)
	SITER <- get("SITER", envir = env)
	
	if (cv > 0) {
		
		e <- array(dim = c(SITER, NTIME))
		
		e[] <- exp(log(1 / sqrt(1 + cv^2)) + rnorm(SITER * NTIME) * sqrt(log(1 + cv^2)))
		
	} else {
	
		e   <- array(dim = c(SITER, NTIME))
		e[] <- 1
	}
	
	return(e)
}
