#' @import RTMB
.pdyn <- function(h, shape, survivorship, multiplier, fecundity, epsilon, maturity, selectivity, lambda, env) {
    
	NAGES <- get("NAGES", envir = env)
	NTIME <- get("NTIME", envir = env)
	
	age_mat <- as.integer(maturity)
	age_pat <- age_mat + 1L
	age_sel <- as.integer(selectivity)
	
	mat    <- c(rep(0, age_mat), rep(1, NAGES - age_mat))
	pat    <- c(rep(0, age_pat), rep(1, NAGES - age_pat))
	sel    <- c(rep(0, age_sel), rep(1, NAGES - age_sel))
			
    n <- AD(array(dim = c(NAGES, NTIME)))
    p <- AD(numeric(NAGES))
    #S <- c(rep(survivorship[1] * multiplier, age_mat), rep(survivorship[1], NAGES - age_mat))
    S <- c(survivorship[1] * multiplier, rep(survivorship[1], NAGES - 1))
	
	s <- matrix(survivorship, ncol = NTIME, nrow = NAGES, byrow = TRUE)
	#s <- (sweep(s, 1, 1 - mat, "*") * multiplier) + sweep(s, 1, mat, "*")
	s[1,] <- s[1,] * multiplier
	
    birth <- function(y) {
        0.5 * sum(pat[-1] * n[-1,y]) * (b_eq + (b_max - b_eq) * (1 - (sum(n[-1,y]))^shape))
    }
    
    # set up unexploited 
    # equilibrium female
    # population
    p[1] <- 0.5
    for(a in 2:NAGES) {
        p[a] <- p[a - 1] * S[a - 1]
    }
    p[a] <- p[a] / (1 - S[a])
    
    # replacement birth rate
    # per female
    b_eq <- 1 / sum(pat * p)
    
    # maximum fecundity
    b_max <- 2 * (lambda^(age_mat + 1) - S[age_mat + 1] * lambda^(age_mat)) / prod(S[1:(age_mat + 1)])
    
    # population
    # at equilibrium
    k_prime <- b_eq * p
    
    # initial conditions
    # (sum(k1+) = 1)
    k <- k_prime / sum(k_prime[-1])
    
    # use iteration to calculate
    # initial age structure
    # and depletion
    n_init <- AD(matrix(k, nrow = NAGES, ncol = 2))
    for (l in 2:1e3) {
        
        n_init[, 1] <- n_init[, 2]
        for(a in 2:NAGES) {
            n_init[a, 2] <- n_init[a - 1, 1] * S[a - 1] * (1 - sel[a - 1] * h)
        }
        n_init[a, 2] <- n_init[a, 2] + n_init[a, 1] * S[a] * (1 -  sel[a] * h)
        n_init[1, 2] <- 0.5 * sum(pat[-1] * n_init[-1, 2]) * (b_eq + (b_max - b_eq) * (1 - (sum(n_init[-1, 2]))^shape))
    }
    
    # check depletion
    #if(.Call("_RTMB_getValues", sum(n_init[-1, 2]), PACKAGE = "RTMB") > 1) {
    #    warning("initial depletion > 1")    
    #}
    
    # check for negative values
    #if(any(.Call("_RTMB_getValues", n_init[-1, 2], PACKAGE = "RTMB") < 0)) {
    #    warning("initial numbers[c(", paste0(which(n_init[-1, 2] < 0), collapse = ","), ")] < 0")  
    #}
    
    # initialise
    n[, 1] <- n_init[, 2]
    
    # project
    for (y in 2:NTIME) {
        
        for (a in 2:NAGES) {
            n[a, y] <- n[a - 1, y - 1] * s[a - 1, y - 1] * (1 - sel[a - 1] * h) 
        }
        
        # plus group
        n[a, y] <- n[a, y] + n[a, y - 1] * s[a, y - 1] * (1 - sel[a] * h)
        
        # birth
        n[1, y] <- birth(y) * epsilon[y]
    }
    
    return(n)
}
# projection function with advector types
# removed and constraints on depletion
.pdyn_proj <- function(h, shape, survivorship, multiplier, fecundity, epsilon, maturity, selectivity, lambda, env) {
    
    NAGES <- get("NAGES", envir = env)
    NTIME <- get("NTIME", envir = env)
    
    age_mat <- as.integer(maturity)
    age_pat <- age_mat + 1L
    age_sel <- as.integer(selectivity)
    
    mat    <- c(rep(0, age_mat), rep(1, NAGES - age_mat))
    pat    <- c(rep(0, age_pat), rep(1, NAGES - age_pat))
    sel    <- c(rep(0, age_sel), rep(1, NAGES - age_sel))
    
    n <- array(dim = c(NAGES, NTIME))
    p <- numeric(NAGES)
    #S <- c(rep(survivorship[1] * multiplier, age_mat), rep(survivorship[1], NAGES - age_mat))
    S <- c(survivorship[1] * multiplier, rep(survivorship[1], NAGES - 1))
    
    s <- matrix(survivorship, ncol = NTIME, nrow = NAGES, byrow = TRUE)
    #s <- (sweep(s, 1, 1 - mat, "*") * multiplier) + sweep(s, 1, mat, "*")
    s[1,] <- s[1,] * multiplier
    
    birth <- function(y) {
        0.5 * sum(pat[-1] * n[-1,y]) * (b_eq + (b_max - b_eq) * (1 - (min(1, sum(n[-1,y])))^shape))
    }
    
    # set up unexploited 
    # equilibrium female
    # population
    p[1] <- 0.5
    for(a in 2:NAGES) {
        p[a] <- p[a - 1] * S[a - 1]
    }
    p[a] <- p[a] / (1 - S[a])
    
    # replacement birth rate
    # per female
    # (equal to: 2 * (1 - S[age_mat + 1]) / prod(S[1:(age_mat + 1)])
    b_eq <- 1 / sum(pat * p)
    
    # maximum fecundity
    b_max <- 2 * (lambda^(age_mat + 1) - S[age_mat + 1] * lambda^(age_mat)) / prod(S[1:(age_mat + 1)])
    
    # population
    # at equilibrium
    k_prime <- b_eq * p
    
    # initial conditions
    # (sum(k1+) = 1)
    k <- k_prime / sum(k_prime[-1])
    
    # use iteration to calculate
    # initial age structure
    # and depletion
    n_init <- matrix(k, nrow = NAGES, ncol = 2)
    for (l in 2:1e3) {
        
        n_init[, 1] <- n_init[, 2]
        for(a in 2:NAGES) {
            n_init[a, 2] <- n_init[a - 1, 1] * S[a - 1] * (1 - sel[a - 1] * h)
        }
        n_init[a, 2] <- n_init[a, 2] + n_init[a, 1] * S[a] * (1 -  sel[a] * h)
        n_init[1, 2] <- 0.5 * sum(pat[-1] * n_init[-1, 2]) * (b_eq + (b_max - b_eq) * (1 - (min(1, sum(n_init[-1, 2])))^shape))
    }
    
    # check depletion
    if(sum(n_init[-1, 2]) > 1) {
        warning("initial depletion > 1")    
    }
    
    # check for negative values
    if(any(n_init[-1, 2] < 0)) {
        warning("initial numbers[c(", paste0(which(n_init[-1, 2] < 0), collapse = ","), ")] < 0")    
    }
    
    # initialise
    n[, 1] <- n_init[, 2]
    
    # project
    for (y in 2:NTIME) {
        
        for (a in 2:NAGES) {
            n[a, y] <- n[a - 1, y - 1] * s[a - 1, y - 1] * (1 - sel[a - 1] * h) 
        }
        
        # plus group
        n[a, y] <- n[a, y] + n[a, y - 1] * s[a, y - 1] * (1 - sel[a] * h)
        
        # birth
        n[1, y] <- birth(y) * epsilon[y]
    }
    
    return(n)
}

.pdyn2 <- function(h, shape, survivorship, multiplier, fecundity, epsilon, maturity, selectivity, lambda, env) {
    
	NAGES <- get("NAGES", envir = env)
	NTIME <- get("NTIME", envir = env)
	
	age_mat <- as.integer(maturity)
	age_pat <- age_mat + 1L
	age_sel <- as.integer(selectivity)
	
	mat    <- c(rep(0, age_mat), rep(1, NAGES - age_mat))
	pat    <- c(rep(0, age_pat), rep(1, NAGES - age_pat))
	sel    <- c(rep(0, age_sel), rep(1, NAGES - age_sel))
			
    n <- AD(array(dim = c(NAGES, NTIME)))
    p <- AD(numeric(NAGES))
    #S <- c(rep(survivorship[1] * multiplier, age_mat), rep(survivorship[1], NAGES - age_mat))
    S <- c(survivorship[1] * multiplier, rep(survivorship[1], NAGES - 1))
	
	s <- matrix(survivorship, ncol = NTIME, nrow = NAGES, byrow = TRUE)
	#s <- (sweep(s, 1, 1 - mat, "*") * multiplier) + sweep(s, 1, mat, "*")
	s[1,] <- s[1,] * multiplier
    
	birth <- function(y) {
        0.5 * sum(pat[-1] * n[-1,y]) * (b_eq + (b_max - b_eq) * (1 - (sum(n[-1,y]))^shape))
    }
    
    # set up unexploited 
    # equilibrium female
    # population
    p[1] <- 0.5
    for(a in 2:NAGES) {
        p[a] <- p[a - 1] * S[a - 1]
    }
    p[a] <- p[a] / (1 - S[a])
    
    # replacement birth rate
    # per female
    b_eq <- 1 / sum(pat * p)
    
    # maximum fecundity
    b_max <- 2 * (lambda^(age_mat + 1) - S[age_mat + 1] * lambda^(age_mat)) / prod(S[1:(age_mat + 1)])
    
    # population
    # at equilibrium
    k_prime <- b_eq * p
    
    # initial conditions
    # (sum(k1+) = 1)
    k <- k_prime / sum(k_prime[-1])
    
    # use iteration to calculate
    # initial age structure
    # and depletion
    n_init <- AD(matrix(k, nrow = NAGES, ncol = 2))
    for (l in 2:1e3) {
        
        n_init[, 1] <- n_init[, 2]
        for(a in 2:NAGES) {
            n_init[a, 2] <- n_init[a - 1, 1] * S[a - 1] * (1 - sel[a - 1] * h)
        }
        n_init[a, 2] <- n_init[a, 2] + n_init[a, 1] * S[a] * (1 -  sel[a] * h)
        n_init[1, 2] <- 0.5 * sum(pat[-1] * n_init[-1, 2]) * (b_eq + (b_max - b_eq) * (1 - (sum(n_init[-1, 2]))^shape))
    }
    
    # check depletion
    #if(.Call("_RTMB_getValues", sum(n_init[-1, 2]), PACKAGE = "RTMB") > 1) {
    #    warning("initial depletion > 1")    
    #}
    
    # check for negative values
    #if(any(.Call("_RTMB_getValues", n_init[-1, 2], PACKAGE = "RTMB") < 0)) {
    #    warning("initial numbers[c(", paste0(which(n_init[-1, 2] < 0), collapse = ","), ")] < 0")      
    #}
    
    # initialise
    n[, 1] <- n_init[, 2]
    
    # project
    for (y in 2:NTIME) {
        
        for (a in 2:NAGES) {
            n[a, y] <- n[a - 1, y - 1] * s[a - 1, y - 1] * (1 - sel[a - 1] * h) 
        }
        
        # plus group
        n[a, y] <- n[a, y] + n[a, y - 1] * s[a, y - 1] * (1 - sel[a] * h)
        
        # birth
        n[1, y] <- birth(y) * epsilon[y]
    }
    
    return(n)
}

.pdyn2_proj <- function(h, shape, survivorship, multiplier, fecundity, epsilon, maturity, selectivity, lambda, env) {
    
    NAGES <- get("NAGES", envir = env)
    NTIME <- get("NTIME", envir = env)
    
    age_mat <- as.integer(maturity)
    age_pat <- age_mat + 1L
    age_sel <- as.integer(selectivity)
    
    mat    <- c(rep(0, age_mat), rep(1, NAGES - age_mat))
    pat    <- c(rep(0, age_pat), rep(1, NAGES - age_pat))
    sel    <- c(rep(0, age_sel), rep(1, NAGES - age_sel))
    
    n <- array(dim = c(NAGES, NTIME))
    p <- numeric(NAGES)
    #S <- c(rep(survivorship[1] * multiplier, age_mat), rep(survivorship[1], NAGES - age_mat))
    S <- c(survivorship[1] * multiplier, rep(survivorship[1], NAGES - 1))
    
    s <- matrix(survivorship, ncol = NTIME, nrow = NAGES, byrow = TRUE)
    #s <- (sweep(s, 1, 1 - mat, "*") * multiplier) + sweep(s, 1, mat, "*")
    s[1,] <- s[1,] * multiplier
    
    birth <- function(y) {
        0.5 * sum(pat[-1] * n[-1,y]) * (b_eq + (b_max - b_eq) * (1 - (min(1, sum(n[-1,y])))^shape))
    }
    
    # set up unexploited 
    # equilibrium female
    # population
    p[1] <- 0.5
    for(a in 2:NAGES) {
        p[a] <- p[a - 1] * S[a - 1]
    }
    p[a] <- p[a] / (1 - S[a])
    
    # replacement birth rate
    # per female
    b_eq <- 1 / sum(pat * p)
    
    # maximum fecundity
    b_max <- 2 * (lambda^(age_mat + 1) - S[age_mat + 1] * lambda^(age_mat)) / prod(S[1:(age_mat + 1)])
    
    # population
    # at equilibrium
    k_prime <- b_eq * p
    
    # initial conditions
    # (sum(k1+) = 1)
    k <- k_prime / sum(k_prime[-1])
    
    # use iteration to calculate
    # initial age structure
    # and depletion
    n_init <- matrix(k, nrow = NAGES, ncol = 2)
    for (l in 2:1e3) {
        
        n_init[, 1] <- n_init[, 2]
        for(a in 2:NAGES) {
            n_init[a, 2] <- n_init[a - 1, 1] * S[a - 1] * (1 - sel[a - 1] * h)
        }
        n_init[a, 2] <- n_init[a, 2] + n_init[a, 1] * S[a] * (1 -  sel[a] * h)
        n_init[1, 2] <- 0.5 * sum(pat[-1] * n_init[-1, 2]) * (b_eq + (b_max - b_eq) * (1 - (min(1, sum(n_init[-1, 2])))^shape))
    }
    
    # check depletion
    if(sum(n_init[-1, 2]) > 1) {
        warning("initial depletion > 1")    
    }
    
    # check for negative values
    if(any(n_init[-1, 2] < 0)) {
        warning("initial numbers[c(", paste0(which(n_init[-1, 2] < 0), collapse = ","), ")] < 0")     
    }
    
    # initialise
    n[, 1] <- n_init[, 2]
    
    # project
    for (y in 2:NTIME) {
        
        for (a in 2:NAGES) {
            n[a, y] <- n[a - 1, y - 1] * s[a - 1, y - 1] * (1 - sel[a - 1] * h) 
        }
        
        # plus group
        n[a, y] <- n[a, y] + n[a, y - 1] * s[a, y - 1] * (1 - sel[a] * h)
        
        # birth
        n[1, y] <- birth(y) * epsilon[y]
    }
    
    return(n)
}

# fast-forward (deterministic)
.ff <- function(h, shape, survivorship, multiplier, fecundity, epsilon, maturity, selectivity, lambda, env) {
    
	# dimensions
	NAGES <- get("NAGES", envir = env)
	NTIME <- get("NTIME", envir = env)
	
	# vectors
	pat <- c(rep(0, maturity + 1), rep(1, NAGES - maturity - 1))
    sel <- c(rep(0, selectivity),  rep(1, NAGES - selectivity)) 
	
    # run dynamics
    N <- do.call(".pdyn_proj", list(h = h, shape = shape, survivorship = survivorship[1,], multiplier = multiplier, fecundity = fecundity, epsilon = epsilon[1,], maturity = maturity, selectivity = selectivity, lambda = lambda, env = env))
    
    # recent time
    recent_time <- ceiling((2 / 3) * NTIME):NTIME
    
    # equilibrium female captures
    captures <- mean(apply(sweep(N[, recent_time], 1, sel, "*") * h, 2, sum))
    
    # equilibrium depletion
    depletion <- mean(apply(N[-1, recent_time], 2, sum))
    
    # equilibrium per-capita birth
    production <- mean(N[1, recent_time] / apply(sweep(N[-1, recent_time], 1, pat[-1], "*"), 2, sum))
    
    # equilibrium growth rate
    lambda <- mean(apply(N[, recent_time], 2, sum) / apply(N[, recent_time - 1], 2, sum)) 
    
    # numbers
    numbers <- apply(N[, recent_time], 1, mean)
    
    # return dynamics
    return(list(captures = captures, depletion = depletion, production = production, lambda = lambda, numbers = numbers))
}

# fast-forward (stochastic)
.ff2 <- function(h, shape, survivorship, multiplier, fecundity, epsilon, maturity, selectivity, lambda, env) {

    # dimensions
	NAGES <- get("NAGES", envir = env)
	NTIME <- get("NTIME", envir = env)
	SITER <- get("SITER", envir = env)
	
	# vectors
	pat <- c(rep(0, maturity + 1), rep(1, NAGES - maturity - 1))
    sel <- c(rep(0, selectivity),  rep(1, NAGES - selectivity)) 
	
    # setup
    N <- array(dim = c(SITER, NAGES, NTIME))
    
    # run dynamics
    for (i in 1:SITER) {
        N[i,,] <- do.call(".pdyn2_proj", list(h = h, shape = shape, survivorship = survivorship[i,], multiplier = multiplier, fecundity = fecundity, epsilon = epsilon[i,], maturity = maturity, selectivity = selectivity, lambda = lambda, env = env))
    }
    
    # recent time
    recent_time <- ceiling((2 / 3) * NTIME):NTIME
    
    # equilibrium female captures
    captures <- mean(apply(sweep(N[,, recent_time], 2, sel, "*") * h, 1, sum) / length(recent_time))
    
    # equilibrium depletion
	depletion <- mean(apply(N[, -1, recent_time], 1, sum) / length(recent_time))
    
    # equilibrium per-capita birth
    production <- mean(apply(N[,1,recent_time], 1, sum) / apply(sweep(N[,-1, recent_time], 2, pat[-1], "*"), 1, sum))
    
    # equilibrium growth rate
    lambda <- mean(apply(N[,, recent_time], 3, sum) / apply(N[,, recent_time - 1], 3, sum)) 
    
    # numbers
    numbers <- apply(N[,, recent_time], 2, mean)
    
    # return dynamics
    return(list(captures = captures, depletion = depletion, production = production, lambda = lambda, numbers = numbers))
}


