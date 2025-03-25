// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ILRTOracle} from "../interfaces/ILRTOracle.sol";

/**
 * @title MockLRTOracle
 * @notice A mock oracle for testing that allows setting LRT rates manually
 */
contract MockLRTOracle is ILRTOracle {
    /// @notice The address that can update rates
    address public admin;
    
    /// @notice Storage for LRT rates
    mapping(address => uint256) private rates;
    
    /// @notice Storage for last updated timestamps
    mapping(address => uint256) private lastUpdated;
    
    constructor() {
        admin = msg.sender;
    }
    
    /**
     * @notice Sets the rate for an LRT token manually
     * @param lrt The address of the LRT token
     * @param rate The exchange rate (scaled by 1e18)
     */
    function setRate(address lrt, uint256 rate) external {
        require(msg.sender == admin, "Only admin");
        rates[lrt] = rate;
        lastUpdated[lrt] = block.timestamp;
    }
    
    /**
     * @notice Gets the ETH exchange rate for a specific LRT
     * @param lrt The address of the LRT token
     * @return rate The exchange rate (scaled by 1e18)
     * @return lastUpdate The timestamp when the rate was last updated
     */
    function getLRTRate(address lrt) external view override returns (uint256 rate, uint256 lastUpdate) {
        return (rates[lrt], lastUpdated[lrt]);
    }
    
    /**
     * @notice Updates the exchange rate for a specific LRT
     * @param lrt The address of the LRT token
     * @return success Whether the update was successful
     * @return rate The updated exchange rate (scaled by 1e18)
     */
    function updateLRTRate(address lrt) external override returns (bool success, uint256 rate) {
        // In this mock implementation, we're just returning the existing rate
        // In a real implementation, this would fetch the rate from an external source
        return (rates[lrt] > 0, rates[lrt]);
    }
} 