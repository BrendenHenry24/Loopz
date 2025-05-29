import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { Play, Star, Download, Pause } from 'lucide-react';
import Search from '../components/Search';
import { AudioPlayer } from '../components/AudioPlayer';
import { supabase } from '../lib/supabase';
import { useStorage } from '../hooks/useStorage';
import toast from 'react-hot-toast';

interface Loop {
  id: string;
  title: string;
  producer_id: string;
  producer: {
    id: string;
    username: string;
    avatar_url: string;
  };
  audio_url: string;
  bpm: number;
  key: string;
  rating: number;
  downloads: number;
}

interface Profile {
  id: string;
  username: string;
  avatar_url: string | null;
  followers_count: number;
  following_count: number;
  total_uploads: number;
  average_loop_rating: number;
}

interface SearchFilters {
  type: 'all' | 'producer' | 'loop' | 'style';
  bpmRange: string;
  key: string;
  sortBy?: 'newest' | 'downloads' | 'rating';
}

const DEFAULT_FILTERS: SearchFilters = {
  type: 'all',
  bpmRange: 'Any BPM',
  key: 'Any Key',
  sortBy: 'newest'
};

export default function Home() {
  const [playingId, setPlayingId] = useState<string | null>(null);
  const [searchResults, setSearchResults] = useState<Loop[]>([]);
  const [profileResults, setProfileResults] = useState<Profile[]>([]);
  const [loops, setLoops] = useState<Loop[]>([]);
  const [loading, setLoading] = useState(true);
  const { getPublicUrl, downloadLoop } = useStorage();

  useEffect(() => {
    fetchLoops();
  }, []);

  const fetchLoops = async () => {
    try {
      const { data: loops, error } = await supabase.rpc('search_loops');
      if (error) throw error;

      const loopsWithUrls = (loops || []).map(loop => ({
        ...loop,
        audio_url: getPublicUrl(loop.audio_url),
        producer: {
          id: loop.producer_id,
          username: loop.producer_username,
          avatar_url: loop.producer_avatar_url || `https://ui-avatars.com/api/?name=${loop.producer_username || 'UP'}&background=8b5cf6&color=fff`
        },
        rating: loop.average_rating || 0
      }));
      setLoops(loopsWithUrls);
    } catch (error) {
      console.error('Error fetching loops:', error);
      toast.error('Failed to load loops');
    } finally {
      setLoading(false);
    }
  };

  const handleSearch = async (query: string, filters: SearchFilters) => {
    try {
      // Reset results
      setSearchResults([]);
      setProfileResults([]);

      // Search for profiles if query exists
      if (query) {
        const { data: profiles, error: profileError } = await supabase
          .from('profiles')
          .select('id, username, avatar_url, followers_count, following_count, total_uploads, average_loop_rating')
          .ilike('username', `%${query}%`)
          .limit(5);

        if (profileError) throw profileError;
        setProfileResults(profiles || []);
      }

      // Search for loops
      let bpmMin: number | undefined;
      let bpmMax: number | undefined;

      if (filters.bpmRange !== 'Any BPM') {
        const [min, max] = filters.bpmRange.split('-').map(Number);
        bpmMin = min;
        bpmMax = max;
      }

      const { data: loops, error } = await supabase.rpc('search_loops', {
        search_query: query || null,
        bpm_min: bpmMin,
        bpm_max: bpmMax,
        key_signature: filters.key === 'Any Key' ? null : filters.key,
        sort_by: filters.sortBy,
        limit_count: 50
      });

      if (error) throw error;

      const searchedLoops = (loops || []).map(loop => ({
        ...loop,
        audio_url: getPublicUrl(loop.audio_url),
        producer: {
          id: loop.producer_id,
          username: loop.producer_username,
          avatar_url: loop.producer_avatar_url || `https://ui-avatars.com/api/?name=${loop.producer_username || 'UP'}&background=8b5cf6&color=fff`
        },
        rating: loop.average_rating || 0
      }));

      setSearchResults(searchedLoops);
    } catch (error) {
      console.error('Search error:', error);
      toast.error('Failed to search loops');
    }
  };

  const handlePlay = (id: string) => {
    setPlayingId(playingId === id ? null : id);
  };

  const handleRatingChange = (loopId: string, newRating: number) => {
    const updateLoops = (loopList: Loop[]) =>
      loopList.map(loop =>
        loop.id === loopId ? { ...loop, rating: newRating } : loop
      );

    setLoops(updateLoops);
    if (searchResults.length > 0) {
      setSearchResults(updateLoops);
    }
  };

  const displayedLoops = searchResults.length > 0 ? searchResults : loops;

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="w-16 h-16 border-4 border-primary-500 border-t-transparent rounded-full animate-spin"></div>
      </div>
    );
  }

  return (
    <div className="space-y-8 pt-24">
      <section className="text-center py-16 glass-panel">
        <h1 className="text-4xl font-bold gradient-text mb-4">
          Loopz.music
        </h1>
        <p className="text-xl mb-8 text-gray-700 dark:text-gray-300">
          Share and discover the best music loops from producers worldwide
        </p>
        <Search onSearch={handleSearch} />
      </section>

      <section>
        <div className="flex justify-between items-center mb-6">
          <h2 className="text-2xl font-bold gradient-text">
            {searchResults.length > 0 || profileResults.length > 0 ? 'Search Results' : 'Featured Loops'}
          </h2>
          <select 
            className="glass-input px-4 py-2"
            onChange={(e) => handleSearch('', { ...DEFAULT_FILTERS, sortBy: e.target.value as SearchFilters['sortBy'] })}
          >
            <option value="newest">Newest First</option>
            <option value="downloads">Most Downloads</option>
            <option value="rating">Highest Rated</option>
          </select>
        </div>

        <div className="space-y-4">
          {/* Profile Results */}
          {profileResults.length > 0 && (
            <div className="mb-8">
              <h3 className="text-lg font-semibold text-gray-700 dark:text-gray-300 mb-4">Producers</h3>
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                {profileResults.map(profile => (
                  <div key={profile.id} className="glass-panel p-4 hover:bg-white/10 dark:hover:bg-black/10 transition-colors">
                    <Link to={`/${profile.username}`} className="flex items-center space-x-4">
                      <img
                        src={profile.avatar_url || `https://ui-avatars.com/api/?name=${profile.username}&background=8b5cf6&color=fff`}
                        alt={profile.username}
                        className="w-12 h-12 rounded-full object-cover"
                      />
                      <div>
                        <h4 className="font-semibold text-gray-900 dark:text-white">{profile.username}</h4>
                        <div className="flex items-center space-x-4 text-sm text-gray-600 dark:text-gray-400">
                          <span>{profile.total_uploads} loops</span>
                          <span>{profile.followers_count} followers</span>
                        </div>
                      </div>
                    </Link>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Loop Results */}
          {searchResults.length > 0 && (
            <div>
              <h3 className="text-lg font-semibold text-gray-700 dark:text-gray-300 mb-4">Loops</h3>
            </div>
          )}

          {displayedLoops.length === 0 ? (
            <div className="text-center py-12 glass-panel">
              <p className="text-gray-600 dark:text-gray-400">
                {searchResults.length === 0 && profileResults.length === 0
                  ? 'No loops found. Try adjusting your search criteria.'
                  : 'No loops available. Be the first to upload!'}
              </p>
            </div>
          ) : (
            displayedLoops.map(loop => (
              <div key={loop.id} className="glass-panel p-4">
                <div className="flex items-start justify-between relative z-10">
                  <div className="flex-grow min-w-0">
                    <div className="flex justify-between items-start mb-2">
                      <div className="min-w-0">
                        <h3 className="text-lg font-semibold gradient-text truncate">
                          {loop.title}
                        </h3>
                      </div>
                      <div className="flex items-center space-x-2">
                        <button 
                          onClick={() => handlePlay(loop.id)}
                          className="p-2 rounded-full bg-primary-500/10 hover:bg-primary-500 text-primary-600 hover:text-white transition-colors duration-300 relative z-20"
                        >
                          {playingId === loop.id ? 
                            <Pause className="w-4 h-4" /> : 
                            <Play className="w-4 h-4" />
                          }
                        </button>
                        <button 
                          onClick={() => downloadLoop(loop.id, loop.audio_url)}
                          className="p-2 rounded-full bg-gray-100 hover:bg-primary-500 dark:bg-gray-700 text-gray-600 hover:text-white dark:text-gray-400 dark:hover:text-white transition-colors duration-300 relative z-20"
                        >
                          <Download className="w-4 h-4" />
                        </button>
                      </div>
                    </div>

                    <div className="relative z-0">
                      <AudioPlayer
                        url={loop.audio_url}
                        isPlaying={playingId === loop.id}
                        onFinish={() => setPlayingId(null)}
                        loopId={loop.id}
                        producer={loop.producer}
                        rating={loop.rating}
                        onRatingChange={(newRating) => handleRatingChange(loop.id, newRating)}
                      />
                    </div>

                    <div className="flex items-center justify-between text-sm mt-3 relative z-10">
                      <div className="flex items-center space-x-3 text-gray-600 dark:text-gray-400">
                        <span className="px-2 py-1 glass-input text-xs font-medium">
                          {loop.bpm} BPM
                        </span>
                        <span className="px-2 py-1 glass-input text-xs font-medium">
                          {loop.key}
                        </span>
                        <span className="text-xs">{loop.downloads.toLocaleString()} downloads</span>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            ))
          )}
        </div>
      </section>
    </div>
  );
}