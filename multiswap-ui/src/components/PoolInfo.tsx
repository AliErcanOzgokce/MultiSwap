import { useMultiLRTContract } from '../hooks/useMultiLRTContract';
import { formatTokenAmount, formatPercentage, formatUSD } from '../utils/formatters';
import { BLOCK_EXPLORERS } from '../lib/constants';
import { useAccount } from 'wagmi';

export function PoolInfo() {
  const { isConnected } = useAccount();
  const { 
    tokens, 
    isLoading, 
    totalWeight,
    basketTotalSupply,
    basketTokenPrice,
    basketDecimals,
    networkName,
    connectionError
  } = useMultiLRTContract();

  if (!isConnected) {
    return (
      <div className="p-6 rounded-lg bg-gray-800 shadow-md">
        <h2 className="text-xl font-bold mb-4">Pool Information</h2>
        <p className="text-gray-300">Connect your wallet to view pool information</p>
      </div>
    );
  }

  if (isLoading) {
    return (
      <div className="p-6 rounded-lg bg-gray-800 shadow-md">
        <h2 className="text-xl font-bold mb-4">Pool Information</h2>
        <p className="text-gray-300">Loading pool data...</p>
      </div>
    );
  }
  
  if (connectionError) {
    return (
      <div className="p-6 rounded-lg bg-gray-800 shadow-md">
        <h2 className="text-xl font-bold mb-4">Pool Information</h2>
        <div className="bg-red-900/30 border border-red-700 rounded-lg p-4 mb-4">
          <p className="text-red-300">{connectionError}</p>
          <p className="text-red-300 text-sm mt-2">
            Make sure you are connected to the Unichain Sepolia network.
          </p>
        </div>
      </div>
    );
  }

  // Calculate total pool value in USD
  const totalPoolValueInWei = basketTotalSupply && basketTokenPrice 
    ? basketTotalSupply * basketTokenPrice / BigInt(10 ** (basketDecimals || 18))
    : BigInt(0);

  // Format for display
  const formattedTotalPoolValue = formatUSD(totalPoolValueInWei);
  const formattedTotalSupply = formatTokenAmount(basketTotalSupply || BigInt(0), basketDecimals || 18);

  // Generate explorer URLs
  const explorerBaseUrl = BLOCK_EXPLORERS[networkName as keyof typeof BLOCK_EXPLORERS];

  // Get token percentages for display
  const percentages = {};
  let totalPercentage = 0;
  
  tokens.forEach(token => {
    if (token.weight && totalWeight) {
      const percent = (token.weight / Number(totalWeight)) * 100;
      percentages[token.address] = percent;
      totalPercentage += percent;
    }
  });

  return (
    <div className="p-6 rounded-lg bg-gray-800 shadow-md">
      <h2 className="text-xl font-bold mb-4">Pool Information</h2>
      
      <div className="grid grid-cols-2 gap-4 mb-6">
        <div className="bg-gray-700 p-4 rounded-lg">
          <p className="text-gray-400 text-sm">Total Value Locked</p>
          <p className="text-2xl font-bold">{formattedTotalPoolValue}</p>
        </div>
        <div className="bg-gray-700 p-4 rounded-lg">
          <p className="text-gray-400 text-sm">Total Supply</p>
          <p className="text-2xl font-bold">{formattedTotalSupply}</p>
        </div>
      </div>

      <h3 className="text-lg font-semibold mb-3">Token Allocation</h3>
      <div className="space-y-4">
        {tokens.map(token => {
          const weightPercentage = token.weight && totalWeight 
            ? formatPercentage(token.weight, Number(totalWeight)) 
            : '0%';
          
          return (
            <div key={token.address} className="bg-gray-700 p-4 rounded-lg flex items-center justify-between">
              <div className="flex items-center">
                <div className="w-8 h-8 rounded-full bg-blue-500 flex items-center justify-center mr-3">
                  {token.symbol?.charAt(0)}
                </div>
                <div>
                  <p className="font-medium">{token.symbol}</p>
                  <a 
                    href={`${explorerBaseUrl}/address/${token.address}`}
                    target="_blank" 
                    rel="noopener noreferrer"
                    className="text-xs text-blue-400 hover:text-blue-300"
                  >
                    {token.address.slice(0, 6)}...{token.address.slice(-4)}
                  </a>
                </div>
              </div>
              <div className="text-right">
                <p className="font-bold">{weightPercentage}</p>
                <p className="text-xs text-gray-400">Weight: {token.weight?.toLocaleString()}</p>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
} 