import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15

// Dialog para crear/editar producto - CORREGIDO
Dialog {
    id: crearProductoDialog
    
    // Propiedades del Dialog
    modal: true
    dim: true
    closePolicy: Popup.NoAutoClose
    anchors.centerIn: parent
    width: Math.min(parent.width * 0.9, 900)
    height: Math.min(parent.height * 0.9,550)
    
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
    
    // Métricas del diseño - OPTIMIZADAS
    readonly property real baseSpacing: 12
    readonly property real cardPadding: 16
    readonly property real inputHeight: 40
    readonly property real buttonHeight: 45
    readonly property real headerHeight: 60
    readonly property real sectionSpacing: 12
    
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
    property string inputMarca: ""

    // Datos del formulario - PRIMER LOTE (CORREGIDO)
    property string inputExpirationDate: ""  // CORREGIDO: nombre consistente
    property bool inputNoExpiry: false  // Por defecto tiene vencimiento
    property int inputStockBox: 0
    property int inputStockUnit: 0
    property string inputSupplier: ""
    
    // Validación - CORREGIDA
    property bool isFormValid: {
        if (modoEdicion) {
            return inputProductName.length > 0 &&
                inputPurchasePrice > 0 &&
                inputSalePrice > 0 &&
                inputMarca.length > 0
        } else {
            return inputProductName.length > 0 &&
                inputPurchasePrice > 0 &&
                inputSalePrice > 0 &&
                inputMarca.length > 0 &&
                (inputNoExpiry || inputExpirationDate.length > 0) &&  // CORREGIDO
                (inputStockBox > 0 || inputStockUnit > 0)
        }
    }

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

        if (cleaned.length > 10) {
            cleaned = cleaned.substring(0, 10)
        }
        
        return cleaned
    }

    function validateExpiryDate(dateStr) {
        // Permitir vacío cuando inputNoExpiry es true
        if (inputNoExpiry || dateStr === "" || dateStr === "Sin vencimiento") return true;
        
        // Validar formato YYYY-MM-DD
        var regex = /^\d{4}-\d{2}-\d{2}$/;
        if (!regex.test(dateStr)) return false;
        
        var parts = dateStr.split('-');
        var year = parseInt(parts[0], 10);
        var month = parseInt(parts[1], 10);
        var day = parseInt(parts[2], 10);
        
        if (month < 1 || month > 12) return false;
        if (day < 1 || day > 31) return false;
        if (year < 2020 || year > 2050) return false;
        
        // Validar días por mes
        var daysInMonth = new Date(year, month, 0).getDate();
        if (day > daysInMonth) return false;
        
        return true;
    }
    
    function formatearFechaParaBD() {
        if (inputNoExpiry) {
            return null  // NULL para productos sin vencimiento
        }
        if (!inputExpirationDate || inputExpirationDate.length === 0) {
            return null  // NULL si no hay fecha especificada
        }
        
        return inputExpirationDate  // Retorna la fecha tal como está
    }

    function generarCodigoAutomatico() {
        return "PROD" + String(Date.now()).slice(-6)
    }
    
    function guardarProducto() {
        // Generar código automático si está vacío
        if (inputProductCode.trim().length === 0) {
            inputProductCode = generarCodigoAutomatico()
            codigoField.text = inputProductCode
        }
        
        if (!isFormValid) {
            showNotification("Complete todos los campos obligatorios")
            return false
        }
        
        // CORREGIDO: Validación de fecha
        if (!modoEdicion && !inputNoExpiry && !validateExpiryDate(inputExpirationDate)) {
            showNotification("Fecha de vencimiento inválida (YYYY-MM-DD)")
            return false
        }
        
        var producto = {
            codigo: inputProductCode.trim(),
            nombre: inputProductName.trim(),
            detalles: inputProductDetails.trim(),
            marca: inputMarca.trim(),
            precio_compra: inputPurchasePrice,
            precio_venta: inputSalePrice,
            unidad_medida: inputMeasureUnit,
            stock_caja: inputStockBox,
            stock_unitario: inputStockUnit,
            fecha_vencimiento: formatearFechaParaBD(),
            proveedor: inputSupplier.trim(),
            sin_vencimiento: inputNoExpiry
        }
        
        if (modoEdicion) {
            producto.id = productoData.id
            productoActualizado(producto)
            showNotification("Producto actualizado correctamente")
        } else {
            productoCreado(producto)
            var tipoVencimiento = inputNoExpiry ? " (sin vencimiento)" : ""
            showNotification("Producto y primer lote creados correctamente" + tipoVencimiento)
        }
        
        Qt.callLater(function() {
            limpiarFormulario()
            close()
        })
        
        return true
    }
    
    function limpiarFormulario() {
        inputProductCode = ""
        inputProductName = ""
        inputProductDetails = ""
        inputPurchasePrice = 0.0
        inputSalePrice = 0.0
        inputMarca = ""
        
        inputExpirationDate = ""  // CORREGIDO
        inputNoExpiry = false  // Volver al estado por defecto
        inputStockBox = 0
        inputStockUnit = 0
        inputSupplier = ""
        
        codigoField.text = ""
        nombreField.text = ""
        detallesField.text = ""
        precioCompraField.text = ""
        precioVentaField.text = ""
        marcaField.text = ""
        fechaVencimientoField.text = ""
        stockCajaField.text = ""
        stockUnitarioField.text = ""
        proveedorField.text = ""
        
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
        
        open()
    }
    
    function cargarDatosProducto() {
        if (!productoData) return
        
        inputProductCode = productoData.codigo || ""
        inputProductName = productoData.nombre || ""
        inputProductDetails = productoData.detalles || ""
        inputPurchasePrice = productoData.precio_compra || 0
        inputSalePrice = productoData.precio_venta || 0
        inputMarca = productoData.marca || ""
        
        codigoField.text = inputProductCode
        nombreField.text = inputProductName
        detallesField.text = inputProductDetails
        precioCompraField.text = inputPurchasePrice.toString()
        precioVentaField.text = inputSalePrice.toString()
        marcaField.text = inputMarca
    }

    // Header personalizado
    header: Rectangle {
        height: headerHeight
        color: white
        radius: 12
        
        // Recortar esquinas inferiores para que solo las superiores sean redondeadas
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 12
            color: white
        }
        
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
            
            RowLayout {
                spacing: 10
                
                Rectangle {
                    width: 36
                    height: 36
                    color: modoEdicion ? warningAmber : primaryBlue
                    radius: 8
                    
                    Text {
                        anchors.centerIn: parent
                        text: modoEdicion ? "✏" : "+"
                        color: white
                        font.pixelSize: 14
                        font.bold: true
                    }
                }
                
                Column {
                    spacing: 2
                    
                    Text {
                        text: modoEdicion ? "Editar Producto" : "Nuevo Producto + Primer Lote"
                        font.pixelSize: 18
                        font.bold: true
                        color: grayDark
                    }
                    
                    Text {
                        text: modoEdicion ? "Actualizar información del producto" : "Crear producto e inventario inicial"
                        font.pixelSize: 12
                        color: grayMedium
                    }
                }
            }
            
            Item { Layout.fillWidth: true }
            
            Button {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                
                background: Rectangle {
                    color: parent.pressed ? "#E5E7EB" : "#F9FAFB"
                    border.color: borderColor
                    border.width: 1
                    radius: 8
                }
                
                contentItem: Text {
                    text: "×"
                    color: grayDark
                    font.pixelSize: 18
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: {
                    cancelarCreacion()
                    close()
                }
            }
        }
    }

    // Contenido principal
    contentItem: Rectangle {
        color: grayLight
        
        ScrollView {
            anchors.fill: parent
            anchors.margins: baseSpacing
            clip: true
            
            Rectangle {
                width: parent.width
                height: allContent.height + cardPadding * 2
                color: white
                radius: 8
                border.color: borderColor
                border.width: 1
                
                ColumnLayout {
                    id: allContent
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: cardPadding
                    spacing: 12
                    
                    // Fila 1: Código, Nombre del Producto, Marca
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        
                        // Código (ya no obligatorio)
                        ColumnLayout {
                            Layout.preferredWidth: 120
                            spacing: 4
                            
                            Text {
                                text: "Código (Opcional)"
                                font.pixelSize: 12
                                font.bold: true
                                color: grayDark
                            }
                            
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: inputHeight
                                color: white
                                border.color: codigoField.activeFocus ? primaryBlue : borderColor
                                border.width: 1
                                radius: 6
                                
                                TextEdit {
                                    id: codigoField
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    verticalAlignment: TextEdit.AlignVCenter
                                    selectByMouse: true
                                    font.pixelSize: 12
                                    color: grayDark
                                    
                                    onTextChanged: inputProductCode = text
                                    
                                    Text {
                                        text: "Auto-generado"
                                        color: grayMedium
                                        visible: !parent.text
                                        font: parent.font
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                            }
                        }
                        
                        // Nombre del Producto
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            
                            Text {
                                text: "Nombre del Producto *"
                                font.pixelSize: 12
                                font.bold: true
                                color: grayDark
                            }
                            
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: inputHeight
                                color: white
                                border.color: nombreField.activeFocus ? primaryBlue : borderColor
                                border.width: 1
                                radius: 6
                                
                                TextEdit {
                                    id: nombreField
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    verticalAlignment: TextEdit.AlignVCenter
                                    selectByMouse: true
                                    font.pixelSize: 12
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
                        
                        // Marca
                        ColumnLayout {
                            Layout.preferredWidth: 160
                            spacing: 4
                            
                            Text {
                                text: "Marca *"
                                font.pixelSize: 12
                                font.bold: true
                                color: grayDark
                            }
                            
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: inputHeight
                                color: white
                                border.color: marcaField.activeFocus ? primaryBlue : borderColor
                                border.width: 1
                                radius: 6
                                
                                TextEdit {
                                    id: marcaField
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    verticalAlignment: TextEdit.AlignVCenter
                                    selectByMouse: true
                                    font.pixelSize: 12
                                    color: grayDark
                                    
                                    onTextChanged: inputMarca = text
                                    
                                    Text {
                                        text: "GSK, Roche..."
                                        color: grayMedium
                                        visible: !parent.text
                                        font: parent.font
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                            }
                        }
                    }
                    
                    // Fila 2: Unidad, P. Compra, P. Venta, Fecha Vencimiento con Checkbox CORREGIDO
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        
                        // Unidad
                        ColumnLayout {
                            Layout.preferredWidth: 110
                            spacing: 4
                            
                            Text {
                                text: "Unidad"
                                font.pixelSize: 12
                                font.bold: true
                                color: grayDark
                            }
                            
                            ComboBox {
                                id: unidadCombo
                                Layout.fillWidth: true
                                Layout.preferredHeight: inputHeight
                                model: ["Tabletas", "Cápsulas", "ml", "mg", "g", "Unidades", "Sobres", "Frascos", "Ampollas", "Jeringas"]
                                font.pixelSize: 11
                                
                                background: Rectangle {
                                    color: white
                                    border.color: parent.activeFocus ? primaryBlue : borderColor
                                    border.width: 1
                                    radius: 6
                                }
                                
                                onCurrentTextChanged: inputMeasureUnit = currentText
                                
                                Component.onCompleted: {
                                    currentIndex = 0
                                    inputMeasureUnit = currentText
                                }
                            }
                        }
                        
                        // Precio Compra
                        ColumnLayout {
                            Layout.preferredWidth: 100
                            spacing: 4
                            
                            Text {
                                text: "P. Compra *"
                                font.pixelSize: 12
                                font.bold: true
                                color: grayDark
                            }
                            
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: inputHeight
                                color: white
                                border.color: precioCompraField.activeFocus ? successGreen : borderColor
                                border.width: 1
                                radius: 6
                                
                                TextInput {
                                    id: precioCompraField
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    verticalAlignment: TextInput.AlignVCenter
                                    selectByMouse: true
                                    font.pixelSize: 12
                                    color: grayDark
                                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                                    horizontalAlignment: TextInput.AlignHCenter
                                    
                                    onTextChanged: {
                                        var cleanText = text.replace(/[^0-9.]/g, '');
                                        if (cleanText !== text) {
                                            text = cleanText;
                                        }
                                        
                                        inputPurchasePrice = text.length > 0 ? (parseFloat(text) || 0.0) : 0.0;
                                    }
                                    
                                    Text {
                                        text: "0.00"
                                        color: grayMedium
                                        visible: !parent.text
                                        font: parent.font
                                        verticalAlignment: Text.AlignVCenter
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }
                            }
                        }
                        
                        // Precio Venta
                        ColumnLayout {
                            Layout.preferredWidth: 100
                            spacing: 4
                            
                            Text {
                                text: "P. Venta *"
                                font.pixelSize: 12
                                font.bold: true
                                color: grayDark
                            }
                            
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: inputHeight
                                color: white
                                border.color: precioVentaField.activeFocus ? primaryBlue : borderColor
                                border.width: 1
                                radius: 6
                                
                                TextInput {
                                    id: precioVentaField
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    verticalAlignment: TextInput.AlignVCenter
                                    selectByMouse: true
                                    font.pixelSize: 12
                                    color: grayDark
                                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                                    horizontalAlignment: TextInput.AlignHCenter
                                    
                                    onTextChanged: {
                                        var cleanText = text.replace(/[^0-9.]/g, '');
                                        if (cleanText !== text) {
                                            text = cleanText;
                                        }
                                        
                                        inputSalePrice = text.length > 0 ? (parseFloat(text) || 0.0) : 0.0;
                                    }
                                    
                                    Text {
                                        text: "0.00"
                                        color: grayMedium
                                        visible: !parent.text
                                        font: parent.font
                                        verticalAlignment: Text.AlignVCenter
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }
                            }
                        }
                        
                        // Fecha Vencimiento con checkbox CORREGIDO
                        ColumnLayout {
                            Layout.preferredWidth: 200
                            spacing: 4
                            visible: !modoEdicion
                            
                            Text {
                                text: "Fecha Venc."
                                font.pixelSize: 12
                                font.bold: true
                                color: grayDark
                            }
                            
                            RowLayout {
                                spacing: 4
                                
                                Rectangle {
                                    Layout.preferredWidth: 120
                                    Layout.preferredHeight: inputHeight
                                    color: inputNoExpiry ? "#F5F5F5" : white  // Deshabilitado cuando es sin vencimiento
                                    border.color: fechaVencimientoField.activeFocus ? warningAmber : borderColor
                                    border.width: 1
                                    radius: 6
                                    
                                    TextInput {
                                        id: fechaVencimientoField
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        verticalAlignment: TextInput.AlignVCenter
                                        selectByMouse: true
                                        font.pixelSize: 12
                                        color: grayDark
                                        inputMethodHints: Qt.ImhDigitsOnly
                                        maximumLength: 10
                                        enabled: !inputNoExpiry  // Deshabilitado cuando es sin vencimiento
                                        
                                        onTextChanged: {
                                            if (!inputNoExpiry) {
                                                var formatted = autoFormatDate(text)
                                                if (formatted !== text) {
                                                    text = formatted
                                                }
                                                inputExpirationDate = formatted  // CORREGIDO
                                            }
                                        }
                                        
                                        Text {
                                            text:"YYYY-MM-DD"
                                            color: grayMedium
                                            visible: !parent.text
                                            font: parent.font
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                }
                                
                                // CHECKBOX CORREGIDO - Por defecto marcado (tiene vencimiento)
                                CheckBox {
                                    Layout.preferredWidth: 20
                                    Layout.preferredHeight: inputHeight
                                    checked: !inputNoExpiry  // CORREGIDO: checked cuando tiene vencimiento
                                    
                                    indicator: Rectangle {
                                        width: 16
                                        height: 16
                                        anchors.centerIn: parent
                                        radius: 2
                                        border.color: borderColor
                                        border.width: 1
                                        color: parent.checked ? primaryBlue : white
                                        
                                        Text {
                                            anchors.centerIn: parent
                                            text: "✓"
                                            color: white
                                            font.pixelSize: 10
                                            visible: parent.parent.checked
                                        }
                                    }
                                    
                                    contentItem: Item {}
                                    
                                    onCheckedChanged: {
                                        inputNoExpiry = !checked  // CORREGIDO: sin vencimiento cuando NO está checked
                                        if (!checked) {
                                            // Si NO está marcado (sin vencimiento), limpiar fecha
                                            inputExpirationDate = ""
                                            fechaVencimientoField.text = ""
                                        }
                                    }
                                }
                                
                                Text {
                                    text: "Con vencimiento"  // CORREGIDO: texto más claro
                                    font.pixelSize: 10
                                    color: grayMedium
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }
                        }
                        
                        Item { Layout.fillWidth: true }
                    }
                    
                    // Fila 3: Stock Caja, Stock Unitario, Total, Proveedor
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        visible: !modoEdicion
                        
                        // Stock Caja
                        ColumnLayout {
                            Layout.preferredWidth: 90
                            spacing: 4
                            
                            Text {
                                text: "Stock Caja *"
                                font.pixelSize: 12
                                font.bold: true
                                color: grayDark
                            }
                            
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: inputHeight
                                color: white
                                border.color: stockCajaField.activeFocus ? warningAmber : borderColor
                                border.width: 1
                                radius: 6
                                
                                TextInput {
                                    id: stockCajaField
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    verticalAlignment: TextInput.AlignVCenter
                                    selectByMouse: true
                                    font.pixelSize: 12
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
                            Layout.preferredWidth: 100
                            spacing: 4
                            
                            Text {
                                text: "Stock Unitario *"
                                font.pixelSize: 12
                                font.bold: true
                                color: grayDark
                            }
                            
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: inputHeight
                                color: white
                                border.color: stockUnitarioField.activeFocus ? primaryBlue : borderColor
                                border.width: 1
                                radius: 6
                                
                                TextInput {
                                    id: stockUnitarioField
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    verticalAlignment: TextInput.AlignVCenter
                                    selectByMouse: true
                                    font.pixelSize: 12
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
                            Layout.preferredWidth: 70
                            spacing: 4
                            
                            Text {
                                text: "Stock Total"
                                font.pixelSize: 12
                                font.bold: true
                                color: grayDark
                            }
                            
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: inputHeight
                                color: "#F0F9FF"
                                border.color: primaryBlue
                                border.width: 1
                                radius: 6
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: (inputStockBox * inputStockUnit).toString()  // CORREGIDO: suma no multiplicación
                                    color: primaryBlue
                                    font.pixelSize: 14
                                    font.bold: true
                                }
                            }
                        }
                        
                        // Proveedor
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            
                            Text {
                                text: "Proveedor (Opcional)"
                                font.pixelSize: 12
                                font.bold: true
                                color: grayDark
                            }
                            
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: inputHeight
                                color: white
                                border.color: proveedorField.activeFocus ? primaryBlue : borderColor
                                border.width: 1
                                radius: 6
                                
                                TextInput {
                                    id: proveedorField
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    verticalAlignment: TextInput.AlignVCenter
                                    selectByMouse: true
                                    font.pixelSize: 12
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
                    }
                    
                    // Fila 4: Descripción (fila completa)
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        
                        Text {
                            text: "Descripción (Opcional)"
                            font.pixelSize: 12
                            font.bold: true
                            color: grayDark
                        }
                        
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 60
                            color: white
                            border.color: detallesField.activeFocus ? primaryBlue : borderColor
                            border.width: 1
                            radius: 6
                            
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
                                    height: Math.max(implicitHeight, 44)
                                    wrapMode: TextEdit.Wrap
                                    selectByMouse: true
                                    font.pixelSize: 12
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
                            }
                        }
                    }
                    
                    // Botones de acción (debajo de descripción)
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 20
                        Layout.alignment: Qt.AlignCenter
                        spacing: 12
                        
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
                                close()
                            }
                        }
                        
                        Button {
                            Layout.preferredWidth: modoEdicion ? 180 : 200
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
            }
        }
    }

    // Notificación
    Rectangle {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 100
        width: Math.min(parent.width - baseSpacing * 2, 350)
        height: 40
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
            spacing: 8
            
            Text {
                text: "✓"
                color: white
                font.pixelSize: 14
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
            
            Text {
                text: successMessage
                color: white
                font.pixelSize: 12
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    Component.onCompleted: {
        if (inventarioModel) {
            cargarMarcasDisponibles()
        }
    }

    onOpened: {
        Qt.callLater(function() {
            if (nombreField) {  // Cambio: ahora el foco va al nombre ya que el código es opcional
                nombreField.forceActiveFocus()
            }
        })
    }
}