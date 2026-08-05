import React, { useRef, useState } from 'react';
import { useWorkspace } from '../WorkspaceContext';
import { useRunOm, getListSessionsQueryKey } from '@workspace/api-client-react';
import { useQueryClient } from '@tanstack/react-query';
import { Card, CardContent, CardDescription, CardHeader, CardTitle, Button, Input, Label, Separator } from './ui/core';
import { Layers, Loader2, CheckCircle2, Upload, X, AlertCircle } from 'lucide-react';

interface OmSettings {
  ref_points: { stochastic: boolean | null; iterations: number | null; time: number | null };
  projection: { stochastic: boolean | null; iterations: number | null; time: number | null };
  cv: { survivorship: number; birth: number; numbers: number; harvest_rate: number; capture: number; rmax: number };
  qn: { numbers_lo: number; numbers_hi: number | null };
  bias: { numbers: number; harvest_rate: number; capture: number; rmax: number };
}

interface OmSlots {
  ages: string;
  samples: number;
  time: number;
  shape: number | null;
  seeds: number | null;
  settings: OmSettings | null;
}

/** Small key=value pair for the settings table */
function SettingsRow({ label, value }: { label: string; value: string | number | boolean | null | undefined }) {
  const display =
    value === null || value === undefined ? '—'
    : typeof value === 'boolean' ? (value ? 'true' : 'false')
    : String(value);
  return (
    <div className="flex justify-between gap-2 py-0.5">
      <span className="text-muted-foreground">{label}</span>
      <span className="font-mono text-right">{display}</span>
    </div>
  );
}

function SettingsGroup({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div>
      <p className="text-[10px] font-semibold uppercase tracking-wider text-muted-foreground mb-1">{title}</p>
      <div className="text-xs space-y-0">{children}</div>
    </div>
  );
}

type UploadState =
  | { status: 'idle' }
  | { status: 'uploading' }
  | { status: 'inspecting' }
  | { status: 'loaded'; fileId: string; filename: string; slots: OmSlots }
  | { status: 'error'; message: string };

export function OmForm() {
  const { setUploadedFile, setActiveTab } = useWorkspace();
  const queryClient = useQueryClient();
  const runOm = useRunOm();
  const fileInputRef = useRef<HTMLInputElement>(null);

  const [ages, setAges] = useState('0:20');
  const [samples, setSamples] = useState<string>('100');
  const [time, setTime] = useState<string>('100');
  const [shape, setShape] = useState<string>('');
  const [seeds, setSeeds] = useState<string>('');

  const [uploadState, setUploadState] = useState<UploadState>({ status: 'idle' });
  const [lastOutputFileId, setLastOutputFileId] = useState<string | null>(null);

  // ── File upload + inspect ────────────────────────────────────────────────────
  const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    // Reset so the same file can be re-selected after clearing
    e.target.value = '';

    setUploadState({ status: 'uploading' });
    setLastOutputFileId(null);

    try {
      // 1. Upload
      const formData = new FormData();
      formData.append('file', file);
      const uploadRes = await fetch('/api/r/upload', { method: 'POST', body: formData });
      if (!uploadRes.ok) {
        const err = await uploadRes.json().catch(() => ({}));
        throw new Error((err as { error?: string }).error ?? `Upload failed (${uploadRes.status})`);
      }
      const { fileId } = (await uploadRes.json()) as { fileId: string };

      setUploadState({ status: 'inspecting' });

      // 2. Inspect slots
      const inspectRes = await fetch('/api/r/om/inspect', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ fileId }),
      });
      if (!inspectRes.ok) {
        const err = await inspectRes.json().catch(() => ({}));
        throw new Error((err as { error?: string }).error ?? `Inspect failed (${inspectRes.status})`);
      }
      const slots = (await inspectRes.json()) as OmSlots;

      // 3. Populate fields
      setAges(slots.ages);
      setSamples(String(slots.samples));
      setTime(String(slots.time));
      setShape(slots.shape != null ? String(slots.shape) : '');
      setSeeds(slots.seeds != null ? String(slots.seeds) : '');

      // 4. Make available for pdyn immediately
      setUploadedFile(fileId, file.name);

      setUploadState({ status: 'loaded', fileId, filename: file.name, slots });
    } catch (err) {
      setUploadState({
        status: 'error',
        message: err instanceof Error ? err.message : String(err),
      });
    }
  };

  const clearUpload = () => {
    setUploadState({ status: 'idle' });
  };

  // ── Om initialise ────────────────────────────────────────────────────────────
  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!ages.trim()) return;

    setLastOutputFileId(null);

    runOm.mutate(
      {
        data: {
          ages: ages.trim(),
          samples: samples !== '' ? Number(samples) : undefined,
          time: time !== '' ? Number(time) : undefined,
          shape: shape !== '' ? Number(shape) : undefined,
          seeds: seeds !== '' ? Number(seeds) : undefined,
        }
      },
      {
        onSuccess: (session) => {
          queryClient.invalidateQueries({ queryKey: getListSessionsQueryKey() });
          if (session.outputFileId) {
            setLastOutputFileId(session.outputFileId);
            setUploadedFile(session.outputFileId, 'om_output.rds');
            setActiveTab('pdyn');
          }
        }
      }
    );
  };

  const isWorking = runOm.isPending || uploadState.status === 'uploading' || uploadState.status === 'inspecting';

  return (
    <Card className="h-full flex flex-col">
      <CardHeader>
        <CardTitle className="text-xl">om</CardTitle>
        <CardDescription>Initialise operating model S4 object</CardDescription>
      </CardHeader>
      <CardContent className="flex-1 flex flex-col">
        {/* ── Upload area ─────────────────────────────────────────────────── */}
        <input
          ref={fileInputRef}
          type="file"
          accept=".rds,.RDS"
          className="hidden"
          onChange={handleFileChange}
        />

        {uploadState.status === 'idle' && (
          <button
            type="button"
            onClick={() => fileInputRef.current?.click()}
            className="mb-4 w-full rounded-md border-2 border-dashed border-muted-foreground/25 px-4 py-3 text-sm text-muted-foreground hover:border-muted-foreground/50 hover:text-foreground transition-colors flex items-center justify-center gap-2"
          >
            <Upload className="h-4 w-4" />
            Upload existing om object (.rds) to pre-fill fields
          </button>
        )}

        {(uploadState.status === 'uploading' || uploadState.status === 'inspecting') && (
          <div className="mb-4 w-full rounded-md border border-border px-4 py-3 text-sm text-muted-foreground flex items-center gap-2">
            <Loader2 className="h-4 w-4 animate-spin shrink-0" />
            {uploadState.status === 'uploading' ? 'Uploading…' : 'Reading slots from object…'}
          </div>
        )}

        {uploadState.status === 'loaded' && (
          <div className="mb-4 space-y-2">
            {/* ── Loaded banner ── */}
            <div className="rounded-md bg-blue-50 dark:bg-blue-950/20 border border-blue-200 dark:border-blue-900/50 px-4 py-3 text-sm text-blue-800 dark:text-blue-400 flex items-start gap-2">
              <CheckCircle2 className="h-4 w-4 shrink-0 mt-0.5" />
              <div className="flex-1 min-w-0">
                <p className="font-medium truncate">{uploadState.filename}</p>
                <p className="text-xs mt-0.5 text-blue-600 dark:text-blue-500">Fields populated from object slots · ready for pdyn</p>
              </div>
              <div className="flex items-center gap-1 shrink-0">
                <button
                  type="button"
                  onClick={() => setActiveTab('pdyn')}
                  className="text-xs font-medium underline underline-offset-2 hover:no-underline"
                >
                  Go to pdyn
                </button>
                <button type="button" onClick={clearUpload} className="ml-2 hover:text-blue-600">
                  <X className="h-3.5 w-3.5" />
                </button>
              </div>
            </div>

            {/* ── Settings panel ── always shown when loaded */}
            {(() => {
              const s = uploadState.slots.settings;
              return (
              <div className="rounded-md border border-border bg-muted/30 px-4 py-3 space-y-3">
                <p className="text-xs font-semibold text-foreground">@settings</p>

                <SettingsGroup title="ref_points">
                  <SettingsRow label="stochastic" value={s?.ref_points.stochastic ?? null} />
                  <SettingsRow label="iterations"  value={s?.ref_points.iterations ?? null} />
                  <SettingsRow label="time"        value={s?.ref_points.time ?? null} />
                </SettingsGroup>

                <SettingsGroup title="projection">
                  <SettingsRow label="stochastic" value={s?.projection.stochastic ?? null} />
                  <SettingsRow label="iterations"  value={s?.projection.iterations ?? null} />
                  <SettingsRow label="time"        value={s?.projection.time ?? null} />
                </SettingsGroup>

                <SettingsGroup title="cv">
                  <SettingsRow label="survivorship" value={s?.cv.survivorship ?? null} />
                  <SettingsRow label="birth"        value={s?.cv.birth ?? null} />
                  <SettingsRow label="numbers"      value={s?.cv.numbers ?? null} />
                  <SettingsRow label="harvest_rate" value={s?.cv.harvest_rate ?? null} />
                  <SettingsRow label="capture"      value={s?.cv.capture ?? null} />
                  <SettingsRow label="rmax"         value={s?.cv.rmax ?? null} />
                </SettingsGroup>

                <SettingsGroup title="qn">
                  <SettingsRow label="numbers lo" value={s?.qn.numbers_lo ?? null} />
                  <SettingsRow label="numbers hi" value={s?.qn.numbers_hi ?? null} />
                </SettingsGroup>

                <SettingsGroup title="bias">
                  <SettingsRow label="numbers"      value={s?.bias.numbers ?? null} />
                  <SettingsRow label="harvest_rate" value={s?.bias.harvest_rate ?? null} />
                  <SettingsRow label="capture"      value={s?.bias.capture ?? null} />
                  <SettingsRow label="rmax"         value={s?.bias.rmax ?? null} />
                </SettingsGroup>
              </div>
              );
            })()}
          </div>
        )}

        {uploadState.status === 'error' && (
          <div className="mb-4 rounded-md bg-destructive/10 border border-destructive/20 px-4 py-3 text-sm text-destructive flex items-start gap-2">
            <AlertCircle className="h-4 w-4 shrink-0 mt-0.5" />
            <div className="flex-1 min-w-0">
              <p className="font-medium">Upload failed</p>
              <p className="text-xs mt-0.5 break-all">{uploadState.message}</p>
            </div>
            <button type="button" onClick={clearUpload} className="shrink-0 hover:opacity-70">
              <X className="h-3.5 w-3.5" />
            </button>
          </div>
        )}

        <Separator className="mb-4" />

        {/* ── Parameter form ───────────────────────────────────────────────── */}
        <form onSubmit={handleSubmit} className="flex-1 flex flex-col">
          <div className="space-y-5 flex-1">
            {/* ages */}
            <div className="space-y-2">
              <Label htmlFor="ages">Ages <span className="text-destructive">*</span></Label>
              <Input
                id="ages"
                value={ages}
                onChange={(e) => setAges(e.target.value)}
                placeholder="e.g. 0:20 or c(0,1,2,3,4,5)"
                disabled={isWorking}
                className="font-mono"
              />
              <p className="text-[10px] text-muted-foreground">R integer vector expression — minimum age must be 0</p>
            </div>

            <div className="grid grid-cols-2 gap-4">
              {/* samples */}
              <div className="space-y-2">
                <Label htmlFor="samples">Samples</Label>
                <Input
                  id="samples"
                  type="number"
                  min={1}
                  value={samples}
                  onChange={(e) => setSamples(e.target.value)}
                  placeholder="default"
                  disabled={isWorking}
                />
                <p className="text-[10px] text-muted-foreground">Monte Carlo samples</p>
              </div>

              {/* time */}
              <div className="space-y-2">
                <Label htmlFor="time">Time</Label>
                <Input
                  id="time"
                  type="number"
                  min={1}
                  value={time}
                  onChange={(e) => setTime(e.target.value)}
                  placeholder="default"
                  disabled={isWorking}
                />
                <p className="text-[10px] text-muted-foreground">Time horizon (years)</p>
              </div>

              {/* shape */}
              <div className="space-y-2">
                <Label htmlFor="shape">Shape</Label>
                <Input
                  id="shape"
                  type="number"
                  step="any"
                  value={shape}
                  onChange={(e) => setShape(e.target.value)}
                  placeholder="default"
                  disabled={isWorking}
                />
                <p className="text-[10px] text-muted-foreground">Shape parameter</p>
              </div>

              {/* seeds */}
              <div className="space-y-2">
                <Label htmlFor="seeds">Seed</Label>
                <Input
                  id="seeds"
                  type="number"
                  min={0}
                  value={seeds}
                  onChange={(e) => setSeeds(e.target.value)}
                  placeholder="random"
                  disabled={isWorking}
                />
                <p className="text-[10px] text-muted-foreground">Random seed</p>
              </div>
            </div>
          </div>

          <div className="mt-8 space-y-4">
            {runOm.isError && (
              <div className="p-3 text-sm rounded-md bg-destructive/10 text-destructive border border-destructive/20">
                Failed to initialise om. Check history logs for R output.
              </div>
            )}

            {lastOutputFileId && (
              <div className="p-3 text-sm rounded-md bg-green-50 dark:bg-green-950/20 text-green-800 dark:text-green-400 border border-green-200 dark:border-green-900/50 flex items-center gap-2">
                <CheckCircle2 className="h-4 w-4 shrink-0" />
                <span>om object created — switching to pdyn</span>
              </div>
            )}

            <Button
              type="submit"
              className="w-full"
              size="lg"
              disabled={!ages.trim() || isWorking}
            >
              {runOm.isPending ? (
                <>
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  Initialising…
                </>
              ) : (
                <>
                  <Layers className="mr-2 h-4 w-4" />
                  {uploadState.status === 'loaded' ? 'Re-initialise om' : 'Initialise om'}
                </>
              )}
            </Button>
          </div>
        </form>
      </CardContent>
    </Card>
  );
}
