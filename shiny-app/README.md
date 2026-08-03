# pstom Shiny Interface

A standalone Shiny app for running `om`, `pdyn`, and `dynplot` from the
[pstom](https://github.com/geiloshark/PST-Visual/tree/main/pstom) R package
locally, without any server setup.

---

## Requirements

- **R ≥ 4.1**
- An internet connection for the initial package install

---

## Installation

Open an R session and run the following once:

```r
# 1. Install CRAN dependencies
install.packages(c("shiny", "ggplot2", "remotes"))

# 2. Install pstom from GitHub
remotes::install_github("geiloshark/PST-Visual", subdir = "pstom")
```

> **Note:** `pstom` depends on TMB/RTMB, which requires a C++ compiler.
> On **Windows** install [Rtools](https://cran.r-project.org/bin/windows/Rtools/)
> first. On **macOS** install the Xcode Command Line Tools (`xcode-select --install`).
> Linux users typically have `g++` already.

---

## Running the app

**Option A — from the R console:**

```r
shiny::runApp("path/to/shiny-app")
```

Replace `path/to/shiny-app` with the actual path to this directory, e.g.:

```r
shiny::runApp("~/PST-Visual/shiny-app")
```

**Option B — from RStudio:**

Open `app.R` and click the **Run App** button in the top-right corner of the
editor pane.

The app will open in your browser (or the RStudio viewer). If packages are
missing, it will print install instructions in the console and stop.

---

## Workflow

The app guides you through three steps on separate tabs. Each tab
automatically advances to the next on success.

### Tab 1 — om

Initialise an `om` S4 operating model object.

| Field | Default | Notes |
|-------|---------|-------|
| Ages | `0:20` | R integer vector — **minimum age must be 0** (e.g. `0:20`, `0:30`) |
| Samples | `100` | **Required.** Number of Monte Carlo samples |
| Time (years) | `100` | **Required.** Time horizon |
| Shape | (package default `1`) | Shape parameter |
| Seed | (random) | Set an integer for reproducible results |

Click **Initialise om**. On success the app moves to tab 2 and passes the
`om` object through automatically.

You can also **Download om RDS** to save the object for use elsewhere.

### Tab 2 — pdyn

Run a population dynamics projection from the `om` object.

| Field | Default | Notes |
|-------|---------|-------|
| Input | om from tab 1 | Or upload a pre-built `.rds` file |
| Iterations | `100` | Number of projection iterations |
| Time (years) | `50` | Projection time horizon |
| Initial depletion | `1.0` | Starting depletion level (0–1) |
| Stochastic | `TRUE` | Tick for stochastic projection |

Click **Run pdyn**. On success the app moves to tab 3.

**Download pdyn RDS** saves the output object.

### Tab 3 — dynplot

Plot the population dynamics results.

| Field | Default | Notes |
|-------|---------|-------|
| Parameters | `depletion` | Comma-separated — see valid values below |
| Input | pdyn from tab 2 | Or upload a pre-built `.rds` file |

**Valid `pars` values:**

| Value | Description |
|-------|-------------|
| `depletion` | Spawning stock depletion over time |
| `captures` | Total captures (catch) |
| `harvest_rate` | Harvest rate |

Multiple parameters can be combined, e.g. `depletion,captures`.

Click **Generate Plot** to render the figure. **Download PNG** saves it at
10 × 7 inches, 150 dpi.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `there is no package called 'pstom'` | Run the install step above |
| `object of type 'closure' is not subsettable` | Make sure you are passing an `om` RDS, not a plain R object |
| C++ compilation errors during install | Install Rtools (Windows) or Xcode CLT (macOS) |
| `min(ages) must equal 0` error | Change Ages to start from 0, e.g. `0:20` |
| Plot is blank | Check that `pars` contains only valid values: `depletion`, `captures`, `harvest_rate` |
