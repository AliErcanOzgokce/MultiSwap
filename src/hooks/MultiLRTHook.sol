// UPDATED: Added Core Functionality
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";

import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {Currency, CurrencyLibrary} from "v4-core/src/types/Currency.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary, toBeforeSwapDelta} from "v4-core/src/types/BeforeSwapDelta.sol";

/**
 * @title MultiLRTHook
 * @notice A Uniswap v4 hook that implements a multi-LRT (Liquid Restaking Token) pool
 * similar to Sanctum's approach on Solana. This hook enables:
 * 1. Direct swaps between different LRTs with minimal slippage
 * 2. Custom pricing curves for LRT-to-LRT swaps based on their underlying value
 * 3. Fee collection on swaps to provide yield to liquidity providers
 */
contract MultiLRTHook is BaseHook {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;
    using SafeERC20 for IERC20;

    /// @notice Fee denominator (1e6 = 100%)
    uint256 constant FEE_DENOMINATOR = 1_000_000;
    
    /// @notice Default swap fee (0.1%)
    uint256 constant DEFAULT_SWAP_FEE = 1000;

    /// @notice Mapping of LRT to its underlying ETH price (rate)
    mapping(Currency currency => uint256 rate) public lrtRates;
    
    /// @notice Custom fee rate per pool
    mapping(PoolId poolId => uint256 feeRate) public poolFeeRates;
    
    /// @notice Accumulated fees per token
    mapping(Currency currency => uint256 fees) public accumulatedFees;
    
    /// @notice LRT reserves held by this contract for the constant-sum curve
    mapping(Currency currency => uint256 reserves) public lrtReserves;
    
    /// @notice The address that can update LRT rates and withdraw fees
    address public owner;
    
    /// @notice Event emitted when an LRT rate is updated
    event RateUpdated(address indexed lrt, uint256 rate);
    
    /// @notice Event emitted when fees are collected
    event FeesCollected(address indexed token, uint256 amount);
    
    /// @notice Event emitted when a swap occurs
    event MultiLRTSwap(
        address indexed fromToken,
        address indexed toToken, 
        uint256 amountIn, 
        uint256 amountOut,
        uint256 fee
    );

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {
        owner = msg.sender;
    }

    /// @notice Returns the hooks' permission bitmap
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    /**
     * @notice Updates the rate for an LRT
     * @param lrt The LRT address
     * @param newRate The new rate (scaled by 1e18)
     */
    function updateLRTRate(address lrt, uint256 newRate) external {
        require(msg.sender == owner, "Only owner");
        lrtRates[Currency.wrap(lrt)] = newRate;
        emit RateUpdated(lrt, newRate);
    }
    
    /**
     * @notice Transfer ownership of the hook to a new address
     * @param newOwner The address of the new owner
     */
    function transferOwnership(address newOwner) external {
        require(msg.sender == owner, "Only owner");
        require(newOwner != address(0), "Invalid owner");
        owner = newOwner;
    }
    
    /**
     * @notice Sets the fee rate for a specific pool
     * @param key The pool key
     * @param newFeeRate The new fee rate (scaled by FEE_DENOMINATOR)
     */
    function setPoolFeeRate(PoolKey calldata key, uint256 newFeeRate) external {
        require(msg.sender == owner, "Only owner");
        require(newFeeRate <= FEE_DENOMINATOR, "Fee too high");
        poolFeeRates[key.toId()] = newFeeRate;
    }
    
    /**
     * @notice Adds liquidity for a specific LRT
     * @param lrt The LRT to add liquidity for
     * @param amount The amount of LRT to add
     */
    function addLiquidity(address lrt, uint256 amount) external {
        IERC20(lrt).safeTransferFrom(msg.sender, address(this), amount);
        lrtReserves[Currency.wrap(lrt)] += amount;
    }
    
    /**
     * @notice Removes liquidity for a specific LRT
     * @param lrt The LRT to remove liquidity for
     * @param amount The amount of LRT to remove
     */
    function removeLiquidity(address lrt, uint256 amount) external {
        require(msg.sender == owner, "Only owner");
        require(amount <= lrtReserves[Currency.wrap(lrt)], "Insufficient reserves");
        
        lrtReserves[Currency.wrap(lrt)] -= amount;
        IERC20(lrt).safeTransfer(msg.sender, amount);
    }
    
    /**
     * @notice Collects accumulated fees for a token
     * @param token The token to collect fees for
     */
    function collectFees(address token) external {
        require(msg.sender == owner, "Only owner");
        
        Currency currency = Currency.wrap(token);
        uint256 amount = accumulatedFees[currency];
        accumulatedFees[currency] = 0;
        
        IERC20(token).safeTransfer(msg.sender, amount);
        emit FeesCollected(token, amount);
    }

    /**
     * @notice Calculates the exchange amount between two LRTs based on their rates
     * @param fromToken The token to swap from
     * @param toToken The token to swap to
     * @param amountIn The input amount
     * @return amountOut The output amount (before fees)
     */
    function calculateExchangeAmount(
        address fromToken,
        address toToken,
        uint256 amountIn
    ) public view returns (uint256 amountOut) {
        uint256 fromRate = lrtRates[Currency.wrap(fromToken)];
        uint256 toRate = lrtRates[Currency.wrap(toToken)];
        
        require(fromRate > 0 && toRate > 0, "Invalid rates");
        
        // Calculate based on relative rates (similar to a constant-sum curve)
        amountOut = (amountIn * fromRate) / toRate;
    }
    
    /**
     * @notice Implementation of the beforeSwap hook
     * @dev This is where we implement our custom curve logic
     */
    function _beforeSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata
    ) internal override returns (bytes4, BeforeSwapDelta, uint24) {
        address tokenIn = params.zeroForOne 
            ? Currency.unwrap(key.currency0) 
            : Currency.unwrap(key.currency1);
        
        address tokenOut = params.zeroForOne 
            ? Currency.unwrap(key.currency1) 
            : Currency.unwrap(key.currency0);
        
        // Skip custom curve if either token has no rate (use native Uniswap curve)
        if (lrtRates[Currency.wrap(tokenIn)] == 0 || lrtRates[Currency.wrap(tokenOut)] == 0) {
            return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
        }
        
        // Calculate the input amount based on the params
        uint256 amountIn;
        if (params.amountSpecified > 0) {
            // Exact input swap
            amountIn = uint256(params.amountSpecified);
        } else {
            // For exact output swaps, we'd need to calculate the input amount
            // This is more complex, so for simplicity we don't override in this case
            return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
        }
        
        // Use our custom curve to calculate the output amount
        uint256 amountOut = calculateExchangeAmount(tokenIn, tokenOut, amountIn);
        
        // Ensure we have enough reserves
        require(amountOut <= lrtReserves[Currency.wrap(tokenOut)], "Insufficient reserves");
        
        // Calculate fee
        PoolId poolId = key.toId();
        uint256 feeRate = poolFeeRates[poolId] == 0 ? DEFAULT_SWAP_FEE : poolFeeRates[poolId];
        uint256 fee = (amountOut * feeRate) / FEE_DENOMINATOR;
        uint256 amountOutAfterFee = amountOut - fee;
        
        // Update reserves
        lrtReserves[Currency.wrap(tokenIn)] += amountIn;
        lrtReserves[Currency.wrap(tokenOut)] -= amountOut;
        
        // Accumulate fees
        accumulatedFees[Currency.wrap(tokenOut)] += fee;
        
        // Prepare delta values for the hook
        // The deltas represent the amount of tokens to add/remove from the pool
        int128 deltaIn = params.zeroForOne ? -int128(uint128(amountIn)) : int128(uint128(amountIn));
        int128 deltaOut = params.zeroForOne ? int128(uint128(amountOutAfterFee)) : -int128(uint128(amountOutAfterFee));
        
        BeforeSwapDelta delta = toBeforeSwapDelta(deltaIn, deltaOut);
        
        emit MultiLRTSwap(tokenIn, tokenOut, amountIn, amountOutAfterFee, fee);
        
        // Return the custom deltas
        return (BaseHook.beforeSwap.selector, delta, 0);
    }
    
    /**
     * @notice Implementation of the afterSwap hook
     */
    function _afterSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata,
        BalanceDelta,
        bytes calldata
    ) internal override returns (bytes4, int128) {
        return (BaseHook.afterSwap.selector, 0);
    }
} 