// SPDX-License-Identifier: PropietarioUnico
pragma solidity ^0.8.28;

// Importaciones necesarias
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ProductionTokenERC20.sol";
import "./ProductionManager.sol";
import "./Treasury.sol";
import "./EUDRCompliance.sol";

contract Marketplace is AccessControl, ReentrancyGuard {
    // Definición de roles
    bytes32 public constant PRODUCER_ROLE = keccak256("PRODUCER_ROLE");
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");
    
    // Referencia al token ERC-20
    ProductionTokenERC20 public productionToken;

    // Referencia al contrato ProductionManager
    ProductionManager public productionManager;

    // Referencia al contrato Treasury
    Treasury public treasury;

    // Referencia al contrato EUDRCompliance
    EUDRCompliance public eudrCompliance;

    // Estructura para los listados en el marketplace
    struct Listing {
        uint256 listingId;
        address seller;
        uint256 assetId; // Activo vinculado a la producción
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
        uint256 assetId,
        uint256 amount,
        uint256 pricePerToken
    );
    event ListingCancelled(uint256 indexed listingId, address indexed seller);
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
        address treasuryAddress,
        address eudrComplianceAddress
    ) {
        // Configurar roles
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PRODUCER_ROLE, admin);
        _grantRole(DISTRIBUTOR_ROLE, admin);

        // Establecer referencias a contratos externos
        productionToken = ProductionTokenERC20(productionTokenAddress);
        productionManager = ProductionManager(productionManagerAddress);
        treasury = Treasury(treasuryAddress);
        eudrCompliance = EUDRCompliance(eudrComplianceAddress);
    }

    // Función para crear un listado en el marketplace
    function createListing(uint256 assetId, uint256 amount, uint256 pricePerToken)
        external
        nonReentrant
    {
        require(
            productionToken.balanceOf(msg.sender) >= amount,
            "No tienes suficientes tokens de produccion"
        );
        require(amount > 0, "La cantidad debe ser mayor a cero");
        require(pricePerToken > 0, "El precio por token debe ser mayor a cero");
        require(
            eudrCompliance.isAssetEUDRCompliant(assetId),
            "El activo no cumple con la normativa EUDR"
        );

        // Transferir los tokens al contrato del marketplace para custodia
        productionToken.transferFrom(msg.sender, address(this), amount);

        // Crear el nuevo listado
        _listingCounter++;
        listings[_listingCounter] = Listing({
            listingId: _listingCounter,
            seller: msg.sender,
            assetId: assetId,
            amount: amount,
            pricePerToken: pricePerToken,
            isActive: true
        });

        // Emitir evento
        emit ListingCreated(_listingCounter, msg.sender, assetId, amount, pricePerToken);
    }

    // Funcion para cancelar un listado
    function cancelListing(uint256 listingId) external nonReentrant {
        Listing storage listing = listings[listingId];
        require(listing.isActive, "El listado no esta activo");
        require(listing.seller == msg.sender, "No eres el vendedor");

        // Marcar el listado como inactivo
        listing.isActive = false;

        // Devolver los tokens al vendedor
        productionToken.transfer(listing.seller, listing.amount);

        // Emitir evento
        emit ListingCancelled(listingId, msg.sender);
    }

    // Funcion para comprar tokens de un listado
    function purchaseTokens(uint256 listingId, uint256 amount)
        external
        payable
        nonReentrant
    {
        Listing storage listing = listings[listingId];
        require(listing.isActive, "El listado no esta activo");
        require(amount > 0, "La cantidad debe ser mayor a cero");
        require(listing.amount >= amount, "Cantidad insuficiente en el listado");

        uint256 totalPrice = amount * listing.pricePerToken;
        require(msg.value == totalPrice, "El pago enviado es incorrecto");

        // Actualizar la cantidad restante en el listado
        listing.amount -= amount;

        // Si la cantidad llega a cero, desactivar el listado
        if (listing.amount == 0) {
            listing.isActive = false;
        }

        // Transferir los tokens al comprador
        productionToken.transfer(msg.sender, amount);

        // Transferir el pago al vendedor
        (bool success, ) = payable(listing.seller).call{value: msg.value}("");
        require(success, "Error al transferir el pago al vendedor");

        // Emitir evento
        emit TokensPurchased(listingId, msg.sender, amount, totalPrice);
    }

    // Funcion para agregar un distribuidor (solo administrador)
    function addDistributor(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(DISTRIBUTOR_ROLE, account);
    }

    // Función para remover un distribuidor (solo administrador)
    function removeDistributor(address account)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _revokeRole(DISTRIBUTOR_ROLE, account);
    }

    // Función para verificar si una dirección tiene el rol de distribuidor
    function isDistributor(address account) external view returns (bool) {
        return hasRole(DISTRIBUTOR_ROLE, account);
    }
}
