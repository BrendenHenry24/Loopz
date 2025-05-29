import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';

interface FollowerCounts {
  followers_count: number;
  following_count: number;
}

export function useFollowerCount(userId: string) {
  const [counts, setCounts] = useState<FollowerCounts>({
    followers_count: 0,
    following_count: 0
  });

  useEffect(() => {
    if (!userId) return;

    // Initial fetch
    fetchCounts();

    // Set up realtime subscription
    const channel = supabase.channel('follower_counts')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'follows',
          filter: `following_id=eq.${userId}`
        },
        () => fetchCounts()
      )
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'follows',
          filter: `follower_id=eq.${userId}`
        },
        () => fetchCounts()
      )
      .subscribe();

    // Cleanup subscription
    return () => {
      channel.unsubscribe();
    };
  }, [userId]);

  const fetchCounts = async () => {
    try {
      const { data, error } = await supabase
        .from('profiles')
        .select('followers_count, following_count')
        .eq('id', userId)
        .single();

      if (error) throw error;

      if (data) {
        setCounts({
          followers_count: data.followers_count || 0,
          following_count: data.following_count || 0
        });
      }
    } catch (error) {
      console.error('Error fetching follower counts:', error);
    }
  };

  return counts;
}