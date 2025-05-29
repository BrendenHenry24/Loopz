export interface Profile {
  id: string;
  username: string;
  email: string;
  avatar_url?: string;
  instagram_handle?: string;
  bio?: string;
  website?: string;
  total_uploads: number;
  total_downloads: number;
  average_loop_rating: number;
  followers_count: number;
  following_count: number;
  created_at: string;
}

export interface Loop {
  id: string;
  title: string;
  producer_id: string;
  audio_url: string;
  bpm: number;
  key: string;
  downloads: number;
  average_rating: number;
  created_at: string;
  producer?: {
    username: string;
    avatar_url?: string;
  };
}

export interface Rating {
  id: string;
  loop_id: string;
  user_id: string;
  rating: number;
  created_at: string;
}

export interface Download {
  id: string;
  loop_id: string;
  user_id: string;
  created_at: string;
}

export interface Follow {
  follower_id: string;
  following_id: string;
  created_at: string;
}