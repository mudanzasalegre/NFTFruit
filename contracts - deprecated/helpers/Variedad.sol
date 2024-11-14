// SPDX-License-Identifier: PropietarioUnico
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract Variedad is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant COMMUNITY_ROLE = keccak256("COMMUNITY_ROLE");

    event VarietyAdded(uint256 indexed varietyId, string name);
    event ThresholdUpdateProposed(uint256 indexed varietyId, uint256 newThreshold, address proposer);
    event ThresholdUpdated(uint256 indexed varietyId, uint256 newThreshold);

    enum VariedadEnum { Naranjos, ClemenSats, Mandarinos, LimonPomelo }

    struct Variety {
        string name;
        uint256 threshold;
    }

    Variety[] public varieties;
    mapping(uint256 => uint256) public thresholdUpdateVotes;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    uint256 public votingThreshold = 3; // Example threshold for demonstration

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(COMMUNITY_ROLE, msg.sender);

        // Initial varieties
        addVariety("Naranjos", 500);
        addVariety("ClemenSats", 1000);
        addVariety("Mandarinos", 750);
        addVariety("LimonPomelo", 800);
    }

    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        _;
    }

    modifier onlyCommunity() {
        require(hasRole(COMMUNITY_ROLE, msg.sender), "Caller is not a community member");
        _;
    }

    function addVariety(string memory _name, uint256 _threshold) public onlyAdmin {
        varieties.push(Variety(_name, _threshold));
        emit VarietyAdded(varieties.length - 1, _name);
    }

    function proposeThresholdUpdate(uint256 _varietyId, uint256 _newThreshold) public onlyCommunity {
        require(_varietyId < varieties.length, "Invalid variety ID");
        require(!hasVoted[_varietyId][msg.sender], "Already voted for this update");

        thresholdUpdateVotes[_varietyId]++;
        hasVoted[_varietyId][msg.sender] = true;

        emit ThresholdUpdateProposed(_varietyId, _newThreshold, msg.sender);

        if (thresholdUpdateVotes[_varietyId] >= votingThreshold) {
            updateThreshold(_varietyId, _newThreshold);
        }
    }

    function updateThreshold(uint256 _varietyId, uint256 _newThreshold) internal {
        require(_varietyId < varieties.length, "Invalid variety ID");

        varieties[_varietyId].threshold = _newThreshold;
        resetVotes(_varietyId);

        emit ThresholdUpdated(_varietyId, _newThreshold);
    }

    function resetVotes(uint256 _varietyId) internal {
        thresholdUpdateVotes[_varietyId] = 0;
        for (uint256 i = 0; i < varieties.length; i++) {
            hasVoted[_varietyId][msg.sender] = false;
        }
    }

    function getVarieties() public view returns (Variety[] memory) {
        return varieties;
    }

    function getThreshold(uint256 _varietyId) public view returns (uint256) {
        require(_varietyId < varieties.length, "Invalid variety ID");
        return varieties[_varietyId].threshold;
    }

    function setVotingThreshold(uint256 _newThreshold) public onlyAdmin {
        votingThreshold = _newThreshold;
    }

    function addCommunityMember(address _account) public onlyAdmin {
        grantRole(COMMUNITY_ROLE, _account);
    }

    function removeCommunityMember(address _account) public onlyAdmin {
        revokeRole(COMMUNITY_ROLE, _account);
    }
}
