import { analyze } from 'web-audio-beat-detector';
import { detectKey } from './keyDetection';

export interface AudioAnalysis {
  key: string;
  scale: 'major' | 'minor';
  bpm: number;
  confidence: number;
}

export async function loadAudioBuffer(file: File): Promise<AudioBuffer> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    
    reader.onload = async (e) => {
      try {
        const arrayBuffer = e.target?.result as ArrayBuffer;
        if (!arrayBuffer) {
          throw new Error('Failed to read audio file');
        }

        const audioContext = new (window.AudioContext || window.webkitAudioContext)();
        const audioBuffer = await audioContext.decodeAudioData(arrayBuffer);
        
        if (!audioBuffer || audioBuffer.length === 0) {
          throw new Error('Invalid audio data');
        }

        resolve(audioBuffer);
      } catch (error) {
        reject(new Error('Failed to decode audio file'));
      }
    };
    
    reader.onerror = () => reject(new Error('Failed to read audio file'));
    reader.readAsArrayBuffer(file);
  });
}

export async function analyzeAudio(audioBuffer: AudioBuffer): Promise<AudioAnalysis> {
  try {
    if (!audioBuffer || audioBuffer.length === 0) {
      throw new Error('Invalid audio buffer');
    }

    // Run analyses in parallel for better performance
    const [tempo, keyAnalysis] = await Promise.all([
      analyze(audioBuffer),
      detectKey(audioBuffer)
    ]);

    return {
      key: keyAnalysis.key,
      scale: keyAnalysis.scale,
      bpm: Math.round(tempo),
      confidence: keyAnalysis.confidence
    };
  } catch (error: any) {
    console.error('Audio analysis failed:', error);
    throw new Error(error.message || 'Failed to analyze audio file');
  }
}