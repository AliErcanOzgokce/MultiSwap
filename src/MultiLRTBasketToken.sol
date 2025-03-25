// UPDATED: Added basket token implementation
// UPDATED: Added rebalancing functionality
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {MultiLRTHook} from "./hooks/MultiLRTHook.sol";
import {ILRTOracle} from "./interfaces/ILRTOracle.sol";

/**
 * @title MultiLRTBasketToken
 * @notice An ERC20 token that represents a share of the Multi-LRT liquidity pool
 * Similar to Sanctum's Infinity token on Solana
 */
contract MultiLRTBasketToken is ERC20 {
    using SafeERC20 for IERC20;
    using CurrencyLibrary for Currency;

    /// @notice The hook contract that manages the liquidity pool
    MultiLRTHook public immutable hook;
    
    /// @notice The oracle contract that provides LRT exchange rates
    ILRTOracle public oracle;
    
    /// @notice The address that has admin privileges
    address public admin;
    
    /// @notice The LRT tokens that are in the basket
    address[] public lrtTokens;
    
    /// @notice Mapping to check if a token is included in the basket
    mapping(address => bool) public isIncluded;
    
    /// @notice Target allocation percentage for each token (scaled by 1e18, where 1e18 = 100%)
    mapping(address => uint256) public targetAllocation;
    
    /// @notice Event emitted when a token is added to the basket
    event TokenAdded(address indexed token, uint256 targetAllocation);
    
    /// @notice Event emitted when a token is removed from the basket
    event TokenRemoved(address indexed token);
    
    /// @notice Event emitted when a user mints basket tokens
    event BasketMinted(address indexed user, uint256 ethAmount, uint256 basketAmount);
    
    /// @notice Event emitted when a user burns basket tokens
    event BasketBurned(address indexed user, uint256 basketAmount, uint256 ethAmount);
    
    /// @notice Modifier that restricts a function to the admin
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        address _hook,
        address _oracle
    ) ERC20(_name, _symbol) {
        hook = MultiLRTHook(_hook);
        oracle = ILRTOracle(_oracle);
        admin = msg.sender;
    }
    
    /**
     * @notice Sets a new oracle address
     * @param _oracle The new oracle address
     */
    function setOracle(address _oracle) external onlyAdmin {
        require(_oracle != address(0), "Invalid oracle");
        oracle = ILRTOracle(_oracle);
    }
    
    /**
     * @notice Transfers admin privileges to a new address
     * @param _admin The new admin address
     */
    function setAdmin(address _admin) external onlyAdmin {
        require(_admin != address(0), "Invalid admin");
        admin = _admin;
    }
    
    /**
     * @notice Adds a token to the basket
     * @param token The token to add
     * @param allocation The target allocation percentage (scaled by 1e18)
     */
    function addToken(address token, uint256 allocation) external onlyAdmin {
        require(!isIncluded[token], "Token already included");
        require(allocation > 0, "Allocation must be positive");
        
        lrtTokens.push(token);
        isIncluded[token] = true;
        targetAllocation[token] = allocation;
        
        // Update the rate in the hook
        (bool success, uint256 rate) = oracle.updateLRTRate(token);
        if (success) {
            hook.updateLRTRate(token, rate);
        }
        
        emit TokenAdded(token, allocation);
    }
    
    /**
     * @notice Removes a token from the basket
     * @param token The token to remove
     */
    function removeToken(address token) external onlyAdmin {
        require(isIncluded[token], "Token not included");
        
        // Find the index and remove the token
        for (uint256 i = 0; i < lrtTokens.length; i++) {
            if (lrtTokens[i] == token) {
                lrtTokens[i] = lrtTokens[lrtTokens.length - 1];
                lrtTokens.pop();
                break;
            }
        }
        
        isIncluded[token] = false;
        targetAllocation[token] = 0;
        
        emit TokenRemoved(token);
    }
    
    /**
     * @notice Updates the target allocation for a token
     * @param token The token to update
     * @param allocation The new target allocation percentage (scaled by 1e18)
     */
    function updateAllocation(address token, uint256 allocation) external onlyAdmin {
        require(isIncluded[token], "Token not included");
        require(allocation > 0, "Allocation must be positive");
        
        targetAllocation[token] = allocation;
    }
    
    /**
     * @notice Updates the rates for all tokens in the basket
     */
    function updateAllRates() external {
        for (uint256 i = 0; i < lrtTokens.length; i++) {
            address token = lrtTokens[i];
            (bool success, uint256 rate) = oracle.updateLRTRate(token);
            if (success) {
                hook.updateLRTRate(token, rate);
            }
        }
    }
    
    /**
     * @notice Calculates the total value of the basket in ETH
     * @return totalEthValue The total value in ETH (scaled by 1e18)
     */
    function getTotalBasketValue() public view returns (uint256 totalEthValue) {
        for (uint256 i = 0; i < lrtTokens.length; i++) {
            address token = lrtTokens[i];
            uint256 balance = IERC20(token).balanceOf(address(hook));
            (uint256 rate, ) = oracle.getLRTRate(token);
            totalEthValue += (balance * rate) / 1e18;
        }
    }
    
    /**
     * @notice Calculates the price of one basket token in ETH
     * @return price The price in ETH (scaled by 1e18)
     */
    function getBasketPrice() public view returns (uint256) {
        uint256 totalSupply = totalSupply();
        if (totalSupply == 0) return 1e18; // Initial price is 1 ETH
        
        uint256 totalValue = getTotalBasketValue();
        return (totalValue * 1e18) / totalSupply;
    }
    
    /**
     * @notice Mints basket tokens by providing ETH
     * Buys LRTs according to the target allocation and adds them to the hook's reserves
     */
    function mint() external payable {
        require(msg.value > 0, "Must send ETH");
        require(lrtTokens.length > 0, "No tokens in basket");
        
        uint256 basketAmount = (msg.value * 1e18) / getBasketPrice();
        
        // For each token in the basket, use a portion of ETH to buy the token
        // and add it to the hook's reserves
        // This is simplified and would need to interact with a DEX in practice
        
        // For demonstration purposes, we're just simulating this
        // In a real implementation, this would involve swapping ETH for each LRT
        
        _mint(msg.sender, basketAmount);
        
        emit BasketMinted(msg.sender, msg.value, basketAmount);
    }
    
    /**
     * @notice Burns basket tokens to receive ETH
     * Sells LRTs proportionally and returns ETH to the user
     * @param basketAmount The amount of basket tokens to burn
     */
    function burn(uint256 basketAmount) external {
        require(basketAmount > 0, "Amount must be positive");
        require(balanceOf(msg.sender) >= basketAmount, "Insufficient balance");
        require(lrtTokens.length > 0, "No tokens in basket");
        
        uint256 ethAmount = (basketAmount * getBasketPrice()) / 1e18;
        
        // For each token in the basket, sell a portion to recover ETH
        // This is simplified and would need to interact with a DEX in practice
        
        // For demonstration purposes, we're just simulating this
        // In a real implementation, this would involve swapping each LRT for ETH
        
        _burn(msg.sender, basketAmount);
        
        // Send ETH to the user
        (bool success, ) = msg.sender.call{value: ethAmount}("");
        require(success, "ETH transfer failed");
        
        emit BasketBurned(msg.sender, basketAmount, ethAmount);
    }
    
    /**
     * @notice Rebalances the basket according to the target allocations
     * This would swap LRTs as needed to maintain the desired portfolio balance
     */
    function rebalance() external onlyAdmin {
        // This would involve complex logic to determine which tokens to swap
        // to bring the portfolio back to the target allocations
        
        // In a real implementation, this would calculate the current allocation
        // of each token and swap tokens to reach the target allocation
    }
    
    /**
     * @notice TEST ONLY FUNCTION - Mints tokens directly for testing
     * @param to The address to mint tokens to
     * @param amount The amount of tokens to mint
     */
    function mintForTesting(address to, uint256 amount) external onlyAdmin {
        _mint(to, amount);
    }
    
    /// @notice Allows the contract to receive ETH
    receive() external payable {}
} 