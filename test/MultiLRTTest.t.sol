// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {MultiLRTHook} from "../src/hooks/MultiLRTHook.sol";
import {MultiLRTFactory} from "../src/MultiLRTFactory.sol";
import {MockLRTToken} from "../src/test/MockLRTToken.sol";
import {MockLRTOracle} from "../src/test/MockLRTOracle.sol";
import {MultiLRTBasketToken} from "../src/MultiLRTBasketToken.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {HookMiner} from "../src/utils/HookMiner.sol";
import {UniswapV4Router} from "../src/test/UniswapV4Router.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";

// Mock interface for transferOwnership
interface MockTransferOwnable {
    function transferOwnership(address newOwner) external;
}

contract MultiLRTTest is Test {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;

    // Test contracts
    PoolManager public poolManager;
    MultiLRTFactory public factory;
    MultiLRTHook public hook;
    MockLRTOracle public oracle;
    MultiLRTBasketToken public basketToken;
    UniswapV4Router public router;
    
    // Mock tokens
    MockLRTToken public stETH;
    MockLRTToken public rETH;
    MockLRTToken public cbETH;
    
    // Addresses for testing
    address public user1;
    address public user2;
    address public owner;
    
    // Pool keys
    PoolKey public poolKey_stETH_rETH;
    PoolKey public poolKey_stETH_cbETH;
    PoolKey public poolKey_rETH_cbETH;
    
    // Constants
    uint256 constant INITIAL_RATE = 1e18; // 1:1 with ETH initially
    uint256 constant INITIAL_MINT = 1000 * 1e18; // 1000 tokens
    uint256 constant INITIAL_LIQUIDITY = 100 * 1e18; // 100 tokens
    
    function setUp() public {
        // Set up addresses
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        // Fund test accounts
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        
        // Deploy the pool manager
        poolManager = new PoolManager(address(this));
        
        // Deploy the oracle
        oracle = new MockLRTOracle();
        
        // Deploy the hook factory
        factory = new MultiLRTFactory();
        
        // Set the flags for the hook
        uint160 flags = uint160(
            Hooks.BEFORE_SWAP_FLAG | 
            Hooks.AFTER_SWAP_FLAG
        );
        
        // Mine hook address with correct flags
        (address hookAddress, bytes32 salt) = HookMiner.find(
            address(this),
            flags,
            type(MultiLRTHook).creationCode,
            abi.encode(IPoolManager(address(poolManager)))
        );
        
        // Deploy the hook with the computed salt
        hook = new MultiLRTHook{salt: salt}(IPoolManager(address(poolManager)));
        require(address(hook) == hookAddress, "Hook deployment failed");
        
        // Verify that the test contract is the owner of the hook
        assertEq(hook.owner(), address(this), "Test contract should be the owner of the hook");
        
        // Deploy the router
        router = new UniswapV4Router(IPoolManager(address(poolManager)));
        
        // Deploy the mock tokens
        stETH = new MockLRTToken("Lido Staked ETH", "stETH", INITIAL_RATE);
        rETH = new MockLRTToken("Rocket Pool ETH", "rETH", INITIAL_RATE);
        cbETH = new MockLRTToken("Coinbase Staked ETH", "cbETH", INITIAL_RATE);
        
        // Set initial rates in the oracle
        oracle.setRate(address(stETH), INITIAL_RATE);
        oracle.setRate(address(rETH), INITIAL_RATE);
        oracle.setRate(address(cbETH), INITIAL_RATE);
        
        // Update rates in the hook
        hook.updateLRTRate(address(stETH), INITIAL_RATE);
        hook.updateLRTRate(address(rETH), INITIAL_RATE);
        hook.updateLRTRate(address(cbETH), INITIAL_RATE);
        
        // Mint tokens for testing
        stETH.mint(owner, INITIAL_MINT);
        rETH.mint(owner, INITIAL_MINT);
        cbETH.mint(owner, INITIAL_MINT);
        
        stETH.mint(user1, INITIAL_MINT);
        rETH.mint(user1, INITIAL_MINT);
        cbETH.mint(user1, INITIAL_MINT);
        
        // Create and initialize the pools
        createPool(Currency.wrap(address(stETH)), Currency.wrap(address(rETH)));
        createPool(Currency.wrap(address(stETH)), Currency.wrap(address(cbETH)));
        createPool(Currency.wrap(address(rETH)), Currency.wrap(address(cbETH)));
        
        // Add liquidity to the hook
        stETH.approve(address(hook), INITIAL_LIQUIDITY);
        rETH.approve(address(hook), INITIAL_LIQUIDITY);
        cbETH.approve(address(hook), INITIAL_LIQUIDITY);
        
        hook.addLiquidity(address(stETH), INITIAL_LIQUIDITY);
        hook.addLiquidity(address(rETH), INITIAL_LIQUIDITY);
        hook.addLiquidity(address(cbETH), INITIAL_LIQUIDITY);
        
        // Deploy the basket token
        basketToken = new MultiLRTBasketToken(
            "Multi LRT Basket Token",
            "mLRT",
            address(hook),
            address(oracle)
        );
        
        // Transfer ownership of the hook to the basket token
        // This allows the basket token to call privileged functions on the hook
        transferHookOwnership(address(basketToken));
        
        // Add tokens to the basket
        uint256 allocation = 333333333333333333; // ~33.33% each
        basketToken.addToken(address(stETH), allocation);
        basketToken.addToken(address(rETH), allocation);
        basketToken.addToken(address(cbETH), allocation);
    }
    
    // Helper function to transfer hook ownership
    function transferHookOwnership(address newOwner) internal {
        // This function would be implemented in the hook contract
        // For testing purposes, we can simulate it if the hook doesn't have this method
        // First check if the hook has a transferOwnership method
        try MockTransferOwnable(address(hook)).transferOwnership(newOwner) {
            // Successful transfer
        } catch {
            // If transferOwnership doesn't exist, we might need to use a different approach
            // For example, updating the tests to mock the owner check
            console2.log("Warning: Hook doesn't have transferOwnership method");
        }
    }
    
    function createPool(Currency currency0, Currency currency1) internal {
        // Ensure tokens are in the correct order
        if (Currency.unwrap(currency0) > Currency.unwrap(currency1)) {
            (currency0, currency1) = (currency1, currency0);
        }
        
        // Create pool key
        PoolKey memory poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 3000,
            tickSpacing: 60,
            hooks: hook
        });
        
        // Store the pool key for later use
        if (
            (Currency.unwrap(currency0) == address(stETH) && Currency.unwrap(currency1) == address(rETH)) ||
            (Currency.unwrap(currency0) == address(rETH) && Currency.unwrap(currency1) == address(stETH))
        ) {
            poolKey_stETH_rETH = poolKey;
        } else if (
            (Currency.unwrap(currency0) == address(stETH) && Currency.unwrap(currency1) == address(cbETH)) ||
            (Currency.unwrap(currency0) == address(cbETH) && Currency.unwrap(currency1) == address(stETH))
        ) {
            poolKey_stETH_cbETH = poolKey;
        } else if (
            (Currency.unwrap(currency0) == address(rETH) && Currency.unwrap(currency1) == address(cbETH)) ||
            (Currency.unwrap(currency0) == address(cbETH) && Currency.unwrap(currency1) == address(rETH))
        ) {
            poolKey_rETH_cbETH = poolKey;
        }
        
        // Initialize the pool at price = 1.0
        poolManager.initialize(poolKey, uint160(TickMath.getSqrtPriceAtTick(0)));
    }
    
    function test_HookDeployment() public {
        assertTrue(address(hook) != address(0), "Hook not deployed");
        assertEq(hook.owner(), address(basketToken), "Hook owner incorrect");
    }
    
    function test_UpdateLRTRate() public {
        uint256 newRate = 1.1e18; // 1.1 ETH per LRT
        
        oracle.setRate(address(stETH), newRate);
        
        basketToken.updateAllRates();
        
        assertEq(hook.lrtRates(Currency.wrap(address(stETH))), newRate, "Rate not updated");
    }
    
    function test_addLiquidity() public {
        uint256 additionalLiquidity = 50 * 1e18;
        uint256 initialBalance = stETH.balanceOf(address(hook));
        
        stETH.approve(address(hook), additionalLiquidity);
        hook.addLiquidity(address(stETH), additionalLiquidity);
        
        assertEq(
            stETH.balanceOf(address(hook)),
            initialBalance + additionalLiquidity,
            "Liquidity not added correctly"
        );
        assertEq(
            hook.lrtReserves(Currency.wrap(address(stETH))),
            INITIAL_LIQUIDITY + additionalLiquidity,
            "Reserves not updated correctly"
        );
    }
    
    function test_CalculateExchangeAmount() public {
        uint256 stETHRate = 1.05e18; // 1.05 ETH per stETH
        uint256 rETHRate = 1.1e18;   // 1.1 ETH per rETH
        
        oracle.setRate(address(stETH), stETHRate);
        oracle.setRate(address(rETH), rETHRate);
        
        basketToken.updateAllRates();
        
        uint256 amountIn = 10 * 1e18; // 10 stETH
        uint256 expectedOut = (amountIn * stETHRate) / rETHRate; // (10 * 1.05) / 1.1 = 9.54...
        
        uint256 actualOut = hook.calculateExchangeAmount(address(stETH), address(rETH), amountIn);
        
        assertEq(actualOut, expectedOut, "Exchange amount calculation incorrect");
    }
    
    function test_BasketTokenValuation() public {
        // First, mint some tokens directly for testing
        basketToken.mintForTesting(address(this), 300 * 1e18); // Mint 300 tokens
        
        // Check that the initial basket price is as expected (1 ETH)
        console2.log("Initial basket price:", basketToken.getBasketPrice());
        console2.log("Initial total supply:", basketToken.totalSupply());
        console2.log("Initial total basket value:", basketToken.getTotalBasketValue());
        
        assertEq(basketToken.getBasketPrice(), 1e18, "Initial basket price incorrect");
        
        // Update the rates in the oracle - make all LRTs more valuable
        uint256 newRate = 1.1e18; // 1.1 ETH per LRT
        oracle.setRate(address(stETH), newRate);
        oracle.setRate(address(rETH), newRate);
        oracle.setRate(address(cbETH), newRate);
        
        // Trigger rate updates through the basketToken which has owner rights
        basketToken.updateAllRates();
        
        // Verify the rates were updated in the hook
        assertEq(hook.lrtRates(Currency.wrap(address(stETH))), newRate, "stETH rate not updated in hook");
        assertEq(hook.lrtRates(Currency.wrap(address(rETH))), newRate, "rETH rate not updated in hook");
        assertEq(hook.lrtRates(Currency.wrap(address(cbETH))), newRate, "cbETH rate not updated in hook");
        
        // Print debug information
        console2.log("Updated basket price:", basketToken.getBasketPrice());
        console2.log("Updated total supply:", basketToken.totalSupply());
        console2.log("Updated total basket value:", basketToken.getTotalBasketValue());
        
        // Let's examine what we expect for the basket value
        uint256 expectedBasketValue = 3 * INITIAL_LIQUIDITY * newRate / 1e18;
        console2.log("Expected basket value:", expectedBasketValue);
        
        // Check if there are any tokens minted to the basketToken
        uint256 totalSupply = basketToken.totalSupply();
        if (totalSupply == 0) {
            console2.log("No tokens minted - will use default price of 1 ETH");
        } else {
            // Calculate the expected price
            uint256 expectedPrice = expectedBasketValue * 1e18 / totalSupply;
            console2.log("Expected price based on calculation:", expectedPrice);
        }
        
        // The basket value should now reflect the increased rates
        // Each token has INITIAL_LIQUIDITY (100e18) with a rate of 1.1e18, so the total value should be:
        // 3 tokens * 100e18 * 1.1e18 / 1e18 = 330e18
        // With a total supply of 300e18, the price should be:
        // 330e18 * 1e18 / 300e18 = 1.1e18
        assertEq(basketToken.getBasketPrice(), 1.1e18, "Updated basket price incorrect");
    }
    
    // Additional tests would be added here for swap functionality, basket minting/burning, etc.
} 