import React, { useState } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { Music, Activity, Play, Pause } from 'lucide-react';
import { useStorage } from '../hooks/useStorage';
import { AudioPlayer } from '../components/AudioPlayer';
import AudioAnalysisDisplay from '../components/AudioAnalysis';
import toast from 'react-hot-toast';
import type { AudioAnalysis } from '../lib/audioAnalysis';

interface LocationState {
  file: File;
  analysis: AudioAnalysis;
  preview: string;
}

// Musical keys with sharp notation only
const MUSICAL_KEYS = [
  { value: 'C', label: 'C Major' },
  { value: 'Cm', label: 'C Minor' },
  { value: 'C#', label: 'C♯ Major' },
  { value: 'C#m', label: 'C♯ Minor' },
  { value: 'D', label: 'D Major' },
  { value: 'Dm', label: 'D Minor' },
  { value: 'D#', label: 'D♯ Major' },
  { value: 'D#m', label: 'D♯ Minor' },
  { value: 'E', label: 'E Major' },
  { value: 'Em', label: 'E Minor' },
  { value: 'F', label: 'F Major' },
  { value: 'Fm', label: 'F Minor' },
  { value: 'F#', label: 'F♯ Major' },
  { value: 'F#m', label: 'F♯ Minor' },
  { value: 'G', label: 'G Major' },
  { value: 'Gm', label: 'G Minor' },
  { value: 'G#', label: 'G♯ Major' },
  { value: 'G#m', label: 'G♯ Minor' },
  { value: 'A', label: 'A Major' },
  { value: 'Am', label: 'A Minor' },
  { value: 'A#', label: 'A♯ Major' },
  { value: 'A#m', label: 'A♯ Minor' },
  { value: 'B', label: 'B Major' },
  { value: 'Bm', label: 'B Minor' }
];

export default function LoopAnalysis() {
  const navigate = useNavigate();
  const location = useLocation();
  const { uploadLoop } = useStorage();
  const [uploading, setUploading] = useState(false);
  const [isPlaying, setIsPlaying] = useState(false);

  // Get the file and analysis data from navigation state
  const state = location.state as LocationState;
  
  if (!state?.file || !state?.analysis || !state?.preview) {
    return (
      <div className="text-center py-12">
        <p className="text-gray-600 dark:text-gray-400">
          No loop selected. Please upload a loop first.
        </p>
        <button
          onClick={() => navigate('/upload')}
          className="mt-4 px-6 py-2 bg-primary-500 text-white rounded-lg hover:bg-primary-600 transition-colors"
        >
          Go to Upload
        </button>
      </div>
    );
  }

  const { file, analysis, preview } = state;

  const [form, setForm] = useState({
    title: '',
    genre: '',
    tags: '',
    description: '',
    bpm: analysis.bpm,
    key: `${analysis.key}${analysis.scale === 'minor' ? 'm' : ''}`
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!form.title.trim()) {
      toast.error('Please enter a title for your loop');
      return;
    }

    setUploading(true);
    try {
      await uploadLoop(file, {
        title: form.title.trim(),
        bpm: form.bpm,
        key: form.key
      });
      
      navigate('/profile');
    } catch (error) {
      console.error('Upload error:', error);
    } finally {
      setUploading(false);
    }
  };

  return (
    <div className="max-w-3xl mx-auto space-y-8">
      <div className="text-center">
        <h1 className="text-3xl font-bold gradient-text mb-4">Loop Analysis Results</h1>
        <p className="text-gray-600 dark:text-gray-400">
          Review the analysis and provide additional details about your loop
        </p>
      </div>

      <div className="glass-panel p-6 space-y-6">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-4">
            <Music className="w-6 h-6 text-primary-500" />
            <div>
              <h2 className="text-lg font-semibold">{file.name}</h2>
              <p className="text-sm text-gray-500 dark:text-gray-400">
                {(file.size / (1024 * 1024)).toFixed(2)} MB
              </p>
            </div>
          </div>
          <button
            onClick={() => setIsPlaying(!isPlaying)}
            className="p-3 rounded-full bg-primary-500/10 hover:bg-primary-500 
                     text-primary-600 hover:text-white transition-colors duration-300"
          >
            {isPlaying ? <Pause className="w-5 h-5" /> : <Play className="w-5 h-5" />}
          </button>
        </div>

        <AudioPlayer
          url={preview}
          isPlaying={isPlaying}
          onFinish={() => setIsPlaying(false)}
        />

        <AudioAnalysisDisplay analysis={analysis} isLoading={false} />
      </div>

      <form onSubmit={handleSubmit} className="glass-panel p-6 space-y-6">
        <h2 className="text-xl font-bold gradient-text">Loop Details</h2>

        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
              Title *
            </label>
            <input
              type="text"
              value={form.title}
              onChange={e => setForm(prev => ({ ...prev, title: e.target.value }))}
              className="w-full glass-input px-3 py-2"
              placeholder="Give your loop a name"
              required
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
              Genre
            </label>
            <input
              type="text"
              value={form.genre}
              onChange={e => setForm(prev => ({ ...prev, genre: e.target.value }))}
              className="w-full glass-input px-3 py-2"
              placeholder="e.g., Hip Hop, House, Trap"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
              Tags
            </label>
            <input
              type="text"
              value={form.tags}
              onChange={e => setForm(prev => ({ ...prev, tags: e.target.value }))}
              className="w-full glass-input px-3 py-2"
              placeholder="Separate tags with commas"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
              Description
            </label>
            <textarea
              value={form.description}
              onChange={e => setForm(prev => ({ ...prev, description: e.target.value }))}
              className="w-full glass-input px-3 py-2"
              rows={3}
              placeholder="Tell others about your loop"
            />
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                BPM
              </label>
              <input
                type="number"
                value={form.bpm}
                onChange={e => setForm(prev => ({ ...prev, bpm: parseInt(e.target.value) || 120 }))}
                className="w-full glass-input px-3 py-2"
                min="1"
                max="999"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                Key
              </label>
              <select
                value={form.key}
                onChange={e => setForm(prev => ({ ...prev, key: e.target.value }))}
                className="w-full glass-input px-3 py-2 text-gray-900 dark:text-white bg-transparent dark:bg-transparent"
              >
                {MUSICAL_KEYS.map(({ value, label }) => (
                  <option key={value} value={value} className="bg-white dark:bg-gray-800">
                    {label}
                  </option>
                ))}
              </select>
            </div>
          </div>
        </div>

        <div className="flex justify-end space-x-4">
          <button
            type="button"
            onClick={() => navigate('/upload')}
            className="px-4 py-2 text-gray-600 dark:text-gray-400 hover:text-gray-800 dark:hover:text-gray-200"
          >
            Cancel
          </button>
          <button
            type="submit"
            disabled={uploading}
            className={`px-6 py-2 bg-primary-500 text-white rounded-lg 
              ${uploading 
                ? 'opacity-50 cursor-not-allowed' 
                : 'hover:bg-primary-600 transition-colors'
              }`}
          >
            {uploading ? 'Uploading...' : 'Upload Loop'}
          </button>
        </div>
      </form>
    </div>
  );
}