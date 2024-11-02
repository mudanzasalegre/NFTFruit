// SPDX-License-Identifier: PropietarioUnico
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./Variedad.sol";
import "../NFTFruit.sol";
import "../Treasury.sol";

contract MainTree is AccessControl, ReentrancyGuard {
    // Roles de acceso
    bytes32 public constant FARMER_ROLE = keccak256("FARMER_ROLE");
    NFTFruit private nftContract;
    Treasury private treasury;

    uint256 public plantingFee = 1 ether; // Tarifa de plantación
    uint256 public farmerRoleFee = 0.1 ether; // Tarifa para obtener el rol de agricultor

    // Estructuras de ubicaciones, producciones y tratamientos
    struct Location {
        uint256 latitude;
        uint256 longitude;
        uint8 pol;
        uint8 parcela;
        string plot;
        string municipality;
    }

    struct Production {
        uint40 date;
        uint256 amount;
        uint256 totalAmount;
    }

    struct Treatment {
        uint40 date;
        uint256 dose;
        string family;
        string desc;
        string composition;
        string numReg;
        string reason;
        string period;
    }

    struct Tree {
        uint256 plantedAt;
        Variedad.VariedadEnum variety;
        string class;
        Location location;
        uint256 numTreatments;
        uint256 numProductions;
        mapping(uint256 => Treatment) treatments;
        mapping(uint256 => Production) productions;
        mapping(uint256 => ProductionForSale) productionsForSale;
        address owner;
    }

    struct TreeForSale {
        uint256 price;
        bool isForSale;
    }

    struct ProductionForSale {
        uint256 amountAvailable;
        uint256 pricePerUnit;
        bool isForSale;
    }

    mapping(uint256 => Tree) private trees;
    mapping(uint256 => TreeForSale) public treesForSale;
    uint256 public numTrees; // Contador de árboles

    // Eventos
    event TreePlanted(uint256 indexed treeId, uint256 timestamp);
    event TreeRemoved(uint256 indexed treeId, address indexed owner);
    event TreatmentAdded(
        uint256 indexed treeId,
        uint256 treatmentId,
        Treatment treatment
    );
    event ProductionAdded(uint256 indexed treeId, uint256 productionId);
    event ProductionListedForSale(
        uint256 indexed treeId,
        uint256 indexed productionId,
        uint256 amount,
        uint256 pricePerUnit
    );
    event ProductionSold(
        uint256 indexed treeId,
        uint256 indexed productionId,
        address indexed buyer,
        uint256 amount,
        uint256 pricePerUnit
    );
    event TreeListedForSale(uint256 indexed treeId, uint256 price);
    event TreeUnlisted(uint256 indexed treeId);
    event TreeSold(
        uint256 indexed treeId,
        address indexed oldOwner,
        address indexed newOwner,
        uint256 price
    );
    event FarmerRoleRequested(address indexed account, uint256 feePaid);

    constructor(address _nftContractAddress, address _treasuryAddress) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        nftContract = NFTFruit(_nftContractAddress);
        treasury = Treasury(_treasuryAddress);
    }

    modifier onlyTreeOwner(uint256 _treeId) {
        require(
            trees[_treeId].owner == msg.sender,
            "No eres el duenno del arbol"
        );
        _;
    }

    // Función pública y pagadera para solicitar el rol de agricultor
    function requestFarmerRole() external payable {
        require(msg.value == farmerRoleFee, "Incorrect fee for farmer role");
        require(
            !hasRole(FARMER_ROLE, msg.sender),
            "You already have the farmer role"
        );

        treasury.deposit{value: msg.value}();

        _grantRole(FARMER_ROLE, msg.sender);

        emit FarmerRoleRequested(msg.sender, msg.value);
    }

    // Función para plantar un árbol y asignarle un NFT
    function plantTree(
        uint256 _latitude,
        uint256 _longitude,
        uint8 _pol,
        uint8 _parcela,
        string calldata _plot,
        string calldata _municipality,
        string calldata _class,
        uint8 _var
    ) external payable onlyRole(FARMER_ROLE) nonReentrant {
        require(msg.value == plantingFee, "Incorrect planting fee");

        treasury.deposit{value: msg.value}();

        uint256 treeId = ++numTrees;

        Tree storage newTree = trees[treeId];
        newTree.plantedAt = block.timestamp;
        newTree.variety = Variedad.VariedadEnum(_var);
        newTree.class = _class;
        newTree.location = Location(
            _latitude,
            _longitude,
            _pol,
            _parcela,
            _plot,
            _municipality
        );
        newTree.owner = msg.sender;

        nftContract.mintNFT(msg.sender, treeId);

        emit TreePlanted(treeId, block.timestamp);
    }

    // Función para añadir un tratamiento a un árbol
    function addTreatment(uint256 _treeId, Treatment calldata _treatment)
        external
        onlyRole(FARMER_ROLE)
        onlyTreeOwner(_treeId)
    {
        Tree storage tree = trees[_treeId];
        uint256 treatmentId = tree.numTreatments;

        tree.treatments[treatmentId] = _treatment;
        tree.numTreatments++;

        emit TreatmentAdded(_treeId, treatmentId, _treatment);
    }

    // Función para añadir una producción a un árbol
    function addProduction(uint256 _treeId, uint256 _amount)
        external
        onlyRole(FARMER_ROLE)
        onlyTreeOwner(_treeId)
    {
        Tree storage tree = trees[_treeId];
        uint256 productionId = tree.numProductions;

        Production memory newProduction = Production({
            date: uint40(block.timestamp),
            amount: _amount,
            totalAmount: _amount
        });

        tree.productions[productionId] = newProduction;
        tree.numProductions++;

        emit ProductionAdded(_treeId, productionId);
    }

    // Función para reducir la cantidad de una producción específica
    function reduceProduction(
        uint256 _treeId,
        uint256 _productionId,
        uint256 _amount
    ) external onlyRole(FARMER_ROLE) onlyTreeOwner(_treeId) {
        Production storage production = trees[_treeId].productions[
            _productionId
        ];
        require(
            production.amount >= _amount,
            "Cantidad insuficiente en la produccion"
        );

        production.amount -= _amount;
    }

    // Función para listar un árbol individual en venta
    function listTreeForSale(uint256 _treeId, uint256 _price)
        external
        onlyTreeOwner(_treeId)
    {
        require(_price > 0, "El precio debe ser mayor a cero");

        treesForSale[_treeId] = TreeForSale({price: _price, isForSale: true});

        emit TreeListedForSale(_treeId, _price);
    }

    // Función para listar varios árboles en venta
    function listTreesForSale(
        uint256[] calldata _treeIds,
        uint256[] calldata _prices
    ) external {
        require(
            _treeIds.length == _prices.length,
            "Longitudes de arrays no coinciden"
        );

        for (uint256 i = 0; i < _treeIds.length; i++) {
            uint256 treeId = _treeIds[i];
            uint256 price = _prices[i];

            require(
                trees[treeId].owner == msg.sender,
                "No eres el duenno de uno de los arboles"
            );
            require(price > 0, "El precio debe ser mayor a cero");

            treesForSale[treeId] = TreeForSale({price: price, isForSale: true});

            emit TreeListedForSale(treeId, price);
        }
    }

    // Función para comprar un árbol
    function buyTree(uint256 _treeId) external payable nonReentrant {
        TreeForSale storage treeForSale = treesForSale[_treeId];
        require(treeForSale.isForSale, "El arbol no esta en venta");
        require(msg.value == treeForSale.price, "Pago incorrecto");

        address oldOwner = trees[_treeId].owner;
        trees[_treeId].owner = msg.sender;

        // Transferencia de pago al dueño anterior
        payable(oldOwner).transfer(msg.value);

        // Quitar el árbol del listado de venta
        delete treesForSale[_treeId];

        emit TreeSold(_treeId, oldOwner, msg.sender, msg.value);
    }

    // Función para quitar un árbol de la venta
    function unlistTree(uint256 _treeId) external onlyTreeOwner(_treeId) {
        require(treesForSale[_treeId].isForSale, "El arbol no esta en venta");

        delete treesForSale[_treeId];

        emit TreeUnlisted(_treeId);
    }

    // Function to get a specific production of a tree
    function getProduction(uint256 _treeId, uint256 _productionId)
        external
        view
        returns (Production memory)
    {
        _validateTreeAndProductionIds(_treeId, _productionId);
        return trees[_treeId].productions[_productionId];
    }

    // Function to get all productions of a tree
    function getProductions(uint256 _treeId)
        external
        view
        returns (Production[] memory)
    {
        _validateTreeId(_treeId);

        Tree storage tree = trees[_treeId];
        Production[] memory productions = new Production[](tree.numProductions);
        for (uint256 i = 0; i < tree.numProductions; i++) {
            productions[i] = tree.productions[i];
        }
        return productions;
    }

    function getProductionForSale(uint256 _treeId, uint256 _productionId)
        external
        view
        returns (ProductionForSale memory)
    {
        Tree storage tree = trees[_treeId];
        ProductionForSale storage sale = tree.productionsForSale[_productionId];
        require(sale.isForSale, "Production is not for sale");
        return sale;
    }

     function reduceProductionForSale(
        uint256 _treeId,
        uint256 _productionId,
        uint256 _amount
    ) external onlyRole(FARMER_ROLE) onlyTreeOwner(_treeId) {
        Tree storage tree = trees[_treeId];
        ProductionForSale storage sale = tree.productionsForSale[_productionId];
        require(sale.isForSale, "Production is not for sale");
        require(sale.amountAvailable >= _amount, "Insufficient amount available");

        sale.amountAvailable -= _amount;

        if (sale.amountAvailable == 0) {
            sale.isForSale = false;
        }
    }

    // Helper function to validate tree ID
    function _validateTreeId(uint256 _treeId) internal view {
        require(_treeId > 0 && _treeId <= numTrees, "Tree ID is invalid");
    }

    // Helper function to validate tree and production IDs
    function _validateTreeAndProductionIds(
        uint256 _treeId,
        uint256 _productionId
    ) internal view {
        _validateTreeId(_treeId);
        require(
            _productionId < trees[_treeId].numProductions,
            "Production ID is invalid"
        );
    }

    // Funciones de consulta para obtener datos del árbol
    function getTreeLocation(uint256 _treeId)
        external
        view
        returns (Location memory)
    {
        return trees[_treeId].location;
    }

    function getTreeOwner(uint256 _treeId) external view returns (address) {
        return trees[_treeId].owner;
    }

    function getTreeTreatmentCount(uint256 _treeId)
        external
        view
        returns (uint256)
    {
        return trees[_treeId].numTreatments;
    }

    function getTreeTreatment(uint256 _treeId, uint256 _treatmentId)
        external
        view
        returns (Treatment memory)
    {
        return trees[_treeId].treatments[_treatmentId];
    }

    function getTreeProductionCount(uint256 _treeId)
        external
        view
        returns (uint256)
    {
        return trees[_treeId].numProductions;
    }

    function getTreeProduction(uint256 _treeId, uint256 _productionId)
        external
        view
        returns (Production memory)
    {
        return trees[_treeId].productions[_productionId];
    }

    function getTreeAge(uint256 _treeId) external view returns (uint256) {
        return (block.timestamp - trees[_treeId].plantedAt) / 1 days;
    }

    // Ajuste de tarifas
    function setPlantingFee(uint256 _newFee)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        plantingFee = _newFee;
    }

    function setFarmerRoleFee(uint256 _newFee)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        farmerRoleFee = _newFee;
    }
}
