import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

Item {
    id: comprasRoot
    objectName: "comprasRoot"
    
    // Referencia al módulo principal de farmacia
    property var farmaciaData: parent.farmaciaData
    
    // Propiedades de colores consistentes
    readonly property color primaryColor: "#273746"
    readonly property color primaryDarkColor: "#34495E"
    readonly property color successColor: "#27ae60"
    readonly property color dangerColor: "#E74C3C"
    readonly property color warningColor: "#f39c12"
    readonly property color lightGrayColor: "#ECF0F1"
    readonly property color darkGrayColor: "#7f8c8d"
    readonly property color textColor: "#2c3e50"
    readonly property color whiteColor: "#FFFFFF"
    readonly property color blueColor: "#3498db"
    
    // Estados de la interfaz
    property int currentView: 0 // 0 = Lista, 1 = Nueva Compra
    property bool showProviderDialog: false
    property bool showPurchaseDetailsDialog: false
    property var selectedPurchase: null
    property var purchaseDetails: []
    
    // Datos para nueva compra
    property string newPurchaseProvider: ""
    property string newPurchaseUser: "Dr. Admin"
    property string newPurchaseDate: "04/07/2025"
    property string newPurchaseId: "C" + String((farmaciaData && farmaciaData.comprasModel ? farmaciaData.comprasModel.count : 0) + 1).padStart(3, '0')
    property real newPurchaseTotal: 0.0
    property string newPurchaseDetails: "" // Nueva propiedad para detalles
    
    // Campos de entrada para productos MEJORADOS
    property string inputProductCode: ""
    property string inputProductName: ""
    property int inputBoxes: 0
    property int inputUnits: 0
    property int inputTotalStock: 0
    property real inputPurchasePrice: 0.0
    property real inputSalePrice: 0.0
    property string inputExpiryDate: ""
    property bool isNewProduct: true // Indica si es producto nuevo o existente
    
    // Lista temporal de productos para la nueva compra
    ListModel {
        id: temporaryProductsModel
    }
    
    // Modelo para resultados de búsqueda de productos existentes
    ListModel {
        id: productSearchResultsModel
    }

        // AGREGAR ESTE MODELO NUEVO
    ListModel {
        id: comprasPaginadasModel
    }
    
    property bool showSuccessMessage: false
    property string successMessage: ""
    // Propiedades de paginación para compras
    property int itemsPerPageCompras: 10
    property int currentPageCompras: 0
    property int totalPagesCompras: 0
    property bool showProductDropdown: false

    // CONEXIÓN CON DATOS CENTRALES
    Connections {
        target: farmaciaData
        function onDatosActualizados() {
            console.log("🚚 Compras: Datos centrales actualizados")
            updateProviderNames() 
            actualizarPaginacionCompras()
        }
    }
    
    // PROPIEDADES PARA PROVEEDORES
    property var providerNames: ["Seleccionar proveedor..."]

    // Función simplificada para actualizar proveedores desde el modelo central
    function updateProviderNames() {
        var names = ["Seleccionar proveedor..."]
        
        if (farmaciaData && farmaciaData.proveedoresModel) {
            for (var i = 0; i < farmaciaData.proveedoresModel.count; i++) {
                var provider = farmaciaData.proveedoresModel.get(i)
                if (provider && provider.nombre) {
                    names.push(provider.nombre)
                }
            }
        }
        
        providerNames = names
    }
    
    function updatePurchaseTotal() {
        var total = 0.0
        for (var i = 0; i < temporaryProductsModel.count; i++) {
            var item = temporaryProductsModel.get(i)
            total += item.precioCompra  // ← SOLO SUMAR EL PRECIO DE COMPRA
        }
        newPurchaseTotal = total
    }
    // Función para obtener detalles de una compra
    function obtenerDetallesCompra(compraId) {
        if (!farmaciaData) return []
        
        console.log("🔍 Buscando detalles para:", compraId)
        
        if (farmaciaData.obtenerProductosDeCompra) {
            var productos = farmaciaData.obtenerProductosDeCompra(compraId)
            console.log("📦 Productos encontrados:", productos.length)
            
            // Convertir a ListModel compatible
            var detalles = []
            for (var i = 0; i < productos.length; i++) {
                detalles.push(productos[i])
            }
            return detalles
        }
        return []
    }

    // FUNCIÓN: Buscar productos existentes usando datos centrales
    function buscarProductosExistentes(texto) {
        console.log("🔍 Compras: Buscando productos existentes:", texto)
        productSearchResultsModel.clear()
        
        if (!farmaciaData || texto.length < 2) {
            showProductDropdown = false
            return
        }
        
        var textoBusqueda = texto.toLowerCase()
        var encontrado = false
        
        // Usar datos centrales
        if (farmaciaData.productosUnicosModel) {
            for (var i = 0; i < farmaciaData.productosUnicosModel.count; i++) {
                var producto = farmaciaData.productosUnicosModel.get(i)
                
                if (producto.nombre.toLowerCase().indexOf(textoBusqueda) >= 0 || 
                    producto.codigo.toLowerCase().indexOf(textoBusqueda) >= 0) {
                    
                    productSearchResultsModel.append({
                        codigo: producto.codigo,
                        nombre: producto.nombre,
                        precioCompraBase: producto.precioCompraBase,
                        precioVentaBase: producto.precioVentaBase,
                        unidadMedida: producto.unidadMedida
                    })
                    encontrado = true
                }
            }
        }
        
        // Si encontró productos, mostrar dropdown, si no, permitir crear nuevo
        if (encontrado) {
            showProductDropdown = true
            isNewProduct = false
        } else {
            showProductDropdown = false
            isNewProduct = true
            inputProductName = ""
        }
        
        console.log("📦 Compras: Productos encontrados desde centro:", productSearchResultsModel.count)
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
            showSuccess("❌ Error: Ingrese el código del producto")
            return false
        }
        
        if (inputProductName.length === 0) {
            showSuccess("❌ Error: Ingrese el nombre del producto")
            return false
        }
        
        if (inputBoxes <= 0 && inputUnits <= 0) {
            showSuccess("❌ Error: Ingrese cantidad de cajas o unidades")
            return false
        }
        
        if (inputPurchasePrice <= 0) {
            showSuccess("❌ Error: El precio de compra debe ser mayor a 0")
            return false
        }
        
        // Validar fecha de vencimiento
        if (inputExpiryDate.length > 0 && !validateExpiryDate(inputExpiryDate)) {
            showSuccess("❌ Error: Fecha de vencimiento inválida (DD/MM/YYYY)")
            return false
        }
        
        // Verificar si el producto ya está en la lista temporal
        for (var i = 0; i < temporaryProductsModel.count; i++) {
            var item = temporaryProductsModel.get(i)
            if (item.codigo === inputProductCode) {
                showSuccess("❌ Error: El producto ya está agregado a esta compra")
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
        
        // AGREGAR ESTA LÍNEA para sincronizar el campo visual:
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
        
        if (!farmaciaData) {
            showSuccess("❌ Error: No se puede acceder a los datos centrales")
            return false
        }
        
        if (newPurchaseProvider === "") {
            showSuccess("❌ Error: Seleccione un proveedor")
            return false
        }
        
        if (temporaryProductsModel.count === 0) {
            showSuccess("❌ Error: Agregue al menos un producto")
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
        if (farmaciaData.agregarCompraConDetalles) {
            try {
                console.log("🚚 Llamando a farmaciaData.agregarCompraConDetalles...")
                compraId = farmaciaData.agregarCompraConDetalles(newPurchaseProvider, newPurchaseUser, productosArray, newPurchaseDetails)
            } catch (e) {
                console.log("❌ Error al procesar compra:", e.message)
                showSuccess("❌ Error al procesar la compra: " + e.message)
                return false
            }
        }
        
        if (compraId) {
            console.log("✅ Compra completada en sistema central:", compraId)
            
            // Limpiar formulario
            clearPurchase()
            clearProductFields()
            
            // Generar nuevo ID
            newPurchaseId = "C" + String((farmaciaData.comprasModel ? farmaciaData.comprasModel.count : 0) + 1).padStart(3, '0')
            
            // Mostrar mensaje y volver a lista
            showSuccess("✅ Compra " + compraId + " completada exitosamente")
            currentView = 0
            actualizarPaginacionCompras() 
            
            return true
        } else {
            showSuccess("❌ Error: No se pudo completar la compra")
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

    // FUNCIÓN CORREGIDA para Compras.qml
    function actualizarPaginacionCompras() {
        if (!farmaciaData || !farmaciaData.comprasModel) return
        
        var totalItems = farmaciaData.comprasModel.count
        totalPagesCompras = Math.ceil(totalItems / itemsPerPageCompras)
        
        // Ajustar página actual si es necesario
        if (currentPageCompras >= totalPagesCompras && totalPagesCompras > 0) {
            currentPageCompras = totalPagesCompras - 1
        }
        if (currentPageCompras < 0) {
            currentPageCompras = 0
        }
        
        // Limpiar modelo paginado
        comprasPaginadasModel.clear()
        
        // Calcular índices
        var startIndex = currentPageCompras * itemsPerPageCompras
        var endIndex = Math.min(startIndex + itemsPerPageCompras, totalItems)
        
        // Agregar elementos de la página actual
        for (var i = startIndex; i < endIndex; i++) {
            var compra = farmaciaData.comprasModel.get(i)
            comprasPaginadasModel.append(compra)
        }
        
        console.log("📄 Compras: Página", currentPageCompras + 1, "de", totalPagesCompras, 
                    "- Mostrando", comprasPaginadasModel.count, "de", totalItems)
    }

    // Timer para ocultar mensaje de éxito
    Timer {
        id: successTimer
        interval: 3000
        onTriggered: showSuccessMessage = false
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 24
        
        // Header con navegación
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            color: whiteColor
            radius: 16
            border.color: lightGrayColor
            border.width: 1
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 16
                
                Label {
                    text: "🚚"
                    font.pixelSize: 28
                    color: primaryColor
                }
                
                ColumnLayout {
                    spacing: 4
                    
                    Label {
                        text: "Módulo de Farmacia"
                        color: textColor
                        font.pixelSize: 24
                        font.bold: true
                    }
                    
                    Label {
                        text: "Gestión de Compras"
                        color: darkGrayColor
                        font.pixelSize: 14
                    }
                }
                
                Item { Layout.fillWidth: true }
                
                // Navegación principal
                Row {
                    spacing: 8
                    
                    TabButton {
                        text: "📋 Lista de Compras"
                        checked: currentView === 0
                        onClicked: currentView = 0
                        width: 150
                        height: 40
                        
                        background: Rectangle {
                            color: parent.checked ? blueColor : "transparent"
                            radius: 8
                            border.color: blueColor
                            border.width: 1
                        }
                        
                        contentItem: Label {
                            text: parent.text
                            color: parent.checked ? whiteColor : blueColor
                            font.bold: parent.checked
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                    
                    TabButton {
                        text: "+ Nueva Compra"
                        checked: currentView === 1
                        onClicked: {
                            currentView = 1
                        }
                        width: 150
                        height: 40
                        
                        background: Rectangle {
                            color: parent.checked ? successColor : "transparent"
                            radius: 8
                            border.color: successColor
                            border.width: 1
                        }
                        
                        contentItem: Label {
                            text: parent.text
                            color: parent.checked ? whiteColor : successColor
                            font.bold: parent.checked
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }
        
        // Contenido principal
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: whiteColor
            radius: 16
            border.color: lightGrayColor
            border.width: 1
            
            StackLayout {
                anchors.fill: parent
                anchors.margins: 20
                currentIndex: currentView
                
                // Vista 0: Lista de Compras
                ColumnLayout {
                    spacing: 20
                    
                    // Filtros y búsqueda
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16
                        
                        Label {
                            text: "🔍"
                            font.pixelSize: 16
                        }
                        
                        TextField {
                            Layout.preferredWidth: 200
                            placeholderText: "Buscar compras..."
                            background: Rectangle {
                                color: lightGrayColor
                                radius: 8
                                border.color: darkGrayColor
                                border.width: 1
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }


                    // Tabla de Lista de Compras
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: "#FFFFFF"
                        border.color: "#D5DBDB"
                        border.width: 1
                        radius: 8
                        
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 0
                            spacing: 0
                            
                            // Header de la tabla
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 50
                                color: "#F8F9FA"
                                
                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 0
                                    
                                    Rectangle {
                                        Layout.preferredWidth: 120
                                        Layout.fillHeight: true
                                        color: "#F8F9FA"
                                        border.color: "#D5DBDB"
                                        border.width: 1
                                        
                                        Label {
                                            anchors.centerIn: parent
                                            text: "ID COMPRA"
                                            color: "#2C3E50"
                                            font.bold: true
                                            font.pixelSize: 12
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 250
                                        Layout.fillHeight: true
                                        color: "#F8F9FA"
                                        border.color: "#D5DBDB"
                                        border.width: 1
                                        
                                        Label {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 12
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "PROVEEDOR"
                                            color: "#2C3E50"
                                            font.bold: true
                                            font.pixelSize: 12
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: 140
                                        Layout.fillHeight: true
                                        color: "#F8F9FA"
                                        border.color: "#D5DBDB"
                                        border.width: 1
                                        
                                        Label {
                                            anchors.centerIn: parent
                                            text: "USUARIO"
                                            color: "#2C3E50"
                                            font.bold: true
                                            font.pixelSize: 12
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: 140
                                        Layout.fillHeight: true
                                        color: "#F8F9FA"
                                        border.color: "#D5DBDB"
                                        border.width: 1
                                        
                                        Label {
                                            anchors.centerIn: parent
                                            text: "FECHA"
                                            color: "#2C3E50"
                                            font.bold: true
                                            font.pixelSize: 12
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
                                            text: "TOTAL"
                                            color: "#2C3E50"
                                            font.bold: true
                                            font.pixelSize: 12
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
                                            text: "DETALLE"
                                            color: "#2C3E50"
                                            font.bold: true
                                            font.pixelSize: 12
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
                                    model: comprasPaginadasModel
                                    
                                    delegate: Item {
                                        width: ListView.view.width
                                        height: 60
                                        
                                        RowLayout {
                                            anchors.fill: parent
                                            spacing: 0
                                            
                                            Rectangle {
                                                Layout.preferredWidth: 120
                                                Layout.fillHeight: true
                                                color: "transparent"
                                                border.color: "#D5DBDB"
                                                border.width: 1
                                                
                                                Label {
                                                    anchors.centerIn: parent
                                                    text: model.id
                                                    color: "#3498DB"
                                                    font.bold: true
                                                    font.pixelSize: 14
                                                }
                                            }
                                            
                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.minimumWidth: 250
                                                Layout.fillHeight: true
                                                color: "transparent"
                                                border.color: "#D5DBDB"
                                                border.width: 1
                                                
                                                ColumnLayout {
                                                    anchors.left: parent.left
                                                    anchors.leftMargin: 12
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    spacing: 4
                                                    
                                                    Label {
                                                        text: model.proveedor
                                                        color: "#2C3E50"
                                                        font.bold: true
                                                        font.pixelSize: 12
                                                        elide: Text.ElideRight
                                                        Layout.maximumWidth: 220
                                                    }
                                                }
                                            }
                                            
                                            Rectangle {
                                                Layout.preferredWidth: 140
                                                Layout.fillHeight: true
                                                color: "transparent"
                                                border.color: "#D5DBDB"
                                                border.width: 1
                                                
                                                RowLayout {
                                                    anchors.centerIn: parent
                                                    spacing: 6     
                                                    Label {
                                                        text: model.usuario
                                                        color: "#2C3E50"
                                                        font.pixelSize: 12
                                                    }
                                                }
                                            }
                                            
                                            Rectangle {
                                                Layout.preferredWidth: 140
                                                Layout.fillHeight: true
                                                color: "transparent"
                                                border.color: "#D5DBDB"
                                                border.width: 1
                                                
                                                ColumnLayout {
                                                    anchors.centerIn: parent
                                                    spacing: 2
                                                    
                                                    RowLayout {
                                                        spacing: 4                                                        
                                                        Label {
                                                            text: model.fecha
                                                            color: "#3498DB"
                                                            font.bold: true
                                                            font.pixelSize: 11
                                                        }
                                                    }
                                                    
                                                    Label {
                                                        text: model.hora
                                                        color: "#7F8C8D"
                                                        font.pixelSize: 10
                                                        Layout.alignment: Qt.AlignHCenter
                                                    }
                                                }
                                            }
                                            
                                            Rectangle {
                                                Layout.preferredWidth: 120
                                                Layout.fillHeight: true
                                                color: "transparent"
                                                border.color: "#D5DBDB"
                                                border.width: 1
                                                
                                                Rectangle {
                                                    anchors.centerIn: parent
                                                    width: 90
                                                    height: 28
                                                    color: "#27AE60"
                                                    radius: 14
                                                    
                                                    Label {
                                                        anchors.centerIn: parent
                                                        text: "Bs" + model.total.toFixed(2)
                                                        color: "#FFFFFF"
                                                        font.bold: true
                                                        font.pixelSize: 11
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
                                                    id: detailLabel
                                                    anchors.centerIn: parent
                                                    text: "Ver detalle"
                                                    color: detailMouseArea.containsMouse ? "#E74C3C" : "#3498DB"
                                                    font.pixelSize: 11
                                                    font.underline: true
                                                    
                                                    MouseArea {
                                                        id: detailMouseArea
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        
                                                        onClicked: {
                                                            selectedPurchase = model
                                                            // Cargar detalles de la compra
                                                            purchaseDetails = obtenerDetallesCompra(model.id)
                                                            showPurchaseDetailsDialog = true
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            // Control de Paginación - Centrado con indicador
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 60
                                color: "#F8F9FA"
                                border.color: "#D5DBDB"
                                border.width: 1
                                
                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 20
                                                                        
                                    Button {
                                        Layout.preferredWidth: 100
                                        Layout.preferredHeight: 36
                                        text: "← Anterior"
                                        enabled: currentPageCompras > 0
                                        
                                        background: Rectangle {
                                            color: parent.enabled ? 
                                                (parent.pressed ? Qt.darker("#10B981", 1.1) : "#10B981") :   // ✅ VERDE
                                                "#E5E7EB"
                                            radius: 18
                                            
                                            Behavior on color {
                                                ColorAnimation { duration: 150 }
                                            }
                                        }
                                        
                                        contentItem: Label {
                                            text: parent.text
                                            color: parent.enabled ? "#FFFFFF" : "#9CA3AF"   // ✅ BLANCO cuando activo
                                            font.bold: true
                                            font.pixelSize: 14
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        
                                        onClicked: {
                                            if (currentPageCompras > 0) {
                                                currentPageCompras--
                                                actualizarPaginacionCompras() 
                                                // Aquí iría la función para actualizar la vista
                                            }
                                        }
                                    }
                                    

                                    // 1. Indicador de página CORREGIDO:
                                    Label {
                                        text: "Página " + (currentPageCompras + 1) + " de " + Math.max(1, totalPagesCompras)
                                        color: "#374151"
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                    }

                                    // 2. Botón Siguiente CORREGIDO:
                                    Button {
                                        Layout.preferredWidth: 110
                                        Layout.preferredHeight: 36
                                        text: "Siguiente →"
                                        enabled: currentPageCompras < totalPagesCompras - 1  // ✅ CORREGIDO
                                        
                                        background: Rectangle {
                                            color: parent.enabled ? 
                                                (parent.pressed ? Qt.darker("#10B981", 1.1) : "#10B981") : 
                                                "#E5E7EB"
                                            radius: 18
                                            
                                            Behavior on color {
                                                ColorAnimation { duration: 150 }
                                            }
                                        }
                                        
                                        contentItem: Label {
                                            text: parent.text
                                            color: parent.enabled ? "#FFFFFF" : "#9CA3AF"
                                            font.bold: true
                                            font.pixelSize: 14
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        
                                        onClicked: {
                                            if (currentPageCompras < totalPagesCompras - 1) {  // ✅ CORREGIDO
                                                currentPageCompras++
                                                actualizarPaginacionCompras()  // ✅ CORREGIDO
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                // Vista 1: Nueva Compra MEJORADA
                ScrollView {
                    ColumnLayout {
                        width: parent.parent.width - 40
                        spacing: 20
                        
                        // SECCIÓN INTEGRADA: Información de compra + Búsqueda/Agregar productos
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 240
                            color: "#E3F2FD"
                            radius: 12
                            border.color: blueColor
                            border.width: 2
                            
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 16
                                
                                // Header con información básica
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 20
                                    
                                    ComboBox {
                                        id: providerCombo
                                        Layout.preferredWidth: 200
                                        model: comprasRoot.providerNames
                                        
                                        background: Rectangle {
                                            color: whiteColor
                                            border.color: darkGrayColor
                                            border.width: 1
                                            radius: 6
                                        }
                                        
                                        onCurrentTextChanged: {
                                            if (currentIndex > 0) {
                                                newPurchaseProvider = currentText
                                            } else {
                                                newPurchaseProvider = ""
                                            }
                                        }
                                        
                                        Connections {
                                            target: comprasRoot
                                            function onProviderNamesChanged() {
                                                providerCombo.model = comprasRoot.providerNames
                                            }
                                        }
                                    }
                                    
                                    Button {
                                        text: "+"
                                        width: 28
                                        height: 28
                                        background: Rectangle {
                                            color: successColor
                                            radius: 6
                                        }
                                        contentItem: Label {
                                            text: parent.text
                                            color: whiteColor
                                            font.bold: true
                                            font.pixelSize: 14
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        onClicked: showProviderDialog = true
                                    }
                                    
                                    Label {
                                        text: "Usuario: Dr. Admin"
                                        color: textColor
                                        font.pixelSize: 12
                                    }
                                    
                                    Label {
                                        text: "Fecha: 04/07/2025"
                                        color: textColor
                                        font.pixelSize: 12
                                    }
                                    
                                    Item { Layout.fillWidth: true }
                                }
                                
                                // Sección de búsqueda y creación de productos
                                RowLayout {
                                    Layout.fillWidth: true
                                    
                                    Label {
                                        text: "🔍"
                                        font.pixelSize: 16
                                    }
                                    
                                    Label {
                                        text: "BUSCAR PRODUCTO EXISTENTE O CREAR NUEVO"
                                        color: textColor
                                        font.bold: true
                                        font.pixelSize: 14
                                    }
                                }

                                // Fila de búsqueda y nombre
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 12
                                    
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4
                                        
                                        Label {
                                            text: "Buscar producto o ingresar código nuevo:"
                                            color: darkGrayColor
                                            font.pixelSize: 11
                                        }
                                        
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 36
                                            color: whiteColor
                                            radius: 8
                                            border.color: productCodeField.activeFocus ? blueColor : darkGrayColor
                                            border.width: 1
                                            
                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: 6
                                                spacing: 6
                                                
                                                Label {
                                                    text: "🔍"
                                                    color: darkGrayColor
                                                    font.pixelSize: 12
                                                }
                                                
                                                TextField {
                                                    id: productCodeField
                                                    Layout.fillWidth: true
                                                    placeholderText: "Código o nombre del producto..."
                                                    text: inputProductName.length > 0 ? inputProductName : inputProductCode  // ← MOSTRAR NOMBRE SI EXISTE
                                                    background: Rectangle { color: "transparent" }
                                                    font.pixelSize: 12
                                                    
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
                                        
                                        // Dropdown de productos encontrados (compacto)
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: Math.min(100, productSearchResultsModel.count * 35)
                                            color: whiteColor
                                            border.color: blueColor
                                            border.width: 1
                                            radius: 6
                                            visible: showProductDropdown
                                            z: 100
                                            
                                            ListView {
                                                anchors.fill: parent
                                                anchors.margins: 2
                                                model: productSearchResultsModel
                                                clip: true
                                                
                                                delegate: Rectangle {
                                                    width: ListView.view.width
                                                    height: 35
                                                    color: mouseArea.containsMouse ? "#E3F2FD" : "transparent"
                                                    
                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.margins: 6
                                                        spacing: 8
                                                        
                                                        Rectangle {
                                                            Layout.preferredWidth: 60
                                                            Layout.preferredHeight: 18
                                                            color: blueColor
                                                            radius: 9
                                                            
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
                                                            font.pixelSize: 11
                                                            Layout.fillWidth: true
                                                            elide: Text.ElideRight
                                                        }
                                                        
                                                        Label {
                                                            text: "Bs" + model.precioVentaBase.toFixed(2)
                                                            color: successColor
                                                            font.bold: true
                                                            font.pixelSize: 10
                                                        }
                                                    }
                                                    
                                                    MouseArea {
                                                        id: mouseArea
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        
                                                        onClicked: {
                                                            seleccionarProductoExistente(model.codigo, model.nombre)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                // Fila de cantidades y precios (compacta)
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    
                                    ColumnLayout {
                                        spacing: 2
                                        
                                        Label {
                                            text: "Cajas:"
                                            color: darkGrayColor
                                            font.pixelSize: 10
                                            font.bold: true
                                        }
                                        
                                        TextField {
                                            id: boxesField
                                            Layout.preferredWidth: 60
                                            Layout.preferredHeight: 32
                                            placeholderText: "0"
                                            text: inputBoxes > 0 ? inputBoxes.toString() : ""
                                            background: Rectangle {
                                                color: whiteColor
                                                radius: 6
                                                border.color: parent.activeFocus ? successColor : darkGrayColor
                                                border.width: 1
                                            }
                                            validator: IntValidator { bottom: 0; top: 9999 }
                                            font.pixelSize: 11
                                            horizontalAlignment: Text.AlignHCenter
                                            onTextChanged: {
                                                var newValue = text.length > 0 ? (parseInt(text) || 0) : 0
                                                if (inputBoxes !== newValue) {
                                                    inputBoxes = newValue
                                                    calculateTotalStock()
                                                }
                                            }
                                            onEditingFinished: {
                                                calculateTotalStock() // Asegurar cálculo al finalizar edición
                                            }   
                                        }
                                    }
                                    
                                    ColumnLayout {
                                        spacing: 2
                                        
                                        Label {
                                            text: "Unidades:"
                                            color: darkGrayColor
                                            font.pixelSize: 10
                                            font.bold: true
                                        }
                                        
                                        TextField {
                                            id: unitsField
                                            Layout.preferredWidth: 60
                                            Layout.preferredHeight: 32
                                            placeholderText: "0"
                                            text: inputUnits > 0 ? inputUnits.toString() : ""
                                            background: Rectangle {
                                                color: whiteColor
                                                radius: 6
                                                border.color: parent.activeFocus ? successColor : darkGrayColor
                                                border.width: 1
                                            }
                                            validator: IntValidator { bottom: 0; top: 9999 }
                                            font.pixelSize: 11
                                            horizontalAlignment: Text.AlignHCenter
                                            onTextChanged: {
                                                var newValue = text.length > 0 ? (parseInt(text) || 0) : 0
                                                if (inputUnits !== newValue) {
                                                    inputUnits = newValue
                                                    calculateTotalStock()
                                                }
                                            }
                                            onEditingFinished: {
                                                calculateTotalStock() // Asegurar cálculo al finalizar edición
                                            }
                                        }
                                    }
                                    
                                    ColumnLayout {
                                        spacing: 2
                                        
                                        Label {
                                            text: "Stock Total:"
                                            color: darkGrayColor
                                            font.pixelSize: 10
                                            font.bold: true
                                        }
                                        
                                        TextField {
                                            id: totalStockField
                                            Layout.preferredWidth: 80
                                            Layout.preferredHeight: 32
                                            placeholderText: "0"
                                            text: inputTotalStock > 0 ? inputTotalStock.toString() : ""
                                            background: Rectangle {
                                                color: whiteColor
                                                radius: 6
                                                border.color: parent.activeFocus ? blueColor : darkGrayColor
                                                border.width: 1
                                            }
                                            validator: IntValidator { bottom: 0; top: 99999 }
                                            font.pixelSize: 11
                                            horizontalAlignment: Text.AlignHCenter
                                            onTextChanged: {
                                                inputTotalStock = text.length > 0 ? (parseInt(text) || 0) : 0
                                            }
                                        }
                                    }
                                    
                                    ColumnLayout {
                                        spacing: 2
                                        
                                        Label {
                                            text: "Precio Compra:"
                                            color: darkGrayColor
                                            font.pixelSize: 10
                                            font.bold: true
                                        }
                                        
                                        TextField {
                                            id: purchasePriceField
                                            Layout.preferredWidth: 80
                                            Layout.preferredHeight: 32
                                            placeholderText: "0.00"
                                            text: inputPurchasePrice > 0 ? inputPurchasePrice.toString() : ""
                                            background: Rectangle {
                                                color: whiteColor
                                                radius: 6
                                                border.color: parent.activeFocus ? successColor : darkGrayColor
                                                border.width: 1
                                            }
                                            font.pixelSize: 11
                                            horizontalAlignment: Text.AlignHCenter
                                            onEditingFinished: {
                                                inputPurchasePrice = text.length > 0 ? (parseFloat(text) || 0.0) : 0.0
                                            }
                                        }
                                    }
                                    
                                    ColumnLayout {
                                        spacing: 2
                                        
                                        Label {
                                            text: "F. Vencimiento:"
                                            color: darkGrayColor
                                            font.pixelSize: 10
                                            font.bold: true
                                        }
                                        
                                        TextField {
                                            id: expiryField
                                            Layout.preferredWidth: 100
                                            Layout.preferredHeight: 32
                                            placeholderText: "DD/MM/YYYY"
                                            text: inputExpiryDate
                                            background: Rectangle {
                                                color: whiteColor
                                                radius: 6
                                                border.color: parent.activeFocus ? "#9C27B0" : darkGrayColor
                                                border.width: 1
                                            }
                                            font.pixelSize: 11
                                            onTextChanged: {
                                                var formatted = autoFormatDate(text)
                                                if (formatted !== text) {
                                                    text = formatted
                                                }
                                                inputExpiryDate = text
                                            }
                                        }
                                    }
                                    
                                    Button {
                                        text: "Agregar"
                                        Layout.topMargin: 16
                                        Layout.preferredHeight: 32
                                        enabled: inputProductCode.length > 0 && inputProductName.length > 0 && 
                                                inputTotalStock > 0 && inputPurchasePrice > 0
                                        background: Rectangle {
                                            color: enabled ? successColor : darkGrayColor
                                            radius: 6
                                        }
                                        contentItem: Label {
                                            text: parent.text
                                            color: whiteColor
                                            font.bold: true
                                            font.pixelSize: 12
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        onClicked: addProductToPurchase()
                                    }
                                }
                            }
                        }
                        
                        // Lista de productos MEJORADA
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 300
                            color: "#F8F9FA"
                            radius: 12
                            border.color: lightGrayColor
                            border.width: 1
                            
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 12
                                
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
                                        font.pixelSize: 14
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 250
                                    color: "#FFFFFF"
                                    border.color: "#D5DBDB"
                                    border.width: 1
                                    radius: 8
                                    
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 0
                                        spacing: 0
                                        
                                        // Header de la tabla de productos
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 40
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
                                                    
                                                    ColumnLayout {
                                                        anchors.fill: parent
                                                        
                                                        Label {
                                                            text: "CÓDIGO"
                                                            font.bold: true
                                                            font.pixelSize: 12
                                                            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                                                        }
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
                                                        anchors.leftMargin: 8
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: "NOMBRE"
                                                        color: "#2C3E50"
                                                        font.bold: true
                                                        font.pixelSize: 10
                                                    }
                                                }
                                                
                                                Rectangle {
                                                    Layout.preferredWidth: 70
                                                    Layout.fillHeight: true
                                                    color: "#F8F9FA"
                                                    border.color: "#D5DBDB"
                                                    border.width: 1
                                                    
                                                    Label {
                                                        anchors.centerIn: parent
                                                        text: "CAJA"
                                                        color: "#2C3E50"
                                                        font.bold: true
                                                        font.pixelSize: 9
                                                    }
                                                }
                                                
                                                Rectangle {
                                                    Layout.preferredWidth: 90
                                                    Layout.fillHeight: true
                                                    color: "#F8F9FA"
                                                    border.color: "#D5DBDB"
                                                    border.width: 1
                                                    
                                                    Label {
                                                        anchors.centerIn: parent
                                                        text: "STOCK UNIDAD"
                                                        color: "#2C3E50"
                                                        font.bold: true
                                                        font.pixelSize: 8
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
                                                        color: "#2C3E50"
                                                        font.bold: true
                                                        font.pixelSize: 8
                                                    }
                                                }                                              
                                            }
                                        }
                                        
                                        // Contenido de la tabla de productos
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
                                                                color: "#2C3E50"
                                                                font.bold: true
                                                                font.pixelSize: 10
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
                                                                anchors.margins: 8
                                                                spacing: 8
                                                                
                                                                Label {
                                                                    text: model.nombre
                                                                    color: "#2C3E50"
                                                                    font.bold: true
                                                                    font.pixelSize: 10
                                                                    elide: Text.ElideRight
                                                                    Layout.fillWidth: true
                                                                    wrapMode: Text.WordWrap
                                                                    maximumLineCount: 2
                                                                }
                                                                
                                                                Button {
                                                                    width: 20
                                                                    height: 20
                                                                    text: "🗑️"
                                                                    background: Rectangle {
                                                                        color: "#E74C3C"
                                                                        radius: 10
                                                                    }
                                                                    contentItem: Label {
                                                                        text: parent.text
                                                                        color: "#FFFFFF"
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
                                                        
                                                        // CAJAS
                                                        Rectangle {
                                                            Layout.preferredWidth: 70
                                                            Layout.fillHeight: true
                                                            color: "transparent"
                                                            border.color: "#D5DBDB"
                                                            border.width: 1
                                                            
                                                            Rectangle {
                                                                anchors.centerIn: parent
                                                                width: 40
                                                                height: 20
                                                                color: "#F39C12"
                                                                radius: 10
                                                                
                                                                Label {
                                                                    anchors.centerIn: parent
                                                                    text: model.cajas
                                                                    color: "#FFFFFF"
                                                                    font.bold: true
                                                                    font.pixelSize: 9
                                                                }
                                                            }
                                                        }
                                                        
                                                        // STOCK UNIDAD
                                                        Rectangle {
                                                            Layout.preferredWidth: 90
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
                                                                    color: "#FFFFFF"
                                                                    font.bold: true
                                                                    font.pixelSize: 9
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
                                                                color: "#27AE60"
                                                                font.bold: true
                                                                font.pixelSize: 9
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        
                                        // Estado vacío
                                        Label {
                                            anchors.centerIn: parent
                                            text: temporaryProductsModel.count === 0 ? 
                                                "No hay productos agregados aún" : ""
                                            color: "#7F8C8D"
                                            font.italic: true
                                            font.pixelSize: 12
                                            horizontalAlignment: Text.AlignHCenter
                                            visible: temporaryProductsModel.count === 0
                                        }
                                    }
                                }
                            }
                        }

                        // Total y acciones
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 20
                            
                            Item { Layout.fillWidth: true }
                            
                            // Total de la compra
                            Rectangle {
                                Layout.preferredWidth: 200
                                Layout.preferredHeight: 50
                                color: newPurchaseTotal > 0 ? successColor : darkGrayColor
                                radius: 8
                                
                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    
                                    Label {
                                        text: "💰"
                                        color: whiteColor
                                        font.pixelSize: 16
                                    }
                                    
                                    Label {
                                        text: "TOTAL: Bs" + newPurchaseTotal.toFixed(2)
                                        color: whiteColor
                                        font.bold: true
                                        font.pixelSize: 16
                                    }
                                }
                            }
                            
                            // Botón cancelar
                            Button {
                                text: "✖ Cancelar"
                                background: Rectangle {
                                    color: dangerColor
                                    radius: 8
                                }
                                contentItem: Label {
                                    text: parent.text
                                    color: whiteColor
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                onClicked: {
                                    clearPurchase()
                                    providerCombo.currentIndex = 0
                                    currentView = 0
                                }
                            }
                            
                            // Botón completar compra
                            Button {
                                text: "💾 Completar Compra"
                                enabled: providerCombo.currentIndex > 0 && temporaryProductsModel.count > 0
                                background: Rectangle {
                                    color: enabled ? successColor : darkGrayColor
                                    radius: 8
                                }
                                contentItem: Label {
                                    text: parent.text
                                    color: whiteColor
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                onClicked: {
                                    if (completarCompra()) {
                                        providerCombo.currentIndex = 0
                                    }
                                }
                            }
                        }

                        // Notificación de éxito
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 50
                            color: successColor
                            radius: 8
                            visible: showSuccessMessage
                            opacity: showSuccessMessage ? 1.0 : 0.0
                            
                            Behavior on opacity {
                                NumberAnimation { duration: 300 }
                            }
                            
                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 12
                                
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
                                    font.pixelSize: 14
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    // Diálogo Configuración de Proveedores (Fondo)
    Rectangle {
        id: configProveedoresBackground
        anchors.fill: parent
        color: "black"
        opacity: showProviderDialog ? 0.5 : 0
        visible: opacity > 0
        
        MouseArea {
            anchors.fill: parent
            onClicked: showProviderDialog = false
        }
        
        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }
    }

    // Diálogo Principal de Proveedores
    Rectangle {
        id: configProveedoresDialog
        anchors.centerIn: parent
        width: 700
        height: 600
        color: whiteColor
        radius: 20
        border.color: lightGrayColor
        border.width: 2
        visible: showProviderDialog
        
        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            
            // Header fijo para título y formulario
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 350
                color: whiteColor
                radius: 20
                z: 10
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 30
                    spacing: 20
                    
                    Label {
                        Layout.fillWidth: true
                        text: "🏢 Configuración de Proveedores"
                        font.pixelSize: 24
                        font.bold: true
                        color: textColor
                        horizontalAlignment: Text.AlignHCenter
                    }
                    
                    // Formulario para agregar nuevo proveedor
                    GroupBox {
                        Layout.fillWidth: true
                        title: "Agregar Nuevo Proveedor"
                        
                        background: Rectangle {
                            color: "#f8f9fa"
                            border.color: lightGrayColor
                            border.width: 1
                            radius: 8
                        }
                        
                        GridLayout {
                            anchors.fill: parent
                            columns: 2
                            rowSpacing: 12
                            columnSpacing: 10
                            
                            Label {
                                text: "Nombre Proveedor:"
                                font.bold: true
                                color: textColor
                            }
                            TextField {
                                id: nuevoProveedorNombre
                                Layout.fillWidth: true
                                placeholderText: "Ej: Farmacéutica Nacional S.A."
                                background: Rectangle {
                                    color: whiteColor
                                    border.color: lightGrayColor
                                    border.width: 1
                                    radius: 6
                                }
                            }
                            
                            Label {
                                text: "Celular:"
                                font.bold: true
                                color: textColor
                            }
                            TextField {
                                id: nuevoProveedorCelular
                                Layout.fillWidth: true
                                placeholderText: "Ej:+591 67819311 "
                                background: Rectangle {
                                    color: whiteColor
                                    border.color: lightGrayColor
                                    border.width: 1
                                    radius: 6
                                }
                            }
                            
                            Label {
                                text: "Correo (opcional):"
                                font.bold: true
                                color: textColor
                            }
                            TextField {
                                id: nuevoProveedorCorreo
                                Layout.fillWidth: true
                                placeholderText: "Ej: ventas@proveedor.com"
                                background: Rectangle {
                                    color: whiteColor
                                    border.color: lightGrayColor
                                    border.width: 1
                                    radius: 6
                                }
                            }
                            
                            Label {
                                text: "Ubicación:"
                                font.bold: true
                                color: textColor
                            }
                            TextField {
                                id: nuevoProveedorUbicacion
                                Layout.fillWidth: true
                                placeholderText: "Ej: Av. Principal 123, Ciudad Capital"
                                background: Rectangle {
                                    color: whiteColor
                                    border.color: lightGrayColor
                                    border.width: 1
                                    radius: 6
                                }
                            }
                            
                            Item { }
                            Button {
                                Layout.alignment: Qt.AlignRight
                                text: "➕ Agregar"
                                enabled: nuevoProveedorNombre.text.length > 0 && nuevoProveedorCelular.text.length > 0
                                background: Rectangle {
                                    color: enabled ? successColor : darkGrayColor
                                    radius: 8
                                }
                                contentItem: Label {
                                    text: parent.text
                                    color: whiteColor
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                onClicked: {
                                    if (nuevoProveedorNombre.text.length > 0 && nuevoProveedorCelular.text.length > 0) {
                                        
                                        // Agregar al modelo central de farmacia
                                        if (farmaciaData && farmaciaData.agregarProveedor) {
                                            var agregado = farmaciaData.agregarProveedor(
                                                nuevoProveedorNombre.text.trim(),
                                                nuevoProveedorUbicacion.text.trim(),
                                                nuevoProveedorCelular.text.trim(),
                                                nuevoProveedorCorreo.text.trim()
                                            )
                                            
                                            if (agregado) {
                                                // Actualizar lista de proveedores
                                                updateProviderNames()
                                                
                                                // Limpiar campos
                                                nuevoProveedorNombre.text = ""
                                                nuevoProveedorCelular.text = ""
                                                nuevoProveedorCorreo.text = ""
                                                nuevoProveedorUbicacion.text = ""
                                                
                                                showSuccess("✅ Proveedor agregado exitosamente")
                                            } else {
                                                showSuccess("❌ Error al agregar proveedor")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // Lista de proveedores existentes con scroll limitado
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 30
                Layout.topMargin: 0
                color: "transparent"
                
                ScrollView {
                    anchors.fill: parent
                    clip: true
                    
                    ListView {
                        model: farmaciaData ? farmaciaData.proveedoresModel : null
                        delegate: Rectangle {
                            width: ListView.view.width
                            height: 70
                            color: index % 2 === 0 ? "transparent" : "#fafafa"
                            border.color: "#e8e8e8"
                            border.width: 1
                            radius: 8
                            
                            GridLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                columns: 4
                                rowSpacing: 6
                                columnSpacing: 12
                                
                                // Nombre y Ubicación
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    
                                    Label {
                                        text: model.nombre || "Sin nombre"
                                        font.bold: true
                                        color: primaryColor
                                        font.pixelSize: 14
                                    }
                                    Label {
                                        text: (model.direccion && model.direccion.length > 0) ? model.direccion : "Sin ubicación"
                                        color: textColor
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                        Layout.maximumWidth: 200
                                    }
                                }
                                
                                // Celular
                                ColumnLayout {
                                    Layout.preferredWidth: 120
                                    spacing: 4
                                    
                                    Label {
                                        text: "📞 Celular"
                                        font.bold: true
                                        color: successColor
                                        font.pixelSize: 12
                                    }
                                    Label {
                                        text: (model.telefono && model.telefono.length > 0) ? model.telefono : "Sin celular"
                                        color: successColor
                                        font.bold: true
                                        font.pixelSize: 12
                                    }
                                }
                                
                                // Correo
                                ColumnLayout {
                                    Layout.preferredWidth: 150
                                    spacing: 4
                                    
                                    Label {
                                        text: "✉️ Correo"
                                        font.bold: true
                                        color: "#3498db"
                                        font.pixelSize: 12
                                    }
                                    Label {
                                        text: (model.email && model.email.length > 0) ? model.email : "Sin correo"
                                        color: "#3498db"
                                        font.bold: true
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                        Layout.maximumWidth: 140
                                    }
                                }
                                
                                // Botón eliminar
                                Button {
                                    Layout.preferredWidth: 30
                                    Layout.preferredHeight: 30
                                    text: "🗑️"
                                    background: Rectangle {
                                        color: dangerColor
                                        radius: 6
                                    }
                                    contentItem: Label {
                                        text: parent.text
                                        color: whiteColor
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    onClicked: {
                                        if (farmaciaData && farmaciaData.proveedoresModel) {
                                            farmaciaData.proveedoresModel.remove(index)
                                            updateProviderNames()
                                            showSuccess("🗑️ Proveedor eliminado")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // Botón cerrar en la parte inferior
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                color: whiteColor
                
                RowLayout {
                    anchors.centerIn: parent
                    
                    Button {
                        text: "Cerrar"
                        width: 100
                        height: 36
                        background: Rectangle {
                            color: "#ECF0F1"
                            radius: 6
                            border.color: "#BDC3C7"
                            border.width: 1
                        }
                        contentItem: Label {
                            text: parent.text
                            color: "#5D6D7E"
                            font.pixelSize: 14
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: {
                            showProviderDialog = false
                            // Limpiar campos al cerrar
                            nuevoProveedorNombre.text = ""
                            nuevoProveedorCelular.text = ""
                            nuevoProveedorCorreo.text = ""
                            nuevoProveedorUbicacion.text = ""
                        }
                    }
                }
            }
        }
    }
    // Diálogo para mostrar detalles de compra
    Rectangle {
        id: purchaseDetailsDialog
        anchors.fill: parent
        color: "#80000000"
        visible: showPurchaseDetailsDialog
        
        MouseArea {
            anchors.fill: parent
            onClicked: showPurchaseDetailsDialog = false
        }
        
        Rectangle {
            anchors.centerIn: parent
            width: 700
            height: 500
            color: "#FFFFFF"
            radius: 8
            border.color: "#D5DBDB"
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 16
                
                // Header
                RowLayout {
                    Layout.fillWidth: true
                    
                    Label {
                        text: "Detalles de Compra: " + (selectedPurchase ? selectedPurchase.id : "")
                        color: "#2C3E50"
                        font.bold: true
                        font.pixelSize: 16
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    Button {
                        text: "Cerrar"
                        width: 80
                        height: 32
                        background: Rectangle {
                            color: "#ECF0F1"
                            radius: 4
                            border.color: "#BDC3C7"
                            border.width: 1
                        }
                        contentItem: Label {
                            text: parent.text
                            color: "#5D6D7E"
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: showPurchaseDetailsDialog = false
                    }
                }
                
                // Tabla de productos
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#FFFFFF"
                    border.color: "#D5DBDB"
                    border.width: 1
                    
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0
                        
                        // Header de tabla
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
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
                                        font.pixelSize: 12
                                    }
                                }
                                
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    color: "#F8F9FA"
                                    border.color: "#D5DBDB"
                                    border.width: 1
                                    Label {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "NOMBRE"
                                        font.bold: true
                                        font.pixelSize: 12
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
                                        text: "CAJA"
                                        font.bold: true
                                        font.pixelSize: 12
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
                                        text: "STOCK UNIDAD"
                                        font.bold: true
                                        font.pixelSize: 12
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
                                        font.bold: true
                                        font.pixelSize: 12
                                    }
                                }
                            }
                        }
                        
                        // Contenido scrolleable
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            
                            ListView {
                                model: purchaseDetails.length ? purchaseDetails : []
                                
                                delegate: Rectangle {
                                    width: ListView.view.width
                                    height: 50
                                    color: "#FFFFFF"
                                    
                                    RowLayout {
                                        anchors.fill: parent
                                        spacing: 0
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 100
                                            Layout.fillHeight: true
                                            border.color: "#D5DBDB"
                                            border.width: 1
                                            Label {
                                                anchors.centerIn: parent
                                                text: model.codigo || ""
                                                font.pixelSize: 11
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            border.color: "#D5DBDB"
                                            border.width: 1
                                            Label {
                                                anchors.left: parent.left
                                                anchors.leftMargin: 8
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: model.nombre || ""
                                                font.pixelSize: 11
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 80
                                            Layout.fillHeight: true
                                            border.color: "#D5DBDB"
                                            border.width: 1
                                            Label {
                                                anchors.centerIn: parent
                                                text: model.cajas || "0"
                                                font.pixelSize: 11
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 100
                                            Layout.fillHeight: true
                                            border.color: "#D5DBDB"
                                            border.width: 1
                                            Label {
                                                anchors.centerIn: parent
                                                text: model.stockTotal || "0"
                                                font.pixelSize: 11
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 120
                                            Layout.fillHeight: true
                                            border.color: "#D5DBDB"
                                            border.width: 1
                                            Label {
                                                anchors.centerIn: parent
                                                text: "Bs" + (model.precioCompra ? model.precioCompra.toFixed(2) : "0.00")
                                                font.pixelSize: 11
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
    // Función para obtener total de compras
    function getTotalComprasCount() {
        return farmaciaData ? farmaciaData.comprasModel.count : 0
    }
    Component.onCompleted: {
        console.log("🚚 Módulo Compras iniciado")
        console.log("farmaciaData disponible:", !!farmaciaData)
        
        if (farmaciaData) {
            console.log("proveedoresModel disponible:", !!farmaciaData.proveedoresModel)
            updateProviderNames()
            actualizarPaginacionCompras()
        } else {
            console.log("⚠️ farmaciaData no disponible al iniciar")
        }
    }
}