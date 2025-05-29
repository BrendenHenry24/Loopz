export interface Database {
  public: {
    Tables: {
      profiles: {
        Row: {
          id: string;
          username: string;
          email: string;
          avatar_url: string | null;
          instagram_handle: string | null;
          bio: string | null;
          website: string | null;
          total_uploads: number;
          total_downloads: number;
          average_loop_rating: number;
          created_at: string;
        };
        Insert: {
          id: string;
          username: string;
          email: string;
          avatar_url?: string | null;
          instagram_handle?: string | null;
          bio?: string | null;
          website?: string | null;
          total_uploads?: number;
          total_downloads?: number;
          average_loop_rating?: number;
          created_at?: string;
        };
        Update: {
          id?: string;
          username?: string;
          email?: string;
          avatar_url?: string | null;
          instagram_handle?: string | null;
          bio?: string | null;
          website?: string | null;
          total_uploads?: number;
          total_downloads?: number;
          average_loop_rating?: number;
          created_at?: string;
        };
      };
      loops: {
        Row: {
          id: string;
          title: string;
          producer_id: string;
          audio_url: string;
          bpm: number;
          key: string;
          downloads: number;
          average_rating: number;
          created_at: string;
        };
        Insert: {
          title: string;
          producer_id: string;
          audio_url: string;
          bpm: number;
          key: string;
          downloads?: number;
          average_rating?: number;
          created_at?: string;
        };
        Update: {
          title?: string;
          producer_id?: string;
          audio_url?: string;
          bpm?: number;
          key?: string;
          downloads?: number;
          average_rating?: number;
          created_at?: string;
        };
      };
    };
  };
}