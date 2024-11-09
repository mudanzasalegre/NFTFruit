// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Treasury is AccessControl, ReentrancyGuard {
    bytes32 public constant TREASURY_ADMIN_ROLE = keccak256("TREASURY_ADMIN_ROLE");
    bytes32 public constant TREASURY_SPENDER_ROLE = keccak256("TREASURY_SPENDER_ROLE");

    // Mapeo de balances de usuarios
    mapping(address => uint256) private userBalances;

    // Variable para mantener el total de balances de usuarios
    uint256 private totalUserBalance;

    // Tarifa para adquirir el rol de gastador
    uint256 public SPENDER_ROLE_FEE = 0.001 ether;

    // Eventos
    event FundsDeposited(address indexed from, uint256 amount);
    event FundsWithdrawn(address indexed to, uint256 amount);
    event FundsSpent(address indexed from, uint256 amount, string reason);
    event TreasuryClaimed(address indexed admin, uint256 amount);
    event SpenderRolePurchased(address indexed account);
    event SpenderRoleFeeUpdated(uint256 newFee);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(TREASURY_ADMIN_ROLE, admin);
    }

    // Función para depositar fondos en la tesorería
    function deposit() external payable {
        require(msg.value > 0, "El monto de deposito debe ser mayor a cero");
        userBalances[msg.sender] += msg.value;
        totalUserBalance += msg.value; // Actualizar el total de balances de usuarios
        emit FundsDeposited(msg.sender, msg.value);
    }

    // Función para que el usuario retire sus fondos
    function withdraw(uint256 amount) external nonReentrant {
        require(userBalances[msg.sender] >= amount, "Fondos insuficientes");
        userBalances[msg.sender] -= amount;
        totalUserBalance -= amount; // Actualizar el total de balances de usuarios
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transferencia fallida");
        emit FundsWithdrawn(msg.sender, amount);
    }

    // Función para que contratos autorizados gasten fondos del usuario
    function spendFunds(address user, uint256 amount) external onlyRole(TREASURY_SPENDER_ROLE) {
        require(userBalances[user] >= amount, "Fondos insuficientes del usuario");
        userBalances[user] -= amount;
        totalUserBalance -= amount; // Actualizar el total de balances de usuarios
        emit FundsSpent(user, amount, "Fondos gastados por contrato autorizado");
    }

    // Función para obtener el balance de un usuario
    function balanceOf(address user) external view returns (uint256) {
        return userBalances[user];
    }

    // Función para obtener el total de balances de usuarios
    function totalUserBalances() public view returns (uint256) {
        return totalUserBalance;
    }

    // Función para que el administrador reclame los fondos de la tesorería
    function claimTreasury(address payable _to) external nonReentrant onlyRole(TREASURY_ADMIN_ROLE) {
        require(_to != address(0), "La direccion no puede ser cero");
        uint256 amount = address(this).balance - totalUserBalance;
        require(amount > 0, "No hay fondos en tesoreria para reclamar");

        (bool success, ) = _to.call{value: amount}("");
        require(success, "Transferencia fallida");

        emit TreasuryClaimed(_to, amount);
    }

    // Funciones para gestionar roles de administrador
    function addTreasuryAdmin(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(TREASURY_ADMIN_ROLE, account);
    }

    function removeTreasuryAdmin(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(TREASURY_ADMIN_ROLE, account);
    }

    function isTreasuryAdmin(address account) external view returns (bool) {
        return hasRole(TREASURY_ADMIN_ROLE, account);
    }

    // Funciones para gestionar el rol de gastador
    function addTreasurySpender(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(TREASURY_SPENDER_ROLE, account);
    }

    function removeTreasurySpender(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(TREASURY_SPENDER_ROLE, account);
    }

    function isTreasurySpender(address account) external view returns (bool) {
        return hasRole(TREASURY_SPENDER_ROLE, account);
    }

    // Función para que un usuario pueda comprar el rol de gastador
    function claimTreasurySpender() external payable {
        require(msg.value == SPENDER_ROLE_FEE, "Debe enviar exactamente el SPENDER_ROLE_FEE");
        require(!hasRole(TREASURY_SPENDER_ROLE, msg.sender), "Ya tienes el rol de gastador");

        // Los fondos recibidos se agregan a la tesorería pero no al balance del usuario
        emit FundsDeposited(msg.sender, msg.value);

        // Otorgar el rol de gastador al usuario
        _grantRole(TREASURY_SPENDER_ROLE, msg.sender);

        // Emitir evento
        emit SpenderRolePurchased(msg.sender);
    }

    // Función para que el administrador pueda actualizar la tarifa del rol de gastador
    function setSpenderRoleFee(uint256 newFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        SPENDER_ROLE_FEE = newFee;
        emit SpenderRoleFeeUpdated(newFee);
    }
}
