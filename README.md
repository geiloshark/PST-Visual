# PST-Visual

Tools for the **pstom** operating model — an R package for evaluating protected-species threshold reference points, and a standalone Shiny app for running it locally.

---

## Contents

| Path | What it is |
|------|-----------|
| [`pstom/`](pstom/) | R package (simulation model, reference-point estimation) |
| [`shiny-app/`](shiny-app/) | Standalone Shiny app |

---

## pstom R package

Simulation model for the evaluation of protected-species reference points. Implements a three-step workflow:

1. **`om()`** — initialise an S4 operating model object (ages, samples, time horizon, shape)
2. **`pdyn()`** — run a stochastic population-dynamics projection from an `om` object
3. **`dynplot()`** — plot projection results (depletion, captures, harvest rate)

### Install

```r
# Requires a C++ compiler for TMB/RTMB
# Windows: install Rtools  https://cran.r-project.org/bin/windows/Rtools/
# macOS:   xcode-select --install

remotes::install_github("geiloshark/PST-Visual", subdir = "pstom")
```

### Quick start

```r
library(pstom)

# 1 — operating model
model <- om(ages = 0:20, samples = 100, time = 100)

# 2 — population dynamics
proj <- pdyn(model)

# 3 — plot
dynplot(proj, pars = "depletion")
```

---

## Shiny app

A self-contained three-tab Shiny app. Runs entirely in a local R session — no server or Node.js required.

### Requirements

- R ≥ 4.1
- Internet connection for the initial install

### Install

```r
install.packages(c("shiny", "ggplot2", "remotes"))
remotes::install_github("geiloshark/PST-Visual", subdir = "pstom")
```

### Run

```r
shiny::runApp("shiny-app")
```

See [`shiny-app/README.md`](shiny-app/README.md) for full field-level documentation and troubleshooting.

---

## Author

Charles T T Edwards — [cescapecs@gmail.com](mailto:cescapecs@gmail.com)
