import { useState, useEffect } from 'react';
import { useMultiLRTContract } from '../hooks/useMultiLRTContract';
import { formatTokenAmount } from '../utils/formatters';
import { useAccount } from 'wagmi';

export function SwapInterface() {
  const { isConnected } = useAccount();
  const { tokens, isLoading, mint, burn, connectionError } = useMultiLRTContract();
  
  const [inputAmount, setInputAmount] = useState<string>('');
  const [selectedToken, setSelectedToken] = useState<string>('');
  const [isDeposit, setIsDeposit] = useState<boolean>(true);
  const [isProcessing, setIsProcessing] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  
  // Reset error on input change
  useEffect(() => {
    setError(null);
    setSuccessMessage(null);
  }, [inputAmount, selectedToken, isDeposit]);
  
  // Set default selected token when tokens load
  useEffect(() => {
    if (tokens.length > 0 && !selectedToken) {
      setSelectedToken(tokens[0].address);
    }
  }, [tokens, selectedToken]);
  
  const handleAmountChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    if (value === '' || /^\d*\.?\d*$/.test(value)) {
      setInputAmount(value);
    }
  };
  
  const handleTokenChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    setSelectedToken(e.target.value);
  };
  
  const handleSwapTypeToggle = () => {
    setIsDeposit(!isDeposit);
  };
  
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!inputAmount || parseFloat(inputAmount) <= 0) {
      setError('Please enter a valid amount');
      return;
    }
    
    setIsProcessing(true);
    setError(null);
    setSuccessMessage(null);
    
    try {
      if (isDeposit) {
        // Deposit/Mint
        await mint(selectedToken, inputAmount);
        setSuccessMessage(`Successfully minted basket tokens with ${inputAmount} ${tokens.find(t => t.address === selectedToken)?.symbol}`);
      } else {
        // Withdraw/Burn
        await burn(inputAmount);
        setSuccessMessage(`Successfully burned ${inputAmount} basket tokens`);
      }
      
      // Clear the form on success
      setInputAmount('');
    } catch (err) {
      console.error('Transaction failed:', err);
      setError('Transaction failed. Please check your wallet and try again.');
    } finally {
      setIsProcessing(false);
    }
  };
  
  if (!isConnected) {
    return (
      <div className="p-6 rounded-lg bg-gray-800 shadow-md">
        <h2 className="text-xl font-bold mb-4">Swap Tokens</h2>
        <p className="text-gray-300">Connect your wallet to swap tokens</p>
      </div>
    );
  }
  
  if (connectionError) {
    return (
      <div className="p-6 rounded-lg bg-gray-800 shadow-md">
        <h2 className="text-xl font-bold mb-4">Swap Tokens</h2>
        <div className="bg-red-900/30 border border-red-700 rounded-lg p-4 mb-4">
          <p className="text-red-300">{connectionError}</p>
          <p className="text-red-300 text-sm mt-2">
            Make sure you are connected to the Unichain Sepolia network.
          </p>
        </div>
      </div>
    );
  }
  
  if (isLoading) {
    return (
      <div className="p-6 rounded-lg bg-gray-800 shadow-md">
        <h2 className="text-xl font-bold mb-4">Swap Tokens</h2>
        <p className="text-gray-300">Loading tokens...</p>
      </div>
    );
  }
  
  const selectedTokenObj = tokens.find(t => t.address === selectedToken);
  const formattedBalance = selectedTokenObj 
    ? formatTokenAmount(selectedTokenObj.balance, selectedTokenObj.decimals)
    : '0';
  
  return (
    <div className="p-6 rounded-lg bg-gray-800 shadow-md">
      <div className="flex justify-between items-center mb-6">
        <h2 className="text-xl font-bold">Swap Tokens</h2>
        <div className="flex">
          <button 
            className={`px-4 py-2 rounded-l-md ${isDeposit ? 'bg-blue-600 text-white' : 'bg-gray-700 text-gray-300'}`}
            onClick={() => setIsDeposit(true)}
          >
            Deposit
          </button>
          <button 
            className={`px-4 py-2 rounded-r-md ${!isDeposit ? 'bg-blue-600 text-white' : 'bg-gray-700 text-gray-300'}`}
            onClick={() => setIsDeposit(false)}
          >
            Withdraw
          </button>
        </div>
      </div>
      
      <form onSubmit={handleSubmit}>
        <div className="mb-4">
          <label className="block text-sm text-gray-400 mb-2">
            {isDeposit ? 'Deposit Amount' : 'Withdraw Amount'}
          </label>
          <div className="flex flex-col space-y-2">
            <div className="relative">
              <input 
                type="text"
                value={inputAmount}
                onChange={handleAmountChange}
                placeholder="0.0"
                className="w-full p-3 bg-gray-700 rounded-md focus:ring-2 focus:ring-blue-500 outline-none"
                disabled={isProcessing}
              />
              {isDeposit && (
                <button 
                  type="button"
                  className="absolute right-3 top-1/2 transform -translate-y-1/2 text-sm text-blue-400 hover:text-blue-300"
                  onClick={() => {
                    if (selectedTokenObj) {
                      const maxAmount = formatTokenAmount(selectedTokenObj.balance, selectedTokenObj.decimals, true);
                      setInputAmount(maxAmount);
                    }
                  }}
                >
                  MAX
                </button>
              )}
            </div>
            
            {isDeposit && (
              <div className="flex justify-between text-sm text-gray-400">
                <span>Balance: {formattedBalance}</span>
                <span>Token: {selectedTokenObj?.symbol || 'Unknown'}</span>
              </div>
            )}
          </div>
        </div>
        
        {isDeposit && (
          <div className="mb-6">
            <label className="block text-sm text-gray-400 mb-2">
              Select Token
            </label>
            <select
              value={selectedToken}
              onChange={handleTokenChange}
              className="w-full p-3 bg-gray-700 rounded-md focus:ring-2 focus:ring-blue-500 outline-none"
              disabled={isProcessing}
            >
              {tokens.map(token => (
                <option key={token.address} value={token.address}>
                  {token.symbol}
                </option>
              ))}
            </select>
          </div>
        )}
        
        {error && (
          <div className="p-3 mb-4 bg-red-900/50 border border-red-700 rounded-md text-red-300">
            {error}
          </div>
        )}
        
        {successMessage && (
          <div className="p-3 mb-4 bg-green-900/50 border border-green-700 rounded-md text-green-300">
            {successMessage}
          </div>
        )}
        
        <button
          type="submit"
          className={`w-full py-3 rounded-md font-bold ${
            isProcessing 
              ? 'bg-gray-600 cursor-not-allowed' 
              : 'bg-blue-600 hover:bg-blue-700'
          }`}
          disabled={isProcessing || !inputAmount}
        >
          {isProcessing 
            ? 'Processing...' 
            : isDeposit 
              ? 'Deposit and Mint Basket Token' 
              : 'Withdraw from Basket Token'
          }
        </button>
      </form>
    </div>
  );
}

// Helper function for formatting percentage
function formatPercentage(value: number | undefined, total: number): string {
  if (!value || !total) return '0%';
  const percentage = (value / total) * 100;
  return `${percentage.toFixed(2)}%`;
} 