import React, { useEffect, useRef, useState } from 'react';
import type { Howl } from 'howler';

interface WaveformProps {
  url: string;
  progress: number;
  duration: number;
  onSeek: (position: number) => void;
  isPlaying: boolean;
  howl: Howl | null;
}

export default function Waveform({ url, progress, duration, onSeek, isPlaying, howl }: WaveformProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const [error, setError] = useState(false);
  const [waveformData, setWaveformData] = useState<number[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    let isSubscribed = true;
    const abortController = new AbortController();

    const loadAudio = async () => {
      try {
        setIsLoading(true);
        setError(false);

        const response = await fetch(url, {
          signal: abortController.signal
        });
        
        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        const arrayBuffer = await response.arrayBuffer();
        const audioContext = new (window.AudioContext || window.webkitAudioContext)();
        
        const audioBuffer = await audioContext.decodeAudioData(arrayBuffer);
        if (!isSubscribed) return;
        
        // Get audio data and compute waveform with higher resolution
        const channelData = audioBuffer.getChannelData(0);
        const samples = 800; // Increased for better resolution
        const blockSize = Math.floor(channelData.length / samples);
        const data: number[] = [];
        
        // Process audio data in chunks with advanced peak detection
        for (let i = 0; i < samples; i++) {
          let blockStart = i * blockSize;
          let blockEnd = blockStart + blockSize;
          let min = Infinity;
          let max = -Infinity;
          let sum = 0;
          let count = 0;
          
          // Find min, max, and RMS values in each block
          for (let j = blockStart; j < blockEnd && j < channelData.length; j++) {
            const value = channelData[j];
            min = Math.min(min, value);
            max = Math.max(max, value);
            sum += value * value;
            count++;
          }
          
          // Calculate RMS (Root Mean Square) for better amplitude representation
          const rms = Math.sqrt(sum / count);
          
          // Use a combination of peak-to-peak and RMS values for better visualization
          const value = Math.max(Math.abs(max - min), rms * 2);
          data.push(value);
        }

        // Normalize the data with dynamic range compression
        const maxValue = Math.max(...data);
        const normalizedData = data.map(value => {
          const normalized = value / maxValue;
          // Apply non-linear scaling to make quieter parts more visible
          return Math.pow(normalized, 0.7);
        });
        
        setWaveformData(normalizedData);
        setError(false);
      } catch (error: any) {
        if (error.name === 'AbortError') return;
        
        console.error('Error loading audio for waveform:', error);
        setError(true);
        setWaveformData([]);
      } finally {
        if (isSubscribed) {
          setIsLoading(false);
        }
      }
    };

    if (url && howl) {
      loadAudio();
    }

    return () => {
      isSubscribed = false;
      abortController.abort();
    };
  }, [url, howl]);

  useEffect(() => {
    const draw = () => {
      const canvas = canvasRef.current;
      if (!canvas) return;

      const ctx = canvas.getContext('2d');
      if (!ctx) return;

      // Clear canvas
      ctx.clearRect(0, 0, canvas.width, canvas.height);

      if (error || waveformData.length === 0) {
        // Draw placeholder waveform
        const centerY = canvas.height / 2;
        const amplitude = canvas.height / 4;
        const frequency = 0.02;
        const phase = 0;

        ctx.beginPath();
        ctx.moveTo(0, centerY);

        for (let x = 0; x < canvas.width; x++) {
          const y = centerY + Math.sin(x * frequency + phase) * amplitude * 0.3;
          ctx.lineTo(x, y);
        }

        ctx.strokeStyle = 'rgba(139, 92, 246, 0.3)'; // primary-500 with opacity
        ctx.lineWidth = 2;
        ctx.stroke();
        return;
      }

      const barWidth = canvas.width / waveformData.length;
      const heightMultiplier = canvas.height * 0.8; // Use 80% of canvas height
      const progressPosition = (progress / duration) * canvas.width;

      // Draw mirrored waveform with anti-aliasing
      ctx.imageSmoothingEnabled = true;
      ctx.imageSmoothingQuality = 'high';

      waveformData.forEach((value, index) => {
        const x = index * barWidth;
        const height = value * heightMultiplier;
        const y = (canvas.height - height) / 2;

        // Determine if this bar should be highlighted (played) or not
        const isPlayed = x <= progressPosition;
        
        // Draw top and bottom bars with gradient
        const gradient = ctx.createLinearGradient(x, 0, x, canvas.height);
        if (isPlayed) {
          gradient.addColorStop(0, 'rgba(139, 92, 246, 0.9)');
          gradient.addColorStop(0.5, 'rgba(139, 92, 246, 0.7)');
          gradient.addColorStop(1, 'rgba(139, 92, 246, 0.9)');
        } else {
          gradient.addColorStop(0, 'rgba(139, 92, 246, 0.4)');
          gradient.addColorStop(0.5, 'rgba(139, 92, 246, 0.2)');
          gradient.addColorStop(1, 'rgba(139, 92, 246, 0.4)');
        }
        ctx.fillStyle = gradient;

        // Draw bars with rounded corners
        const barHeight = height / 2;
        const radius = Math.min(barWidth / 2, barHeight / 2, 2);

        // Top bar
        ctx.beginPath();
        ctx.moveTo(x + radius, y);
        ctx.lineTo(x + barWidth - radius, y);
        ctx.quadraticCurveTo(x + barWidth, y, x + barWidth, y + radius);
        ctx.lineTo(x + barWidth, y + barHeight - radius);
        ctx.quadraticCurveTo(x + barWidth, y + barHeight, x + barWidth - radius, y + barHeight);
        ctx.lineTo(x + radius, y + barHeight);
        ctx.quadraticCurveTo(x, y + barHeight, x, y + barHeight - radius);
        ctx.lineTo(x, y + radius);
        ctx.quadraticCurveTo(x, y, x + radius, y);
        ctx.fill();

        // Bottom bar (mirrored)
        ctx.beginPath();
        ctx.moveTo(x + radius, canvas.height - y - barHeight);
        ctx.lineTo(x + barWidth - radius, canvas.height - y - barHeight);
        ctx.quadraticCurveTo(x + barWidth, canvas.height - y - barHeight, x + barWidth, canvas.height - y - barHeight + radius);
        ctx.lineTo(x + barWidth, canvas.height - y - radius);
        ctx.quadraticCurveTo(x + barWidth, canvas.height - y, x + barWidth - radius, canvas.height - y);
        ctx.lineTo(x + radius, canvas.height - y);
        ctx.quadraticCurveTo(x, canvas.height - y, x, canvas.height - y - radius);
        ctx.lineTo(x, canvas.height - y - barHeight + radius);
        ctx.quadraticCurveTo(x, canvas.height - y - barHeight, x + radius, canvas.height - y - barHeight);
        ctx.fill();
      });
    };

    draw();

    // Animate loading state
    if (isLoading) {
      const animationFrame = requestAnimationFrame(draw);
      return () => cancelAnimationFrame(animationFrame);
    }
  }, [waveformData, progress, duration, error, isLoading]);

  const handleClick = (e: React.MouseEvent<HTMLDivElement>) => {
    if (error || !containerRef.current) return;

    const rect = containerRef.current.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const position = (x / rect.width) * duration;
    onSeek(Math.max(0, Math.min(position, duration)));
  };

  return (
    <div 
      ref={containerRef}
      onClick={handleClick}
      className="relative w-full h-16 cursor-pointer"
    >
      <canvas
        ref={canvasRef}
        width={1600} // Increased resolution for sharper rendering
        height={200}
        className={`absolute top-0 left-0 w-full h-full rounded-lg bg-white/5 dark:bg-black/5 
          ${error ? 'opacity-50' : ''}`}
      />
      <div className="absolute inset-0" />
    </div>
  );
}