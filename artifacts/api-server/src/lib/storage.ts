import fs from "fs";
import path from "path";
import { randomUUID } from "crypto";

export const STORAGE_DIR = path.join(process.cwd(), ".r-storage", "files");
const SESSIONS_FILE = path.join(process.cwd(), ".r-storage", "sessions.json");

export function ensureStorageDir(): void {
  fs.mkdirSync(STORAGE_DIR, { recursive: true });
  fs.mkdirSync(path.dirname(SESSIONS_FILE), { recursive: true });
}

export function getFilePath(fileId: string): string {
  return path.join(STORAGE_DIR, fileId);
}

export function fileExists(fileId: string): boolean {
  return fs.existsSync(getFilePath(fileId));
}

export async function saveFile(
  buffer: Buffer,
  originalName: string,
): Promise<{ fileId: string; filePath: string }> {
  ensureStorageDir();
  const ext = path.extname(originalName) || "";
  const fileId = randomUUID() + ext;
  const filePath = getFilePath(fileId);
  await fs.promises.writeFile(filePath, buffer);
  return { fileId, filePath };
}

export async function deleteFile(fileId: string): Promise<void> {
  const filePath = getFilePath(fileId);
  if (fs.existsSync(filePath)) {
    await fs.promises.unlink(filePath);
  }
}

// Session persistence
export interface StoredSession {
  id: string;
  type: string;
  status: string;
  createdAt: string;
  args: Record<string, unknown>;
  outputFileId: string | null;
  plotId: string | null;
  logs: string | null;
  error: string | null;
  inputFileId: string | null;
}

let sessionCache: StoredSession[] | null = null;

export function loadSessions(): StoredSession[] {
  if (sessionCache !== null) return sessionCache;
  try {
    ensureStorageDir();
    if (fs.existsSync(SESSIONS_FILE)) {
      const raw = fs.readFileSync(SESSIONS_FILE, "utf-8");
      sessionCache = JSON.parse(raw) as StoredSession[];
    } else {
      sessionCache = [];
    }
  } catch {
    sessionCache = [];
  }
  return sessionCache;
}

export function saveSessions(sessions: StoredSession[]): void {
  sessionCache = sessions;
  ensureStorageDir();
  fs.writeFileSync(SESSIONS_FILE, JSON.stringify(sessions, null, 2));
}

export function createSession(data: Omit<StoredSession, "id" | "createdAt">): StoredSession {
  const sessions = loadSessions();
  const session: StoredSession = {
    id: randomUUID(),
    createdAt: new Date().toISOString(),
    ...data,
  };
  sessions.unshift(session);
  saveSessions(sessions);
  return session;
}

export function getSession(id: string): StoredSession | undefined {
  return loadSessions().find((s) => s.id === id);
}

export function listSessions(): StoredSession[] {
  return loadSessions();
}

export function updateSession(id: string, updates: Partial<StoredSession>): StoredSession | undefined {
  const sessions = loadSessions();
  const idx = sessions.findIndex((s) => s.id === id);
  if (idx === -1) return undefined;
  sessions[idx] = { ...sessions[idx], ...updates };
  saveSessions(sessions);
  return sessions[idx];
}

export function deleteSessionRecord(id: string): StoredSession | undefined {
  const sessions = loadSessions();
  const idx = sessions.findIndex((s) => s.id === id);
  if (idx === -1) return undefined;
  const [removed] = sessions.splice(idx, 1);
  saveSessions(sessions);
  return removed;
}
