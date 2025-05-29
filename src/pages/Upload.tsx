import React, { useState } from 'react';
import { Upload as UploadIcon, Music, X } from 'lucide-react';

interface UploadedFile extends File {
  preview?: string;
  localUrl?: string;
}

export default function Upload() {
  const [dragActive, setDragActive] = useState(false);
  const [files, setFiles] = useState<UploadedFile[]>([]);
  const [uploading, setUploading] = useState(false);

  const handleDrag = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    if (e.type === "dragenter" || e.type === "dragover") {
      setDragActive(true);
    } else if (e.type === "dragleave") {
      setDragActive(false);
    }
  };

  const processFile = async (file: File): Promise<UploadedFile> => {
    // Create a sanitized filename
    const timestamp = Date.now();
    const sanitizedName = file.name.toLowerCase().replace(/[^a-z0-9.]/g, '-');
    const uniqueFileName = `${timestamp}-${sanitizedName}`;
    
    // Create a local URL for the file
    const localUrl = `/samples/${uniqueFileName}`;
    
    // Create an object URL for preview
    const preview = URL.createObjectURL(file);
    
    return Object.assign(file, {
      preview,
      localUrl,
    });
  };

  const handleDrop = async (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setDragActive(false);
    
    const droppedFiles = Array.from(e.dataTransfer.files);
    const audioFiles = droppedFiles.filter(file => 
      file.type === "audio/mpeg" || file.type === "audio/wav"
    );
    
    const processedFiles = await Promise.all(audioFiles.map(processFile));
    setFiles(prev => [...prev, ...processedFiles]);
  };

  const handleFileInput = async (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files) {
      const selectedFiles = Array.from(e.target.files);
      const audioFiles = selectedFiles.filter(file => 
        file.type === "audio/mpeg" || file.type === "audio/wav"
      );
      
      const processedFiles = await Promise.all(audioFiles.map(processFile));
      setFiles(prev => [...prev, ...processedFiles]);
    }
  };

  const removeFile = (index: number) => {
    const file = files[index];
    if (file.preview) {
      URL.revokeObjectURL(file.preview);
    }
    setFiles(prev => prev.filter((_, i) => i !== index));
  };

  const handleUpload = async () => {
    setUploading(true);
    try {
      for (const file of files) {
        // Create a copy of the file in the public/samples directory
        const response = await fetch(file.preview!);
        const blob = await response.blob();
        
        // In a real application, you would use a proper file upload service
        // For now, we're simulating the upload by copying to public/samples
        const formData = new FormData();
        formData.append('file', blob, file.localUrl?.split('/').pop());
        
        // Simulate upload delay
        await new Promise(resolve => setTimeout(resolve, 1000));
        
        console.log(`File would be saved to: ${file.localUrl}`);
      }
      
      // Clear the files after successful upload
      files.forEach(file => {
        if (file.preview) {
          URL.revokeObjectURL(file.preview);
        }
      });
      setFiles([]);
      
    } catch (error) {
      console.error('Upload error:', error);
    } finally {
      setUploading(false);
    }
  };

  return (
    <div className="max-w-3xl mx-auto space-y-8">
      <div className="text-center">
        <h1 className="text-3xl font-bold gradient-text mb-4">Upload Your Loops</h1>
        <p className="text-gray-600 dark:text-gray-400">Share your beats with producers worldwide</p>
      </div>

      <div 
        className={`glass-panel p-8 text-center ${
          dragActive ? "border-primary-500 bg-primary-50/50 dark:bg-primary-900/10" : ""
        }`}
        onDragEnter={handleDrag}
        onDragLeave={handleDrag}
        onDragOver={handleDrag}
        onDrop={handleDrop}
      >
        <UploadIcon className="mx-auto h-12 w-12 text-gray-400 dark:text-gray-600 mb-4" />
        <p className="text-gray-600 dark:text-gray-400 mb-2">
          Drag and drop your audio files here, or
        </p>
        <label className="inline-block">
          <span className="bg-primary-500 text-white px-4 py-2 rounded-full cursor-pointer hover:bg-primary-600 transition-colors">
            Browse Files
          </span>
          <input
            type="file"
            className="hidden"
            accept=".mp3,.wav"
            multiple
            onChange={handleFileInput}
          />
        </label>
        <p className="text-sm text-gray-500 dark:text-gray-400 mt-2">
          Supported formats: MP3, WAV
        </p>
      </div>

      {files.length > 0 && (
        <div className="space-y-4">
          <h2 className="text-xl font-semibold gradient-text">Selected Files</h2>
          {files.map((file, index) => (
            <div 
              key={index}
              className="glass-panel p-4 flex items-center justify-between"
            >
              <div className="flex items-center space-x-3">
                <Music className="h-5 w-5 text-primary-500" />
                <div>
                  <p className="text-gray-900 dark:text-white font-medium">{file.name}</p>
                  <p className="text-sm text-gray-500 dark:text-gray-400">
                    {(file.size / (1024 * 1024)).toFixed(2)} MB
                  </p>
                </div>
              </div>
              <button 
                onClick={() => removeFile(index)}
                className="text-gray-400 hover:text-gray-500 dark:hover:text-gray-300"
                disabled={uploading}
              >
                <X className="h-5 w-5" />
              </button>
            </div>
          ))}
          
          <button 
            onClick={handleUpload}
            disabled={uploading}
            className={`w-full bg-primary-500 text-white py-3 rounded-lg font-semibold 
              ${uploading 
                ? 'opacity-50 cursor-not-allowed' 
                : 'hover:bg-primary-600 transition-colors'
              }`}
          >
            {uploading 
              ? 'Uploading...' 
              : `Upload ${files.length} ${files.length === 1 ? 'File' : 'Files'}`
            }
          </button>
        </div>
      )}
    </div>
  );
}