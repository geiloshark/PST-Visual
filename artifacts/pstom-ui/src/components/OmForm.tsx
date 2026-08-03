import React, { useState } from 'react';
import { useWorkspace } from '../WorkspaceContext';
import { useRunOm, getListSessionsQueryKey } from '@workspace/api-client-react';
import { useQueryClient } from '@tanstack/react-query';
import { Card, CardContent, CardDescription, CardHeader, CardTitle, Button, Input, Label, Separator } from './ui/core';
import { Layers, Loader2, CheckCircle2 } from 'lucide-react';

export function OmForm() {
  const { setUploadedFile, setActiveTab } = useWorkspace();
  const queryClient = useQueryClient();
  const runOm = useRunOm();

  const [ages, setAges] = useState('1:20');
  const [samples, setSamples] = useState<string>('');
  const [time, setTime] = useState<string>('');
  const [shape, setShape] = useState<string>('');
  const [seeds, setSeeds] = useState<string>('');

  const [lastOutputFileId, setLastOutputFileId] = useState<string | null>(null);

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
            // Auto-populate the file for pdyn — same as uploading an .rds
            setUploadedFile(session.outputFileId, 'om_output.rds');
            // Switch to pdyn tab
            setActiveTab('pdyn');
          }
        }
      }
    );
  };

  return (
    <Card className="h-full flex flex-col">
      <CardHeader>
        <CardTitle className="text-xl">om</CardTitle>
        <CardDescription>Initialise operating model S4 object</CardDescription>
      </CardHeader>
      <CardContent className="flex-1 flex flex-col">
        <form onSubmit={handleSubmit} className="flex-1 flex flex-col">
          <div className="space-y-5 flex-1">
            {/* ages */}
            <div className="space-y-2">
              <Label htmlFor="ages">Ages <span className="text-destructive">*</span></Label>
              <Input
                id="ages"
                value={ages}
                onChange={(e) => setAges(e.target.value)}
                placeholder="e.g. 1:20 or c(1,2,3,4,5)"
                disabled={runOm.isPending}
                className="font-mono"
              />
              <p className="text-[10px] text-muted-foreground">Any R integer vector expression</p>
            </div>

            <Separator />

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
                  disabled={runOm.isPending}
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
                  disabled={runOm.isPending}
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
                  disabled={runOm.isPending}
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
                  disabled={runOm.isPending}
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
              disabled={!ages.trim() || runOm.isPending}
            >
              {runOm.isPending ? (
                <>
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  Initialising…
                </>
              ) : (
                <>
                  <Layers className="mr-2 h-4 w-4" />
                  Initialise om
                </>
              )}
            </Button>
          </div>
        </form>
      </CardContent>
    </Card>
  );
}
