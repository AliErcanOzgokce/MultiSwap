# MultiSwap: Unified Liquidity Layer for Liquid Restaking Tokens (LRTs)

<div align="center">
  <h1>🔄 MultiSwap</h1>
  <h3>A Uniswap v4 Hook for the Atrium Academy Uniswap V4 Hookathon</h3>
  <p><em>Bringing Sanctum Infinity's unified liquidity approach from Solana to Ethereum</em></p>
</div>

## 📌 Overview

MultiSwap creates a unified liquidity layer for all Liquid Restaking Tokens (LRTs) on Ethereum, enabling seamless swaps between them with minimal slippage, dynamic fees, and zero impermanent loss. The protocol is powered by a custom Uniswap v4 hook that implements a novel pricing mechanism optimized for similarly-valued assets.

## 🔍 Problem / Background

### The LRT Fragmentation Problem

The Ethereum LRT ecosystem faces significant liquidity fragmentation. With multiple LRT providers (Lido, Rocket Pool, Coinbase, etc.), users face:

- **Fragmented Liquidity**: Each LRT pair requires its own pool, diluting liquidity
- **Inefficient Capital Usage**: LPs need to provide liquidity across multiple pools
- **High Slippage**: Low liquidity in specific pairs leads to high slippage for traders
- **Impermanent Loss**: Traditional AMMs cause IL when pricing assets that track the same underlying value

Despite all LRTs representing the same underlying asset (staked ETH), the market treats them as completely different tokens, leading to liquidity inefficiency.

### Inspiration from Solana

Our solution is inspired by **Sanctum Infinity**, which has successfully implemented a unified liquidity layer for LSTs (Liquid Staking Tokens) on Solana. We're bringing this innovative approach to Ethereum's LRT ecosystem using Uniswap v4's hook architecture.

## 💡 Impact: Why MultiSwap Matters

MultiSwap represents a paradigm shift in how Ethereum handles LRT tokens:

### 1. Unified Liquidity Layer

Instead of requiring separate pools for each LRT pair (stETH/rETH, stETH/cbETH, rETH/cbETH, etc.), MultiSwap creates a single unified pool where all tokens share the same liquidity. This approach:

- **Increases Capital Efficiency**: 10x more efficient use of capital than traditional AMM approaches
- **Reduces Slippage**: Larger effective liquidity for all token pairs
- **Simplifies LP Experience**: LPs provide liquidity once instead of to multiple pools

### 2. Zero Impermanent Loss Design

Unlike traditional AMMs, MultiSwap uses a specialized constant-sum curve that recognizes LRTs as wrappers over the same underlying asset:

- **Fair Value Swaps**: Exchange rates based on actual underlying ETH value
- **Oracle Integration**: Rates updated via oracles to maintain accurate pricing
- **Protection for LPs**: No divergence loss when token prices change together

### 3. Dynamic Fee Mechanism

MultiSwap implements a novel fee structure that:

- **Encourages Balanced Pools**: Lower fees for swaps that rebalance the pool
- **Optimizes Capital Efficiency**: Fees guide pool toward target weights
- **Prevents Arbitrage Exploitation**: Dynamic fees that adjust to market conditions

### 4. Composable DeFi Building Block

As a Uniswap v4 hook, MultiSwap is:

- **Highly Composable**: Can be integrated with other DeFi protocols
- **Gas-Efficient**: Uses v4's singleton pool model for reduced gas costs
- **Extensible**: Framework for supporting future LRT tokens

## 🛠️ Technical Architecture

The protocol consists of three main components:

### MultiLRTHook.sol

The core hook implementation that integrates with Uniswap v4. Key features:

```solidity
function _beforeSwap(
    address,
    PoolKey calldata key,
    IPoolManager.SwapParams calldata params,
    bytes calldata
) internal override returns (bytes4, BeforeSwapDelta, uint24) {
    // Custom swap logic for LRT-to-LRT exchanges
    // Uses specialized constant-sum curve with dynamic fees
    // ...
}
```

- Implements custom swap logic with rebalancing fee adjustment
- Manages LRT rates and reserves
- Controls token weights and target allocations

### MultiLRTBasketToken.sol

An ERC20 token representing a basket of all LRTs in the pool:

```solidity
function getTotalBasketValue() public view returns (uint256 totalEthValue) {
    for (uint256 i = 0; i < lrtTokens.length; i++) {
        address token = lrtTokens[i];
        uint256 balance = IERC20(token).balanceOf(address(hook));
        (uint256 rate, ) = oracle.getLRTRate(token);
        totalEthValue += (balance * rate) / 1e18;
    }
}
```

- Tracks and manages the basket composition
- Allows users to mint and burn basket tokens
- Similar to Sanctum's Infinity token on Solana

### Dynamic Fee System

The protocol features a dynamic fee system that encourages pool rebalancing:

```solidity
function updateTokenFees(address token) public {
    // Calculate current pool composition and compare to target
    // Adjust fees to incentivize rebalancing
    // ...
}
```

- Automatically adjusts fees based on pool composition
- Higher fees for swaps that imbalance the pool
- Lower fees for swaps that restore target weights

## 🧪 Challenges: What Made This Hard

Building MultiSwap involved overcoming several technical and design challenges:

### 1. Uniswap v4 Integration Complexity

- **Hook Constraints**: Working within the constraints of the hook system while implementing custom swap logic
- **Delta Calculation**: Computing appropriate balanceDelta values to communicate with the pool manager
- **Gas Optimization**: Making the hook efficient enough for production use

### 2. Dynamic Fee Mechanism Design

- **Balanced Incentives**: Creating a fee system that encourages rebalancing without creating arbitrage opportunities
- **Mathematics**: Designing formulas that properly factor in pool weights, token rates, and desired allocations
- **Edge Cases**: Handling extreme market conditions without adverse effects

### 3. Oracle Reliability

- **Rate Accuracy**: Ensuring accurate rates for proper exchange calculations
- **Manipulation Resistance**: Designing the system to resist oracle manipulation
- **Failure Modes**: Creating fallback mechanisms for oracle failures

### 4. Capital Efficiency Trade-offs

- **Reserve Management**: Balancing liquidity needs across multiple token pairs
- **Slippage Control**: Minimizing slippage while maintaining efficient capital usage
- **Reserve Allocation**: Determining optimal token weightings

## 🚀 Getting Started

### Prerequisites

- [Forge](https://github.com/foundry-rs/foundry/tree/master/forge) (Foundry)
- [Node.js](https://nodejs.org/en/) (v16+)

### Installation

```bash
git clone https://github.com/AliErcanOzgokce/MultiSwap.git
cd MultiSwap
forge install
```

### Testing

```bash
forge test
```

### Deployment

1. Set your private key:

```bash
export PRIVATE_KEY=your_private_key
```

2. Run the deployment script:

```bash
forge script script/DeployMultiLRT.s.sol --rpc-url <your-rpc-url> --broadcast
```

## 🔄 Extension: Future Development

With additional funding and development time, MultiSwap could be extended in several ways:

### 1. Advanced Oracle System

- **Multi-Oracle Integration**: Aggregate rates from multiple providers for robustness
- **TWAPs**: Time-weighted average prices to smooth volatility
- **On-Chain Rate Validation**: Mathematical validation of rate consistency

### 2. Expanded Token Support

- **EigenLayer LRTs**: Support for upcoming LRTs from EigenLayer
- **Cross-Chain LSTs**: Integration with LSTs from other chains via bridges
- **Liquid Restaking Derivatives**: Support for more complex LRT derivatives

### 3. Governance and Tokenomics

- **DAO-Controlled Parameters**: Community governance of fees and weights
- **Fee Sharing**: Protocol fee distribution to stakeholders
- **Liquidity Mining**: Incentive programs for early LPs

### 4. Advanced Risk Management

- **Circuit Breakers**: Automatic protections against extreme market conditions
- **Rate Discrepancy Guards**: Detection and handling of oracle issues
- **Emergency Shutdown**: Controlled unwinding capability

### 5. Integration with LRT Providers

- **Direct Staking/Unstaking**: Seamless conversion between ETH and LRTs
- **Validator Diversity Management**: Helping promote decentralization by balancing across providers
- **Custom LRT Provider Hooks**: Specific optimizations for each LRT protocol

## 📊 Current Status

- [x] Core protocol design and implementation
- [x] Dynamic fee mechanism for pool rebalancing
- [x] Integration with Uniswap v4 hook system
- [x] Basket token implementation
- [x] Comprehensive test suite
- [ ] Mainnet deployment
- [ ] Frontend UI implementation
- [ ] Advanced oracle integration

## 📜 License

This project is licensed under MIT.

## 🙏 Acknowledgements

- Uniswap Labs for the v4 architecture and hook system
- Atrium Academy for the Uniswap V4 Hookathon opportunity
- Sanctum Finance for inspiration from their Solana LST implementation
