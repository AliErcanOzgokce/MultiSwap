// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";

/**
 * @title UniswapV4Router
 * @notice A simple mock router for testing Uniswap v4 hooks
 */
contract UniswapV4Router {
    using SafeERC20 for IERC20;

    IPoolManager public immutable poolManager;
    PoolSwapTest public immutable swapRouter;

    constructor(IPoolManager _poolManager) {
        poolManager = _poolManager;
        swapRouter = new PoolSwapTest(_poolManager);
    }

    /**
     * @notice Executes a swap through the Uniswap v4 pool
     * @param key The pool key
     * @param params The swap parameters
     * @param hookData Any additional data to pass to hooks
     * @return amountOut The amount of output tokens received
     */
    function swap(
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata hookData
    ) external returns (int256 amountOut) {
        // Get input token
        Currency inputCurrency = params.zeroForOne ? key.currency0 : key.currency1;
        uint256 inputAmount = params.amountSpecified > 0 ? uint256(params.amountSpecified) : 0;
        
        // Transfer tokens from the caller to this contract
        if (inputAmount > 0) {
            IERC20(Currency.unwrap(inputCurrency)).safeTransferFrom(msg.sender, address(this), inputAmount);
            IERC20(Currency.unwrap(inputCurrency)).approve(address(swapRouter), inputAmount);
        }
        
        // Execute the swap through the swap router
        amountOut = int256(BalanceDelta.unwrap(swapRouter.swap(
            key,
            params,
            PoolSwapTest.TestSettings({
                takeClaims: true,
                settleUsingBurn: false
            }),
            hookData
        )));
        
        // Transfer output tokens back to the caller
        Currency outputCurrency = params.zeroForOne ? key.currency1 : key.currency0;
        if (amountOut < 0) {
            IERC20(Currency.unwrap(outputCurrency)).safeTransfer(msg.sender, uint256(-amountOut));
        }
        
        return amountOut;
    }
} 