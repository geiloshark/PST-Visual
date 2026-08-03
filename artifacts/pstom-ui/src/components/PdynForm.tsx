import React, { useState } from 'react';
import { useWorkspace } from '../WorkspaceContext';
import { useRunPdyn, getListSessionsQueryKey } from '@workspace/api-client-react';
import { useQueryClient } from '@tanstack/react-query';
import { Card, CardContent, CardDescription, CardHeader, CardTitle, Button, Input, Label, Switch, Separator } from './ui/core';
import { Play, Loader2, Download, CheckCircle2 } from 'lucide-react';

export function PdynForm() {
  const { uploadedFileId, setSelectedPdynSessionId, setActiveTab, setActiveOutputSessionId } = useWorkspace();
  const queryClient = useQueryClient();
  const runPdyn = useRunPdyn();

  const [stochastic, setStochastic] = useState(true);
  const [iterations, setIterations] = useState(1000);
  const [time, setTime] = useState(100);
  const [initialDepletion, setInitialDepletion] = useState(1.0);
  const [useRmax, setUseRmax] = useState(true);
  const [verbose, setVerbose] = useState(false);

  const [lastResult, setLastResult] = useState<{ id: string, outputFileId: string | null } | null>(null);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!uploadedFileId) return;

    setLastResult(null);

    runPdyn.mutate(
      {
        data: {
          fileId: uploadedFileId,
          stochastic,
          iterations,
          time,
          initialDepletion,
          useRmax,
          verbose
        }
      },
      {
        onSuccess: (session) => {
          queryClient.invalidateQueries({ queryKey: getListSessionsQueryKey() });
          setSelectedPdynSessionId(session.id);
          if (session.outputFileId) {
            setLastResult({ id: session.id, outputFileId: session.outputFileId });
          }
          setActiveOutputSessionId(session.id);
          // Also automatically switch to dynplot tab so they can plot it
          setActiveTab('dynplot');
        }
      }
    );
  };

  return (
    <Card className="h-full flex flex-col">
      <CardHeader>
        <CardTitle className="text-xl">pdyn</CardTitle>
        <CardDescription>Population dynamics projection</CardDescription>
      </CardHeader>
      <CardContent className="flex-1 flex flex-col">
        <form onSubmit={handleSubmit} className="flex-1 flex flex-col">
          <div className="space-y-6 flex-1">
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="iterations">Iterations</Label>
                <Input 
                  id="iterations" 
                  type="number" 
                  min={1} 
                  value={iterations} 
                  onChange={(e) => setIterations(Number(e.target.value))} 
                  disabled={runPdyn.isPending}
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="time">Time horizon</Label>
                <Input 
                  id="time" 
                  type="number" 
                  min={1} 
                  value={time} 
                  onChange={(e) => setTime(Number(e.target.value))} 
                  disabled={runPdyn.isPending}
                />
              </div>
            </div>

            <div className="space-y-2">
              <Label htmlFor="initialDepletion">Initial Depletion</Label>
              <Input 
                id="initialDepletion" 
                type="number" 
                step="0.01" 
                min={0} 
                max={1} 
                value={initialDepletion} 
                onChange={(e) => setInitialDepletion(Number(e.target.value))} 
                disabled={runPdyn.isPending}
              />
            </div>

            <Separator />

            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <div className="space-y-0.5">
                  <Label>Stochastic</Label>
                  <p className="text-xs text-muted-foreground">Use stochastic dynamics</p>
                </div>
                <Switch 
                  checked={stochastic} 
                  onCheckedChange={setStochastic} 
                  disabled={runPdyn.isPending}
                />
              </div>

              <div className="flex items-center justify-between">
                <div className="space-y-0.5">
                  <Label>Use Rmax</Label>
                  <p className="text-xs text-muted-foreground">Estimate parameters using Rmax</p>
                </div>
                <Switch 
                  checked={useRmax} 
                  onCheckedChange={setUseRmax} 
                  disabled={runPdyn.isPending}
                />
              </div>

              <div className="flex items-center justify-between">
                <div className="space-y-0.5">
                  <Label>Verbose</Label>
                  <p className="text-xs text-muted-foreground">Detailed R output logs</p>
                </div>
                <Switch 
                  checked={verbose} 
                  onCheckedChange={setVerbose} 
                  disabled={runPdyn.isPending}
                />
              </div>
            </div>
          </div>

          <div className="mt-8 space-y-4">
            {runPdyn.isError && (
              <div className="p-3 text-sm rounded-md bg-destructive/10 text-destructive border border-destructive/20">
                Failed to run pdyn. Check history logs.
              </div>
            )}
            
            {lastResult && (
              <div className="p-3 text-sm rounded-md bg-green-50 dark:bg-green-950/20 text-green-800 dark:text-green-400 border border-green-200 dark:border-green-900/50 flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <CheckCircle2 className="h-4 w-4" />
                  <span>Dynamics generated</span>
                </div>
                <a 
                  href={`/api/r/files/${lastResult.outputFileId}`}
                  target="_blank"
                  rel="noreferrer" 
                  className="inline-flex items-center gap-1 hover:underline font-medium"
                >
                  <Download className="h-3 w-3" /> .rds
                </a>
              </div>
            )}

            <Button 
              type="submit" 
              className="w-full" 
              size="lg"
              disabled={!uploadedFileId || runPdyn.isPending}
            >
              {runPdyn.isPending ? (
                <>
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  Computing...
                </>
              ) : (
                <>
                  <Play className="mr-2 h-4 w-4" />
                  Run pdyn
                </>
              )}
            </Button>
            {!uploadedFileId && (
              <p className="text-xs text-center text-muted-foreground">Upload an .rds file first</p>
            )}
          </div>
        </form>
      </CardContent>
    </Card>
  );
}