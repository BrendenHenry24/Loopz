import React, { useState } from 'react';
import { Search as SearchIcon, Filter, X } from 'lucide-react';

export interface SearchFilters {
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

interface SearchProps {
  onSearch: (query: string, filters: SearchFilters) => void;
}

const musicalKeys = ['C', 'Cm', 'D', 'Dm', 'E', 'Em', 'F', 'Fm', 'G', 'Gm', 'A', 'Am', 'B', 'Bm'];
const bpmRanges = ['Any BPM', '80-100', '100-120', '120-140', '140+'];

export default function Search({ onSearch }: SearchProps) {
  const [query, setQuery] = useState('');
  const [showFilters, setShowFilters] = useState(false);
  const [filters, setFilters] = useState<SearchFilters>(DEFAULT_FILTERS);

  const handleSearch = () => {
    onSearch(query, filters);
  };

  const handleClear = () => {
    setQuery('');
    setFilters(DEFAULT_FILTERS);
    onSearch('', DEFAULT_FILTERS);
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      handleSearch();
    }
  };

  const clearSearch = () => {
    setQuery('');
    setFilters(DEFAULT_FILTERS);
    onSearch('', DEFAULT_FILTERS);
  };

  return (
    <div className="w-full max-w-2xl mx-auto space-y-4">
      <div className="relative flex items-center group">
        <div className="relative flex-grow">
          <div className="relative">
            <input
              type="text"
              placeholder="Search loops, producers, or styles..."
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              onKeyPress={handleKeyPress}
              className="w-full pl-10 pr-14 py-3 glass-input bg-white/40 dark:bg-white/5 
                        focus:bg-white/60 dark:focus:bg-white/10 transition-all duration-300
                        text-base placeholder:text-gray-400 dark:placeholder:text-gray-500"
            />
            <SearchIcon className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 
                                 text-primary-500 dark:text-primary-400 transition-colors duration-300" />
            
            {query && (
              <button
                onClick={handleClear}
                className="absolute right-16 top-1/2 -translate-y-1/2 p-1 rounded-full
                         hover:bg-gray-100 dark:hover:bg-white/10 transition-colors duration-300"
              >
                <X className="w-3.5 h-3.5 text-gray-400 dark:text-gray-500" />
              </button>
            )}
          </div>
        </div>
        <button
          onClick={() => setShowFilters(!showFilters)}
          className={`ml-2 p-3 glass-input hover:bg-white/60 dark:hover:bg-white/10 
                     transition-all duration-300 ${showFilters ? 'bg-primary-100 dark:bg-primary-900/20' : ''}`}
        >
          <Filter className={`w-4 h-4 ${showFilters 
            ? 'text-primary-600 dark:text-primary-400' 
            : 'text-gray-400 dark:text-gray-500'}`} 
          />
        </button>
      </div>

      {showFilters && (
        <div className="glass-panel p-4 grid grid-cols-1 md:grid-cols-3 gap-4 animate-fadeIn">
          <div className="space-y-1.5">
            <label className="text-sm font-medium text-gray-600 dark:text-gray-300">
              Search Type
            </label>
            <select
              value={filters.type}
              onChange={(e) => setFilters({ ...filters, type: e.target.value as SearchFilters['type'] })}
              className="w-full p-2 glass-input bg-white/40 dark:bg-white/5 
                       focus:bg-white/60 dark:focus:bg-white/10 transition-all duration-300"
            >
              <option value="all">All</option>
              <option value="producer">Producers</option>
              <option value="loop">Loops</option>
              <option value="style">Styles</option>
            </select>
          </div>

          <div className="space-y-1.5">
            <label className="text-sm font-medium text-gray-600 dark:text-gray-300">
              BPM Range
            </label>
            <select
              value={filters.bpmRange}
              onChange={(e) => setFilters({ ...filters, bpmRange: e.target.value })}
              className="w-full p-2 glass-input bg-white/40 dark:bg-white/5 
                       focus:bg-white/60 dark:focus:bg-white/10 transition-all duration-300"
            >
              {bpmRanges.map((range) => (
                <option key={range} value={range}>{range}</option>
              ))}
            </select>
          </div>

          <div className="space-y-1.5">
            <label className="text-sm font-medium text-gray-600 dark:text-gray-300">
              Key
            </label>
            <select
              value={filters.key}
              onChange={(e) => setFilters({ ...filters, key: e.target.value })}
              className="w-full p-2 glass-input bg-white/40 dark:bg-white/5 
                       focus:bg-white/60 dark:focus:bg-white/10 transition-all duration-300"
            >
              <option value="Any Key">Any Key</option>
              {musicalKeys.map((key) => (
                <option key={key} value={key}>{key}</option>
              ))}
            </select>
          </div>
        </div>
      )}
    </div>
  );
}