import React from 'react';
import { Music, Activity, Gauge } from 'lucide-react';
import type { AudioAnalysis } from '../lib/audioAnalysis';

interface AudioAnalysisProps {
  analysis: AudioAnalysis;
  isLoading: boolean;
}

export default function AudioAnalysisDisplay({ analysis, isLoading }: AudioAnalysisProps) {
  // Normalize confidence to be between 0 and 100
  const confidenceScore = Math.min(Math.round(analysis.confidence * 100), 100);

  // Format key signature with scale
  const keySignature = `${analysis.key} ${analysis.scale === 'minor' ? 'Minor' : 'Major'}`;

  if (isLoading) {
    return (
      <div className="glass-panel p-6 animate-pulse">
        <div className="flex items-center space-x-2 mb-4">
          <Activity className="w-5 h-5 text-primary-500" />
          <h3 className="text-lg font-semibold gradient-text">Analyzing Audio...</h3>
        </div>
        <div className="space-y-4">
          <div className="h-8 bg-gray-200 dark:bg-gray-700 rounded-md"></div>
          <div className="h-8 bg-gray-200 dark:bg-gray-700 rounded-md"></div>
        </div>
      </div>
    );
  }

  return (
    <div className="glass-panel p-6">
      <div className="flex items-center space-x-2 mb-4">
        <Activity className="w-5 h-5 text-primary-500" />
        <h3 className="text-lg font-semibold gradient-text">Audio Analysis</h3>
      </div>
      
      <div className="grid grid-cols-2 gap-4">
        <div className="glass-panel p-4">
          <div className="flex items-center space-x-2 mb-2">
            <Music className="w-4 h-4 text-primary-500" />
            <span className="text-sm text-gray-600 dark:text-gray-400">Key Signature</span>
          </div>
          <div className="text-2xl font-bold gradient-text">
            {keySignature}
          </div>
        </div>

        <div className="glass-panel p-4">
          <div className="flex items-center space-x-2 mb-2">
            <Gauge className="w-4 h-4 text-primary-500" />
            <span className="text-sm text-gray-600 dark:text-gray-400">Tempo</span>
          </div>
          <div className="text-2xl font-bold gradient-text">
            {analysis.bpm} BPM
          </div>
        </div>
      </div>

      <div className="mt-4">
        <div className="flex justify-between items-center mb-2">
          <span className="text-sm text-gray-600 dark:text-gray-400">Analysis Confidence</span>
          <span className="text-sm font-medium text-primary-500">{confidenceScore}%</span>
        </div>
        <div className="w-full h-2 bg-gray-200 dark:bg-gray-700 rounded-full overflow-hidden">
          <div 
            className="h-full bg-primary-500 rounded-full transition-all duration-500"
            style={{ width: `${confidenceScore}%` }}
          ></div>
        </div>
      </div>
    </div>
  );
}