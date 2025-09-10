import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15

// Componente para crear/editar producto - CON SISTEMA DE LOTES COMPLETO
Item {
    id: crearProductoRoot
    
    // Propiedades de comunicación
    property var inventarioModel: null
    property var farmaciaData: null
    property bool modoEdicion: false
    property var productoData: null
    property var marcasModel: []
    
    // Señales
    signal productoCreado(var producto)
    signal productoActualizado(var producto) 
    signal cancelarCreacion()
    signal volverALista()
    
    // Métricas del diseño
    readonly property real baseSpacing: 20
    readonly property real cardPadding: 24
    readonly property real inputHeight: 48
    readonly property real buttonHeight: 50
    readonly property real headerHeight: 70
    readonly property real sectionSpacing: 20
    
    // Colores
    readonly property color primaryBlue: "#2563EB"
    readonly property color successGreen: "#059669"
    readonly property color warningAmber: "#D97706"
    readonly property color dangerRed: "#DC2626"
    readonly property color grayLight: "#F3F4F6"
    readonly property color grayMedium: "#6B7280"
    readonly property color grayDark: "#374151"
    readonly property color white: "#FFFFFF"
    readonly property color borderColor: "#D1D5DB"
    
    // Estados
    property bool showSuccessMessage: false
    property string successMessage: ""
    property bool marcasCargadas: false
    
    // Datos del formulario - PRODUCTO
    property string inputProductCode: ""
    property string inputProductName: ""
    property string inputProductDetails: ""
    property real inputPurchasePrice: 0.0
    property real inputSalePrice: 0.0
    property string inputMeasureUnit: "Tabletas"
    property real calculatedMargin: 0.0

    // Datos del formulario - PRIMER LOTE
    property string inputExpirationDate: ""
    property int inputStockBox: 0
    property int inputStockUnit: 0
    property string inputSupplier: ""
    
    // Validación
    property bool isFormValid: {
        return inputProductCode.length > 0 &&
               inputProductName.length > 0 &&
               inputPurchasePrice > 0 &&
               inputSalePrice > 0 &&
               marcaCombo.currentIndex >= 0 &&
               inputExpirationDate.length > 0 &&
               (inputStockBox > 0 || inputStockUnit > 0)  // Al menos algo de stock
    }

    // Timer para notificaciones
    Timer {
        id: successTimer
        interval: 3000
        onTriggered: showSuccessMessage = false
    }

    // FUNCIONES
    function cargarMarcasDisponibles() {
        if (!inventarioModel) return
        
        try {
            var marcas = inventarioModel.get_marcas_disponibles()
            if (marcas && marcas.length > 0) {
                marcasModel = marcas
                marcasCargadas = true
            } else {
                marcasModel = []
            }
        } catch (error) {
            marcasModel = []
        }
        marcasCargadas = true
    }
    
    function calcularMargen() {
        if (inputPurchasePrice > 0 && inputSalePrice > 0) {
            calculatedMargin = ((inputSalePrice - inputPurchasePrice) / inputPurchasePrice) * 100
        } else {
            calculatedMargin = 0
        }
    }
    
    function validarFechaVencimiento() {
        if (!inputExpirationDate) return false
        
        // Validar formato YYYY-MM-DD o DD/MM/YYYY
        var regex1 = /^\d{4}-\d{2}-\d{2}$/  // YYYY-MM-DD
        var regex2 = /^\d{2}\/\d{2}\/\d{4}$/ // DD/MM/YYYY
        
        if (!regex1.test(inputExpirationDate) && !regex2.test(inputExpirationDate)) {
            return false
        }
        
        // Validar que la fecha sea futura
        var fechaIngresada = new Date(inputExpirationDate)
        var hoy = new Date()
        
        return fechaIngresada > hoy
    }
    
    function formatearFechaParaBD() {
        if (!inputExpirationDate) return ""
        
        // Si ya está en formato YYYY-MM-DD
        if (/^\d{4}-\d{2}-\d{2}$/.test(inputExpirationDate)) {
            return inputExpirationDate
        }
        
        // Si está en formato DD/MM/YYYY, convertir
        if (/^\d{2}\/\d{2}\/\d{4}$/.test(inputExpirationDate)) {
            var partes = inputExpirationDate.split('/')
            return partes[2] + '-' + partes[1] + '-' + partes[0]
        }
        
        return inputExpirationDate
    }
    
    function guardarProducto() {
        if (!isFormValid) {
            showNotification("Complete todos los campos obligatorios")
            return false
        }
        
        if (!validarFechaVencimiento()) {
            showNotification("Fecha de vencimiento inválida o en el pasado")
            return false
        }
        
        // Datos del producto
        var producto = {
            codigo: inputProductCode.trim(),
            nombre: inputProductName.trim(),
            detalles: inputProductDetails.trim(),
            id_marca: marcaCombo.currentValue,
            precio_compra: inputPurchasePrice,
            precio_venta: inputSalePrice,
            unidad_medida: inputMeasureUnit,
            // Stock inicial - será usado por el primer lote
            stock_caja: inputStockBox,
            stock_unitario: inputStockUnit,
            // Datos del primer lote
            fecha_vencimiento: formatearFechaParaBD(),
            proveedor: inputSupplier.trim()
        }
        
        if (modoEdicion) {
            // En modo edición, solo actualizar datos básicos del producto
            // (no crear nuevo lote)
            producto.id = productoData.id
            productoActualizado(producto)
            showNotification("Producto actualizado correctamente")
        } else {
            // Crear producto nuevo con primer lote
            productoCreado(producto)
            showNotification("Producto y primer lote creados correctamente")
        }
        
        Qt.callLater(function() {
            limpiarFormulario()
            volverALista()
        })
        
        return true
    }
    
    function limpiarFormulario() {
        // Limpiar datos del producto
        inputProductCode = ""
        inputProductName = ""
        inputProductDetails = ""
        inputPurchasePrice = 0.0
        inputSalePrice = 0.0
        calculatedMargin = 0.0
        
        // Limpiar datos del primer lote
        inputExpirationDate = ""
        inputStockBox = 0
        inputStockUnit = 0
        inputSupplier = ""
        
        // Limpiar campos UI
        codigoField.text = ""
        nombreField.text = ""
        detallesField.text = ""
        precioCompraField.text = ""
        precioVentaField.text = ""
        fechaVencimientoField.text = ""
        stockCajaField.text = ""
        stockUnitarioField.text = ""
        proveedorField.text = ""
        
        if (marcaCombo) marcaCombo.currentIndex = -1
        if (unidadCombo) unidadCombo.currentIndex = 0
    }
    
    function showNotification(message) {
        successMessage = message
        showSuccessMessage = true
        successTimer.restart()
    }
    
    function abrirCrearProducto(modo = false, datos = null) {
        modoEdicion = modo
        productoData = datos
        cargarMarcasDisponibles()
        limpiarFormulario()
        
        if (modoEdicion && productoData) {
            Qt.callLater(cargarDatosProducto)
        }
    }
    
    function cargarDatosProducto() {
        if (!productoData) return
        
        // Cargar solo datos básicos del producto en modo edición
        inputProductCode = productoData.codigo || ""
        inputProductName = productoData.nombre || ""
        inputProductDetails = productoData.detalles || ""
        inputPurchasePrice = productoData.precio_compra || 0
        inputSalePrice = productoData.precio_venta || 0
        
        codigoField.text = inputProductCode
        nombreField.text = inputProductName
        detallesField.text = inputProductDetails
        precioCompraField.text = inputPurchasePrice.toString()
        precioVentaField.text = inputSalePrice.toString()
        
        calcularMargen()
        
        // En modo edición, no cargar datos de lote
        // (el usuario debe ir a "Gestión de Lotes" para eso)
    }

    function obtenerFechaSugerida() {
        // Sugerir fecha 1 año en el futuro
        var fecha = new Date()
        fecha.setFullYear(fecha.getFullYear() + 1)
        return fecha.toISOString().split('T')[0] // Formato YYYY-MM-DD
    }

    // Manejo de teclas
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            event.accepted = true
            cancelarCreacion()
            volverALista()
        }
    }

    // INTERFAZ PRINCIPAL
    Rectangle {
        anchors.fill: parent
        color: grayLight
        focus: true
        
        // Header
        Rectangle {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: headerHeight
            color: white
            
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: borderColor
            }
            
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: baseSpacing
                anchors.rightMargin: baseSpacing
                spacing: baseSpacing
                
                // Botón volver
                Button {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    
                    background: Rectangle {
                        color: parent.pressed ? "#E5E7EB" : "#F9FAFB"
                        border.color: borderColor
                        border.width: 1
                        radius: 8
                    }
                    
                    contentItem: Text {
                        text: "←"
                        color: primaryBlue
                        font.pixelSize: 18
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        cancelarCreacion()
                        volverALista()
                    }
                }
                
                // Título
                RowLayout {
                    spacing: 12
                    
                    Rectangle {
                        width: 40
                        height: 40
                        color: modoEdicion ? warningAmber : primaryBlue
                        radius: 8
                        
                        Text {
                            anchors.centerIn: parent
                            text: modoEdicion ? "✏" : "+"
                            color: white
                            font.pixelSize: 16
                            font.bold: true
                        }
                    }
                    
                    Column {
                        spacing: 2
                        
                        Text {
                            text: modoEdicion ? "Editar Producto" : "Nuevo Producto + Primer Lote"
                            font.pixelSize: 20
                            font.bold: true
                            color: grayDark
                        }
                        
                        Text {
                            text: modoEdicion ? "Actualizar información del producto" : "Crear producto e inventario inicial"
                            font.pixelSize: 14
                            color: grayMedium
                        }
                    }
                }
                
                Item { Layout.fillWidth: true }
                
                // Estado del formulario
                Rectangle {
                    Layout.preferredWidth: 140
                    Layout.preferredHeight: 36
                    color: isFormValid ? "#ECFDF5" : "#FEF2F2"
                    border.color: isFormValid ? successGreen : dangerRed
                    border.width: 1
                    radius: 6
                    
                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        
                        Text {
                            text: isFormValid ? "✓" : "!"
                            color: isFormValid ? successGreen : dangerRed
                            font.pixelSize: 14
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Text {
                            text: isFormValid ? "Completo" : "Incompleto"
                            color: isFormValid ? "#065F46" : "#991B1B"
                            font.pixelSize: 13
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }
        
        // Contenido principal
        ScrollView {
            anchors.top: header.bottom
            anchors.bottom: footer.top
            anchors.left: parent.left
            anchors.right: parent.right
            clip: true
            
            ColumnLayout {
                width: parent.parent.width
                spacing: sectionSpacing
                
                // Margen superior
                Item { Layout.preferredHeight: baseSpacing }
                
                // Sección: Información básica del producto
                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: baseSpacing
                    Layout.rightMargin: baseSpacing
                    Layout.preferredHeight: basicInfoContent.height + cardPadding * 2
                    color: white
                    radius: 12
                    border.color: borderColor
                    border.width: 1
                    
                    ColumnLayout {
                        id: basicInfoContent
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: cardPadding
                        spacing: 16
                        
                        Row {
                            spacing: 8
                            
                            Rectangle {
                                width: 24
                                height: 24
                                color: primaryBlue
                                radius: 4
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "1"
                                    color: white
                                    font.bold: true
                                    font.pixelSize: 12
                                }
                            }
                            
                            Text {
                                text: "Información Básica del Producto"
                                font.pixelSize: 16
                                font.bold: true
                                color: grayDark
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        
                        // Fila 1: Código y Nombre
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16
                            
                            // Código
                            ColumnLayout {
                                Layout.preferredWidth: 200
                                spacing: 6
                                
                                Text {
                                    text: "Código *"
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: grayDark
                                }
                                
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: inputHeight
                                    color: white
                                    border.color: codigoField.activeFocus ? primaryBlue : borderColor
                                    border.width: 1
                                    radius: 8
                                    
                                    TextEdit {
                                        id: codigoField
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        verticalAlignment: TextEdit.AlignVCenter
                                        selectByMouse: true
                                        font.pixelSize: 14
                                        color: grayDark
                                        
                                        onTextChanged: inputProductCode = text
                                        
                                        Text {
                                            text: "PAR001"
                                            color: grayMedium
                                            visible: !parent.text
                                            font: parent.font
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                }
                            }
                            
                            // Nombre
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                
                                Text {
                                    text: "Nombre del Producto *"
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: grayDark
                                }
                                
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: inputHeight
                                    color: white
                                    border.color: nombreField.activeFocus ? primaryBlue : borderColor
                                    border.width: 1
                                    radius: 8
                                    
                                    TextEdit {
                                        id: nombreField
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        verticalAlignment: TextEdit.AlignVCenter
                                        selectByMouse: true
                                        font.pixelSize: 14
                                        color: grayDark
                                        
                                        onTextChanged: inputProductName = text
                                        
                                        Text {
                                            text: "Paracetamol 500mg"
                                            color: grayMedium
                                            visible: !parent.text
                                            font: parent.font
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Fila 2: Marca y Unidad
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16
                            
                            // Marca
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                
                                Text {
                                    text: "Marca *"
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: grayDark
                                }
                                
                                ComboBox {
                                    id: marcaCombo
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: inputHeight
                                    model: marcasModel
                                    textRole: "Nombre"
                                    valueRole: "id"
                                    font.pixelSize: 14
                                    
                                    displayText: {
                                        if (!marcasCargadas) return "Cargando marcas..."
                                        if (currentIndex === -1) return "Seleccionar marca"
                                        return currentText
                                    }
                                    
                                    enabled: marcasCargadas && marcasModel.length > 0
                                    
                                    background: Rectangle {
                                        color: parent.enabled ? white : "#F9FAFB"
                                        border.color: parent.activeFocus ? primaryBlue : borderColor
                                        border.width: 1
                                        radius: 8
                                    }
                                }
                            }
                            
                            // Unidad
                            ColumnLayout {
                                Layout.preferredWidth: 160
                                spacing: 6
                                
                                Text {
                                    text: "Unidad de Medida"
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: grayDark
                                }
                                
                                ComboBox {
                                    id: unidadCombo
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: inputHeight
                                    model: ["Tabletas", "Cápsulas", "ml", "mg", "g", "Unidades", "Sobres", "Frascos", "Ampollas", "Jeringas"]
                                    font.pixelSize: 14
                                    
                                    background: Rectangle {
                                        color: white
                                        border.color: parent.activeFocus ? primaryBlue : borderColor
                                        border.width: 1
                                        radius: 8
                                    }
                                    
                                    onCurrentTextChanged: inputMeasureUnit = currentText
                                    
                                    Component.onCompleted: {
                                        currentIndex = 0
                                        inputMeasureUnit = currentText
                                    }
                                }
                            }
                        }
                        
                        // Descripción
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            
                            Text {
                                text: "Descripción (Opcional)"
                                font.pixelSize: 14
                                font.bold: true
                                color: grayDark
                            }
                            
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 80
                                color: white
                                border.color: detallesField.activeFocus ? primaryBlue : borderColor
                                border.width: 1
                                radius: 8
                                
                                Flickable {
                                    id: flick
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    contentWidth: width
                                    contentHeight: detallesField.implicitHeight
                                    clip: true
                                    
                                    function ensureVisible(r) {
                                        if (contentY >= r.y)
                                            contentY = r.y;
                                        else if (contentY+height <= r.y+r.height)
                                            contentY = r.y+r.height-height;
                                    }
                                    
                                    TextEdit {
                                        id: detallesField
                                        width: parent.width
                                        height: Math.max(implicitHeight, 64)
                                        wrapMode: TextEdit.Wrap
                                        selectByMouse: true
                                        font.pixelSize: 14
                                        color: grayDark
                                        
                                        onCursorRectangleChanged: flick.ensureVisible(cursorRectangle)
                                        onTextChanged: inputProductDetails = text
                                        
                                        Text {
                                            text: "Descripción detallada del medicamento..."
                                            color: grayMedium
                                            visible: !parent.text
                                            font: parent.font
                                        }
                                    }
                                    
                                    ScrollBar.vertical: ScrollBar {
                                        policy: ScrollBar.AsNeeded
                                        width: 8
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Sección: Precios
                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: baseSpacing
                    Layout.rightMargin: baseSpacing
                    Layout.preferredHeight: pricesContent.height + cardPadding * 2
                    color: white
                    radius: 12
                    border.color: borderColor
                    border.width: 1
                    
                    ColumnLayout {
                        id: pricesContent
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: cardPadding
                        spacing: 16
                        
                        Row {
                            spacing: 8
                            
                            Rectangle {
                                width: 24
                                height: 24
                                color: successGreen
                                radius: 4
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "2"
                                    color: white
                                    font.bold: true
                                    font.pixelSize: 12
                                }
                            }
                            
                            Text {
                                text: "Precios y Margen"
                                font.pixelSize: 16
                                font.bold: true
                                color: grayDark
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 20
                            
                            // Precio de Compra
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                
                                Text {
                                    text: "Precio de Compra (Bs) *"
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: grayDark
                                }
                                
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: inputHeight
                                    color: white
                                    border.color: precioCompraField.activeFocus ? successGreen : borderColor
                                    border.width: 1
                                    radius: 8
                                    
                                    TextInput {
                                        id: precioCompraField
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        verticalAlignment: TextInput.AlignVCenter
                                        selectByMouse: true
                                        font.pixelSize: 14
                                        color: grayDark
                                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                                        
                                        onTextChanged: {
                                            var cleanText = text.replace(/[^0-9.]/g, '');
                                            if (cleanText !== text) {
                                                text = cleanText;
                                            }
                                            
                                            inputPurchasePrice = text.length > 0 ? (parseFloat(text) || 0.0) : 0.0;
                                            calcularMargen();
                                        }
                                        
                                        Text {
                                            text: "0.00"
                                            color: grayMedium
                                            visible: !parent.text
                                            font: parent.font
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                }
                            }
                            
                            // Precio de Venta
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                
                                Text {
                                    text: "Precio de Venta (Bs) *"
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: grayDark
                                }
                                
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: inputHeight
                                    color: white
                                    border.color: precioVentaField.activeFocus ? primaryBlue : borderColor
                                    border.width: 1
                                    radius: 8
                                    
                                    TextInput {
                                        id: precioVentaField
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        verticalAlignment: TextInput.AlignVCenter
                                        selectByMouse: true
                                        font.pixelSize: 14
                                        color: grayDark
                                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                                        
                                        onTextChanged: {
                                            var cleanText = text.replace(/[^0-9.]/g, '');
                                            if (cleanText !== text) {
                                                text = cleanText;
                                            }
                                            
                                            inputSalePrice = text.length > 0 ? (parseFloat(text) || 0.0) : 0.0;
                                            calcularMargen();
                                        }
                                        
                                        Text {
                                            text: "0.00"
                                            color: grayMedium
                                            visible: !parent.text
                                            font: parent.font
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                }
                            }
                            
                            // Margen
                            ColumnLayout {
                                Layout.preferredWidth: 120
                                spacing: 6
                                
                                Text {
                                    text: "Margen"
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: grayDark
                                }
                                
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: inputHeight
                                    color: calculatedMargin >= 0 ? "#ECFDF5" : "#FEF2F2"
                                    border.color: calculatedMargin >= 0 ? successGreen : dangerRed
                                    border.width: 1
                                    radius: 8
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: calculatedMargin.toFixed(1) + "%"
                                        color: calculatedMargin >= 0 ? "#065F46" : "#991B1B"
                                        font.pixelSize: 14
                                        font.bold: true
                                    }
                                }
                            }
                        }
                    }
                }

                // Sección: Primer Lote (nueva y más importante)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: baseSpacing
                    Layout.rightMargin: baseSpacing
                    Layout.preferredHeight: loteContent.height + cardPadding * 2
                    color: white
                    radius: 12
                    border.color: warningAmber
                    border.width: 2
                    visible: !modoEdicion  // Solo en creación
                    
                    ColumnLayout {
                        id: loteContent
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: cardPadding
                        spacing: 16
                        
                        Row {
                            spacing: 8
                            
                            Rectangle {
                                width: 24
                                height: 24
                                color: warningAmber
                                radius: 4
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "3"
                                    color: white
                                    font.bold: true
                                    font.pixelSize: 12
                                }
                            }
                            
                            Column {
                                spacing: 2
                                anchors.verticalCenter: parent.verticalCenter
                                
                                Text {
                                    text: "Primer Lote de Inventario *"
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: grayDark
                                }
                                
                                Text {
                                    text: "Información del stock inicial que estás registrando"
                                    font.pixelSize: 12
                                    color: grayMedium
                                    font.italic: true
                                }
                            }
                        }
                        
                        // Fila 1: Fecha de vencimiento
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            
                            Text {
                                text: "Fecha de Vencimiento *"
                                font.pixelSize: 14
                                font.bold: true
                                color: grayDark
                            }
                            
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12
                                
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: inputHeight
                                    color: white
                                    border.color: fechaVencimientoField.activeFocus ? warningAmber : borderColor
                                    border.width: 1
                                    radius: 8
                                    
                                    TextInput {
                                        id: fechaVencimientoField
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        verticalAlignment: TextInput.AlignVCenter
                                        selectByMouse: true
                                        font.pixelSize: 14
                                        color: grayDark
                                        
                                        onTextChanged: inputExpirationDate = text
                                        
                                        Text {
                                            text: "YYYY-MM-DD o DD/MM/YYYY"
                                            color: grayMedium
                                            visible: !parent.text
                                            font: parent.font
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                }
                                
                                Button {
                                    Layout.preferredWidth: 140
                                    Layout.preferredHeight: inputHeight - 6
                                    text: "Sugerir (+1 año)"
                                    
                                    background: Rectangle {
                                        color: parent.pressed ? "#FEF3C7" : "#FFFBEB"
                                        border.color: warningAmber
                                        border.width: 1
                                        radius: 6
                                    }
                                    
                                    contentItem: Text {
                                        text: parent.text
                                        color: "#92400E"
                                        font.pixelSize: 12
                                        font.bold: true
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    
                                    onClicked: {
                                        var fechaSugerida = obtenerFechaSugerida()
                                        fechaVencimientoField.text = fechaSugerida
                                        inputExpirationDate = fechaSugerida
                                    }
                                }
                            }
                        }
                        
                        // Fila 2: Stock inicial
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16
                            
                            // Stock en Cajas
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                
                                Text {
                                    text: "Stock en Cajas *"
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: grayDark
                                }
                                
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: inputHeight
                                    color: white
                                    border.color: stockCajaField.activeFocus ? warningAmber : borderColor
                                    border.width: 1
                                    radius: 8
                                    
                                    TextInput {
                                        id: stockCajaField
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        verticalAlignment: TextInput.AlignVCenter
                                        selectByMouse: true
                                        font.pixelSize: 14
                                        color: grayDark
                                        inputMethodHints: Qt.ImhDigitsOnly
                                        horizontalAlignment: TextInput.AlignHCenter
                                        
                                        onTextChanged: {
                                            var cleanText = text.replace(/[^0-9]/g, '');
                                            if (cleanText !== text) {
                                                text = cleanText;
                                            }
                                            
                                            inputStockBox = text.length > 0 ? (parseInt(text) || 0) : 0;
                                        }
                                        
                                        Text {
                                            text: "0"
                                            color: grayMedium
                                            visible: !parent.text
                                            font: parent.font
                                            verticalAlignment: Text.AlignVCenter
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }
                                }
                            }
                            
                            // Stock Unitario
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                
                                Text {
                                    text: "Stock Unitario *"
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: grayDark
                                }
                                
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: inputHeight
                                    color: white
                                    border.color: stockUnitarioField.activeFocus ? primaryBlue : borderColor
                                    border.width: 1
                                    radius: 8
                                    
                                    TextInput {
                                        id: stockUnitarioField
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        verticalAlignment: TextInput.AlignVCenter
                                        selectByMouse: true
                                        font.pixelSize: 14
                                        color: grayDark
                                        inputMethodHints: Qt.ImhDigitsOnly
                                        horizontalAlignment: TextInput.AlignHCenter
                                        
                                        onTextChanged: {
                                            var cleanText = text.replace(/[^0-9]/g, '');
                                            if (cleanText !== text) {
                                                text = cleanText;
                                            }
                                            
                                            inputStockUnit = text.length > 0 ? (parseInt(text) || 0) : 0;
                                        }
                                        
                                        Text {
                                            text: "0"
                                            color: grayMedium
                                            visible: !parent.text
                                            font: parent.font
                                            verticalAlignment: Text.AlignVCenter
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }
                                }
                            }
                            
                            // Total
                            ColumnLayout {
                                Layout.preferredWidth: 100
                                spacing: 6
                                
                                Text {
                                    text: "Total"
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: grayDark
                                }
                                
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: inputHeight
                                    color: "#F0F9FF"
                                    border.color: primaryBlue
                                    border.width: 1
                                    radius: 8
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: (inputStockBox + inputStockUnit).toString()
                                        color: primaryBlue
                                        font.pixelSize: 16
                                        font.bold: true
                                    }
                                }
                            }
                        }
                        
                        // Fila 3: Proveedor (opcional)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            
                            Text {
                                text: "Proveedor (Opcional)"
                                font.pixelSize: 14
                                font.bold: true
                                color: grayDark
                            }
                            
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: inputHeight
                                color: white
                                border.color: proveedorField.activeFocus ? primaryBlue : borderColor
                                border.width: 1
                                radius: 8
                                
                                TextInput {
                                    id: proveedorField
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    verticalAlignment: TextInput.AlignVCenter
                                    selectByMouse: true
                                    font.pixelSize: 14
                                    color: grayDark
                                    
                                    onTextChanged: inputSupplier = text
                                    
                                    Text {
                                        text: "Nombre del proveedor..."
                                        color: grayMedium
                                        visible: !parent.text
                                        font: parent.font
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                            }
                        }
                        
                        // Nota informativa
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 50
                            color: "#FEF3C7"
                            border.color: warningAmber
                            border.width: 1
                            radius: 8
                            
                            Row {
                                anchors.centerIn: parent
                                spacing: 8
                                
                                Text {
                                    text: "ℹ"
                                    color: warningAmber
                                    font.pixelSize: 18
                                    font.bold: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                
                                Text {
                                    text: "Este será el primer lote de inventario. Luego podrás agregar más lotes con diferentes fechas."
                                    color: "#92400E"
                                    font.pixelSize: 13
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }
                
                // Margen inferior
                Item { Layout.preferredHeight: 80 }
            }
        }
        
        // Footer con botones de acción
        Rectangle {
            id: footer
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 80
            color: white
            
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: borderColor
            }
            
            RowLayout {
                anchors.centerIn: parent
                spacing: 16
                
                Button {
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: buttonHeight
                    
                    background: Rectangle {
                        color: parent.pressed ? "#F3F4F6" : white
                        border.color: borderColor
                        border.width: 1
                        radius: 8
                    }
                    
                    contentItem: Text {
                        text: "Cancelar"
                        color: grayDark
                        font.pixelSize: 14
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        limpiarFormulario()
                        cancelarCreacion()
                        volverALista()
                    }
                }
                
                Button {
                    Layout.preferredWidth: modoEdicion ? 180 : 220
                    Layout.preferredHeight: buttonHeight
                    enabled: isFormValid && marcasCargadas
                    
                    background: Rectangle {
                        color: parent.enabled ? (parent.pressed ? "#1D4ED8" : primaryBlue) : "#E5E7EB"
                        radius: 8
                    }
                    
                    contentItem: Text {
                        text: modoEdicion ? "Actualizar Producto" : "Crear Producto + Lote"
                        color: parent.parent.enabled ? white : grayMedium
                        font.pixelSize: 14
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: guardarProducto()
                }
            }
        }
        
        // Notificación de éxito
        Rectangle {
            anchors.bottom: footer.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.margins: baseSpacing
            width: Math.min(parent.width - baseSpacing * 2, 400)
            height: 50
            color: successGreen
            radius: 8
            visible: showSuccessMessage
            opacity: showSuccessMessage ? 1.0 : 0.0
            z: 100
            
            Behavior on opacity {
                NumberAnimation { duration: 300 }
            }
            
            Row {
                anchors.centerIn: parent
                spacing: 12
                
                Text {
                    text: "✓"
                    color: white
                    font.pixelSize: 16
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                Text {
                    text: successMessage
                    color: white
                    font.pixelSize: 14
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    // Inicialización
    Component.onCompleted: {
        if (inventarioModel) {
            cargarMarcasDisponibles()
        }
        
        Qt.callLater(function() {
            if (codigoField) {
                codigoField.forceActiveFocus()
            }
        })
    }
}