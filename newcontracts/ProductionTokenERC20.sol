// SPDX-License-Identifier: PropietarioUnico
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./EUDRCompliance.sol";

contract ProductionTokenERC20 is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant COMPLIANCE_VERIFIER_ROLE = keccak256("COMPLIANCE_VERIFIER_ROLE");

    // Referencia al contrato de cumplimiento EUDR
    EUDRCompliance public eudrCompliance;

    // Constructor
    constructor(address admin, address eudrComplianceAddress) ERC20("ProductionToken", "PTK") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(COMPLIANCE_VERIFIER_ROLE, admin);

        // Establecer la referencia al contrato EUDRCompliance
        eudrCompliance = EUDRCompliance(eudrComplianceAddress);
    }

    // Función para acuñar nuevos tokens
    function mint(address to, uint256 amount, uint256 assetId) public onlyRole(MINTER_ROLE) {
        // Verificar cumplimiento EUDR antes de acuñar tokens
        require(
            eudrCompliance.isAssetEUDRCompliant(assetId),
            "ProductionTokenERC20: El activo no cumple con la normativa EUDR"
        );
        _mint(to, amount);
    }

    // Función para quemar tokens
    function burn(address from, uint256 amount) public onlyRole(MINTER_ROLE) {
        _burn(from, amount);
    }

    // Función para agregar y remover verificadores de cumplimiento (solo administrador)
    function addComplianceVerifier(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(COMPLIANCE_VERIFIER_ROLE, account);
    }

    function removeComplianceVerifier(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(COMPLIANCE_VERIFIER_ROLE, account);
    }

    // Función para verificar y registrar el cumplimiento de un activo
    function verifyCompliance(
        uint256 assetId,
        bool isCompliant,
        string memory reportUri
    ) external onlyRole(COMPLIANCE_VERIFIER_ROLE) {
        eudrCompliance.verifyCompliance(assetId, isCompliant, reportUri);
    }
}
