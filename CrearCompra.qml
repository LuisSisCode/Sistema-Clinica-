import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15

// Componente para crear/editar compras - INTERFAZ MINIMALISTA MEJORADA
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

    // ============================================================================
    // FUNCIONES DE NEGOCIO MEJORADAS
    // ============================================================================
    
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
        
        // ✅ CORRECCIÓN: Convertir fecha de Python a string
        if (datosOrig && datosOrig.fecha) {
            // Si la fecha viene como objeto Python, convertirla a string
            try {
                var fechaStr = datosOrig.fecha.toString()
                if (fechaStr && fechaStr.length > 0) {
                    newPurchaseDate = fechaStr
                }
            } catch (e) {
                console.log("⚠️ Error al convertir fecha:", e)
                // Usar fecha actual como fallback
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
        
        showSuccess("Producto seleccionado: " + nombre)
    }
    
    // FUNCIÓN MEJORADA: Agregar o actualizar producto
    function addProductToPurchase() {
        if (inputProductCode.length === 0) {
            showSuccess("Error: Ingrese el código del producto")
            return false
        }
        
        if (inputProductName.length === 0) {
            showSuccess("Error: Ingrese el nombre del producto")
            return false
        }
        
        if (inputStock <= 0) {
            showSuccess("Error: Ingrese cantidad de stock")
            return false
        }
        
        if (inputPurchasePrice <= 0) {
            showSuccess("Error: El precio debe ser mayor a 0")
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
    
    // FUNCIÓN: Agregar nuevo producto
    function agregarNuevoProducto() {
        if (compraModel) {
            compraModel.agregar_item_compra(
                inputProductCode,
                inputStock,
                inputPurchasePrice,
                inputNoExpiry ? "" : inputExpiryDate
            )
            
            showSuccess("Producto agregado: " + inputProductName)
        }
        
        updatePurchaseTotal()
        clearProductFields()
        return true
    }
    
    // FUNCIÓN: Actualizar producto existente
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
        
        var productoOriginal = items[productoEditandoIndex]
        
        // Actualizar en el modelo
        compraModel.actualizar_item_compra(
            productoEditandoIndex,
            inputStock,
            inputPurchasePrice,
            inputNoExpiry ? "" : inputExpiryDate
        )
        
        showSuccess("Producto actualizado: " + inputProductName)
        updatePurchaseTotal()
        cancelarEdicionProducto()
        return true
    }
    
    // FUNCIÓN: Editar producto existente
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
        inputStock = producto.cantidad_unitario || 0
        inputPurchasePrice = producto.subtotal || 0
        inputExpiryDate = producto.fecha_vencimiento || ""
        inputNoExpiry = (inputExpiryDate.length === 0 || inputExpiryDate === "Sin vencimiento")
        
        // Actualizar campos visuales
        if (productCodeField) productCodeField.text = inputProductName
        if (stockField) stockField.text = inputStock.toString()
        if (purchasePriceField) purchasePriceField.text = inputPurchasePrice.toString()
        if (expiryField) expiryField.text = inputExpiryDate
        if (noExpiryCheckbox) noExpiryCheckbox.checked = !inputNoExpiry
        
        // Marcar como editando
        productoEditandoIndex = index
        
        // Enfocar el campo de stock
        Qt.callLater(function() {
            if (stockField) {
                stockField.focus = true
                stockField.selectAll()
            }
        })
        
        showSuccess("Editando: " + inputProductName)
    }
    
    // FUNCIÓN: Cancelar edición de producto
    function cancelarEdicionProducto() {
        productoEditandoIndex = -1
        clearProductFields()
        showSuccess("Edición cancelada")
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
        productoEditandoIndex = -1
        
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
        console.log("Iniciando proceso de completar/actualizar compra...")
        
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
        
        // Verificar si hay un producto en edición sin guardar
        if (productoEditandoIndex >= 0) {
            showSuccess("Advertencia: Hay un producto en edición. Guárdelo o cancele primero")
            return false
        }
        
        if (modoEdicion) {
            var cambios = compraModel.obtener_cambios_realizados()
            if (cambios && cambios.hay_cambios) {
                var mensaje = `Cambios detectados: ${cambios.total_cambios} modificaciones`
                showSuccess(mensaje)
            } else if (cambios && !cambios.hay_cambios) {
                showSuccess("No hay cambios para guardar")
                return true
            }
        }
        
        var exito = compraModel.procesar_compra_actual()
        
        if (exito) {
            var accion = modoEdicion ? "actualizada" : "creada"
            showSuccess(`Compra ${accion} exitosamente`)
            return true
        } else {
            showSuccess(`Error: No se pudo ${modoEdicion ? "actualizar" : "crear"} la compra`)
            return false
        }
    }

    function showSuccess(message) {
        successMessage = message
        showSuccessMessage = true
        successTimer.restart()
    }

    // ============================================================================
    // INTERFAZ MINIMALISTA MEJORADA
    // ============================================================================
    
    Rectangle {
        anchors.fill: parent
        color: "#f8f9fa"
        
        // HEADER MINIMALISTA
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
            
            Rectangle {
                visible: modoEdicion
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 3
                color: editModeColor
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
                        color: modoEdicion ? editModeColor : blueColor
                        radius: radiusMedium
                        
                        Label {
                            anchors.centerIn: parent
                            text: modoEdicion ? "✏️" : "📦"
                            font.pixelSize: 14
                            color: whiteColor
                        }
                    }
                    
                    ColumnLayout {
                        spacing: 2
                        
                        Label {
                            text: modoEdicion ? `Editando Compra #${compraIdEdicion}` : "Nueva Compra"
                            font.pixelSize: fontLarge
                            font.bold: true
                            color: modoEdicion ? editModeColor : textColor
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
                            
                            Rectangle {
                                visible: modoEdicion
                                Layout.preferredWidth: 70
                                Layout.preferredHeight: 18
                                color: "#ECF0F1"
                                radius: 9
                                border.color: editModeColor
                                border.width: 1
                                
                                Label {
                                    anchors.centerIn: parent
                                    text: "EDITANDO"
                                    color: editModeColor
                                    font.pixelSize: 8
                                    font.bold: true
                                }
                            }
                            
                            Rectangle {
                                visible: productoEditandoIndex >= 0
                                Layout.preferredWidth: 90
                                Layout.preferredHeight: 18
                                color: "#FFF9C4"
                                radius: 9
                                border.color: "#F39C12"
                                border.width: 1
                                
                                Label {
                                    anchors.centerIn: parent
                                    text: "EDITANDO PRODUCTO"
                                    color: "#E67E22"
                                    font.pixelSize: 7
                                    font.bold: true
                                }
                            }
                        }
                    }
                }
                
                Item { Layout.fillWidth: true }
                
                Button {
                    visible: modoEdicion
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 28
                    text: showComparisonPanel ? "Ocultar Original" : "Ver Original"
                    
                    background: Rectangle {
                        color: parent.pressed ? "#ECF0F1" : "#F8F9FA"
                        radius: radiusSmall
                        border.color: editModeColor
                        border.width: 1
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        color: editModeColor
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
                    color: modoEdicion ? editModeColor : blueColor
                    font.pixelSize: fontMedium
                    font.bold: true
                }
            }
        }
        
        // Panel de comparación
        Rectangle {
            id: comparisonPanel
            visible: modoEdicion && showComparisonPanel
            anchors.top: fixedHeader.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: spacing8
            anchors.topMargin: spacing4
            height: visible ? 80 : 0
            color: "#ECF0F1"
            radius: radiusMedium
            border.color: editModeColor
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
                    color: editModeColor
                }
                
                RowLayout {
                    spacing: spacing20
                    
                    Label {
                        text: `Proveedor: ${datosOriginales.proveedor || "N/A"}`
                        font.pixelSize: fontSmall
                        color: textColor
                    }
                    
                    Label {
                        text: `Total: Bs${(datosOriginales.total || 0).toFixed(2)}`
                        font.pixelSize: fontSmall
                        color: textColor
                    }
                    
                    Label {
                        text: `Fecha: ${datosOriginales.fecha || "N/A"}`
                        font.pixelSize: fontSmall
                        color: textColor
                    }
                    
                    Label {
                        text: `Productos: ${compraModel ? compraModel.items_originales.length : 0}`
                        font.pixelSize: fontSmall
                        color: textColor
                    }
                }
            }
        }
        
        // SECCIÓN PROVEEDOR
        Rectangle {
            id: providerSection
            anchors.top: comparisonPanel.visible ? comparisonPanel.bottom : fixedHeader.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: spacing8
            anchors.topMargin: spacing4
            height: 50
            color: "#F8F9FA"
            radius: radiusMedium
            border.color: modoEdicion ? editModeColor : blueColor
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
                    text: "💡 Para gestionar proveedores, usa Farmacia → Proveedores"
                    color: "#666"
                    font.pixelSize: fontSmall
                    font.italic: true
                    Layout.fillWidth: true
                }
            }
        }
        
        // SECCIÓN BÚSQUEDA Y CAMPOS - ESTILO CREARVENTAS
        Rectangle {
            id: unifiedInputSection
            anchors.top: providerSection.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: spacing8
            anchors.topMargin: spacing4
            height: 80
            color: productoEditandoIndex >= 0 ? "#FFF9C4" : "#F8F9FA"
            radius: radiusMedium
            border.color: productoEditandoIndex >= 0 ? "#F39C12" : "#D5DBDB"
            border.width: 1
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: spacing8
                spacing: spacing12
                
                // MITAD IZQUIERDA: BÚSQUEDA
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50
                    color: "transparent"
                    
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: spacing8
                        
                        Label {
                            text: productoEditandoIndex >= 0 ? "EDITANDO PRODUCTO" : "BUSCAR PRODUCTO"
                            color: productoEditandoIndex >= 0 ? "#E67E22" : textColor
                            font.bold: true
                            font.pixelSize: fontSmall
                        }
                        
                        Rectangle {
                            id: campoBusquedaContainer
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
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
                                
                                font.pixelSize: fontSmall
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
                                text: "Buscar producto..."
                                color: "#999999"
                                font.pixelSize: fontSmall
                                visible: productCodeField.text.length === 0
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
                        
                        // Campo Stock
                        Column {
                            spacing: 2
                            
                            Label {
                                text: "Stock"
                                color: darkGrayColor
                                font.pixelSize: fontSmall
                                font.bold: true
                            }
                            
                            Rectangle {
                                width: 80
                                height: inputHeight
                                color: "#ffffff"
                                border.color: stockField.activeFocus ? successColor : darkGrayColor
                                border.width: stockField.activeFocus ? 2 : 1
                                radius: radiusSmall
                                
                                TextInput {
                                    id: stockField
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    
                                    text: inputStock > 0 ? inputStock.toString() : ""
                                    
                                    validator: IntValidator { bottom: 0; top: 99999 }
                                    font.pixelSize: fontSmall
                                    color: "#000000"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    
                                    clip: true
                                    selectByMouse: true
                                    
                                    onTextChanged: {
                                        inputStock = text.length > 0 ? (parseInt(text) || 0) : 0
                                    }
                                }
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "0"
                                    color: "#999999"
                                    font.pixelSize: fontSmall
                                    visible: stockField.text.length === 0
                                }
                            }
                        }
                        
                        // Campo Costo
                        Column {
                            spacing: 2
                            
                            Label {
                                text: "Costo"
                                color: darkGrayColor
                                font.pixelSize: fontSmall
                                font.bold: true
                            }
                            
                            Rectangle {
                                width: 70
                                height: inputHeight
                                color: "#ffffff"
                                border.color: purchasePriceField.activeFocus ? successColor : darkGrayColor
                                border.width: purchasePriceField.activeFocus ? 2 : 1
                                radius: radiusSmall
                                
                                TextInput {
                                    id: purchasePriceField
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    
                                    text: inputPurchasePrice > 0 ? inputPurchasePrice.toString() : ""
                                    
                                    validator: RegularExpressionValidator {
                                        regularExpression: /^\d*\.?\d{0,2}$/
                                    }
                                    
                                    font.pixelSize: fontSmall
                                    color: "#000000"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    
                                    clip: true
                                    selectByMouse: true
                                    
                                    onEditingFinished: {
                                        inputPurchasePrice = text.length > 0 ? (parseFloat(text) || 0.0) : 0.0
                                    }
                                }
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "0.00"
                                    color: "#999999"
                                    font.pixelSize: fontSmall
                                    visible: purchasePriceField.text.length === 0
                                }
                            }
                        }
                        
                        // Campo Vencimiento
                        Column {
                            spacing: 2
                            
                            Label {
                                text: "Vencimiento"
                                color: darkGrayColor
                                font.pixelSize: fontSmall
                                font.bold: true
                            }
                            
                            RowLayout {
                                spacing: 4
                                
                                Rectangle {
                                    Layout.preferredWidth: 90
                                    Layout.preferredHeight: inputHeight
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
                                        
                                        font.pixelSize: fontSmall
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
                        
                        // BOTÓN AGREGAR/ACTUALIZAR
                        Rectangle {
                            Layout.preferredWidth: 70
                            Layout.preferredHeight: buttonHeight
                            Layout.alignment: Qt.AlignVCenter
                            color: {
                                var enabled = inputProductCode.length > 0 && 
                                            inputProductName.length > 0 && 
                                            inputStock > 0 &&
                                            inputPurchasePrice > 0 &&
                                            (inputNoExpiry || (inputExpiryDate.length > 0 && validateExpiryDate(inputExpiryDate)))
                                
                                if (!enabled) return darkGrayColor
                                return productoEditandoIndex >= 0 ? blueColor : successColor
                            }
                            radius: radiusSmall
                            
                            Label {
                                anchors.centerIn: parent
                                text: productoEditandoIndex >= 0 ? "Actualizar" : "Agregar"
                                color: whiteColor
                                font.bold: true
                                font.pixelSize: fontSmall
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                enabled: inputProductCode.length > 0 && 
                                        inputProductName.length > 0 && 
                                        inputStock > 0 &&
                                        inputPurchasePrice > 0 &&
                                        (inputNoExpiry || (inputExpiryDate.length > 0 && validateExpiryDate(inputExpiryDate)))
                                onClicked: addProductToPurchase()
                            }
                        }
                        
                        // Botón Cancelar edición
                        Rectangle {
                            visible: productoEditandoIndex >= 0
                            Layout.preferredWidth: 60
                            Layout.preferredHeight: buttonHeight
                            Layout.alignment: Qt.AlignVCenter
                            color: warningColor
                            radius: radiusSmall
                            
                            Label {
                                anchors.centerIn: parent
                                text: "Cancelar"
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
                                    
                                    Rectangle {
                                        anchors.fill: parent
                                        color: {
                                            if (productoEditandoIndex === index) return "#FFF9C4"
                                            if (modoEdicion) return "#F5F5F5"
                                            return "transparent"
                                        }
                                        opacity: {
                                            if (productoEditandoIndex === index) return 0.5
                                            if (modoEdicion) return 0.3
                                            return 0
                                        }
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
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.leftMargin: spacing4
                                                anchors.right: parent.right
                                                anchors.rightMargin: spacing4
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: modelData.nombre || ""
                                                color: textColor
                                                font.bold: true
                                                font.pixelSize: fontSmall
                                                elide: Text.ElideRight
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
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 80
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#D5DBDB"
                                            border.width: 1
                                            
                                            RowLayout {
                                                anchors.centerIn: parent
                                                spacing: 4
                                                
                                                Rectangle {
                                                    width: 24
                                                    height: 24
                                                    color: editarMouseArea.pressed ? "#2980b9" : blueColor
                                                    radius: 4
                                                    
                                                    Label {
                                                        anchors.centerIn: parent
                                                        text: "✏️"
                                                        color: whiteColor
                                                        font.pixelSize: 10
                                                    }
                                                    
                                                    MouseArea {
                                                        id: editarMouseArea
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        
                                                        onClicked: {
                                                            editarProductoExistente(index)
                                                        }
                                                        
                                                        onHoveredChanged: {
                                                            parent.scale = containsMouse ? 1.1 : 1.0
                                                        }
                                                    }
                                                    
                                                    Behavior on scale {
                                                        NumberAnimation { duration: 100 }
                                                    }
                                                }
                                                
                                                Rectangle {
                                                    width: 24
                                                    height: 24
                                                    color: eliminarMouseArea.pressed ? "#c0392b" : dangerColor
                                                    radius: 4
                                                    
                                                    Label {
                                                        anchors.centerIn: parent
                                                        text: "🗑️"
                                                        color: whiteColor
                                                        font.pixelSize: 10
                                                    }
                                                    
                                                    MouseArea {
                                                        id: eliminarMouseArea
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        
                                                        onClicked: {
                                                            if (compraModel) {
                                                                compraModel.remover_item_compra(modelData.codigo)
                                                            }
                                                            updatePurchaseTotal()
                                                        }
                                                        
                                                        onHoveredChanged: {
                                                            parent.scale = containsMouse ? 1.1 : 1.0
                                                        }
                                                    }
                                                    
                                                    Behavior on scale {
                                                        NumberAnimation { duration: 100 }
                                                    }
                                                }
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
        
        // SECCIÓN ACCIONES
        Rectangle {
            id: actionsSection
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: spacing8
            height: 50
            color: whiteColor
            radius: radiusMedium
            border.color: modoEdicion ? editModeColor : lightGrayColor
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
                            text: `TOTAL: Bs${(compraModel ? compraModel.total_compra_actual : 0).toFixed(2)}`
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
                    enabled: (providerCombo ? providerCombo.currentIndex > 0 : false) && 
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
                        if (completarCompra()) {
                            var textoExito = modoEdicion ? "✅ ¡Actualizado!" : "✅ ¡Completado!"
                            completarCompraButton.text = textoExito
                            Qt.callLater(function() {
                                completarCompraButton.text = modoEdicion ? "💾 Guardar Cambios" : "📦 Completar Compra"
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
            color: modoEdicion ? editModeColor : successColor
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
                        color: modoEdicion ? editModeColor : successColor
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
            visible: showProductDropdown && productoEditandoIndex < 0
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

    // CONEXIONES CORREGIDAS
    Connections {
        target: compraModel
        function onItemsCompraCambiado() {
            updatePurchaseTotal()
        }
    }

    Component.onCompleted: {
        console.log("✅ CrearCompra.qml inicializado con interfaz minimalista")
        
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