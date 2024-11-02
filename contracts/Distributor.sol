// SPDX-License-Identifier: PropietarioUnico
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./helpers/MainTree.sol";
import "./ProductionTokenERC20.sol";

contract Distributor is AccessControl, ReentrancyGuard {
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");

    MainTree private mainTreeContract;
    ProductionTokenERC20 private productionToken;

    // Estructura para almacenar la producción adquirida por el distribuidor
    struct AcquiredProduction {
        uint256 treeId;
        uint256 productionId;
        uint256 amount;
        uint256 pricePerUnit;
    }

    // Mapeo del inventario de cada distribuidor
    mapping(address => AcquiredProduction[]) private distributorInventory;

    // Mapeo de precios por unidad para la producción listada por distribuidores
    mapping(address => mapping(uint256 => uint256)) private distributorPrices;

    // Registro de ventas totales por distribuidor
    mapping(address => uint256) public totalSales;

    // Eventos para seguimiento de acciones
    event ProductionAcquired(
        uint256 indexed treeId,
        uint256 indexed productionId,
        address indexed distributor,
        uint256 amount,
        uint256 timestamp
    );
    event ProductionListedForSale(
        address indexed distributor,
        uint256 indexed inventoryIndex,
        uint256 amount,
        uint256 pricePerUnit,
        uint256 timestamp
    );
    event ProductionSold(
        address indexed distributor,
        uint256 indexed inventoryIndex,
        address indexed buyer,
        uint256 amount,
        uint256 pricePerUnit,
        uint256 timestamp
    );

    constructor(
        address _mainTreeAddress,
        address _productionTokenAddress,
        address _admin
    ) {
        mainTreeContract = MainTree(_mainTreeAddress);
        productionToken = ProductionTokenERC20(_productionTokenAddress);

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(DISTRIBUTOR_ROLE, _admin);
    }

    // Función para que un distribuidor adquiera producción de un árbol
    function acquireProduction(
        uint256 _treeId,
        uint256 _productionId,
        uint256 _amount
    ) external payable onlyRole(DISTRIBUTOR_ROLE) nonReentrant {
        // Obtener la información de la producción en venta
        MainTree.ProductionForSale memory sale = mainTreeContract
            .getProductionForSale(_treeId, _productionId);

        require(sale.isForSale, "Production is not for sale");
        require(sale.amountAvailable >= _amount, "Insufficient amount available");

        uint256 totalPrice = _amount * sale.pricePerUnit;
        require(msg.value == totalPrice, "Incorrect payment amount");

        // Transferir el pago al propietario del árbol
        address payable treeOwner = payable(mainTreeContract.getTreeOwner(_treeId));
        (bool sent, ) = treeOwner.call{value: msg.value}("");
        require(sent, "Failed to send Ether to tree owner");

        // Reducir la cantidad disponible en la producción en venta
        mainTreeContract.reduceProductionForSale(_treeId, _productionId, _amount);

        // Registrar la producción en el inventario del distribuidor
        distributorInventory[msg.sender].push(
            AcquiredProduction({
                treeId: _treeId,
                productionId: _productionId,
                amount: _amount,
                pricePerUnit: 0 // Inicialmente sin precio
            })
        );

        // Emitir evento de adquisición de producción
        emit ProductionAcquired(
            _treeId,
            _productionId,
            msg.sender,
            _amount,
            block.timestamp
        );

        // Mint tokens ERC20 al distribuidor
        productionToken.mint(msg.sender, _amount);
    }

    // Función para que el distribuidor liste su producción para la venta
    function listProductionForSale(
        uint256 _inventoryIndex,
        uint256 _pricePerUnit
    ) external onlyRole(DISTRIBUTOR_ROLE) {
        AcquiredProduction storage production = distributorInventory[msg.sender][
            _inventoryIndex
        ];

        require(production.amount > 0, "No production available to sell");
        require(_pricePerUnit > 0, "Price per unit must be greater than zero");

        // Actualizar el precio por unidad
        production.pricePerUnit = _pricePerUnit;

        // Registrar el precio en el mapping
        distributorPrices[msg.sender][_inventoryIndex] = _pricePerUnit;

        // Emitir evento de producción listada para la venta
        emit ProductionListedForSale(
            msg.sender,
            _inventoryIndex,
            production.amount,
            _pricePerUnit,
            block.timestamp
        );
    }

    // Función para que un comprador adquiera producción del distribuidor
    function buyProduction(
        address _distributor,
        uint256 _inventoryIndex,
        uint256 _amount
    ) external payable nonReentrant {
        AcquiredProduction storage production = distributorInventory[_distributor][
            _inventoryIndex
        ];

        require(production.amount >= _amount, "Insufficient production amount");

        uint256 pricePerUnit = production.pricePerUnit;
        require(pricePerUnit > 0, "Production not listed for sale");

        uint256 totalPrice = _amount * pricePerUnit;
        require(msg.value == totalPrice, "Incorrect payment amount");

        // Transferir el pago al distribuidor
        (bool sent, ) = payable(_distributor).call{value: msg.value}("");
        require(sent, "Failed to send Ether to distributor");

        // Reducir la cantidad disponible en el inventario del distribuidor
        production.amount -= _amount;

        // Registrar la venta en totalSales
        totalSales[_distributor] += _amount;

        // Transferir tokens ERC20 al comprador
        productionToken.transferFrom(_distributor, msg.sender, _amount);

        // Emitir evento de venta de producción
        emit ProductionSold(
            _distributor,
            _inventoryIndex,
            msg.sender,
            _amount,
            pricePerUnit,
            block.timestamp
        );
    }

    // Función para obtener el inventario de un distribuidor
    function getDistributorInventory(address _distributor)
        external
        view
        returns (AcquiredProduction[] memory)
    {
        return distributorInventory[_distributor];
    }

    // Función para agregar un nuevo distribuidor
    function addDistributor(address _account)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        grantRole(DISTRIBUTOR_ROLE, _account);
    }

    // Función para remover un distribuidor
    function removeDistributor(address _account)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        revokeRole(DISTRIBUTOR_ROLE, _account);
    }
}
