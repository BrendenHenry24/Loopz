import { loadStripe } from '@stripe/stripe-js';
import { supabase } from './supabase';

// Initialize Stripe with your publishable key
const stripePromise = loadStripe(import.meta.env.VITE_STRIPE_PUBLISHABLE_KEY);

export const stripe = {
  async redirectToCheckout(priceId: string) {
    try {
      if (!import.meta.env.VITE_STRIPE_PUBLISHABLE_KEY) {
        throw new Error('Missing Stripe publishable key');
      }

      const stripe = await stripePromise;
      if (!stripe) throw new Error('Stripe failed to initialize');

      // Get the user's auth token
      const { data: { session } } = await supabase.auth.getSession();
      if (!session) throw new Error('Not authenticated');

      const response = await fetch('https://hywokpxajcrfuhmgpfwi.supabase.co/functions/v1/create-checkout-session', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${session.access_token}`
        },
        body: JSON.stringify({ priceId }),
      });

      const { sessionId } = await response.json();
      
      // Redirect to Checkout
      const { error } = await stripe.redirectToCheckout({ sessionId });
      
      if (error) throw error;
    } catch (error: any) {
      console.error('Stripe error:', error);
      throw new Error(error.message || 'Failed to redirect to checkout');
    }
  },

  async createPortalSession() {
    try {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session) throw new Error('Not authenticated');

      const response = await fetch('https://hywokpxajcrfuhmgpfwi.supabase.co/functions/v1/create-portal-session', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${session.access_token}`
        }
      });
      
      const { url } = await response.json();
      window.location.href = url;
    } catch (error: any) {
      console.error('Portal session error:', error);
      throw new Error(error.message || 'Failed to create portal session');
    }
  }
};