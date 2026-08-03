import React, { createContext, useContext, useState, ReactNode } from 'react';

interface WorkspaceContextType {
  uploadedFileId: string | null;
  uploadedFilename: string | null;
  setUploadedFile: (id: string | null, filename: string | null) => void;
  selectedPdynSessionId: string | null;
  setSelectedPdynSessionId: (id: string | null) => void;
  activeTab: "pdyn" | "dynplot";
  setActiveTab: (tab: "pdyn" | "dynplot") => void;
  activeOutputSessionId: string | null;
  setActiveOutputSessionId: (id: string | null) => void;
}

const WorkspaceContext = createContext<WorkspaceContextType | undefined>(undefined);

export function WorkspaceProvider({ children }: { children: ReactNode }) {
  const [uploadedFileId, setUploadedFileId] = useState<string | null>(null);
  const [uploadedFilename, setUploadedFilename] = useState<string | null>(null);
  const [selectedPdynSessionId, setSelectedPdynSessionId] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<"pdyn" | "dynplot">("pdyn");
  const [activeOutputSessionId, setActiveOutputSessionId] = useState<string | null>(null);

  const setUploadedFile = (id: string | null, filename: string | null) => {
    setUploadedFileId(id);
    setUploadedFilename(filename);
  };

  return (
    <WorkspaceContext.Provider value={{
      uploadedFileId,
      uploadedFilename,
      setUploadedFile,
      selectedPdynSessionId,
      setSelectedPdynSessionId,
      activeTab,
      setActiveTab,
      activeOutputSessionId,
      setActiveOutputSessionId
    }}>
      {children}
    </WorkspaceContext.Provider>
  );
}

export function useWorkspace() {
  const context = useContext(WorkspaceContext);
  if (context === undefined) {
    throw new Error('useWorkspace must be used within a WorkspaceProvider');
  }
  return context;
}