'use client';

import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { WagmiProvider } from 'wagmi';
import { config } from '../lib/wagmiConfig';

// Create a client
const queryClient = new QueryClient();

type Web3ModalProps = {
  children: React.ReactNode;
  initialState?: any;
};

export function Web3Modal({ children, initialState }: Web3ModalProps) {
  return (
    <WagmiProvider config={config} initialState={initialState}>
      <QueryClientProvider client={queryClient}>
        {children}
      </QueryClientProvider>
    </WagmiProvider>
  );
} 