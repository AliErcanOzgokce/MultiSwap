import { formatUnits } from 'viem';

/**
 * Formats an address for display by truncating the middle
 * @param address Ethereum address to format
 * @param firstChars Number of characters to show at start
 * @param lastChars Number of characters to show at end
 * @returns Formatted address string
 */
export function formatAddress(address: string, firstChars = 6, lastChars = 4): string {
  if (!address) return '';
  
  const start = address.substring(0, firstChars);
  const end = address.substring(address.length - lastChars);
  return `${start}...${end}`;
}

/**
 * Formats a number for display with specified decimal places
 * @param value Number to format
 * @param decimals Decimal places to show
 * @param maxDecimals Maximum decimal places to show
 * @returns Formatted number string
 */
export function formatNumber(value: number, decimals = 2, maxDecimals = 6): string {
  if (value === 0) return '0';
  
  // For very small numbers, use maxDecimals
  if (value < 0.01) {
    return value.toFixed(maxDecimals);
  }
  
  return value.toFixed(decimals);
}

/**
 * Formats a bigint value to human-readable form with token symbol
 * @param value BigInt value to format
 * @param decimals Decimal places of the token
 * @param symbol Token symbol
 * @returns Formatted token amount string
 */
export function formatTokenAmount(amount: bigint, decimals: number, forInput = false): string {
  const formatted = formatUnits(amount, decimals);
  
  if (forInput) {
    return formatted;
  }
  
  // Format with commas for display
  const parts = formatted.split('.');
  const integerPart = parseInt(parts[0]).toLocaleString();
  const fractionalPart = parts[1] ? `.${parts[1].slice(0, 4)}` : '';
  
  return `${integerPart}${fractionalPart}`;
}

/**
 * Formats a percentage value
 * @param value Percentage value (0-100)
 * @param includeSign Whether to include % sign
 * @returns Formatted percentage string
 */
export function formatPercentage(value: number, total: number): string {
  if (!value || !total) return '0%';
  const percentage = (value / total) * 100;
  return `${percentage.toFixed(2)}%`;
}

/**
 * Formats a USD value with $ symbol
 * @param value USD value to format
 * @returns Formatted USD string
 */
export function formatUSD(amount: bigint): string {
  const amountInUsd = Number(formatUnits(amount, 18));
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(amountInUsd);
}

/**
 * Formats a unix timestamp to a readable date
 * @param timestamp Unix timestamp 
 * @returns Formatted date string
 */
export function formatDate(timestamp: number): string {
  const date = new Date(timestamp * 1000);
  return date.toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric'
  });
}

/**
 * Returns a color based on whether a number is positive or negative
 * @param value Number to check
 * @returns CSS color class
 */
export function getValueColor(value: number): string {
  if (value > 0) return 'text-green-500';
  if (value < 0) return 'text-red-500';
  return 'text-gray-500';
}

/**
 * Format APY for display
 * @param apy - The APY as a decimal (e.g., 0.05 for 5%)
 * @returns Formatted APY string
 */
export function formatAPY(apy: number): string {
  return `${(apy * 100).toFixed(2)}%`;
} 