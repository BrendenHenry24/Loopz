import React, { useState, useEffect } from 'react';
import { useNavigate, Navigate } from 'react-router-dom';
import { Loader2, AlertCircle } from 'lucide-react';
import { useAuthStore } from '../stores/authStore';
import toast from 'react-hot-toast';
import { supabase } from '../lib/supabase';

export default function Verify() {
  const navigate = useNavigate();
  const { user, updateUser } = useAuthStore();
  const [loading, setLoading] = useState(false);
  const [code, setCode] = useState('');
  const [error, setError] = useState('');
  const [signupData] = useState(() => {
    const data = sessionStorage.getItem('signupData');
    return data ? JSON.parse(data) : null;
  });

  // Redirect if no user
  if (!user && !signupData) {
    return <Navigate to="/login" replace />;
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      // Verify the OTP
      const { data, error } = await supabase.auth.verifyOtp({
        phone: signupData?.phone || user?.phone_number,
        token: code,
        type: 'sms',
      });

      if (error) throw error;

      // Clear signup data from session storage
      sessionStorage.removeItem('signupData');
      // Update profile with verified status
      const { error: profileUpdateError } = await supabase
        .from('profiles')
        .update({ phone_verified: true })
        .eq('id', data.user.id);

      if (profileUpdateError) throw profileUpdateError;

      // Update local user state
      updateUser({
        ...data.user,
        phone_verified: true
      });
      toast.success('Phone number verified successfully');
      navigate('/profile');
    } catch (error: any) {
      console.error('Verification error:', error);
      setError(error.message || 'Failed to verify code');
      toast.error(error.message || 'Failed to verify code');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center p-4">
      <div className="w-full max-w-md space-y-8 glass-panel p-8">
        <div className="text-center">
          <h2 className="text-3xl font-bold gradient-text mb-2">Verify Phone Number</h2>
          {(signupData?.phone || user?.phone_number) && (
            <p className="text-gray-600 dark:text-gray-400">
              Enter the verification code sent to {signupData?.phone || user?.phone_number}
            </p>
          )}
        </div>

        <form onSubmit={handleSubmit} className="space-y-6">
          <div>
            <div className="relative">
              <input
                type="text"
                value={code}
                onChange={(e) => setCode(e.target.value.replace(/\D/g, ''))}
                placeholder="Enter verification code"
                className={`w-full px-4 py-3 glass-input text-center text-2xl tracking-widest ${
                  error ? 'border-red-500 dark:border-red-500' : ''
                }`}
                maxLength={6}
              />
              {error && (
                <AlertCircle className="absolute right-3 top-1/2 -translate-y-1/2 w-5 h-5 text-red-500" />
              )}
            </div>
            {error && (
              <p className="mt-1 text-sm text-red-500">{error}</p>
            )}
          </div>

          <button
            type="submit"
            disabled={loading || code.length !== 6}
            className="w-full bg-primary-500 text-white py-3 rounded-lg font-semibold
                     hover:bg-primary-600 focus:outline-none focus:ring-2 
                     focus:ring-primary-500 focus:ring-offset-2 
                     disabled:opacity-50 disabled:cursor-not-allowed
                     transition-all duration-200"
          >
            {loading ? (
              <Loader2 className="w-5 h-5 animate-spin mx-auto" />
            ) : (
              'Verify'
            )}
          </button>
        </form>
      </div>
    </div>
  );
}