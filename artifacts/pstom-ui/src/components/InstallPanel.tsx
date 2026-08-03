import React, { useCallback, useEffect, useRef, useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { getGetRStatusQueryKey } from '@workspace/api-client-react';
import { Download, Loader2, CheckCircle2, XCircle, Terminal, ChevronDown, ChevronUp } from 'lucide-react';

type InstallPhase = 'idle' | 'running' | 'success' | 'failed';

interface InstallPanelProps {
  /** Whether R itself is available (controls whether install is even possible) */
  rAvailable: boolean;
}

export function InstallPanel({ rAvailable }: InstallPanelProps) {
  const queryClient = useQueryClient();
  const [phase, setPhase] = useState<InstallPhase>('idle');
  const [logs, setLogs] = useState('');
  const [logsExpanded, setLogsExpanded] = useState(false);
  const logEndRef = useRef<HTMLDivElement>(null);
  const esRef = useRef<EventSource | null>(null);

  // Auto-scroll the log terminal as new lines arrive
  useEffect(() => {
    if (logsExpanded && logEndRef.current) {
      logEndRef.current.scrollIntoView({ behavior: 'smooth' });
    }
  }, [logs, logsExpanded]);

  // On unmount, close any open SSE connection
  useEffect(() => {
    return () => {
      esRef.current?.close();
    };
  }, []);

  const connectStream = useCallback(() => {
    // Close any previous connection
    esRef.current?.close();

    const es = new EventSource('/api/r/install/stream');
    esRef.current = es;

    es.onmessage = (evt) => {
      try {
        const msg = JSON.parse(evt.data) as { type: string; text?: string; ok?: boolean };
        if (msg.type === 'log' && msg.text) {
          setLogs((prev) => prev + msg.text);
        } else if (msg.type === 'done') {
          setPhase(msg.ok ? 'success' : 'failed');
          es.close();
          esRef.current = null;
          // Invalidate the R status query so the badge refreshes immediately
          queryClient.invalidateQueries({ queryKey: getGetRStatusQueryKey() });
        }
      } catch {
        // ignore malformed events
      }
    };

    es.onerror = () => {
      // SSE connection lost — treat as failure only if we're still running
      setPhase((prev) => (prev === 'running' ? 'failed' : prev));
      setLogs((prev) => prev + '\n[Connection to install stream lost]\n');
      es.close();
      esRef.current = null;
    };
  }, [queryClient]);

  const handleInstall = useCallback(async () => {
    if (phase === 'running') return;

    setPhase('running');
    setLogs('');
    setLogsExpanded(true);

    try {
      await fetch('/api/r/install', { method: 'POST' });
    } catch {
      setLogs('Failed to start installation.\n');
      setPhase('failed');
      return;
    }

    connectStream();
  }, [phase, connectStream]);

  // If a previous install was already running when the component mounts, reconnect
  useEffect(() => {
    let cancelled = false;

    fetch('/api/r/install/status')
      .then((r) => r.json())
      .then((state: { status: InstallPhase; output: string }) => {
        if (cancelled) return;
        if (state.status === 'running') {
          setPhase('running');
          setLogs(state.output ?? '');
          setLogsExpanded(true);
          connectStream();
        } else if (state.status === 'success' || state.status === 'failed') {
          setPhase(state.status);
          setLogs(state.output ?? '');
        }
      })
      .catch(() => {/* ignore */});

    return () => { cancelled = true; };
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  if (!rAvailable) return null;

  return (
    <div className="rounded-lg border bg-card shadow-sm overflow-hidden">
      {/* Header row */}
      <div className="flex items-center justify-between gap-3 px-4 py-3 border-b bg-muted/30">
        <div className="flex items-center gap-2">
          <Terminal className="h-4 w-4 text-muted-foreground" />
          <span className="text-sm font-medium">pstom Package</span>
          <StatusPill phase={phase} />
        </div>

        <button
          onClick={handleInstall}
          disabled={phase === 'running' || !rAvailable}
          className="inline-flex items-center gap-1.5 rounded-md px-3 py-1.5 text-xs font-medium
            bg-primary text-primary-foreground hover:bg-primary/90 transition-colors
            disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {phase === 'running' ? (
            <>
              <Loader2 className="h-3 w-3 animate-spin" />
              Installing…
            </>
          ) : (
            <>
              <Download className="h-3 w-3" />
              {phase === 'failed' ? 'Retry Install' : 'Install pstom'}
            </>
          )}
        </button>
      </div>

      {/* Description */}
      {phase === 'idle' && (
        <p className="px-4 py-3 text-xs text-muted-foreground leading-relaxed">
          The <span className="font-mono">pstom</span> package (with TMB/RTMB dependencies) is
          required to run analyses. Installation compiles C++ code and may take 5–15 minutes.
        </p>
      )}

      {/* Log terminal — shown once install starts */}
      {(phase !== 'idle' || logs) && (
        <div>
          <button
            onClick={() => setLogsExpanded((v) => !v)}
            className="w-full flex items-center justify-between px-4 py-2 text-[11px] text-muted-foreground
              hover:bg-muted/20 transition-colors border-t font-mono"
          >
            <span>Installation log</span>
            {logsExpanded ? <ChevronUp className="h-3 w-3" /> : <ChevronDown className="h-3 w-3" />}
          </button>

          {logsExpanded && (
            <div className="bg-[#0d1117] max-h-64 overflow-y-auto border-t">
              <pre className="p-3 text-[11px] font-mono text-green-400 whitespace-pre-wrap break-words leading-relaxed">
                {logs || '(waiting for output…)'}
                <div ref={logEndRef} />
              </pre>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

function StatusPill({ phase }: { phase: InstallPhase }) {
  switch (phase) {
    case 'running':
      return (
        <span className="inline-flex items-center gap-1 rounded-full bg-blue-500/15 px-2 py-0.5 text-[10px] font-medium text-blue-600 dark:text-blue-400">
          <Loader2 className="h-2.5 w-2.5 animate-spin" />
          Installing
        </span>
      );
    case 'success':
      return (
        <span className="inline-flex items-center gap-1 rounded-full bg-green-500/15 px-2 py-0.5 text-[10px] font-medium text-green-600 dark:text-green-400">
          <CheckCircle2 className="h-2.5 w-2.5" />
          Installed
        </span>
      );
    case 'failed':
      return (
        <span className="inline-flex items-center gap-1 rounded-full bg-red-500/15 px-2 py-0.5 text-[10px] font-medium text-red-600 dark:text-red-400">
          <XCircle className="h-2.5 w-2.5" />
          Failed
        </span>
      );
    default:
      return (
        <span className="inline-flex items-center gap-1 rounded-full bg-orange-500/15 px-2 py-0.5 text-[10px] font-medium text-orange-600 dark:text-orange-400">
          Not installed
        </span>
      );
  }
}
