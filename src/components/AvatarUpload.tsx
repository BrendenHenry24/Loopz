import React, { useCallback, useState } from 'react';
import { useDropzone } from 'react-dropzone';
import { Camera, X } from 'lucide-react';
import ReactCrop, { type Crop } from 'react-image-crop';
import 'react-image-crop/dist/ReactCrop.css';
import { supabase } from '../lib/supabase';
import toast from 'react-hot-toast';

interface AvatarUploadProps {
  url: string | null;
  onUpload: (url: string) => void;
  size?: number;
  className?: string;
  onCropStart?: () => void;
  onCropEnd?: () => void;
}

export default function AvatarUpload({ 
  url, 
  onUpload, 
  size = 150, 
  className = '',
  onCropStart,
  onCropEnd 
}: AvatarUploadProps) {
  const [showCropper, setShowCropper] = useState(false);
  const [imageFile, setImageFile] = useState<File | null>(null);
  const [imageSrc, setImageSrc] = useState<string>('');
  const [crop, setCrop] = useState<Crop>({
    unit: '%',
    width: 100,
    height: 100,
    x: 0,
    y: 0,
    aspect: 1
  });

  const onDrop = useCallback(async (acceptedFiles: File[]) => {
    try {
      const file = acceptedFiles[0];
      
      // Validate file type
      if (!file.type.startsWith('image/')) {
        throw new Error('Please upload an image file');
      }

      // Validate file size (max 2MB)
      if (file.size > 2 * 1024 * 1024) {
        throw new Error('Image size should be less than 2MB');
      }

      // Get file extension
      const fileExt = file.name.split('.').pop()?.toLowerCase() || '';
      const allowedExts = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
      
      if (!allowedExts.includes(fileExt)) {
        throw new Error('Please upload a JPG, PNG, GIF, or WebP file');
      }

      // Create object URL for cropping
      const objectUrl = URL.createObjectURL(file);
      setImageFile(file);
      setImageSrc(objectUrl);
      onCropStart?.();
      setShowCropper(true);
    } catch (error: any) {
      console.error('Avatar validation error:', error);
      toast.error(error.message || 'Failed to process image');
    }
  }, []);

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    onDrop,
    accept: {
      'image/*': ['.jpg', '.jpeg', '.png', '.gif', '.webp']
    },
    maxFiles: 1,
    multiple: false
  });

  const handleCropComplete = async () => {
    if (!imageFile || !crop.width || !crop.height) return;

    let newUrl = '';
    try {
      // Create canvas for cropping
      const image = new Image();
      image.src = imageSrc;
      
      await new Promise((resolve) => {
        image.onload = resolve;
      });

      const canvas = document.createElement('canvas');
      const ctx = canvas.getContext('2d');
      if (!ctx) throw new Error('Failed to get canvas context');
      
      // Calculate source (crop) dimensions
      const scaleX = image.naturalWidth / image.width;
      const scaleY = image.naturalHeight / image.height;
      const sourceX = crop.x * scaleX;
      const sourceY = crop.y * scaleY;
      const sourceWidth = crop.width * scaleX;
      const sourceHeight = crop.height * scaleY;
      
      // Set canvas size to desired output size (always square)
      const size = 400; // Final image size
      canvas.width = size;
      canvas.height = size;
      
      // Clear the canvas and make it transparent
      ctx.clearRect(0, 0, size, size);
      
      // Create circular clipping path
      ctx.beginPath();
      ctx.arc(size / 2, size / 2, size / 2, 0, Math.PI * 2);
      ctx.closePath();
      ctx.clip();

      // Draw cropped image into the circular area
      ctx.drawImage(
        image,
        sourceX,
        sourceY,
        sourceWidth,
        sourceHeight,
        0,
        0,
        size,
        size
      );

      // Convert to blob
      const blob = await new Promise<Blob>((resolve) => {
        canvas.toBlob((blob) => {
          if (blob) resolve(blob);
        }, 'image/png', 1.0); // Use PNG for better quality with transparency
      });

      // Create unique file name
      const fileName = `${Math.random().toString(36).slice(2)}.png`;

      // Upload file
      const { data, error: uploadError } = await supabase.storage
        .from('avatars')
        .upload(`public/${fileName}`, blob, {
          contentType: 'image/png',
          cacheControl: '3600',
          upsert: true
        });

      if (uploadError) throw uploadError;

      // Get public URL
      const { data: { publicUrl } } = supabase.storage
        .from('avatars')
        .getPublicUrl(`public/${fileName}`, {
          transform: {
            width: 400,
            height: 400
          }
        });
      
      newUrl = publicUrl;

      // Update profile
      const { error: updateError } = await supabase
        .from('profiles')
        .update({ avatar_url: publicUrl })
        .eq('id', (await supabase.auth.getUser()).data.user?.id)
        .select()
        .single();

      if (updateError) throw updateError;

      // Update local state with new URL
      onUpload(newUrl);
      toast.success('Avatar updated successfully');
    } catch (error: any) {
      console.error('Avatar upload error:', error);
      toast.error(error.message || 'Failed to upload avatar');
    } finally {
      // Clean up
      URL.revokeObjectURL(imageSrc);
      setImageFile(null);
      setImageSrc('');
      setShowCropper(false);
    }
  };

  return (
    <>
      <div {...getRootProps()} style={{ width: size, height: size }} className={className}>
        <input {...getInputProps()} />
        <div className={`relative rounded-full overflow-hidden cursor-pointer w-full h-full
          transition-all duration-200 group
          ${isDragActive ? 'ring-4 ring-primary-500 ring-opacity-50' : ''}`}
        >
          <img
            src={url || `https://ui-avatars.com/api/?background=8b5cf6&color=fff&size=${size}`}
            alt="Avatar"
            className="w-full h-full object-cover rounded-full"
          />
          <div className="absolute inset-0 bg-black/50 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity">
            <Camera className="w-8 h-8 text-white" />
          </div>
        </div>
      </div>

      {showCropper && (
        <div className="fixed inset-0 z-[9999] flex items-center justify-center p-4 bg-black/50">
          <div className="relative w-full max-w-xl glass-panel p-6">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-semibold gradient-text">Crop Avatar</h3>
              <button
                onClick={() => {
                  URL.revokeObjectURL(imageSrc);
                  onCropEnd?.();
                  setShowCropper(false);
                }}
                className="p-1 text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="relative max-h-[60vh] overflow-hidden">
              <div className="flex items-center justify-center">
                <ReactCrop
                  crop={crop}
                  onChange={(_, percentCrop) => setCrop(percentCrop)}
                  aspect={1}
                  circularCrop
                  className="max-w-full mx-auto"
                >
                  <img 
                    src={imageSrc} 
                    alt="Crop preview"
                    className="max-w-full max-h-[60vh] object-contain"
                  />
                </ReactCrop>
              </div>
            </div>

            <div className="flex justify-end space-x-3 mt-6">
              <button
                onClick={() => {
                  URL.revokeObjectURL(imageSrc);
                  onCropEnd?.();
                  setShowCropper(false);
                }}
                className="px-4 py-2 text-gray-600 dark:text-gray-400 hover:text-gray-800 dark:hover:text-gray-200"
              >
                Cancel
              </button>
              <button
                onClick={handleCropComplete}
                className="px-6 py-2 bg-primary-500 text-white rounded-lg hover:bg-primary-600 
                         transition-colors focus:outline-none focus:ring-2 focus:ring-primary-500"
              >
                Save
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}