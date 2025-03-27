import { useEffect, useState } from 'react';
import { useOracleSimulation, formatRate } from '../lib/oracleSimulator';
import { CONTRACT_ADDRESSES } from '../lib/constants';
import { useChainId } from 'wagmi';

// Type definitions for exchange rates
type ExchangeRate = {
  address: string;
  rate: number;
  formattedRate: string;
  history: number[];
};

type ExchangeRates = {
  [address: string]: ExchangeRate;
};

/**
 * Custom hook to get and track exchange rates for LRT tokens
 */
export function useExchangeRates() {
  const chainId = useChainId();
  const network = chainId === 1 ? 'mainnet' : 'sepolia';
  const addresses = CONTRACT_ADDRESSES[network as keyof typeof CONTRACT_ADDRESSES];
  
  // Get token addresses to track
  const tokenAddresses = [
    addresses.stETH,
    addresses.rETH,
    addresses.cbETH
  ];
  
  // Use the Oracle simulation to get simulated rates
  const simulatedRates = useOracleSimulation(tokenAddresses);
  
  // State for formatted exchange rates
  const [exchangeRates, setExchangeRates] = useState<ExchangeRates>({});
  
  // Update exchange rates when simulation updates
  useEffect(() => {
    if (Object.keys(simulatedRates).length === 0) return;
    
    const formattedRates: ExchangeRates = {};
    
    // Format the rates for each token
    tokenAddresses.forEach(address => {
      if (simulatedRates[address]) {
        formattedRates[address] = {
          address,
          rate: simulatedRates[address].current,
          formattedRate: formatRate(simulatedRates[address].current),
          history: [...simulatedRates[address].history],
        };
      }
    });
    
    setExchangeRates(formattedRates);
  }, [simulatedRates, tokenAddresses]);
  
  /**
   * Calculate the exchange rate between two tokens
   * @param fromToken Source token address
   * @param toToken Destination token address
   * @returns Exchange rate as a number
   */
  const getExchangeRate = (fromToken: string, toToken: string): number => {
    const fromRate = exchangeRates[fromToken]?.rate || 1;
    const toRate = exchangeRates[toToken]?.rate || 1;
    return fromRate / toRate;
  };
  
  /**
   * Calculate output amount for a swap
   * @param fromToken Source token address
   * @param toToken Destination token address
   * @param amount Amount of source token
   * @returns Calculated output amount
   */
  const calculateSwapOutput = (fromToken: string, toToken: string, amount: number): number => {
    return amount * getExchangeRate(fromToken, toToken);
  };
  
  /**
   * Get estimated APY for a token
   * This is a simulation - in a real app, you would get this from a data provider
   */
  const getEstimatedAPY = (tokenAddress: string): number => {
    // Simulated APYs for different tokens
    const apyMap: {[key: string]: number} = {
      // Use last part of the address as a key for demo
      [addresses.stETH.substring(36)]: 3.5, // stETH: 3.5%
      [addresses.rETH.substring(36)]: 4.2, // rETH: 4.2%
      [addresses.cbETH.substring(36)]: 3.8, // cbETH: 3.8%
    };
    
    // Use the token address suffix as a key
    const tokenKey = tokenAddress.substring(36);
    
    // Return the APY or a default value
    return apyMap[tokenKey] || 3.0;
  };
  
  return {
    exchangeRates,
    getExchangeRate,
    calculateSwapOutput,
    getEstimatedAPY
  };
} 