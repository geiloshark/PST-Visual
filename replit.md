# pstom R Interface

A web UI for running functions from the [pstom R package](https://github.com/geiloshark/PST-Visual) (subdir: `pstom`). Scientists upload an S4 object (.rds file), fill in arguments for `pdyn` and `dynplot`, run the analysis, view generated ggplot2 plots inline, and download outputs.

## Run & Operate

- `pnpm --filter @workspace/api-server run dev` — run the API server (port 8080)
- `pnpm --filter @workspace/pstom-ui run dev` — run the React frontend (port auto-assigned)
- `pnpm run typecheck` — full typecheck across all packages
- `pnpm run build` — typecheck + build all packages
- `pnpm --filter @workspace/api-spec run codegen` — regenerate API hooks and Zod schemas from the OpenAPI spec

## Stack

- pnpm workspaces, Node.js 24, TypeScript 5.9
- Frontend: React + Vite + Tailwind CSS + shadcn/ui
- API: Express 5 (contract-first OpenAPI → Orval codegen)
- R: R 4.5.2, pstom package (GitHub: geiloshark/PST-Visual, subdir: pstom)
- Validation: Zod (zod/v4), Orval-generated hooks

## Where things live

- `artifacts/pstom-ui/` — React frontend
- `artifacts/api-server/src/routes/r/` — R execution routes (upload, pdyn, dynplot, sessions, file serving)
- `artifacts/api-server/src/lib/rRunner.ts` — R process spawning, function execution
- `artifacts/api-server/src/lib/storage.ts` — file storage + JSON session persistence
- `.r-storage/` — runtime directory: uploaded .rds files, output .rds files, PNG plots, sessions.json
- `lib/api-spec/openapi.yaml` — API contract source of truth
- `.r-storage/install.log` — R package installation log

## Architecture decisions

- File upload endpoint (`POST /api/r/upload`) uses multer and is **not** in the OpenAPI spec to avoid `File`/`Blob` Node.js type issues from Orval codegen; it's a raw Express route.
- R scripts are embedded as template literal strings in `rRunner.ts` and written to temp files per invocation — avoids path issues when esbuild bundles the server.
- Sessions are stored as a JSON file (`.r-storage/sessions.json`) rather than the DB — sessions reference binary files on disk, and the tool is a single-user analysis environment.
- R packages are installed to `~/R-libs` (user library) on first setup; the `POST /api/r/install` endpoint triggers installation; `/api/r/status` polls availability.
- `dynplot` always takes the output .rds of a `pdyn` session — the UI auto-populates the session ID.

## R package setup

pstom depends on TMB and RTMB (compiled C++ packages). On first use:
1. Open the app — the R status badge will show "pstom not installed"
2. Click "Install pstom" — this triggers background compilation (5–15 min)
3. Poll `/api/r/status` or refresh until pstomInstalled = true

The install script also lives at `.r-storage/install.log` for debugging.

## User preferences

_Populate as you build._

## Gotchas

- R pdyn/dynplot calls can take 10–120 seconds; the API uses a 3-minute timeout
- After server restart, in-memory file IDs still exist on disk but the session list reloads from `.r-storage/sessions.json`
- The `pars` argument to `dynplot` is comma-separated in the UI (e.g. `N,B,F`) — the backend splits it into an R character vector
