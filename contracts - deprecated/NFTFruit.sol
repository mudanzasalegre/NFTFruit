// SPDX-License-Identifier: PropietarioUnico
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract NFTFruit is ERC721Enumerable, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    event NFTCreated(
        uint256 indexed treeId,
        uint256 indexed tokenId,
        address indexed owner
    );

    constructor(address _admin) ERC721("NFTFruit", "NFTF") {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(MINTER_ROLE, _admin);
    }

    function mintNFT(address to, uint256 tokenId)
        external
        onlyRole(MINTER_ROLE)
    {
        _safeMint(to, tokenId);

        emit NFTCreated(tokenId, tokenId, to);
    }

    function burn(uint256 tokenId) public {
        address owner = ownerOf(tokenId);
        require(
            msg.sender == owner ||
                getApproved(tokenId) == msg.sender ||
                isApprovedForAll(owner, msg.sender),
            "Caller is not owner nor approved"
        );
        _burn(tokenId);
    }

    // Override required due to multiple inheritance
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
