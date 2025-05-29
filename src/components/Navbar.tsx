import React, { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Music4, Upload, User, Sun, Moon, LogOut, Menu, X } from 'lucide-react';
import { useTheme } from '../context/ThemeContext';
import { useAuthStore } from '../stores/authStore';
import toast from 'react-hot-toast';

interface NavLinkProps {
  to: string;
  onClick?: () => void;
  children: React.ReactNode;
}

const NavLink = ({ to, onClick, children }: NavLinkProps) => (
  <Link 
    to={to}
    onClick={onClick}
    className="flex items-center space-x-2 px-4 py-2 text-gray-700 dark:text-gray-300 hover:text-primary-500 dark:hover:text-primary-400 transition-colors"
  >
    {children}
  </Link>
);

export default function Navbar() {
  const { theme, toggleTheme } = useTheme();
  const { user, signOut } = useAuthStore();
  const navigate = useNavigate();
  const [isOpen, setIsOpen] = useState(false);

  // Close menu when route changes
  useEffect(() => {
    setIsOpen(false);
  }, [navigate]);

  // Close menu when clicking outside
  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      const nav = document.getElementById('mobile-nav');
      const button = document.getElementById('menu-button');
      if (isOpen && nav && button && !nav.contains(e.target as Node) && !button.contains(e.target as Node)) {
        setIsOpen(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, [isOpen]);

  const handleSignOut = async () => {
    try {
      await signOut();
      toast.success('Successfully signed out');
      navigate('/');
      setIsOpen(false);
    } catch (error) {
      toast.error('Failed to sign out');
      console.error('Sign out error:', error);
    }
  };

  return (
    <nav className="bg-white/80 dark:bg-gray-900/80 backdrop-blur-md border-b border-white/20 fixed top-0 left-0 right-0 z-50">
      <div className="container mx-auto px-4 relative">
        <div className="flex items-center justify-between h-16 relative">
          <Link to="/" className="flex items-center space-x-2">
            <Music4 className="h-8 w-8 text-primary-500" />
            <span className="text-xl font-bold gradient-text">Loopz.music</span>
          </Link>
          
          {/* Desktop Navigation */}
          <div className="hidden md:flex items-center space-x-6">
            <NavLink to="/pricing">Pricing</NavLink>
            
            {user ? (
              <>
                <NavLink to="/upload">
                  <Upload className="h-5 w-5" />
                  <span>Upload</span>
                </NavLink>
                
                <NavLink to="/profile">
                  <User className="h-5 w-5" />
                  <span>Profile</span>
                </NavLink>

                <button
                  onClick={handleSignOut}
                  className="flex items-center space-x-2 px-4 py-2 text-gray-700 dark:text-gray-300 hover:text-primary-500 dark:hover:text-primary-400 transition-colors"
                >
                  <LogOut className="h-5 w-5" />
                  <span>Sign Out</span>
                </button>
              </>
            ) : (
              <NavLink to="/login">
                <User className="h-5 w-5" />
                <span>Sign In</span>
              </NavLink>
            )}
            
            <button
              onClick={toggleTheme}
              className="p-2 text-gray-700 dark:text-gray-300 hover:text-primary-500 dark:hover:text-primary-400 transition-colors"
            >
              {theme === 'dark' ? <Sun className="h-5 w-5" /> : <Moon className="h-5 w-5" />}
            </button>
          </div>

          {/* Mobile Menu Button */}
          <div className="flex items-center space-x-4 md:hidden">
            <button
              onClick={toggleTheme}
              className="p-2 text-gray-700 dark:text-gray-300 hover:text-primary-500 dark:hover:text-primary-400 transition-colors"
            >
              {theme === 'dark' ? <Sun className="h-5 w-5" /> : <Moon className="h-5 w-5" />}
            </button>
            <button
              id="menu-button"
              onClick={() => setIsOpen(!isOpen)}
              className="p-2 text-gray-700 dark:text-gray-300 hover:text-primary-500 dark:hover:text-primary-400 transition-colors"
              aria-label="Toggle menu"
            >
              {isOpen ? <X className="h-6 w-6" /> : <Menu className="h-6 w-6" />}
            </button>
          </div>

          {/* Mobile Navigation */}
          <div
            id="mobile-nav"
            className={`absolute top-full left-0 right-0 bg-white/95 dark:bg-gray-900/95 backdrop-blur-md border-b border-white/20 md:hidden transition-all duration-300 ease-in-out ${
              isOpen ? 'opacity-100 translate-y-0' : 'opacity-0 -translate-y-2 pointer-events-none'
            }`}
          >
            <div className="py-2">
              <NavLink to="/pricing" onClick={() => setIsOpen(false)}>
                Pricing
              </NavLink>
              
              {user ? (
                <>
                  <NavLink to="/upload" onClick={() => setIsOpen(false)}>
                    <Upload className="h-5 w-5" />
                    <span>Upload</span>
                  </NavLink>
                  
                  <NavLink to="/profile" onClick={() => setIsOpen(false)}>
                    <User className="h-5 w-5" />
                    <span>Profile</span>
                  </NavLink>

                  <button
                    onClick={handleSignOut}
                    className="w-full flex items-center space-x-2 px-4 py-2 text-gray-700 dark:text-gray-300 hover:text-primary-500 dark:hover:text-primary-400 transition-colors"
                  >
                    <LogOut className="h-5 w-5" />
                    <span>Sign Out</span>
                  </button>
                </>
              ) : (
                <NavLink to="/login" onClick={() => setIsOpen(false)}>
                  <User className="h-5 w-5" />
                  <span>Sign In</span>
                </NavLink>
              )}
            </div>
          </div>
        </div>
      </div>
    </nav>
  );
}