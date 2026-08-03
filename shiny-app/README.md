# pstom Shiny Interface

A local Shiny app for running `om`, `pdyn`, and `dynplot` from the **pstom** R package.

## Requirements

- R ≥ 4.0
- The following R packages:

```r
# Install from CRAN
install.packages(c("shiny", "ggplot2", "remotes"))

# Install pstom from GitHub
remotes::install_github("geiloshark/PST-Visual", subdir = "pstom")
```

## Running the app

```r
shiny::runApp("path/to/shiny-app")
```

Or open `app.R` in RStudio and click **Run App**.

## Workflow

The app guides you through three steps, each on its own tab:

### Tab 1 — om
Initialise an `om` S4 operating model object.

| Field | Default | Notes |
|-------|---------|-------|
| Ages | `1:20` | Any R integer vector expression |
| Samples | (package default) | Monte Carlo samples |
| Time | (package default) | Time horizon in years |
| Shape | (package default) | Shape parameter |
| Seed | (random) | Set for reproducible results |

Click **Initialise om** → the app automatically switches to tab 2.  
You can also **Download om RDS** to save the object for later use.

### Tab 2 — pdyn
Run population dynamics projection.

- **Input**: use the `om` object from tab 1, or upload a pre-built `.rds` file
- Configure iterations, time horizon, initial depletion, and stochastic flags
- Click **Run pdyn** → the app automatically switches to tab 3
- **Download pdyn RDS** to save the output

### Tab 3 — dynplot
Plot the population dynamics results.

- **pars**: comma-separated parameter names to plot (e.g. `N,B,F`)
  - `N` — Numbers
  - `B` — Biomass  
  - `F` — Fishing Mortality
- Click **Generate Plot** to render the ggplot2 figure
- **Download PNG** to save the plot (10 × 7 in, 150 dpi)
