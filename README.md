# PST-Visual

Tools for the **pstom** operating model — an R package for evaluating protected-species threshold reference points, a React web interface, and a standalone Shiny app.

---

## Contents

| Path | What it is |
|------|-----------|
| [`pstom/`](pstom/) | R package (simulation model, reference-point estimation) |
| [`artifacts/pstom-ui/`](artifacts/pstom-ui/) | React + Vite web interface |
| [`artifacts/api-server/`](artifacts/api-server/) | Node/Express API — spawns R child processes |
| [`shiny-app/`](shiny-app/) | Standalone Shiny app (local use, no server needed) |

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

## Web interface

A browser-based UI that runs `om`, `pdyn`, and `dynplot` through a REST API backed by a live R session. Sessions are saved with their outputs so results can be revisited without re-running.

### Features

- **om tab** — configure and initialise an operating model, or upload an existing `om` RDS to pre-fill all form fields and inspect `@settings` slot values (ref_points, projection, cv, qn, bias)
- **pdyn tab** — run a projection from the current om object or any uploaded RDS
- **dynplot tab** — render and download plots inline
- Session history panel with per-session input/output log
- Server-sent event stream for real-time pstom installation progress

### Stack

- Frontend: React 19, Vite, Tailwind CSS, shadcn/ui, React Query
- API: Express 5, contract-first (OpenAPI → Orval codegen → React Query hooks + Zod schemas)
- R: R 4.5, pstom installed on first use to `~/R-libs`
- Runtime storage: flat JSON sessions + binary files under `.r-storage/`

### Running locally (monorepo)

```bash
# Install Node dependencies
pnpm install

# Start both services (each in its own terminal)
pnpm --filter @workspace/api-server run dev   # API on port 8080
pnpm --filter @workspace/pstom-ui    run dev   # UI  on assigned port
```

On first use, open the app and click **Install pstom** in the status bar. TMB/RTMB compilation takes 5–15 minutes; progress streams live to the browser.

### API routes

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/r/status` | R availability and pstom version |
| `POST` | `/api/r/install` | Trigger pstom installation |
| `GET` | `/api/r/install/stream` | SSE stream of install output |
| `POST` | `/api/r/upload` | Upload an RDS file → returns `fileId` |
| `POST` | `/api/r/om` | Run `om()` |
| `POST` | `/api/r/om/inspect` | Inspect slots of an uploaded om RDS |
| `POST` | `/api/r/pdyn` | Run `pdyn()` |
| `POST` | `/api/r/dynplot` | Run `dynplot()` → PNG |
| `GET` | `/api/r/files/:fileId` | Download a stored file |
| `GET` | `/api/r/sessions` | List all sessions |
| `GET` | `/api/r/sessions/:id` | Get a single session |
| `DELETE` | `/api/r/sessions/:id` | Delete a session |

---

## Shiny app

A self-contained three-tab Shiny app — no server, no Node.js. Runs entirely in a local R session.

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

## Repository structure

```
PST-Visual/
├── pstom/                  R package source
│   ├── R/                  Function and class definitions
│   │   ├── om-class.R      om S4 class
│   │   ├── om.R            om() constructor
│   │   ├── pdyn.R          pdyn() projection
│   │   └── dynplot.R       dynplot() plotting
│   └── DESCRIPTION
│
├── artifacts/
│   ├── pstom-ui/           React/Vite frontend
│   │   └── src/
│   │       ├── components/ OmForm, PdynForm, DynplotForm, …
│   │       └── pages/      Workspace layout
│   └── api-server/         Express API
│       └── src/
│           ├── lib/
│           │   ├── rRunner.ts   R process orchestration
│           │   └── storage.ts   File + session persistence
│           └── routes/r/    All /api/r/* handlers
│
├── shiny-app/
│   └── app.R               Standalone Shiny interface
│
└── lib/
    ├── api-spec/            OpenAPI spec + Orval config
    ├── api-client-react/    Generated React Query hooks
    └── api-zod/             Generated Zod schemas
```

---

## Deployment

The web interface requires a **Reserved VM** deployment (not autoscale) because the Nix `r-4.5` module and long-running R compilation are not compatible with autoscale cold-starts.

---

## Author

Charles T T Edwards — [cescapecs@gmail.com](mailto:cescapecs@gmail.com)
