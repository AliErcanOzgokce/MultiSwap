import { http, createConfig } from 'wagmi';
import { mainnet, sepolia } from 'wagmi/chains';
import { APP_SETTINGS } from './constants';
import { createWeb3Modal } from '@web3modal/wagmi';
import { walletConnect, injected, coinbaseWallet } from 'wagmi/connectors';

// Define Unichain Sepolia
const unichain = {
  id: 1301,
  name: 'Unichain Sepolia',
  nativeCurrency: { 
    name: 'Unichain ETH', 
    symbol: 'ETH', 
    decimals: 18 
  },
  rpcUrls: {
    default: { http: ['https://unichain-sepolia.drpc.org'] },
  },
  blockExplorers: {
    default: { name: 'Explorer', url: 'https://unichain-sepolia.blockscout.com/' }
  },
  testnet: true
};

// Project ID for WalletConnect
const projectId = process.env.NEXT_PUBLIC_PROJECT_ID || '979177ca4dab65de4f79eeff30c9eea9';

// Create wagmi config
export const config = createConfig({
  chains: [unichain, mainnet, sepolia],
  transports: {
    [unichain.id]: http(),
    [mainnet.id]: http(),
    [sepolia.id]: http(),
  },
  connectors: [
    walletConnect({ projectId }),
    injected(),
    coinbaseWallet({
      appName: 'MultiSwap',
    }),
  ],
});

// Create Web3Modal
if (typeof window !== 'undefined') {
  createWeb3Modal({
    wagmiConfig: config,
    projectId,
    enableAnalytics: false,
    themeMode: 'dark',
    themeVariables: {
      '--w3m-accent': '#2563EB', // Blue-600
      '--w3m-background-color': '#1F2937', // Gray-800
    },
  });
} 