import { Router, type IRouter } from "express";
import multer from "multer";
import fs from "fs";
import path from "path";
import {
  GetSessionParams,
  DeleteSessionParams,
  RunOmBody,
  RunPdynBody,
  RunDynplotBody,
} from "@workspace/api-zod";
import {
  saveFile,
  getFilePath,
  fileExists,
  createSession,
  getSession,
  listSessions,
  deleteSessionRecord,
  updateSession,
  deleteFile,
} from "../../lib/storage.js";
import {
  checkRStatus,
  installPstom,
  runOm,
  runPdyn,
  runDynplot,
  getInstallState,
  installLogEmitter,
} from "../../lib/rRunner.js";

const router: IRouter = Router();

// Multer — store uploads in memory, then persist with saveFile()
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 200 * 1024 * 1024 }, // 200 MB
  fileFilter: (_req, file, cb) => {
    const allowed = [".rds", ".RDS", ".rda", ".RDA"];
    const ext = path.extname(file.originalname);
    if (allowed.includes(ext) || file.originalname === "") {
      cb(null, true);
    } else {
      cb(new Error("Only .rds / .rda files are accepted"));
    }
  },
});

// ── GET /r/status ─────────────────────────────────────────────────────────────
router.get("/r/status", async (_req, res): Promise<void> => {
  const status = await checkRStatus();

  const state = getInstallState();

  const state = getInstallState();
    const { fileId, filePath } = await saveFile(
      req.file.buffer,
      req.file.originalname || "upload.rds",
    );
    req.log.info({ fileId, size: req.file.size }, "RDS file uploaded");
    res.json({
      fileId,
      filename: req.file.originalname || "upload.rds",
      sizeBytes: req.file.size,
    });
    void filePath;
  },
);

// ── GET /r/files/:fileId ───────────────────────────────────────────────────────
router.get("/r/files/:fileId", (req, res): void => {
  const fileId = Array.isArray(req.params.fileId)
    ? req.params.fileId[0]
    : req.params.fileId;
  if (!fileId || !fileExists(fileId)) {
    res.status(404).json({ error: "File not found" });
    return;
  }
  const filePath = getFilePath(fileId);
  const ext = path.extname(fileId).toLowerCase();
  if (ext === ".png") {
    res.setHeader("Content-Type", "image/png");
  } else {
    res.setHeader("Content-Type", "application/octet-stream");
    res.setHeader(
      "Content-Disposition",
      `attachment; filename="${path.basename(fileId)}"`,
    );
  }
  res.sendFile(path.resolve(filePath));
});

// ── POST /r/om ────────────────────────────────────────────────────────────────
router.post("/r/om", async (req, res): Promise<void> => {
  const parsed = RunDynplotBody.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: parsed.error.message });
    return;
  }
  const { ages, samples, time, shape, seeds } = parsed.data;

  const session = deleteSessionRecord(params.data.id);

  req.log.info({ sessionId: session.id }, "Running pdyn");

  try {
    const { outputFileId, logs } = await runPdyn(fileId, {
      stochastic,
      iterations,
      time,
      initialDepletion,
      verbose,
      useRmax,
    });

    updateSession(session.id, { status: "success", outputFileId, logs });
    req.log.info({ sessionId: session.id, outputFileId }, "pdyn succeeded");
    res.json({ ...session, status: "success", outputFileId, logs });
  } catch (err) {
    const error = err instanceof Error ? err.message : String(err);
    updateSession(session.id, { status: "error", error });
    req.log.error({ sessionId: session.id, error }, "pdyn failed");
    res.status(500).json({ error });
  }
});

// ── POST /r/dynplot ────────────────────────────────────────────────────────────
router.post("/r/dynplot", async (req, res): Promise<void> => {
  const parsed = RunDynplotBody.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: parsed.error.message });
    return;
  }
  const { fileId, stochastic, iterations, time, initialDepletion, verbose, useRmax } =
    parsed.data;

  if (!fileExists(fileId)) {
    res.status(400).json({ error: `Uploaded file not found: ${fileId}. Please re-upload.` });
    return;
  }

  const session = deleteSessionRecord(params.data.id);

  req.log.info({ sessionId: session.id }, "Running pdyn");

  try {
    const { outputFileId, logs } = await runPdyn(fileId, {
      stochastic,
      iterations,
      time,
      initialDepletion,
      verbose,
      useRmax,
    });

    updateSession(session.id, { status: "success", outputFileId, logs });
    req.log.info({ sessionId: session.id, outputFileId }, "pdyn succeeded");
    res.json({ ...session, status: "success", outputFileId, logs });
  } catch (err) {
    const error = err instanceof Error ? err.message : String(err);
    updateSession(session.id, { status: "error", error });
    req.log.error({ sessionId: session.id, error }, "pdyn failed");
    res.status(500).json({ error });
  }
});

// ── POST /r/dynplot ────────────────────────────────────────────────────────────
router.post("/r/dynplot", async (req, res): Promise<void> => {
  const parsed = RunDynplotBody.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: parsed.error.message });
    return;
  }
  const { sessionId, pars } = parsed.data;

  const pdynSession = getSession(sessionId);
  if (!pdynSession) {
    res.status(400).json({ error: `Session not found: ${sessionId}` });
    return;
  }
  if (pdynSession.status !== "success" || !pdynSession.outputFileId) {
    res.status(400).json({ error: "Referenced session did not complete successfully" });
    return;
  }

  const session = deleteSessionRecord(params.data.id);

  req.log.info({ sessionId: session.id }, "Running dynplot");

  try {
    const { plotId, logs } = await runDynplot(pdynSession.outputFileId, pars);
    updateSession(session.id, { status: "success", plotId, logs });
    req.log.info({ sessionId: session.id, plotId }, "dynplot succeeded");
    res.json({ ...session, status: "success", plotId, logs });
  } catch (err) {
    const error = err instanceof Error ? err.message : String(err);
    updateSession(session.id, { status: "error", error });
    req.log.error({ sessionId: session.id, error }, "dynplot failed");
    res.status(500).json({ error });
  }
});

// ── GET /r/sessions ────────────────────────────────────────────────────────────
router.get("/r/sessions", (_req, res): void => {
  res.json(listSessions());
});

// ── GET /r/sessions/:id ────────────────────────────────────────────────────────
router.get("/r/sessions/:id", (req, res): void => {
  const params = DeleteSessionParams.safeParse(req.params);
  if (!params.success) {
    res.status(400).json({ error: params.error.message });
    return;
  }
  const session = deleteSessionRecord(params.data.id);
  if (!session) {
    res.status(404).json({ error: "Session not found" });
    return;
  }
  res.json(session);
});

// ── DELETE /r/sessions/:id ─────────────────────────────────────────────────────
router.delete("/r/sessions/:id", async (req, res): Promise<void> => {
  const params = DeleteSessionParams.safeParse(req.params);
  if (!params.success) {
    res.status(400).json({ error: params.error.message });
    return;
  }
  const session = deleteSessionRecord(params.data.id);
  if (!session) {
    res.status(404).json({ error: "Session not found" });
    return;
  }
  // Clean up associated files
  if (session.outputFileId) await deleteFile(session.outputFileId);
  if (session.plotId) await deleteFile(session.plotId);
  // Don't delete inputFileId — it's the original upload shared across sessions
  req.log.info({ sessionId: session.id }, "Session deleted");
  res.sendStatus(204);
});

export default router;

  const heartbeat = setInterval(() => {
    res.write(`: heartbeat\n\n`);
  }, 15_000);

  const onDone = ({ ok }: { ok: boolean }) => {
    clearInterval(heartbeat);
    res.write(`data: ${JSON.stringify({ type: "done", ok })}\n\n`);
    res.end();
    installLogEmitter.off("log", onLog);
    installLogEmitter.off("done", onDone);
  };

  const onLog = (text: string) => {
    res.write(`data: ${JSON.stringify({ type: "log", text })}\n\n`);
  };
