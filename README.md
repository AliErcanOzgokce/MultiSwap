# MultiSwap LRT Pool for Uniswap v4

This project implements a custom Uniswap v4 hook that enables efficient swaps between various Liquid Restaking Tokens (LRTs) like stETH, rETH, and cbETH. The implementation is inspired by Sanctum's approach on Solana.

## Key Features

- **Direct LRT-to-LRT Swaps**: Swap directly between different LRTs with minimal slippage
- **Underlying-Aware Pricing**: Custom pricing based on the underlying ETH value of each LRT
- **Constant-Sum Curve**: Utilizes a constant-sum AMM model optimized for tokens with similar values
- **Custom Fee Structure**: Configurable fee rates per pool

## Project Structure

- `src/hooks/MultiLRTHook.sol`: Main hook implementation that manages cross-LRT swaps
- `src/utils/HookMiner.sol`: Utility for computing valid hook addresses with specific flags
- `test/`: Test files for the contracts
- `script/DeployMultiLRT.s.sol`: Deployment script

## How It Works

1. **LRT Rate Management**: Each LRT has an exchange rate to ETH that is updated periodically
2. **Constant-Sum Swaps**: Swaps price tokens based on their underlying ETH value
3. **Reserve Management**: The hook maintains reserves of each LRT to facilitate swaps
4. **Fee Collection**: Charges small fees on swaps that can be collected by the owner

## Uniswap v4 Integration

This project is built on Uniswap v4 and uses the hook system to customize the swap behavior. The hooks intercept swap calls and apply custom logic for LRT-to-LRT swaps.

## Testing

The project includes a comprehensive test suite. To run the tests:

```bash
forge test
```

## Deployment

1. Set the private key in your environment:

```bash
export PRIVATE_KEY=your_private_key
```

2. Run the deployment script:

```bash
forge script script/DeployMultiLRT.s.sol --rpc-url <your-rpc-url> --broadcast
```

## Development

This project is built with [Foundry](https://book.getfoundry.sh/). To set up your local environment:

```bash
git clone https://github.com/AliErcanOzgokce/MultiSwap.git
cd MultiSwap
forge install
```

## License

This project is licensed under MIT.
