import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { useAuthStore } from '../stores/authStore';
import { Loader2 } from 'lucide-react';
import toast from 'react-hot-toast';

export default function AuthCallback() {
  const navigate = useNavigate();
  const { setUser } = useAuthStore();

  useEffect(() => {
    const handleAuthCallback = async () => {
      try {
        // Get session from URL
        const { data: { session }, error: sessionError } = await supabase.auth.getSession();
        
        if (sessionError) throw sessionError;
        
        if (!session) {
          throw new Error('No session found');
        }

        const { data: { user }, error } = await supabase.auth.getUser();
        
        if (error) throw error;
        
        if (user) {
          const { data: profile } = await supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .single();
            
          if (!profile) {
            const { error: insertError } = await supabase
              .from('profiles')
              .insert({
                id: user.id,
                email: user.email,
                username: user.user_metadata.preferred_username || user.email?.split('@')[0],
                avatar_url: user.user_metadata.avatar_url,
                instagram_handle: user.user_metadata.instagram_handle
              });
              
            if (insertError) throw insertError;
          }
          
          setUser(profile || user);
          toast.success('Successfully signed in!');
          navigate('/');
        }
      } catch (error) {
        console.error('Auth callback error:', error);
        toast.error('Failed to complete authentication');
        navigate('/auth');
      }
    };

    handleAuthCallback();
  }, [navigate, setUser]);

  return (
    <div className="min-h-screen flex items-center justify-center">
      <div className="glass-panel p-8 text-center">
        <Loader2 className="w-16 h-16 text-primary-500 animate-spin mx-auto mb-4" />
        <p className="text-xl font-semibold gradient-text">Completing sign in...</p>
        <p className="text-gray-600 dark:text-gray-400 mt-2">Please wait while we set up your account</p>
      </div>
    </div>
  );
}