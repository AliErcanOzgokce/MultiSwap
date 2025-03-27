import { useEffect, useState } from 'react';
import { useAccount, useChainId, useReadContract, useWriteContract } from 'wagmi';
import { parseUnits, formatUnits } from 'viem';

// Import ABIs
import MultiLRTHookABI from '../abis/MultiLRTHook.json';
import MultiLRTBasketTokenABI from '../abis/MultiLRTBasketToken.json';
import MockERC20ABI from '../abis/MockERC20.json';

// Import config and constants
import { config } from '../lib/wagmiConfig';
import { CONTRACT_ADDRESSES, WEIGHT_DENOMINATOR, DEFAULT_TOKEN_WEIGHTS } from '../lib/constants';

// Token type definition
export type Token = {
  address: string;
  symbol: string;
  name: string;
  decimals: number;
  balance: bigint;
  weight?: number;
  rate?: number;
};

// useMultiLRTContract hook
export function useMultiLRTContract() {
  const chainId = useChainId();
  const { address } = useAccount();
  
  // State for contract data
  const [tokens, setTokens] = useState<Token[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [basketTokenBalance, setBasketTokenBalance] = useState<bigint>(BigInt(0));
  const [basketTokenPrice, setBasketTokenPrice] = useState<bigint>(BigInt(0));
  const [connectionError, setConnectionError] = useState<string | null>(null);
  
  // Get contract addresses for current network
  // Use unichain as default network since that's where we deployed
  const network = chainId === 1 ? 'mainnet' : 'unichain';
  const addresses = CONTRACT_ADDRESSES[network as keyof typeof CONTRACT_ADDRESSES];
  
  console.log('Current network:', network, 'Chain ID:', chainId);
  console.log('Contract addresses:', addresses);
  
  // Read hooks for contracts
  const { data: totalWeight, isLoading: isLoadingTokensCount, error: totalWeightError } = useReadContract({
    address: addresses.multiLRTHook as `0x${string}`,
    abi: MultiLRTHookABI,
    functionName: 'totalTargetWeight',
  });
  
  const { data: basketTotalSupply, error: basketSupplyError } = useReadContract({
    address: addresses.multiLRTBasketToken as `0x${string}`,
    abi: MultiLRTBasketTokenABI,
    functionName: 'totalSupply',
  });
  
  const { data: basketDecimals } = useReadContract({
    address: addresses.multiLRTBasketToken as `0x${string}`,
    abi: MultiLRTBasketTokenABI,
    functionName: 'decimals',
  });
  
  const { data: basketPrice } = useReadContract({
    address: addresses.multiLRTBasketToken as `0x${string}`,
    abi: MultiLRTBasketTokenABI,
    functionName: 'getBasketPrice',
  });
  
  const { data: userBasketBalance } = useReadContract({
    address: addresses.multiLRTBasketToken as `0x${string}`,
    abi: MultiLRTBasketTokenABI,
    functionName: 'balanceOf',
    args: [address as `0x${string}`],
    enabled: !!address,
  });
  
  // Create contract read hooks for each token
  const stETHNameResult = useReadContract({
    address: addresses.stETH as `0x${string}`,
    abi: MockERC20ABI,
    functionName: 'name',
  });
  
  const stETHSymbolResult = useReadContract({
    address: addresses.stETH as `0x${string}`,
    abi: MockERC20ABI,
    functionName: 'symbol',
  });
  
  const stETHDecimalsResult = useReadContract({
    address: addresses.stETH as `0x${string}`,
    abi: MockERC20ABI,
    functionName: 'decimals',
  });
  
  const stETHBalanceResult = useReadContract({
    address: addresses.stETH as `0x${string}`,
    abi: MockERC20ABI,
    functionName: 'balanceOf',
    args: [address as `0x${string}`],
    enabled: !!address,
  });
  
  const stETHWeightResult = useReadContract({
    address: addresses.multiLRTHook as `0x${string}`,
    abi: MultiLRTHookABI,
    functionName: 'tokenTargetWeights',
    args: [addresses.stETH],
  });
  
  const stETHRateResult = useReadContract({
    address: addresses.multiLRTHook as `0x${string}`,
    abi: MultiLRTHookABI,
    functionName: 'lrtRates',
    args: [addresses.stETH],
  });
  
  // rETH Hooks
  const rETHNameResult = useReadContract({
    address: addresses.rETH as `0x${string}`,
    abi: MockERC20ABI,
    functionName: 'name',
  });
  
  const rETHSymbolResult = useReadContract({
    address: addresses.rETH as `0x${string}`,
    abi: MockERC20ABI,
    functionName: 'symbol',
  });
  
  const rETHDecimalsResult = useReadContract({
    address: addresses.rETH as `0x${string}`,
    abi: MockERC20ABI,
    functionName: 'decimals',
  });
  
  const rETHBalanceResult = useReadContract({
    address: addresses.rETH as `0x${string}`,
    abi: MockERC20ABI,
    functionName: 'balanceOf',
    args: [address as `0x${string}`],
    enabled: !!address,
  });
  
  const rETHWeightResult = useReadContract({
    address: addresses.multiLRTHook as `0x${string}`,
    abi: MultiLRTHookABI,
    functionName: 'tokenTargetWeights',
    args: [addresses.rETH],
  });
  
  const rETHRateResult = useReadContract({
    address: addresses.multiLRTHook as `0x${string}`,
    abi: MultiLRTHookABI,
    functionName: 'lrtRates',
    args: [addresses.rETH],
  });
  
  // cbETH Hooks
  const cbETHNameResult = useReadContract({
    address: addresses.cbETH as `0x${string}`,
    abi: MockERC20ABI,
    functionName: 'name',
  });
  
  const cbETHSymbolResult = useReadContract({
    address: addresses.cbETH as `0x${string}`,
    abi: MockERC20ABI,
    functionName: 'symbol',
  });
  
  const cbETHDecimalsResult = useReadContract({
    address: addresses.cbETH as `0x${string}`,
    abi: MockERC20ABI,
    functionName: 'decimals',
  });
  
  const cbETHBalanceResult = useReadContract({
    address: addresses.cbETH as `0x${string}`,
    abi: MockERC20ABI,
    functionName: 'balanceOf',
    args: [address as `0x${string}`],
    enabled: !!address,
  });
  
  const cbETHWeightResult = useReadContract({
    address: addresses.multiLRTHook as `0x${string}`,
    abi: MultiLRTHookABI,
    functionName: 'tokenTargetWeights',
    args: [addresses.cbETH],
  });
  
  const cbETHRateResult = useReadContract({
    address: addresses.multiLRTHook as `0x${string}`,
    abi: MultiLRTHookABI,
    functionName: 'lrtRates',
    args: [addresses.cbETH],
  });
  
  // Write hooks
  const { writeContractAsync: mintBasketToken } = useWriteContract();
  const { writeContractAsync: burnBasketToken } = useWriteContract();
  const { writeContractAsync: approveToken } = useWriteContract();
  
  // Track contract errors
  useEffect(() => {
    if (totalWeightError) {
      console.error('Error fetching total weight:', totalWeightError);
      setConnectionError('Failed to connect to MultiLRTHook contract. Please check your network connection.');
    } else if (basketSupplyError) {
      console.error('Error fetching basket supply:', basketSupplyError);
      setConnectionError('Failed to connect to MultiLRTBasketToken contract. Please check your network connection.');
    } else {
      setConnectionError(null);
    }
  }, [totalWeightError, basketSupplyError]);
  
  // Log contract data for debugging
  useEffect(() => {
    console.log('Total weight from contract:', totalWeight);
    console.log('stETH weight from contract:', stETHWeightResult.data);
    console.log('rETH weight from contract:', rETHWeightResult.data);
    console.log('cbETH weight from contract:', cbETHWeightResult.data);
  }, [totalWeight, stETHWeightResult.data, rETHWeightResult.data, cbETHWeightResult.data]);
  
  // Load token list and data from hooks
  useEffect(() => {
    if (isLoadingTokensCount) return;
    
    setIsLoading(true);
    
    try {
      const tokensData: Token[] = [];
      
      // Even if we don't have data from the contract, we can still show the tokens with default values
      // This ensures the UI always shows something meaningful while we debug contract connections
      
      // Add stETH
      tokensData.push({
        address: addresses.stETH,
        name: stETHNameResult.data as string || "Lido Staked ETH",
        symbol: stETHSymbolResult.data as string || "stETH",
        decimals: stETHDecimalsResult.data as number || 18,
        balance: stETHBalanceResult.data as bigint || BigInt(0),
        weight: Number(stETHWeightResult.data) || DEFAULT_TOKEN_WEIGHTS.stETH,
        rate: Number(stETHRateResult.data || 0),
      });
      
      // Add rETH
      tokensData.push({
        address: addresses.rETH,
        name: rETHNameResult.data as string || "Rocket Pool ETH",
        symbol: rETHSymbolResult.data as string || "rETH",
        decimals: rETHDecimalsResult.data as number || 18,
        balance: rETHBalanceResult.data as bigint || BigInt(0),
        weight: Number(rETHWeightResult.data) || DEFAULT_TOKEN_WEIGHTS.rETH,
        rate: Number(rETHRateResult.data || 0),
      });
      
      // Add cbETH
      tokensData.push({
        address: addresses.cbETH,
        name: cbETHNameResult.data as string || "Coinbase ETH",
        symbol: cbETHSymbolResult.data as string || "cbETH",
        decimals: cbETHDecimalsResult.data as number || 18,
        balance: cbETHBalanceResult.data as bigint || BigInt(0),
        weight: Number(cbETHWeightResult.data) || DEFAULT_TOKEN_WEIGHTS.cbETH,
        rate: Number(cbETHRateResult.data || 0),
      });
      
      console.log('Tokens data constructed:', tokensData);
      setTokens(tokensData);
    } catch (error) {
      console.error('Error loading tokens data:', error);
    } finally {
      setIsLoading(false);
    }
  }, [
    isLoadingTokensCount, addresses,
    stETHNameResult.data, stETHSymbolResult.data, stETHDecimalsResult.data, stETHBalanceResult.data, stETHWeightResult.data, stETHRateResult.data,
    rETHNameResult.data, rETHSymbolResult.data, rETHDecimalsResult.data, rETHBalanceResult.data, rETHWeightResult.data, rETHRateResult.data,
    cbETHNameResult.data, cbETHSymbolResult.data, cbETHDecimalsResult.data, cbETHBalanceResult.data, cbETHWeightResult.data, cbETHRateResult.data
  ]);
  
  // Update basket token balance when it changes
  useEffect(() => {
    if (userBasketBalance) {
      setBasketTokenBalance(userBasketBalance as bigint);
    }
  }, [userBasketBalance]);
  
  // Update basket price when it changes
  useEffect(() => {
    if (basketPrice) {
      setBasketTokenPrice(basketPrice as bigint);
    }
  }, [basketPrice]);
  
  // Function to mint basket tokens
  const mint = async (tokenAddress: string, amount: string) => {
    if (!address) throw new Error('Wallet not connected');
    
    const token = tokens.find(t => t.address === tokenAddress);
    if (!token) throw new Error('Token not found');
    
    // Convert amount to proper units
    const amountInWei = parseUnits(amount, token.decimals);
    
    // First approve the token
    const approvalTx = await approveToken({
      address: tokenAddress as `0x${string}`,
      abi: MockERC20ABI,
      functionName: 'approve',
      args: [addresses.multiLRTBasketToken as `0x${string}`, amountInWei],
    });
    
    // Then mint the basket token
    return mintBasketToken({
      address: addresses.multiLRTBasketToken as `0x${string}`,
      abi: MultiLRTBasketTokenABI,
      functionName: 'mint',
      args: [tokenAddress as `0x${string}`, amountInWei],
    });
  };
  
  // Function to burn basket tokens
  const burn = async (amount: string) => {
    if (!address) throw new Error('Wallet not connected');
    if (!basketDecimals) throw new Error('Basket decimals not loaded');
    
    // Convert amount to proper units
    const amountInWei = parseUnits(amount, basketDecimals as number);
    
    return burnBasketToken({
      address: addresses.multiLRTBasketToken as `0x${string}`,
      abi: MultiLRTBasketTokenABI,
      functionName: 'burn',
      args: [amountInWei],
    });
  };
  
  // Calculate percentages based on weights
  const getTokenPercentages = () => {
    const percentages: Record<string, number> = {};
    let weightSum = 0;
    
    tokens.forEach(token => {
      if (token.weight) {
        weightSum += token.weight;
      }
    });
    
    // If we have no weights from the contract, use the sum of our default weights
    if (weightSum === 0) {
      weightSum = WEIGHT_DENOMINATOR;
    }
    
    tokens.forEach(token => {
      if (token.weight) {
        percentages[token.address] = (token.weight / weightSum) * 100;
      }
    });
    
    return percentages;
  };
  
  // Calculate APY for the basket based on weighted average of tokens
  const calculateBasketAPY = (tokenAPYs: Record<string, number>) => {
    const percentages = getTokenPercentages();
    let totalAPY = 0;
    
    Object.keys(percentages).forEach(tokenAddress => {
      const apy = tokenAPYs[tokenAddress] || 0;
      const percentage = percentages[tokenAddress] / 100; // Convert to decimal
      totalAPY += apy * percentage;
    });
    
    return totalAPY;
  };
  
  return {
    tokens,
    isLoading,
    basketTokenBalance,
    basketTokenPrice,
    basketTotalSupply: basketTotalSupply as bigint,
    basketDecimals: basketDecimals as number,
    totalWeight: totalWeight as bigint || BigInt(WEIGHT_DENOMINATOR),
    mint,
    burn,
    getTokenPercentages,
    calculateBasketAPY,
    networkName: network,
    connectionError,
  };
} 