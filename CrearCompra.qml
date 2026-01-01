import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15

// 🚀 CrearCompra.qml - Sistema FIFO 2.0 con Cálculo Automático de Precios
Item {
    id: crearCompraRoot
    
    // Propiedades de comunicación
    property var inventarioModel: parent.inventarioModel || null
    property var ventaModel: null
    property var compraModel: null
    
    // PROPIEDADES PARA EDICIÓN DE COMPRA
    property bool modoEdicion: compraModel ? compraModel.modo_edicion : false
    property int compraIdEdicion: compraModel ? compraModel.compra_id_edicion : 0
    property var datosOriginales: compraModel ? compraModel.datos_originales : {}
    
    // PROPIEDAD: Índice del producto que se está editando
    property int productoEditandoIndex: -1
    
    // Señales para comunicación
    signal compraCompletada()
    signal cancelarCompra()
    
    // SISTEMA DE MÉTRICAS COMPACTO
    readonly property real scaleFactor: Math.min(width / 1400, height / 900)
    readonly property real baseUnit: 4
    readonly property real fontBaseSize: Math.max(13, height / 65)
    
    // Tamaños de fuente consistentes
    readonly property real fontSmall: fontBaseSize * 0.85
    readonly property real fontMedium: fontBaseSize
    readonly property real fontLarge: fontBaseSize * 1.2
    readonly property real fontXLarge: fontBaseSize * 1.4
    readonly property real fontHeader: fontBaseSize * 1.6
    
    // Espaciados compactos
    readonly property real spacing4: baseUnit
    readonly property real spacing8: baseUnit * 2
    readonly property real spacing12: baseUnit * 3
    readonly property real spacing16: baseUnit * 4
    readonly property real spacing20: baseUnit * 5
    readonly property real spacing24: baseUnit * 6
    
    // Alturas estándar
    readonly property real inputHeight: 32
    readonly property real buttonHeight: 36
    readonly property real headerHeight: 70

    // Radios uniformes
    readonly property real radiusSmall: 6
    readonly property real radiusMedium: 8
    readonly property real radiusLarge: 12

    // COLORES MINIMALISTAS
    property color primaryColor: modoEdicion ? "#2C3E50" : "#273746"
    property color accentColor: modoEdicion ? "#3498DB" : "#3498db"
    property color successColor: "#27ae60"
    property color warningColor: "#f39c12"
    property color dangerColor: "#e74c3c"
    property color blueColor: "#3498db"
    property color whiteColor: "#ffffff"
    property color textColor: "#2c3e50"
    property color darkGrayColor: "#7f8c8d"
    property color lightGrayColor: "#bdc3c7"
    property color editModeColor: "#34495E"

    // Estados de la interfaz
    property bool showSuccessMessage: false
    property string successMessage: ""
    property bool showProductDropdown: false
    property bool showComparisonPanel: false
    property bool mostrarAyuda: false  // 🆕 Oculto por defecto para ahorrar espacio
    property bool procesandoCompra: false
    property int contadorClics: 0 
    
    // Datos para compra
    property string newPurchaseProvider: ""
    property string newPurchaseUser: "Dr. Admin"
    property string newPurchaseDate: ""
    property string newPurchaseId: ""
    property real newPurchaseTotal: 0.0
    
    // 🚀 CAMPOS NUEVOS - FLUJO INTUITIVO
    property string inputProductCode: ""
    property string inputProductName: ""
    property int inputProductId: 0
    property int inputCantidad: 0                      // Cantidad de unidades
    property real inputPrecioTotalCompra: 0.0          // Precio total pagado
    property real inputPrecioUnitarioCalculado: 0.0    // Auto-calculado
    property real inputMargenPorcentaje: 100.0         // 100% por defecto
    property real inputPrecioVentaSugerido: 0.0        // Auto-calculado
    property real inputPrecioVentaFinal: 0.0           // Usuario puede modificar
    property real inputGananciaUnitaria: 0.0           // Auto-calculado
    property real inputGananciaTotal: 0.0              // Auto-calculado
    property real inputMargenRealPorcentaje: 0.0       // Margen calculado después de redondeo
    property string inputExpiryDate: ""
    property bool inputNoExpiry: false
    property bool isNewProduct: true
    property bool esPrimeraCompra: false
    property bool precioModificadoManualmente: false   // Flag para saber si usuario editó precio
    
    // Lista temporal de productos
    ListModel {
        id: temporaryProductsModel
    }
    
    // Modelo para resultados de búsqueda
    ListModel {
        id: productSearchResultsModel
    }
    
    // PROPIEDADES PARA PROVEEDORES
    property var providerNames: ["Seleccionar proveedor..."]

    // CONEXIONES PARA EDICIÓN
    Connections {
        target: compraModel
        
        function onModoEdicionChanged() {
            console.log("📝 Modo edición cambiado:", compraModel.modo_edicion)
            if (compraModel.modo_edicion) {
                cargarDatosEdicion()
            }
        }
        
        function onCompraActualizada(compraId, total) {
            console.log("✅ Compra actualizada:", compraId, "Total:", total)
            showSuccess(`Compra #${compraId} actualizada: Bs${total.toFixed(2)}`)
            Qt.callLater(function() {
                compraCompletada()
            })
        }
        
        function onProveedoresChanged() {
            updateProviderNames()
        }
        
        function onOperacionExitosa(mensaje) {
            if (mensaje.includes("proveedores") || mensaje.includes("actualizada")) {
                Qt.callLater(updateProviderNames)
            }
        }
    }
    // Timer para ocultar mensaje de éxito
    Timer {
        id: successTimer
        interval: 3000
        onTriggered: showSuccessMessage = false
    }

    // ✅ Timer para resetear botón después de compra (AHORA TAMBIÉN RESETEA CONTADOR)
    Timer {
        id: resetButtonTimer
        interval: 2000
        onTriggered: {
            completarCompraButton.text = modoEdicion ? "💾 Guardar Cambios" : "📦 Completar Compra"
            procesandoCompra = false
            // ✅ RE-CALCULAR enabled del botón
            completarCompraButton.enabled = Qt.binding(function() {
                return !procesandoCompra &&
                    (providerCombo ? providerCombo.currentIndex > 0 : false) && 
                    (compraModel ? compraModel.items_en_compra > 0 : false) &&
                    productoEditandoIndex < 0
            })
            
            // ✅ **CORRECCIÓN IMPORTANTE**: RESETEAR CONTADOR SOLO DESPUÉS DE COMPLETAR TODO EL PROCESO
            contadorClics = 0
            console.log("🔄 Contador de clics reseteado (compra completada)")
        }
    }
    // ============================================================================
    // FUNCIONES DE NEGOCIO MEJORADAS + CÁLCULOS AUTOMÁTICOS
    // ============================================================================
    
    // 🚀 NUEVA FUNCIÓN: Calcular todos los precios automáticamente
    function calcularPreciosAutomaticos() {
        if (inputCantidad <= 0 || inputPrecioTotalCompra <= 0) {
            // Reset
            inputPrecioUnitarioCalculado = 0
            inputPrecioVentaSugerido = 0
            if (!precioModificadoManualmente) {
                inputPrecioVentaFinal = 0
            }
            inputGananciaUnitaria = 0
            inputGananciaTotal = 0
            inputMargenRealPorcentaje = 0
            return
        }
        
        // 1. Calcular precio unitario de compra
        inputPrecioUnitarioCalculado = inputPrecioTotalCompra / inputCantidad
        
        // 2. Calcular precio de venta con margen (100% por defecto)
        var factor = 1 + (inputMargenPorcentaje / 100)
        var precioSugerido = inputPrecioUnitarioCalculado * factor
        
        // 3. Redondear a 0.05 más cercano (Bs0.10, Bs0.15, Bs0.20, Bs0.25...)
        inputPrecioVentaSugerido = Math.ceil(precioSugerido * 20) / 20
        
        // 4. Si usuario no ha modificado precio, usar el sugerido
        if (!precioModificadoManualmente) {
            inputPrecioVentaFinal = inputPrecioVentaSugerido
        }
        
        // 5. Calcular ganancia
        inputGananciaUnitaria = inputPrecioVentaFinal - inputPrecioUnitarioCalculado
        inputGananciaTotal = inputGananciaUnitaria * inputCantidad
        
        // 6. Calcular margen real (puede diferir del sugerido por redondeo)
        if (inputPrecioUnitarioCalculado > 0) {
            inputMargenRealPorcentaje = (inputGananciaUnitaria / inputPrecioUnitarioCalculado) * 100
        }
        
        console.log("💰 Cálculos:", 
                    "Unit:", inputPrecioUnitarioCalculado.toFixed(2),
                    "Venta:", inputPrecioVentaFinal.toFixed(2),
                    "Margen:", inputMargenRealPorcentaje.toFixed(1) + "%")
    }
    
    function cargarDatosEdicion() {
        if (!modoEdicion || !compraModel) return
        
        console.log("📋 Cargando datos para edición - Compra:", compraIdEdicion)
        
        // Configurar ID y fecha
        newPurchaseId = `C${String(compraIdEdicion).padStart(3, '0')}`
        
        // Configurar proveedor
        var datosOrig = datosOriginales
        if (datosOrig && datosOrig.proveedor) {
            newPurchaseProvider = datosOrig.proveedor
            
            for (var i = 0; i < providerNames.length; i++) {
                if (providerNames[i] === datosOrig.proveedor) {
                    if (providerCombo) {
                        providerCombo.currentIndex = i
                    }
                    break
                }
            }
        }
        
        if (datosOrig && datosOrig.fecha) {
            try {
                var fechaStr = datosOrig.fecha.toString()
                if (fechaStr && fechaStr.length > 0) {
                    newPurchaseDate = fechaStr
                }
            } catch (e) {
                console.log("⚠️ Error al convertir fecha:", e)
                var fechaActual = new Date()
                var dia = fechaActual.getDate().toString().padStart(2, '0')
                var mes = (fechaActual.getMonth() + 1).toString().padStart(2, '0')
                var año = fechaActual.getFullYear()
                newPurchaseDate = dia + "/" + mes + "/" + año
            }
        }
        
        updatePurchaseTotal()
        console.log("✅ Datos de edición cargados")
        showSuccess("Compra cargada para edición")
    }
    
    function updateProviderNames() {
        var names = ["Seleccionar proveedor..."]
        
        if (compraModel && compraModel.proveedores) {
            var proveedores = compraModel.proveedores
            
            for (var i = 0; i < proveedores.length; i++) {
                var provider = proveedores[i]
                if (provider && (provider.Nombre || provider.nombre)) {
                    var nombreProveedor = provider.Nombre || provider.nombre
                    names.push(nombreProveedor)
                }
            }
        }
        
        providerNames = names
    }
    
    function updatePurchaseTotal() {
        var total = 0.0
        if (compraModel && compraModel.items_compra) {
            var items = compraModel.items_compra
            for (var i = 0; i < items.length; i++) {
                var item = items[i]
                total += parseFloat(item.subtotal || 0)
            }
        }
        newPurchaseTotal = total
    }

    function buscarProductosExistentes(texto) {
        productSearchResultsModel.clear()
        
        if (!inventarioModel || texto.length < 2) {
            showProductDropdown = false
            return
        }
        
        var textoBusqueda = texto.toLowerCase()
        
        if (inventarioModel) {
            inventarioModel.buscar_productos(textoBusqueda)
        }
        
        Qt.callLater(function() {
            var resultados = inventarioModel.search_results || []
            
            if (resultados.length > 0) {
                for (var i = 0; i < resultados.length; i++) {
                    var producto = resultados[i]
                    
                    productSearchResultsModel.append({
                        id: producto.id || producto.Id || 0,
                        codigo: producto.Codigo || producto.codigo || "",
                        nombre: producto.Nombre || producto.nombre || "",
                        precioCompraBase: producto.Precio_compra || producto.precioCompraBase || 0,
                        precioVentaBase: producto.Precio_venta || producto.precioVentaBase || 0,
                        unidadMedida: producto.Unidad_Medida || producto.unidadMedida || "Unidades"
                    })
                }
                
                showProductDropdown = true
                isNewProduct = false
            } else {
                showProductDropdown = false
                isNewProduct = true
                inputProductName = ""
            }
        })
    }

    // Seleccionar producto existente con detección de primera compra
    function seleccionarProductoExistente(productoId, codigo, nombre) {
        inputProductCode = codigo
        inputProductName = nombre
        inputProductId = productoId
        isNewProduct = false
        
        showProductDropdown = false
        productCodeField.text = nombre
        
        // Obtener datos de precio del producto
        if (compraModel && productoId > 0) {
            var datosProducto = compraModel.obtener_datos_precio_producto(productoId)
            
            console.log("📊 Datos producto:", JSON.stringify(datosProducto))
            
            if (datosProducto) {
                esPrimeraCompra = datosProducto.es_primera || false
                
                // ✅ NUEVO: Resetear flag cuando se selecciona producto
                precioModificadoManualmente = false
                
                if (esPrimeraCompra) {
                    console.log("🆕 Primera compra de producto:", nombre)
                    showSuccess("⚠️ Primera compra: Define precio de venta (100% margen sugerido)")
                } else {
                    console.log("♻️ Compra subsiguiente - Precio venta actual: Bs" + (datosProducto.Precio_Venta || 0).toFixed(2))
                }
            }
        }
        
        Qt.callLater(function() {
            if (cantidadField) {
                cantidadField.focus = true
            }
        })
        
        showSuccess("Producto seleccionado: " + nombre)
    }
    
    // Agregar o actualizar producto
    function addProductToPurchase() {
        if (inputProductCode.length === 0) {
            showSuccess("Error: Ingrese el código del producto")
            return false
        }
        
        if (inputProductName.length === 0) {
            showSuccess("Error: Ingrese el nombre del producto")
            return false
        }
        
        if (inputCantidad <= 0) {
            showSuccess("Error: Ingrese cantidad de unidades")
            return false
        }
        
        if (inputPrecioTotalCompra <= 0) {
            showSuccess("Error: El precio total debe ser mayor a 0")
            return false
        }
        
        // Validar precio de venta para primera compra
        if (esPrimeraCompra && inputPrecioVentaFinal <= 0) {
            showSuccess("Error: Debe definir precio de venta para primera compra")
            return false
        }
        
        if (esPrimeraCompra && inputPrecioVentaFinal <= inputPrecioUnitarioCalculado) {
            showSuccess("Error: Precio de venta debe ser mayor al precio de compra")
            return false
        }
        
        if (!inputNoExpiry) {
            if (inputExpiryDate.length === 0) {
                showSuccess("Error: Ingrese fecha de vencimiento o marque 'Sin vencimiento'")
                return false
            }
            if (!validateExpiryDate(inputExpiryDate)) {
                showSuccess("Error: Fecha de vencimiento inválida (YYYY-MM-DD)")
                return false
            }
        }
        
        // Verificar si estamos en modo edición
        if (productoEditandoIndex >= 0) {
            return actualizarProductoExistente()
        } else {
            return agregarNuevoProducto()
        }
    }
    
    // Agregar nuevo producto
    function agregarNuevoProducto() {
        if (compraModel) {
            // Agregar item con precio unitario calculado
            compraModel.agregar_item_compra(
                inputProductCode,
                inputCantidad,
                inputPrecioUnitarioCalculado,
                inputNoExpiry ? "" : inputExpiryDate
            )
            
            // Guardar datos adicionales FIFO 2.0
            Qt.callLater(function() {
                var items = compraModel.items_compra
                if (items && items.length > 0) {
                    var ultimoItem = items[items.length - 1]
                    
                    // Guardar producto_id
                    if (inputProductId > 0) {
                        ultimoItem.producto_id = inputProductId
                        console.log("✅ Producto ID guardado:", inputProductId)
                    }
                    
                    // Guardar precio_venta SOLO si es primera compra
                    if (esPrimeraCompra && inputPrecioVentaFinal > 0) {
                        ultimoItem.precio_venta = inputPrecioVentaFinal
                        console.log("💰 Precio venta guardado:", inputPrecioVentaFinal)
                        
                        showSuccess(`Producto agregado: ${inputProductName} | Margen: Bs${inputGananciaUnitaria.toFixed(2)} (${inputMargenRealPorcentaje.toFixed(1)}%)`)
                    } else {
                        showSuccess("Producto agregado: " + inputProductName)
                    }
                }
            })
        }
        
        updatePurchaseTotal()
        clearProductFields()
        return true
    }
    
    // Actualizar producto existente
    function actualizarProductoExistente() {
        if (productoEditandoIndex < 0 || !compraModel) {
            return false
        }
        
        var items = compraModel.items_compra
        if (productoEditandoIndex >= items.length) {
            console.log("Índice inválido:", productoEditandoIndex)
            cancelarEdicionProducto()
            return false
        }
        
        // Actualizar en el modelo
        compraModel.actualizar_item_compra(
            productoEditandoIndex,
            inputCantidad,
            inputPrecioUnitarioCalculado,
            inputNoExpiry ? "" : inputExpiryDate
        )
        
        showSuccess("Producto actualizado: " + inputProductName)
        updatePurchaseTotal()
        cancelarEdicionProducto()
        return true
    }
    
    // Editar producto existente
    function editarProductoExistente(index) {
        if (index < 0 || !compraModel) {
            return
        }
        
        var items = compraModel.items_compra
        if (index >= items.length) {
            console.log("Índice inválido:", index)
            return
        }
        
        var producto = items[index]
        
        console.log("Editando producto:", producto.codigo, "- Índice:", index)
        
        // Cargar datos en el formulario
        inputProductCode = producto.codigo || ""
        inputProductName = producto.nombre || ""
        inputProductId = producto.producto_id || 0
        inputCantidad = producto.cantidad_unitario || 0
        
        // Calcular precio total desde unitario
        var precioUnit = producto.precio_unitario || 0
        var cantidad = producto.cantidad_unitario || 1
        inputPrecioTotalCompra = precioUnit * cantidad
        
        inputExpiryDate = producto.fecha_vencimiento || ""
        inputNoExpiry = (inputExpiryDate.length === 0 || inputExpiryDate === "Sin vencimiento")
        
        // Recalcular precios
        calcularPreciosAutomaticos()
        
        // Actualizar campos visuales
        if (productCodeField) productCodeField.text = inputProductName
        if (cantidadField) cantidadField.text = inputCantidad.toString()
        if (precioTotalField) precioTotalField.text = inputPrecioTotalCompra.toString()
        if (expiryField) expiryField.text = inputExpiryDate
        
        // Marcar como editando
        productoEditandoIndex = index
        
        Qt.callLater(function() {
            if (cantidadField) {
                cantidadField.focus = true
                cantidadField.selectAll()
            }
        })
        
        showSuccess("Editando: " + inputProductName)
    }
    
    // Cancelar edición de producto
    function cancelarEdicionProducto() {
        productoEditandoIndex = -1
        clearProductFields()
        showSuccess("Edición cancelada")
    }

    function clearProductFields() {
        // ✅ IMPORTANTE: Resetear flag PRIMERO
        precioModificadoManualmente = false
        
        inputProductCode = ""
        inputProductName = ""
        inputProductId = 0
        inputCantidad = 0
        inputPrecioTotalCompra = 0.0
        inputPrecioUnitarioCalculado = 0.0
        inputMargenPorcentaje: 100.0
        inputPrecioVentaSugerido = 0.0
        inputPrecioVentaFinal = 0.0
        inputGananciaUnitaria = 0.0
        inputGananciaTotal = 0.0
        inputMargenRealPorcentaje = 0.0
        inputExpiryDate = ""
        inputNoExpiry = false
        isNewProduct = true
        showProductDropdown = false
        productSearchResultsModel.clear()
        productoEditandoIndex = -1
        esPrimeraCompra = false

        // ❌ **CORRECCIÓN CRÍTICA**: NO resetear contadorClics aquí
        // El contador se resetea solo cuando se completa la compra o se cancela
        // contadorClics = 0  // ❌ ELIMINADO PARA EVITAR DUPLICACIONES
        
        if (productCodeField) productCodeField.text = ""
        if (cantidadField) cantidadField.text = "" 
        if (precioTotalField) precioTotalField.text = ""
        if (precioVentaField) precioVentaField.text = ""
        if (expiryField) expiryField.text = ""
    }

    function validateExpiryDate(dateStr) {
        if (dateStr === "" || dateStr === "Sin vencimiento") return true;
        
        var regex = /^\d{4}-\d{2}-\d{2}$/;
        if (!regex.test(dateStr)) return false;
        
        var parts = dateStr.split('-');
        var year = parseInt(parts[0], 10);
        var month = parseInt(parts[1], 10);
        var day = parseInt(parts[2], 10);
        
        if (month < 1 || month > 12) return false;
        if (day < 1 || day > 31) return false;
        if (year < 2020 || year > 2050) return false;
        
        var daysInMonth = new Date(year, month, 0).getDate();
        if (day > daysInMonth) return false;
        
        return true;
    }

    // Completar compra con FIFO 2.0
    function completarCompra() {
        console.log("Iniciando proceso de completar/actualizar compra FIFO 2.0...")
        
        if (!compraModel) {
            showSuccess("Error: Sistema de compras no disponible")
            return false
        }
        
        if (newPurchaseProvider === "") {
            showSuccess("Error: Seleccione un proveedor")
            return false
        }
        
        if (!compraModel.items_compra || compraModel.items_compra.length === 0) {
            showSuccess("Error: Agregue al menos un producto")
            return false
        }
        
        if (productoEditandoIndex >= 0) {
            showSuccess("Advertencia: Hay un producto en edición. Guárdelo o cancele primero")
            return false
        }
        
        // MODO EDICIÓN: usar método legacy
        if (modoEdicion) {
            var cambios = compraModel.obtener_cambios_realizados()
            if (cambios && cambios.hay_cambios) {
                var mensaje = `Cambios detectados: ${cambios.total_cambios} modificaciones`
                showSuccess(mensaje)
            } else if (cambios && !cambios.hay_cambios) {
                showSuccess("No hay cambios para guardar")
                return true
            }
            
            var exito = compraModel.procesar_compra_actual()
            
            if (exito) {
                showSuccess("Compra actualizada exitosamente")
                return true
            } else {
                showSuccess("Error: No se pudo actualizar la compra")
                return false
            }
        }
        
        // MODO CREACIÓN: usar FIFO 2.0
        console.log("📦 Usando sistema FIFO 2.0 para nueva compra")
        
        // Obtener proveedor_id
        var proveedor_id = 0
        var proveedores = compraModel.proveedores
        for (var i = 0; i < proveedores.length; i++) {
            var proveedor = proveedores[i]
            if ((proveedor.Nombre || proveedor.nombre) === newPurchaseProvider) {
                proveedor_id = proveedor.id
                break
            }
        }
        
        if (proveedor_id <= 0) {
            showSuccess("Error: Proveedor no válido")
            return false
        }
        
        // Construir JSON de detalles para FIFO 2.0
        var detalles = []
        var items = compraModel.items_compra
        
        for (var j = 0; j < items.length; j++) {
            var item = items[j]
            
            var detalle = {
                "Id_Producto": item.producto_id || 0,
                "Cantidad": item.cantidad_unitario || 0,
                "Precio_Unitario": item.precio_unitario || 0.0
            }
            
            // Agregar fecha de vencimiento si existe
            if (item.fecha_vencimiento && item.fecha_vencimiento !== "" && item.fecha_vencimiento !== "Sin vencimiento") {
                detalle["Fecha_Vencimiento"] = item.fecha_vencimiento
            }
            
            // FIFO 2.0: Agregar Precio_Venta SOLO si es primera compra
            if (item.precio_venta && item.precio_venta > 0) {
                detalle["Precio_Venta"] = item.precio_venta
                console.log(`💰 Item ${item.codigo}: Precio Venta = Bs${item.precio_venta}`)
            }
            
            detalles.push(detalle)
        }
        
        console.log("📋 Detalles FIFO 2.0:", JSON.stringify(detalles))
        
        // Llamar al método FIFO 2.0
        var usuario_id = compraModel.usuario_actual_id
        var resultado = compraModel.registrar_compra_fifo_v2(
            proveedor_id,
            usuario_id,
            JSON.stringify(detalles)
        )
        
        console.log("📦 Resultado FIFO 2.0:", JSON.stringify(resultado))
        
        if (resultado && resultado.exito) {
            var id_compra = resultado.id_compra || 0
            var total = resultado.total || 0.0
            
            showSuccess(`✅ Compra #${id_compra} registrada: Bs${total.toFixed(2)} (FIFO 2.0)`)
            clearProductFields()
            
            return true
        } else {
            var errorMsg = resultado ? resultado.mensaje : "Error desconocido"
            showSuccess(`Error: ${errorMsg}`)
            return false
        }
    }

    function showSuccess(message) {
        successMessage = message
        showSuccessMessage = true
        successTimer.restart()
    }

    // ============================================================================
    // INTERFAZ MEJORADA + INDICADORES EDUCATIVOS
    // ============================================================================
    
    Rectangle {
        anchors.fill: parent
        color: "#f8f9fa"
        
        // HEADER
        Rectangle {
            id: fixedHeader
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: headerHeight
            color: whiteColor
            radius: radiusLarge
            border.color: modoEdicion ? editModeColor : "#e9ecef"
            border.width: 1
            z: 10
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: spacing8
                spacing: spacing8
                
                Button {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    
                    background: Rectangle {
                        color: parent.pressed ? Qt.darker(accentColor, 1.2) : accentColor
                        radius: 20
                    }
                    
                    contentItem: Label {
                        text: "←"
                        color: whiteColor
                        font.bold: true
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        // ✅ RESETEAR CONTADOR DE CLICS
                        contadorClics = 0
                        console.log("↩️ Cancelar - Contador reseteado")
                        
                        if (modoEdicion && compraModel) {
                            compraModel.cancelar_edicion()
                        }
                        cancelarCompra()
                    }
                }
                
                RowLayout {
                    spacing: spacing8
                    
                    Rectangle {
                        width: 32
                        height: 32
                        color: modoEdicion ? editModeColor : primaryColor
                        radius: 16
                        
                        Label {
                            anchors.centerIn: parent
                            text: modoEdicion ? "📝" : "🛒"
                            font.pixelSize: 16
                        }
                    }
                    
                    ColumnLayout {
                        spacing: 4
                        
                        Label {
                            text: modoEdicion ? "Editar Compra" : "Nueva Compra"
                            color: textColor
                            font.bold: true
                            font.pixelSize: fontLarge
                        }
                        
                        Label {
                            text: modoEdicion ? `Compra ${newPurchaseId}` : `${newPurchaseId} - ${newPurchaseDate}`
                            color: darkGrayColor
                            font.pixelSize: fontSmall
                        }
                    }
                }
                
                Item { Layout.fillWidth: true }
                
                // 🆕 Botón de ayuda
                Button {
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 36
                    text: mostrarAyuda ? "Ocultar ayuda" : "Mostrar ayuda"
                    
                    background: Rectangle {
                        color: parent.pressed ? "#e3f2fd" : "#f8f9fa"
                        radius: radiusSmall
                        border.color: blueColor
                        border.width: 1
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        color: blueColor
                        font.pixelSize: fontSmall
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: mostrarAyuda = !mostrarAyuda
                }
                
                Rectangle {
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 40
                    color: "#E8F5E9"
                    radius: radiusMedium
                    border.color: successColor
                    border.width: 1
                    
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 0
                        
                        Label {
                            text: "Total Compra"
                            color: "#2E7D32"
                            font.pixelSize: fontSmall
                            Layout.alignment: Qt.AlignHCenter
                        }
                        
                        Label {
                            text: "Bs" + newPurchaseTotal.toFixed(2)
                            color: successColor
                            font.bold: true
                            font.pixelSize: fontMedium
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }
        }
        
        // 🆕 PANEL DE AYUDA EDUCATIVO
        Rectangle {
            id: ayudaPanel
            visible: mostrarAyuda
            anchors.top: fixedHeader.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: spacing8
            anchors.topMargin: spacing4
            height: mostrarAyuda ? 60 : 0  // Más compacto y colapsable
            color: "#E3F2FD"
            radius: radiusMedium
            border.color: "#2196F3"
            border.width: 2
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: spacing12
                spacing: spacing12
                
                Rectangle {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    color: "#2196F3"
                    radius: 20
                    
                    Label {
                        anchors.centerIn: parent
                        text: "💡"
                        font.pixelSize: 20
                    }
                }
                
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    
                    Label {
                        text: "¿CÓMO REGISTRAR UNA COMPRA?"
                        color: "#1565C0"
                        font.bold: true
                        font.pixelSize: fontMedium
                    }
                    
                    Label {
                        text: "1️⃣ Busca el producto → 2️⃣ Ingresa CANTIDAD y PRECIO TOTAL que pagaste → 3️⃣ El sistema calcula precio unitario y sugiere precio de venta con 100% margen → 4️⃣ Puedes modificar el precio de venta → 5️⃣ Agregar"
                        color: "#1976D2"
                        font.pixelSize: fontSmall
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }
        }
        
        // SECCIÓN PROVEEDOR
        Rectangle {
            id: providerSection
            anchors.top: mostrarAyuda ? ayudaPanel.bottom : fixedHeader.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: spacing8
            anchors.topMargin: spacing4
            height: 50
            color: whiteColor
            radius: radiusMedium
            border.color: "#D5DBDB"
            border.width: 1
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: spacing8
                spacing: spacing8
                
                Label {
                    text: "Proveedor:"
                    color: textColor
                    font.bold: true
                    font.pixelSize: fontSmall
                }
                
                ComboBox {
                    id: providerCombo
                    Layout.preferredWidth: 250
                    Layout.preferredHeight: inputHeight
                    model: crearCompraRoot.providerNames
                    font.pixelSize: fontSmall
                    
                    background: Rectangle {
                        color: whiteColor
                        border.color: modoEdicion ? editModeColor : darkGrayColor
                        border.width: 1
                        radius: radiusSmall
                    }
                    
                    onCurrentTextChanged: {
                        if (currentIndex > 0) {
                            newPurchaseProvider = currentText
                        } else {
                            newPurchaseProvider = ""
                        }
                        
                        if (compraModel) {
                            var proveedores = compraModel.proveedores
                            for (var i = 0; i < proveedores.length; i++) {
                                var proveedor = proveedores[i]
                                if ((proveedor.Nombre || proveedor.nombre) === currentText) {
                                    compraModel.set_proveedor_seleccionado(proveedor.id)
                                    break
                                }
                            }
                        }
                    }
                }
                
                Button {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: inputHeight
                    
                    background: Rectangle {
                        color: parent.pressed ? Qt.darker(blueColor, 1.2) : blueColor
                        radius: radiusSmall
                    }
                    
                    contentItem: Label {
                        text: "🔄"
                        color: whiteColor
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        if (compraModel) {
                            compraModel.force_refresh_proveedores()
                        }
                    }
                }
                
                Label {
                    text: "💡 Para gestiónar proveedores, usa Farmacia → Proveedores"
                    color: "#666"
                    font.pixelSize: fontSmall
                    font.italic: true
                    Layout.fillWidth: true
                }
            }
        }
        
        // 🚀 SECCIÓN FORMULARIO MEJORADO - FLUJO INTUITIVO CON CAMPOS MÁS GRANDES
        Rectangle {
            id: unifiedInputSection
            anchors.top: providerSection.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: spacing8
            anchors.topMargin: spacing4
            height: esPrimeraCompra ? 320 : 210  // ✅ Ajustado para que quepa el botón
            color: productoEditandoIndex >= 0 ? "#FFF9C4" : "#F8F9FA"
            radius: radiusMedium
            border.color: productoEditandoIndex >= 0 ? "#F39C12" : "#D5DBDB"
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: spacing12
                spacing: spacing8  // Más compacto
                
                // FILA 1: BÚSQUEDA
                RowLayout {
                    Layout.fillWidth: true
                    spacing: spacing8
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        
                        Label {
                            text: productoEditandoIndex >= 0 ? "EDITANDO PRODUCTO" : "1️⃣ BUSCAR PRODUCTO"
                            color: productoEditandoIndex >= 0 ? "#E67E22" : textColor
                            font.bold: true
                            font.pixelSize: fontSmall
                        }
                        
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 45  // Aumentado
                            color: "#ffffff"
                            border.color: productCodeField.activeFocus ? blueColor : darkGrayColor
                            border.width: productCodeField.activeFocus ? 2 : 1
                            radius: radiusMedium
                            opacity: productoEditandoIndex >= 0 ? 0.5 : 1.0
                            
                            TextInput {
                                id: productCodeField
                                anchors.fill: parent
                                anchors.margins: 12
                                
                                text: inputProductName.length > 0 ? inputProductName : inputProductCode
                                enabled: productoEditandoIndex < 0
                                
                                font.pixelSize: fontMedium  // Aumentado
                                color: "#000000"
                                verticalAlignment: Text.AlignVCenter
                                
                                clip: true
                                selectByMouse: true
                                
                                onTextChanged: {
                                    if (inputProductName.length > 0 && text === inputProductName) {
                                        return
                                    }
                                    
                                    if (text !== inputProductName) {
                                        inputProductCode = text
                                        inputProductName = ""
                                        isNewProduct = true
                                    }
                                    
                                    if (text.length >= 2) {
                                        buscarProductosExistentes(text)
                                    } else {
                                        showProductDropdown = false
                                        isNewProduct = true
                                    }
                                }
                            }
                            
                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Escribe nombre o código del producto..."
                                color: "#999999"
                                font.pixelSize: fontSmall
                                visible: productCodeField.text.length === 0
                            }
                        }
                    }
                }
                
                // FILA 2: CANTIDAD Y PRECIO TOTAL - CAMPOS MÁS GRANDES
                RowLayout {
                    Layout.fillWidth: true
                    spacing: spacing12
                    
                    // CANTIDAD - CAMPO MÁS GRANDE
                    ColumnLayout {
                        spacing: 4
                        
                        Label {
                            text: "2️⃣ Cantidad Unidades"
                            color: textColor
                            font.bold: true
                            font.pixelSize: fontSmall
                        }
                        
                        Rectangle {
                            width: 140  // Aumentado
                            height: 40  // Aumentado
                            color: "#ffffff"
                            border.color: cantidadField.activeFocus ? blueColor : darkGrayColor
                            border.width: cantidadField.activeFocus ? 2 : 1
                            radius: radiusSmall
                            
                            TextInput {
                                id: cantidadField
                                anchors.fill: parent
                                anchors.margins: 8
                                
                                text: inputCantidad > 0 ? inputCantidad.toString() : ""
                                
                                validator: IntValidator { bottom: 0 }
                                
                                font.pixelSize: fontLarge  // Aumentado
                                font.bold: true
                                color: "#000000"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                
                                clip: true
                                selectByMouse: true
                                
                                onTextChanged: {
                                    inputCantidad = text.length > 0 ? (parseInt(text) || 0) : 0
                                    calcularPreciosAutomaticos()
                                }
                            }
                            
                            Text {
                                anchors.centerIn: parent
                                text: "0"
                                color: "#999999"
                                font.pixelSize: fontSmall
                                visible: cantidadField.text.length === 0
                            }
                        }
                    }
                    
                    // PRECIO TOTAL COMPRA - CAMPO MÁS GRANDE
                    ColumnLayout {
                        spacing: 4
                        
                        Label {
                            text: "3️⃣ Precio TOTAL Compra"
                            color: textColor
                            font.bold: true
                            font.pixelSize: fontSmall
                        }
                        
                        Rectangle {
                            width: 180  // Aumentado
                            height: 40  // Aumentado
                            color: "#FFF3E0"
                            border.color: precioTotalField.activeFocus ? "#FF6F00" : "#FFB74D"
                            border.width: precioTotalField.activeFocus ? 2 : 1
                            radius: radiusSmall
                            
                            TextInput {
                                id: precioTotalField
                                anchors.fill: parent
                                anchors.margins: 8
                                
                                text: inputPrecioTotalCompra > 0 ? inputPrecioTotalCompra.toString() : ""
                                
                                validator: RegularExpressionValidator {
                                    regularExpression: /^\d*\.?\d{0,2}$/
                                }
                                
                                font.pixelSize: fontLarge  // Aumentado
                                font.bold: true
                                color: "#E65100"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                
                                clip: true
                                selectByMouse: true
                                
                                onTextChanged: {
                                    inputPrecioTotalCompra = text.length > 0 ? (parseFloat(text) || 0.0) : 0.0
                                    calcularPreciosAutomaticos()
                                }
                            }
                            
                            Text {
                                anchors.centerIn: parent
                                text: "Bs 0.00"
                                color: "#FFAB91"
                                font.pixelSize: fontSmall
                                visible: precioTotalField.text.length === 0
                            }
                        }
                    }
                    
                    // PRECIO UNITARIO CALCULADO (READ-ONLY) - CAMPO MÁS GRANDE
                    ColumnLayout {
                        visible: inputPrecioUnitarioCalculado > 0
                        spacing: 4
                        
                        Label {
                            text: "📊 Precio Unitario"
                            color: "#1565C0"
                            font.bold: true
                            font.pixelSize: fontSmall
                        }
                        
                        Rectangle {
                            width: 130  // Aumentado
                            height: 40  // Aumentado
                            color: "#E3F2FD"
                            border.color: "#2196F3"
                            border.width: 2
                            radius: radiusSmall
                            
                            Label {
                                anchors.centerIn: parent
                                text: "Bs " + inputPrecioUnitarioCalculado.toFixed(2)
                                color: "#1565C0"
                                font.bold: true
                                font.pixelSize: fontMedium  // Aumentado
                            }
                        }
                    }
                    
                    // FECHA VENCIMIENTO - MEJORADA SIN noExpiryCheckbox
                    ColumnLayout {
                        spacing: 4
                        
                        Label {
                            text: "Vencimiento"
                            color: darkGrayColor
                            font.pixelSize: fontSmall
                            font.bold: true
                        }
                        
                        RowLayout {
                            spacing: 4
                            
                            Rectangle {
                                Layout.preferredWidth: 100  // Aumentado
                                Layout.preferredHeight: 40  // Aumentado
                                color: inputNoExpiry ? "#F5F5F5" : "#ffffff"
                                border.color: {
                                    if (inputNoExpiry) return "#E0E0E0"
                                    if (expiryField.activeFocus) return "#9C27B0"
                                    if (inputExpiryDate.length > 0 && !validateExpiryDate(inputExpiryDate)) return dangerColor
                                    return darkGrayColor
                                }
                                border.width: expiryField.activeFocus ? 2 : 1
                                radius: radiusSmall
                                
                                TextInput {
                                    id: expiryField
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    
                                    text: inputExpiryDate
                                    enabled: !inputNoExpiry
                                    
                                    font.pixelSize: fontMedium  // Aumentado
                                    color: "#000000"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    
                                    clip: true
                                    selectByMouse: true
                                    
                                    onTextChanged: {
                                        if (!inputNoExpiry) {
                                            inputExpiryDate = text
                                        }
                                    }
                                }
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "AAAA-MM-DD"
                                    color: "#999999"
                                    font.pixelSize: fontSmall
                                    visible: expiryField.text.length === 0 && !inputNoExpiry
                                }
                            }

                            // Checkbox personalizado sin variable noExpiryCheckbox
                            Rectangle {
                                width: 24
                                height: 24
                                radius: 4
                                border.color: darkGrayColor
                                border.width: 1
                                color: !inputNoExpiry ? successColor : whiteColor
                                
                                Label {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    color: whiteColor
                                    font.pixelSize: 12
                                    font.bold: true
                                    visible: !inputNoExpiry
                                }
                                
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        inputNoExpiry = !inputNoExpiry
                                        if (inputNoExpiry) {
                                            inputExpiryDate = ""
                                            expiryField.text = ""
                                        }
                                    }
                                }
                            }  
                            
                            Text {
                                text: "Con venc."
                                font.pixelSize: 10
                                color: darkGrayColor
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }
                    }
                }
                
                // 🆕 FILA 3: PRECIO DE VENTA (SOLO PRIMERA COMPRA) - CAMPOS MÁS GRANDES
                RowLayout {
                    Layout.fillWidth: true
                    visible: esPrimeraCompra
                    spacing: spacing12
                    
                    // PRECIO VENTA SUGERIDO - CAMPO MÁS GRANDE
                    ColumnLayout {
                        spacing: 4
                        
                        Label {
                            text: "4️⃣ Precio Venta Sugerido (100% margen)"
                            color: "#E65100"
                            font.bold: true
                            font.pixelSize: fontSmall
                        }
                        
                        Rectangle {
                            width: 150  // Aumentado
                            height: 40  // Aumentado
                            color: "#FFE0B2"
                            border.color: "#FF6F00"
                            border.width: 2
                            radius: radiusSmall
                            
                            Label {
                                anchors.centerIn: parent
                                text: "Bs " + inputPrecioVentaSugerido.toFixed(2)
                                color: "#BF360C"
                                font.bold: true
                                font.pixelSize: fontLarge  // Aumentado
                            }
                        }
                    }
                    
                    Label {
                        text: "→"
                        font.pixelSize: 20
                        color: "#FF6F00"
                    }
                    
                    // PRECIO VENTA FINAL (EDITABLE) - CAMPO MÁS GRANDE
                    ColumnLayout {
                        spacing: 4
                        
                        Label {
                            text: "✏️ Precio Venta Final"
                            color: "#E65100"
                            font.bold: true
                            font.pixelSize: fontSmall
                        }
                        
                        Rectangle {
                            width: 150  // Aumentado
                            height: 40  // Aumentado
                            color: "#ffffff"
                            border.color: precioVentaField.activeFocus ? "#4CAF50" : "#FF6F00"
                            border.width: precioVentaField.activeFocus ? 3 : 2
                            radius: radiusSmall
                            
                            TextInput {
                                id: precioVentaField
                                anchors.fill: parent
                                anchors.margins: 8
                                
                                // ✅ MEJORADO: Usar el sugerido hasta que usuario empiece a escribir
                                text: {
                                    if (precioModificadoManualmente && inputPrecioVentaFinal > 0) {
                                        return inputPrecioVentaFinal.toFixed(2)
                                    }
                                    if (inputPrecioVentaSugerido > 0) {
                                        return inputPrecioVentaSugerido.toFixed(2)
                                    }
                                    return ""
                                }
                                
                                validator: RegularExpressionValidator {
                                    regularExpression: /^\d*\.?\d{0,2}$/
                                }
                                
                                font.pixelSize: fontLarge  // ✅ Más grande
                                font.bold: true
                                color: "#E65100"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                
                                clip: true
                                selectByMouse: true
                                
                                onTextChanged: {
                                    if (activeFocus) {  // ✅ Solo marcar si usuario está escribiendo
                                        precioModificadoManualmente = true
                                    }
                                    
                                    inputPrecioVentaFinal = text.length > 0 ? (parseFloat(text) || 0.0) : 0.0
                                    
                                    // Recalcular ganancia con el nuevo precio
                                    if (inputPrecioUnitarioCalculado > 0) {
                                        inputGananciaUnitaria = inputPrecioVentaFinal - inputPrecioUnitarioCalculado
                                        inputGananciaTotal = inputGananciaUnitaria * inputCantidad
                                        inputMargenRealPorcentaje = (inputGananciaUnitaria / inputPrecioUnitarioCalculado) * 100
                                    }
                                    
                                    console.log("💰 Cálculos: Unit:", inputPrecioUnitarioCalculado.toFixed(2),
                                                "Venta:", inputPrecioVentaFinal.toFixed(2),
                                                "Margen:", inputMargenRealPorcentaje.toFixed(1) + "%")
                                }
                                
                                onFocusChanged: {
                                    if (focus) {
                                        selectAll()
                                    }
                                }
                            }
                            
                            Text {
                                anchors.centerIn: parent
                                text: "Bs 0.00"
                                color: "#FFAB91"
                                font.pixelSize: fontSmall
                                visible: precioVentaField.text.length === 0
                            }
                        }
                    }
                    
                    // GANANCIA CALCULADA - CAMPO MÁS GRANDE
                    Rectangle {
                        visible: inputGananciaUnitaria > 0
                        Layout.preferredWidth: 220  // Aumentado
                        Layout.preferredHeight: 55  // Aumentado
                        color: inputMargenRealPorcentaje >= 15 ? "#E8F5E9" : "#FFEBEE"
                        border.color: inputMargenRealPorcentaje >= 15 ? "#4CAF50" : "#F44336"
                        border.width: 2
                        radius: radiusSmall
                        
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2
                            
                            Label {
                                text: "💰 GANANCIA"
                                color: inputMargenRealPorcentaje >= 15 ? "#2E7D32" : "#C62828"
                                font.pixelSize: 10
                                font.bold: true
                                Layout.alignment: Qt.AlignHCenter
                            }
                            
                            Label {
                                text: "Bs " + inputGananciaUnitaria.toFixed(2) + " × " + inputCantidad
                                color: inputMargenRealPorcentaje >= 15 ? "#4CAF50" : "#F44336"
                                font.pixelSize: fontMedium  // Aumentado
                                font.bold: true
                                Layout.alignment: Qt.AlignHCenter
                            }
                            
                            Label {
                                text: "= Bs " + inputGananciaTotal.toFixed(2) + " (" + inputMargenRealPorcentaje.toFixed(0) + "%)"
                                color: inputMargenRealPorcentaje >= 15 ? "#2E7D32" : "#C62828"
                                font.pixelSize: fontSmall
                                font.bold: true
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }
                }
                
                // ✅ NUEVO: Advertencia de pérdida
                Rectangle {
                    visible: esPrimeraCompra && inputMargenRealPorcentaje < 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50
                    color: "#FFEBEE"
                    border.color: "#F44336"
                    border.width: 2
                    radius: radiusMedium
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: spacing8
                        spacing: spacing8
                        
                        Rectangle {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            color: "#F44336"
                            radius: 15
                            
                            Label {
                                anchors.centerIn: parent
                                text: "⚠️"
                                font.pixelSize: 16
                            }
                        }
                        
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            
                            Label {
                                text: "ADVERTENCIA: Precio de venta MENOR que precio de compra"
                                color: "#C62828"
                                font.bold: true
                                font.pixelSize: fontSmall
                            }
                            
                            Label {
                                text: "Estás perdiendo Bs " + Math.abs(inputGananciaUnitaria).toFixed(2) + " por unidad (" + Math.abs(inputMargenRealPorcentaje).toFixed(1) + "%)"
                                color: "#D32F2F"
                                font.pixelSize: fontSmall
                            }
                        }
                    }
                }
                
                // FILA 4: BOTONES
                RowLayout {
                    Layout.fillWidth: true
                    spacing: spacing8
                    
                    Item { Layout.fillWidth: true }
                    
                    // BOTÓN AGREGAR
                    Rectangle {
                        Layout.preferredWidth: 155
                        Layout.preferredHeight: 48
                        color: {
                            var baseEnabled = inputProductCode.length > 0 && 
                                        inputProductName.length > 0 && 
                                        inputCantidad > 0 &&
                                        inputPrecioTotalCompra > 0 &&
                                        (inputNoExpiry || (inputExpiryDate.length > 0 && validateExpiryDate(inputExpiryDate)))
                            
                            if (esPrimeraCompra) {
                                baseEnabled = baseEnabled && inputPrecioVentaFinal > 0 && inputPrecioVentaFinal > inputPrecioUnitarioCalculado
                            }
                            
                            if (!baseEnabled) return darkGrayColor
                            return productoEditandoIndex >= 0 ? blueColor : successColor
                        }
                        radius: radiusMedium
                        
                        Label {
                            anchors.centerIn: parent
                            text: productoEditandoIndex >= 0 ? "✏️ Actualizar" : "➕ Agregar"
                            color: whiteColor
                            font.bold: true
                            font.pixelSize: fontMedium
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            enabled: {
                                var baseEnabled = inputProductCode.length > 0 && 
                                            inputProductName.length > 0 && 
                                            inputCantidad > 0 &&
                                            inputPrecioTotalCompra > 0 &&
                                            (inputNoExpiry || (inputExpiryDate.length > 0 && validateExpiryDate(inputExpiryDate)))
                                
                                if (esPrimeraCompra) {
                                    return baseEnabled && inputPrecioVentaFinal > 0 && inputPrecioVentaFinal > inputPrecioUnitarioCalculado
                                }
                                
                                return baseEnabled
                            }
                            onClicked: addProductToPurchase()
                        }
                    }
                    
                    // Botón Cancelar edición
                    Rectangle {
                        visible: productoEditandoIndex >= 0
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: buttonHeight
                        color: warningColor
                        radius: radiusSmall
                        
                        Label {
                            anchors.centerIn: parent
                            text: "❌ Cancelar"
                            color: whiteColor
                            font.bold: true
                            font.pixelSize: fontSmall
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            onClicked: cancelarEdicionProducto()
                        }
                    }
                }
            }
        }
        
        // SECCIÓN LISTA DE PRODUCTOS
        Rectangle {
            id: productListSection
            anchors.top: unifiedInputSection.bottom
            anchors.bottom: actionsSection.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: spacing8
            anchors.topMargin: spacing4
            anchors.bottomMargin: spacing4
            color: "#F8F9FA"
            radius: radiusLarge
            border.color: lightGrayColor
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: spacing8
                spacing: spacing8
                
                RowLayout {
                    Layout.fillWidth: true
                    
                    Label {
                        text: "📦"
                        font.pixelSize: 16
                    }
                    
                    Label {
                        text: `Productos en la compra: ${compraModel ? compraModel.items_en_compra : 0}`
                        color: textColor
                        font.bold: true
                        font.pixelSize: fontMedium
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: whiteColor
                    border.color: "#D5DBDB"
                    border.width: 1
                    radius: radiusMedium
                    
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0
                        
                        // Header de tabla
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 35
                            color: "#F8F9FA"
                            
                            RowLayout {
                                anchors.fill: parent
                                spacing: 0
                                
                                Rectangle {
                                    Layout.preferredWidth: 80
                                    Layout.fillHeight: true
                                    color: "#F8F9FA"
                                    border.color: "#D5DBDB"
                                    border.width: 1
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "CÓDIGO"
                                        font.bold: true
                                        font.pixelSize: fontSmall
                                        color: textColor
                                    }
                                }
                                
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 150
                                    Layout.fillHeight: true
                                    color: "#F8F9FA"
                                    border.color: "#D5DBDB"
                                    border.width: 1
                                    
                                    Label {
                                        anchors.left: parent.left
                                        anchors.leftMargin: spacing4
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "NOMBRE"
                                        color: textColor
                                        font.bold: true
                                        font.pixelSize: fontSmall
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 80
                                    Layout.fillHeight: true
                                    color: "#F8F9FA"
                                    border.color: "#D5DBDB"
                                    border.width: 1
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "CANTIDAD"
                                        color: textColor
                                        font.bold: true
                                        font.pixelSize: fontSmall
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 100
                                    Layout.fillHeight: true
                                    color: "#F8F9FA"
                                    border.color: "#D5DBDB"
                                    border.width: 1
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "COSTO TOTAL"
                                        color: textColor
                                        font.bold: true
                                        font.pixelSize: fontSmall
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 80
                                    Layout.fillHeight: true
                                    color: "#F8F9FA"
                                    border.color: "#D5DBDB"
                                    border.width: 1
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "ACCIONES"
                                        color: textColor
                                        font.bold: true
                                        font.pixelSize: fontSmall
                                    }
                                }
                            }
                        }
                        
                        // Lista de productos
                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            
                            model: compraModel ? compraModel.items_compra : []
                            
                            delegate: Rectangle {
                                width: ListView.view ? ListView.view.width : 0
                                height: 40
                                color: index % 2 === 0 ? whiteColor : "#F8F9FA"
                                
                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 0
                                    
                                    // CÓDIGO
                                    Rectangle {
                                        Layout.preferredWidth: 80
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#D5DBDB"
                                        border.width: 1
                                        
                                        Label {
                                            anchors.centerIn: parent
                                            text: modelData.codigo || ""
                                            font.pixelSize: fontSmall
                                            color: textColor
                                        }
                                    }
                                    
                                    // NOMBRE
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 150
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#D5DBDB"
                                        border.width: 1
                                        
                                        Label {
                                            anchors.left: parent.left
                                            anchors.leftMargin: spacing4
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.nombre || ""
                                            font.pixelSize: fontSmall
                                            color: textColor
                                            elide: Text.ElideRight
                                            width: parent.width - spacing4 * 2
                                        }
                                    }
                                    
                                    // CANTIDAD
                                    Rectangle {
                                        Layout.preferredWidth: 80
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#D5DBDB"
                                        border.width: 1
                                        
                                        Label {
                                            anchors.centerIn: parent
                                            text: (modelData.cantidad_unitario || 0).toString()
                                            font.pixelSize: fontSmall
                                            color: textColor
                                        }
                                    }
                                    
                                    // COSTO TOTAL
                                    Rectangle {
                                        Layout.preferredWidth: 100
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#D5DBDB"
                                        border.width: 1
                                        
                                        Label {
                                            anchors.centerIn: parent
                                            text: "Bs" + (modelData.subtotal || 0).toFixed(2)
                                            font.pixelSize: fontSmall
                                            font.bold: true
                                            color: successColor
                                        }
                                    }
                                    
                                    // ACCIONES
                                    Rectangle {
                                        Layout.preferredWidth: 80
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#D5DBDB"
                                        border.width: 1
                                        
                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: spacing4
                                            
                                            Rectangle {
                                                width: 24
                                                height: 24
                                                color: blueColor
                                                radius: 12
                                                
                                                Label {
                                                    anchors.centerIn: parent
                                                    text: "✏️"
                                                    font.pixelSize: 10
                                                }
                                                
                                                MouseArea {
                                                    anchors.fill: parent
                                                    onClicked: editarProductoExistente(index)
                                                }
                                            }
                                            
                                            Rectangle {
                                                width: 24
                                                height: 24
                                                color: dangerColor
                                                radius: 12
                                                
                                                Label {
                                                    anchors.centerIn: parent
                                                    text: "🗑️"
                                                    font.pixelSize: 10
                                                }
                                                
                                                MouseArea {
                                                    anchors.fill: parent
                                                    onClicked: {
                                                        if (compraModel) {
                                                            compraModel.remover_item_compra(modelData.codigo)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // SECCIÓN DE ACCIONES
        Rectangle {
            id: actionsSection
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: spacing8
            height: 60
            color: whiteColor
            radius: radiusMedium
            border.color: "#D5DBDB"
            border.width: 1
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: spacing8
                spacing: spacing8
                
                Item { Layout.fillWidth: true }
                
                Button {
                    text: "❌ Cancelar"
                    Layout.preferredHeight: buttonHeight
                    
                    background: Rectangle {
                        color: parent.pressed ? Qt.darker(dangerColor, 1.2) : dangerColor
                        radius: radiusSmall
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        color: whiteColor
                        font.bold: true
                        font.pixelSize: fontSmall
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        // ✅ RESETEAR CONTADOR DE CLICS
                        contadorClics = 0
                        console.log("↩️ Cancelar - Contador reseteado")
                        
                        if (modoEdicion && compraModel) {
                            compraModel.cancelar_edicion()
                        }
                        cancelarCompra()
                    }
                }
                
                Button {
                    id: completarCompraButton
                    text: modoEdicion ? "💾 Guardar Cambios" : "📦 Completar Compra"
                    Layout.preferredHeight: buttonHeight
                    enabled: !procesandoCompra &&  // ✅ AGREGAR ESTA LÍNEA
                        (providerCombo ? providerCombo.currentIndex > 0 : false) && 
                        (compraModel ? compraModel.items_en_compra > 0 : false) &&
                        productoEditandoIndex < 0
                    
                    background: Rectangle {
                        color: !enabled ? darkGrayColor : (modoEdicion ? editModeColor : successColor)
                        radius: radiusSmall
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        color: whiteColor
                        font.bold: true
                        font.pixelSize: fontSmall
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        // ✅ INCREMENTAR Y LOGGEAR CLICS
                        contadorClics++
                        console.log("🔵 CLIC #" + contadorClics + " en botón Completar Compra")
                        
                        // ✅ BLOQUEAR SI YA HUBO UN CLIC
                        if (contadorClics > 1) {
                            console.log("🚫 CLIC DUPLICADO DETECTADO - BLOQUEANDO (Clic #" + contadorClics + ")")
                            return  // ❌ Salir inmediatamente
                        }
                        
                        // ✅ DESHABILITAR BOTÓN INMEDIATAMENTE
                        completarCompraButton.enabled = false
                        completarCompraButton.text = "⏳ Procesando..."
                        console.log("🔒 Botón deshabilitado - Iniciando guardado")
                        
                        // Ejecutar compra
                        if (completarCompra()) {
                            console.log("✅ Compra ejecutada exitosamente")
                            Qt.callLater(function() {
                                completarCompraButton.text = modoEdicion ? "✅ ¡Actualizado!" : "✅ ¡Completado!"
                                // ✅ INICIAR TIMER PARA RESETEO COMPLETO
                                resetButtonTimer.restart()
                            })
                        } else {
                            console.log("❌ Error en compra - Reactivando botón")
                            completarCompraButton.enabled = true
                            completarCompraButton.text = modoEdicion ? "💾 Guardar Cambios" : "📦 Completar Compra"
                            contadorClics = 0  // Reset del contador solo en error
                        }
                    }
                }
            }
        }

        // DROPDOWN FLOTANTE
        Rectangle {
            id: floatingDropdown
            anchors.top: unifiedInputSection.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: spacing8
            anchors.topMargin: spacing4
            height: Math.min(100, productSearchResultsModel.count * 30)
            color: whiteColor
            border.color: blueColor
            border.width: 1
            radius: radiusSmall
            visible: showProductDropdown && productoEditandoIndex < 0
            z: 1000
            
            ListView {
                anchors.fill: parent
                anchors.margins: spacing4
                model: productSearchResultsModel
                clip: true
                
                delegate: Rectangle {
                    width: ListView.view ? ListView.view.width : 0
                    height: 30
                    color: mouseArea.containsMouse ? "#E3F2FD" : "transparent"
                    radius: radiusSmall
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: spacing4
                        spacing: spacing4
                        
                        Rectangle {
                            Layout.preferredWidth: 50
                            Layout.preferredHeight: 16
                            color: blueColor
                            radius: 8
                            
                            Label {
                                anchors.centerIn: parent
                                text: model.codigo
                                color: whiteColor
                                font.bold: true
                                font.pixelSize: 8
                            }
                        }
                        
                        Label {
                            text: model.nombre
                            color: textColor
                            font.pixelSize: fontSmall
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        
                        Label {
                            text: "Bs" + model.precioVentaBase.toFixed(2)
                            color: successColor
                            font.bold: true
                            font.pixelSize: fontSmall
                        }
                    }
                    
                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: seleccionarProductoExistente(model.id, model.codigo, model.nombre)
                    }
                }
            }
        }
    }

    // CONEXIONES
    Connections {
        target: compraModel
        function onItemsCompraCambiado() {
            updatePurchaseTotal()
        }
    }

    Component.onCompleted: {
        console.log("✅ CrearCompra.qml inicializado - FIFO 2.0 con cálculos automáticos")
        
        if (!compraModel || !inventarioModel) {
            console.log("⚠️ Models no disponibles aún")
            
            Qt.callLater(function() {
                if (compraModel) {
                    console.log("✅ CompraModel disponible en retry")
                    updateProviderNames()
                    
                    if (compraModel.modo_edicion) {
                        cargarDatosEdicion()
                    }
                }
            })
        } else {
            console.log("✅ Models conectados correctamente")
            
            if (compraModel) {
                compraModel.force_refresh_proveedores()
                Qt.callLater(updateProviderNames)
                
                if (compraModel.modo_edicion) {
                    Qt.callLater(cargarDatosEdicion)
                }
            }
        }
        
        var fechaActual = new Date()
        var dia = fechaActual.getDate().toString().padStart(2, '0')
        var mes = (fechaActual.getMonth() + 1).toString().padStart(2, '0')
        var año = fechaActual.getFullYear()
        newPurchaseDate = dia + "/" + mes + "/" + año
        
        if (!modoEdicion) {
            newPurchaseId = "C" + String((compraModel ? compraModel.total_compras_mes : 0) + 1).padStart(3, '0')
        }
        
        Qt.callLater(function() {
            if (productCodeField) {
                productCodeField.focus = true
            }
        })
    }
}