import React from 'react';
import { Link } from 'react-router-dom';

interface ProducerLinkProps {
  producer: {
    id: string;
    username: string;
    avatar_url?: string;
  };
  className?: string;
}

export default function ProducerLink({ producer, className = '' }: ProducerLinkProps) {
  return (
    <Link 
      to={`/${producer.username}`}
      className={`flex items-center space-x-2 hover:text-primary-500 transition-colors ${className}`}
    >
      <img 
        src={producer.avatar_url || `https://ui-avatars.com/api/?name=${producer.username}&background=8b5cf6&color=fff`}
        alt={producer.username}
        className="w-6 h-6 rounded-full border border-white/20"
      />
      <span className="truncate">{producer.username}</span>
    </Link>
  );
}