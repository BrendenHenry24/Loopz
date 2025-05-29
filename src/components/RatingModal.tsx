import React, { useState, useEffect } from 'react';
import { Star, X } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuthStore } from '../stores/authStore';
import toast from 'react-hot-toast';

interface RatingModalProps {
  isOpen: boolean;
  onClose: () => void;
  loopId: string;
  onRatingSubmit: (newRating: number) => void;
  producerId?: string;
}

export default function RatingModal({ isOpen, onClose, loopId, onRatingSubmit, producerId }: RatingModalProps) {
  const { user } = useAuthStore();
  const [rating, setRating] = useState(0);
  const [hoveredRating, setHoveredRating] = useState(0);
  const [submitting, setSubmitting] = useState(false);
  const [existingRating, setExistingRating] = useState<number | null>(null);

  useEffect(() => {
    if (user && loopId) {
      checkExistingRating();
    }
  }, [user, loopId]);

  const checkExistingRating = async () => {
    try {
      const { data, error } = await supabase
        .from('ratings')
        .select('rating')
        .eq('loop_id', loopId)
        .eq('user_id', user!.id);

      if (error) throw error;
      
      // If we have a rating, use the first one
      if (data && data.length > 0) {
        setRating(data[0].rating);
        setExistingRating(data[0].rating);
      }
    } catch (error) {
      console.error('Error checking existing rating:', error);
    }
  };

  const handleSubmit = async () => {
    if (!user) {
      toast.error('Please sign in to rate loops');
      return;
    }

    if (rating === 0) {
      toast.error('Please select a rating');
      return;
    }

    // Check if user is trying to rate their own loop
    if (user.id === producerId) {
      toast.error("You can't rate your own loops!");
      onClose();
      return;
    }

    setSubmitting(true);
    try {
      if (existingRating) {
        // Update existing rating
        const { error } = await supabase
          .from('ratings')
          .update({ rating })
          .eq('loop_id', loopId)
          .eq('user_id', user.id);

        if (error) throw error;
      } else {
        // Insert new rating
        const { error } = await supabase
          .from('ratings')
          .insert({
            loop_id: loopId,
            user_id: user.id,
            rating
          });

        if (error) throw error;
      }

      // Get updated average rating
      const { data: updatedLoop, error: updateError } = await supabase
        .from('loops')
        .select('average_rating')
        .eq('id', loopId)
        .single();

      if (updateError) throw updateError;

      onRatingSubmit(updatedLoop.average_rating);
      toast.success(existingRating ? 'Rating updated' : 'Rating submitted');
      onClose();
    } catch (error: any) {
      console.error('Rating error:', error);
      toast.error(error.message || 'Failed to submit rating');
    } finally {
      setSubmitting(false);
    }
  };

  if (!isOpen || !user) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50">
      <div className="glass-panel p-6 max-w-sm w-full">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-xl font-bold gradient-text">
            {existingRating ? 'Update Rating' : 'Rate this Loop'}
          </h3>
          <button
            onClick={onClose}
            className="p-1 text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200"
          >
            <X className="w-5 h-5" />
          </button>
        </div>
        
        <div className="flex justify-center space-x-2 mb-6">
          {[1, 2, 3, 4, 5].map((value) => (
            <button
              key={value}
              onClick={() => setRating(value)}
              onMouseEnter={() => setHoveredRating(value)}
              onMouseLeave={() => setHoveredRating(0)}
              className="p-1 transition-colors duration-200"
            >
              <Star
                className={`w-8 h-8 ${
                  value <= (hoveredRating || rating)
                    ? 'fill-yellow-400 text-yellow-400'
                    : 'text-gray-300 dark:text-gray-600'
                }`}
              />
            </button>
          ))}
        </div>

        <div className="flex justify-end space-x-3">
          <button
            onClick={onClose}
            className="px-4 py-2 text-gray-600 dark:text-gray-400 hover:text-gray-800 dark:hover:text-gray-200"
          >
            Cancel
          </button>
          <button
            onClick={handleSubmit}
            disabled={submitting}
            className={`px-6 py-2 bg-primary-500 text-white rounded-lg 
              ${submitting 
                ? 'opacity-50 cursor-not-allowed' 
                : 'hover:bg-primary-600 transition-colors'
              }`}
          >
            {existingRating ? 'Update' : 'Submit'}
          </button>
        </div>
      </div>
    </div>
  );
}