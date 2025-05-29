import { supabase } from './supabase';
import { MEMBERSHIP_LIMITS } from '../types/membership';

// Supported audio formats and their MIME types
export const SUPPORTED_FORMATS = {
  'audio/wav': '.wav',
  'audio/mpeg': '.mp3',
  'audio/x-m4a': '.m4a',
  'audio/aac': '.aac'
} as const;

// Maximum file size (10MB)
export const MAX_FILE_SIZE = 10 * 1024 * 1024;

export const storage = {
  /**
   * Upload an audio file to Supabase Storage
   */
  async uploadLoop(file: File, userId: string, title: string): Promise<string> {
    // Validate file format
    if (!SUPPORTED_FORMATS[file.type as keyof typeof SUPPORTED_FORMATS]) {
      throw new Error(`Unsupported file format: ${file.type}. Please upload WAV, MP3, M4A, or AAC files.`);
    }

    // Validate file size
    if (file.size > MAX_FILE_SIZE) {
      throw new Error('File size exceeds 10MB limit.');
    }

    // Check user's storage limit
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('membership_tier, storage_used')
      .eq('id', userId)
      .single();

    if (profileError) throw profileError;

    const tier = profile.membership_tier || 'basic';
    const limit = MEMBERSHIP_LIMITS[tier].storageLimit;
    
    if (profile.storage_used + file.size > limit) {
      throw new Error(`Upload would exceed your ${tier} storage limit of ${limit / (1024 * 1024)}MB`);
    }

    // Create a sanitized filename using the title
    const sanitizedTitle = title
      .toLowerCase()
      .replace(/[^a-z0-9]/g, '-')
      .replace(/-+/g, '-')
      .replace(/^-|-$/g, '');

    // Generate timestamp in MMDDYY format
    const date = new Date();
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    const year = date.getFullYear().toString().slice(-2);
    const timestamp = `${month}${day}${year}`;

    // Generate unique filename
    const extension = SUPPORTED_FORMATS[file.type as keyof typeof SUPPORTED_FORMATS];
    const filePath = `${userId}/${sanitizedTitle}_${timestamp}${extension}`;

    try {
      const { data, error } = await supabase.storage
        .from('loops')
        .upload(filePath, file, {
          cacheControl: '3600',
          contentType: file.type,
          upsert: true
        });

      if (error) throw error;
      
      // Create database entry with all required fields
      const { error: dbError } = await supabase
        .from('loops')
        .insert({
          title,
          producer_id: userId,
          audio_url: data.path,
          file_size: file.size,
          bpm: 0, // Temporary value, will be updated
          key: 'C' // Temporary value, will be updated
        });

      if (dbError) {
        // If database insert fails, clean up the uploaded file
        await this.deleteLoop(data.path);
        throw dbError;
      }

      return data.path;
    } catch (error: any) {
      console.error('Storage upload error:', error);
      throw new Error(error.message || 'Failed to upload file');
    }
  },

  /**
   * Get a public URL for an audio file
   */
  getPublicUrl(path: string): string {
    if (!path) throw new Error('Invalid file path');

    const { data: { publicUrl } } = supabase.storage
      .from('loops')
      .getPublicUrl(path);

    if (!publicUrl) {
      throw new Error('Failed to generate public URL');
    }

    return publicUrl;
  },

  /**
   * Delete an audio file
   */
  async deleteLoop(path: string): Promise<void> {
    if (!path) throw new Error('Invalid file path');

    try {
      const { error } = await supabase.storage
        .from('loops')
        .remove([path]);

      if (error) throw error;
    } catch (error: any) {
      console.error('Storage delete error:', error);
      throw new Error(error.message || 'Failed to delete file');
    }
  }
};