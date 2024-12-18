// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

// import "hardhat/console.sol";

import {Ownable} from "./external/openzeppline/Ownable.sol";
import {ReentrancyGuard} from "./external/openzeppline/ReentrancyGuard.sol";

/// @title BuyLifeContract
/// @author Racoon Devs
/// @notice Creates a contract to buy life for game

contract BuyLifeContract is Ownable, ReentrancyGuard {
    // address public owner;
    uint256 public lifePrice; // Price of a "life" in wei

    event LifePurchased(address indexed buyer, uint256 amount);
    event FundsWithdrawn(address indexed owner, uint256 amount);

    /// @dev creates a constructor for the contract
    /// @param _lifePrice price of a "life" in wei

    constructor(uint256 _lifePrice, address _delegate) Ownable(_delegate) {
        require(_lifePrice > 0, "Life price must be greater than zero");
        lifePrice = _lifePrice;
    }

    /// @dev defines a function to buy life
    /// @param _amount amount of life to purchase

    // Function to buy a "life"
    function buyLife(
        uint256 _amount
    ) external payable nonReentrant returns (bool) {
        require(
            msg.value >= (lifePrice * _amount),
            "Insufficient ETH to buy a life"
        );

        // Emit an event for successful purchase
        emit LifePurchased(msg.sender, msg.value);

        return true;
    }

    // ==========================OWNER FUNCTIONS======================================= //

    // Function to withdraw funds (only the owner can call this)
    function withdraw() external onlyOwner {
        uint256 contractBalance = address(this).balance;
        require(contractBalance > 0, "No funds to withdraw");

        (bool success, ) = payable(owner()).call{value: contractBalance}("");
        require(success, "Withdrawal failed");

        emit FundsWithdrawn(owner(), contractBalance);
    }

    /// @dev creates a function to set life price
    /// @param _lifePrice price of a "life" in wei

    function setLifePrice(uint256 _lifePrice) external onlyOwner {
        lifePrice = _lifePrice;
    }

    // =============================EXTRAS======================================= //

    // Fallback function to prevent accidental ETH transfers
    receive() external payable {
        revert("Direct deposits are not allowed");
    }

    fallback() external payable {
        revert("Fallback function called");
    }
}
