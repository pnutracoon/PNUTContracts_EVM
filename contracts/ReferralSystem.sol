// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Ownable} from "./external/openzeppline/Ownable.sol";
import {AccessControl} from "./external/openzeppline/AccessControl.sol";

interface INameAvailability {
    /**
     * @notice Checks if the given name appended with ".raccoon" exists.
     * @param _name The base name to check availability for (without the ".raccoon" suffix).
     * @return bool True if the name is available, false otherwise.
     */
    function ifIsAvailable(string calldata _name) external view returns (bool);

    /**
     * @notice Gets the owner of the specified token ID.
     * @param tokenId The ID of the token.
     * @return address The address of the token owner.
     */
    function ownerOf(uint256 tokenId) external view returns (address);
}

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

    struct UserData {
        uint256 refCoins;
        uint256 coins;
        uint256 totalInvitees;
        address userAddress;
        address referredBy;
        address[] allMyInvitees;
        uint256[] unClaimedInvitees;
    }

    // Reference to the Game Manager contract
    IGameManager public gameManager;

    INameAvailability public nameAvailability;

    // Reward per referral
    uint256 public rewardPerReferral = 3000;

    // Minimum coins required to convert RefCoins
    uint256 public minCoinsRequired = 6000;

    mapping(address => UserData) public userData;

    // Events
    event ReferralRegistered(address indexed referrer, address indexed referee);
    event RefCoinsAwarded(address indexed referrer, uint256 amount);
    event RefCoinsConverted(
        address indexed user,
        uint256 refCoinsConverted,
        uint256[] inviteeIndices
    );
    event UpdatedBalanceOnClaim(address indexed player, uint256 coins);

    constructor(
        address _gameManagerAddress,
        address _nameAvailability,
        address _delegate
    ) Ownable(_delegate) {
        _grantRole(DEFAULT_ADMIN_ROLE, _delegate);
        gameManager = IGameManager(_gameManagerAddress);
        nameAvailability = INameAvailability(_nameAvailability);
    }

    /**
     * @notice Allows users to claim rewards for multiple invitees in a batch.
     * @param inviteeIndices An array of indices corresponding to unclaimed invitees.
     */
    function claimReferralRewardsBatch(
        uint256[] calldata inviteeIndices,
        address playerAddress
    ) external onlyRole(PLANNER_ADMIN) {
        UserData storage referrer = userData[playerAddress];
        uint256 inviteeCount = inviteeIndices.length;

        // Ensure the player has enough coins to claim
        require(
            canClaim(playerAddress, inviteeCount),
            "Not enough coins to claim rewards"
        );

        uint256 totalRewards = 0;

        // Keep track of processed indices to handle removal later
        uint256 lastIndex = referrer.unClaimedInvitees.length - 1;
        uint256 removedCount = 0;

        for (uint256 i = 0; i < inviteeIndices.length; i++) {
            uint256 inviteeIndex = inviteeIndices[i];

            // Validate the index
            require(
                inviteeIndex < referrer.unClaimedInvitees.length,
                "Invalid invitee index"
            );

            // Calculate adjusted index accounting for previously removed items
            uint256 adjustedIndex = inviteeIndex - removedCount;

            // Add reward for this invitee
            totalRewards += rewardPerReferral;

            // Remove the claimed invitee using swap-and-pop
            if (adjustedIndex != lastIndex) {
                referrer.unClaimedInvitees[adjustedIndex] = referrer
                    .unClaimedInvitees[lastIndex];
            }
            referrer.unClaimedInvitees.pop();
            lastIndex--;
            removedCount++;
        }

        // Update referrer's refCoins balance
        referrer.coins += totalRewards;

        emit RefCoinsConverted(playerAddress, totalRewards, inviteeIndices);
    }

    function useRefCode(
        string calldata code,
        address _newUser
    ) external onlyRole(PLANNER_ADMIN) {
        (
            uint256 _tokenId,
            string memory _noSuffix
        ) = _requireAndRemoveRaccoonSuffix(code);
        bool nameExists = nameAvailability.ifIsAvailable(_noSuffix);
        require(nameExists, "Invalid code");

        address _referrer = nameAvailability.ownerOf(_tokenId);
        require(_referrer != _newUser, "Self-referral is not allowed");

        // Ensure the new user is not already initialized
        require(
            !gameManager.isPlayerInitialized(_newUser),
            "User already initialized"
        );

        // Update referral data
        userData[_newUser].referredBy = _referrer;
        userData[_referrer].totalInvitees += 1;
        userData[_referrer].allMyInvitees.push(_newUser);
        uint256 newIndex = userData[_referrer].unClaimedInvitees.length + 1;
        userData[_referrer].unClaimedInvitees.push(newIndex);

        // Award referral coins
        userData[_referrer].refCoins += rewardPerReferral;

        emit ReferralRegistered(_referrer, _newUser);
        emit RefCoinsAwarded(_referrer, rewardPerReferral);
    }

    function getUserData(
        address _user
    )
        external
        view
        returns (
            uint256 refCoins,
            uint256 coins,
            uint256 totalInvitees,
            address referredBy,
            address[] memory allMyInvitees
        )
    {
        UserData storage user = userData[_user];
        return (
            user.refCoins,
            user.coins,
            user.totalInvitees,
            user.referredBy,
            user.allMyInvitees
        );
    }

    /**
     * @notice Checks if a player has enough coins to claim rewards for given invitee indices.
     * @param player The address of the player.
     * @param inviteeCount The number of invitees the player wants to claim for.
     * @return bool True if the player has enough coins, false otherwise.
     */
    function canClaim(
        address player,
        uint256 inviteeCount
    ) public view returns (bool) {
        // Fetch player stats
        (uint256 coins, , , ) = gameManager.getPlayerStats(player);

        // Calculate the required coins to claim
        uint256 requiredCoins = rewardPerReferral * inviteeCount;

        // Check if the player has enough coins
        return coins >= requiredCoins;
    }

    function _requireAndRemoveRaccoonSuffix(
        string memory input
    ) internal pure returns (uint256 prefix, string memory name) {
        string memory suffix = ".raccoon";
        bytes memory inputBytes = bytes(input);
        bytes memory suffixBytes = bytes(suffix);

        // Check if the input ends with the suffix
        require(inputBytes.length > suffixBytes.length, "Input too short");
        for (uint256 i = 0; i < suffixBytes.length; i++) {
            require(
                inputBytes[inputBytes.length - suffixBytes.length + i] ==
                    suffixBytes[i],
                "Input must end with .raccoon"
            );
        }

        // Find the first '.' to locate the prefix
        int256 firstDotIndex = -1;
        for (uint256 i = 0; i < inputBytes.length; i++) {
            if (inputBytes[i] == ".") {
                firstDotIndex = int256(i);
                break;
            }
        }
        require(firstDotIndex > 0, "Invalid format: no '.' before name");

        // Extract the prefix
        uint256 num = 0;
        for (uint256 i = 0; i < uint256(firstDotIndex); i++) {
            require(
                inputBytes[i] >= "0" && inputBytes[i] <= "9",
                "Invalid prefix format"
            );
            num = num * 10 + (uint8(inputBytes[i]) - 48); // ASCII '0' is 48
        }

        // Find the last '.' before the suffix to locate the name
        int256 lastDotIndex = -1;
        for (
            uint256 i = uint256(firstDotIndex) + 1;
            i < inputBytes.length - suffixBytes.length;
            i++
        ) {
            if (inputBytes[i] == ".") {
                lastDotIndex = int256(i);
            }
        }

        // If no additional '.' is found, assume the name ends before the suffix
        if (lastDotIndex <= int256(firstDotIndex)) {
            lastDotIndex = int256(inputBytes.length - suffixBytes.length);
        }

        // Extract the name
        uint256 startIndex = uint256(firstDotIndex) + 1;
        uint256 endIndex = uint256(lastDotIndex);
        bytes memory nameBytes = new bytes(endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; i++) {
            nameBytes[i - startIndex] = inputBytes[i];
        }

        return (num, string(nameBytes));
    }

    function updateRewardPerReferral(
        uint256 newReward
    ) external onlyRole(ADMIN_ROLE) {
        rewardPerReferral = newReward;
    }

    function updateMinCoinsRequired(
        uint256 newMinCoins
    ) external onlyRole(ADMIN_ROLE) {
        minCoinsRequired = newMinCoins;
    }

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

    /// @notice THIS IS TO BE CALLED BY CLAIM CONTRACT ONLY
    /// @param _userAddress address of the player
    /// @param _amount amount claimed by the player
    function updateCoinBalance(
        address _userAddress,
        uint256 _amount
    ) external onlyRole(ADMIN_ROLE) {
        require(
            gameManager.isPlayerInitialized(_userAddress),
            "Player not initialized"
        );
        UserData storage player = userData[_userAddress];
        player.coins -= _amount;
        emit UpdatedBalanceOnClaim(_userAddress, _amount);
    }

    /// @notice grants role
    /// @param _address  address to be granted
    function grantPlannerAdminRole(
        address _address
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(PLANNER_ADMIN, _address);
    }

    /// @notice revokes role
    /// @param _address  address to be revoked
    function revokePlannerAdminRole(
        address _address
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(PLANNER_ADMIN, _address);
    }
}
