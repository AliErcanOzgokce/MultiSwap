// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {MultiLRTHook} from "../src/hooks/MultiLRTHook.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "../src/utils/HookMiner.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";

/**
 * @title DeployMultiLRT
 * @notice Deployment script for the Multi LRT Pool system
 */
contract DeployMultiLRT is Script {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;
    
    // Deployment addresses
    PoolManager public poolManager;
    MultiLRTHook public hook;
    
    // Mock tokens for testing
    MockERC20 public stETH;
    MockERC20 public rETH;
    MockERC20 public cbETH;
    
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
        uint256 initialRate = 1e18; // 1 LRT = 1 ETH
        hook.updateLRTRate(address(stETH), initialRate);
        hook.updateLRTRate(address(rETH), initialRate);
        hook.updateLRTRate(address(cbETH), initialRate);
        
        // Mint some tokens for testing
        uint256 testAmount = 1000 * 1e18;
        stETH.mint(msg.sender, testAmount);
        rETH.mint(msg.sender, testAmount);
        cbETH.mint(msg.sender, testAmount);
        
        // Create pairs and initialize pools
        createAndInitializePool(Currency.wrap(address(stETH)), Currency.wrap(address(rETH)));
        createAndInitializePool(Currency.wrap(address(stETH)), Currency.wrap(address(cbETH)));
        createAndInitializePool(Currency.wrap(address(rETH)), Currency.wrap(address(cbETH)));
        
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
        console2.log("Pool ID:", toHexString(uint256(uint160(address(this)))));
    }

    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x0";
        }

        bytes16 hexSymbols = "0123456789abcdef";
        uint256 length = 0;
        uint256 temp = value;
        
        while (temp != 0) {
            length++;
            temp >>= 4;
        }
        
        bytes memory buffer = new bytes(2 + length);
        buffer[0] = "0";
        buffer[1] = "x";
        
        for (uint256 i = 2 + length - 1; i >= 2; i--) {
            buffer[i] = hexSymbols[value & 0xf];
            value >>= 4;
        }
        
        return string(buffer);
    }

    function addressToString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)));
    }
} 