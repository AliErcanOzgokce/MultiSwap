// UPDATED: Improved tests and factory
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {MultiLRTHook} from "./hooks/MultiLRTHook.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {HookMiner} from "./utils/HookMiner.sol";

/**
 * @title MultiLRTFactory
 * @notice Factory contract for deploying the MultiLRTHook with the correct address prefix
 */
contract MultiLRTFactory {
    using CurrencyLibrary for Currency;

    /// @notice The address of the hook that was deployed by this factory
    address public hook;

    /// @notice Creates the MultiLRTHook with the correct address prefix for Uniswap v4
    /// @param _poolManager The address of the Uniswap v4 PoolManager
    /// @param _salt The salt to use for address generation (can be adjusted to find a valid hook address)
    function deploy(address _poolManager, bytes32 _salt) external returns (address) {
        // Calculate the address prefix needed for the hook
        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG);

        // Find a salt that produces a hook address with the correct prefix
        (address hookAddress, bytes32 salt) = HookMiner.find(
            address(this),
            flags,
            type(MultiLRTHook).creationCode,
            abi.encode(IPoolManager(_poolManager))
        );

        // Deploy the hook with the correct address
        hook = address(new MultiLRTHook{salt: salt}(IPoolManager(_poolManager)));
        require(hook == hookAddress, "Factory: Hook deployment failed");
        
        return hook;
    }
} 