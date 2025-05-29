import React, { useEffect, useRef, useState } from 'react';
import { Howl } from 'howler';
import { Volume2, VolumeX, Star } from 'lucide-react';
import Waveform from './Waveform';
import ProducerLink from './ProducerLink';
import RatingModal from './RatingModal';
import { useAuthStore } from '../stores/authStore';
import { useRealtimeSubscription } from '../hooks/useRealtimeSubscription';
import toast from 'react-hot-toast';

interface AudioPlayerProps {
  url: string;
  isPlaying: boolean;
  onFinish: () => void;
  loopId?: string;
  producer?: {
    id: string;
    username: string;
    avatar_url?: string;
  };
  rating?: number;
  onRatingChange?: (newRating: number) => void;
}

export function AudioPlayer({ 
  url, 
  isPlaying, 
  onFinish, 
  loopId,
  producer,
  rating = 0,
  onRatingChange 
}: AudioPlayerProps) {
  const { user } = useAuthStore();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [progress, setProgress] = useState(0);
  const [duration, setDuration] = useState(0);
  const [isMuted, setIsMuted] = useState(false);
  const [showRatingModal, setShowRatingModal] = useState(false);
  const howlRef = useRef<Howl | null>(null);
  const progressInterval = useRef<number>();

  // Subscribe to rating changes
  useRealtimeSubscription(
    'ratings',
    'UPDATE',
    (payload) => {
      if (payload.new && payload.new.loop_id === loopId) {
        onRatingChange?.(payload.new.rating);
      }
    },
    loopId ? `loop_id=eq.${loopId}` : undefined
  );

  useEffect(() => {
    const initializeAudio = () => {
      if (howlRef.current) {
        howlRef.current.unload();
      }

      try {
        howlRef.current = new Howl({
          src: [url],
          html5: true,
          preload: true,
          format: ['mp3', 'wav', 'm4a', 'aac'],
          onload: () => {
            setLoading(false);
            setError(null);
            setDuration(howlRef.current?.duration() || 0);
          },
          onloaderror: () => {
            console.error('Audio loading error');
            setError('Failed to load audio');
            setLoading(false);
          },
          onend: () => {
            setProgress(0);
            onFinish();
          }
        });
      } catch (error: any) {
        console.error('Audio initialization error:', error);
        setError('Failed to initialize audio');
        setLoading(false);
      }
    };

    if (url) {
      initializeAudio();
    }

    return () => {
      if (howlRef.current) {
        howlRef.current.unload();
      }
      stopProgressTracking();
    };
  }, [url]);

  useEffect(() => {
    if (!howlRef.current || loading || error) return;

    if (isPlaying) {
      howlRef.current.play();
      startProgressTracking();
    } else {
      howlRef.current.pause();
      stopProgressTracking();
    }

    return () => stopProgressTracking();
  }, [isPlaying, loading, error]);

  const startProgressTracking = () => {
    if (progressInterval.current) {
      window.clearInterval(progressInterval.current);
    }

    progressInterval.current = window.setInterval(() => {
      if (howlRef.current) {
        setProgress(howlRef.current.seek() as number);
      }
    }, 100);
  };

  const stopProgressTracking = () => {
    if (progressInterval.current) {
      window.clearInterval(progressInterval.current);
      progressInterval.current = undefined;
    }
  };

  const handleSeek = (position: number) => {
    if (!howlRef.current || loading || error) return;
    howlRef.current.seek(position);
    setProgress(position);
  };

  const toggleMute = () => {
    if (!howlRef.current || loading || error) return;
    const newMuteState = !isMuted;
    howlRef.current.mute(newMuteState);
    setIsMuted(newMuteState);
  };

  const formatTime = (seconds: number): string => {
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  const handleRatingClick = () => {
    if (!user) {
      toast.error('Please sign in to rate loops');
      return;
    }
    if (!loopId) return;

    // Check if user is trying to rate their own loop
    if (user.id === producer?.id) {
      toast.error("You can't rate your own loops!");
      return;
    }

    setShowRatingModal(true);
  };

  return (
    <div className="relative bg-white/5 dark:bg-black/5 rounded-lg p-4">
      {producer && (
        <div className="mb-3">
          <ProducerLink producer={producer} className="text-sm text-gray-600 dark:text-gray-400" />
        </div>
      )}

      <div className="relative z-10">
        <Waveform
          url={url}
          progress={progress}
          duration={duration}
          onSeek={handleSeek}
          isPlaying={isPlaying}
          howl={howlRef.current}
        />
      </div>

      <div className="flex items-center justify-between mt-2 relative z-10">
        <div className="flex items-center space-x-4">
          <button
            onClick={toggleMute}
            className="p-1 rounded-full hover:bg-white/10 transition-colors"
          >
            {isMuted ? 
              <VolumeX className="w-4 h-4 text-gray-500" /> : 
              <Volume2 className="w-4 h-4 text-gray-500" />
            }
          </button>
          <span className="text-sm text-gray-500">
            {formatTime(progress)} / {formatTime(duration)}
          </span>
          {loopId && (
            <button
              onClick={handleRatingClick}
              className="flex items-center space-x-1 text-gray-500 hover:text-yellow-400 transition-colors"
            >
              <Star className={`w-4 h-4 ${rating > 0 ? 'fill-yellow-400 text-yellow-400' : ''}`} />
              <span>{rating > 0 ? rating.toFixed(1) : 'Rate'}</span>
            </button>
          )}
        </div>

        {error && (
          <span className="text-sm text-red-500">
            {error}
          </span>
        )}
      </div>

      {loading && (
        <div className="absolute inset-0 flex items-center justify-center bg-white/50 dark:bg-black/50 rounded-lg z-20">
          <div className="w-6 h-6 border-2 border-primary-500 border-t-transparent rounded-full animate-spin" />
        </div>
      )}

      {showRatingModal && loopId && (
        <RatingModal
          isOpen={showRatingModal}
          onClose={() => setShowRatingModal(false)}
          loopId={loopId}
          producerId={producer?.id}
          onRatingSubmit={(newRating) => {
            if (onRatingChange) {
              onRatingChange(newRating);
            }
          }}
        />
      )}
    </div>
  );
}