// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {Currency, CurrencyLibrary} from "v4-core/src/types/Currency.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {FixedPointMathLib} from "solmate/src/utils/FixedPointMathLib.sol";
import {HookMiner} from "../src/utils/HookMiner.sol";
import {CounterHook} from "../src/hooks/CounterHook.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";

contract AnvilScript is Script {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using FixedPointMathLib for uint256;

    // Contract instances
    PoolManager public poolManager;
    CounterHook public hook;
    
    // Test tokens
    MockERC20 public token0;
    MockERC20 public token1;

    function setUp() public {}

    function run() public {
        // Start broadcasting
        vm.startBroadcast();

        // Deploy the PoolManager
        poolManager = new PoolManager(address(this));
        console2.log("PoolManager deployed at:", address(poolManager));

        // Deploy test tokens
        token0 = new MockERC20("Token0", "TK0", 18);
        token1 = new MockERC20("Token1", "TK1", 18);
        console2.log("Token0 deployed at:", address(token0));
        console2.log("Token1 deployed at:", address(token1));

        // Ensure token0 address is less than token1
        if (address(token0) > address(token1)) {
            (token0, token1) = (token1, token0);
        }

        // Mine hook address with correct flags for CounterHook
        (address hookAddress, bytes32 salt) = HookMiner.find(
            address(this), 
            uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG), 
            type(CounterHook).creationCode,
            abi.encode(address(poolManager))
        );

        // Deploy the hook with the computed salt
        hook = new CounterHook{salt: salt}(IPoolManager(address(poolManager)));
        require(address(hook) == hookAddress, "Hook deployment failed");
        console2.log("CounterHook deployed at:", address(hook));

        // Create pool key
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(address(token0)),
            currency1: Currency.wrap(address(token1)),
            fee: 3000,
            tickSpacing: 60,
            hooks: hook
        });

        // Initialize the pool with 1:1 price ratio
        poolManager.initialize(poolKey, uint160(TickMath.getSqrtPriceAtTick(0)));
        console2.log("Pool initialized with ID:", toHexString(uint256(uint160(address(this)))));

        // Mint tokens to the deployer
        uint256 mintAmount = 1000 * 10**18;
        token0.mint(msg.sender, mintAmount);
        token1.mint(msg.sender, mintAmount);
        console2.log("Minted tokens to deployer:", msg.sender);

        vm.stopBroadcast();
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