import React, { useState, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { useDropzone } from 'react-dropzone';
import { Upload as UploadIcon } from 'lucide-react';
import { SUPPORTED_FORMATS, MAX_FILE_SIZE } from '../lib/storage';
import { analyzeAudio, loadAudioBuffer } from '../lib/audioAnalysis';
import toast from 'react-hot-toast';

export default function Upload() {
  const navigate = useNavigate();
  const [analyzing, setAnalyzing] = useState(false);

  const onDrop = useCallback(async (acceptedFiles: File[]) => {
    if (acceptedFiles.length === 0) return;

    const file = acceptedFiles[0]; // Take only the first file
    setAnalyzing(true);

    try {
      // Analyze the audio file
      const audioBuffer = await loadAudioBuffer(file);
      const analysis = await analyzeAudio(audioBuffer);
      const preview = URL.createObjectURL(file);

      // Navigate to analysis page with file data
      navigate('/loop-analysis', {
        state: {
          file,
          analysis,
          preview
        }
      });
    } catch (error: any) {
      console.error('Analysis error:', error);
      toast.error(error.message || 'Failed to analyze audio file');
    } finally {
      setAnalyzing(false);
    }
  }, [navigate]);

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    onDrop,
    accept: SUPPORTED_FORMATS,
    maxSize: MAX_FILE_SIZE,
    multiple: false
  });

  return (
    <div className="max-w-3xl mx-auto space-y-8">
      <div className="text-center">
        <h1 className="text-3xl font-bold gradient-text mb-4">Upload Your Loops</h1>
        <p className="text-gray-600 dark:text-gray-400">
          Share your beats with producers worldwide
        </p>
      </div>

      <div 
        {...getRootProps()} 
        className={`glass-panel p-8 text-center cursor-pointer transition-all duration-200
          ${isDragActive ? 'border-primary-500 bg-primary-50/50 dark:bg-primary-900/10' : ''}`}
      >
        <input {...getInputProps()} />
        {analyzing ? (
          <div className="space-y-4">
            <div className="w-16 h-16 border-4 border-primary-500 border-t-transparent rounded-full animate-spin mx-auto"></div>
            <p className="text-gray-600 dark:text-gray-400">Analyzing audio...</p>
          </div>
        ) : (
          <>
            <UploadIcon className="mx-auto h-12 w-12 text-gray-400 dark:text-gray-600 mb-4" />
            <p className="text-gray-600 dark:text-gray-400 mb-2">
              Drag and drop your audio file here, or click to browse
            </p>
            <p className="text-sm text-gray-500 dark:text-gray-400">
              Supported formats: WAV, MP3, M4A, AAC (Max 10MB)
            </p>
          </>
        )}
      </div>
    </div>
  );
}