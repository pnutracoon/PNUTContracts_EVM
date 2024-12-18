// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Ownable} from "./external/openzeppline/Ownable.sol";
import {AccessControl} from "./external/openzeppline/AccessControl.sol";

interface IGameManager {
    /**
     * @dev Checks if a player is initialized.
     * @param playerAddress Address of the player.
     * @return Boolean indicating if the player is initialized.
     */
    function isPlayerInitialized(
        address playerAddress
    ) external view returns (bool);

    /**
     * @dev Retrieve player stats from the Game Manager contract.
     * @param playerAddress Address of the player.
     * @return coins Player's coins.
     * @return lives Player's lives.
     * @return rank Player's rank.
     * @return premiumCoins Player's premium coins.
     */
    function getPlayerStats(
        address playerAddress
    )
        external
        view
        returns (
            uint256 coins,
            uint256 lives,
            uint256 rank,
            uint256 premiumCoins
        );
}

contract ReferralSystem is Ownable, AccessControl {
    bytes32 private constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 private constant PLANNER_ADMIN = keccak256("PLANNER_ADMIN");

    // Reference to the Game Manager contract
    IGameManager public gameManager;

    // Reward per referral
    uint256 public rewardPerReferral = 3000;

    // Minimum coins required to convert RefCoins
    uint256 public minCoinsRequired = 6000;

    // Events
    event ReferralRegistered(address indexed referrer, address indexed referee);
    event RefCoinsAwarded(address indexed referrer, uint256 amount);
    event RefCoinsConverted(address indexed user, uint256 refCoinsConverted);

    constructor(
        address _gameManagerAddress,
        address _delegate
    ) Ownable(_delegate) {
        _grantRole(DEFAULT_ADMIN_ROLE, _delegate);
        gameManager = IGameManager(_gameManagerAddress);
    }

    function generateRefCode(address) external onlyRole(PLANNER_ADMIN) {}

    /// @notice grants role
    /// @param _address  address to be granted
    function grantAdminRole(
        address _address
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(ADMIN_ROLE, _address);
    }

    /// @notice revokes role
    /// @param _address  address to be revoked
    function revokeAdminRole(
        address _address
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(ADMIN_ROLE, _address);
    }
}
