import React from 'react';
import { useNavigate } from 'react-router-dom';
import { Check, Music, Download, Star, Zap, BarChart2, Code2, Users, Crown } from 'lucide-react';
import { useAuthStore } from '../stores/authStore';
import toast from 'react-hot-toast';
import { useEffect } from 'react';

const features = {
  basic: [
    '25 loops uploaded at a time',
    '100 downloads monthly',
    'Basic audio analysis',
    'Standard quality downloads (192kbps)',
    'Community features',
  ],
  pro: [
    '100 loops uploaded at a time',
    '250 downloads monthly',
    'Advanced audio analysis',
    'High quality downloads (320kbps + WAV)',
    'Custom profile page',
    'Featured placement in search',
    'Download statistics',
    'Bulk upload tools',
    'No watermark on previews',
    'Priority support',
  ],
  enterprise: [
    'Unlimited loop uploads',
    'Unlimited downloads',
    'Everything in Pro plan',
    'API access',
    'Custom licensing options',
    'White-label option',
    'Revenue sharing from sales',
    'Dedicated account manager',
    'Early access features',
    'Custom watermark',
    'Team collaboration',
  ],
  prices: {
    basic: 'free',
    pro: 'price_1OqXYzGXoqNc1krhJ8K9L2Mv',
    enterprise: 'price_1OqXZNGXoqNc1krhM5K2P9Qw'
  }
};

export default function Pricing() {
  const navigate = useNavigate();
  const { user } = useAuthStore();

  useEffect(() => {
    // Load Stripe.js
    const script = document.createElement('script');
    script.src = 'https://js.stripe.com/v3/buy-button.js';
    script.async = true;
    document.body.appendChild(script);

    return () => {
      document.body.removeChild(script);
    };
  }, []);

  const handleSubscribe = async (plan: string) => {
    if (!user) {
      navigate('/auth');
      return;
    }
    
    if (plan === 'basic') {
      toast.success('You are now on the Basic plan');
    }
  };

  return (
    <div className="py-12 px-4 sm:px-6 lg:px-8">
      <div className="text-center mb-12">
        <h1 className="text-4xl font-bold gradient-text mb-4">
          Choose Your Plan
        </h1>
        <p className="text-xl text-gray-600 dark:text-gray-400">
          Start sharing your beats with producers worldwide
        </p>
      </div>

      <div className="max-w-7xl mx-auto grid grid-cols-1 gap-8 lg:grid-cols-3">
        {/* Basic Plan */}
        <div className="glass-panel p-8 relative overflow-hidden">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h3 className="text-2xl font-bold gradient-text">Basic</h3>
              <p className="text-gray-600 dark:text-gray-400">For hobbyists</p>
            </div>
            <Music className="w-8 h-8 text-primary-500" />
          </div>
          
          <div className="mb-6">
            <span className="text-4xl font-bold">Free</span>
            <span className="text-gray-600 dark:text-gray-400">/month</span>
          </div>

          <ul className="space-y-4 mb-8">
            {features.basic.map((feature, index) => (
              <li key={index} className="flex items-center">
                <Check className="w-5 h-5 text-green-500 mr-2" />
                <span className="text-gray-700 dark:text-gray-300">{feature}</span>
              </li>
            ))}
          </ul>

          <button
            onClick={() => handleSubscribe('basic')}
            className="w-full py-3 px-6 rounded-lg bg-primary-500/10 text-primary-600 
                     hover:bg-primary-500 hover:text-white transition-colors duration-200"
          >
            Get Started
          </button>
        </div>

        {/* Pro Plan */}
        <div className="glass-panel p-8 relative overflow-hidden border-2 border-primary-500">
          <div className="absolute top-4 right-4 bg-primary-500 text-white px-3 py-1 rounded-full text-sm">
            Popular
          </div>
          
          <div className="flex items-center justify-between mb-4">
            <div>
              <h3 className="text-2xl font-bold gradient-text">Pro</h3>
              <p className="text-gray-600 dark:text-gray-400">For serious producers</p>
            </div>
            <Star className="w-8 h-8 text-primary-500" />
          </div>
          
          <div className="mb-6">
            <span className="text-4xl font-bold">$20</span>
            <span className="text-gray-600 dark:text-gray-400">/month</span>
          </div>

          <ul className="space-y-4 mb-8">
            {features.pro.map((feature, index) => (
              <li key={index} className="flex items-center">
                <Check className="w-5 h-5 text-green-500 mr-2" />
                <span className="text-gray-700 dark:text-gray-300">{feature}</span>
              </li>
            ))}
          </ul>

          <stripe-buy-button
            buy-button-id="buy_btn_1QUcQ0GXoqNc1krh9F5BFzry"
            publishable-key="pk_test_51QUc8nGXoqNc1krhSI3BbjXwSGwre01huzKZASGpr93lehTP9xjAz0mj4KRbAbjRsbbUckJpOikd0mOhZI4zLmBA006Z5HYYhZ"
          >
          </stripe-buy-button>
        </div>

        {/* Enterprise Plan */}
        <div className="glass-panel p-8 relative overflow-hidden">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h3 className="text-2xl font-bold gradient-text">Enterprise</h3>
              <p className="text-gray-600 dark:text-gray-400">For studios & labels</p>
            </div>
            <Crown className="w-8 h-8 text-primary-500" />
          </div>
          
          <div className="mb-6">
            <span className="text-4xl font-bold">$49</span>
            <span className="text-gray-600 dark:text-gray-400">/month</span>
          </div>

          <ul className="space-y-4 mb-8">
            {features.enterprise.map((feature, index) => (
              <li key={index} className="flex items-center">
                <Check className="w-5 h-5 text-green-500 mr-2" />
                <span className="text-gray-700 dark:text-gray-300">{feature}</span>
              </li>
            ))}
          </ul>

          <stripe-buy-button
            buy-button-id="buy_btn_1QUdaoGXoqNc1krhu7Wj5ZiA"
            publishable-key="pk_test_51QUc8nGXoqNc1krhSI3BbjXwSGwre01huzKZASGpr93lehTP9xjAz0mj4KRbAbjRsbbUckJpOikd0mOhZI4zLmBA006Z5HYYhZ"
          >
          </stripe-buy-button>
        </div>
      </div>

      <div className="mt-16 max-w-3xl mx-auto text-center">
        <h2 className="text-2xl font-bold gradient-text mb-8">
          Why Choose Loopz.music?
        </h2>
        
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8">
          <div className="glass-panel p-6">
            <Music className="w-8 h-8 text-primary-500 mx-auto mb-4" />
            <h3 className="font-semibold mb-2">High Quality Audio</h3>
            <p className="text-gray-600 dark:text-gray-400 text-sm">
              Professional grade audio formats and pristine sound quality
            </p>
          </div>
          
          <div className="glass-panel p-6">
            <BarChart2 className="w-8 h-8 text-primary-500 mx-auto mb-4" />
            <h3 className="font-semibold mb-2">Detailed Analytics</h3>
            <p className="text-gray-600 dark:text-gray-400 text-sm">
              Track your loops' performance and audience engagement
            </p>
          </div>
          
          <div className="glass-panel p-6">
            <Users className="w-8 h-8 text-primary-500 mx-auto mb-4" />
            <h3 className="font-semibold mb-2">Growing Community</h3>
            <p className="text-gray-600 dark:text-gray-400 text-sm">
              Connect with producers and artists worldwide
            </p>
          </div>
          
          <div className="glass-panel p-6">
            <Zap className="w-8 h-8 text-primary-500 mx-auto mb-4" />
            <h3 className="font-semibold mb-2">Fast Delivery</h3>
            <p className="text-gray-600 dark:text-gray-400 text-sm">
              Lightning-fast downloads and seamless integration
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}