// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title ILRTOracle
 * @notice Interface for an oracle that provides exchange rates for Liquid Restaking Tokens (LRTs)
 */
interface ILRTOracle {
    /**
     * @notice Gets the ETH exchange rate for a specific LRT
     * @param lrt The address of the LRT token
     * @return rate The exchange rate (scaled by 1e18, where 1e18 = 1 ETH)
     * @return lastUpdated The timestamp when the rate was last updated
     */
    function getLRTRate(address lrt) external view returns (uint256 rate, uint256 lastUpdated);
    
    /**
     * @notice Updates the exchange rate for a specific LRT
     * @param lrt The address of the LRT token
     * @return success Whether the update was successful
     * @return rate The updated exchange rate (scaled by 1e18)
     */
    function updateLRTRate(address lrt) external returns (bool success, uint256 rate);
} 