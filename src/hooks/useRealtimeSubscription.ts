import { useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { RealtimeChannel } from '@supabase/supabase-js';

type SubscriptionCallback = (payload: any) => void;

export function useRealtimeSubscription(
  table: string,
  event: 'INSERT' | 'UPDATE' | 'DELETE',
  callback: SubscriptionCallback,
  filter?: string
) {
  useEffect(() => {
    let channel: RealtimeChannel;

    const setupSubscription = async () => {
      // Create channel with name "MMM"
      channel = supabase.channel('MMM');

      // Set up subscription with filter if provided
      channel.on(
        'postgres_changes',
        {
          event: event,
          schema: 'public',
          table: table,
          filter: filter
        },
        callback
      );

      // Subscribe to the channel
      await channel.subscribe((status) => {
        if (status === 'SUBSCRIBED') {
          console.log(`Subscribed to ${table} ${event} events`);
        }
      });
    };

    setupSubscription();

    // Cleanup subscription on unmount
    return () => {
      if (channel) {
        channel.unsubscribe();
      }
    };
  }, [table, event, callback, filter]);
}