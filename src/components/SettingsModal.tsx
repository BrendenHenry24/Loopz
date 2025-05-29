import React, { useState, useEffect } from 'react';
import { X, Loader2, AlertCircle, Phone } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useQuery } from '../hooks/useQuery';
import { useAuthStore } from '../stores/authStore';
import { useNavigate } from 'react-router-dom';
import PhoneInput from 'react-phone-input-2';
import toast from 'react-hot-toast';

interface SettingsModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export default function SettingsModal({ isOpen, onClose }: SettingsModalProps) {
  const { user, updateUser } = useAuthStore();
  const navigate = useNavigate();
  const [loading, setLoading] = useState(false);
  const [canChangeUsername, setCanChangeUsername] = useState(false);
  const [nextChangeDate, setNextChangeDate] = useState<Date | null>(null);
  const [authUser, setAuthUser] = useState<any>(null);
  const [formData, setFormData] = useState({
    username: user?.username || '',
    displayName: user?.display_name || '',
    instagram_handle: user?.instagram_handle || '',
    phone: user?.phone_number || ''
  });
  const [errors, setErrors] = useState<{
    username?: string;
    displayName?: string;
    instagram_handle?: string;
    phone?: string;
  }>({});

  if (!isOpen || !user) return null;
  
  // Get phone number from auth.users
  useEffect(() => {
    const getAuthUser = async () => {
      const { data: { user: authUserData } } = await supabase.auth.getUser();
      setAuthUser(authUserData);
      if (authUserData?.phone) {
        setFormData(prev => ({ ...prev, phone: authUserData.phone }));
      }
    };
    getAuthUser();
  }, []);

  // Check if username change is available
  useEffect(() => {
    const checkUsernameChange = async () => {
      try {
        const { data, error } = await supabase
          .from('profiles')
          .select('last_username_change')
          .eq('id', user!.id)
          .single();

        if (error) throw error;

        const lastChange = data?.last_username_change ? new Date(data.last_username_change) : null;
        const now = new Date();

        if (!lastChange) {
          setCanChangeUsername(true);
          setNextChangeDate(null);
        } else {
          const nextChange = new Date(lastChange.getTime() + (7 * 24 * 60 * 60 * 1000));
          setCanChangeUsername(now >= nextChange);
          setNextChangeDate(nextChange);
        }
      } catch (error) {
        console.error('Error checking username change:', error);
      }
    };

    if (user) {
      checkUsernameChange();
    }
  }, [user]);

  const validateForm = (): boolean => {
    const newErrors: typeof errors = {};

    if (!formData.displayName.trim()) {
      newErrors.displayName = 'Display name is required';
    }

    if (formData.instagram_handle && !/^[a-zA-Z0-9._]{1,30}$/.test(formData.instagram_handle)) {
      newErrors.instagram_handle = 'Invalid Instagram handle format';
    }

    // Clean the phone number - remove spaces, parentheses, and hyphens
    const cleanPhone = formData.phone.replace(/[\s()-]/g, '');
    
    if (formData.phone && !/^\+?1?\d{10,11}$/.test(cleanPhone)) {
      newErrors.phone = 'Invalid phone number format';
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!validateForm()) return;

    setLoading(true);
    try {
      // Prepare update data
      const updates: any = {
        display_name: formData.displayName.trim(),
        instagram_handle: formData.instagram_handle.trim() || null,
        phone_number: formData.phone || null
      };

      // Only include username if it's changed and allowed
      if (canChangeUsername && formData.username !== user.username) {
        updates.username = formData.username.trim();
      }

      // Update profile
      const { data: profile, error } = await supabase
        .from('profiles')
        .update(updates)
        .eq('id', user.id)
        .select()
        .single();

      if (error) throw error;

      // Update local user state
      updateUser({
        ...user,
        username: profile.username,
        display_name: profile.display_name,
        instagram_handle: profile.instagram_handle,
        phone_number: profile.phone_number
      });

      toast.success('Profile updated successfully');
      onClose();
    } catch (error: any) {
      console.error('Settings update error:', error);
      toast.error(error.message || 'Failed to update profile');
    } finally {
      setLoading(false);
    }
  };

  const handleVerifyPhone = async () => {
    try {
      if (!formData.phone) {
        throw new Error('Please enter a phone number first');
      }

      // Clean the phone number before sending to Supabase
      const cleanPhone = formData.phone.replace(/[\s()-]/g, '');
      
      // Start phone verification process
      const { error } = await supabase.auth.signInWithOtp({
        phone: cleanPhone
      });

      if (error) throw error;

      // Navigate to verification page
      navigate('/verify');
    } catch (error: any) {
      console.error('Phone verification error:', error);
      toast.error(error.message || 'Failed to start phone verification');
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50">
      <div className="relative w-full max-w-md glass-panel p-6">
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-xl font-bold gradient-text">Profile Settings</h2>
          <button
            onClick={onClose}
            className="p-1 text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
              Username
            </label>
            <input
              type="text"
              value={formData.username}
              onChange={(e) => setFormData(prev => ({ ...prev, username: e.target.value }))}
              className={`w-full glass-input px-3 py-2 ${
                !canChangeUsername ? 'bg-gray-50 dark:bg-gray-800/50 cursor-not-allowed' : ''
              }`}
              disabled={!canChangeUsername}
              placeholder="Your username"
            />
            {!canChangeUsername && nextChangeDate && (
              <p className="mt-1 text-xs text-gray-500 dark:text-gray-400">
                Username can be changed again on {nextChangeDate.toLocaleDateString()}
              </p>
            )}
            {canChangeUsername && (
              <p className="mt-1 text-xs text-gray-500 dark:text-gray-400">
                You can change your username now. Next change will be available in 7 days.
              </p>
            )}
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
              Display Name
            </label>
            <input
              type="text"
              value={formData.displayName}
              onChange={(e) => setFormData(prev => ({ ...prev, displayName: e.target.value }))}
              className={`w-full glass-input px-3 py-2 ${
                errors.displayName ? 'border-red-500' : ''
              }`}
              placeholder="Your display name"
            />
            {errors.displayName && (
              <p className="mt-1 text-sm text-red-500">{errors.displayName}</p>
            )}
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
              Instagram Handle
            </label>
            <div className="relative">
              <span className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-500">@</span>
              <input
                type="text"
                value={formData.instagram_handle}
                onChange={(e) => setFormData(prev => ({ ...prev, instagram_handle: e.target.value }))}
                className={`w-full glass-input pl-8 pr-3 py-2 ${
                  errors.instagram_handle ? 'border-red-500' : ''
                }`}
                placeholder="Your Instagram handle"
              />
            </div>
            {errors.instagram_handle && (
              <p className="mt-1 text-sm text-red-500">{errors.instagram_handle}</p>
            )}
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
              Phone Number
            </label>
            <div className="flex items-center space-x-2">
              <div className="flex-grow">
                <PhoneInput
                  country={'us'}
                  value={formData.phone}
                  onChange={phone => setFormData(prev => ({ ...prev, phone: `+${phone}` }))}
                  containerClass={`${errors.phone ? 'phone-input-error' : ''}`}
                  inputClass="w-full glass-input !pl-12 py-2"
                  buttonClass="!glass-input !border-0"
                  disabled={authUser?.phone_confirmed_at}
                />
              </div>
              {!authUser?.phone_confirmed_at && formData.phone && (
                <button
                  type="button"
                  onClick={handleVerifyPhone}
                  className="px-3 py-2 bg-primary-500 text-white rounded-lg hover:bg-primary-600 
                           transition-colors focus:outline-none focus:ring-2 focus:ring-primary-500"
                >
                  <Phone className="w-5 h-5" />
                </button>
              )}
            </div>
            {errors.phone && (
              <p className="mt-1 text-sm text-red-500">{errors.phone}</p>
            )}
            {authUser?.phone_confirmed_at ? (
              <p className="mt-1 text-sm text-green-500">Phone number verified</p>
            ) : (
              <p className="mt-1 text-sm text-gray-500">Phone number not verified</p>
            )}
          </div>

          <div className="flex justify-end space-x-3 mt-6">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 text-gray-600 dark:text-gray-400 hover:text-gray-800 dark:hover:text-gray-200"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={loading}
              className="px-6 py-2 bg-primary-500 text-white rounded-lg hover:bg-primary-600 
                       disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              {loading ? (
                <Loader2 className="w-5 h-5 animate-spin mx-auto" />
              ) : (
                'Save Changes'
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}