// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @title HookMiner
/// @notice Library for computing hook addresses that have specific flags
library HookMiner {
    /// @notice Computes the address of a hook contract with specific flags
    /// @param deployer The address that will deploy the hook
    /// @param flags The hook flags that must be encoded in the address
    /// @param creationCode The creation code of the hook
    /// @param constructorArgs The constructor arguments for the hook
    /// @param salt The salt for address generation (can be adjusted to find a valid address)
    /// @return hookAddress The computed hook address
    /// @return salt The salt that generates the computed hook address
    function find(
        address deployer,
        uint160 flags,
        bytes memory creationCode,
        bytes memory constructorArgs,
        bytes32 salt
    ) internal pure returns (address hookAddress, bytes32) {
        bytes memory bytecode = abi.encodePacked(creationCode, constructorArgs);
        bytes32 initcodeHash = keccak256(bytecode);

        // Find a salt that produces a hook address with the correct prefix
        uint256 saltNum = uint256(salt);
        while (true) {
            saltNum++;
            salt = bytes32(saltNum);
            
            hookAddress = computeAddress(deployer, salt, initcodeHash);
            
            // Check if the address has the correct flags encoded
            if (uint160(hookAddress) & 0xFF == flags) {
                // Found a valid address
                return (hookAddress, salt);
            }
        }
    }

    /// @dev Compute the contract address given the deployer, salt, and initcode hash
    function computeAddress(
        address deployer,
        bytes32 salt,
        bytes32 initcodeHash
    ) internal pure returns (address hookAddress) {
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            deployer,
                            salt,
                            initcodeHash
                        )
                    )
                )
            )
        );
    }
} 