// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockLRTToken
 * @notice A simple ERC20 token that represents a Liquid Restaking Token for testing
 */
contract MockLRTToken is ERC20 {
    /// @notice The address that can mint and burn tokens
    address public admin;
    
    /// @notice The exchange rate of this token to ETH (scaled by 1e18)
    uint256 public ethRate;
    
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialRate
    ) ERC20(name, symbol) {
        admin = msg.sender;
        ethRate = initialRate;
    }
    
    /**
     * @notice Mints tokens to an address
     * @param to The address to mint tokens to
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) external {
        require(msg.sender == admin, "Only admin");
        _mint(to, amount);
    }
    
    /**
     * @notice Burns tokens from an address
     * @param from The address to burn tokens from
     * @param amount The amount of tokens to burn
     */
    function burn(address from, uint256 amount) external {
        require(msg.sender == admin || msg.sender == from, "Not authorized");
        _burn(from, amount);
    }
    
    /**
     * @notice Updates the ETH exchange rate
     * @param newRate The new exchange rate (scaled by 1e18)
     */
    function setEthRate(uint256 newRate) external {
        require(msg.sender == admin, "Only admin");
        ethRate = newRate;
    }
} 