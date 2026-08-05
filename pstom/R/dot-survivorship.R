
.survivorship <- function(S, cv = 0, env) {
		
	NTIME <- get("NTIME", envir = env)
	SITER <- get("SITER", envir = env)
	
	if (cv > 0) {
		
		# process error term
		sigma <- cv * S
		
		# calculate mu given sigma
		mu <- uniroot(function(x) S - pnorm(x / sqrt(1 + sigma^2)), interval = c(-10, 10))$root
		
		s <- array(dim = c(SITER, NTIME))
		e <- rnorm(SITER * NTIME, mu, sigma)
			
		s[] <- pnorm(e)
			
		# first year is
		# equal to expectation
		s[,1] <- S
		
	} else {
	
		s   <- array(dim = c(SITER, NTIME))
		s[] <- S
	}
	
	return(s)
}
