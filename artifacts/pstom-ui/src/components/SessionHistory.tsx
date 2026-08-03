import React, { useState } from 'react';
import { useListSessions, useDeleteSession, getListSessionsQueryKey, Session } from '@workspace/api-client-react';
import { useQueryClient } from '@tanstack/react-query';
import { useWorkspace } from '../WorkspaceContext';
import { Button, Badge, Separator } from './ui/core';
import { Trash2, Terminal, ChevronDown, ChevronRight, FileOutput, Clock, AlertCircle } from 'lucide-react';
import { cn } from './ui/core';

export function SessionHistory() {
  const { data: sessions, isLoading, isError } = useListSessions();
  const deleteSession = useDeleteSession();
  const queryClient = useQueryClient();
  const { setSelectedPdynSessionId, setActiveTab, setActiveOutputSessionId } = useWorkspace();

  const [expandedId, setExpandedId] = useState<string | null>(null);

  const handleToggle = (id: string) => {
    const isExpanding = expandedId !== id;
    setExpandedId(isExpanding ? id : null);
    if (isExpanding) {
      setActiveOutputSessionId(id);
    }
  };

  const handleDelete = (id: string, e: React.MouseEvent) => {
    e.stopPropagation();
    deleteSession.mutate({ id }, {
      onSuccess: () => {
        queryClient.invalidateQueries({ queryKey: getListSessionsQueryKey() });
        if (expandedId === id) setExpandedId(null);
      }
    });
  };

  const handleUsePdynOutput = (id: string, e: React.MouseEvent) => {
    e.stopPropagation();
    setSelectedPdynSessionId(id);
    setActiveTab('dynplot');
  };

  if (isLoading) {
    return <div className="p-4 text-sm text-muted-foreground flex items-center justify-center">Loading history...</div>;
  }

  if (isError || !sessions) {
    return <div className="p-4 text-sm text-destructive">Failed to load sessions</div>;
  }

  if (sessions.length === 0) {
    return <div className="p-8 text-center text-sm text-muted-foreground">No sessions run yet.</div>;
  }

  return (
    <div className="flex flex-col h-full overflow-hidden">
      <div className="p-4 bg-muted/50 border-b flex items-center justify-between">
        <h3 className="font-semibold text-sm">Session History</h3>
        <Badge variant="outline" className="text-[10px]">{sessions.length}</Badge>
      </div>
      <div className="flex-1 overflow-y-auto">
        <div className="flex flex-col divide-y">
          {sessions.map((session) => (
            <SessionItem 
              key={session.id} 
              session={session} 
              isExpanded={expandedId === session.id}
              onToggle={() => handleToggle(session.id)}
              onDelete={(e) => handleDelete(session.id, e)}
              onUsePdynOutput={(e) => handleUsePdynOutput(session.id, e)}
            />
          ))}
        </div>
      </div>
    </div>
  );
}

function SessionItem({ 
  session, 
  isExpanded, 
  onToggle, 
  onDelete,
  onUsePdynOutput
}: { 
  session: Session; 
  isExpanded: boolean; 
  onToggle: () => void;
  onDelete: (e: React.MouseEvent) => void;
  onUsePdynOutput: (e: React.MouseEvent) => void;
}) {
  const isSuccess = session.status === 'success';
  const isPdyn = session.type === 'pdyn';
  const date = new Date(session.createdAt);

  return (
    <div className={cn("flex flex-col transition-colors", isExpanded ? "bg-accent/20" : "hover:bg-accent/10")}>
      <div 
        className="flex items-center justify-between p-3 cursor-pointer select-none group"
        onClick={onToggle}
      >
        <div className="flex items-center gap-3">
          <button className="text-muted-foreground hover:text-foreground">
            {isExpanded ? <ChevronDown className="h-4 w-4" /> : <ChevronRight className="h-4 w-4" />}
          </button>
          <div className="flex flex-col gap-1">
            <div className="flex items-center gap-2">
              <Badge variant={isPdyn ? "default" : "secondary"} className="text-[10px] uppercase">
                {session.type}
              </Badge>
              <span className="text-xs font-mono text-muted-foreground" title={session.id}>
                {session.id.substring(0, 8)}
              </span>
              <Badge variant={isSuccess ? "success" : "destructive"} className="text-[10px] h-4">
                {session.status}
              </Badge>
            </div>
            <div className="flex items-center gap-1 text-[10px] text-muted-foreground">
              <Clock className="h-3 w-3" />
              {date.toLocaleDateString()} {date.toLocaleTimeString()}
            </div>
          </div>
        </div>
        
        <Button 
          variant="ghost" 
          size="icon" 
          className="h-7 w-7 opacity-0 group-hover:opacity-100 transition-opacity text-muted-foreground hover:text-destructive"
          onClick={onDelete}
        >
          <Trash2 className="h-3 w-3" />
        </Button>
      </div>

      {isExpanded && (
        <div className="px-4 pb-4 pt-1 flex flex-col gap-3 text-sm animate-in slide-in-from-top-2">
          {session.args && (
            <div className="bg-card border rounded p-2 text-xs font-mono overflow-x-auto text-muted-foreground">
              {Object.entries(session.args).map(([k, v]) => (
                <div key={k} className="flex gap-2">
                  <span className="text-foreground">{k}:</span>
                  <span>{String(v)}</span>
                </div>
              ))}
            </div>
          )}

          {!isSuccess && session.error && (
            <div className="bg-destructive/10 border-destructive/20 border rounded p-2 text-xs text-destructive flex gap-2 items-start">
              <AlertCircle className="h-4 w-4 shrink-0 mt-0.5" />
              <p className="whitespace-pre-wrap font-mono">{session.error}</p>
            </div>
          )}

          {isSuccess && isPdyn && session.outputFileId && (
            <div className="flex items-center gap-2 mt-1">
              <Button size="sm" variant="secondary" onClick={onUsePdynOutput} className="w-full text-xs">
                <FileOutput className="h-3 w-3 mr-2" />
                Use in dynplot
              </Button>
            </div>
          )}

          {isSuccess && !isPdyn && session.plotId && (
            <div className="mt-1">
              <a 
                href={`/api/r/files/${session.plotId}`}
                target="_blank" 
                rel="noreferrer"
              >
                <img 
                  src={`/api/r/files/${session.plotId}`} 
                  alt="Plot result" 
                  className="w-full h-auto rounded border bg-white max-h-48 object-contain"
                />
              </a>
            </div>
          )}

          {session.logs && (
            <div className="mt-2">
              <div className="flex items-center gap-1 text-xs text-muted-foreground mb-1">
                <Terminal className="h-3 w-3" /> R Output
              </div>
              <div className="bg-[#1e1e1e] text-[#d4d4d4] p-3 rounded text-[10px] font-mono whitespace-pre-wrap overflow-x-auto max-h-64 overflow-y-auto">
                {session.logs}
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}