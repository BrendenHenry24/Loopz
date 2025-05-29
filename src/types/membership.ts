export type MembershipTier = 'basic' | 'pro' | 'enterprise';

export interface MembershipLimits {
  storageLimit: number; // in bytes
  maxLoops: number;
  downloadLimit: number;
}

export const MEMBERSHIP_LIMITS: Record<MembershipTier, MembershipLimits> = {
  basic: {
    storageLimit: 20 * 1024 * 1024, // 20MB
    maxLoops: 25,
    downloadLimit: 100
  },
  pro: {
    storageLimit: 100 * 1024 * 1024, // 100MB
    maxLoops: 100,
    downloadLimit: 250
  },
  enterprise: {
    storageLimit: 250 * 1024 * 1024, // 250MB
    maxLoops: Infinity,
    downloadLimit: Infinity
  }
};