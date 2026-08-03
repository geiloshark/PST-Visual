import React from 'react';
import { useWorkspace } from '../WorkspaceContext';
import { useGetSession, getGetSessionQueryKey } from '@workspace/api-client-react';
import { Card, Button, Badge } from './ui/core';
import { Terminal, ImageIcon, Download, Loader2, AlertCircle } from 'lucide-react';

export function OutputDisplay() {
  const { activeOutputSessionId, setActiveTab, setSelectedPdynSessionId } = useWorkspace();

  const { data: session, isLoading, isError } = useGetSession(activeOutputSessionId || '', {
    query: {
      enabled: !!activeOutputSessionId,
      queryKey: getGetSessionQueryKey(activeOutputSessionId || '')
    }
  });

  if (!activeOutputSessionId) {
    return (
      <div className="h-full w-full flex items-center justify-center text-muted-foreground border-l border-border bg-muted/10 p-8 text-center">
        <div className="max-w-sm flex flex-col items-center gap-4">
          <Terminal className="h-12 w-12 opacity-20" />
          <h2 className="text-lg font-semibold text-foreground">Workspace Output</h2>
          <p className="text-sm">Run a pdyn or dynplot analysis, or select a session from the history to view its output here.</p>
        </div>
      </div>
    );
  }

  if (isLoading) {
    return (
      <div className="h-full w-full flex flex-col items-center justify-center text-muted-foreground border-l border-border bg-background p-8 gap-4">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
        <p className="text-sm font-medium animate-pulse">Loading session data...</p>
      </div>
    );
  }

  if (isError || !session) {
    return (
      <div className="h-full w-full flex flex-col items-center justify-center text-destructive border-l border-border bg-background p-8 gap-4">
        <AlertCircle className="h-8 w-8" />
        <p className="text-sm font-medium">Failed to load session details</p>
      </div>
    );
  }

  const isSuccess = session.status === 'success';

  return (
    <div className="h-full w-full flex flex-col border-l border-border bg-background">
      <div className="px-6 py-4 border-b border-border bg-muted/30 flex items-center justify-between shrink-0">
        <div className="flex items-center gap-3">
          <Badge variant={session.type === 'pdyn' ? 'default' : 'secondary'} className="uppercase text-[10px]">
            {session.type}
          </Badge>
          <span className="text-sm font-mono text-muted-foreground">{session.id}</span>
          <Badge variant={isSuccess ? 'success' : 'destructive'} className="text-[10px]">
            {session.status}
          </Badge>
        </div>
        <div className="text-xs text-muted-foreground">
          {new Date(session.createdAt).toLocaleString()}
        </div>
      </div>

      <div className="flex-1 overflow-y-auto p-6 flex flex-col gap-6">
        {!isSuccess && session.error && (
          <div className="bg-destructive/10 border border-destructive/20 rounded-md p-4 text-sm text-destructive font-mono whitespace-pre-wrap">
            <div className="flex items-center gap-2 mb-2 font-bold font-sans">
              <AlertCircle className="h-4 w-4" /> Error Output
            </div>
            {session.error}
          </div>
        )}

        {isSuccess && session.type === 'pdyn' && (
          <Card className="p-6 flex flex-col items-center justify-center text-center gap-4 bg-green-50/50 dark:bg-green-900/10 border-green-200 dark:border-green-900/50">
            <div className="h-12 w-12 rounded-full bg-green-100 dark:bg-green-900/50 flex items-center justify-center text-green-600 dark:text-green-400">
              <Download className="h-6 w-6" />
            </div>
            <div>
              <h3 className="text-lg font-semibold text-green-800 dark:text-green-400 mb-1">Dynamics Generated</h3>
              <p className="text-sm text-green-700/80 dark:text-green-500/80">
                The S4 object was successfully updated with stochastic simulations.
              </p>
            </div>
            <div className="flex items-center gap-3 mt-2">
              <Button asChild variant="outline" className="border-green-300 dark:border-green-800 hover:bg-green-100 dark:hover:bg-green-900/50">
                <a href={`/api/r/files/${session.outputFileId}`} target="_blank" rel="noreferrer">
                  Download .rds
                </a>
              </Button>
              <Button 
                className="bg-green-600 text-white hover:bg-green-700 dark:bg-green-700 dark:hover:bg-green-600"
                onClick={() => {
                  setSelectedPdynSessionId(session.id);
                  setActiveTab('dynplot');
                }}
              >
                Plot Dynamics
              </Button>
            </div>
          </Card>
        )}

        {isSuccess && session.type === 'dynplot' && session.plotId && (
          <div className="flex flex-col gap-4">
            <div className="flex items-center justify-between">
              <h3 className="text-lg font-semibold flex items-center gap-2">
                <ImageIcon className="h-5 w-5 text-muted-foreground" /> Plot Output
              </h3>
              <Button asChild variant="outline" size="sm">
                <a href={`/api/r/files/${session.plotId}`} target="_blank" rel="noreferrer">
                  <Download className="h-4 w-4 mr-2" /> Download PNG
                </a>
              </Button>
            </div>
            <div className="rounded-lg border bg-white p-2 shadow-sm overflow-hidden flex items-center justify-center min-h-[400px]">
              <img 
                src={`/api/r/files/${session.plotId}`} 
                alt="Dynamics plot" 
                className="max-w-full h-auto object-contain max-h-[800px]"
              />
            </div>
          </div>
        )}

        {session.logs && (
          <div className="flex flex-col gap-2 mt-4">
            <h3 className="text-sm font-semibold flex items-center gap-2">
              <Terminal className="h-4 w-4 text-muted-foreground" /> Console Output
            </h3>
            <div className="bg-[#1e1e1e] text-[#d4d4d4] p-4 rounded-md text-xs font-mono whitespace-pre-wrap overflow-x-auto">
              {session.logs}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}