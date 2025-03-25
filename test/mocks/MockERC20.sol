// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockERC20
 * @notice A simple ERC20 token implementation for testing purposes
 */
contract MockERC20 is ERC20 {
    uint8 private _decimals;

    /**
     * @notice Constructor
     * @param name_ The name of the token
     * @param symbol_ The token symbol
     * @param decimals_ The number of decimals the token uses
     */
    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
        _decimals = decimals_;
    }

    /**
     * @notice Returns the number of decimals the token uses
     */
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /**
     * @notice Mints tokens to the specified account
     * @param account The account to mint tokens to
     * @param amount The amount of tokens to mint
     */
    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    /**
     * @notice Burns tokens from the specified account
     * @param account The account to burn tokens from
     * @param amount The amount of tokens to burn
     */
    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }
} 