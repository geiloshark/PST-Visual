import React from 'react';
import { useGetRStatus, getGetRStatusQueryKey } from '@workspace/api-client-react';
import { Badge } from './ui/core';
import { Activity, AlertTriangle, CheckCircle2 } from 'lucide-react';

export function RStatusBadge() {
  const { data: status, isLoading, isError } = useGetRStatus({
    query: {
      queryKey: getGetRStatusQueryKey(),
      // Poll every 5 s while pstom isn't ready so the badge goes green automatically
      refetchInterval: (query) => {
        const data = query.state.data;
        if (!data) return 5_000;
        return data.rAvailable && data.pstomInstalled ? false : 5_000;
      },
    },
  });

  if (isLoading) {
    return (
      <Badge variant="outline" className="flex items-center gap-1.5 opacity-50 px-2 py-1">
        <Activity className="h-3 w-3 animate-pulse" />
        <span className="text-[10px]">Checking R...</span>
      </Badge>
    );
  }

  if (isError || !status) {
    return (
      <Badge variant="destructive" className="flex items-center gap-1.5 px-2 py-1">
        <AlertTriangle className="h-3 w-3" />
        <span className="text-[10px]">R Service Offline</span>
      </Badge>
    );
  }

  const isHealthy = status.rAvailable && status.pstomInstalled;

  if (isHealthy) {
    return (
      <div className="flex items-center gap-2">
        <Badge variant="success" className="flex items-center gap-1.5 px-2 py-1">
          <CheckCircle2 className="h-3 w-3" />
          <span className="text-[10px]">Ready</span>
        </Badge>
        {status.pstomVersion && (
          <span className="text-[10px] font-mono text-muted-foreground">
            pstom v{status.pstomVersion}
          </span>
        )}
      </div>
    );
  }

  return (
    <Badge variant="warning" className="flex items-center gap-1.5 px-2 py-1">
      <AlertTriangle className="h-3 w-3" />
      <span className="text-[10px]">
        {!status.rAvailable ? 'R Not Found' : 'pstom Package Missing'}
      </span>
    </Badge>
  );
}
