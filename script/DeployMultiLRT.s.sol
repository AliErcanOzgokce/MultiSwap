// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {MultiLRTHook} from "../src/hooks/MultiLRTHook.sol";
import {MultiLRTBasketToken} from "../src/MultiLRTBasketToken.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "../src/utils/HookMiner.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";

/**
 * @title DeployMultiLRT
 * @notice Deployment script for the Multi LRT Unified Liquidity Pool system
 * @dev Deploys a Sanctum Infinity-style unified liquidity layer for LRTs on Ethereum
 */
contract DeployMultiLRT is Script {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;
    
    // Deployment addresses
    PoolManager public poolManager;
    MultiLRTHook public hook;
    MultiLRTBasketToken public basketToken;
    
    // Mock tokens for testing
    MockERC20 public stETH;
    MockERC20 public rETH;
    MockERC20 public cbETH;
    
    // Constants
    uint256 constant INITIAL_RATE = 1e18; // 1:1 with ETH initially
    uint256 constant INITIAL_MINT = 1000 * 1e18; // 1000 tokens
    uint256 constant INITIAL_LIQUIDITY = 100 * 1e18; // 100 tokens
    uint256 constant DEFAULT_WEIGHT = 333000; // ~33.3% each for equal distribution, ensuring total doesn't exceed 1_000_000
    
    function setUp() public {}
    
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy Uniswap v4 PoolManager
        poolManager = new PoolManager(address(this));
        console2.log("PoolManager deployed at:", address(poolManager));
        
        // Deploy the hook with the correct address prefix
        uint160 flags = uint160(
            Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG
        );
        
        (address hookAddress, bytes32 salt) = HookMiner.find(
            address(this),
            flags,
            type(MultiLRTHook).creationCode,
            abi.encode(IPoolManager(address(poolManager)))
        );
        
        hook = new MultiLRTHook{salt: salt}(IPoolManager(address(poolManager)));
        require(address(hook) == hookAddress, "Hook deployment failed");
        console2.log("MultiLRTHook deployed at:", address(hook));
        
        // Deploy Mock LRT Tokens
        stETH = new MockERC20("Lido Staked ETH", "stETH", 18);
        rETH = new MockERC20("Rocket Pool ETH", "rETH", 18);
        cbETH = new MockERC20("Coinbase Staked ETH", "cbETH", 18);
        console2.log("stETH deployed at:", address(stETH));
        console2.log("rETH deployed at:", address(rETH));
        console2.log("cbETH deployed at:", address(cbETH));
        
        // Set initial rates in the hook
        hook.updateLRTRate(address(stETH), INITIAL_RATE);
        hook.updateLRTRate(address(rETH), INITIAL_RATE);
        hook.updateLRTRate(address(cbETH), INITIAL_RATE);
        
        // Add tokens to the supported list with equal weights initially
        console2.log("Adding tokens to supported list with equal weights...");
        hook.addSupportedToken(address(stETH), DEFAULT_WEIGHT);
        hook.addSupportedToken(address(rETH), DEFAULT_WEIGHT);
        hook.addSupportedToken(address(cbETH), DEFAULT_WEIGHT);
        
        // Mint some tokens for testing
        stETH.mint(msg.sender, INITIAL_MINT);
        rETH.mint(msg.sender, INITIAL_MINT);
        cbETH.mint(msg.sender, INITIAL_MINT);
        
        // Create pairs and initialize pools
        createAndInitializePool(Currency.wrap(address(stETH)), Currency.wrap(address(rETH)));
        createAndInitializePool(Currency.wrap(address(stETH)), Currency.wrap(address(cbETH)));
        createAndInitializePool(Currency.wrap(address(rETH)), Currency.wrap(address(cbETH)));
        
        // Deploy the basket token
        console2.log("Deploying MultiLRTBasketToken...");
        // Note: In production, you would deploy a real oracle here
        address oracle = address(0); // Placeholder for now
        basketToken = new MultiLRTBasketToken(
            "Multi LRT Basket Token",
            "mLRT",
            address(hook),
            oracle
        );
        console2.log("MultiLRTBasketToken deployed at:", address(basketToken));
        
        // Transfer hook ownership to the basket token
        // This allows the basket token to manage the liquidity pool
        console2.log("Transferring hook ownership to basket token...");
        hook.transferOwnership(address(basketToken));
        
        // Add tokens to the basket
        console2.log("Adding tokens to basket...");
        uint256 allocation = 333333333333333333; // ~33.33% each
        basketToken.addToken(address(stETH), allocation);
        basketToken.addToken(address(rETH), allocation);
        basketToken.addToken(address(cbETH), allocation);
        
        // Show final deployment summary
        console2.log("\n=== MultiSwap Deployment Complete ===");
        console2.log("MultiLRTHook:", address(hook));
        console2.log("MultiLRTBasketToken:", address(basketToken));
        console2.log("Supported Tokens:");
        console2.log("- stETH:", address(stETH));
        console2.log("- rETH:", address(rETH));
        console2.log("- cbETH:", address(cbETH));
        console2.log("==================================\n");
        
        vm.stopBroadcast();
    }
    
    /**
     * @notice Creates and initializes a Uniswap v4 pool for an LRT pair
     * @param currency0 The first token
     * @param currency1 The second token
     */
    function createAndInitializePool(Currency currency0, Currency currency1) internal {
        // Ensure tokens are in the correct order
        if (Currency.unwrap(currency0) > Currency.unwrap(currency1)) {
            (currency0, currency1) = (currency1, currency0);
        }
        
        // Create pool key
        PoolKey memory poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 3000, // 0.3% fee tier
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
        
        // Initialize the pool with 1:1 starting price (sqrt price = 2^96)
        poolManager.initialize(poolKey, uint160(1 << 96));
        
        console2.log("Pool initialized for pair:", Currency.unwrap(currency0), "-", Currency.unwrap(currency1));
    }
} 