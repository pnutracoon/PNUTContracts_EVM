// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract LifePurchaseMock {
    uint256 public lifePrice = 0.01 ether;

    event LifePurchased(address indexed buyer, uint256 amount);

    function buyLife(uint256 _amount) external payable returns (bool) {
        require(msg.value >= lifePrice * _amount, "Insufficient ETH to buy a life");
        emit LifePurchased(msg.sender, _amount);
        return true;
    }
}
