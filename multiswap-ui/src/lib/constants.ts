// Contract addresses - updated based on Unichain Sepolia deployment
export const CONTRACT_ADDRESSES = {
  // Mainnet addresses
  mainnet: {
    multiLRTHook: '0x0000000000000000000000000000000000000000', // Placeholder
    multiLRTBasketToken: '0x0000000000000000000000000000000000000000', // Placeholder
    lrtOracle: '0x0000000000000000000000000000000000000000', // Placeholder
    poolManager: '0x0000000000000000000000000000000000000000', // Placeholder
    // Known LRT token addresses
    stETH: '0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84',
    rETH: '0xae78736Cd615f374D3085123A210448E74Fc6393',
    cbETH: '0xBe9895146f7AF43049ca1c1AE358B0541Ea49704',
  },
  // Unichain Sepolia testnet addresses - from our deployment
  unichain: {
    poolManager: '0xC135e8b68984117f3f92173d330aA328Dd427978',
    multiLRTHook: '0x9C2e0fD4E224227F1cb8410e4301D7f68B437d8B',
    lrtOracle: '0xE30f84EA86e1DFD105cAc0A4b3ff2cF81535D4D6',
    multiLRTBasketToken: '0x39527F8eaf223bcf8c5cfE1176912CD3d0a6108f',
    // Deployed mock tokens
    stETH: '0x79d6520b4dD72e87adD669E777cD209B0C7BDA68',
    rETH: '0xae86B32A55175507Bb9C327AfAbB8FB917D20e92',
    cbETH: '0xA8d4618EFF5e3709d01d794F37C746DB352885d8',
  }
};

// Default weights for tokens in the basket
export const DEFAULT_TOKEN_WEIGHTS = {
  stETH: 400000, // 40%
  rETH: 400000,  // 40%
  cbETH: 200000,  // 20%
};

// The denominator used for percentage calculations (1,000,000 = 100%)
export const WEIGHT_DENOMINATOR = 1000000;

// Block explorers
export const BLOCK_EXPLORERS = {
  mainnet: 'https://etherscan.io',
  sepolia: 'https://sepolia.etherscan.io',
  unichain: 'https://explorer.unichain.network', // Unichain explorer
};

// Application settings
export const APP_SETTINGS = {
  defaultChainId: 1301, // Unichain Sepolia
  pollInterval: 15000, // 15 seconds
  oracleUpdateInterval: 30000, // 30 seconds
};

// Token metadata for UI display
export const TOKEN_METADATA = {
  stETH: {
    name: 'Lido Staked ETH',
    symbol: 'stETH',
    icon: '/tokens/steth.svg',
    protocol: 'Lido',
    description: 'Lido liquid staking token, backed 1:1 with ETH deposits',
  },
  rETH: {
    name: 'Rocket Pool ETH',
    symbol: 'rETH',
    icon: '/tokens/reth.svg',
    protocol: 'Rocket Pool',
    description: 'Rocket Pool liquid staking token with a floating exchange rate',
  },
  cbETH: {
    name: 'Coinbase Staked ETH',
    symbol: 'cbETH',
    icon: '/tokens/cbeth.svg',
    protocol: 'Coinbase',
    description: 'Coinbase liquid staking token, wrapped staked ETH',
  },
  mlrt: {
    name: 'Multi-LRT Basket',
    symbol: 'MLRT',
    icon: '/tokens/mlrt.svg',
    protocol: 'MultiSwap',
    description: 'Diversified basket of Ethereum liquid restaking tokens',
  }
}; 