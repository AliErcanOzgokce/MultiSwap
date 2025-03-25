// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IHooks} from "v4-core/src/interfaces/IHooks.sol";

/// @title HookDeployer
/// @notice A utility for deploying hooks with correct addresses for Uniswap v4
contract HookDeployer {
    /// @notice Deploys a hook with the CREATE2 opcode
    /// @param implementation The implementation address of the hook
    /// @param salt The salt to use for the deployment
    /// @return deployedHook The address of the deployed hook
    function deploy(address implementation, bytes32 salt) external returns (address deployedHook) {
        // Simplified implementation code for testing purposes
        // In a real-world scenario, we would check the address flags
        
        // Deploy the hook using CREATE2
        assembly {
            let bytecode := mload(0x40)  // Get free memory pointer
            mstore(bytecode, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(bytecode, 0x14), shl(96, implementation))
            mstore(add(bytecode, 0x28), 0x5af43d82803e903d91602b57fd5bf3)
            deployedHook := create2(0, bytecode, 0x37, salt)
            if iszero(deployedHook) { revert(0, 0) }
        }
        
        return deployedHook;
    }
    
    /// @notice Gets the address that would be deployed
    /// @param implementation The implementation address of the hook
    /// @param salt The salt to use for the deployment
    /// @return deployedAddress The address that would be deployed
    function getDeployedAddress(address implementation, bytes32 salt) public view returns (address deployedAddress) {
        bytes32 bytecodeHash = keccak256(abi.encodePacked(
            bytes1(0x3d), bytes1(0x60), bytes1(0x2d), bytes1(0x80), bytes1(0x60), bytes1(0x0a), bytes1(0x3d), bytes1(0x39), bytes1(0x81), bytes1(0xf3),
            bytes1(0x36), bytes1(0x3d), bytes1(0x3d), bytes1(0x37), bytes1(0x3d), bytes1(0x3d), bytes1(0x3d), bytes1(0x36), bytes1(0x3d), bytes1(0x73),
            bytes20(implementation),
            bytes1(0x5a), bytes1(0xf4), bytes1(0x3d), bytes1(0x82), bytes1(0x80), bytes1(0x3e), bytes1(0x90), bytes1(0x3d), bytes1(0x91), bytes1(0x60), bytes1(0x2b), bytes1(0x57), bytes1(0xfd), bytes1(0x5b), bytes1(0xf3)
        ));
        
        deployedAddress = address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            address(this),
            salt,
            bytecodeHash
        )))));
    }
} 