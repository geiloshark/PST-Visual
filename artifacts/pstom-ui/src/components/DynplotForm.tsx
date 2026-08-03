import React, { useState, useEffect } from 'react';
import { useWorkspace } from '../WorkspaceContext';
import { useRunDynplot, getListSessionsQueryKey } from '@workspace/api-client-react';
import { useQueryClient } from '@tanstack/react-query';
import { Card, CardContent, CardDescription, CardHeader, CardTitle, Button, Input, Label } from './ui/core';
import { Loader2, Image as ImageIcon, Download } from 'lucide-react';

export function DynplotForm() {
  const { selectedPdynSessionId, setActiveOutputSessionId } = useWorkspace();
  const queryClient = useQueryClient();
  const runDynplot = useRunDynplot();

  const [sessionId, setSessionId] = useState('');
  const [pars, setPars] = useState('N,B,F');

  const [lastPlotId, setLastPlotId] = useState<string | null>(null);

  // Auto-fill when context changes
  useEffect(() => {
    if (selectedPdynSessionId) {
      setSessionId(selectedPdynSessionId);
    }
  }, [selectedPdynSessionId]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!sessionId.trim()) return;

    setLastPlotId(null);

    runDynplot.mutate(
      {
        data: {
          sessionId: sessionId.trim(),
          pars: pars.trim() || undefined
        }
      },
      {
        onSuccess: (session) => {
          queryClient.invalidateQueries({ queryKey: getListSessionsQueryKey() });
          if (session.plotId) {
            setLastPlotId(session.plotId);
          }
          setActiveOutputSessionId(session.id);
        }
      }
    );
  };

  return (
    <Card className="h-full flex flex-col">
      <CardHeader>
        <CardTitle className="text-xl">dynplot</CardTitle>
        <CardDescription>Plot population dynamics</CardDescription>
      </CardHeader>
      <CardContent className="flex-1 flex flex-col">
        <form onSubmit={handleSubmit} className="flex-1 flex flex-col">
          <div className="space-y-6 flex-1">
            <div className="space-y-2">
              <Label htmlFor="sessionId">Source Session ID</Label>
              <Input 
                id="sessionId" 
                value={sessionId} 
                onChange={(e) => setSessionId(e.target.value)} 
                placeholder="Session ID of a successful pdyn run"
                disabled={runDynplot.isPending}
                className="font-mono text-xs"
              />
              <p className="text-[10px] text-muted-foreground">Automatically filled from the latest pdyn run</p>
            </div>

            <div className="space-y-2">
              <Label htmlFor="pars">Parameters to plot</Label>
              <Input 
                id="pars" 
                value={pars} 
                onChange={(e) => setPars(e.target.value)} 
                placeholder="e.g. N,B,F"
                disabled={runDynplot.isPending}
                className="font-mono"
              />
              <p className="text-[10px] text-muted-foreground">Comma-separated list (N: Numbers, B: Biomass, F: Fishing Mortality)</p>
            </div>
          </div>

          <div className="mt-8 space-y-4">
            {runDynplot.isError && (
              <div className="p-3 text-sm rounded-md bg-destructive/10 text-destructive border border-destructive/20">
                Failed to generate plot. Ensure the Session ID belongs to a successful pdyn run.
              </div>
            )}

            {lastPlotId && (
              <div className="flex flex-col gap-2">
                <a 
                  href={`/api/r/files/${lastPlotId}`}
                  target="_blank"
                  rel="noreferrer"
                  className="w-full"
                >
                  <Button type="button" variant="outline" className="w-full font-mono text-xs text-primary">
                    <Download className="mr-2 h-3 w-3" /> PNG Output
                  </Button>
                </a>
              </div>
            )}

            <Button 
              type="submit" 
              className="w-full" 
              size="lg"
              disabled={!sessionId.trim() || runDynplot.isPending}
            >
              {runDynplot.isPending ? (
                <>
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  Plotting...
                </>
              ) : (
                <>
                  <ImageIcon className="mr-2 h-4 w-4" />
                  Generate Plot
                </>
              )}
            </Button>
          </div>
        </form>
      </CardContent>
    </Card>
  );
}