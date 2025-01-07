// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.22;

import {ERC4671} from "./external/ERC4671/contracts/ERC4671.sol";
import {Ownable} from "./external/openzeppline/Ownable.sol";
import {AccessControl} from "./external/openzeppline/AccessControl.sol";

/**
 * @title Soulbound ERC721 contract for Raccoon Names Service.
 * @dev This contract implements an ERC721 token that is soulbound, meaning it cannot be transferred once minted.
 */

contract RaccoonNames is ERC4671, AccessControl, Ownable {
    bytes32 internal constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 internal constant PLANNER_ADMIN = keccak256("PLANNER_ADMIN");

    uint16 internal currentId = 0;
    // uint16 public constant MAX_NAMES = 4000;

    ///@notice Maximum length for usernames (excluding ".raccoon")
    uint8 public constant MAX_LENGTH = 18;

    uint16 public nameCount = 0;

    mapping(string => bool) public nameExists;
    mapping(address => string) public addressToName;
    mapping(address => uint16) public addressToTokenId;
    event RaccoonNameRegistered(
        address indexed account,
        string name,
        uint256 tokenId
    );

    /**
     * @dev Grants `DEFAULT_ADMIN_ROLE` to the specified address.
     * @param _owner Address that will be granted the DEFAULT_ADMIN_ROLE role.
     */
    constructor(
        address _owner
    ) ERC4671("Raccoon Names Service", "RNS") Ownable(_owner) {
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
    }

    function claimName(
        string calldata _name,
        address _owner
    ) external onlyRole(PLANNER_ADMIN) {
        ///@notice Ensure the name length is within the allowed limit (excluding ".raccoon")
        require(
            bytes(_name).length > 0 && bytes(_name).length <= MAX_LENGTH,
            "Name length must be between 1 and 18 characters."
        );

        ///@notice Append ".raccoon" to the provided name
        string memory fullName = string(abi.encodePacked(_name, ".raccoon"));

        require(!nameExists[fullName], "Name already exists.");

        ///@notice Ensure the address has not registered a name yet
        require(
            bytes(addressToName[_owner]).length == 0,
            "Address has already registered a name."
        );

        currentId++;
        uint256 newTokenId = currentId;
        _mint(_owner);

        ///@notice Register the full name
        nameExists[fullName] = true;
        addressToName[_owner] = fullName;
        addressToTokenId[_owner] = uint16(emittedCount());

        ///@notice Increment the name counter
        nameCount++;

        ///@notice Emit the event
        emit RaccoonNameRegistered(_owner, fullName, newTokenId);
    }

    function totalSupply() public view returns (uint16 supply) {
        supply = currentId;
    }

    ///@notice Function to retrieve the name registered by an address
    function getName(address _user) public view returns (string memory) {
        return addressToName[_user];
    }

    ///@notice Function to retrieve the token ID registered by an address
    function getTokenId(address _user) public view returns (uint16) {
        return addressToTokenId[_user];
    }

    function ifIsAvailable(string calldata _name) public view returns (bool) {
        string memory fullName = string(abi.encodePacked(_name, ".raccoon"));
        return nameExists[fullName];
    }

    function grantMinterRole(
        address _account
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(ADMIN_ROLE, _account);
    }

    function revokeMinterAdminRole(
        address _account
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(ADMIN_ROLE, _account);
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

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC4671, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
