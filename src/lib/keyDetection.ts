import FFT from 'fft.js';

// Define key profiles (Krumhansl-Kessler profiles)
const KEY_PROFILES = {
  major: [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88],
  minor: [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]
};

// Note names for each semitone
const NOTES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];

interface KeyResult {
  key: string;
  scale: 'major' | 'minor';
  confidence: number;
}

export async function detectKey(audioBuffer: AudioBuffer): Promise<KeyResult> {
  try {
    // Convert audio data to mono if necessary
    const monoData = convertToMono(audioBuffer);
    
    // Calculate chromagram
    const chromagram = computeChromagram(monoData, audioBuffer.sampleRate);
    
    // Find best matching key
    const keyResult = findKey(chromagram);
    
    return keyResult;
  } catch (error) {
    console.error('Key detection error:', error);
    return {
      key: 'C',
      scale: 'major',
      confidence: 0
    };
  }
}

function convertToMono(audioBuffer: AudioBuffer): Float32Array {
  const numChannels = audioBuffer.numberOfChannels;
  const length = audioBuffer.length;
  const monoData = new Float32Array(length);

  // Mix all channels to mono
  for (let i = 0; i < length; i++) {
    let sum = 0;
    for (let channel = 0; channel < numChannels; channel++) {
      sum += audioBuffer.getChannelData(channel)[i];
    }
    monoData[i] = sum / numChannels;
  }

  return monoData;
}

function computeChromagram(audioData: Float32Array, sampleRate: number): Float32Array {
  // Parameters for chromagram computation
  const fftSize = 4096;
  const hopSize = fftSize / 4;
  const fft = new FFT(fftSize);
  
  // Frequency to pitch class mapping
  const minFreq = 55; // A1
  const maxFreq = 7040; // A8
  const binsPerOctave = 12;
  
  // Initialize chromagram
  const chromagram = new Float32Array(12).fill(0);
  
  // Process audio in overlapping windows
  for (let start = 0; start < audioData.length - fftSize; start += hopSize) {
    // Apply Hanning window
    const windowed = new Float32Array(fftSize);
    for (let i = 0; i < fftSize; i++) {
      const windowValue = 0.5 * (1 - Math.cos(2 * Math.PI * i / fftSize));
      windowed[i] = audioData[start + i] * windowValue;
    }
    
    // Compute FFT
    const spectrum = new Float32Array(fftSize);
    fft.realTransform(spectrum, windowed);
    
    // Compute magnitude spectrum
    const magnitudes = new Float32Array(fftSize / 2);
    for (let i = 0; i < fftSize / 2; i++) {
      const real = spectrum[2 * i];
      const imag = spectrum[2 * i + 1];
      magnitudes[i] = Math.sqrt(real * real + imag * imag);
    }
    
    // Map frequencies to pitch classes
    for (let i = 0; i < fftSize / 2; i++) {
      const freq = i * sampleRate / fftSize;
      if (freq >= minFreq && freq <= maxFreq) {
        const pitchClass = Math.round(12 * Math.log2(freq / 440) + 69) % 12;
        chromagram[pitchClass] += magnitudes[i];
      }
    }
  }
  
  // Normalize chromagram
  const maxVal = Math.max(...chromagram);
  if (maxVal > 0) {
    for (let i = 0; i < 12; i++) {
      chromagram[i] /= maxVal;
    }
  }
  
  return chromagram;
}

function findKey(chromagram: Float32Array): KeyResult {
  let bestKey = 'C';
  let bestScale: 'major' | 'minor' = 'major';
  let bestCorrelation = -Infinity;
  let secondBestCorrelation = -Infinity;
  
  // Test all possible keys and scales
  for (const scale of ['major', 'minor'] as const) {
    const profile = KEY_PROFILES[scale];
    
    for (let transpose = 0; transpose < 12; transpose++) {
      let correlation = 0;
      
      // Compute correlation with key profile
      for (let i = 0; i < 12; i++) {
        const pitchClass = (i + transpose) % 12;
        correlation += chromagram[i] * profile[pitchClass];
      }
      
      // Update best match
      if (correlation > bestCorrelation) {
        secondBestCorrelation = bestCorrelation;
        bestCorrelation = correlation;
        bestKey = NOTES[transpose];
        bestScale = scale;
      } else if (correlation > secondBestCorrelation) {
        secondBestCorrelation = correlation;
      }
    }
  }
  
  // Compute confidence based on difference between best and second-best correlation
  const confidence = Math.max(0, Math.min(1, (bestCorrelation - secondBestCorrelation) / bestCorrelation));
  
  return {
    key: bestKey,
    scale: bestScale,
    confidence
  };
}