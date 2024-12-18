// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Ownable} from "./external/openzeppline/Ownable.sol";
import {AccessControl} from "./external/openzeppline/AccessControl.sol";

/// @title Game Manager Contract
/// @author Racoon Devs
/// @notice Manages Player's Data

/// @notice  Interface of Life Purchase
interface ILifePurchase {
    function buyLife(uint256 _amount) external payable returns (bool);
}

/// @notice  Interface of Life Purchase
interface IGameManager {
    /// @notice Retrieve player stats
    /// @param playerAddress Address of the player
    /// @return coins Number of coins owned by the player
    /// @return lives Number of lives the player has
    /// @return rank Player's rank
    /// @return premiumCoins Number of premium coins owned by the player
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

contract GameManager is Ownable, AccessControl {
    address public immutable lifePurchaseContract;
    address public immutable previousGameContract;

    uint256 public constant RESET_TIME_UTC = 1 * 60 * 60; // 1 AM UTC in seconds

    bytes32 private constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 private constant PLANNER_ADMIN = keccak256("PLANNER_ADMIN");
    bytes32 private constant UPGRADE_CONTRACT_ADMIN =
        keccak256("UPGRADE_CONTRACT_ADMIN");

    uint256 public initLife = 10;
    uint256 public dailyClaimLife = 3;

    // ================================================================= STRUCT  ================================================================= //

    /// @dev defines a struct to hold player stats
    struct Player {
        uint256 coins;
        uint256 lives;
        uint256 rank;
        uint256 premiumCoins;
    }

    // ================================================================= MODIFIERS ================================================================= //

    modifier hasNotClaimedForToday(address player) {
        require(
            canSignAgain(player),
            "You can only claim once a day after 1 AM UTC."
        );
        _;
    }

    // ================================================================= MAPPINGS ================================================================= //

    /// @dev maps address to player
    mapping(address => Player) private players;

    ///@dev maps to track if a player is initialized
    mapping(address => bool) private initialized;

    /// @dev maps to track if a player has claimed for the day
    mapping(address => uint256) public lastClaimTime;

    // ================================================================= EVENTS ================================================================= //

    ///@notice Event for player data update
    event PlayerUpdated(
        address indexed player,
        uint256 coins,
        uint256 lives,
        uint256 rank,
        uint256 premiumCoins
    );

    ///@notice Event for player data migrations
    event PlayerSet(
        address indexed player,
        uint256 coins,
        uint256 lives,
        uint256 rank,
        uint256 premiumCoins
    );

    ///@notice Event for player initialization
    event PlayerInitialized(address indexed player);

    ///@notice Event for players upgrades
    event PlayersMigrated(address[] indexed accounts);

    ///@notice Event for players completed migration
    event PlayersSet(address[] indexed accounts);

    ///notice Event for claming balance
    event UpdatedBalanceOnClaim(address indexed player, uint256 coins);

    ///@notice Event for life purchase
    event LifePurchased(address indexed player, uint256 livesBought);

    ///@notice Event for life purchase
    event ClaimedDailyLife(
        address indexed player,
        uint256 lifeClaimed,
        uint256 claimedAt
    );

    /// @dev defines constructor for Game Manager
    /// @param _previousGameContract  previous contract
    /// @param _lifePurchaseContract  life purchase contract
    /// @param _delegate owner of the contract
    constructor(
        address _previousGameContract,
        address _lifePurchaseContract,
        address _delegate
    ) Ownable(_delegate) {
        _grantRole(DEFAULT_ADMIN_ROLE, _delegate);
        previousGameContract = _previousGameContract;
        lifePurchaseContract = _lifePurchaseContract;
    }

    // ================================================================= EXTERNAL METHODS ================================================================= //

    /// @notice Initialize player data (only if not already initialized)
    /// @param playerAddress address of the player
    function initializePlayer(
        address playerAddress
    ) external onlyRole(PLANNER_ADMIN) {
        require(!initialized[playerAddress], "Player already initialized");

        players[playerAddress] = Player({
            coins: 0,
            lives: initLife,
            rank: 0,
            premiumCoins: 0
        });

        initialized[playerAddress] = true; // Mark player as initialized

        emit PlayerInitialized(playerAddress);
    }

    ///@notice updates the state of the player
    /// @param playerAddress address of the player
    /// @param coinsEarned  coins from the player
    /// @param livesLost  lives lost from the player
    /// @param rankIncrease  rank of the player
    /// @param premiumCoinsEarned  premium coins from the player
    function updateStats(
        address playerAddress,
        uint256 coinsEarned,
        uint256 livesLost,
        uint256 rankIncrease,
        uint256 premiumCoinsEarned
    ) external onlyRole(PLANNER_ADMIN) {
        require(initialized[playerAddress], "Player not initialized");

        Player storage player = players[playerAddress];

        // Validate inputs
        require(livesLost <= player.lives, "Lives lost exceeds current lives");
        require(coinsEarned >= 0, "Coins earned cannot be negative");
        require(rankIncrease >= 0, "Rank increase cannot be negative");
        require(premiumCoinsEarned >= 0, "Premium coins cannot be negative");

        // Update stats
        player.coins += coinsEarned;
        player.lives -= livesLost; // Simplified since we already checked livesLost
        player.rank += rankIncrease;
        player.premiumCoins += premiumCoinsEarned;

        // Emit event
        emit PlayerUpdated(
            playerAddress,
            coinsEarned,
            livesLost,
            rankIncrease,
            premiumCoinsEarned
        );
    }

    ///@notice  Retrieve player stats
    /// @param playerAddress address of the player
    /// @return coins
    /// @return lives
    /// @return rank
    /// @return premiumCoins
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
        )
    {
        Player memory player = players[playerAddress];
        return (player.coins, player.lives, player.rank, player.premiumCoins);
    }

    /// @notice Buy lives using the buy life contract and update lives balance
    /// @param amount  amount to buy
    function buyLives(uint256 amount) external payable {
        require(amount > 0, "Amount must be greater than zero");
        require(
            lifePurchaseContract != address(0),
            "Life purchase contract not set"
        );

        // Call the external contract's buyLife function
        ILifePurchase lifePurchase = ILifePurchase(lifePurchaseContract);
        bool success = lifePurchase.buyLife{value: msg.value}(amount);
        require(success, "Life purchase failed");

        // Update the player's lives balance
        Player storage player = players[msg.sender];
        player.lives += amount;

        // Emit an event for the life purchase
        emit LifePurchased(msg.sender, amount);
    }

    function isPlayerInitialized(
        address playerAddress
    ) external view returns (bool) {
        return initialized[playerAddress];
    }

    function claimDailyLife(
        address player
    ) external hasNotClaimedForToday(player) onlyRole(PLANNER_ADMIN) {
        uint256 currentTime = getCurrentDay();
        lastClaimTime[player] = currentTime;

        Player storage thisPlayer = players[player];
        thisPlayer.lives += dailyClaimLife;

        emit ClaimedDailyLife(player, dailyClaimLife, currentTime);
    }

    function canSignAgain(address player) public view returns (bool) {
        uint256 currentDay = getCurrentDay();
        uint256 userLastClaimTime = lastClaimTime[player];
        return currentDay > userLastClaimTime;
    }

    function getLastClaimTime(address player) public view returns (uint256) {
        return lastClaimTime[player];
    }

    function getCurrentDay() public view returns (uint256) {
        uint256 currentTime = block.timestamp;

        // Modulo operation to get the time since midnight (UTC)
        uint256 timeSinceMidnight = currentTime % 1 days;

        // If it's after 1 AM UTC, today counts as the current day; otherwise, it's counted as the previous day
        if (timeSinceMidnight >= RESET_TIME_UTC) {
            return currentTime / 1 days;
        } else {
            return (currentTime / 1 days) - 1;
        }
    }

    // ================================================================= ADMIN ROLES ================================================================= //

    /// @notice THIS IS TO BE CALLED BY CLAIM CONTRACT ONLY
    /// @param _userAddress address of the player
    /// @param _amount amount claimed by the player
    function updateCoinBalance(
        address _userAddress,
        uint256 _amount
    ) external onlyRole(ADMIN_ROLE) {
        require(initialized[_userAddress], "Player not initialized");
        Player storage player = players[_userAddress];
        player.coins -= _amount;
        emit UpdatedBalanceOnClaim(_userAddress, _amount);
    }

    /// @notice updates default life value on int
    /// @param _initLife new life value
    function setInitLive(uint256 _initLife) external onlyRole(ADMIN_ROLE) {
        initLife = _initLife;
    }

    /// @notice updates daily claim life
    /// @param _dailyLife new life value
    function setDailyClaimLife(
        uint256 _dailyLife
    ) external onlyRole(ADMIN_ROLE) {
        dailyClaimLife = _dailyLife;
    }

    // ================================================================= UPGRADE_CONTRACT ADMIN ROLES ================================================================= //

    ///@dev upgrades contracts and migrates accounts
    /// @param _migratingAddresses former contract accounts

    function batchInit(
        address[] calldata _migratingAddresses
    ) external onlyRole(UPGRADE_CONTRACT_ADMIN) {
        for (uint i = 0; i < _migratingAddresses.length; i++) {
            require(
                !initialized[_migratingAddresses[i]],
                "Player already initialized"
            );
            players[_migratingAddresses[i]] = Player({
                coins: 0,
                lives: initLife,
                rank: 0,
                premiumCoins: 0
            });

            initialized[_migratingAddresses[i]] = true; // Mark player as initialized
            emit PlayerInitialized(_migratingAddresses[i]);
        }
        emit PlayersMigrated(_migratingAddresses);
    }

    function setMigratedAccounts(
        address[] calldata _migratingAddresses
    ) external onlyRole(UPGRADE_CONTRACT_ADMIN) {
        IGameManager gameManagerContract = IGameManager(previousGameContract);

        for (uint i = 0; i < _migratingAddresses.length; i++) {
            (
                uint256 _coins,
                uint256 _lives,
                uint256 _rank,
                uint256 _premiumCoins
            ) = gameManagerContract.getPlayerStats(_migratingAddresses[i]);

            require(
                initialized[_migratingAddresses[i]],
                "Player not initialized"
            );

            Player storage player = players[_migratingAddresses[i]];

            // Update stats
            player.coins = _coins;
            player.lives = _lives;
            player.rank = _rank;
            player.premiumCoins = _premiumCoins;

            emit PlayerSet(
                _migratingAddresses[i],
                _coins,
                _lives,
                _rank,
                _premiumCoins
            );
        }

        emit PlayersSet(_migratingAddresses);
    }

    // ================================================================= DEFAULT ADMIN ROLES ================================================================= //

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

    /// @notice grants role
    /// @param _address  address to be granted
    function grantUpgradeAdminRole(
        address _address
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(UPGRADE_CONTRACT_ADMIN, _address);
    }

    /// @notice revokes role
    /// @param _address  address to be revoked
    function revokeUpgradeAdminRole(
        address _address
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(UPGRADE_CONTRACT_ADMIN, _address);
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
