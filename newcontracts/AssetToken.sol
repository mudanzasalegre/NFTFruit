// SPDX-License-Identifier: PropietarioUnico
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol"; // Importar ERC721
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract AssetToken is ERC721, ERC721Burnable, AccessControl {
    // Definición de roles
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // Mapeo de token ID a token URI
    mapping(uint256 => string) private _tokenURIs;

    // Constructor
    constructor(address admin) ERC721("AssetToken", "ATK") {
        // Configurar roles
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
    }

    // Función para acuñar nuevos tokens
    function mint(
        address to,
        uint256 tokenId,
        string memory tokenURI_
    ) public onlyRole(MINTER_ROLE) {
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, tokenURI_);
    }

    // Función pública para establecer el token URI
    function setTokenURI(uint256 tokenId, string memory _tokenURI) public {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId) ||
                hasRole(MINTER_ROLE, _msgSender()),
            "AssetToken: No autorizado para actualizar el token URI"
        );
        _setTokenURI(tokenId, _tokenURI);
    }

    // Implementación de la función _exists
    function exists(uint256 tokenId) public view virtual returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    // Función interna personalizada para verificar si es aprobado o propietario
    function _isApprovedOrOwner(address spender, uint256 tokenId)
        internal
        view
        virtual
        returns (bool)
    {
        require(exists(tokenId), "AssetToken: consulta para token inexistente");
        address owner = ownerOf(tokenId);
        return (spender == owner ||
            getApproved(tokenId) == spender ||
            isApprovedForAll(owner, spender));
    }

    // Función interna para establecer el token URI
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal {
        require(exists(tokenId), "AssetToken: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }

    // Función para obtener el token URI
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(exists(tokenId), "AssetToken: URI query for nonexistent token");
        return _tokenURIs[tokenId];
    }

    // Override de supportsInterface para resolver la ambigüedad
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
