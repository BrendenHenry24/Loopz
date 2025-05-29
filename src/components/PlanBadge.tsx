import React from 'react';
import { Crown, Gem, User } from 'lucide-react';

interface PlanBadgeProps {
  tier: string;
}

export default function PlanBadge({ tier }: PlanBadgeProps) {
  const plans = {
    basic: {
      icon: User,
      label: 'Basic Plan',
      className: 'bg-gray-100 dark:bg-gray-800 text-gray-600 dark:text-gray-400 shadow-sm'
    },
    pro: {
      icon: Gem,
      label: 'Pro Plan',
      className: 'bg-indigo-100 dark:bg-indigo-900/30 text-indigo-600 dark:text-indigo-400 shadow-indigo-500/20 dark:shadow-indigo-400/20'
    },
    enterprise: {
      icon: Crown,
      label: 'Enterprise Plan',
      className: 'bg-amber-100 dark:bg-amber-900/30 text-amber-600 dark:text-amber-400 shadow-amber-500/20 dark:shadow-amber-400/20'
    }
  };

  const plan = plans[tier as keyof typeof plans] || plans.basic;
  const Icon = plan.icon;

  return (
    <div className={`flex items-center space-x-1.5 px-3 py-1.5 rounded-full text-sm font-medium shadow-lg ${plan.className} transition-all duration-300 hover:scale-105`}>
      <Icon className="w-4 h-4" />
      <span>{plan.label}</span>
    </div>
  );
}