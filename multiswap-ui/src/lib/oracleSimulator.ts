import { useState, useEffect } from 'react';

// Rate type definition for token rates
type Rate = {
  current: number; // Current rate
  history: number[]; // Historical rates for chart
};

// TokenRates type for mapping token addresses to their rates
type TokenRates = {
  [tokenAddress: string]: Rate;
};

// Initial rates for tokens (will be populated dynamically)
const initialRates: TokenRates = {};

/**
 * Simulates random fluctuations in ETH price
 * Generates changes between -3% and +3%
 */
const simulateRateChange = (currentRate: number): number => {
  // Random percentage change between -3% and +3%
  const changePercent = (Math.random() * 6) - 3;
  const changeAmount = currentRate * (changePercent / 100);
  return Math.max(0.001, currentRate + changeAmount); // Ensure rate doesn't go below 0.001
};

/**
 * Adds a token to the simulation with an initial rate
 */
const addTokenToSimulation = (tokenAddress: string, initialRate = 1): void => {
  if (!initialRates[tokenAddress]) {
    initialRates[tokenAddress] = {
      current: initialRate,
      history: [initialRate]
    };
  }
};

/**
 * Gets current rate for a token
 * Default to 1:1 ratio with ETH if token not found
 */
const getCurrentRate = (tokenAddress: string): number => {
  return initialRates[tokenAddress]?.current || 1;
};

/**
 * Custom hook to use Oracle simulation
 * @param tokenAddresses - Array of token addresses to track
 * @param updateInterval - Interval in ms to update rates (default 30 seconds)
 */
export function useOracleSimulation(tokenAddresses: string[], updateInterval = 30000) {
  const [rates, setRates] = useState<TokenRates>({});

  useEffect(() => {
    // Initialize any new tokens
    tokenAddresses.forEach(address => {
      addTokenToSimulation(address);
    });

    // Set initial rates
    setRates({...initialRates});

    // Update rates periodically
    const intervalId = setInterval(() => {
      const updatedRates = {...initialRates};
      
      // Update all rates
      Object.keys(updatedRates).forEach(address => {
        const newRate = simulateRateChange(updatedRates[address].current);
        updatedRates[address].current = newRate;
        updatedRates[address].history.push(newRate);
        
        // Keep history at reasonable length
        if (updatedRates[address].history.length > 100) {
          updatedRates[address].history.shift();
        }
      });
      
      // Update state
      setRates({...updatedRates});
    }, updateInterval);

    return () => clearInterval(intervalId);
  }, [tokenAddresses, updateInterval]);

  return rates;
}

/**
 * Formats a rate into a human-readable string
 */
export function formatRate(rate: number): string {
  return `${rate.toFixed(6)} ETH`;
}

/**
 * Generates historical rate data for charts
 * @param days Number of days to generate data for
 * @param startRate Starting rate
 * @param volatility Volatility factor (0.01 = 1%)
 */
export function generateHistoricalRates(days: number, startRate = 1, volatility = 0.01): number[] {
  const dataPoints = days * 24; // Hourly data points
  const rates: number[] = [startRate];
  
  for (let i = 1; i < dataPoints; i++) {
    const previousRate = rates[i-1];
    const change = previousRate * volatility * (Math.random() * 2 - 1);
    rates.push(Math.max(0.001, previousRate + change));
  }
  
  return rates;
}

export { getCurrentRate, addTokenToSimulation }; 