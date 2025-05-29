import { supabase } from './supabase';
import type { Loop, Profile } from '../types/database';

interface SearchParams {
  query?: string;
  bpmRange?: string;
  key?: string;
  sortBy?: 'newest' | 'downloads' | 'rating';
  limit?: number;
}

export const api = {
  profiles: {
    async getByUsername(username: string) {
      try {
        const { data, error } = await supabase
          .from('profiles')
          .select(`
            *,
            followers_count,
            following_count
          `)
          .eq('username', username)
          .single();

        if (error) throw error;
        return data;
      } catch (error) {
        console.error('Error fetching profile:', error);
        throw error;
      }
    },

    async update(userId: string, updates: Partial<Profile>) {
      try {
        const { data, error } = await supabase
          .from('profiles')
          .update(updates)
          .eq('id', userId)
          .select()
          .single();

        if (error) throw error;
        return data;
      } catch (error) {
        console.error('Error updating profile:', error);
        throw error;
      }
    }
  },

  follows: {
    async followUser(userId: string) {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session?.user) throw new Error('Not authenticated');
      if (session.user.id === userId) throw new Error('Cannot follow yourself');

      try {
        // First check if already following
        const { data: existingFollow } = await supabase
          .from('follows')
          .select('id')
          .match({
            follower_id: session.user.id,
            following_id: userId
          })
          .single();

        if (existingFollow) {
          throw new Error('Already following this user');
        }

        const { error } = await supabase
          .from('follows')
          .insert({
            follower_id: session.user.id,
            following_id: userId
          });

        if (error) throw error;
        return true;
      } catch (error) {
        console.error('Error following user:', error);
        throw error;
      }
    },

    async unfollowUser(userId: string) {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session?.user) throw new Error('Not authenticated');

      try {
        const { error } = await supabase
          .from('follows')
          .delete()
          .match({
            follower_id: session.user.id,
            following_id: userId
          });

        if (error) throw error;
        return true;
      } catch (error) {
        console.error('Error unfollowing user:', error);
        throw error;
      }
    },

    async isFollowing(userId: string) {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session?.user) return false;

      try {
        const { data, error } = await supabase
          .from('follows')
          .select('follower_id')
          .match({
            follower_id: session.user.id,
            following_id: userId
          })
          .maybeSingle();

        if (error) throw error;
        return !!data;
      } catch (error) {
        console.error('Error checking follow status:', error);
        return false;
      }
    },

    async getFollowCounts(userId: string) {
      try {
        const { data, error } = await supabase
          .from('profiles')
          .select('followers_count, following_count')
          .eq('id', userId)
          .single();

        if (error) throw error;
        return {
          followers_count: data.followers_count || 0,
          following_count: data.following_count || 0
        };
      } catch (error) {
        console.error('Error getting follow counts:', error);
        return { followers_count: 0, following_count: 0 };
      }
    }
  },

  loops: {
    async search({ query, bpmRange, key, sortBy = 'newest', limit = 50 }: SearchParams = {}) {
      try {
        let bpmMin: number | null = null;
        let bpmMax: number | null = null;
        
        if (bpmRange && bpmRange !== 'Any BPM') {
          const [min, max] = bpmRange.split('-').map(Number);
          bpmMin = min;
          bpmMax = max || 999;
        }

        const { data, error } = await supabase.rpc('search_loops', {
          search_query: query || null,
          bpm_min: bpmMin,
          bpm_max: bpmMax,
          key_signature: key === 'Any Key' ? null : key,
          sort_by: sortBy,
          limit_count: limit
        });

        if (error) throw error;
        return data || [];
      } catch (error) {
        console.error('Search error:', error);
        throw error;
      }
    },

    async getByProducer(producerId: string) {
      try {
        const { data, error } = await supabase
          .from('loops')
          .select(`
            *,
            producer:profiles(username, avatar_url)
          `)
          .eq('producer_id', producerId)
          .order('created_at', { ascending: false });

        if (error) throw error;
        return data;
      } catch (error) {
        console.error('Error fetching producer loops:', error);
        throw error;
      }
    },

    async delete(id: string) {
      try {
        const { error } = await supabase
          .from('loops')
          .delete()
          .eq('id', id);

        if (error) throw error;
      } catch (error) {
        console.error('Error deleting loop:', error);
        throw error;
      }
    }
  }
};