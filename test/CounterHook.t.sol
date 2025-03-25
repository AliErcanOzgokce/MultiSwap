// UPDATED: Fixed lock/unlock patterns
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {CounterHook} from "../src/hooks/CounterHook.sol";
import {HookMiner} from "../src/utils/HookMiner.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {LiquidityAmounts} from "v4-periphery/src/libraries/LiquidityAmounts.sol";
import {FixedPointMathLib} from "solmate/src/utils/FixedPointMathLib.sol";

contract CounterHookTest is Test {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using FixedPointMathLib for uint256;

    PoolManager public poolManager;
    CounterHook public hook;

    MockERC20 public token0;
    MockERC20 public token1;

    PoolKey public poolKey;
    PoolId public poolId;

    function setUp() public {
        // Deploy the pool manager
        poolManager = new PoolManager(address(this));

        // Deploy tokens
        token0 = new MockERC20("Token0", "TK0", 18);
        token1 = new MockERC20("Token1", "TK1", 18);

        // Sort tokens by address
        if (address(token0) > address(token1)) {
            (token0, token1) = (token1, token0);
        }

        // Set the flags for the hook
        uint160 flags = uint160(
            Hooks.BEFORE_SWAP_FLAG | 
            Hooks.AFTER_SWAP_FLAG | 
            Hooks.BEFORE_ADD_LIQUIDITY_FLAG | 
            Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
        );
        
        // Mine hook address with correct flags
        (address hookAddress, bytes32 salt) = HookMiner.find(
            address(this),
            flags,
            type(CounterHook).creationCode,
            abi.encode(IPoolManager(address(poolManager)))
        );

        // Deploy the hook with the computed salt
        hook = new CounterHook{salt: salt}(IPoolManager(address(poolManager)));
        require(address(hook) == hookAddress, "Hook deployment failed");

        // Create pool key
        poolKey = PoolKey({
            currency0: Currency.wrap(address(token0)),
            currency1: Currency.wrap(address(token1)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(hook)
        });
        poolId = poolKey.toId();

        // Initialize the pool
        poolManager.initialize(poolKey, TickMath.MIN_SQRT_PRICE);

        // Mint tokens to this contract
        token0.mint(address(this), 100 ether);
        token1.mint(address(this), 100 ether);

        // Approve tokens to the pool manager for this contract
        token0.approve(address(poolManager), type(uint256).max);
        token1.approve(address(poolManager), type(uint256).max);
    }

    function test_CounterHookDeployment() public view {
        assertTrue(address(hook) != address(0), "Hook was not deployed");

        // Verify hook permissions
        Hooks.Permissions memory permissions = hook.getHookPermissions();
        assertTrue(permissions.beforeSwap, "beforeSwap should be enabled");
        assertTrue(permissions.afterSwap, "afterSwap should be enabled");
        assertTrue(permissions.beforeAddLiquidity, "beforeAddLiquidity should be enabled");
        assertTrue(permissions.beforeRemoveLiquidity, "beforeRemoveLiquidity should be enabled");
    }
} 