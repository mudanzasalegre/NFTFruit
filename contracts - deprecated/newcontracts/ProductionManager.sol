// SPDX-License-Identifier: PropietarioUnico
pragma solidity ^0.8.28;

// Importaciones necesarias
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./AssetManager.sol";
import "./AssetToken.sol";
import "./ProductionTokenERC20.sol";
import "./EUDRCompliance.sol";

contract ProductionManager is AccessControl {
    using Counters for Counters.Counter;

    // Definición de roles
    bytes32 public constant PRODUCER_ROLE = keccak256("PRODUCER_ROLE");

    // Referencia al contrato AssetManager
    AssetManager public assetManager;

    // Referencia al contrato AssetToken
    AssetToken public assetToken;

    // Referencia al token ERC-20
    ProductionTokenERC20 public productionToken;

    // Referencia al contrato de cumplimiento EUDR
    EUDRCompliance public eudrCompliance;

    // Contador para IDs únicos de producción
    Counters.Counter private _productionIds;

    // Estructura para una producción
    struct Production {
        uint256 productionId;
        uint256 assetId;
        uint256 quantity;
        string unit; // Unidad de medida (por ejemplo, kg, toneladas)
        uint256 timestamp;
        bool eudrCompliant; // Cumplimiento con la normativa EUDR
    }

    // Estructura para un tratamiento
    struct Treatment {
        uint256 treatmentId;
        uint256 assetId;
        string description;
        uint256 timestamp;
    }

    // Mapeo de productionId a Production
    mapping(uint256 => Production) public productions;

    // Mapeo de assetId a lista de productionIds
    mapping(uint256 => uint256[]) public assetProductions;

    // Contador para IDs únicos de tratamientos
    Counters.Counter private _treatmentIds;

    // Mapeo de treatmentId a Treatment
    mapping(uint256 => Treatment) public treatments;

    // Mapeo de assetId a lista de treatmentIds
    mapping(uint256 => uint256[]) public assetTreatments;

    // Eventos
    event ProductionRecorded(
        uint256 indexed productionId,
        uint256 indexed assetId,
        uint256 quantity,
        string unit,
        uint256 timestamp,
        bool eudrCompliant
    );

    event TreatmentApplied(
        uint256 indexed treatmentId,
        uint256 indexed assetId,
        string description,
        uint256 timestamp
    );

    // Constructor
    constructor(
        address admin,
        address assetManagerAddress,
        address assetTokenAddress,
        address productionTokenAddress,
        address eudrComplianceAddress
    ) {
        // Configurar roles
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PRODUCER_ROLE, admin);

        // Establecer referencias a contratos externos
        assetManager = AssetManager(assetManagerAddress);
        assetToken = AssetToken(assetTokenAddress);
        productionToken = ProductionTokenERC20(productionTokenAddress);
        eudrCompliance = EUDRCompliance(eudrComplianceAddress);
    }

    // Modificador para verificar el propietario del activo
    modifier onlyAssetOwner(uint256 _assetId) {
        require(
            assetToken.ownerOf(_assetId) == msg.sender,
            "No eres el propietario del activo"
        );
        _;
    }

    // Función para registrar una producción
    function recordProduction(
        uint256 _assetId,
        uint256 _quantity,
        string memory _unit
    ) public onlyAssetOwner(_assetId) returns (uint256) {
        _productionIds.increment();
        uint256 newProductionId = _productionIds.current();

        // Verificar el cumplimiento con la normativa EUDR
        bool isEUDRCompliant = eudrCompliance.isAssetEUDRCompliant(_assetId);

        // Registrar la producción
        productions[newProductionId] = Production({
            productionId: newProductionId,
            assetId: _assetId,
            quantity: _quantity,
            unit: _unit,
            timestamp: block.timestamp,
            eudrCompliant: isEUDRCompliant
        });

        // Asociar la producción al activo
        assetProductions[_assetId].push(newProductionId);

        // Acuñar tokens ERC-20 al propietario, incluyendo el assetId como parámetro
        productionToken.mint(msg.sender, _quantity, _assetId);

        // Emitir evento
        emit ProductionRecorded(
            newProductionId,
            _assetId,
            _quantity,
            _unit,
            block.timestamp,
            isEUDRCompliant
        );

        return newProductionId;
    }

    // Función para aplicar un tratamiento
    function applyTreatment(
        uint256 _assetId,
        string memory _description
    ) public onlyAssetOwner(_assetId) returns (uint256) {
        _treatmentIds.increment();
        uint256 newTreatmentId = _treatmentIds.current();

        // Registrar el tratamiento
        treatments[newTreatmentId] = Treatment({
            treatmentId: newTreatmentId,
            assetId: _assetId,
            description: _description,
            timestamp: block.timestamp
        });

        // Asociar el tratamiento al activo
        assetTreatments[_assetId].push(newTreatmentId);

        // Emitir evento
        emit TreatmentApplied(
            newTreatmentId,
            _assetId,
            _description,
            block.timestamp
        );

        return newTreatmentId;
    }

    // Función para obtener las producciones de un activo
    function getProductionsByAsset(
        uint256 _assetId
    ) public view returns (Production[] memory) {
        uint256[] memory productionIds = assetProductions[_assetId];
        Production[] memory assetProductionList = new Production[](
            productionIds.length
        );

        for (uint256 i = 0; i < productionIds.length; i++) {
            assetProductionList[i] = productions[productionIds[i]];
        }

        return assetProductionList;
    }

    // Función para obtener los tratamientos de un activo
    function getTreatmentsByAsset(
        uint256 _assetId
    ) public view returns (Treatment[] memory) {
        uint256[] memory treatmentIds = assetTreatments[_assetId];
        Treatment[] memory assetTreatmentList = new Treatment[](
            treatmentIds.length
        );

        for (uint256 i = 0; i < treatmentIds.length; i++) {
            assetTreatmentList[i] = treatments[treatmentIds[i]];
        }

        return assetTreatmentList;
    }
}
