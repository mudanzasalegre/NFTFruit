// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Importaciones necesarias
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ProductionTokenERC20.sol";
import "./ProductionManager.sol";
import "./Treasury.sol";

contract Marketplace is AccessControl, ReentrancyGuard {
    // Definición de roles
    bytes32 public constant PRODUCER_ROLE = keccak256("PRODUCER_ROLE");
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");

    // Tarifas
    uint256 public DISTRIBUTOR_ROLE_FEE = 0.1 ether;

    // Referencia al token ERC-20
    ProductionTokenERC20 public productionToken;

    // Referencia al contrato ProductionManager
    ProductionManager public productionManager;

    // Referencia al contrato Treasury
    Treasury public treasury;

    // Estructura para los listados en el marketplace
    struct Listing {
        uint256 listingId;
        address seller;
        uint256 amount; // Cantidad de tokens en venta
        uint256 pricePerToken; // Precio en ETH por token
        bool isActive;
    }

    // Contador para IDs únicos de listados
    uint256 private _listingCounter;

    // Mapeo de listingId a Listing
    mapping(uint256 => Listing) public listings;

    // Eventos
    event ListingCreated(
        uint256 indexed listingId,
        address indexed seller,
        uint256 amount,
        uint256 pricePerToken
    );
    event ListingCancelled(uint256 indexed listingId, address indexed seller);
    event DistributorRolePurchased(address indexed account);
    event TokensPurchased(
        uint256 indexed listingId,
        address indexed buyer,
        uint256 amount,
        uint256 totalPrice
    );

    // Constructor
    constructor(
        address admin,
        address productionTokenAddress,
        address productionManagerAddress,
        address treasuryAddress
    ) {
        // Configurar roles
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PRODUCER_ROLE, admin);
        _grantRole(DISTRIBUTOR_ROLE, admin);

        // Establecer referencias a contratos externos
        productionToken = ProductionTokenERC20(productionTokenAddress);
        productionManager = ProductionManager(productionManagerAddress);
        treasury = Treasury(treasuryAddress);
    }

    // Modificador para verificar si el llamante es un distribuidor o consumidor
    modifier onlyBuyer() {
        require(
            hasRole(DISTRIBUTOR_ROLE, msg.sender) ||
                hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "No tienes permiso para comprar tokens"
        );
        _;
    }

    // Función para que un usuario pueda comprar el rol de productor
    function buyDistributorRole() external {
        require(
            !hasRole(DISTRIBUTOR_ROLE, msg.sender),
            "Ya tienes el rol de distribuidor"
        );
        require(
            treasury.balanceOf(msg.sender) >= DISTRIBUTOR_ROLE_FEE,
            "No tienes suficientes fondos en la tesoreria"
        );
        require(
            treasury.isTreasurySpender(msg.sender),
            "No tiene el rol TREASURY_SPENDER_ROLE"
        );

        // Transferir fondos del usuario a la tesorería
        treasury.spendFunds(msg.sender, DISTRIBUTOR_ROLE_FEE);

        // Otorgar el rol de productor
        _grantRole(DISTRIBUTOR_ROLE, msg.sender);

        // Emitir evento
        emit DistributorRolePurchased(msg.sender);
    }

    // Función para crear un listado en el marketplace
    function createListing(uint256 amount, uint256 pricePerToken)
        external
        nonReentrant
    {
        require(
            productionToken.balanceOf(msg.sender) >= amount,
            "No tienes suficientes tokens de produccion"
        );
        require(amount > 0, "La cantidad debe ser mayor a cero");
        require(pricePerToken > 0, "El precio por token debe ser mayor a cero");

        // Aprobacion de tokens
        require(
            productionToken.allowance(msg.sender, address(this)) >= amount,
            "Debes aprobar al marketplace para transferir tus tokens"
        );

        // Transferir los tokens al contrato del marketplace para custodia
        bool success = productionToken.transferFrom(
            msg.sender,
            address(this),
            amount
        );
        require(success, "Error al transferir tokens al marketplace");

        // Crear el nuevo listado
        _listingCounter++;
        listings[_listingCounter] = Listing({
            listingId: _listingCounter,
            seller: msg.sender,
            amount: amount,
            pricePerToken: pricePerToken,
            isActive: true
        });

        // Emitir evento
        emit ListingCreated(_listingCounter, msg.sender, amount, pricePerToken);
    }

    // Funcion para cancelar un listado
    function cancelListing(uint256 listingId) external nonReentrant {
        Listing storage listing = listings[listingId];
        require(listing.isActive, "El listado no esta activo");
        require(listing.seller == msg.sender, "No eres el vendedor");

        // Marcar el listado como inactivo
        listing.isActive = false;

        // Devolver los tokens al vendedor
        bool success = productionToken.transfer(listing.seller, listing.amount);
        require(success, "Error al devolver tokens al vendedor");

        // Emitir evento
        emit ListingCancelled(listingId, msg.sender);
    }

    // Funcion para comprar tokens de un listado
    function purchaseTokens(uint256 listingId, uint256 amount)
        external
        nonReentrant
    {
        Listing storage listing = listings[listingId];
        require(listing.isActive, "El listado no esta activo");
        require(amount > 0, "La cantidad debe ser mayor a cero");
        require(
            listing.amount >= amount,
            "Cantidad insuficiente en el listado"
        );

        uint256 totalPrice = amount * listing.pricePerToken;

        // Verificar que el comprador tiene fondos suficientes en la tesorería
        require(
            treasury.balanceOf(msg.sender) >= totalPrice,
            "Fondos insuficientes en la tesoreria"
        );

        // Transferir fondos del comprador al vendedor a través de la tesorería
        treasury.spendFunds(msg.sender, totalPrice);
        treasury.depositTo{value: 0}(listing.seller, totalPrice);

        // Actualizar la cantidad restante en el listado
        listing.amount -= amount;

        // Si la cantidad llega a cero, desactivar el listado
        if (listing.amount == 0) {
            listing.isActive = false;
        }

        // Transferir los tokens al comprador
        bool success = productionToken.transfer(msg.sender, amount);
        require(success, "Error al transferir tokens al comprador");

        // Emitir evento
        emit TokensPurchased(listingId, msg.sender, amount, totalPrice);
    }

    // Funcion para agregar un distribuidor (solo administrador)
    function addDistributor(address account)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _grantRole(DISTRIBUTOR_ROLE, account);
        treasury.addTreasurySpender(account);
    }

    // Funcion para remover un distribuidor (solo administrador)
    function removeDistributor(address account)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _revokeRole(DISTRIBUTOR_ROLE, account);
        treasury.removeTreasurySpender(account);
    }

    // Funcion para verificar si una direccion tiene el rol de distribuidor
    function isDistributor(address account) external view returns (bool) {
        return hasRole(DISTRIBUTOR_ROLE, account);
    }

    // Funcion para permitir depósitos directos a la tesorería del vendedor
    receive() external payable {
        // Esta función permite que el contrato reciba ETH, necesario para depositar en la tesorería
    }
}
