---
name: pstom source facts
description: Key constraints discovered from reading the pstom R package source (geiloshark/PST-Visual, now public)
---

# pstom source facts

**Why:** Package source was private initially; constraints were discovered by reading om-class.R, om.R, pdyn.R, dynplot.R once the repo was made public.

## om() constructor

```r
om <- function(ages, harvest_function = .harvest_rate, ...) new('om', ages, harvest_function, ...)
```

S4 initialiser (`setMethod("initialize", "om", ...)`) enforces:
- `ages`: required; **minimum age must be 0** (stops with error if min > 0)
- `samples`: **required** (stops with "samples is a required input" if missing)
- `time`: **required** (stops with "time is a required input" if missing)
- `shape`: optional, defaults to 1
- `seeds`: optional

**How to apply:** Always pass `ages` starting from 0 (e.g. `0:20`). Always pass `samples` and `time` — never leave them NULL/unset.

## pdyn()

```r
setMethod("pdyn", signature = "om", function(object, stochastic, iterations, time,
  initial_depletion = 1.0, verbose = FALSE, use_rmax = TRUE, ...) { ... })
```

- `initial_depletion` default is **1.0** (not 0.1)
- `stochastic`, `iterations`, `time` have no R defaults — they are validated/defaulted inside `.check_pdyn()`

## dynplot()

```r
dynplot.om <- function(object, ..., pars = 'depletion', labels) { ... }
stopifnot(all(pars %in% c("depletion", "harvest_rate", "captures")))
```

Valid `pars` values: `"depletion"`, `"harvest_rate"`, `"captures"` — **not** N/B/F.
Default is `"depletion"`.

## GitHub

- Repo: `https://github.com/geiloshark/PST-Visual`
- Web interface lives on the `web-interface` branch (separate from the R package on `main`)
