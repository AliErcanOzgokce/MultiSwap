import { useMultiLRTContract } from '../hooks/useMultiLRTContract';
import { formatTokenAmount, formatUSD } from '../utils/formatters';
import { useAccount } from 'wagmi';

export function UserBalance() {
  const { basketTokenBalance, basketTokenPrice, basketDecimals, isLoading } = useMultiLRTContract();
  const { isConnected } = useAccount();
  
  if (!isConnected) {
    return (
      <div className="p-6 rounded-lg bg-gray-800 shadow-md mb-6">
        <h2 className="text-xl font-bold mb-4">Your Balance</h2>
        <p className="text-gray-300">Connect your wallet to view your balance</p>
      </div>
    );
  }
  
  if (isLoading) {
    return (
      <div className="p-6 rounded-lg bg-gray-800 shadow-md mb-6">
        <h2 className="text-xl font-bold mb-4">Your Balance</h2>
        <p className="text-gray-300">Loading balance...</p>
      </div>
    );
  }
  
  // Calculate balance in USD
  const balanceInUsd = basketTokenBalance && basketTokenPrice
    ? basketTokenBalance * basketTokenPrice / BigInt(10 ** (basketDecimals || 18))
    : BigInt(0);
  
  // Format for display
  const formattedBalance = formatTokenAmount(basketTokenBalance || BigInt(0), basketDecimals || 18);
  const formattedBalanceUsd = formatUSD(balanceInUsd);
  
  return (
    <div className="p-6 rounded-lg bg-gray-800 shadow-md mb-6">
      <h2 className="text-xl font-bold mb-4">Your Balance</h2>
      
      <div className="bg-gray-700 p-4 rounded-lg">
        <p className="text-gray-400 text-sm">Basket Token Balance</p>
        <p className="text-2xl font-bold">{formattedBalance}</p>
        <p className="text-sm text-gray-400">{formattedBalanceUsd}</p>
      </div>
    </div>
  );
} 