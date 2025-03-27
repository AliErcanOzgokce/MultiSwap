'use client';

import { useState, useEffect } from 'react';
import { PoolInfo } from '../components/PoolInfo';
import { SwapInterface } from '../components/SwapInterface';
import { UserBalance } from '../components/UserBalance';
import { useAccount, useChainId } from 'wagmi';
import { APP_SETTINGS } from '../lib/constants';

export default function Home() {
  const { isConnected, address } = useAccount();
  const chainId = useChainId();
  const [isWrongNetwork, setIsWrongNetwork] = useState(false);
  
  // Check if user is on the wrong network
  useEffect(() => {
    if (isConnected && chainId !== APP_SETTINGS.defaultChainId) {
      setIsWrongNetwork(true);
    } else {
      setIsWrongNetwork(false);
    }
  }, [isConnected, chainId]);

  return (
    <main className="min-h-screen flex flex-col bg-gray-900 text-white p-6">
      <header className="container mx-auto mb-8">
        <div className="flex justify-between items-center">
          <h1 className="text-3xl font-bold">MultiSwap</h1>
          <div>
            
              <w3m-button />
           
          </div>
        </div>
      </header>

      {isWrongNetwork && (
        <div className="container mx-auto mb-6">
          <div className="bg-yellow-900/30 border border-yellow-700 rounded-lg p-4">
            <p className="text-yellow-300 font-medium">Please connect to Unichain Sepolia Network</p>
            <p className="text-yellow-300/70 text-sm mt-1">
              The MultiSwap contracts are deployed on Unichain Sepolia (Chain ID: {APP_SETTINGS.defaultChainId}).
              Please switch your network to continue.
            </p>
          </div>
        </div>
      )}

      <div className="container mx-auto flex-grow">
        {isConnected && <UserBalance />}
        
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <PoolInfo />
          </div>
          <div>
            <SwapInterface />
          </div>
        </div>
      </div>

      <footer className="container mx-auto mt-12 pt-6 border-t border-gray-800 text-center text-gray-500">
        <p>MultiSwap - Unichain Sepolia Testnet</p>
        <p className="text-sm mt-2">Powered by Uniswap v4 and Universal Liquid Restaking Tokens</p>
      </footer>
    </main>
  );
}
