// SPDX-License-Identifier: PropietarioUnico
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Treasury is AccessControl, ReentrancyGuard {
    bytes32 public constant TREASURY_ADMIN_ROLE = keccak256("TREASURY_ADMIN_ROLE");
    uint256 public treasuryBalance;

    event FundsDeposited(address indexed from, uint256 amount);
    event TreasuryClaimed(address indexed admin, uint256 amount);

    constructor() {
        _grantRole(TREASURY_ADMIN_ROLE, msg.sender);
    }

    // Función para depositar fondos en la tesorería
    function deposit() external payable {
        require(msg.value > 0, "El monto de deposito debe ser mayor a cero");
        treasuryBalance += msg.value;
        emit FundsDeposited(msg.sender, msg.value);
    }

    // Función para que el administrador reclame los fondos de la tesorería
    function claimTreasury() external nonReentrant onlyRole(TREASURY_ADMIN_ROLE) {
        uint256 amount = treasuryBalance;
        require(amount > 0, "No hay fondos en tesoreria para reclamar");

        treasuryBalance = 0;
        payable(msg.sender).transfer(amount);

        emit TreasuryClaimed(msg.sender, amount);
    }

    // Funciones para gestionar roles
    function addTreasuryAdmin(address account) external onlyRole(TREASURY_ADMIN_ROLE) {
        grantRole(TREASURY_ADMIN_ROLE, account);
    }

    function removeTreasuryAdmin(address account) external onlyRole(TREASURY_ADMIN_ROLE) {
        revokeRole(TREASURY_ADMIN_ROLE, account);
    }

    function isTreasuryAdmin(address account) external view returns (bool) {
        return hasRole(TREASURY_ADMIN_ROLE, account);
    }
}