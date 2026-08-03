import React from 'react';
import { WorkspaceProvider, useWorkspace } from '../WorkspaceContext';
import { SessionHistory } from '../components/SessionHistory';
import { FileUploader } from '../components/FileUploader';
import { OmForm } from '../components/OmForm';
import { PdynForm } from '../components/PdynForm';
import { DynplotForm } from '../components/DynplotForm';
import { OutputDisplay } from '../components/OutputDisplay';
import { RStatusBadge } from '../components/RStatusBadge';
import { InstallPanel } from '../components/InstallPanel';
import { Tabs, TabsList, TabsTrigger, TabsContent } from '../components/ui/tabs';
import { FlaskConical } from 'lucide-react';
import { useGetRStatus } from '@workspace/api-client-react';

function WorkspaceLayout() {
  const { activeTab, setActiveTab } = useWorkspace();
  const { data: rStatus } = useGetRStatus();

  const pstomReady = rStatus?.rAvailable && rStatus?.pstomInstalled;

  return (
    <div className="flex flex-col h-screen w-full bg-background overflow-hidden text-foreground">
      {/* Header */}
      <header className="h-14 shrink-0 border-b bg-card flex items-center justify-between px-4 z-10">
        <div className="flex items-center gap-3">
          <div className="h-8 w-8 bg-primary rounded-md flex items-center justify-center text-primary-foreground shadow-sm">
            <FlaskConical className="h-4 w-4" />
          </div>
          <div>
            <h1 className="font-semibold text-sm leading-tight tracking-tight">pstom R Interface</h1>
            <p className="text-[10px] text-muted-foreground font-mono">Scientific Web UI</p>
          </div>
        </div>
        <div className="flex items-center">
          <RStatusBadge />
        </div>
      </header>

      {/* Main 3-pane workspace */}
      <main className="flex-1 flex overflow-hidden">
        {/* Pane 1: History */}
        <aside className="w-[300px] shrink-0 border-r bg-card/50 flex flex-col z-0">
          <SessionHistory />
        </aside>

        {/* Pane 2: Tools / Forms */}
        <section className="w-[450px] shrink-0 flex flex-col p-6 overflow-y-auto bg-muted/20 gap-6">
          {/* Show the install panel when pstom isn't available yet */}
          {rStatus && !pstomReady && rStatus.rAvailable && (
            <InstallPanel rAvailable={rStatus.rAvailable} />
          )}

          <FileUploader />

          <Tabs value={activeTab} onValueChange={(v) => setActiveTab(v as "om" | "pdyn" | "dynplot")} className="flex-1 flex flex-col">
            <TabsList className="grid w-full grid-cols-3 mb-6">
              <TabsTrigger value="om">om</TabsTrigger>
              <TabsTrigger value="pdyn">pdyn</TabsTrigger>
              <TabsTrigger value="dynplot">dynplot</TabsTrigger>
            </TabsList>
            <TabsContent value="om" className="flex-1 m-0 focus-visible:outline-none">
              <OmForm />
            </TabsContent>
            <TabsContent value="pdyn" className="flex-1 m-0 focus-visible:outline-none">
              <PdynForm />
            </TabsContent>
            <TabsContent value="dynplot" className="flex-1 m-0 focus-visible:outline-none">
              <DynplotForm />
            </TabsContent>
          </Tabs>
        </section>

        {/* Pane 3: Live Output */}
        <section className="flex-1 flex flex-col overflow-hidden bg-muted/5">
          <OutputDisplay />
        </section>
      </main>
    </div>
  );
}

export default function WorkspacePage() {
  return (
    <WorkspaceProvider>
      <WorkspaceLayout />
    </WorkspaceProvider>
  );
}
