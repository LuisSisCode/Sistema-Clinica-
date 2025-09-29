import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15

// Componente para crear/editar compras - MEJORADO CON EDICIÓN
Item {
    id: crearCompraRoot
    
    // Propiedades de comunicación
    property var inventarioModel: parent.inventarioModel || null
    property var ventaModel: null
    property var compraModel: null
    
    // NUEVAS PROPIEDADES PARA EDICIÓN
    property bool modoEdicion: compraModel ? compraModel.modo_edicion : false
    property int compraIdEdicion: compraModel ? compraModel.compra_id_edicion : 0
    property var datosOriginales: compraModel ? compraModel.datos_originales : {}
    
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

    // COLORES DINÁMICOS SEGÚN MODO
    property color primaryColor: modoEdicion ? "#2E7D32" : "#273746"  // Verde para edición
    property color accentColor: modoEdicion ? "#FF9800" : "#3498db"   // Naranja para edición
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
    property bool showComparisonPanel: false  // NUEVO
    
    // Datos para compra
    property string newPurchaseProvider: ""
    property string newPurchaseUser: "Dr. Admin"
    property string newPurchaseDate: ""
    property string newPurchaseId: ""
    property real newPurchaseTotal: 0.0
    
    // Campos de entrada para productos
    property string inputProductCode: ""
    property string inputProductName: ""
    property int inputStock: 0
    property real inputPurchasePrice: 0.0
    property real inputSalePrice: 0.0
    property string inputExpiryDate: ""
    property bool inputNoExpiry: false
    property bool isNewProduct: true
    
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

    // NUEVAS CONEXIONES PARA EDICIÓN
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
            showSuccess(`🎉 Compra #${compraId} actualizada: Bs${total.toFixed(2)}`)
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

    // FUNCIONES DE NEGOCIO MEJORADAS
    
    function cargarDatosEdicion() {

        if (!modoEdicion || !compraModel) return
        
        console.log("📋 Cargando datos para edición - Compra:", compraIdEdicion)
        
        // Configurar ID y fecha
        newPurchaseId = `C${String(compraIdEdicion).padStart(3, '0')}`
        
        // Configurar proveedor
        var datosOrig = datosOriginales
        if (datosOrig && datosOrig.proveedor) {
            newPurchaseProvider = datosOrig.proveedor
            
            // Buscar índice del proveedor en el combo
            for (var i = 0; i < providerNames.length; i++) {
                if (providerNames[i] === datosOrig.proveedor) {
                    if (providerCombo) {
                        providerCombo.currentIndex = i
                    }
                    break
                }
            }
        }
        
        // Configurar fecha
        if (datosOrig && datosOrig.fecha) {
            newPurchaseDate = datosOrig.fecha
        }
        
        // Los productos ya fueron cargados por el modelo
        updatePurchaseTotal()
        
        console.log("✅ Datos de edición cargados")
        showSuccess("📝 Compra cargada para edición")
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

    function seleccionarProductoExistente(codigo, nombre) {
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
        
        showSuccess("📦 Producto seleccionado: " + nombre)
    }
    
    function addProductToPurchase() {
        if (inputProductCode.length === 0) {
            showSuccess("⚠️ Error: Ingrese el código del producto")
            return false
        }
        
        if (inputProductName.length === 0) {
            showSuccess("⚠️ Error: Ingrese el nombre del producto")
            return false
        }
        
        if (inputStock <= 0) {
            showSuccess("⚠️ Error: Ingrese cantidad de stock")
            return false
        }
        
        if (inputPurchasePrice <= 0) {
            showSuccess("⚠️ Error: El precio debe ser mayor a 0")
            return false
        }
        
        if (!inputNoExpiry) {
            if (inputExpiryDate.length === 0) {
                showSuccess("⚠️ Error: Ingrese fecha de vencimiento o marque 'Sin vencimiento'")
                return false
            }
            if (!validateExpiryDate(inputExpiryDate)) {
                showSuccess("⚠️ Error: Fecha de vencimiento inválida (YYYY-MM-DD)")
                return false
            }
        }
        
        // Usar el modelo para agregar
        if (compraModel) {
            compraModel.agregar_item_compra(
                inputProductCode,
                inputStock,
                inputPurchasePrice,
                inputNoExpiry ? "" : inputExpiryDate
            )
        }
        
        updatePurchaseTotal()
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

    function completarCompra() {
        console.log("🚛 Iniciando proceso de completar/actualizar compra...")
        
        if (!compraModel) {
            showSuccess("⚠️ Error: Sistema de compras no disponible")
            return false
        }
        
        if (newPurchaseProvider === "") {
            showSuccess("⚠️ Error: Seleccione un proveedor")
            return false
        }
        
        if (!compraModel.items_compra || compraModel.items_compra.length === 0) {
            showSuccess("⚠️ Error: Agregue al menos un producto")
            return false
        }
        
        // NUEVA LÓGICA: Mostrar resumen de cambios en modo edición
        if (modoEdicion) {
            var cambios = compraModel.obtener_cambios_realizados()
            if (cambios && cambios.hay_cambios) {
                var mensaje = `Cambios detectados: ${cambios.total_cambios} modificaciones`
                showSuccess("📝 " + mensaje)
            } else if (cambios && !cambios.hay_cambios) {
                showSuccess("ℹ️ No hay cambios para guardar")
                return true
            }
        }
        
        // Procesar compra (crear o actualizar según modo)
        var exito = compraModel.procesar_compra_actual()
        
        if (exito) {
            var accion = modoEdicion ? "actualizada" : "creada"
            showSuccess(`✅ Compra ${accion} exitosamente`)
            return true
        } else {
            showSuccess(`⚠️ Error: No se pudo ${modoEdicion ? "actualizar" : "crear"} la compra`)
            return false
        }
    }

    function showSuccess(message) {
        successMessage = message
        showSuccessMessage = true
        successTimer.restart()
    }

    // ============================================================================
    // INTERFAZ MEJORADA CON DETECCIÓN DE MODO
    // ============================================================================
    
    Rectangle {
        anchors.fill: parent
        color: "#f8f9fa"
        
        // HEADER MEJORADO CON MODO EDICIÓN
        Rectangle {
            id: fixedHeader
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: headerHeight
            color: whiteColor
            radius: radiusLarge
            border.color: modoEdicion ? "#FF9800" : "#e9ecef"
            border.width: modoEdicion ? 2 : 1
            z: 10
            
            // Indicador visual de modo edición
            Rectangle {
                visible: modoEdicion
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 4
                color: "#FF9800"
                radius: radiusLarge
            }
            
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
                        color: modoEdicion ? "#FF9800" : blueColor
                        radius: radiusMedium
                        
                        Label {
                            anchors.centerIn: parent
                            text: modoEdicion ? "📝" : "🚛"
                            font.pixelSize: 16
                        }
                    }
                    
                    ColumnLayout {
                        spacing: 2
                        
                        Label {
                           text: modoEdicion ? `EDITANDO Compra #${compraIdEdicion}` : "Nueva Compra"
                            font.pixelSize: fontLarge
                            font.bold: true
                            color: modoEdicion ? "#E65100" : textColor
                        }
                        
                        RowLayout {
                            spacing: spacing12
                            
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
                            
                            // NUEVO: Mostrar cambios en modo edición
                            Rectangle {
                                visible: modoEdicion
                                Layout.preferredWidth: 80
                                Layout.preferredHeight: 20
                                color: "#FFF3E0"
                                radius: 10
                                border.color: "#FF9800"
                                border.width: 1
                                
                                Label {
                                    anchors.centerIn: parent
                                    text: "MODO EDICIÓN"
                                    color: "#E65100"
                                    font.pixelSize: 8
                                    font.bold: true
                                }
                            }
                        }
                    }
                }
                
                Item { Layout.fillWidth: true }
                
                // NUEVO: Panel de comparación
                Button {
                    visible: modoEdicion
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 30
                    text: showComparisonPanel ? "🔼 Ocultar Original" : "🔽 Ver Original"
                    
                    background: Rectangle {
                        color: parent.pressed ? "#FFF3E0" : "#FFECB3"
                        radius: radiusSmall
                        border.color: "#FF9800"
                        border.width: 1
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        color: "#E65100"
                        font.pixelSize: fontSmall
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        showComparisonPanel = !showComparisonPanel
                    }
                }
                
                Label {
                    text: modoEdicion ? `Editando: ${newPurchaseId}` : `No. Compra: ${newPurchaseId}`
                    color: modoEdicion ? "#E65100" : blueColor
                    font.pixelSize: fontMedium
                    font.bold: true
                }
            }
        }
        
        // NUEVO: Panel de comparación colapsible
        Rectangle {
            id: comparisonPanel
            visible: modoEdicion && showComparisonPanel
            anchors.top: fixedHeader.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: spacing8
            anchors.topMargin: spacing4
            height: visible ? 80 : 0
            color: "#FFF3E0"
            radius: radiusMedium
            border.color: "#FF9800"
            border.width: 1
            
            Behavior on height {
                NumberAnimation { duration: 200 }
            }
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: spacing8
                spacing: spacing4
                
                Label {
                    text: "📋 DATOS ORIGINALES DE LA COMPRA"
                    font.bold: true
                    font.pixelSize: fontSmall
                    color: "#E65100"
                }
                
                RowLayout {
                    spacing: spacing20
                    
                    Label {
                        text: `Proveedor: ${datosOriginales.proveedor || "N/A"}`
                        font.pixelSize: fontSmall
                        color: "#BF360C"
                    }
                    
                    Label {
                        text: `Total: Bs${(datosOriginales.total || 0).toFixed(2)}`
                        font.pixelSize: fontSmall
                        color: "#BF360C"
                    }
                    
                    Label {
                        text: `Fecha: ${datosOriginales.fecha || "N/A"}`
                        font.pixelSize: fontSmall
                        color: "#BF360C"
                    }
                    
                    Label {
                        text: `Productos: ${compraModel ? compraModel.items_originales.length : 0}`
                        font.pixelSize: fontSmall
                        color: "#BF360C"
                    }
                }
            }
        }
        
        // SECCIÓN PROVEEDOR (ajustada para panel)
        Rectangle {
            id: providerSection
            anchors.top: comparisonPanel.visible ? comparisonPanel.bottom : fixedHeader.bottom
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
                    
                    // NUEVO: Estilo diferente en modo edición
                    background: Rectangle {
                        color: whiteColor
                        border.color: modoEdicion ? "#FF9800" : darkGrayColor
                        border.width: modoEdicion ? 2 : 1
                        radius: radiusSmall
                    }
                    
                    onCurrentTextChanged: {
                        if (currentIndex > 0) {
                            newPurchaseProvider = currentText
                        } else {
                            newPurchaseProvider = ""
                        }
                        
                        // Actualizar modelo
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
                    text: "💡 Para gestionar proveedores, usa Farmacia → Proveedores"
                    color: "#666"
                    font.pixelSize: fontSmall
                    font.italic: true
                    Layout.fillWidth: true
                }
            }
        }
        
        // SECCIÓN BÚSQUEDA Y CAMPOS (igual que antes)
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
                                    text: "🔎"
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
                                    enabled: !inputNoExpiry
                                    
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
                                            inputExpiryDate = text
                                        }
                                    }
                                }

                                CheckBox {
                                    id: noExpiryCheckbox
                                    Layout.preferredWidth: 15
                                    Layout.preferredHeight: inputHeight
                                    checked: !inputNoExpiry
                                    
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
                                        inputNoExpiry = !checked
                                        if (!checked) {
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
                                    (inputNoExpiry || (inputExpiryDate.length > 0 && validateExpiryDate(inputExpiryDate)))
                                    
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
        
        // SECCIÓN LISTA DE PRODUCTOS (conectada con modelo)
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
                    
                    // NUEVO: Indicador de cambios
                    Rectangle {
                        visible: modoEdicion
                        Layout.preferredWidth: 100
                        Layout.preferredHeight: 20
                        color: "#E8F5E8"
                        radius: 10
                        border.color: "#4CAF50"
                        border.width: 1
                        
                        Label {
                            anchors.centerIn: parent
                            text: `📝 ${compraModel ? compraModel.items_en_compra : 0} items actuales`
                            color: "#2E7D32"
                            font.pixelSize: 8
                            font.bold: true
                        }
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
                                        text: "COSTO TOTAL"
                                        color: textColor
                                        font.bold: true
                                        font.pixelSize: fontSmall
                                    }
                                }
                            }
                        }
                        
                        // Lista conectada con modelo
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            
                            ListView {
                                anchors.fill: parent
                                model: compraModel ? compraModel.items_compra : null
                                
                                delegate: Item {
                                    width: ListView.view.width
                                    height: 40
                                    
                                    // NUEVO: Indicador de cambio
                                    Rectangle {
                                        anchors.fill: parent
                                        color: modoEdicion ? "#FFF3E0" : "transparent"
                                        opacity: modoEdicion ? 0.3 : 0
                                    }
                                    
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
                                                text: modelData.codigo || ""
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
                                                    text: modelData.nombre || ""
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
                                                        if (compraModel) {
                                                            compraModel.remover_item_compra(modelData.codigo)
                                                        }
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
                                                    text: modelData.cantidad_unitario || 0
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
                                                text: `Bs${(modelData.subtotal || 0).toFixed(2)}`
                                                color: successColor
                                                font.bold: true
                                                font.pixelSize: fontSmall
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
                            visible: !compraModel || compraModel.items_en_compra === 0
                            
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
        
        // SECCIÓN ACCIONES MEJORADA
        Rectangle {
            id: actionsSection
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: spacing8
            height: 50
            color: whiteColor
            radius: radiusMedium
            border.color: modoEdicion ? "#FF9800" : lightGrayColor
            border.width: modoEdicion ? 2 : 1
            
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
                            text: `TOTAL: Bs${(compraModel ? compraModel.total_compra_actual : 0).toFixed(2)}`
                            color: whiteColor
                            font.bold: true
                            font.pixelSize: fontSmall
                        }
                    }
                }
                
                Button {
                    text: "❌ Cancelar"
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
                        if (modoEdicion && compraModel) {
                            compraModel.cancelar_edicion()
                        }
                        cancelarCompra()
                    }
                }
                
                Button {
                    id: completarCompraButton
                    text: modoEdicion ? "💾 Guardar Cambios" : "🚛 Completar Compra"
                    Layout.preferredHeight: buttonHeight
                    enabled: (providerCombo ? providerCombo.currentIndex > 0 : false) && 
                            (compraModel ? compraModel.items_en_compra > 0 : false)
                    
                    // NUEVO: Estilo diferente para modo edición
                    background: Rectangle {
                        color: {
                            if (!enabled) return darkGrayColor
                            if (modoEdicion) return "#FF9800"
                            return successColor
                        }
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
                            var textoExito = modoEdicion ? "✅ ¡Actualizado!" : "✅ ¡Completado!"
                            completarCompraButton.text = textoExito
                            Qt.callLater(function() {
                                completarCompraButton.text = modoEdicion ? "💾 Guardar Cambios" : "🚛 Completar Compra"
                            })
                        }
                    }
                }
            }
        }
        
        // NOTIFICACIÓN DE ÉXITO MEJORADA
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: spacing8
            height: 40
            color: modoEdicion ? "#FF9800" : successColor
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
                        text: modoEdicion ? "📝" : "✅"
                        color: modoEdicion ? "#FF9800" : successColor
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

        // DROPDOWN FLOTANTE (igual que antes)
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

    // CONNECTIONS Y COMPONENT.ONCOMPLETED MEJORADOS
    
    Connections {
        target: compraModel
        function onItemsCombraCambiado() {
            updatePurchaseTotal()
        }
    }

    Component.onCompleted: {
        console.log("✅ CrearCompra.qml inicializado con edición mejorada")
        
        if (!compraModel || !inventarioModel) {
            console.log("⚠️ Models no disponibles aún")
            
            Qt.callLater(function() {
                if (compraModel) {
                    console.log("✅ CompraModel disponible en retry")
                    updateProviderNames()
                    
                    // Verificar si está en modo edición
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
                
                // Verificar si está en modo edición al inicializar
                if (compraModel.modo_edicion) {
                    Qt.callLater(cargarDatosEdicion)
                }
            }
        }
        
        // Configurar fecha y ID
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