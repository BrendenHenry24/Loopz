import React from 'react';
import { useTheme } from '../context/ThemeContext';

export default function Background() {
  const { theme } = useTheme();
  
  return (
    <div className={`fixed inset-0 ${theme === 'dark' ? 'bg-gradient-dark' : 'bg-gradient-light'}`}>
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_top,_var(--tw-gradient-stops))] from-primary-500/10 via-primary-500/5 to-transparent"></div>
    </div>
  );
}