import React, { useState, useRef } from 'react';
import { useWorkspace } from '../WorkspaceContext';
import { Card, CardContent, CardDescription, CardHeader, CardTitle, Badge } from './ui/core';
import { UploadCloud, CheckCircle2, AlertCircle, Loader2 } from 'lucide-react';
import { cn } from './ui/core';

export function FileUploader() {
  const { uploadedFileId, uploadedFilename, setUploadedFile } = useWorkspace();
  const [isDragging, setIsDragging] = useState(false);
  const [isUploading, setIsUploading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(true);
  };

  const handleDragLeave = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);
  };

  const uploadFile = async (file: File) => {
    if (!file.name.endsWith('.rds') && !file.name.endsWith('.RDS')) {
      setError('Only .rds files are supported');
      return;
    }

    setIsUploading(true);
    setError(null);

    try {
      const formData = new FormData();
      formData.append('file', file);

      const res = await fetch('/api/r/upload', {
        method: 'POST',
        body: formData,
      });

      if (!res.ok) {
        throw new Error(`Upload failed: ${res.statusText}`);
      }

      const data = await res.json();
      setUploadedFile(data.fileId, data.filename);
    } catch (err: any) {
      setError(err.message || 'An error occurred during upload');
      setUploadedFile(null, null);
    } finally {
      setIsUploading(false);
    }
  };

  const handleDrop = async (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);
    
    if (e.dataTransfer.files && e.dataTransfer.files.length > 0) {
      await uploadFile(e.dataTransfer.files[0]);
    }
  };

  const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files.length > 0) {
      await uploadFile(e.target.files[0]);
    }
  };

  return (
    <Card className="mb-6">
      <CardHeader className="pb-3">
        <CardTitle className="text-sm font-semibold flex items-center gap-2">
          1. Input Object <Badge variant="outline" className="ml-2 font-mono text-[10px]">.rds</Badge>
        </CardTitle>
        <CardDescription>
          Upload an S4 object saved from R to run dynamics functions.
        </CardDescription>
      </CardHeader>
      <CardContent>
        <div
          onClick={() => !isUploading && fileInputRef.current?.click()}
          onDragOver={handleDragOver}
          onDragLeave={handleDragLeave}
          onDrop={handleDrop}
          className={cn(
            "relative flex flex-col items-center justify-center p-6 border-2 border-dashed rounded-lg transition-colors cursor-pointer",
            isDragging ? "border-primary bg-primary/5" : "border-border hover:bg-accent/50",
            uploadedFileId && "border-green-500/50 bg-green-50/50 dark:bg-green-950/10",
            isUploading && "pointer-events-none opacity-70",
            error && "border-destructive/50 bg-destructive/5"
          )}
        >
          <input 
            type="file" 
            ref={fileInputRef} 
            onChange={handleFileChange} 
            accept=".rds,.RDS" 
            className="hidden" 
          />
          
          {isUploading ? (
            <div className="flex flex-col items-center gap-2 text-muted-foreground">
              <Loader2 className="h-8 w-8 animate-spin text-primary" />
              <p className="text-sm font-medium">Uploading...</p>
            </div>
          ) : uploadedFileId ? (
            <div className="flex flex-col items-center gap-2 text-green-700 dark:text-green-400">
              <CheckCircle2 className="h-8 w-8" />
              <p className="text-sm font-medium">{uploadedFilename}</p>
              <p className="text-xs opacity-80 mt-1 cursor-pointer hover:underline" onClick={(e) => {
                e.stopPropagation();
                setUploadedFile(null, null);
              }}>
                Upload a different file
              </p>
            </div>
          ) : (
            <div className="flex flex-col items-center gap-2 text-muted-foreground">
              <UploadCloud className="h-8 w-8 mb-2" />
              <p className="text-sm font-medium text-foreground">Click or drag and drop to upload</p>
              <p className="text-xs">Only .rds files are supported</p>
            </div>
          )}
        </div>
        
        {error && (
          <div className="flex items-center gap-2 mt-3 text-sm text-destructive">
            <AlertCircle className="h-4 w-4" />
            <p>{error}</p>
          </div>
        )}
      </CardContent>
    </Card>
  );
}