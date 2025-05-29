import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { Music, Star, Download, Play, Pause, Instagram } from 'lucide-react';
import { useAuthStore } from '../stores/authStore';
import { useStorage } from '../hooks/useStorage';
import { supabase } from '../lib/supabase';
import { AudioPlayer } from '../components/AudioPlayer';
import FollowButton from '../components/FollowButton';
import FollowersModal from '../components/FollowersModal';
import { useFollowerCount } from '../hooks/useFollowerCount';
import toast from 'react-hot-toast';
import type { Profile } from '../types/database';

interface UserLoop {
  id: string;
  title: string;
  audio_url: string;
  bpm: number;
  key: string;
  downloads: number;
  average_rating: number;
}

export default function UserProfile() {
  const { username } = useParams<{ username: string }>();
  const navigate = useNavigate();
  const { user } = useAuthStore();
  const { getPublicUrl, downloadLoop } = useStorage();
  const [profileData, setProfileData] = useState<Profile | null>(null);
  const [userLoops, setUserLoops] = useState<UserLoop[]>([]);
  const [playingId, setPlayingId] = useState<string | null>(null);
  const { followers_count, following_count } = useFollowerCount(profileData?.id || '');
  const [loading, setLoading] = useState(false);
  const [showFollowersModal, setShowFollowersModal] = useState(false);
  const [showFollowingModal, setShowFollowingModal] = useState(false);

  useEffect(() => {
    if (username) {
      fetchUserProfile();
    }
  }, [username]);

  const fetchUserProfile = async () => {
    if (!username) return;

    setLoading(true);
    try {
      // Get profile with follower counts
      const { data: profiles, error } = await supabase
        .from('profiles')
        .select('*, followers_count, following_count')
        .eq('username', username);

      if (error) throw error;
      if (!profiles || profiles.length === 0) {
        navigate('/404');
        return;
      }

      const profile = profiles[0];

      // If this is the current user's profile, redirect to /profile
      if (user && profile.id === user.id) {
        navigate('/profile');
        return;
      }

      setProfileData(profile);
      fetchUserLoops(profile.id);
    } catch (error) {
      console.error('Error fetching profile:', error);
      toast.error('Failed to load profile');
      navigate('/404');
    } finally {
      setLoading(false);
    }
  };

  const fetchUserLoops = async (userId: string) => {
    try {
      const { data: loops, error } = await supabase
        .from('loops')
        .select('*')
        .eq('producer_id', userId)
        .order('created_at', { ascending: false });

      if (error) throw error;

      const loopsWithUrls = loops.map(loop => ({
        ...loop,
        audio_url: getPublicUrl(loop.audio_url)
      }));
      setUserLoops(loopsWithUrls);
    } catch (error) {
      console.error('Error fetching user loops:', error);
      toast.error('Failed to load loops');
    }
  };

  const handleFollowChange = async () => {
    if (!profileData) return;
    
    try {
      // Fetch fresh profile data with updated counts
      const { data: profile, error } = await supabase
        .from('profiles')
        .select('*, followers_count, following_count')
        .eq('username', profileData.username)
        .single();

      if (error) throw error;
      if (profile) {
        setProfileData(profile);
      }
    } catch (error) {
      console.error('Error refreshing profile:', error);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="w-16 h-16 border-4 border-primary-500 border-t-transparent rounded-full animate-spin"></div>
      </div>
    );
  }

  if (!profileData) return null;

  return (
    <div className="max-w-4xl mx-auto space-y-8 pt-24">
      <div className="glass-panel p-6">
        <div className="flex items-start justify-between mb-6">
          <div className="flex items-center space-x-4">
            <img 
              src={profileData.avatar_url || `https://ui-avatars.com/api/?name=${profileData.username}&background=8b5cf6&color=fff`}
              alt={profileData.username} 
              className="w-20 h-20 rounded-full object-cover"
            />
            <div>
              <h1 className="text-2xl font-bold gradient-text">{profileData.username}</h1>
              <div className="flex items-center space-x-2 mt-1">
                <Instagram className="w-4 h-4 text-gray-600 dark:text-gray-400" />
                {profileData.instagram_handle ? (
                  <a 
                    href={`https://instagram.com/${profileData.instagram_handle}`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-gray-600 dark:text-gray-400 hover:text-primary-500 transition-colors"
                  >
                    @{profileData.instagram_handle}
                  </a>
                ) : (
                  <span className="text-gray-500 dark:text-gray-500 text-sm italic">
                    No Instagram handle
                  </span>
                )}
              </div>
              <div className="flex items-center space-x-4 mt-2">
                <button 
                  onClick={() => setShowFollowersModal(true)}
                  className="text-sm text-gray-600 dark:text-gray-400 hover:text-primary-500 transition-colors"
                >
                  <strong>{followers_count}</strong> followers
                </button>
                <button
                  onClick={() => setShowFollowingModal(true)}
                  className="text-sm text-gray-600 dark:text-gray-400 hover:text-primary-500 transition-colors"
                >
                  <strong>{following_count}</strong> following
                </button>
              </div>
            </div>
          </div>
          <FollowButton 
            userId={profileData.id} 
            onFollowChange={handleFollowChange}
          />
        </div>

        <div className="grid grid-cols-3 gap-4 text-center">
          <div className="glass-panel p-4">
            <Music className="w-6 h-6 mx-auto mb-2 text-primary-500" />
            <div className="text-2xl font-bold gradient-text">{userLoops.length}</div>
            <div className="text-sm text-gray-600 dark:text-gray-400">Uploads</div>
          </div>
          <div className="glass-panel p-4">
            <Download className="w-6 h-6 mx-auto mb-2 text-primary-500" />
            <div className="text-2xl font-bold gradient-text">{profileData.total_downloads || 0}</div>
            <div className="text-sm text-gray-600 dark:text-gray-400">Downloads</div>
          </div>
          <div className="glass-panel p-4">
            <Star className="w-6 h-6 mx-auto mb-2 text-yellow-400" />
            <div className="text-2xl font-bold gradient-text">
              {profileData.average_loop_rating?.toFixed(1) || '0.0'}
            </div>
            <div className="text-sm text-gray-600 dark:text-gray-400">Avg Rating</div>
          </div>
        </div>
      </div>

      <div className="glass-panel p-6">
        <h2 className="text-xl font-bold gradient-text mb-4">Loops</h2>
        <div className="space-y-4">
          {userLoops.length === 0 ? (
            <p className="text-center text-gray-600 dark:text-gray-400">
              No loops uploaded yet.
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
                  </div>
                </div>

                <AudioPlayer
                  url={loop.audio_url}
                  isPlaying={playingId === loop.id}
                  onFinish={() => setPlayingId(null)}
                  producer={{
                    id: profileData.id,
                    username: profileData.username,
                    avatar_url: profileData.avatar_url
                  }}
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

      <FollowersModal
        isOpen={showFollowersModal}
        onClose={() => setShowFollowersModal(false)}
        userId={profileData.id}
        type="followers"
        title="Followers"
      />

      <FollowersModal
        isOpen={showFollowingModal}
        onClose={() => setShowFollowingModal(false)}
        userId={profileData.id}
        type="following"
        title="Following"
      />
    </div>
  );
}