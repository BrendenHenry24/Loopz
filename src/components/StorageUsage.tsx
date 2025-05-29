import React from 'react';
import { useStorageLimit } from '../hooks/useStorageLimit';
import { useAuthStore } from '../stores/authStore';
import { MEMBERSHIP_LIMITS } from '../types/membership';
import { HardDrive } from 'lucide-react';

export default function StorageUsage() {
  const { storageUsed, isLoading, formatBytes } = useStorageLimit();
  const { user } = useAuthStore();
  
  if (!user || isLoading) return null;

  const tier = user.membership_tier || 'basic';
  const limit = MEMBERSHIP_LIMITS[tier].storageLimit;
  const usagePercentage = (storageUsed / limit) * 100;
  const isNearLimit = usagePercentage >= 80;

  return (
    <div className="glass-panel p-4">
      <div className="flex items-center justify-between mb-2">
        <div className="flex items-center space-x-2">
          <HardDrive className="w-5 h-5 text-primary-500" />
          <h3 className="font-medium">Storage Usage</h3>
        </div>
        <span className="text-sm text-gray-600 dark:text-gray-400">
          {tier.charAt(0).toUpperCase() + tier.slice(1)} Plan
        </span>
      </div>

      <div className="space-y-2">
        <div className="w-full h-2 bg-gray-200 dark:bg-gray-700 rounded-full overflow-hidden">
          <div 
            className={`h-full rounded-full transition-all duration-300 ${
              isNearLimit ? 'bg-yellow-500' : 'bg-primary-500'
            }`}
            style={{ width: `${Math.min(usagePercentage, 100)}%` }}
          />
        </div>

        <div className="flex justify-between text-sm">
          <span>{formatBytes(storageUsed)} used</span>
          <span>{formatBytes(limit)} total</span>
        </div>

        {isNearLimit && (
          <p className="text-sm text-yellow-500 dark:text-yellow-400">
            You're approaching your storage limit. Consider upgrading your plan.
          </p>
        )}
      </div>
    </div>
  );
}