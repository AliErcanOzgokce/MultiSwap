# MultiSwap: Unified Liquid Restaking Protocol for Ethereum

MultiSwap is a Uniswap v4 hook implementation inspired by Sanctum Infinity on Solana, creating a unified liquidity layer for Ethereum Liquid Restaking Tokens (LRTs). It enables efficient swaps between different LRTs with minimal slippage and innovative dynamic fee structures to maintain balanced pools.

## Key Features

- **Unified Liquidity Layer**: Creates a single unified pool for all LRTs, similar to Sanctum Infinity on Solana
- **Dynamic Fee Mechanism**: Automatically adjusts input/output fees to maintain target token allocations
- **Underlying-Aware Pricing**: Prices swaps based on the underlying ETH value of each LRT token
- **Zero Impermanent Loss Design**: Trade LRTs at their fair value without impermanent loss
- **Multi-Asset LP Token**: Will support a basket token representing all LRTs in the pool
- **Portfolio Rebalancing**: Fee structure encourages swaps that rebalance the pool towards target weights

## Conceptual Background

This implementation recognizes that "LSTs are fungible" - they are wrappers over the same underlying staked ETH. By creating a unified liquidity layer, we bring the benefits of Sanctum's approach on Solana to Ethereum:

- Before: Fragmented liquidity where each LRT pair requires its own pool
- After: A unified liquidity layer connecting all LRTs through a single reserve

## Project Structure

- `src/hooks/MultiLRTHook.sol`: Main hook implementation for multi-LRT swaps with dynamic fees
- `src/MultiLRTBasketToken.sol`: ERC20 token representing the basket of all supported LRTs
- `src/MultiLRTFactory.sol`: Factory contract for deploying the MultiLRTHook
- `src/utils/HookMiner.sol`: Utility for computing valid hook addresses
- `test/MultiLRTTest.t.sol`: Comprehensive test suite for the system

## How It Works

1. **Token Weight Management**: Each LRT has a target weight in the pool (e.g., 33% each for stETH, rETH, cbETH)
2. **Dynamic Fee Allocation**:
   - When a token is overweight: Lower input fee, higher output fee
   - When a token is underweight: Higher input fee, lower output fee
   - This incentivizes swaps that rebalance the pool towards target weights
3. **Fair Value Swaps**: Exchange rates are based on the underlying ETH value of each token
4. **Unified Reserve**: All LRTs share a single reserve, maximizing capital efficiency

## Fee Structure Example

For example, if the pool has excess rETH (overweight) and insufficient stETH (underweight):

- rETH → stETH swap: Low fees (encourages this direction)
- stETH → rETH swap: High fees (discourages this direction)

This mechanism naturally rebalances the pool through normal trading activity.

## Uniswap v4 Integration

This project leverages Uniswap v4's hook system to implement custom swap logic:

- Uses `beforeSwap` hook to apply customized pricing and fee logic
- Implements a constant-sum curve optimized for similarly-valued tokens
- Maintains separate reserves outside of Uniswap pools for efficient token exchange

## Testing

```bash
forge test
```

## Deployment

1. Set your private key:

```bash
export PRIVATE_KEY=your_private_key
```

2. Run the deployment script:

```bash
forge script script/DeployMultiLRT.s.sol --rpc-url <your-rpc-url> --broadcast
```

## Development Setup

```bash
git clone https://github.com/AliErcanOzgokce/MultiSwap.git
cd MultiSwap
forge install
```

## License

This project is licensed under MIT.
