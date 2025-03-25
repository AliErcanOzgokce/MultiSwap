// UPDATED: Fixed hook miner and deployment issues
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Hooks} from "v4-core/src/libraries/Hooks.sol";

/// @title HookMiner
/// @notice A utility for mining hook addresses with the correct flags for Uniswap v4
library HookMiner {
    // Mask to slice out the bottom 20 bits of the address (for hook flags)
    uint160 constant FLAG_MASK = Hooks.ALL_HOOK_MASK;
    
    // Maximum number of iterations to find a salt (prevent infinite loops)
    uint256 constant MAX_LOOP = 100_000;

    /// @notice Find a salt that produces a hook address with the desired flags
    /// @param deployer The address that will deploy the hook
    /// @param flags The desired flags for the hook address
    /// @param creationCode The creation code of the hook contract
    /// @param constructorArgs The encoded constructor arguments
    /// @return hookAddress The address where the hook will be deployed
    /// @return salt The salt to use with CREATE2 deployment
    function find(
        address deployer,
        uint160 flags,
        bytes memory creationCode,
        bytes memory constructorArgs
    ) internal pure returns (address hookAddress, bytes32 salt) {
        // Only use the bottom bits corresponding to the flag mask
        flags = flags & FLAG_MASK;
        
        // Combine creation code with constructor arguments
        bytes memory creationCodeWithArgs = abi.encodePacked(creationCode, constructorArgs);
        
        // Iterate until we find a valid address or reach the maximum loop count
        for (uint256 i = 0; i < MAX_LOOP; i++) {
            salt = bytes32(i);
            hookAddress = computeAddress(deployer, salt, creationCodeWithArgs);
            
            // Check if the bottom bits match the desired flags
            if (uint160(hookAddress) & FLAG_MASK == flags) {
                return (hookAddress, salt);
            }
        }
        
        // If we get here, we couldn't find a valid salt
        revert("HookMiner: could not find salt");
    }
    
    /// @notice Compute a contract address for CREATE2 deployment
    /// @param deployer The address that will deploy the contract
    /// @param salt The salt for CREATE2
    /// @param creationCodeWithArgs Creation code with constructor arguments
    /// @return The computed address
    function computeAddress(
        address deployer,
        bytes32 salt,
        bytes memory creationCodeWithArgs
    ) internal pure returns (address) {
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            deployer,
                            salt,
                            keccak256(creationCodeWithArgs)
                        )
                    )
                )
            )
        );
    }
} 