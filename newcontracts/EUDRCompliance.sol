// SPDX-License-Identifier: PropietarioUnico
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract EUDRCompliance is AccessControl {
    using Counters for Counters.Counter;

    // Definición de roles
    bytes32 public constant INSPECTOR_ROLE = keccak256("INSPECTOR_ROLE");
    bytes32 public constant PRODUCER_ROLE = keccak256("PRODUCER_ROLE");

    // Contador para IDs únicos de verificaciones
    Counters.Counter private _verificationIds;

    // Estructura para una verificación de cumplimiento
    struct ComplianceVerification {
        uint256 verificationId;
        uint256 assetId;
        address inspector;
        bool isCompliant;
        string reportUri;
        uint256 timestamp;
    }

    // Mapeo de assetId a lista de verificaciones
    mapping(uint256 => ComplianceVerification[]) public complianceRecords;

    // Mapeo de productor a estado de cumplimiento
    mapping(address => bool) public producerComplianceStatus;

    // Eventos
    event ComplianceVerified(
        uint256 indexed verificationId,
        uint256 indexed assetId,
        address indexed inspector,
        bool isCompliant,
        string reportUri,
        uint256 timestamp
    );

    event ProducerComplianceUpdated(
        address indexed producer,
        bool isCompliant,
        uint256 timestamp
    );

    // Constructor
    constructor(address admin) {
        // Configurar roles
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    // Funciones para agregar y remover inspectores (solo administrador)
    function addInspector(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(INSPECTOR_ROLE, account);
    }

    function removeInspector(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(INSPECTOR_ROLE, account);
    }

    // Modificador para verificar si una dirección tiene el rol de productor
    modifier onlyProducer(address account) {
        require(hasRole(PRODUCER_ROLE, account), "EUDRCompliance: No eres productor autorizado");
        _;
    }

    // Funciones para agregar y remover productores (solo administrador)
    function addProducer(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(PRODUCER_ROLE, account);
        producerComplianceStatus[account] = false; // Iniciar con no cumplimiento
    }

    function removeProducer(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(PRODUCER_ROLE, account);
        delete producerComplianceStatus[account];
    }

    // Función para verificar cumplimiento de un activo
    function verifyCompliance(
        uint256 assetId,
        bool isCompliant,
        string memory reportUri
    ) external onlyRole(INSPECTOR_ROLE) {
        _verificationIds.increment();
        uint256 newVerificationId = _verificationIds.current();

        ComplianceVerification memory verification = ComplianceVerification({
            verificationId: newVerificationId,
            assetId: assetId,
            inspector: msg.sender,
            isCompliant: isCompliant,
            reportUri: reportUri,
            timestamp: block.timestamp
        });

        complianceRecords[assetId].push(verification);

        // Emitir evento de verificación de cumplimiento
        emit ComplianceVerified(
            newVerificationId,
            assetId,
            msg.sender,
            isCompliant,
            reportUri,
            block.timestamp
        );
    }

    // Función para actualizar el estado de cumplimiento de un productor
    function updateProducerCompliance(address producer, bool isCompliant) external onlyRole(INSPECTOR_ROLE) {
        require(hasRole(PRODUCER_ROLE, producer), "EUDRCompliance: Direccion no es un productor registrado");
        producerComplianceStatus[producer] = isCompliant;

        emit ProducerComplianceUpdated(producer, isCompliant, block.timestamp);
    }

    // Función para verificar si un productor cumple con la normativa
    function isProducerCompliant(address producer) public view returns (bool) {
        return producerComplianceStatus[producer];
    }

    // Función para obtener todas las verificaciones de un activo
    function getComplianceRecords(uint256 assetId) external view returns (ComplianceVerification[] memory) {
        return complianceRecords[assetId];
    }

    // Función para verificar si un activo cumple con la normativa
    function isAssetEUDRCompliant(uint256 assetId) public view returns (bool) {
        ComplianceVerification[] memory records = complianceRecords[assetId];
        if (records.length == 0) {
            return false; // Si no hay registros, el activo no es conforme
        }
        // Verificar el último registro para determinar el estado de cumplimiento
        return records[records.length - 1].isCompliant;
    }
}
