// UPDATED: Added Core Functionality
// UPDATED: Added Uniswap v4 hook integration
// UPDATED: Added transferOwnership function
// UPDATED: Added dynamic fee structure for pool rebalancing
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
 * 4. Dynamic fee structure to encourage pool rebalancing
 * 5. Unified liquidity layer for all LRTs (similar to Sanctum Infinity)
 */
contract MultiLRTHook is BaseHook {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;
    using SafeERC20 for IERC20;

    /// @notice Fee denominator (1e6 = 100%)
    uint256 constant FEE_DENOMINATOR = 1_000_000;
    
    /// @notice Default swap fee (0.1%)
    uint256 constant DEFAULT_SWAP_FEE = 1000;

    /// @notice Maximum fee that can be set (2%)
    uint256 constant MAX_FEE = 20000;
    
    /// @notice Target weight denominator (1e6 = 100%)
    uint256 constant WEIGHT_DENOMINATOR = 1_000_000;

    /// @notice Mapping of LRT to its underlying ETH price (rate)
    mapping(Currency currency => uint256 rate) public lrtRates;
    
    /// @notice Custom fee rate per pool
    mapping(PoolId poolId => uint256 feeRate) public poolFeeRates;
    
    /// @notice Accumulated fees per token
    mapping(Currency currency => uint256 fees) public accumulatedFees;
    
    /// @notice LRT reserves held by this contract for the constant-sum curve
    mapping(Currency currency => uint256 reserves) public lrtReserves;
    
    /// @notice Input fee per token (fee applied when token is sold)
    mapping(Currency currency => uint256 inputFee) public tokenInputFees;
    
    /// @notice Output fee per token (fee applied when token is bought)
    mapping(Currency currency => uint256 outputFee) public tokenOutputFees;
    
    /// @notice Target weight for each token in the pool
    mapping(Currency currency => uint256 targetWeight) public tokenTargetWeights;
    
    /// @notice List of all supported tokens
    Currency[] public supportedTokens;
    
    /// @notice Total target weight of all tokens (should sum to WEIGHT_DENOMINATOR)
    uint256 public totalTargetWeight;
    
    /// @notice The address that can update LRT rates and withdraw fees
    address public owner;

    /// @notice Event emitted when a token is added to the supported list
    event TokenAdded(address indexed token, uint256 targetWeight);
    
    /// @notice Event emitted when target weights are updated
    event TargetWeightUpdated(address indexed token, uint256 weight);
    
    /// @notice Event emitted when fees are updated
    event TokenFeesUpdated(address indexed token, uint256 inputFee, uint256 outputFee);
    
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
        uint256 inputFee,
        uint256 outputFee
    );
    
    /// @notice Event emitted when a pool is rebalanced
    event PoolRebalanced(address indexed token, uint256 currentWeight, uint256 targetWeight);

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
     * @notice Add a new token to the supported tokens list
     * @param token The token address
     * @param weight The target weight of the token (scaled by WEIGHT_DENOMINATOR)
     */
    function addSupportedToken(address token, uint256 weight) external {
        require(msg.sender == owner, "Only owner");
        require(weight > 0, "Weight must be positive");
        require(tokenTargetWeights[Currency.wrap(token)] == 0, "Token already supported");
        
        Currency currency = Currency.wrap(token);
        supportedTokens.push(currency);
        tokenTargetWeights[currency] = weight;
        totalTargetWeight += weight;
        
        require(totalTargetWeight <= WEIGHT_DENOMINATOR, "Total weight exceeds denominator");
        
        // Set default fees
        tokenInputFees[currency] = DEFAULT_SWAP_FEE;
        tokenOutputFees[currency] = DEFAULT_SWAP_FEE;
        
        emit TokenAdded(token, weight);
    }

    /**
     * @notice Updates the target weight for a token
     * @param token The token address
     * @param newWeight The new target weight
     */
    function updateTargetWeight(address token, uint256 newWeight) external {
        require(msg.sender == owner, "Only owner");
        require(newWeight > 0, "Weight must be positive");
        
        Currency currency = Currency.wrap(token);
        require(tokenTargetWeights[currency] > 0, "Token not supported");
        
        // Update total weight
        totalTargetWeight = totalTargetWeight - tokenTargetWeights[currency] + newWeight;
        require(totalTargetWeight <= WEIGHT_DENOMINATOR, "Total weight exceeds denominator");
        
        tokenTargetWeights[currency] = newWeight;
        
        emit TargetWeightUpdated(token, newWeight);
        
        // Automatically update fees based on new weights
        updateTokenFees(token);
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
     * @notice Manually sets input and output fees for a token
     * @param token The token address
     * @param newInputFee The new input fee
     * @param newOutputFee The new output fee
     */
    function setTokenFees(address token, uint256 newInputFee, uint256 newOutputFee) external {
        require(msg.sender == owner, "Only owner");
        require(newInputFee <= MAX_FEE && newOutputFee <= MAX_FEE, "Fee too high");
        
        Currency currency = Currency.wrap(token);
        tokenInputFees[currency] = newInputFee;
        tokenOutputFees[currency] = newOutputFee;
        
        emit TokenFeesUpdated(token, newInputFee, newOutputFee);
    }
    
    /**
     * @notice Automatically update fees based on current reserves vs. target weights
     * @param token The token to update fees for
     */
    function updateTokenFees(address token) public {
        require(msg.sender == owner, "Only owner");
        
        Currency currency = Currency.wrap(token);
        require(tokenTargetWeights[currency] > 0, "Token not supported");
        
        // Calculate the current token value in ETH (with proper scaling)
        uint256 tokenValue = (lrtReserves[currency] * lrtRates[currency]) / 1e18;
        
        // Get total pool value in ETH
        uint256 totalPoolValue = getTotalPoolValue();
        
        if (totalPoolValue == 0) {
            // If pool is empty, set default fees
            tokenInputFees[currency] = DEFAULT_SWAP_FEE;
            tokenOutputFees[currency] = DEFAULT_SWAP_FEE;
            return;
        }
        
        // Calculate current weight
        uint256 currentWeight = (tokenValue * WEIGHT_DENOMINATOR) / totalPoolValue;
        
        // Get target weight
        uint256 targetWeight = tokenTargetWeights[currency];
        
        // Determine the deviation from target
        uint256 deviation;
        bool isOverweight;
        
        if (currentWeight > targetWeight) {
            deviation = currentWeight - targetWeight;
            isOverweight = true;
        } else {
            deviation = targetWeight - currentWeight;
            isOverweight = false;
        }
        
        // Normalize deviation to determine fee adjustment (max 10x the default fee)
        // Prevent overflow by safely calculating the deviation percentage
        uint256 deviationPercent = targetWeight > 0 ? (deviation * 100) / targetWeight : 0;
        uint256 feeAdjustment = (deviationPercent * DEFAULT_SWAP_FEE) / 100;
        feeAdjustment = feeAdjustment > MAX_FEE ? MAX_FEE : feeAdjustment;
        
        if (isOverweight) {
            // Token is overweight in the pool
            // Lower input fee (encourage more inflow)
            // Raise output fee (discourage outflow)
            tokenInputFees[currency] = DEFAULT_SWAP_FEE > feeAdjustment ? DEFAULT_SWAP_FEE - feeAdjustment : 0;
            tokenOutputFees[currency] = DEFAULT_SWAP_FEE + feeAdjustment;
        } else {
            // Token is underweight in the pool
            // Raise input fee (discourage more outflow)
            // Lower output fee (encourage inflow)
            tokenInputFees[currency] = DEFAULT_SWAP_FEE + feeAdjustment;
            tokenOutputFees[currency] = DEFAULT_SWAP_FEE > feeAdjustment ? DEFAULT_SWAP_FEE - feeAdjustment : 0;
        }
        
        // Ensure fees don't exceed maximum
        tokenInputFees[currency] = tokenInputFees[currency] > MAX_FEE ? MAX_FEE : tokenInputFees[currency];
        tokenOutputFees[currency] = tokenOutputFees[currency] > MAX_FEE ? MAX_FEE : tokenOutputFees[currency];
        
        emit TokenFeesUpdated(token, tokenInputFees[currency], tokenOutputFees[currency]);
        emit PoolRebalanced(token, currentWeight, targetWeight);
    }
    
    /**
     * @notice Update fees for all tokens in one transaction
     */
    function updateAllTokenFees() external {
        require(msg.sender == owner, "Only owner");
        
        for (uint i = 0; i < supportedTokens.length; i++) {
            Currency currency = supportedTokens[i];
            updateTokenFees(Currency.unwrap(currency));
        }
    }
    
    /**
     * @notice Calculate the total pool value in ETH terms
     * @return totalValue The total value of all tokens in the pool in ETH terms
     */
    function getTotalPoolValue() public view returns (uint256 totalValue) {
        for (uint i = 0; i < supportedTokens.length; i++) {
            Currency currency = supportedTokens[i];
            totalValue += (lrtReserves[currency] * lrtRates[currency]) / 1e18;
        }
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
     * @notice Calculate the total fee for a swap
     * @param fromToken The token being sold
     * @param toToken The token being bought
     * @param amountOut The output amount (before fees)
     * @return fee The total fee amount in output token
     */
    function calculateSwapFee(
        address fromToken,
        address toToken,
        uint256 /* amountIn */,
        uint256 amountOut
    ) public view returns (uint256 fee) {
        Currency fromCurrency = Currency.wrap(fromToken);
        Currency toCurrency = Currency.wrap(toToken);
        
        // Get input and output fees
        uint256 inFee = tokenInputFees[fromCurrency];
        uint256 outFee = tokenOutputFees[toCurrency];
        
        // Calculate fees (as a portion of the output amount)
        uint256 inFeePortion = (amountOut * inFee) / FEE_DENOMINATOR;
        uint256 outFeePortion = (amountOut * outFee) / FEE_DENOMINATOR;
        
        // Total fee is the sum of both fees
        fee = inFeePortion + outFeePortion;
    }
    
    /**
     * @notice Implementation of the beforeSwap hook
     * @dev This is where we implement our custom curve logic with dynamic fees
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
        
        // Get the input and output fees
        Currency inCurrency = Currency.wrap(tokenIn);
        Currency outCurrency = Currency.wrap(tokenOut);
        uint256 inFee = tokenInputFees[inCurrency];
        uint256 outFee = tokenOutputFees[outCurrency];
        
        // Calculate fee
        uint256 fee = calculateSwapFee(tokenIn, tokenOut, amountIn, amountOut);
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
        
        emit MultiLRTSwap(tokenIn, tokenOut, amountIn, amountOutAfterFee, inFee, outFee);
        
        // Return the custom deltas
        return (BaseHook.beforeSwap.selector, delta, 0);
    }
    
    /**
     * @notice Implementation of the afterSwap hook
     */
    function _afterSwap(
        address,
        PoolKey calldata /* key */,
        IPoolManager.SwapParams calldata /* params */,
        BalanceDelta /* delta */,
        bytes calldata /* hookData */
    ) internal pure override returns (bytes4, int128) {
        return (BaseHook.afterSwap.selector, 0);
    }
} 