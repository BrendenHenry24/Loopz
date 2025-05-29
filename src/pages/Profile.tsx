import React, { useState, useEffect } from 'react';
import { Star, Music, Download, Settings, Trash2, Play, Pause, Instagram } from 'lucide-react';
import { useAuthStore } from '../stores/authStore';
import { useStorage } from '../hooks/useStorage';
import { supabase } from '../lib/supabase';
import { AudioPlayer } from '../components/AudioPlayer';
import AvatarUpload from '../components/AvatarUpload';
import PlanBadge from '../components/PlanBadge';
import SettingsModal from '../components/SettingsModal';
import StorageUsage from '../components/StorageUsage';
import toast from 'react-hot-toast';

interface UserLoop {
  id: string;
  title: string;
  audio_url: string;
  bpm: number;
  key: string;
  downloads: number;
  average_rating: number;
}

export default function Profile() {
  const { user } = useAuthStore();
  const { getPublicUrl, downloadLoop, deleteLoop } = useStorage();
  const [userLoops, setUserLoops] = useState<UserLoop[]>([]);
  const [playingId, setPlayingId] = useState<string | null>(null);
  const [followCounts, setFollowCounts] = useState({ followers_count: 0, following_count: 0 });
  const [showSettings, setShowSettings] = useState(false);
  const [isCropping, setIsCropping] = useState(false);

  // Get profile with membership tier
  useEffect(() => {
    if (user) {
      const fetchProfile = async () => {
        const { data } = await supabase
          .from('profiles')
          .select('*')
          .eq('id', user.id)
          .maybeSingle();
        
        if (data) {
          user.membership_tier = data.membership_tier;
        } else {
          // Create profile if it doesn't exist
          const { data: newProfile, error } = await supabase
            .from('profiles')
            .insert({
              id: user.id,
              email: user.email,
              username: user.email?.split('@')[0],
              membership_tier: 'basic'
            })
            .select()
            .single();

          if (!error && newProfile) {
            user.membership_tier = newProfile.membership_tier;
          }
        }
      };
      fetchProfile();
    }
  }, [user]);

  useEffect(() => {
    if (user) {
      fetchUserLoops();
      fetchFollowCounts();
    }
  }, [user]);

  const fetchUserLoops = async () => {
    try {
      const { data: loops, error } = await supabase
        .from('loops')
        .select('*')
        .eq('producer_id', user!.id)
        .order('created_at', { ascending: false });

      if (error) throw error;

      const loopsWithUrls = loops.map(loop => ({
        ...loop,
        audio_url: getPublicUrl(loop.audio_url)
      }));
      setUserLoops(loopsWithUrls);
    } catch (error) {
      console.error('Error fetching user loops:', error);
      toast.error('Failed to load your loops');
    }
  };

  const fetchFollowCounts = async () => {
    if (!user) return;
    try {
      const { data, error } = await supabase
        .from('profiles')
        .select('followers_count, following_count')
        .eq('id', user.id);

      if (error) throw error;
      if (data && data.length > 0) {
        setFollowCounts({
          followers_count: data[0].followers_count || 0,
          following_count: data[0].following_count || 0
        });
      } else {
        setFollowCounts({ followers_count: 0, following_count: 0 });
      }
    } catch (error) {
      console.error('Error fetching follow counts:', error);
      setFollowCounts({ followers_count: 0, following_count: 0 });
    }
  };

  const confirmDelete = async (loopId: string, title: string) => {
    if (window.confirm(`Are you sure you want to delete "${title}"? This action cannot be undone.`)) {
      try {
        const success = await deleteLoop(loopId);
        if (success) {
          setUserLoops(prev => prev.filter(loop => loop.id !== loopId));
          toast.success('Loop deleted');
        }
      } catch (error) {
        console.error('Delete error:', error);
        toast.error('Failed to delete loop');
      }
    }
  };

  return (
    <div className="max-w-4xl mx-auto space-y-8 pt-24">
      <div className="glass-panel p-6">
        <div className="flex items-start justify-between mb-6 relative">
          <div className="flex items-center space-x-4">
            <AvatarUpload
              url={user?.avatar_url}
              onUpload={(url) => {
                // Update local user state
                useAuthStore.setState(state => ({
                  user: state.user ? { ...state.user, avatar_url: url } : null
                }));
              }}
              onCropStart={() => setIsCropping(true)}
              onCropEnd={() => setIsCropping(false)}
              size={80}
              className="relative z-20"
            />
            <div>
              <div className="flex items-center space-x-3">
                <h1 className="text-2xl font-bold gradient-text">{user?.display_name}</h1>
                <div className="ml-2">
                  <PlanBadge tier={user?.membership_tier || 'basic'} />
                </div>
              </div>
              <div className="flex items-center space-x-2 mt-1 text-gray-600 dark:text-gray-400">
                <span>{user?.username}</span>
                <span>•</span>
                <Instagram className="w-4 h-4 text-gray-600 dark:text-gray-400" />
                {user?.instagram_handle ? (
                  <a 
                    href={`https://instagram.com/${user.instagram_handle}`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="hover:text-primary-500 transition-colors"
                  >
                    @{user.instagram_handle}
                  </a>
                ) : (
                  <span className="text-gray-500 dark:text-gray-500 text-sm italic">
                    No Instagram handle
                  </span>
                )}
              </div>
              <div className="flex items-center space-x-4 mt-2">
                <span className="text-sm text-gray-600 dark:text-gray-400">
                  <strong>{followCounts.followers_count}</strong> followers
                </span>
                <span className="text-sm text-gray-600 dark:text-gray-400">
                  <strong>{followCounts.following_count}</strong> following
                </span>
              </div>
            </div>
          </div>
          <div className="flex items-center space-x-3">
            <button 
              onClick={() => setShowSettings(true)}
              className="text-gray-600 dark:text-gray-400 hover:text-primary-500 transition-colors"
            >
              <Settings className="w-6 h-6" />
            </button>
          </div>
        </div>

        <div className="grid grid-cols-3 gap-4 text-center">
          <div className="glass-panel p-4">
            <Music className="w-6 h-6 mx-auto mb-2 text-primary-500" />
            <div className="text-2xl font-bold gradient-text">{userLoops.length}</div>
            <div className="text-sm text-gray-600 dark:text-gray-400">Uploads</div>
          </div>
          <div className="glass-panel p-4">
            <Download className="w-6 h-6 mx-auto mb-2 text-primary-500" />
            <div className="text-2xl font-bold gradient-text">{user?.total_downloads || 0}</div>
            <div className="text-sm text-gray-600 dark:text-gray-400">Downloads</div>
          </div>
          <div className="glass-panel p-4">
            <Star className="w-6 h-6 mx-auto mb-2 text-yellow-400" />
            <div className="text-2xl font-bold gradient-text">
              {user?.average_loop_rating?.toFixed(1) || '0.0'}
            </div>
            <div className="text-sm text-gray-600 dark:text-gray-400">Avg Rating</div>
          </div>
        </div>
      </div>

      {showSettings && (
        <SettingsModal 
          isOpen={showSettings} 
          onClose={() => setShowSettings(false)} 
        />
      )}

      {!isCropping && (
        <div className="relative z-10">
          <StorageUsage />
        </div>
      )}

      {!isCropping && (
        <div className="glass-panel p-6">
          <h2 className="text-xl font-bold gradient-text mb-4">Your Loops</h2>
          <div className="space-y-4">
            {userLoops.length === 0 ? (
              <p className="text-center text-gray-600 dark:text-gray-400">
                You haven't uploaded any loops yet.
              </p>
            ) : (
              userLoops.map(loop => (
                <div key={loop.id} className="glass-panel p-4">
                <div className="flex items-center justify-between mb-4">
                  <div>
                    <h3 className="font-medium text-gray-900 dark:text-white">{loop.title}</h3>
                    <p className="text-sm text-gray-500 dark:text-gray-400">
                      {loop.bpm} BPM • {loop.key}
                    </p>
                  </div>
                  <div className="flex items-center space-x-2">
                    <button
                      onClick={() => setPlayingId(playingId === loop.id ? null : loop.id)}
                      className="p-2 rounded-full bg-primary-500/10 hover:bg-primary-500 text-primary-600 hover:text-white transition-colors duration-300"
                    >
                      {playingId === loop.id ? 
                        <Pause className="w-4 h-4" /> : 
                        <Play className="w-4 h-4" />
                      }
                    </button>
                    <button
                      onClick={() => downloadLoop(loop.id, loop.audio_url)}
                      className="p-2 rounded-full bg-gray-100 hover:bg-primary-500 dark:bg-gray-700 text-gray-600 hover:text-white dark:text-gray-400 dark:hover:text-white transition-colors duration-300"
                    >
                      <Download className="w-4 h-4" />
                    </button>
                    <button
                      onClick={() => confirmDelete(loop.id, loop.title)}
                      className="p-2 rounded-full bg-gray-100 hover:bg-red-500 dark:bg-gray-700 text-gray-600 hover:text-white dark:text-gray-400 dark:hover:text-white transition-colors duration-300"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                </div>

                <AudioPlayer
                  url={loop.audio_url}
                  isPlaying={playingId === loop.id}
                  onFinish={() => setPlayingId(null)}
                />

                <div className="flex items-center justify-between mt-3 text-sm text-gray-600 dark:text-gray-400">
                  <div className="flex items-center space-x-4">
                    <span className="flex items-center">
                      <Star className="w-4 h-4 text-yellow-400 mr-1" />
                      {loop.average_rating.toFixed(1)}
                    </span>
                    <span>{loop.downloads} downloads</span>
                  </div>
                </div>
                </div>
              ))
            )}
          </div>
        </div>
      )}
    </div>
  );
}