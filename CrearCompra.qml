import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15

// Componente independiente para crear nueva compra - SIN gestión de proveedores
Item {
    id: crearCompraRoot
    
    // Propiedades de comunicación con el componente padre
    property var inventarioModel: parent.inventarioModel || nul
    property var ventaModel: null
    property var compraModel: null
    property bool modoEdicion: false
    property int compraIdEdicion: 0
    property var datosCompraOriginal: null
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
    property int inputStock: 0
    property real inputPurchasePrice: 0.0  // ESTE ES EL COSTO TOTAL DEL PRODUCTO (NO UNITARIO)
    property real inputSalePrice: 0.0
    property string inputExpiryDate: ""
    property bool inputNoExpiry: false
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
            
            if (compraModel) {
                console.log("🔄 Intentando force refresh como fallback...")
                compraModel.force_refresh_proveedores()
            }
        }
        
        providerNames = names
    }
    // FUNCIÓN PARA CARGAR DATOS DE COMPRA EN EDICIÓN
    function cargarDatosCompraEdicion() {
        if (!modoEdicion || compraIdEdicion <= 0 || !compraModel) {
            return
        }
        
        console.log("📝 Cargando datos para editar compra:", compraIdEdicion)
        
        // Obtener datos completos de la compra
        var datosCompra = compraModel.get_compra_detalle(compraIdEdicion)
        
        if (datosCompra && datosCompra.detalles) {
            // Establecer proveedor
            newPurchaseProvider = datosCompra.proveedor || ""
            
            // Buscar y establecer el proveedor en el combo
            for (var i = 0; i < providerNames.length; i++) {
                if (providerNames[i] === newPurchaseProvider) {
                    if (providerCombo) {
                        providerCombo.currentIndex = i
                    }
                    break
                }
            }
            
            // Limpiar productos temporales
            temporaryProductsModel.clear()
            
            // Cargar productos de la compra
            for (var j = 0; j < datosCompra.detalles.length; j++) {
                var detalle = datosCompra.detalles[j]
                
                temporaryProductsModel.append({
                    "codigo": detalle.codigo || "",
                    "nombre": detalle.nombre || "",
                    "stock": detalle.cantidad_unitario || 0,
                    "costoTotalProducto": detalle.costo_total || 0,
                    "fechaVencimiento": detalle.fecha_vencimiento || ""
                })
            }
            
            updatePurchaseTotal()
            console.log("✅ Datos de compra cargados - Productos:", temporaryProductsModel.count)
            showSuccess("📝 Compra cargada para edición")
        } else {
            console.log("❌ No se pudieron cargar los datos de la compra")
            showSuccess("⚠ Error cargando datos de la compra")
        }
    }
        
    Timer {
        id: autoRefreshTimer
        interval: 30000
        running: false
        repeat: true
        onTriggered: {
            console.log("⏰ Auto-refresh de proveedores")
            if (compraModel) {
                compraModel.refresh_proveedores()
            }
        }
    }
    
    // FUNCIÓN CORREGIDA: Solo suma los precios SIN multiplicar por cantidad
    function updatePurchaseTotal() {
        var total = 0.0
        for (var i = 0; i < temporaryProductsModel.count; i++) {
            var item = temporaryProductsModel.get(i)
            // CORRECCIÓN: Solo sumamos el precio ingresado (que ya es el costo total)
            total += item.costoTotalProducto
        }
        newPurchaseTotal = total
        console.log("💰 Total de compra actualizado:", total, "- Productos:", temporaryProductsModel.count)
    }

    function buscarProductosExistentes(texto) {
        console.log("🔍 CrearCompra: Buscando productos existentes:", texto)
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

    function seleccionarProductoExistente(codigo, nombre) {
        console.log("✅ Seleccionando producto existente:", codigo, nombre)
        
        inputProductCode = codigo
        inputProductName = nombre
        isNewProduct = false
        
        showProductDropdown = false
        
        productCodeField.text = nombre
        
        Qt.callLater(function() {
            if (stockField) {
                stockField.focus = true
            }
        })
        
        showSuccess("📦 Producto seleccionado: " + nombre + " (stock se agregará al existente)")
    }
    
    // FUNCIÓN CORREGIDA: Sin multiplicación, precio es el costo total
    function addProductToPurchase() {
        if (inputProductCode.length === 0) {
            showSuccess("⚠ Error: Ingrese el código del producto")
            return false
        }
        
        if (inputProductName.length === 0) {
            showSuccess("⚠ Error: Ingrese el nombre del producto")
            return false
        }
        
        if (inputStock <= 0) {  // CAMBIAR: solo validar stock
            showSuccess("⚠ Error: Ingrese cantidad de stock")
            return false
        }
        
        if (inputPurchasePrice <= 0) {
            showSuccess("⚠ Error: El precio debe ser mayor a 0")
            return false
        }
        
        if (!inputNoExpiry) {
            // Si NO es sin vencimiento, entonces SÍ requiere fecha válida
            if (inputExpiryDate.length === 0) {
                showSuccess("⚠ Error: Ingrese fecha de vencimiento o marque 'Sin vencimiento'")
                return false
            }
            if (!validateExpiryDate(inputExpiryDate)) {
                showSuccess("⚠ Error: Fecha de vencimiento inválida (YYYY-MM-DD)")
                return false
            }
        }
        
        for (var i = 0; i < temporaryProductsModel.count; i++) {
            var item = temporaryProductsModel.get(i)
            if (item.codigo === inputProductCode) {
                showSuccess("⚠ Error: El producto ya está agregado a esta compra")
                return false
            }
        }
        
        // CORRECCIÓN: El precio ingresado ES el costo total, no se multiplica
        temporaryProductsModel.append({
            "codigo": inputProductCode,
            "nombre": inputProductName,
            "stock": inputStock,
            "costoTotalProducto": inputPurchasePrice,  // COSTO TOTAL DEL PRODUCTO (lo que realmente pagamos)
            'fechaVencimiento': inputNoExpiry ? "" : inputExpiryDate
        })
        
        updatePurchaseTotal()
        showSuccess("Producto agregado: " + inputProductName + " - Stock: " + inputStock)
        clearProductFields()
        return true
    }

    function clearProductFields() {
        inputProductCode = ""
        inputProductName = ""
        inputStock = 0
        inputPurchasePrice = 0.0
        inputExpiryDate = ""
        inputNoExpiry = false
        isNewProduct = true
        showProductDropdown = false
        productSearchResultsModel.clear()
        
        if (productCodeField) productCodeField.text = ""
        if (stockField) stockField.text = "" 
        if (purchasePriceField) purchasePriceField.text = ""
        if (expiryField) expiryField.text = ""
    }

    function autoFormatDate(input) {
        // Permitir solo números y guiones
        var cleaned = input.replace(/[^\d\-]/g, '')
        
        // Si está vacío, permitirlo
        if (cleaned.length === 0) {
            return ""
        }
        
        // Auto-agregar guiones para YYYY-MM-DD
        if (cleaned.length === 4 && !cleaned.includes('-')) {
            return cleaned + '-'
        }
        if (cleaned.length === 7 && cleaned.indexOf('-') === 4 && cleaned.lastIndexOf('-') === 4) {
            return cleaned + '-'
        }
        
        // Si ya tiene formato YYYY-MM-DD válido, mantenerlo
        if (/^\d{4}-\d{2}-\d{2}$/.test(cleaned)) {
            return cleaned
        }
        
        // Permitir entrada progresiva con auto-guiones
        var result = cleaned
        
        // Agregar primer guión después de año (4 dígitos)
        if (result.length > 4 && result.charAt(4) !== '-') {
            result = result.substring(0, 4) + '-' + result.substring(4)
        }
        
        // Agregar segundo guión después de mes (7 caracteres = YYYY-MM)
        if (result.length > 7 && result.charAt(7) !== '-') {
            result = result.substring(0, 7) + '-' + result.substring(7)
        }
        
        // Limitar a 10 caracteres máximo (YYYY-MM-DD)
        if (result.length > 10) {
            result = result.substring(0, 10)
        }
        
        return result
    }

    function validateExpiryDate(dateStr) {
        // Permitir vacío (productos sin vencimiento)
        if (dateStr === "" || dateStr === "Sin vencimiento") return true;
        
        // Validar formato YYYY-MM-DD
        var regex = /^\d{4}-\d{2}-\d{2}$/;
        if (!regex.test(dateStr)) return false;
        
        var parts = dateStr.split('-');
        var year = parseInt(parts[0], 10);
        var month = parseInt(parts[1], 10);
        var day = parseInt(parts[2], 10);
        
        if (month < 1 || month > 12) return false;
        if (day < 1 || day > 31) return false;
        if (year < 2020 || year > 2050) return false; // Rango razonable
        
        // Validar días por mes
        var daysInMonth = new Date(year, month, 0).getDate();
        if (day > daysInMonth) return false;
        
        return true;
    }

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
        
        var productosArray = []
        var totalCalculado = 0
        
        for (var i = 0; i < temporaryProductsModel.count; i++) {
            var item = temporaryProductsModel.get(i)
            var productoCompra = {
                "codigo": item.codigo,
                "nombre": item.nombre,
                "cantidad_unitario": item.stock,
                "costoTotal": item.costoTotalProducto,  // COSTO TOTAL (no unitario)
               'fechaVencimiento': item.fechaVencimiento || ""  
            }
            productosArray.push(productoCompra)
            
            // CORRECCIÓN: Solo sumamos el costo total, sin multiplicar
            totalCalculado += item.costoTotalProducto
            
            console.log("🚚 Producto a comprar:", item.codigo, 
                       "- Stock:", item.stock, 
                       "- Costo total:", item.costoTotalProducto)
        }
        
        console.log("🚚 Total calculado:", totalCalculado)
        
        var compraId = null
        try {
            console.log("🚚 Procesando compra con CompraModel...")

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

            compraModel.set_proveedor_seleccionado(proveedorId)
            compraModel.limpiar_items_compra()

            for (var j = 0; j < productosArray.length; j++) {
                var prod = productosArray[j]
                compraModel.agregar_item_compra(
                    prod.codigo,
                    prod.cantidad_unitario,
                    prod.costoTotal,
                    prod.fechaVencimiento === null ? "" : prod.fechaVencimiento
                )
            }
        } catch (e) {
            console.log("❌ Error al procesar compra:", e)
            showSuccess("⚠ Error inesperado al procesar la compra")
            return false
        }
        
        var exito = compraModel.procesar_compra_actual()
        compraId = exito ? "PROCESSED" : null

        if (compraId) {
            console.log("✅ Compra completada en sistema central:", compraId)
            
            clearPurchase()
            clearProductFields()
            
            newPurchaseId = "C" + String((compraModel ? compraModel.total_compras_mes : 0) + 1).padStart(3, '0')
            
            showSuccess("✅ Compra " + compraId + " completada exitosamente")
            if (compraModel) {
                actualizarPaginacionCompras()
                
            }
            Qt.callLater(function() {
                console.log("🔙 Compra completada, regresando a lista...")
                compraCompletada()
            })
            
            return true
        } else {
            showSuccess("⚠ Error: No se pudo completar la compra")
            return false
        }
    }

    function clearPurchase() {
        temporaryProductsModel.clear()
        newPurchaseTotal = 0.0
        newPurchaseProvider = ""
        newPurchaseDetails = ""
    }

    function showSuccess(message) {
        successMessage = message
        showSuccessMessage = true
        successTimer.restart()
    }

    function refreshProveedoresManual() {
        console.log("🔄 Refrescando proveedores...")
        if (compraModel) {
            compraModel.force_refresh_proveedores()
            compraModel.debug_proveedores_info()
            
            Qt.callLater(function() {
                updateProviderNames()
                console.log("📋 Proveedores después de refresh:", providerNames.length)
            })
        } else {
            console.log("❌ CompraModel no disponible")
        }
    }

    // ============================================================================
    // INTERFAZ CON CONTENEDORES SEPARADOS - LAYOUT COMPACTO
    // ============================================================================
    
    Rectangle {
        anchors.fill: parent
        color: "#f8f9fa"
        
        // HEADER FIJO
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
                anchors.margins: spacing8
                spacing: spacing8
                
                Button {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    
                    background: Rectangle {
                        color: parent.pressed ? Qt.darker(blueColor, 1.2) : blueColor
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
                    
                    onClicked: cancelarCompra()
                }
                
                RowLayout {
                    spacing: spacing8
                    
                    Rectangle {
                        width: 32
                        height: 32
                        color: blueColor
                        radius: radiusMedium
                        
                        Label {
                            anchors.centerIn: parent
                            text: "🚚"
                            font.pixelSize: 16
                        }
                    }
                    
                    ColumnLayout {
                        spacing: 2
                        
                        Label {
                           text: modoEdicion ? "Editar Compra #" + compraIdEdicion : "Nueva Compra" 
                            font.pixelSize: fontLarge
                            font.bold: true
                            color: textColor
                        }
                        
                        Label {
                            text: (function() {
                                var fechaActual = new Date()
                                var dia = fechaActual.getDate().toString().padStart(2, '0')
                                var mes = (fechaActual.getMonth() + 1).toString().padStart(2, '0')
                                var año = fechaActual.getFullYear()
                                return "Usuario: Dr. Admin - " + dia + "/" + mes + "/" + año
                            })()
                            color: darkGrayColor
                            font.pixelSize: fontSmall
                        }
                    }
                }
                
                Item { Layout.fillWidth: true }
                
                Label {
                    text: "No. Compra: " + newPurchaseId
                    color: blueColor
                    font.pixelSize: fontMedium
                    font.bold: true
                }
            }
        }
        
        // SECCIÓN 1: PROVEEDOR - Rectangle separado
        Rectangle {
            id: providerSection
            anchors.top: fixedHeader.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: spacing8
            anchors.topMargin: spacing4
            height: 50
            color: "#E3F2FD"
            radius: radiusMedium
            border.color: blueColor
            border.width: 1
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: spacing8
                spacing: spacing8
                
                Label {
                    text: "🏢 Proveedor:"
                    font.pixelSize: fontMedium
                    font.bold: true
                    color: textColor
                }
                
                ComboBox {
                    id: providerCombo
                    Layout.preferredWidth: 250
                    Layout.preferredHeight: inputHeight
                    model: crearCompraRoot.providerNames
                    font.pixelSize: fontSmall
                    
                    background: Rectangle {
                        color: whiteColor
                        border.color: darkGrayColor
                        border.width: 1
                        radius: radiusSmall
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
                    
                    onClicked: refreshProveedoresManual()
                }
                
                Label {
                    text: "💡 Para gestionar proveedores, usa Farmacia → Proveedores"
                    color: "#666"
                    font.pixelSize: fontSmall
                    font.italic: true
                    Layout.fillWidth: true
                }
            }
        }
        
        // SECCIÓN 2: BÚSQUEDA Y CAMPOS UNIFICADOS - Rectangle único con dos mitades
        Rectangle {
            id: unifiedInputSection
            anchors.top: providerSection.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: spacing8
            anchors.topMargin: spacing4
            height: 80
            color: "#FFFEF7"
            radius: radiusMedium
            border.color: "#F39C12"
            border.width: 1
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: spacing8
                spacing: spacing12
                
                // MITAD IZQUIERDA: BÚSQUEDA
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "transparent"
                    
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: spacing4
                        
                        Label {
                            text: "🔍 BUSCAR PRODUCTO EXISTENTE"
                            color: textColor
                            font.bold: true
                            font.pixelSize: fontSmall
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
                                anchors.margins: spacing4
                                spacing: spacing4
                                
                                Label {
                                    text: "🔍"
                                    color: darkGrayColor
                                    font.pixelSize: 14
                                }
                                
                                TextField {
                                    id: productCodeField
                                    Layout.fillWidth: true
                                    placeholderText: "Código o nombre del producto..."
                                    text: inputProductName.length > 0 ? inputProductName : inputProductCode
                                    background: Rectangle { color: "transparent" }
                                    font.pixelSize: fontSmall
                                    
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
                            }
                        }
                    }
                }
                
                // LÍNEA SEPARADORA
                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    color: "#D5DBDB"
                    Layout.topMargin: spacing4
                    Layout.bottomMargin: spacing4
                }
                
                // MITAD DERECHA: CAMPOS DE ENTRADA
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "transparent"
                    
                    RowLayout {
                        anchors.fill: parent
                        spacing: spacing8
                        
                        Column {
                            spacing: 2
                            
                            Label {
                                text: "Stock:"
                                color: darkGrayColor
                                font.pixelSize: fontSmall
                                font.bold: true
                            }
                            
                            TextField {
                                id: stockField
                                width: 80
                                height: inputHeight
                                placeholderText: "Cantidad"
                                text: inputStock > 0 ? inputStock.toString() : ""
                                
                                background: Rectangle {
                                    color: whiteColor
                                    radius: radiusSmall
                                    border.color: parent.activeFocus ? successColor : darkGrayColor
                                    border.width: 1
                                }
                                
                                validator: IntValidator { bottom: 0; top: 99999 }
                                font.pixelSize: fontSmall
                                horizontalAlignment: Text.AlignHCenter
                                
                                onTextChanged: {
                                    inputStock = text.length > 0 ? (parseInt(text) || 0) : 0
                                }
                            }
                        }
                        
                        // COSTO TOTAL (mantener)
                        Column {
                            spacing: 2
                            
                            Label {
                                text: "Costo Total:"
                                color: darkGrayColor
                                font.pixelSize: fontSmall
                                font.bold: true
                            }
                            
                            TextField {
                                id: purchasePriceField
                                width: 70
                                height: inputHeight
                                placeholderText: "0.00"
                                text: inputPurchasePrice > 0 ? inputPurchasePrice.toString() : ""
                                
                                background: Rectangle {
                                    color: whiteColor
                                    radius: radiusSmall
                                    border.color: parent.activeFocus ? successColor : darkGrayColor
                                    border.width: 1
                                }
                                
                                validator: RegularExpressionValidator {
                                    regularExpression: /^\d*\.?\d{0,2}$/
                                }
                                
                                font.pixelSize: fontSmall
                                horizontalAlignment: Text.AlignHCenter
                                
                                onEditingFinished: {
                                    inputPurchasePrice = text.length > 0 ? (parseFloat(text) || 0.0) : 0.0
                                }
                            }
                        }
                        // Fecha Vencimiento
                        Column {
                            spacing: 2
                            
                            Label {
                                text: "Venc:"
                                color: darkGrayColor
                                font.pixelSize: fontSmall
                                font.bold: true
                            }
                            
                            RowLayout {
                                spacing: 4
                                
                                TextField {
                                    id: expiryField
                                    Layout.preferredWidth: 90
                                    Layout.preferredHeight: inputHeight
                                    placeholderText: "YYYY-MM-DD"
                                    text: inputExpiryDate
                                    enabled: !inputNoExpiry  // ✅ CORRECTO: Habilitado cuando NO es sin vencimiento
                                    
                                    background: Rectangle {
                                        color: enabled ? whiteColor : "#F5F5F5"
                                        radius: radiusSmall
                                        border.color: {
                                            if (!enabled) return "#E0E0E0"
                                            if (parent.activeFocus) return "#9C27B0"
                                            if (inputExpiryDate.length > 0 && !validateExpiryDate(inputExpiryDate)) return dangerColor
                                            return darkGrayColor
                                        }
                                        border.width: 1
                                    }
                                    
                                    font.pixelSize: fontSmall
                                    
                                    onTextChanged: {
                                        if (!inputNoExpiry) {
                                            var formatted = autoFormatDate(text)
                                            if (formatted !== text) {
                                                text = formatted
                                            }
                                            inputExpiryDate = formatted
                                        }
                                    }
                                    
                                    validator: RegularExpressionValidator {
                                        regularExpression: /^[0-9\-]*$/
                                    }
                                }

                                CheckBox {
                                    id: noExpiryCheckbox
                                    Layout.preferredWidth: 15
                                    Layout.preferredHeight: inputHeight
                                    checked: !inputNoExpiry  // ✅ CORRECTO: Checked cuando SÍ tiene vencimiento
                                    
                                    indicator: Rectangle {
                                        width: 14
                                        height: 14
                                        anchors.centerIn: parent
                                        radius: 2
                                        border.color: darkGrayColor
                                        border.width: 1
                                        color: parent.checked ? successColor : whiteColor
                                        
                                        Label {
                                            anchors.centerIn: parent
                                            text: "✓"
                                            color: whiteColor
                                            font.pixelSize: 8
                                            visible: parent.parent.checked
                                        }
                                    }
                                    
                                    contentItem: Item {}
                                    
                                    onCheckedChanged: {
                                        inputNoExpiry = !checked  // ✅ CORRECTO: Sin vencimiento cuando NO está checked
                                        if (!checked) {
                                            // Si no está checked = sin vencimiento, limpiar fecha
                                            inputExpiryDate = ""
                                            expiryField.text = ""
                                        }
                                    }
                                }  
                                
                                Text {
                                    text: "Con vencimiento"
                                    font.pixelSize: 10
                                    color: darkGrayColor
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }
                        }
                        
                        // Botón Agregar
                        Button {
                            Layout.preferredWidth: 70
                            Layout.preferredHeight: buttonHeight
                            Layout.alignment: Qt.AlignVCenter  
                            text: "Agregar"
                            enabled: inputProductCode.length > 0 && 
                                    inputProductName.length > 0 && 
                                    inputStock > 0 &&
                                    inputPurchasePrice > 0 &&
                                    // CORRECCIÓN: Lógica corregida para fecha de vencimiento
                                    (inputNoExpiry || (inputExpiryDate.length > 0 && validateExpiryDate(inputExpiryDate)))
                                    //    ↑ CORRECTO: Si es sin vencimiento O tiene fecha válida
                                    
                            background: Rectangle {
                                color: enabled ? successColor : darkGrayColor
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
                            
                            onClicked: addProductToPurchase()
                        }
                    }
                }
            }
        }
        
        // SECCIÓN 3: LISTA DE PRODUCTOS (CORREGIDA)
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
                        text: "Productos en la compra: " + temporaryProductsModel.count
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
                                        text: "STOCK"
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
                                        text: "COSTO TOTAL"  // ENCABEZADO CORREGIDO
                                        color: textColor
                                        font.bold: true
                                        font.pixelSize: fontSmall
                                    }
                                }
                            }
                        }
                        
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            
                            ListView {
                                anchors.fill: parent
                                model: temporaryProductsModel
                                
                                delegate: Item {
                                    width: ListView.view.width
                                    height: 40
                                    
                                    RowLayout {
                                        anchors.fill: parent
                                        spacing: 0
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 80
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#D5DBDB"
                                            border.width: 1
                                            
                                            Label {
                                                anchors.centerIn: parent
                                                text: model.codigo
                                                color: textColor
                                                font.bold: true
                                                font.pixelSize: fontSmall
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 150
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#D5DBDB"
                                            border.width: 1
                                            
                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: spacing4
                                                spacing: spacing4
                                                
                                                Label {
                                                    text: model.nombre
                                                    color: textColor
                                                    font.bold: true
                                                    font.pixelSize: fontSmall
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                                
                                                Button {
                                                    width: 20
                                                    height: 20
                                                    text: "🗑️"
                                                    background: Rectangle {
                                                        color: dangerColor
                                                        radius: 10
                                                    }
                                                    contentItem: Label {
                                                        text: parent.text
                                                        color: whiteColor
                                                        font.pixelSize: 8
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
                                        Rectangle {
                                            Layout.preferredWidth: 80
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#D5DBDB"
                                            border.width: 1
                                            
                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: 40
                                                height: 16
                                                color: "#9B59B6"
                                                radius: 8
                                                
                                                Label {
                                                    anchors.centerIn: parent
                                                    text: model.stock  // SOLO ESTE VALOR
                                                    color: whiteColor
                                                    font.bold: true
                                                    font.pixelSize: 8
                                                }
                                            }
                                        }
                                        
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 100
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#D5DBDB"
                                            border.width: 1
                                            
                                            Label {
                                                anchors.centerIn: parent
                                                text: "Bs" + model.costoTotalProducto.toFixed(2)  // VALOR CORREGIDO
                                                color: successColor
                                                font.bold: true
                                                font.pixelSize: fontSmall
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
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
                                font.pixelSize: fontMedium
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }
                }
            }
        }
        
        // SECCIÓN 4: ACCIONES - Rectangle separado
        Rectangle {
            id: actionsSection
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: spacing8
            height: 50
            color: whiteColor
            radius: radiusMedium
            border.color: lightGrayColor
            border.width: 1
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: spacing8
                spacing: spacing8
                
                Item { Layout.fillWidth: true }
                
                Rectangle {
                    Layout.preferredWidth: 150
                    Layout.preferredHeight: 35
                    color: newPurchaseTotal > 0 ? successColor : darkGrayColor
                    radius: radiusSmall
                    
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: spacing4
                        
                        Label {
                            text: "💰"
                            color: whiteColor
                            font.pixelSize: 14
                        }
                        
                        Label {
                            text: "TOTAL: Bs" + newPurchaseTotal.toFixed(2)
                            color: whiteColor
                            font.bold: true
                            font.pixelSize: fontSmall
                        }
                    }
                }
                
                Button {
                    text: "✖ Cancelar"
                    Layout.preferredHeight: buttonHeight
                    background: Rectangle {
                        color: dangerColor
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
                        clearPurchase()
                        clearProductFields()
                        if (providerCombo) providerCombo.currentIndex = 0
                        cancelarCompra()
                    }
                }
                
                Button {
                    id: completarCompraButton
                    text: "💾 Completar Compra"
                    Layout.preferredHeight: buttonHeight
                    enabled: (providerCombo ? providerCombo.currentIndex > 0 : false) && temporaryProductsModel.count > 0
                    background: Rectangle {
                        color: enabled ? successColor : darkGrayColor
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
                        if (completarCompra()) {
                            completarCompraButton.text = "✅ ¡Completado!"
                            Qt.callLater(function() {
                                completarCompraButton.text = "💾 Completar Compra"
                            })
                        }
                    }
                }
            }
        }
        
        // NOTIFICACIÓN DE ÉXITO
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: spacing8
            height: 40
            color: successColor
            radius: radiusSmall
            visible: showSuccessMessage
            opacity: showSuccessMessage ? 1.0 : 0.0
            z: 20
            
            Behavior on opacity {
                NumberAnimation { duration: 300 }
            }
            
            RowLayout {
                anchors.centerIn: parent
                spacing: spacing8
                
                Rectangle {
                    width: 24
                    height: 24
                    color: whiteColor
                    radius: 12
                    
                    Label {
                        anchors.centerIn: parent
                        text: "✅"
                        color: successColor
                        font.pixelSize: 12
                    }
                }
                
                Label {
                    text: successMessage
                    color: whiteColor
                    font.bold: true
                    font.pixelSize: fontSmall
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
            visible: showProductDropdown
            z: 1000
            
            ListView {
                anchors.fill: parent
                anchors.margins: spacing4
                model: productSearchResultsModel
                clip: true
                
                delegate: Rectangle {
                    width: ListView.view.width
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
                        onClicked: seleccionarProductoExistente(model.codigo, model.nombre)
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        console.log("✅ CrearCompra.qml inicializado con layout compacto - SIN MULTIPLICACIÓN DE PRECIOS")
        
        if (!compraModel || !inventarioModel) {
            console.log("⚠️ Models no disponibles aún")
            
            Qt.callLater(function() {
                if (compraModel) {
                    console.log("✅ CompraModel disponible en retry")
                    updateProviderNames()
                    
                    // AGREGAR ESTA LÍNEA PARA CARGAR DATOS DE EDICIÓN
                    if (modoEdicion) {
                        Qt.callLater(cargarDatosCompraEdicion)
                    }
                }
            })
        } else {
            console.log("✅ Models conectados correctamente")
            
            compraModel.force_refresh_proveedores()
            Qt.callLater(updateProviderNames)
            
            // AGREGAR ESTA LÍNEA PARA CARGAR DATOS DE EDICIÓN
            if (modoEdicion) {
                Qt.callLater(cargarDatosCompraEdicion)
            }
        }
        
        Qt.callLater(function() {
            if (productCodeField) {
                productCodeField.focus = true
            }
        })
    }
}