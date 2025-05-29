import { create } from 'zustand';
import { supabase } from '../lib/supabase';
import toast from 'react-hot-toast';

interface User {
  id: string;
  email: string;
  username?: string;
  avatar_url?: string;
  instagram_handle?: string;
  membership_tier?: string;
}

interface AuthState {
  user: User | null;
  loading: boolean;
  initialized: boolean;
  signUp: (email: string, password: string, username: string) => Promise<void>;
  signIn: (email: string, password: string) => Promise<void>;
  signOut: () => Promise<void>;
  initialize: () => Promise<void>;
  setUser: (user: User | null) => void;
  updateUser: (updates: Partial<User>) => void;
}

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  loading: true,
  initialized: false,

  initialize: async () => {
    try {
      const { data: { session } } = await supabase.auth.getSession();
      let profile = null;

      if (session?.user) {
        const { data: profileData, error } = await supabase
          .from('profiles')
          .select('*')
          .eq('id', session.user.id)
          .maybeSingle();

        if (error) {
          console.error('Profile fetch error:', error);
          set({ user: session.user });
        } else {
          profile = profileData;
          set({ user: profile || session.user });
        }
      }

      set({ loading: false, initialized: true });
    } catch (error) {
      console.error('Auth initialization error:', error);
      toast.error('Failed to initialize authentication');
      set({ user: null, loading: false, initialized: true });
    } finally {
      set({ loading: false, initialized: true });
    }
  },

  setUser: (user: User) => {
    set({ user });
  },

  updateUser: (updates: Partial<User>) => {
    set((state) => ({
      user: state.user ? { ...state.user, ...updates } : null
    }));
  },

  signIn: async (email: string, password: string) => {
    try {
      const { error } = await supabase.auth.signInWithPassword({
        email,
        password,
      });

      if (error) throw error;
      
      toast.success('Successfully signed in');
    } catch (error: any) {
      toast.error(error.message || 'Failed to sign in');
      throw error;
    }
  },

  signUp: async (email: string, password: string, username: string) => {
    try {
      const { error } = await supabase.auth.signUp({
        email,
        password,
        options: {
          data: {
            username: username
          }
        }
      });

      if (error) throw error;
      
      toast.success('Successfully signed up');
      return true;
    } catch (error: any) {
      toast.error(error.message || 'Failed to sign up');
      throw error;
    }
  },

  signOut: async () => {
    try {
      const { error } = await supabase.auth.signOut();
      if (error) throw error;
      
      set({ user: null });
      toast.success('Successfully signed out');
    } catch (error: any) {
      toast.error(error.message || 'Failed to sign out');
      throw error;
    }
  },
}));