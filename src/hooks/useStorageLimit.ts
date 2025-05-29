import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useAuthStore } from '../stores/authStore';
import { MEMBERSHIP_LIMITS } from '../types/membership';
import toast from 'react-hot-toast';

export function useStorageLimit() {
  const { user } = useAuthStore();
  const [storageUsed, setStorageUsed] = useState(0);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    if (user) {
      fetchStorageUsed();
    }
  }, [user]);

  const fetchStorageUsed = async () => {
    try {
      const { data: loops, error } = await supabase
        .from('loops')
        .select('file_size')
        .eq('producer_id', user!.id);

      if (error) throw error;

      const totalSize = loops?.reduce((sum, loop) => sum + (loop.file_size || 0), 0) || 0;
      setStorageUsed(totalSize);
    } catch (error) {
      console.error('Error fetching storage used:', error);
      toast.error('Failed to fetch storage usage');
    } finally {
      setIsLoading(false);
    }
  };

  const checkStorageLimit = (fileSize: number) => {
    if (!user) return false;

    const tier = user.membership_tier || 'basic';
    const limit = MEMBERSHIP_LIMITS[tier].storageLimit;
    const wouldExceedLimit = storageUsed + fileSize > limit;

    if (wouldExceedLimit) {
      toast.error(`Upload would exceed your ${tier} storage limit of ${formatBytes(limit)}`);
      return false;
    }

    return true;
  };

  const formatBytes = (bytes: number) => {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  };

  return {
    storageUsed,
    isLoading,
    checkStorageLimit,
    formatBytes
  };
}