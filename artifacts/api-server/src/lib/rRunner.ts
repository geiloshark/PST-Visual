import { spawn } from "child_process";
import fs from "fs";
import path from "path";
import os from "os";
import { getFilePath, saveFile } from "./storage.js";

export interface RStatus {
  rAvailable: boolean;
  pstomInstalled: boolean;
  rVersion: string | null;
  pstomVersion: string | null;
}

/** Run an R script file and return stdout+stderr combined */
function runRScript(scriptPath: string, timeoutMs = 120_000): Promise<{ ok: boolean; output: string }> {
  return new Promise((resolve) => {
    const proc = spawn("Rscript", ["--vanilla", scriptPath], {
      env: { ...process.env, R_LIBS_USER: process.env.R_LIBS_USER ?? path.join(os.homedir(), "R-libs") },
    });
    let output = "";
    proc.stdout.on("data", (d: Buffer) => { output += d.toString(); });
    proc.stderr.on("data", (d: Buffer) => { output += d.toString(); });
    const timer = setTimeout(() => {
      proc.kill("SIGTERM");
      resolve({ ok: false, output: output + "\nTIMED OUT after " + timeoutMs / 1000 + "s" });
    }, timeoutMs);
    proc.on("close", (code) => {
      clearTimeout(timer);
      resolve({ ok: code === 0, output });
    });
    proc.on("error", (err) => {
      clearTimeout(timer);
      resolve({ ok: false, output: `Failed to start Rscript: ${err.message}` });
    });
  });
}

/** Write R code to a temp file, run it, then clean up */
async function runRCode(
  rCode: string,
  timeoutMs?: number,
): Promise<{ ok: boolean; output: string }> {
  const tmpDir = os.tmpdir();
  const scriptPath = path.join(tmpDir, `pstom_${Date.now()}_${Math.random().toString(36).slice(2)}.R`);
  try {
    await fs.promises.writeFile(scriptPath, rCode);
    return await runRScript(scriptPath, timeoutMs);
  } finally {
    fs.unlink(scriptPath, () => {});
  }
}

export async function checkRStatus(): Promise<RStatus> {
  const code = `
cat("R_ALIVE\\n")
tryCatch({
  v <- as.character(packageVersion("pstom"))
  cat(paste0("PSTOM_VERSION:", v, "\\n"))
}, error = function(e) {
  cat("PSTOM_NOT_FOUND\\n")
})
cat(paste0("R_VERSION:", R.version$major, ".", R.version$minor, "\\n"))
`;
  const { ok, output } = await runRCode(code, 15_000);
  if (!ok && !output.includes("R_ALIVE")) {
    return { rAvailable: false, pstomInstalled: false, rVersion: null, pstomVersion: null };
  }
  const rAlive = output.includes("R_ALIVE");
  const pstomInstalled = output.includes("PSTOM_VERSION:");
  const pstomMatch = output.match(/PSTOM_VERSION:(.+)/);
  const rVersionMatch = output.match(/R_VERSION:(.+)/);
  return {
    rAvailable: rAlive,
    pstomInstalled,
    rVersion: rVersionMatch ? rVersionMatch[1].trim() : null,
    pstomVersion: pstomMatch ? pstomMatch[1].trim() : null,
  };
}

export async function installPstom(): Promise<{ ok: boolean; output: string }> {
  const libPath = path.join(os.homedir(), "R-libs");
  fs.mkdirSync(libPath, { recursive: true });
  const code = `
.libPaths(c("${libPath.replace(/\\/g, "\\\\")}", .libPaths()))
options(repos = c(CRAN = "https://cloud.r-project.org"))

install_if_missing <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat(paste0("Installing ", pkg, "...\\n"))
    install.packages(pkg, lib = "${libPath.replace(/\\/g, "\\\\")}", dependencies = TRUE)
  } else {
    cat(paste0(pkg, " already installed\\n"))
  }
}

install_if_missing("remotes")
install_if_missing("TMB")
install_if_missing("RTMB")

cat("Installing pstom from GitHub...\\n")
remotes::install_github("geiloshark/PST-Visual", subdir = "pstom",
  lib = "${libPath.replace(/\\/g, "\\\\")}",
  dependencies = TRUE, upgrade = "never")
cat("INSTALL_COMPLETE\\n")
`;
  return runRCode(code, 600_000); // 10 min timeout for compilation
}

export async function runPdyn(
  inputFileId: string,
  args: {
    stochastic?: boolean | null;
    iterations?: number | null;
    time?: number | null;
    initialDepletion?: number | null;
    verbose?: boolean | null;
    useRmax?: boolean | null;
  },
): Promise<{ outputFileId: string; logs: string }> {
  const inputPath = getFilePath(inputFileId);
  if (!fs.existsSync(inputPath)) {
    throw new Error(`Input file not found: ${inputFileId}`);
  }

  const libPath = path.join(os.homedir(), "R-libs");
  const outputTmp = path.join(os.tmpdir(), `pdyn_out_${Date.now()}.rds`);

  const stochastic = args.stochastic == null ? "TRUE" : args.stochastic ? "TRUE" : "FALSE";
  const verbose = args.verbose == null ? "FALSE" : args.verbose ? "TRUE" : "FALSE";
  const useRmax = args.useRmax == null ? "TRUE" : args.useRmax ? "TRUE" : "FALSE";
  const iterations = args.iterations != null ? String(args.iterations) : "NULL";
  const time = args.time != null ? String(args.time) : "NULL";
  const initialDepletion = args.initialDepletion != null ? String(args.initialDepletion) : "NULL";

  const code = `
.libPaths(c("${libPath.replace(/\\/g, "\\\\")}", .libPaths()))
library(pstom)

input_obj <- readRDS("${inputPath.replace(/\\/g, "\\\\")}")

pdyn_args <- list(
  object = input_obj,
  stochastic = ${stochastic},
  verbose = ${verbose},
  use_rmax = ${useRmax}
)
if (!is.null(${iterations})) pdyn_args$iterations <- ${iterations}
if (!is.null(${time})) pdyn_args$time <- ${time}
if (!is.null(${initialDepletion})) pdyn_args$initial_depletion <- ${initialDepletion}

result <- do.call(pdyn, pdyn_args)

saveRDS(result, "${outputTmp.replace(/\\/g, "\\\\")}")
cat("PDYN_SUCCESS\\n")
`;

  const { ok, output } = await runRCode(code, 180_000);
  if (!ok || !output.includes("PDYN_SUCCESS")) {
    throw new Error(output || "R execution failed");
  }

  const buffer = await fs.promises.readFile(outputTmp);
  const { fileId: outputFileId } = await saveFile(buffer, "pdyn_output.rds");
  fs.unlink(outputTmp, () => {});

  return { outputFileId, logs: output };
}

export async function runDynplot(
  pdynOutputFileId: string,
  pars?: string | null,
): Promise<{ plotId: string; logs: string }> {
  const inputPath = getFilePath(pdynOutputFileId);
  if (!fs.existsSync(inputPath)) {
    throw new Error(`pdyn output file not found: ${pdynOutputFileId}`);
  }

  const libPath = path.join(os.homedir(), "R-libs");
  const plotTmp = path.join(os.tmpdir(), `dynplot_${Date.now()}.png`);

  // Parse pars: comma-separated → R character vector
  let parsR = "NULL";
  if (pars && pars.trim()) {
    const parsArr = pars
      .split(",")
      .map((p) => p.trim())
      .filter(Boolean)
      .map((p) => `"${p.replace(/"/g, '\\"')}"`)
      .join(", ");
    parsR = `c(${parsArr})`;
  }

  const code = `
.libPaths(c("${libPath.replace(/\\/g, "\\\\")}", .libPaths()))
library(pstom)
library(ggplot2)

input_obj <- readRDS("${inputPath.replace(/\\/g, "\\\\")}")

dynplot_args <- list(object = input_obj)
if (!is.null(${parsR})) dynplot_args$pars <- ${parsR}

p <- do.call(dynplot, dynplot_args)

ggsave("${plotTmp.replace(/\\/g, "\\\\")}", plot = p, width = 10, height = 7, dpi = 150, bg = "white")
cat("DYNPLOT_SUCCESS\\n")
`;

  const { ok, output } = await runRCode(code, 120_000);
  if (!ok || !output.includes("DYNPLOT_SUCCESS")) {
    throw new Error(output || "R execution failed");
  }

  const buffer = await fs.promises.readFile(plotTmp);
  const { fileId: plotId } = await saveFile(buffer, "dynplot.png");
  fs.unlink(plotTmp, () => {});

  return { plotId, logs: output };
}
