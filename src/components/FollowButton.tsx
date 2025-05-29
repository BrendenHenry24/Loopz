import React, { useState, useEffect } from 'react';
import { UserPlus, UserMinus, Loader2 } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuthStore } from '../stores/authStore';
import { useNavigate } from 'react-router-dom';
import { useRealtimeSubscription } from '../hooks/useRealtimeSubscription';
import toast from 'react-hot-toast';

interface FollowButtonProps {
  userId: string;
  onFollowChange?: (isFollowing: boolean) => void;
}

export default function FollowButton({ userId, onFollowChange }: FollowButtonProps) {
  const { user } = useAuthStore();
  const navigate = useNavigate();
  const [isFollowing, setIsFollowing] = useState(false);
  const [loading, setLoading] = useState(false);

  // Don't show button if viewing own profile
  if (!user || userId === user.id) return null;

  useEffect(() => {
    checkFollowStatus();
  }, [user, userId]);

  // Subscribe to follow changes
  useRealtimeSubscription(
    'follows',
    'INSERT',
    (payload) => {
      if (payload.new.following_id === userId && payload.new.follower_id === user?.id) {
        setIsFollowing(true);
        onFollowChange?.(true);
      }
    }
  );

  useRealtimeSubscription(
    'follows',
    'DELETE',
    (payload) => {
      if (payload.old.following_id === userId && payload.old.follower_id === user?.id) {
        setIsFollowing(false);
        onFollowChange?.(false);
      }
    }
  );

  const checkFollowStatus = async () => {
    if (!user) return;
    
    try {
      const { data, error } = await supabase
        .from('follows')
        .select('id')
        .eq('follower_id', user.id)
        .eq('following_id', userId)
        .maybeSingle();

      if (error) throw error;
      setIsFollowing(!!data);
    } catch (error) {
      console.error('Error checking follow status:', error);
    }
  };

  const handleFollow = async () => {
    if (!user) {
      navigate('/auth');
      toast.error('Please sign in to follow users');
      return;
    }

    setLoading(true);
    try {
      if (isFollowing) {
        // Unfollow
        const { error } = await supabase
          .from('follows')
          .delete()
          .eq('follower_id', user.id)
          .eq('following_id', userId);

        if (error) throw error;
      } else {
        // Follow
        const { error } = await supabase
          .from('follows')
          .insert({
            follower_id: user.id,
            following_id: userId
          });

        if (error) throw error;
      }

      // Toggle local state
      setIsFollowing(!isFollowing);
      
      // Show success message
      toast.success(isFollowing ? 'Unfollowed user' : 'Following user');
      
      // Notify parent component
      if (onFollowChange) {
        onFollowChange(!isFollowing);
      }

    } catch (error: any) {
      console.error('Follow error:', error);
      toast.error(error.message || 'Failed to update follow status');
      // Recheck follow status in case of error
      await checkFollowStatus();
    } finally {
      setLoading(false);
    }
  };

  return (
    <button
      onClick={handleFollow}
      disabled={loading}
      className={`flex items-center space-x-1 px-4 py-2 rounded-lg transition-colors
        ${isFollowing
          ? 'bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700'
          : 'bg-primary-500 text-white hover:bg-primary-600'
        } ${loading ? 'opacity-50 cursor-not-allowed' : ''}`}
    >
      {loading ? (
        <Loader2 className="w-4 h-4 animate-spin" />
      ) : isFollowing ? (
        <>
          <UserMinus className="w-4 h-4" />
          <span>Unfollow</span>
        </>
      ) : (
        <>
          <UserPlus className="w-4 h-4" />
          <span>Follow</span>
        </>
      )}
    </button>
  );
}