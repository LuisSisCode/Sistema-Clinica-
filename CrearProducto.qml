import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: crearProductoComponent
    
    // ===============================
    // PROPIEDADES PÚBLICAS
    // ===============================
    
    property bool modoEdicion: false
    property var productoData: null
    property var marcasModel: []
    property color primaryColor: "#273746"
    property color successColor: "#27ae60"
    property color dangerColor: "#E74C3C"
    property color lightGrayColor: "#ECF0F1"
    property color textColor: "#2c3e50"
    property real baseUnit: 8
    property real fontBaseSize: 12
    
    // ===============================
    // SEÑALES
    // ===============================
    
    signal productoCreado(var producto)
    signal productoActualizado(var producto)
    signal cancelado()
    signal cerrarSolicitado()
    
    // ===============================
    // PROPIEDADES INTERNAS
    // ===============================
    
    property bool formularioValido: {
        return codigoField.text.trim() !== "" &&
               nombreField.text.trim() !== "" &&
               marcaCombo.currentIndex >= 0 &&
               parseFloat(precioCompraField.text || "0") > 0 &&
               parseFloat(precioVentaField.text || "0") > 0
    }
    
    // ===============================
    // CONFIGURACIÓN DEL COMPONENTE
    // ===============================
    
    color: "white"
    radius: baseUnit
    border.color: lightGrayColor
    border.width: 1
    
    Component.onCompleted: {
        if (modoEdicion && productoData) {
            cargarDatosProducto()
        }
    }
    
    // ===============================
    // LAYOUT PRINCIPAL
    // ===============================
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: baseUnit * 3
        spacing: baseUnit * 2
        
        // ===============================
        // HEADER
        // ===============================
        
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: baseUnit * 8
            color: primaryColor
            radius: baseUnit * 0.75
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: baseUnit * 2
                spacing: baseUnit * 1.5
                
                Rectangle {
                    width: baseUnit * 5
                    height: baseUnit * 5
                    color: "white"
                    radius: baseUnit * 2.5
                    
                    Text {
                        anchors.centerIn: parent
                        text: modoEdicion ? "✏️" : "➕"
                        font.pixelSize: fontBaseSize * 1.5
                    }
                }
                
                Column {
                    Layout.fillWidth: true
                    spacing: baseUnit * 0.5
                    
                    Text {
                        text: modoEdicion ? "Editar Producto" : "Crear Nuevo Producto"
                        color: "white"
                        font.bold: true
                        font.pixelSize: fontBaseSize * 1.6
                    }
                    
                    Text {
                        text: modoEdicion ? "Modificar información del producto" : "Agregar producto al inventario"
                        color: "#E8F4FD"
                        font.pixelSize: fontBaseSize
                    }
                }
                
                Button {
                    width: baseUnit * 5
                    height: baseUnit * 5
                    
                    background: Rectangle {
                        color: parent.pressed ? "#40FFFFFF" : "transparent"
                        radius: baseUnit * 2.5
                    }
                    
                    contentItem: Text {
                        text: "✕"
                        color: "white"
                        font.pixelSize: fontBaseSize * 1.8
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        cerrarSolicitado()
                    }
                }
            }
        }
        
        // ===============================
        // FORMULARIO
        // ===============================
        
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth
            
            ColumnLayout {
                width: parent.width
                spacing: baseUnit * 3
                
                // ===============================
                // INFORMACIÓN BÁSICA - 4 COLUMNAS
                // ===============================
                
                GroupBox {
                    Layout.fillWidth: true
                    title: "📋 Información Básica"
                    
                    background: Rectangle {
                        color: "#F8F9FA"
                        border.color: lightGrayColor
                        border.width: 1
                        radius: baseUnit * 0.75
                    }
                    
                    label: Rectangle {
                        color: primaryColor
                        width: labelText.width + baseUnit * 3
                        height: baseUnit * 4
                        radius: baseUnit * 0.5
                        x: baseUnit * 1.5
                        y: -baseUnit * 2
                        
                        Text {
                            id: labelText
                            anchors.centerIn: parent
                            text: parent.parent.title
                            color: "white"
                            font.bold: true
                            font.pixelSize: fontBaseSize
                        }
                    }
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: baseUnit * 2
                        spacing: baseUnit * 2
                        
                        // Primera fila: Código y Nombre
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: baseUnit * 3
                            rowSpacing: baseUnit * 1.5
                            
                            // Código
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: baseUnit * 0.75
                                
                                Text {
                                    text: "Código *"
                                    color: textColor
                                    font.bold: true
                                    font.pixelSize: fontBaseSize
                                }
                                
                                TextField {
                                    id: codigoField
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: baseUnit * 6
                                    placeholderText: "Ej: PARA001"
                                    font.pixelSize: fontBaseSize
                                    
                                    background: Rectangle {
                                        color: "white"
                                        border.color: parent.activeFocus ? primaryColor : lightGrayColor
                                        border.width: 2
                                        radius: baseUnit * 0.75
                                    }
                                }
                            }
                            
                            // Nombre
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: baseUnit * 0.75
                                
                                Text {
                                    text: "Nombre *"
                                    color: textColor
                                    font.bold: true
                                    font.pixelSize: fontBaseSize
                                }
                                
                                TextField {
                                    id: nombreField
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: baseUnit * 6
                                    placeholderText: "Ej: Paracetamol 500mg"
                                    font.pixelSize: fontBaseSize
                                    
                                    background: Rectangle {
                                        color: "white"
                                        border.color: parent.activeFocus ? primaryColor : lightGrayColor
                                        border.width: 2
                                        radius: baseUnit * 0.75
                                    }
                                }
                            }
                        }
                        
                        // Segunda fila: Marca
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit * 0.75
                            
                            Text {
                                text: "Marca *"
                                color: textColor
                                font.bold: true
                                font.pixelSize: fontBaseSize
                            }
                            
                            ComboBox {
                                id: marcaCombo
                                Layout.fillWidth: true
                                Layout.preferredHeight: baseUnit * 6
                                model: marcasModel
                                textRole: "nombre"
                                valueRole: "id"
                                font.pixelSize: fontBaseSize
                                
                                background: Rectangle {
                                    color: "white"
                                    border.color: parent.activeFocus ? primaryColor : lightGrayColor
                                    border.width: 2
                                    radius: baseUnit * 0.75
                                }
                            }
                        }
                        
                        // Tercera fila: Descripción
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit * 0.75
                            
                            Text {
                                text: "Descripción"
                                color: textColor
                                font.bold: true
                                font.pixelSize: fontBaseSize
                            }
                            
                            ScrollView {
                                Layout.fillWidth: true
                                Layout.preferredHeight: baseUnit * 12
                                
                                TextArea {
                                    id: descripcionField
                                    placeholderText: "Descripción del producto (opcional)"
                                    wrapMode: TextArea.Wrap
                                    font.pixelSize: fontBaseSize
                                    
                                    background: Rectangle {
                                        color: "white"
                                        border.color: parent.activeFocus ? primaryColor : lightGrayColor
                                        border.width: 2
                                        radius: baseUnit * 0.75
                                    }
                                }
                            }
                        }
                    }
                }
                
                // ===============================
                // PRECIOS - 3 COLUMNAS
                // ===============================
                
                GroupBox {
                    Layout.fillWidth: true
                    title: "💰 Precios"
                    
                    background: Rectangle {
                        color: "#F8F9FA"
                        border.color: lightGrayColor
                        border.width: 1
                        radius: baseUnit * 0.75
                    }
                    
                    label: Rectangle {
                        color: successColor
                        width: precioLabelText.width + baseUnit * 3
                        height: baseUnit * 4
                        radius: baseUnit * 0.5
                        x: baseUnit * 1.5
                        y: -baseUnit * 2
                        
                        Text {
                            id: precioLabelText
                            anchors.centerIn: parent
                            text: parent.parent.title
                            color: "white"
                            font.bold: true
                            font.pixelSize: fontBaseSize
                        }
                    }
                    
                    GridLayout {
                        anchors.fill: parent
                        anchors.margins: baseUnit * 2
                        columns: 3
                        columnSpacing: baseUnit * 3
                        rowSpacing: baseUnit * 2
                        
                        // Precio de Compra
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit * 0.75
                            
                            Text {
                                text: "Precio de Compra *"
                                color: textColor
                                font.bold: true
                                font.pixelSize: fontBaseSize
                            }
                            
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: baseUnit
                                
                                Rectangle {
                                    Layout.preferredWidth: baseUnit * 4
                                    Layout.preferredHeight: baseUnit * 6
                                    color: "#E8F5E8"
                                    border.color: successColor
                                    border.width: 2
                                    radius: baseUnit * 0.75
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "Bs"
                                        font.bold: true
                                        font.pixelSize: fontBaseSize * 1.1
                                        color: successColor
                                    }
                                }
                                
                                TextField {
                                    id: precioCompraField
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: baseUnit * 6
                                    placeholderText: "0.00"
                                    font.pixelSize: fontBaseSize
                                    validator: DoubleValidator {
                                        bottom: 0.01
                                        decimals: 2
                                        notation: DoubleValidator.StandardNotation
                                    }
                                    
                                    background: Rectangle {
                                        color: "white"
                                        border.color: parent.activeFocus ? successColor : lightGrayColor
                                        border.width: 2
                                        radius: baseUnit * 0.75
                                    }
                                    
                                    onTextChanged: {
                                        calcularMargen()
                                    }
                                }
                            }
                        }
                        
                        // Precio de Venta
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit * 0.75
                            
                            Text {
                                text: "Precio de Venta *"
                                color: textColor
                                font.bold: true
                                font.pixelSize: fontBaseSize
                            }
                            
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: baseUnit
                                
                                Rectangle {
                                    Layout.preferredWidth: baseUnit * 4
                                    Layout.preferredHeight: baseUnit * 6
                                    color: "#FFF3E0"
                                    border.color: "#f39c12"
                                    border.width: 2
                                    radius: baseUnit * 0.75
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "Bs"
                                        font.bold: true
                                        font.pixelSize: fontBaseSize * 1.1
                                        color: "#f39c12"
                                    }
                                }
                                
                                TextField {
                                    id: precioVentaField
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: baseUnit * 6
                                    placeholderText: "0.00"
                                    font.pixelSize: fontBaseSize
                                    validator: DoubleValidator {
                                        bottom: 0.01
                                        decimals: 2
                                        notation: DoubleValidator.StandardNotation
                                    }
                                    
                                    background: Rectangle {
                                        color: "white"
                                        border.color: parent.activeFocus ? "#f39c12" : lightGrayColor
                                        border.width: 2
                                        radius: baseUnit * 0.75
                                    }
                                    
                                    onTextChanged: {
                                        calcularMargen()
                                    }
                                }
                            }
                        }
                        
                        // Margen de Ganancia (calculado)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit * 0.75
                            
                            Text {
                                text: "Margen de Ganancia"
                                color: textColor
                                font.bold: true
                                font.pixelSize: fontBaseSize
                            }
                            
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: baseUnit * 6
                                color: margenColor
                                border.color: margenBorderColor
                                border.width: 2
                                radius: baseUnit * 0.75
                                
                                property color margenColor: {
                                    var margen = parseFloat(margenText.text.replace('%', ''))
                                    if (margen >= 30) return "#d4edda"
                                    if (margen >= 15) return "#fff3cd"
                                    return "#f8d7da"
                                }
                                
                                property color margenBorderColor: {
                                    var margen = parseFloat(margenText.text.replace('%', ''))
                                    if (margen >= 30) return successColor
                                    if (margen >= 15) return "#f39c12"
                                    return dangerColor
                                }
                                
                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: baseUnit
                                    
                                    Text {
                                        text: {
                                            var margen = parseFloat(margenText.text.replace('%', ''))
                                            if (margen >= 30) return "📈"
                                            if (margen >= 15) return "📊"
                                            return "📉"
                                        }
                                        font.pixelSize: fontBaseSize * 1.2
                                    }
                                    
                                    Text {
                                        id: margenText
                                        text: "0%"
                                        color: textColor
                                        font.bold: true
                                        font.pixelSize: fontBaseSize * 1.2
                                    }
                                }
                            }
                        }
                    }
                }
                
                // ===============================
                // STOCK INICIAL - 2 COLUMNAS (solo para crear)
                // ===============================
                
                GroupBox {
                    Layout.fillWidth: true
                    title: "📦 Stock Inicial"
                    visible: !modoEdicion
                    
                    background: Rectangle {
                        color: "#F8F9FA"
                        border.color: lightGrayColor
                        border.width: 1
                        radius: baseUnit * 0.75
                    }
                    
                    label: Rectangle {
                        color: "#17a2b8"
                        width: stockLabelText.width + baseUnit * 3
                        height: baseUnit * 4
                        radius: baseUnit * 0.5
                        x: baseUnit * 1.5
                        y: -baseUnit * 2
                        
                        Text {
                            id: stockLabelText
                            anchors.centerIn: parent
                            text: parent.parent.title
                            color: "white"
                            font.bold: true
                            font.pixelSize: fontBaseSize
                        }
                    }
                    
                    GridLayout {
                        anchors.fill: parent
                        anchors.margins: baseUnit * 2
                        columns: 2
                        columnSpacing: baseUnit * 4
                        rowSpacing: baseUnit * 2
                        
                        // Stock en Cajas
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit * 0.75
                            
                            Text {
                                text: "Stock en Cajas"
                                color: textColor
                                font.bold: true
                                font.pixelSize: fontBaseSize
                            }
                            
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: baseUnit
                                
                                Rectangle {
                                    Layout.preferredWidth: baseUnit * 5
                                    Layout.preferredHeight: baseUnit * 6
                                    color: "#E3F2FD"
                                    border.color: "#17a2b8"
                                    border.width: 2
                                    radius: baseUnit * 0.75
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "📦"
                                        font.pixelSize: fontBaseSize * 1.2
                                    }
                                }
                                
                                TextField {
                                    id: stockCajaField
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: baseUnit * 6
                                    placeholderText: "0"
                                    text: "0"
                                    font.pixelSize: fontBaseSize
                                    validator: IntValidator {
                                        bottom: 0
                                    }
                                    
                                    background: Rectangle {
                                        color: "white"
                                        border.color: parent.activeFocus ? "#17a2b8" : lightGrayColor
                                        border.width: 2
                                        radius: baseUnit * 0.75
                                    }
                                }
                            }
                        }
                        
                        // Stock Unitario
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit * 0.75
                            
                            Text {
                                text: "Stock Unitario"
                                color: textColor
                                font.bold: true
                                font.pixelSize: fontBaseSize
                            }
                            
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: baseUnit
                                
                                Rectangle {
                                    Layout.preferredWidth: baseUnit * 5
                                    Layout.preferredHeight: baseUnit * 6
                                    color: "#E8F5E8"
                                    border.color: successColor
                                    border.width: 2
                                    radius: baseUnit * 0.75
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "🔢"
                                        font.pixelSize: fontBaseSize * 1.2
                                    }
                                }
                                
                                TextField {
                                    id: stockUnitarioField
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: baseUnit * 6
                                    placeholderText: "0"
                                    text: "0"
                                    font.pixelSize: fontBaseSize
                                    validator: IntValidator {
                                        bottom: 0
                                    }
                                    
                                    background: Rectangle {
                                        color: "white"
                                        border.color: parent.activeFocus ? successColor : lightGrayColor
                                        border.width: 2
                                        radius: baseUnit * 0.75
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // ===============================
        // BOTONES DE ACCIÓN
        // ===============================
        
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: baseUnit * 10
            color: "#F8F9FA"
            border.color: lightGrayColor
            border.width: 1
            radius: baseUnit * 0.75
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: baseUnit * 2
                spacing: baseUnit * 2
                
                // Información de validación
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: baseUnit * 6
                    color: formularioValido ? "#d4edda" : "#f8d7da"
                    border.color: formularioValido ? successColor : dangerColor
                    border.width: 2
                    radius: baseUnit * 0.75
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: baseUnit * 1.5
                        spacing: baseUnit * 1.5
                        
                        Text {
                            text: formularioValido ? "✅" : "⚠️"
                            font.pixelSize: fontBaseSize * 1.5
                        }
                        
                        Text {
                            Layout.fillWidth: true
                            text: formularioValido ? 
                                  "Formulario completo - Listo para guardar" : 
                                  "Complete los campos obligatorios (*)"
                            color: formularioValido ? "#155724" : "#721c24"
                            font.pixelSize: fontBaseSize
                            font.bold: true
                            wrapMode: Text.WordWrap
                        }
                    }
                }
                
                // Botón Cancelar
                Button {
                    Layout.preferredWidth: baseUnit * 15
                    Layout.preferredHeight: baseUnit * 6
                    text: "Cancelar"
                    
                    background: Rectangle {
                        color: parent.pressed ? Qt.darker("#6c757d", 1.2) : "#6c757d"
                        radius: baseUnit * 0.75
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.bold: true
                        font.pixelSize: fontBaseSize
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        cancelado()
                    }
                }
                
                // Botón Guardar
                Button {
                    Layout.preferredWidth: baseUnit * 20
                    Layout.preferredHeight: baseUnit * 6
                    text: modoEdicion ? "💾 Actualizar Producto" : "✅ Crear Producto"
                    enabled: formularioValido
                    
                    background: Rectangle {
                        color: parent.enabled ? 
                              (parent.pressed ? Qt.darker(successColor, 1.2) : successColor) : 
                              "#cccccc"
                        radius: baseUnit * 0.75
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.bold: true
                        font.pixelSize: fontBaseSize
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        if (modoEdicion) {
                            actualizarProducto()
                        } else {
                            crearProducto()
                        }
                    }
                }
            }
        }
    }
    
    // ===============================
    // FUNCIONES
    // ===============================
    
    function cargarDatosProducto() {
        if (!productoData) return
        
        codigoField.text = productoData.Codigo || ""
        nombreField.text = productoData.Nombre || ""
        descripcionField.text = productoData.Descripcion || ""
        precioCompraField.text = productoData.Precio_compra || ""
        precioVentaField.text = productoData.Precio_venta || ""
        
        // Buscar la marca en el combo
        for (var i = 0; i < marcasModel.length; i++) {
            if (marcasModel[i].id === productoData.ID_Marca) {
                marcaCombo.currentIndex = i
                break
            }
        }
        
        calcularMargen()
    }
    
    function calcularMargen() {
        var precioCompra = parseFloat(precioCompraField.text || "0")
        var precioVenta = parseFloat(precioVentaField.text || "0")
        
        if (precioCompra > 0 && precioVenta > 0) {
            var margen = ((precioVenta - precioCompra) / precioCompra) * 100
            margenText.text = margen.toFixed(1) + "%"
        } else {
            margenText.text = "0%"
        }
    }
    
    function crearProducto() {
        var producto = {
            codigo: codigoField.text.trim(),
            nombre: nombreField.text.trim(),
            descripcion: descripcionField.text.trim(),
            id_marca: marcaCombo.currentValue,
            precio_compra: parseFloat(precioCompraField.text || "0"),
            precio_venta: parseFloat(precioVentaField.text || "0"),
            stock_caja: parseInt(stockCajaField.text || "0"),
            stock_unitario: parseInt(stockUnitarioField.text || "0")
        }
        
        productoCreado(producto)
    }
    
    function actualizarProducto() {
        var producto = {
            id: productoData.id,
            codigo: codigoField.text.trim(),
            nombre: nombreField.text.trim(),
            descripcion: descripcionField.text.trim(),
            id_marca: marcaCombo.currentValue,
            precio_compra: parseFloat(precioCompraField.text || "0"),
            precio_venta: parseFloat(precioVentaField.text || "0")
        }
        
        productoActualizado(producto)
    }
    
    function limpiarFormulario() {
        codigoField.text = ""
        nombreField.text = ""
        descripcionField.text = ""
        precioCompraField.text = ""
        precioVentaField.text = ""
        stockCajaField.text = "0"
        stockUnitarioField.text = "0"
        marcaCombo.currentIndex = -1
        margenText.text = "0%"
    }
}