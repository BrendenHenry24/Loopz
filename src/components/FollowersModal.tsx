import React, { useState, useEffect } from 'react';
import { X, Loader2 } from 'lucide-react';
import { supabase } from '../lib/supabase';
import ProducerLink from './ProducerLink';
import FollowButton from './FollowButton';
import { useAuthStore } from '../stores/authStore';

interface FollowersModalProps {
  isOpen: boolean;
  onClose: () => void;
  userId: string;
  type: 'followers' | 'following';
  title: string;
}

interface FollowUser {
  id: string;
  username: string;
  avatar_url: string | null;
}

export default function FollowersModal({ isOpen, onClose, userId, type, title }: FollowersModalProps) {
  const [users, setUsers] = useState<FollowUser[]>([]);
  const [loading, setLoading] = useState(true);
  const { user: currentUser } = useAuthStore();

  useEffect(() => {
    if (isOpen) {
      fetchUsers();
    }
  }, [isOpen, userId, type]);

  const fetchUsers = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('follows')
        .select(`
          ${type === 'followers' ? 'follower:follower_id' : 'following:following_id'}(
            id,
            username,
            avatar_url
          )
        `)
        .eq(type === 'followers' ? 'following_id' : 'follower_id', userId);

      if (error) throw error;

      const formattedUsers = data.map(item => ({
        ...(type === 'followers' ? item.follower : item.following)
      }));

      setUsers(formattedUsers);
    } catch (error) {
      console.error('Error fetching users:', error);
    } finally {
      setLoading(false);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50">
      <div className="relative w-full max-w-md glass-panel p-6 max-h-[80vh] flex flex-col">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-xl font-bold gradient-text">{title}</h3>
          <button
            onClick={onClose}
            className="p-1 text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {loading ? (
          <div className="flex items-center justify-center py-8">
            <Loader2 className="w-8 h-8 animate-spin text-primary-500" />
          </div>
        ) : users.length === 0 ? (
          <p className="text-center text-gray-600 dark:text-gray-400 py-8">
            No {type} yet
          </p>
        ) : (
          <div className="overflow-y-auto flex-grow">
            <div className="space-y-4">
              {users.map(user => (
                <div key={user.id} className="flex items-center justify-between p-2">
                  <ProducerLink producer={user} />
                  {currentUser?.id !== user.id && (
                    <FollowButton 
                      userId={user.id}
                      onFollowChange={fetchUsers}
                    />
                  )}
                </div>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}