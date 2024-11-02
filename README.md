# **Agricultura Sostenible en Blockchain: Un Sistema Innovador para el Futuro**

La agricultura es la columna vertebral de nuestra sociedad, proporcionando alimentos y recursos esenciales para la vida diaria. Sin embargo, enfrenta desafíos significativos como la trazabilidad, la transparencia y la eficiencia en la cadena de suministro. La tecnología blockchain ofrece soluciones innovadoras para estos problemas, y en este proyecto, exploramos un sistema que integra contratos inteligentes para transformar la agricultura sostenible.

## **Introducción al Sistema**

Imagina un mundo donde cada árbol plantado, cada fruto cosechado y cada tratamiento aplicado están registrados de forma segura y transparente en una cadena de bloques. Este sistema permite a agricultores, distribuidores y consumidores interactuar de manera eficiente, garantizando la trazabilidad desde el origen hasta el consumidor final.

El sistema se basa en varios contratos inteligentes escritos en Solidity, que juntos crean un ecosistema completo para la gestión agrícola:

- [`MainTree.sol`](./contracts/MainTree.sol): Gestiona la plantación y el mantenimiento de árboles.
- [`Distributor.sol`](./contracts/Distributor.sol): Permite la distribución y venta de la producción agrícola.
- [`Variedad.sol`](./contracts/Variedad.sol): Administra las variedades de cultivos y permite la participación comunitaria.
- [`Treasury.sol`](./contracts/Treasury.sol): Gestiona los fondos y las tarifas del sistema.
- [`NFTFruit.sol`](./contracts/NFTFruit.sol): Crea tokens no fungibles (NFTs) para representar árboles únicos.
- [`ProductionTokenERC20.sol`](./contracts/ProductionTokenERC20.sol): Gestiona tokens ERC20 que representan unidades de producción.

## **Cómo Funciona el Sistema**

### **1. Inicio como Agricultor**

El sistema es inclusivo, permitiendo que cualquier persona se convierta en agricultor. Para ello, el usuario solicita el rol de agricultor pagando una tarifa específica. Este rol les otorga permisos para interactuar con el contrato `MainTree.sol`, donde pueden plantar árboles y gestionar sus producciones.

**Proceso:**

- **Solicitud del Rol de Agricultor**: El usuario paga una tarifa mediante la función `requestFarmerRole()`. Una vez completado, obtiene el rol `FARMER_ROLE`.

  ```solidity
  function requestFarmerRole() external payable {
      require(msg.value == farmerRoleFee, "Incorrect fee for farmer role");
      require(!hasRole(FARMER_ROLE, msg.sender), "You already have the farmer role");

      treasury.deposit{value: msg.value}();

      _grantRole(FARMER_ROLE, msg.sender);

      emit FarmerRoleRequested(msg.sender, msg.value);
  }
  ```

- **Transparencia Financiera**: Las tarifas se depositan en el contrato `Treasury.sol`, asegurando una gestión financiera transparente.

### **2. Plantación y Gestión de Árboles**

Una vez que el usuario es agricultor, puede plantar árboles y gestionarlos.

**Características Clave:**

- **Plantación de Árboles**: Mediante la función `plantTree()`, el agricultor registra detalles como ubicación, variedad, clase y otros atributos del árbol.

  ```solidity
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
  ```

- **Creación de NFTs**: Cada árbol plantado genera un NFT único a través del contrato `NFTFruit.sol`, representando la propiedad y unicidad del árbol.
- **Registro de Tratamientos y Producciones**:
  - **Tratamientos**: Los agricultores pueden añadir tratamientos a sus árboles usando `addTreatment()`, registrando información como fecha, dosis y descripción.
  - **Producciones**: Con `addProduction()`, se registran las cosechas, incluyendo cantidades y fechas.

### **3. Listado y Venta de Producciones**

Los agricultores pueden decidir vender sus producciones. Para ello, utilizan funciones específicas para listar producciones y establecer precios.

**Proceso:**

- **Listar Producciones para la Venta**: Usando `listProductionForSale()`, el agricultor especifica la cantidad disponible y el precio por unidad.

  ```solidity
  function listProductionForSale(
      uint256 _treeId,
      uint256 _productionId,
      uint256 _amount,
      uint256 _pricePerUnit
  ) external onlyTreeOwner(_treeId) {
      Tree storage tree = trees[_treeId];
      Production storage production = tree.productions[_productionId];

      require(production.amount >= _amount, "Insufficient production amount");
      require(_pricePerUnit > 0, "Price per unit must be greater than zero");

      production.amount -= _amount;

      tree.productionsForSale[_productionId] = ProductionForSale({
          amountAvailable: _amount,
          pricePerUnit: _pricePerUnit,
          isForSale: true
      });

      emit ProductionListedForSale(
          _treeId,
          _productionId,
          _amount,
          _pricePerUnit
      );
  }
  ```

- **Interacción con Distribuidores**: Las producciones listadas están disponibles para que los distribuidores las adquieran a través del contrato `Distributor.sol`.

### **4. Rol de los Distribuidores**

Los distribuidores desempeñan un papel crucial al conectar a los agricultores con los consumidores finales.

**Funciones Principales:**

- **Adquisición de Producciones**: Mediante `acquireProduction()`, los distribuidores compran producciones listadas, pagando directamente a los agricultores.

  ```solidity
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
  ```

- **Gestión de Inventario**: Los distribuidores tienen un inventario personal donde se registran las producciones adquiridas.
- **Venta a Consumidores**:
  - **Listar para Venta**: Con `listProductionForSale()`, los distribuidores pueden establecer precios y cantidades para la venta al público.
  - **Venta Directa**: Los consumidores pueden comprar producciones usando `buyProduction()`, cerrando el ciclo de la cadena de suministro.

### **5. Participación Comunitaria y Gestión de Variedades**

El contrato `Variedad.sol` permite a la comunidad participar en decisiones importantes sobre las variedades de cultivos.

**Características:**

- **Añadir Nuevas Variedades**: Los administradores pueden introducir nuevas variedades de cultivos.
- **Propuestas de Actualizaciones**: Miembros de la comunidad con el rol `COMMUNITY_ROLE` pueden proponer cambios en los umbrales de producción.
- **Votaciones**: Si una propuesta alcanza un umbral de votos, se aprueba automáticamente, promoviendo la participación democrática.

### **6. Gestión Financiera y Transparencia**

La economía del sistema se gestiona a través del contrato `Treasury.sol`.

**Funciones Clave:**

- **Depósito de Tarifas**: Todas las tarifas recaudadas se depositan aquí, manteniendo un registro transparente.

  ```solidity
  function deposit() external payable {
      require(msg.value > 0, "El monto de deposito debe ser mayor a cero");
      treasuryBalance += msg.value;
      emit FundsDeposited(msg.sender, msg.value);
  }
  ```

- **Reclamación de Fondos**: Los administradores pueden retirar fondos para financiar operaciones o proyectos.

  ```solidity
  function claimTreasury() external nonReentrant onlyRole(TREASURY_ADMIN_ROLE) {
      uint256 amount = treasuryBalance;
      require(amount > 0, "No hay fondos en tesoreria para reclamar");

      treasuryBalance = 0;
      payable(msg.sender).transfer(amount);

      emit TreasuryClaimed(msg.sender, amount);
  }
  ```

## **Beneficios del Sistema**

### **Para los Agricultores**

- **Empoderamiento**: Control total sobre sus producciones y la capacidad de acceder a mercados más amplios sin intermediarios.
- **Trazabilidad**: Registro detallado de tratamientos y producciones, aumentando la confianza de los compradores.
- **Propiedad Digital**: Los árboles como NFTs permiten una representación digital de activos físicos.

### **Para los Distribuidores**

- **Acceso a Productos de Calidad**: Pueden adquirir producciones directamente de los agricultores, garantizando frescura y calidad.
- **Eficiencia Operativa**: Automatización de procesos de adquisición y venta, reduciendo costos y tiempos.
- **Transparencia**: Información clara sobre el origen y manejo de las producciones.

### **Para los Consumidores**

- **Confianza en el Origen**: Pueden verificar el origen de los productos que compran, asegurando prácticas sostenibles y éticas.
- **Calidad Garantizada**: Acceso a productos cuya cadena de suministro es transparente y está registrada en blockchain.

## **Casos de Uso Prácticos**

### **Agricultura Orgánica**

Los consumidores preocupados por productos orgánicos pueden verificar que los árboles no han recibido tratamientos químicos nocivos, gracias al registro detallado de tratamientos.

### **Comercio Justo**

Al eliminar intermediarios, los agricultores reciben una mayor parte de las ganancias, y los consumidores pueden estar seguros de que su dinero apoya directamente a los productores.

### **Gestión de Recursos**

Los agricultores pueden tomar decisiones informadas sobre tratamientos y producciones, basándose en registros históricos y datos transparentes.

## **Tecnologías Clave Utilizadas**

- **Blockchain y Contratos Inteligentes**: Proporcionan un registro inmutable y transparente de todas las transacciones y eventos.
- **Tokens ERC20 y NFTs**: Representan unidades de producción y árboles, respectivamente, facilitando la trazabilidad y propiedad digital.
- **Roles y Permisos**: Garantizan que solo usuarios autorizados puedan realizar ciertas acciones, aumentando la seguridad.

## **Desafíos y Soluciones**

### **Accesibilidad Tecnológica**

**Desafío**: No todos los agricultores pueden tener conocimientos técnicos para interactuar con contratos inteligentes.

**Solución**: Desarrollo de interfaces de usuario amigables y aplicaciones móviles que simplifiquen la interacción con el sistema.

### **Regulaciones y Cumplimiento Legal**

**Desafío**: Las leyes pueden variar según la región y afectar la implementación del sistema.

**Solución**: Adaptar el sistema a las regulaciones locales y colaborar con autoridades para garantizar el cumplimiento.

### **Escalabilidad**

**Desafío**: A medida que más usuarios se unen, la red puede enfrentar problemas de rendimiento.

**Solución**: Utilizar cadenas de bloques escalables o soluciones de capa 2 para manejar un mayor volumen de transacciones.

## **Futuras Mejoras y Expansiones**

- **Integración con IoT**: Incorporar dispositivos que recopilen datos en tiempo real sobre el estado de los cultivos.
- **Análisis de Datos**: Utilizar inteligencia artificial para analizar datos y ofrecer recomendaciones a los agricultores.
- **Expansión a Otros Sectores**: Adaptar el sistema para otras formas de agricultura o incluso industrias diferentes como la pesca o la ganadería.

## **Cómo Empezar con el Sistema**

### **Para Agricultores**

1. **Obtener el Rol de Agricultor**: Solicitar el rol pagando la tarifa correspondiente.
2. **Plantar Árboles**: Utilizar `plantTree()` para registrar nuevos árboles y obtener su NFT.
3. **Gestionar Producciones**: Registrar tratamientos y producciones, y listar producciones para la venta.

### **Para Distribuidores**

1. **Obtener el Rol de Distribuidor**: Ser autorizado por los administradores del sistema.
2. **Adquirir Producciones**: Comprar producciones listadas por agricultores mediante `acquireProduction()`.
3. **Vender a Consumidores**: Listar producciones adquiridas para la venta al público.

### **Para Consumidores**

1. **Explorar Producciones Disponibles**: Ver las producciones listadas por distribuidores.
2. **Comprar Productos**: Adquirir producciones directamente, con la confianza de la trazabilidad ofrecida por el sistema.

## **Conclusión**

La integración de la tecnología blockchain en la agricultura sostenible ofrece oportunidades sin precedentes para mejorar la transparencia, eficiencia y equidad en la cadena de suministro. Este sistema no solo beneficia a agricultores y distribuidores, sino que también empodera a los consumidores al proporcionarles información detallada sobre los productos que consumen.

Al utilizar contratos inteligentes, tokens y NFTs, se crea un ecosistema donde cada participante juega un papel crucial en la promoción de prácticas agrícolas sostenibles y éticas. Este enfoque innovador tiene el potencial de revolucionar la industria agrícola y sentar las bases para un futuro más justo y transparente.

## **Invitación a Participar**

Si te apasiona la agricultura sostenible y la tecnología blockchain, te invitamos a unirte a esta iniciativa. Ya seas agricultor, distribuidor, desarrollador o consumidor consciente, hay un lugar para ti en este ecosistema.

---

**Sobre el Autor**

Este proyecto fue desarrollado por un entusiasta de la tecnología y la agricultura sostenible, comprometido con la promoción de soluciones innovadoras que beneficien a la sociedad y al medio ambiente.

---

## **Licencia**

POR DEFINIR, AUNQUE MÍA TOTALMENTE.

## **Contacto**

- **Email**: mudanzasalegre@hotmail.com
- **GitHub**: [mudanzasalegre](https://github.com/mudanzasalegre)

---

*¡Gracias por tu interés en nuestro proyecto!*