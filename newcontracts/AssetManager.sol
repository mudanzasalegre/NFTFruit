// SPDX-License-Identifier: PropietarioUnico
pragma solidity ^0.8.28;

// Importaciones necesarias
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./AssetToken.sol";
import "./Treasury.sol";

contract AssetManager is AccessControl {
    using Counters for Counters.Counter;

    // Definición de roles
    bytes32 public constant PRODUCER_ROLE = keccak256("PRODUCER_ROLE");

    // Tarifas
    uint256 public PRODUCER_ROLE_FEE = 0.1 ether;
    uint256 public CREATE_ASSET_FEE = 0.001 ether;

    // Contador para IDs únicos
    Counters.Counter private _assetIds;

    // Enumeración para tipos de activos
    enum AssetType {
        Tree,
        CoffeePlant,
        Rubber,
        Soy,
        Timber,
        Cocoa,
        Other
    }

    // Estructura para la ubicación
    struct Location {
        uint256 latitude;
        uint256 longitude;
        string country;
        string region;
        string municipality;
        string plot;
    }

    // Estructura del activo
    struct Asset {
        uint256 assetId;
        AssetType assetType;
        string variety;
        string class;
        Location location;
        address owner;
        bool eudrCompliant; // Cumplimiento con EUDR
    }

    // Mapeo de assetId a Asset
    mapping(uint256 => Asset) public assets;

    // Referencia al contrato AssetToken
    AssetToken public assetToken;

    // Referencia al contrato Treasury
    Treasury public treasury;

    // Eventos
    event AssetCreated(
        uint256 indexed assetId,
        AssetType assetType,
        string variety,
        address indexed owner
    );
    event AssetTransferred(
        uint256 indexed assetId,
        address indexed from,
        address indexed to
    );
    event AssetMetadataUpdated(uint256 indexed assetId, string metadataURI);
    event ProducerRolePurchased(address indexed account);
    event FeesUpdated(string feeType, uint256 newFee);
    event AssetEUDRComplianceUpdated(uint256 indexed assetId, bool compliant);

    // Constructor
    constructor(
        address admin,
        address assetTokenAddress,
        address treasuryAddress
    ) {
        // Configurar roles
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PRODUCER_ROLE, admin);

        // Establecer la referencia al contrato AssetToken
        assetToken = AssetToken(assetTokenAddress);

        // Establecer la referencia al contrato Treasury
        treasury = Treasury(treasuryAddress);
    }

    // Modificador para verificar el propietario del activo
    modifier onlyAssetOwner(uint256 _assetId) {
        require(
            assetToken.ownerOf(_assetId) == msg.sender,
            "No eres el propietario del activo"
        );
        _;
    }

    // Función para crear un nuevo activo
    function createAsset(
        AssetType _assetType,
        string memory _variety,
        string memory _class,
        Location memory _location,
        string memory _metadataURI
    ) public onlyRole(PRODUCER_ROLE) returns (uint256) {
        require(
            treasury.balanceOf(msg.sender) >= CREATE_ASSET_FEE,
            "No tienes suficientes fondos en la tesoreria"
        );

        // Cobrar la tarifa de creación de activo
        treasury.spendFunds(msg.sender, CREATE_ASSET_FEE);

        _assetIds.increment();
        uint256 newAssetId = _assetIds.current();

        // Crear el activo
        assets[newAssetId] = Asset({
            assetId: newAssetId,
            assetType: _assetType,
            variety: _variety,
            class: _class,
            location: _location,
            owner: msg.sender,
            eudrCompliant: false // Inicialmente no cumple hasta ser verificado
        });

        // Acuñar un NFT representando el activo utilizando AssetToken
        assetToken.mint(msg.sender, newAssetId, _metadataURI);

        // Emitir evento
        emit AssetCreated(newAssetId, _assetType, _variety, msg.sender);

        return newAssetId;
    }

    // Función para transferir un activo a otro propietario
    function transferAsset(address _to, uint256 _assetId)
        public
        onlyAssetOwner(_assetId)
    {
        require(_to != address(0), "La direccion no puede ser cero");

        // Transferir el NFT utilizando AssetToken
        assetToken.safeTransferFrom(msg.sender, _to, _assetId);

        // Actualizar el propietario en el mapeo
        assets[_assetId].owner = _to;

        // Emitir evento
        emit AssetTransferred(_assetId, msg.sender, _to);
    }

    // Función para actualizar metadatos del activo
    function updateAssetMetadata(uint256 _assetId, string memory _metadataURI)
        public
        onlyAssetOwner(_assetId)
    {
        // Actualizar el token URI utilizando AssetToken
        assetToken.setTokenURI(_assetId, _metadataURI);

        // Emitir evento
        emit AssetMetadataUpdated(_assetId, _metadataURI);
    }

    // Función para actualizar el cumplimiento con EUDR de un activo
    function updateEUDRCompliance(uint256 _assetId, bool _compliant)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        assets[_assetId].eudrCompliant = _compliant;
        emit AssetEUDRComplianceUpdated(_assetId, _compliant);
    }

    // Función para obtener información completa de un activo
    function getAsset(uint256 _assetId) public view returns (Asset memory) {
        require(assetToken.exists(_assetId), "El activo no existe");
        return assets[_assetId];
    }

    // Función para agregar un nuevo productor (solo administrador)
    function addProducer(address _account)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _grantRole(PRODUCER_ROLE, _account);
        treasury.addTreasurySpender(_account);
    }

    // Función para remover un productor (solo administrador)
    function removeProducer(address _account)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _revokeRole(PRODUCER_ROLE, _account);
        treasury.removeTreasurySpender(_account);
    }

    // Función para verificar si una dirección tiene el rol de productor
    function isProducer(address _account) external view returns (bool) {
        return hasRole(PRODUCER_ROLE, _account);
    }

    // Función para que un usuario pueda comprar el rol de productor
    function buyProducerRole() external {
        require(
            !hasRole(PRODUCER_ROLE, msg.sender),
            "Ya tienes el rol de productor"
        );
        require(
            treasury.balanceOf(msg.sender) >= PRODUCER_ROLE_FEE,
            "No tienes suficientes fondos en la tesoreria"
        );
        require(
            treasury.isTreasurySpender(msg.sender),
            "No tiene el rol TREASURY_SPENDER_ROLE"
        );

        // Transferir fondos del usuario a la tesorería
        treasury.spendFunds(msg.sender, PRODUCER_ROLE_FEE);

        // Otorgar el rol de productor
        _grantRole(PRODUCER_ROLE, msg.sender);

        // Emitir evento
        emit ProducerRolePurchased(msg.sender);
    }

    // Función para que el administrador pueda actualizar la tarifa del rol de productor
    function setProducerRoleFee(uint256 newFee)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        PRODUCER_ROLE_FEE = newFee;
        emit FeesUpdated("PRODUCER_ROLE_FEE", newFee);
    }

    // Función para que el administrador pueda actualizar la tarifa de creación de activo
    function setCreateAssetFee(uint256 newFee)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        CREATE_ASSET_FEE = newFee;
        emit FeesUpdated("CREATE_ASSET_FEE", newFee);
    }
}