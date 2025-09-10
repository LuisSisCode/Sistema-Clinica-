import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15

// Componente independiente para crear nueva compra - SIN gestión de proveedores
Item {
    id: crearCompraRoot
    
    // Propiedades de comunicación con el componente padre
    property var inventarioModel: null
    property var ventaModel: null
    property var compraModel: null
    
    // Señales para comunicación
    signal compraCompletada()
    signal cancelarCompra()
    
    // SISTEMA DE MÉTRICAS COHERENTE Y BIEN ESTRUCTURADO
    readonly property real scaleFactor: Math.min(width / 1400, height / 900)
    readonly property real baseUnit: Math.max(8, height / 100)
    readonly property real fontBaseSize: Math.max(13, height / 65)
    
    // Tamaños de fuente consistentes
    readonly property real fontSmall: fontBaseSize * 0.85
    readonly property real fontMedium: fontBaseSize
    readonly property real fontLarge: fontBaseSize * 1.2
    readonly property real fontXLarge: fontBaseSize * 1.4
    readonly property real fontHeader: fontBaseSize * 1.6
    
    // Espaciados uniformes
    readonly property real spacing4: baseUnit * 0.5
    readonly property real spacing8: baseUnit
    readonly property real spacing12: baseUnit * 1.5
    readonly property real spacing16: baseUnit * 2
    readonly property real spacing20: baseUnit * 2.5
    readonly property real spacing24: baseUnit * 3
    
    // Alturas estándar
    readonly property real inputHeight: Math.max(36, baseUnit * 4.5)
    readonly property real buttonHeight: Math.max(40, baseUnit * 5)
    readonly property real headerHeight: Math.max(80, baseUnit * 10)
    
    // Radios uniformes
    readonly property real radiusSmall: 6
    readonly property real radiusMedium: 8
    readonly property real radiusLarge: 12

    // Colores del tema
    property color primaryColor: "#273746"
    property color successColor: "#27ae60"
    property color warningColor: "#f39c12"
    property color dangerColor: "#e74c3c"
    property color blueColor: "#3498db"
    property color whiteColor: "#ffffff"
    property color textColor: "#2c3e50"
    property color darkGrayColor: "#7f8c8d"
    property color lightGrayColor: "#bdc3c7"

    // Estados de la interfaz
    property bool showSuccessMessage: false
    property string successMessage: ""
    property bool showProductDropdown: false
    
    // Datos para nueva compra
    property string newPurchaseProvider: ""
    property string newPurchaseUser: "Dr. Admin"
    property string newPurchaseDate: "04/07/2025"
    property string newPurchaseId: "C" + String((compraModel ? compraModel.total_compras_mes : 0) + 1).padStart(3, '0')
    property real newPurchaseTotal: 0.0
    property string newPurchaseDetails: ""
    
    // Campos de entrada para productos
    property string inputProductCode: ""
    property string inputProductName: ""
    property int inputBoxes: 0
    property int inputUnits: 0
    property int inputTotalStock: 0
    property real inputPurchasePrice: 0.0
    property real inputSalePrice: 0.0
    property string inputExpiryDate: ""
    property bool isNewProduct: true
    
    // Lista temporal de productos para la nueva compra
    ListModel {
        id: temporaryProductsModel
    }
    
    // Modelo para resultados de búsqueda de productos existentes
    ListModel {
        id: productSearchResultsModel
    }
    
    // PROPIEDADES PARA PROVEEDORES - SIMPLIFICADO
    property var providerNames: ["Seleccionar proveedor..."]

    // Timer para ocultar mensaje de éxito
    Timer {
        id: successTimer
        interval: 3000
        onTriggered: showSuccessMessage = false
    }

    // CONEXIÓN CON DATOS CENTRALES
    Connections {
        target: compraModel
        function onProveedoresChanged() {
            console.log("🚚 CrearCompra: Signal proveedoresChanged recibido")
            updateProviderNames()
        }
        
        function onOperacionExitosa(mensaje) {
            if (mensaje.includes("proveedores") || mensaje.includes("actualizada")) {
                console.log("📢 Operación exitosa relacionada con proveedores:", mensaje)
                Qt.callLater(updateProviderNames)
            }
        }
    }

    // FUNCIONES DE NEGOCIO
    // Función simplificada para actualizar proveedores desde el modelo central
    function updateProviderNames() {
        var names = ["Seleccionar proveedor..."]
        
        if (compraModel && compraModel.proveedores) {
            var proveedores = compraModel.proveedores
            console.log("📝 Proveedores disponibles:", proveedores.length)
            
            for (var i = 0; i < proveedores.length; i++) {
                var provider = proveedores[i]
                if (provider && (provider.Nombre || provider.nombre)) {
                    var nombreProveedor = provider.Nombre || provider.nombre
                    names.push(nombreProveedor)
                    console.log("✅ Proveedor agregado:", nombreProveedor)
                }
            }
            
            console.log("📋 Lista final de proveedores:", names)
        } else {
            console.log("❌ CompraModel o proveedores no disponibles")
            
            // ✅ FALLBACK: Intentar force refresh si no hay datos
            if (compraModel) {
                console.log("🔄 Intentando force refresh como fallback...")
                compraModel.force_refresh_proveedores()
            }
        }
        
        providerNames = names
    }
    Timer {
        id: autoRefreshTimer
        interval: 30000  // 30 segundos
        running: false
        repeat: true
        onTriggered: {
            console.log("⏰ Auto-refresh de proveedores")
            if (compraModel) {
                compraModel.refresh_proveedores()
            }
        }
    }
    
    function updatePurchaseTotal() {
        var total = 0.0
        for (var i = 0; i < temporaryProductsModel.count; i++) {
            var item = temporaryProductsModel.get(i)
            total += item.precioCompra
        }
        newPurchaseTotal = total
    }

    // FUNCIÓN: Buscar productos existentes usando datos centrales
    function buscarProductosExistentes(texto) {
        console.log("🔍 CrearCompra: Buscando productos existentes:", texto)
        productSearchResultsModel.clear()
        
        if (!inventarioModel || texto.length < 2) {
            showProductDropdown = false
            return
        }
        
        var textoBusqueda = texto.toLowerCase()
        
        // Buscar con InventarioModel
        inventarioModel.buscar_productos(textoBusqueda)
        
        // Esperar un poco para que se actualicen los resultados
        Qt.callLater(function() {
            var resultados = inventarioModel.search_results || []
            console.log("🔍 Resultados obtenidos:", resultados.length)
            
            if (resultados.length > 0) {
                for (var i = 0; i < resultados.length; i++) {
                    var producto = resultados[i]
                    
                    productSearchResultsModel.append({
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
            
            console.log("📦 CrearCompra: Productos en dropdown:", productSearchResultsModel.count)
        })
    }

    // FUNCIÓN NUEVA: Seleccionar producto existente
    function seleccionarProductoExistente(codigo, nombre) {
        console.log("✅ Seleccionando producto existente:", codigo, nombre)
        
        inputProductCode = codigo
        inputProductName = nombre
        isNewProduct = false
        
        showProductDropdown = false
        
        // Actualizar el TextField para mostrar el nombre
        productCodeField.text = nombre
        
        // Enfocar el campo de cajas
        Qt.callLater(function() {
            if (boxesField) {
                boxesField.focus = true
            }
        })
        
        showSuccess("📦 Producto seleccionado: " + nombre + " (stock se agregará al existente)")
    }
    
    // Función: Agregar producto MEJORADA
    function addProductToPurchase() {
        // Validar campos obligatorios
        if (inputProductCode.length === 0) {
            showSuccess("⚠ Error: Ingrese el código del producto")
            return false
        }
        
        if (inputProductName.length === 0) {
            showSuccess("⚠ Error: Ingrese el nombre del producto")
            return false
        }
        
        if (inputBoxes <= 0 && inputUnits <= 0) {
            showSuccess("⚠ Error: Ingrese cantidad de cajas o unidades")
            return false
        }
        
        if (inputPurchasePrice <= 0) {
            showSuccess("⚠ Error: El precio de compra debe ser mayor a 0")
            return false
        }
        
        // Validar fecha de vencimiento
        if (inputExpiryDate.length > 0 && !validateExpiryDate(inputExpiryDate)) {
            showSuccess("⚠ Error: Fecha de vencimiento inválida (DD/MM/YYYY)")
            return false
        }
        
        // Verificar si el producto ya está en la lista temporal
        for (var i = 0; i < temporaryProductsModel.count; i++) {
            var item = temporaryProductsModel.get(i)
            if (item.codigo === inputProductCode) {
                showSuccess("⚠ Error: El producto ya está agregado a esta compra")
                return false
            }
        }
        
        var subtotalCompra = inputPurchasePrice * inputTotalStock
        // Agregar a la lista temporal con información de si es nuevo
        temporaryProductsModel.append({
            "codigo": inputProductCode,
            "nombre": inputProductName,
            "cajas": inputBoxes,
            "unidades": inputUnits,
            "stockTotal": inputTotalStock,
            "precioCompra": inputPurchasePrice,
            "fechaVencimiento": inputExpiryDate.length > 0 ? inputExpiryDate : "Sin fecha"
        })
        
        // Actualizar total de la compra
        updatePurchaseTotal()
        // Mostrar mensaje de éxito
        var tipoProducto = isNewProduct ? "🆕 Producto nuevo agregado" : "📦 Stock agregado a producto existente"
        showSuccess(tipoProducto + ": " + inputProductName)
        
        // Limpiar campos
        clearProductFields()
        
        return true
    }

    // NUEVA FUNCIÓN: Calcular stock total automáticamente
    function calculateTotalStock() {
        // Solo multiplicar si hay cajas, sino usar las unidades directamente
        if (inputBoxes > 0) {
            inputTotalStock = (inputBoxes * inputUnits)
        } else {
            inputTotalStock = inputUnits
        }
        
        // Sincronizar el campo visual:
        if (totalStockField) totalStockField.text = inputTotalStock.toString()
    }

    // Función: Limpiar campos del formulario MEJORADA
    function clearProductFields() {
        inputProductCode = ""
        inputProductName = ""
        inputBoxes = 0
        inputUnits = 0
        inputTotalStock = 0
        inputPurchasePrice = 0.0
        inputExpiryDate = ""
        isNewProduct = true
        showProductDropdown = false
        productSearchResultsModel.clear()
        
        // Limpiar campos de interfaz
        if (productCodeField) productCodeField.text = ""
        if (boxesField) boxesField.text = ""
        if (unitsField) unitsField.text = ""
        if (totalStockField) totalStockField.text = ""
        if (purchasePriceField) purchasePriceField.text = ""
        if (expiryField) expiryField.text = ""

        calculateTotalStock()
    }

    // Función: Autocompletar fecha con "/"
    function autoFormatDate(input) {
        // Remover caracteres no numéricos excepto "/"
        var cleaned = input.replace(/[^\d\/]/g, '')
        
        // Auto agregar "/" después de DD y MM
        if (cleaned.length === 2 && !cleaned.includes('/')) {
            cleaned += '/'
        } else if (cleaned.length === 5 && cleaned.split('/').length === 2) {
            cleaned += '/'
        }
        
        // Limitar a formato DD/MM/YYYY
        if (cleaned.length > 10) {
            cleaned = cleaned.substring(0, 10)
        }
        
        return cleaned
    }

    // Función: Validar fecha de vencimiento
    function validateExpiryDate(dateStr) {
        if (dateStr.length === 0) return true
        
        var regex = /^\d{2}\/\d{2}\/\d{4}$/
        if (!regex.test(dateStr)) return false
        
        var parts = dateStr.split('/')
        var day = parseInt(parts[0])
        var month = parseInt(parts[1])
        var year = parseInt(parts[2])
        
        if (month < 1 || month > 12) return false
        if (day < 1 || day > 31) return false
        if (year < 2025 || year > 2030) return false
        
        return true
    }

    // FUNCIÓN: Completar compra usando sistema central
    function completarCompra() {
        console.log("🚚 Iniciando proceso de completar compra...")
        
        if (!compraModel) {
            showSuccess("⚠ Error: Sistema de compras no disponible")
            return false
        }
        
        if (newPurchaseProvider === "") {
            showSuccess("⚠ Error: Seleccione un proveedor")
            return false
        }
        
        if (temporaryProductsModel.count === 0) {
            showSuccess("⚠ Error: Agregue al menos un producto")
            return false
        }
        
        // Convertir productos a array
        var productosArray = []
        var totalCalculado = 0
        
        for (var i = 0; i < temporaryProductsModel.count; i++) {
            var item = temporaryProductsModel.get(i)
            var productoCompra = {
                "codigo": item.codigo,
                "nombre": item.nombre,
                "cajas": item.cajas,
                "unidades": item.unidades,
                "stockTotal": item.stockTotal,
                "precioCompra": item.precioCompra,
                "precioVenta": item.precioVenta || (item.precioCompra * 1.25),
                "fechaVencimiento": item.fechaVencimiento
            }
            productosArray.push(productoCompra)
            totalCalculado += item.precioCompra
            
            console.log("🚚 Producto a comprar:", item.codigo, "- Stock:", item.stockTotal, "- Precio:", item.precioCompra)
        }
        
        console.log("🚚 Total calculado:", totalCalculado)
        
        // Llamar a la función central de farmacia
        var compraId = null
        try {
            console.log("🚚 Procesando compra con CompraModel...")

            // Encontrar ID del proveedor
            var proveedorId = 0
            var proveedores = compraModel.proveedores || []
            for (var p = 0; p < proveedores.length; p++) {
                var proveedor = proveedores[p]
                var nombreProveedor = proveedor.Nombre || proveedor.nombre
                if (nombreProveedor === newPurchaseProvider) {
                    proveedorId = proveedor.id
                    break
                }
            }

            if (proveedorId === 0) {
                showSuccess("⚠ Error: Proveedor no válido")
                return false
            }

            // Establecer proveedor y limpiar items previos
            compraModel.set_proveedor_seleccionado(proveedorId)
            compraModel.limpiar_items_compra()

            // Agregar items a CompraModel
            for (var j = 0; j < productosArray.length; j++) {
                var prod = productosArray[j]
                compraModel.agregar_item_compra(
                    prod.codigo,
                    prod.cajas || 0,
                    prod.stockTotal || prod.cantidad || 0,
                    prod.precioCompra,
                    prod.fechaVencimiento || "2025-12-31"
                )
            }
        } catch (e) {
            console.log("❌ Error al procesar compra:", e)
            showSuccess("⚠ Error inesperado al procesar la compra")
            return false
        }
        
        // Procesar la compra
        var exito = compraModel.procesar_compra_actual()
        compraId = exito ? "PROCESSED" : null

        if (compraId) {
            console.log("✅ Compra completada en sistema central:", compraId)
            
            // Limpiar formulario
            clearPurchase()
            clearProductFields()
            
            // Generar nuevo ID
            newPurchaseId = "C" + String((compraModel ? compraModel.total_compras_mes : 0) + 1).padStart(3, '0')
            
            // Mostrar mensaje y volver a lista
            showSuccess("✅ Compra " + compraId + " completada exitosamente")
            
            // Regresar automáticamente
            Qt.callLater(function() {
                console.log("🔙 Compra completada, regresando a lista...")
                compraCompletada() // Emitir señal
            })
            
            return true
        } else {
            showSuccess("⚠ Error: No se pudo completar la compra")
            return false
        }
    }

    // Función para limpiar toda la compra
    function clearPurchase() {
        temporaryProductsModel.clear()
        newPurchaseTotal = 0.0
        newPurchaseProvider = ""
        newPurchaseDetails = ""
    }

    // Función para mostrar mensajes de éxito
    function showSuccess(message) {
        successMessage = message
        showSuccessMessage = true
        successTimer.restart()
    }

    // ============================================================================
    // INTERFAZ DE USUARIO PRINCIPAL - SIN DIÁLOGO DE PROVEEDORES
    // ============================================================================
    
    Rectangle {
        anchors.fill: parent
        color: "#f8f9fa"
        
        // HEADER FIJO SIEMPRE VISIBLE
        Rectangle {
            id: fixedHeader
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: headerHeight
            color: whiteColor
            radius: radiusLarge
            border.color: "#e9ecef"
            border.width: 1
            z: 10
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: spacing16
                spacing: spacing16
                
                // Botón de regreso
                Button {
                    Layout.preferredWidth: 50
                    Layout.preferredHeight: 50
                    
                    background: Rectangle {
                        color: parent.pressed ? Qt.darker(blueColor, 1.2) : blueColor
                        radius: 25
                    }
                    
                    contentItem: Label {
                        text: "←"
                        color: whiteColor
                        font.bold: true
                        font.pixelSize: 20
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: cancelarCompra()
                }
                
                // Icono y título
                RowLayout {
                    spacing: spacing12
                    
                    Rectangle {
                        width: 40
                        height: 40
                        color: blueColor
                        radius: radiusMedium
                        
                        Label {
                            anchors.centerIn: parent
                            text: "🚚"
                            font.pixelSize: 20
                        }
                    }
                    
                    ColumnLayout {
                        spacing: spacing4
                        
                        Label {
                            text: "Nueva Compra"
                            font.pixelSize: fontHeader
                            font.bold: true
                            color: textColor
                        }
                        
                        RowLayout {
                            spacing: spacing16
                            
                            Label {
                                text: "Usuario: Dr. Admin"
                                color: textColor
                                font.pixelSize: fontMedium
                            }
                            
                            Label {
                                text: {
                                    var fechaActual = new Date()
                                    var dia = fechaActual.getDate().toString().padStart(2, '0')
                                    var mes = (fechaActual.getMonth() + 1).toString().padStart(2, '0')
                                    var año = fechaActual.getFullYear()
                                    var hora = fechaActual.getHours().toString().padStart(2, '0')
                                    var minutos = fechaActual.getMinutes().toString().padStart(2, '0')
                                    return "Fecha: " + dia + "/" + mes + "/" + año + " " + hora + ":" + minutos
                                }
                                color: textColor
                                font.pixelSize: fontMedium
                            }
                        }
                    }
                }
                
                Item { Layout.fillWidth: true }
                
                Label {
                    text: "No. Compra: " + newPurchaseId
                    color: blueColor
                    font.pixelSize: fontLarge
                    font.bold: true
                }
            }
        }
        
        // CONTENIDO PRINCIPAL CON SCROLLVIEW
        ScrollView {
            id: mainScrollView
            anchors.top: fixedHeader.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: spacing16
            anchors.topMargin: spacing8
            clip: true
            
            // Contenedor del contenido scrolleable
            ColumnLayout {
                width: mainScrollView.width
                spacing: spacing20
                
                // SECCIÓN 1: INFORMACIÓN DE COMPRA Y BÚSQUEDA DE PRODUCTOS
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 400
                    color: "#E3F2FD"
                    radius: radiusLarge
                    border.color: blueColor
                    border.width: 2
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: spacing20
                        spacing: spacing16
                        
                        // Fila 1: Selección de proveedor - SIMPLIFICADO
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: spacing12
                            
                            Label {
                                text: "🏢 Proveedor:"
                                font.pixelSize: fontLarge
                                font.bold: true
                                color: textColor
                            }
                            
                            ComboBox {
                                id: providerCombo
                                Layout.preferredWidth: 300
                                Layout.preferredHeight: inputHeight
                                model: crearCompraRoot.providerNames
                                font.pixelSize: fontMedium
                                
                                background: Rectangle {
                                    color: whiteColor
                                    border.color: darkGrayColor
                                    border.width: 1
                                    radius: radiusMedium
                                }
                                
                                onCurrentTextChanged: {
                                    if (currentIndex > 0) {
                                        newPurchaseProvider = currentText
                                    } else {
                                        newPurchaseProvider = ""
                                    }
                                }
                                
                                Connections {
                                    target: crearCompraRoot
                                    function onProviderNamesChanged() {
                                        providerCombo.model = crearCompraRoot.providerNames
                                    }
                                }
                            }
                            Button {
                                Layout.preferredWidth: 40
                                Layout.preferredHeight: inputHeight
                                
                                background: Rectangle {
                                    color: parent.pressed ? Qt.darker(blueColor, 1.2) : blueColor
                                    radius: radiusMedium
                                }
                                
                                contentItem: Label {
                                    text: "🔄"
                                    color: whiteColor
                                    font.pixelSize: 16
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                
                                onClicked: refreshProveedoresManual()
                                
                                ToolTip.visible: hovered
                                ToolTip.text: "Actualizar lista de proveedores"
                            }
                            
                            Label {
                                text: "💡 Para gestionar proveedores, usa Farmacia → Proveedores. Presiona 🔄 para actualizar."
                                color: "#666"
                                font.pixelSize: fontSmall
                                font.italic: true
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                            }
                        }
                        
                        // Fila 2: Título de búsqueda
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: spacing8
                            
                            Label {
                                text: "🔍"
                                font.pixelSize: 18
                            }
                            
                            Label {
                                text: "BUSCAR PRODUCTO EXISTENTE O CREAR NUEVO"
                                color: textColor
                                font.bold: true
                                font.pixelSize: fontLarge
                            }
                        }
                        
                        // Fila 3: Campo de búsqueda
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: spacing8
                            
                            Label {
                                text: "Buscar producto o ingresar código nuevo:"
                                color: darkGrayColor
                                font.pixelSize: fontMedium
                            }
                            
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: inputHeight
                                color: whiteColor
                                radius: radiusMedium
                                border.color: productCodeField.activeFocus ? blueColor : darkGrayColor
                                border.width: 1
                                
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: spacing8
                                    spacing: spacing8
                                    
                                    Label {
                                        text: "🔍"
                                        color: darkGrayColor
                                        font.pixelSize: 16
                                    }
                                    
                                    TextField {
                                        id: productCodeField
                                        Layout.fillWidth: true
                                        placeholderText: "Código o nombre del producto..."
                                        text: inputProductName.length > 0 ? inputProductName : inputProductCode
                                        background: Rectangle { color: "transparent" }
                                        font.pixelSize: fontMedium
                                        
                                        onTextChanged: {
                                            // Si es un producto seleccionado, no buscar de nuevo
                                            if (inputProductName.length > 0 && text === inputProductName) {
                                                return
                                            }
                                            
                                            // Limpiar selección anterior si se está editando
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
                                }
                            }
                            
                            // Dropdown de productos encontrados
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.min(120, productSearchResultsModel.count * 40)
                                color: whiteColor
                                border.color: blueColor
                                border.width: 1
                                radius: radiusMedium
                                visible: showProductDropdown
                                z: 100
                                
                                ListView {
                                    anchors.fill: parent
                                    anchors.margins: spacing4
                                    model: productSearchResultsModel
                                    clip: true
                                    
                                    delegate: Rectangle {
                                        width: ListView.view.width
                                        height: 40
                                        color: mouseArea.containsMouse ? "#E3F2FD" : "transparent"
                                        radius: radiusSmall
                                        
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: spacing8
                                            spacing: spacing8
                                            
                                            Rectangle {
                                                Layout.preferredWidth: 60
                                                Layout.preferredHeight: 20
                                                color: blueColor
                                                radius: 10
                                                
                                                Label {
                                                    anchors.centerIn: parent
                                                    text: model.codigo
                                                    color: whiteColor
                                                    font.bold: true
                                                    font.pixelSize: fontSmall
                                                }
                                            }
                                            
                                            Label {
                                                text: model.nombre
                                                color: textColor
                                                font.pixelSize: fontMedium
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }
                                            
                                            Label {
                                                text: "Bs" + model.precioVentaBase.toFixed(2)
                                                color: successColor
                                                font.bold: true
                                                font.pixelSize: fontMedium
                                            }
                                        }
                                        
                                        MouseArea {
                                            id: mouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: seleccionarProductoExistente(model.codigo, model.nombre)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Fila 4: Campos de entrada de datos
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 6
                            columnSpacing: spacing12
                            rowSpacing: spacing8
                            
                            // Cajas
                            ColumnLayout {
                                spacing: spacing4
                                
                                Label {
                                    text: "Cajas:"
                                    color: darkGrayColor
                                    font.pixelSize: fontMedium
                                    font.bold: true
                                }
                                
                                TextField {
                                    id: boxesField
                                    Layout.preferredWidth: 70
                                    Layout.preferredHeight: inputHeight
                                    placeholderText: "0"
                                    text: inputBoxes > 0 ? inputBoxes.toString() : ""
                                    background: Rectangle {
                                        color: whiteColor
                                        radius: radiusMedium
                                        border.color: parent.activeFocus ? successColor : darkGrayColor
                                        border.width: 1
                                    }
                                    validator: IntValidator { bottom: 0; top: 9999 }
                                    font.pixelSize: fontMedium
                                    horizontalAlignment: Text.AlignHCenter
                                    onTextChanged: {
                                        var newValue = text.length > 0 ? (parseInt(text) || 0) : 0
                                        if (inputBoxes !== newValue) {
                                            inputBoxes = newValue
                                            calculateTotalStock()
                                        }
                                    }
                                }
                            }
                            
                            // Unidades
                            ColumnLayout {
                                spacing: spacing4
                                
                                Label {
                                    text: "Unidades:"
                                    color: darkGrayColor
                                    font.pixelSize: fontMedium
                                    font.bold: true
                                }
                                
                                TextField {
                                    id: unitsField
                                    Layout.preferredWidth: 70
                                    Layout.preferredHeight: inputHeight
                                    placeholderText: "0"
                                    text: inputUnits > 0 ? inputUnits.toString() : ""
                                    background: Rectangle {
                                        color: whiteColor
                                        radius: radiusMedium
                                        border.color: parent.activeFocus ? successColor : darkGrayColor
                                        border.width: 1
                                    }
                                    validator: IntValidator { bottom: 0; top: 9999 }
                                    font.pixelSize: fontMedium
                                    horizontalAlignment: Text.AlignHCenter
                                    onTextChanged: {
                                        var newValue = text.length > 0 ? (parseInt(text) || 0) : 0
                                        if (inputUnits !== newValue) {
                                            inputUnits = newValue
                                            calculateTotalStock()
                                        }
                                    }
                                }
                            }
                            
                            // Stock Total
                            ColumnLayout {
                                spacing: spacing4
                                
                                Label {
                                    text: "Stock Total:"
                                    color: darkGrayColor
                                    font.pixelSize: fontMedium
                                    font.bold: true
                                }
                                
                                TextField {
                                    id: totalStockField
                                    Layout.preferredWidth: 80
                                    Layout.preferredHeight: inputHeight
                                    placeholderText: "0"
                                    text: inputTotalStock > 0 ? inputTotalStock.toString() : ""
                                    background: Rectangle {
                                        color: whiteColor
                                        radius: radiusMedium
                                        border.color: parent.activeFocus ? blueColor : darkGrayColor
                                        border.width: 1
                                    }
                                    validator: IntValidator { bottom: 0; top: 99999 }
                                    font.pixelSize: fontMedium
                                    horizontalAlignment: Text.AlignHCenter
                                    onTextChanged: {
                                        inputTotalStock = text.length > 0 ? (parseInt(text) || 0) : 0
                                    }
                                }
                            }
                            
                            // Precio Compra
                            ColumnLayout {
                                spacing: spacing4
                                
                                Label {
                                    text: "Precio Compra:"
                                    color: darkGrayColor
                                    font.pixelSize: fontMedium
                                    font.bold: true
                                }
                                
                                TextField {
                                    id: purchasePriceField
                                    Layout.preferredWidth: 80
                                    Layout.preferredHeight: inputHeight
                                    placeholderText: "0.00"
                                    text: inputPurchasePrice > 0 ? inputPurchasePrice.toString() : ""
                                    background: Rectangle {
                                        color: whiteColor
                                        radius: radiusMedium
                                        border.color: parent.activeFocus ? successColor : darkGrayColor
                                        border.width: 1
                                    }
                                    font.pixelSize: fontMedium
                                    horizontalAlignment: Text.AlignHCenter
                                    onEditingFinished: {
                                        inputPurchasePrice = text.length > 0 ? (parseFloat(text) || 0.0) : 0.0
                                    }
                                }
                            }
                            
                            // Fecha Vencimiento
                            ColumnLayout {
                                spacing: spacing4
                                
                                Label {
                                    text: "F. Vencimiento:"
                                    color: darkGrayColor
                                    font.pixelSize: fontMedium
                                    font.bold: true
                                }
                                
                                TextField {
                                    id: expiryField
                                    Layout.preferredWidth: 100
                                    Layout.preferredHeight: inputHeight
                                    placeholderText: "DD/MM/YYYY"
                                    text: inputExpiryDate
                                    background: Rectangle {
                                        color: whiteColor
                                        radius: radiusMedium
                                        border.color: parent.activeFocus ? "#9C27B0" : darkGrayColor
                                        border.width: 1
                                    }
                                    font.pixelSize: fontMedium
                                    onTextChanged: {
                                        var formatted = autoFormatDate(text)
                                        if (formatted !== text) {
                                            text = formatted
                                        }
                                        inputExpiryDate = text
                                    }
                                }
                            }
                            
                            // Botón Agregar
                            Button {
                                Layout.topMargin: spacing20
                                Layout.preferredHeight: buttonHeight
                                Layout.preferredWidth: 100
                                text: "Agregar"
                                enabled: inputProductCode.length > 0 && inputProductName.length > 0 && 
                                        inputTotalStock > 0 && inputPurchasePrice > 0
                                background: Rectangle {
                                    color: enabled ? successColor : darkGrayColor
                                    radius: radiusMedium
                                }
                                contentItem: Label {
                                    text: parent.text
                                    color: whiteColor
                                    font.bold: true
                                    font.pixelSize: fontMedium
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                onClicked: addProductToPurchase()
                            }
                        }
                    }
                }
                
                // SECCIÓN 2: LISTA DE PRODUCTOS
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 350
                    color: "#F8F9FA"
                    radius: radiusLarge
                    border.color: lightGrayColor
                    border.width: 1
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: spacing16
                        spacing: spacing12
                        
                        // Header de la lista
                        RowLayout {
                            Layout.fillWidth: true
                            
                            Label {
                                text: "📦"
                                font.pixelSize: 18
                            }
                            
                            Label {
                                text: "Productos en la compra: " + temporaryProductsModel.count
                                color: textColor
                                font.bold: true
                                font.pixelSize: fontLarge
                            }
                        }

                        // Tabla de productos
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
                                
                                // Header de la tabla
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 45
                                    color: "#F8F9FA"
                                    
                                    RowLayout {
                                        anchors.fill: parent
                                        spacing: 0
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 100
                                            Layout.fillHeight: true
                                            color: "#F8F9FA"
                                            border.color: "#D5DBDB"
                                            border.width: 1
                                            
                                            Label {
                                                anchors.centerIn: parent
                                                text: "CÓDIGO"
                                                font.bold: true
                                                font.pixelSize: fontMedium
                                                color: textColor
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 200
                                            Layout.fillHeight: true
                                            color: "#F8F9FA"
                                            border.color: "#D5DBDB"
                                            border.width: 1
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.leftMargin: spacing8
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "NOMBRE"
                                                color: textColor
                                                font.bold: true
                                                font.pixelSize: fontMedium
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
                                                text: "CAJAS"
                                                color: textColor
                                                font.bold: true
                                                font.pixelSize: fontMedium
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
                                                text: "STOCK TOTAL"
                                                color: textColor
                                                font.bold: true
                                                font.pixelSize: fontMedium
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 120
                                            Layout.fillHeight: true
                                            color: "#F8F9FA"
                                            border.color: "#D5DBDB"
                                            border.width: 1
                                            
                                            Label {
                                                anchors.centerIn: parent
                                                text: "PRECIO COMPRA"
                                                color: textColor
                                                font.bold: true
                                                font.pixelSize: fontMedium
                                            }
                                        }
                                    }
                                }
                                
                                // Contenido de la tabla
                                ScrollView {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true
                                    
                                    ListView {
                                        anchors.fill: parent
                                        model: temporaryProductsModel
                                        
                                        delegate: Item {
                                            width: ListView.view.width
                                            height: 50
                                            
                                            RowLayout {
                                                anchors.fill: parent
                                                spacing: 0
                                                
                                                // CÓDIGO
                                                Rectangle {
                                                    Layout.preferredWidth: 100
                                                    Layout.fillHeight: true
                                                    color: "transparent"
                                                    border.color: "#D5DBDB"
                                                    border.width: 1
                                                    
                                                    Label {
                                                        anchors.centerIn: parent
                                                        text: model.codigo
                                                        color: textColor
                                                        font.bold: true
                                                        font.pixelSize: fontMedium
                                                    }
                                                }
                                                
                                                // NOMBRE + BOTÓN ELIMINAR
                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    Layout.minimumWidth: 200
                                                    Layout.fillHeight: true
                                                    color: "transparent"
                                                    border.color: "#D5DBDB"
                                                    border.width: 1
                                                    
                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.margins: spacing8
                                                        spacing: spacing8
                                                        
                                                        Label {
                                                            text: model.nombre
                                                            color: textColor
                                                            font.bold: true
                                                            font.pixelSize: fontMedium
                                                            elide: Text.ElideRight
                                                            Layout.fillWidth: true
                                                        }
                                                        
                                                        Button {
                                                            width: 25
                                                            height: 25
                                                            text: "🗑️"
                                                            background: Rectangle {
                                                                color: dangerColor
                                                                radius: 12
                                                            }
                                                            contentItem: Label {
                                                                text: parent.text
                                                                color: whiteColor
                                                                font.pixelSize: fontSmall
                                                                horizontalAlignment: Text.AlignHCenter
                                                                verticalAlignment: Text.AlignVCenter
                                                            }
                                                            onClicked: {
                                                                temporaryProductsModel.remove(index)
                                                                updatePurchaseTotal()
                                                            }
                                                        }
                                                    }
                                                }
                                                
                                                // CAJAS
                                                Rectangle {
                                                    Layout.preferredWidth: 80
                                                    Layout.fillHeight: true
                                                    color: "transparent"
                                                    border.color: "#D5DBDB"
                                                    border.width: 1
                                                    
                                                    Rectangle {
                                                        anchors.centerIn: parent
                                                        width: 40
                                                        height: 20
                                                        color: warningColor
                                                        radius: 10
                                                        
                                                        Label {
                                                            anchors.centerIn: parent
                                                            text: model.cajas
                                                            color: whiteColor
                                                            font.bold: true
                                                            font.pixelSize: fontSmall
                                                        }
                                                    }
                                                }
                                                
                                                // STOCK TOTAL
                                                Rectangle {
                                                    Layout.preferredWidth: 100
                                                    Layout.fillHeight: true
                                                    color: "transparent"
                                                    border.color: "#D5DBDB"
                                                    border.width: 1
                                                    
                                                    Rectangle {
                                                        anchors.centerIn: parent
                                                        width: 50
                                                        height: 20
                                                        color: "#9B59B6"
                                                        radius: 10
                                                        
                                                        Label {
                                                            anchors.centerIn: parent
                                                            text: model.stockTotal
                                                            color: whiteColor
                                                            font.bold: true
                                                            font.pixelSize: fontSmall
                                                        }
                                                    }
                                                }
                                                
                                                // PRECIO COMPRA
                                                Rectangle {
                                                    Layout.preferredWidth: 120
                                                    Layout.fillHeight: true
                                                    color: "transparent"
                                                    border.color: "#D5DBDB"
                                                    border.width: 1
                                                    
                                                    Label {
                                                        anchors.centerIn: parent
                                                        text: "Bs" + model.precioCompra.toFixed(2)
                                                        color: successColor
                                                        font.bold: true
                                                        font.pixelSize: fontMedium
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                // Estado vacío
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    visible: temporaryProductsModel.count === 0
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "No hay productos agregados aún"
                                        color: darkGrayColor
                                        font.italic: true
                                        font.pixelSize: fontLarge
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }
                            }
                        }
                    }
                }
                
                // SECCIÓN 3: TOTAL Y ACCIONES
                RowLayout {
                    Layout.fillWidth: true
                    spacing: spacing16
                    
                    Item { Layout.fillWidth: true }
                    
                    // Total de la compra
                    Rectangle {
                        Layout.preferredWidth: 200
                        Layout.preferredHeight: 50
                        color: newPurchaseTotal > 0 ? successColor : darkGrayColor
                        radius: radiusMedium
                        
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: spacing8
                            
                            Label {
                                text: "💰"
                                color: whiteColor
                                font.pixelSize: 18
                            }
                            
                            Label {
                                text: "TOTAL: Bs" + newPurchaseTotal.toFixed(2)
                                color: whiteColor
                                font.bold: true
                                font.pixelSize: fontLarge
                            }
                        }
                    }
                    
                    // Botón cancelar
                    Button {
                        text: "✖ Cancelar"
                        Layout.preferredHeight: buttonHeight
                        background: Rectangle {
                            color: dangerColor
                            radius: radiusMedium
                        }
                        contentItem: Label {
                            text: parent.text
                            color: whiteColor
                            font.bold: true
                            font.pixelSize: fontMedium
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: {
                            clearPurchase()
                            clearProductFields()
                            if (providerCombo) providerCombo.currentIndex = 0
                            cancelarCompra()
                        }
                    }
                    
                    // Botón completar compra
                    Button {
                        id: completarCompraButton
                        text: "💾 Completar Compra"
                        Layout.preferredHeight: buttonHeight
                        enabled: (providerCombo ? providerCombo.currentIndex > 0 : false) && temporaryProductsModel.count > 0
                        background: Rectangle {
                            color: enabled ? successColor : darkGrayColor
                            radius: radiusMedium
                        }
                        contentItem: Label {
                            text: parent.text
                            color: whiteColor
                            font.bold: true
                            font.pixelSize: fontMedium
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: {
                            if (completarCompra()) {
                                completarCompraButton.text = "✅ ¡Completado!"
                                Qt.callLater(function() {
                                    completarCompraButton.text = "💾 Completar Compra"
                                })
                            }
                        }
                    }
                }
                
                // Espacio adicional al final para scroll completo
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: spacing24
                }
            }
        }
        
        // NOTIFICACIÓN DE ÉXITO (FIJA)
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: spacing16
            height: 50
            color: successColor
            radius: radiusMedium
            visible: showSuccessMessage
            opacity: showSuccessMessage ? 1.0 : 0.0
            z: 20
            
            Behavior on opacity {
                NumberAnimation { duration: 300 }
            }
            
            RowLayout {
                anchors.centerIn: parent
                spacing: spacing12
                
                Rectangle {
                    width: 30
                    height: 30
                    color: whiteColor
                    radius: 15
                    
                    Label {
                        anchors.centerIn: parent
                        text: "✅"
                        color: successColor
                        font.pixelSize: 16
                    }
                }
                
                Label {
                    text: successMessage
                    color: whiteColor
                    font.bold: true
                    font.pixelSize: fontMedium
                }
            }
        }
    }
    function refreshProveedoresManual() {
        console.log("🔄 Refrescando proveedores...")
        if (compraModel) {
            // 1. Force refresh con nuevo método
            compraModel.force_refresh_proveedores()
            
            // 2. Debug info
            compraModel.debug_proveedores_info()
            
            // 3. Actualizar lista después de un momento
            Qt.callLater(function() {
                updateProviderNames()
                
                // 4. Log final
                console.log("📋 Proveedores después de refresh:", providerNames.length)
            })
        } else {
            console.log("❌ CompraModel no disponible")
        }
    }

    // INICIALIZACIÓN
    Component.onCompleted: {
        console.log("✅ CrearCompra.qml inicializado (sin gestión de proveedores)")
        
        // Verificar models disponibles
        if (!compraModel || !inventarioModel) {
            console.log("⚠️ Models no disponibles aún")
            
            // Retry después de un momento
            Qt.callLater(function() {
                if (compraModel) {
                    console.log("✅ CompraModel disponible en retry")
                    updateProviderNames()
                }
            })
        } else {
            console.log("✅ Models conectados correctamente")
            
            // Refresh inicial
            compraModel.force_refresh_proveedores()
            Qt.callLater(updateProviderNames)
        }
        
        // Focus en campo de producto
        Qt.callLater(function() {
            if (productCodeField) {
                productCodeField.focus = true
            }
        })
        
        // Iniciar auto-refresh (opcional)
        // autoRefreshTimer.start()
    }
}