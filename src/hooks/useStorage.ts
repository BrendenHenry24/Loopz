import { useState } from 'react';
import { storage } from '../lib/storage';
import { supabase } from '../lib/supabase';
import { useAuthStore } from '../stores/authStore';
import toast from 'react-hot-toast';

export function useStorage() {
  const [uploading, setUploading] = useState(false);
  const { user } = useAuthStore();

  const uploadLoop = async (file: File, metadata: { title: string; bpm: number; key: string }) => {
    if (!user) {
      toast.error('You must be logged in to upload loops');
      return null;
    }

    try {
      setUploading(true);

      const path = await storage.uploadLoop(file, user.id, metadata.title);
      if (!path) throw new Error('Failed to upload file to storage');

      // Update the loop with actual BPM and key
      const { data: loop, error: dbError } = await supabase
        .from('loops') 
        .update({
          bpm: metadata.bpm, 
          key: metadata.key
        }) 
        .eq('audio_url', path)
        .select()
        .single();

      if (dbError) {
        await storage.deleteLoop(path);
        throw dbError;
      }

      toast.success('Loop uploaded successfully!');
      return loop;
    } catch (error: any) {
      console.error('Upload error:', error);
      toast.error(error.message || 'Failed to upload loop');
      return null;
    } finally {
      setUploading(false);
    }
  };

  const deleteLoop = async (loopId: string) => {
    if (!user) {
      toast.error('You must be logged in to delete loops');
      return false;
    }

    try {
      // First, get the loop details to ensure ownership and get the file path
      const { data: loop, error: fetchError } = await supabase
        .from('loops')
        .select('audio_url')
        .eq('id', loopId)
        .eq('producer_id', user.id)
        .single();

      if (fetchError) throw fetchError;
      if (!loop) throw new Error('Loop not found');

      // Delete from storage first
      await storage.deleteLoop(loop.audio_url);

      // Then delete from database (this will cascade to ratings and downloads)
      const { error: dbError } = await supabase
        .from('loops')
        .delete()
        .eq('id', loopId)
        .eq('producer_id', user.id);

      if (dbError) throw dbError;

      return true;
    } catch (error: any) {
      console.error('Delete error:', error);
      toast.error(error.message || 'Failed to delete loop');
      return false;
    }
  };

  const downloadLoop = async (loopId: string, audioUrl: string) => {
    if (!user) {
      toast.error('Please sign in to download loops');
      return;
    }

    try {
      // Get the loop title first
      const { data: loop, error: loopError } = await supabase
        .from('loops')
        .select('title')
        .eq('id', loopId)
        .single();

      if (loopError) throw loopError;

      // Record the download
      const { error: downloadError } = await supabase
        .from('downloads')
        .insert({
          loop_id: loopId,
          user_id: user.id
        });

      if (downloadError) throw downloadError;

      // Get the file
      const response = await fetch(audioUrl);
      const blob = await response.blob();

      // Get file extension from URL
      const extension = audioUrl.split('.').pop()?.toLowerCase() || 'mp3';

      // Create sanitized filename
      const sanitizedTitle = loop.title
        .toLowerCase()
        .replace(/[^a-z0-9]/g, '-')
        .replace(/-+/g, '-')
        .replace(/^-|-$/g, '');

      // Download file
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `${sanitizedTitle}.${extension}`;
      document.body.appendChild(a);
      a.click();
      window.URL.revokeObjectURL(url);
      document.body.removeChild(a);

      toast.success('Download started');
    } catch (error: any) {
      console.error('Download error:', error);
      toast.error('Failed to download loop');
    }
  };

  const getPublicUrl = (path: string): string => {
    return storage.getPublicUrl(path);
  };

  return {
    uploadLoop,
    deleteLoop,
    downloadLoop,
    getPublicUrl,
    uploading
  };
}