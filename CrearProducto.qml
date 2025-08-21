import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15

Dialog {
    id: crearProductoDialog
    
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
    // CONFIGURACIÓN DEL DIÁLOGO
    // ===============================
    
    title: modoEdicion ? "Editar Producto" : "Crear Nuevo Producto"
    modal: true
    closePolicy: Popup.CloseOnEscape
    
    // Tamaño y posición
    width: Math.min(800, parent.width * 0.9)
    height: Math.min(700, parent.height * 0.9)
    anchors.centerIn: parent
    
    // Manejar cierre con Escape
    Keys.onEscapePressed: {
        cerrarSolicitado()
        close()
    }
    
    // Fondo personalizado
    background: Rectangle {
        color: "white"
        radius: baseUnit
        border.color: lightGrayColor
        border.width: 2
        
        // Sombra
        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            z: -1
            color: "transparent"
            border.color: "#00000020"
            border.width: 4
            radius: baseUnit + 2
        }
    }
    
    Component.onCompleted: {
        console.log("🆕 CrearProducto inicializado")
        console.log("🏷️ Marcas disponibles:", marcasModel.length)
        
        if (marcasModel.length === 0) {
            console.log("⚠️ PROBLEMA: marcasModel está vacío")
        }
        
        if (modoEdicion && productoData) {
            cargarDatosProducto()
        }
        open()
    }
    
    onClosed: {
        limpiarFormulario()
    }
    
    // ===============================
    // ENCABEZADO PERSONALIZADO
    // ===============================
    
    header: Rectangle {
        height: baseUnit * 7
        color: primaryColor
        radius: baseUnit
        
        // Solo redondear esquinas superiores
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: baseUnit
            color: primaryColor
        }
        
        RowLayout {
            anchors.fill: parent
            anchors.margins: baseUnit * 1.5
            spacing: baseUnit
            
            // Ícono a la izquierda
            Rectangle {
                Layout.preferredWidth: baseUnit * 4
                Layout.preferredHeight: baseUnit * 4
                Layout.alignment: Qt.AlignVCenter
                color: "white"
                radius: baseUnit * 2
                
                Text {
                    anchors.centerIn: parent
                    text: modoEdicion ? "✏️" : "➕"
                    font.pixelSize: fontBaseSize * 1.2
                }
            }
            
            // Textos en el centro
            Column {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: baseUnit * 0.25
                
                Text {
                    text: modoEdicion ? "Editar Producto" : "Crear Nuevo Producto"
                    color: "white"
                    font.bold: true
                    font.pixelSize: fontBaseSize * 1.4
                }
                
                Text {
                    text: modoEdicion ? "Modificar información del producto" : "Agregar producto al inventario"
                    color: "#E8F4FD"
                    font.pixelSize: fontBaseSize * 0.9
                }
            }
            
            // Botón cerrar a la derecha
            Button {
                Layout.preferredWidth: baseUnit * 4
                Layout.preferredHeight: baseUnit * 4
                Layout.alignment: Qt.AlignVCenter
                
                background: Rectangle {
                    color: parent.pressed ? "#40FFFFFF" : "transparent"
                    radius: baseUnit * 2
                }
                
                contentItem: Text {
                    text: "✕"
                    color: "white"
                    font.pixelSize: fontBaseSize * 1.5
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: {
                    cerrarSolicitado()
                    crearProductoDialog.close()
                }
            }
        }
    }
    
    // ===============================
    // CONTENIDO PRINCIPAL
    // ===============================
    
    contentItem: ScrollView {
        clip: true
        contentWidth: availableWidth
        
        // ColumnLayout principal para apilar los grupos de campos
        ColumnLayout {
            width: parent.width
            spacing: baseUnit * 1.5
            
            // ===============================
            // GRUPO: INFORMACIÓN BÁSICA
            // ===============================

            GroupBox {
                Layout.fillWidth: true
                Layout.margins: baseUnit
                padding: baseUnit
                
                background: Rectangle {
                    color: "#FAFBFC"
                    border.color: "#E1E8ED"
                    border.width: 1
                    radius: baseUnit * 0.5
                }
                
                ColumnLayout {
                    anchors.fill: parent
                    spacing: baseUnit
                    
                    // Título dentro del contenedor
                    RowLayout {
                        Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                        
                        Rectangle {
                            width: basicInfoLabel.width + baseUnit
                            height: baseUnit * 2.5
                            color: primaryColor
                            radius: baseUnit * 0.25
                            
                            Text {
                                id: basicInfoLabel
                                anchors.centerIn: parent
                                text: "📋 Información Básica"
                                color: "white"
                                font.bold: true
                                font.pixelSize: fontBaseSize * 0.8
                            }
                        }
                    }
                    
                    // Fila 1: Código, Nombre y Marca en la misma línea
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: baseUnit
                        
                        // Campo Código
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.preferredWidth: parent.width * 0.3
                            spacing: baseUnit * 0.5
                            
                            Text {
                                text: "Código *"
                                color: textColor
                                font.bold: true
                                font.pixelSize: fontBaseSize
                            }
                            
                            TextField {
                                id: codigoField
                                Layout.fillWidth: true
                                Layout.preferredHeight: baseUnit * 3.5
                                placeholderText: "Ej: PARA001"
                                font.pixelSize: fontBaseSize
                                leftPadding: baseUnit
                                rightPadding: baseUnit
                                
                                background: Rectangle {
                                    color: "white"
                                    border.color: parent.activeFocus ? primaryColor : "#D1D9E0"
                                    border.width: parent.activeFocus ? 2 : 1
                                    radius: baseUnit * 0.5
                                }
                            }
                        }
                        
                        // Campo Nombre
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.preferredWidth: parent.width * 0.4
                            spacing: baseUnit * 0.5
                            
                            Text {
                                text: "Nombre *"
                                color: textColor
                                font.bold: true
                                font.pixelSize: fontBaseSize
                            }
                            
                            TextField {
                                id: nombreField
                                Layout.fillWidth: true
                                Layout.preferredHeight: baseUnit * 3.5
                                placeholderText: "Ej: Paracetamol 500mg"
                                font.pixelSize: fontBaseSize
                                leftPadding: baseUnit
                                rightPadding: baseUnit
                                
                                background: Rectangle {
                                    color: "white"
                                    border.color: parent.activeFocus ? primaryColor : "#D1D9E0"
                                    border.width: parent.activeFocus ? 2 : 1
                                    radius: baseUnit * 0.5
                                }
                            }
                        }
                        
                        // Campo Marca
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.preferredWidth: parent.width * 0.3
                            spacing: baseUnit * 0.5
                            
                            Text {
                                text: "Marca *"
                                color: textColor
                                font.bold: true
                                font.pixelSize: fontBaseSize
                            }
                            
                            ComboBox {
                                id: marcaCombo
                                Layout.fillWidth: true
                                Layout.preferredHeight: baseUnit * 3.5
                                model: marcasModel
                                textRole: "Nombre"
                                valueRole: "id"
                                font.pixelSize: fontBaseSize
                                leftPadding: baseUnit
                                rightPadding: baseUnit
                                
                                background: Rectangle {
                                    color: "white"
                                    border.color: parent.activeFocus ? primaryColor : "#D1D9E0"
                                    border.width: parent.activeFocus ? 2 : 1
                                    radius: baseUnit * 0.5
                                }
                                onCurrentIndexChanged: {
                                    if (currentIndex >= 0) {
                                        console.log("Marca seleccionada:", currentText)
                                    } else {
                                        console.log("No se ha seleccionado ninguna marca")
                                    }
                                }  
                            }
                        }
                    }
                    
                    // Fila 2: Descripción (ancho completo)
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: baseUnit * 0.5
                        
                        Text {
                            text: "Descripción"
                            color: textColor
                            font.bold: true
                            font.pixelSize: fontBaseSize
                        }
                        
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.preferredHeight: baseUnit * 6
                            clip: true
                            
                            TextArea {
                                id: descripcionField
                                placeholderText: "Descripción del producto (opcional)"
                                wrapMode: TextArea.Wrap
                                font.pixelSize: fontBaseSize
                                leftPadding: baseUnit
                                rightPadding: baseUnit
                                topPadding: baseUnit * 0.5
                                bottomPadding: baseUnit * 0.5
                                
                                background: Rectangle {
                                    color: "white"
                                    border.color: parent.activeFocus ? primaryColor : "#D1D9E0"
                                    border.width: parent.activeFocus ? 2 : 1
                                    radius: baseUnit * 0.5
                                }
                            }
                        }
                    }
                }
            }
            
            // ===============================
            // GRUPO: PRECIOS
            // ===============================

            GroupBox {
                Layout.fillWidth: true
                Layout.margins: baseUnit
                padding: baseUnit
                
                background: Rectangle {
                    color: "#FAFBFC"
                    border.color: "#E1E8ED"
                    border.width: 1
                    radius: baseUnit * 0.5
                }
                
                ColumnLayout {
                    width: parent.width
                    spacing: baseUnit
                    
                    // Título dentro del contenedor
                    RowLayout {
                        Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                        
                        Rectangle {
                            width: preciosLabel.width + baseUnit
                            height: baseUnit * 2.5
                            color: "#e67e22"
                            radius: baseUnit * 0.25
                            
                            Text {
                                id: preciosLabel
                                anchors.centerIn: parent
                                text: "💰 Precios"
                                color: "white"
                                font.bold: true
                                font.pixelSize: fontBaseSize * 0.8
                            }
                        }
                    }
                    
                    // Fila 1: Precio de Compra y Precio de Venta
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: baseUnit * 1.5
                        
                        // Campo Precio de Compra
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit * 0.5
                            
                            Text {
                                text: "Precio de Compra *"
                                color: textColor
                                font.bold: true
                                font.pixelSize: fontBaseSize
                            }
                            
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: baseUnit * 0.5
                                
                                Rectangle {
                                    Layout.preferredWidth: baseUnit * 3
                                    Layout.preferredHeight: baseUnit * 3.5
                                    color: "#FFF3E0"
                                    border.color: "#e67e22"
                                    border.width: 1
                                    radius: baseUnit * 0.5
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "$"
                                        color: "#e67e22"
                                        font.bold: true
                                        font.pixelSize: fontBaseSize * 1.2
                                    }
                                }
                                
                                TextField {
                                    id: precioCompraField
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: baseUnit * 3.5
                                    placeholderText: "0.00"
                                    font.pixelSize: fontBaseSize
                                    leftPadding: baseUnit
                                    rightPadding: baseUnit
                                    validator: DoubleValidator {
                                        bottom: 0.0
                                        decimals: 2
                                    }
                                    
                                    onTextChanged: calcularMargen()
                                    
                                    background: Rectangle {
                                        color: "white"
                                        border.color: parent.activeFocus ? "#e67e22" : "#D1D9E0"
                                        border.width: parent.activeFocus ? 2 : 1
                                        radius: baseUnit * 0.5
                                    }
                                }
                            }
                        }
                        
                        // Campo Precio de Venta
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit * 0.5
                            
                            Text {
                                text: "Precio de Venta *"
                                color: textColor
                                font.bold: true
                                font.pixelSize: fontBaseSize
                            }
                            
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: baseUnit * 0.5
                                
                                Rectangle {
                                    Layout.preferredWidth: baseUnit * 3
                                    Layout.preferredHeight: baseUnit * 3.5
                                    color: "#E8F5E8"
                                    border.color: successColor
                                    border.width: 1
                                    radius: baseUnit * 0.5
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "$"
                                        color: successColor
                                        font.bold: true
                                        font.pixelSize: fontBaseSize * 1.2
                                    }
                                }
                                
                                TextField {
                                    id: precioVentaField
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: baseUnit * 3.5
                                    placeholderText: "0.00"
                                    font.pixelSize: fontBaseSize
                                    leftPadding: baseUnit
                                    rightPadding: baseUnit
                                    validator: DoubleValidator {
                                        bottom: 0.0
                                        decimals: 2
                                    }
                                    
                                    onTextChanged: calcularMargen()
                                    
                                    background: Rectangle {
                                        color: "white"
                                        border.color: parent.activeFocus ? successColor : "#D1D9E0"
                                        border.width: parent.activeFocus ? 2 : 1
                                        radius: baseUnit * 0.5
                                    }
                                }
                            }
                        }
                    }
                    
                    // Fila 2: Margen de Ganancia (calculado automáticamente)
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: baseUnit * 0.5
                        
                        Text {
                            text: "Margen de Ganancia"
                            color: textColor
                            font.bold: true
                            font.pixelSize: fontBaseSize
                        }
                        
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: baseUnit * 3.5
                            color: "#F0F8FF"
                            border.color: "#3498db"
                            border.width: 1
                            radius: baseUnit * 0.5
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: baseUnit
                                spacing: baseUnit
                                
                                Text {
                                    text: "📈"
                                    font.pixelSize: fontBaseSize * 1.2
                                }
                                
                                Text {
                                    text: "Margen:"
                                    color: "#3498db"
                                    font.bold: true
                                    font.pixelSize: fontBaseSize
                                }
                                
                                Text {
                                    id: margenText
                                    text: "0%"
                                    color: "#2c3e50"
                                    font.bold: true
                                    font.pixelSize: fontBaseSize * 1.1
                                }
                                
                                Item {
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }
                }
            }
            
            // ===============================
            // GRUPO: STOCK INICIAL (solo visible al crear)
            // ===============================

            GroupBox {
                Layout.fillWidth: true
                Layout.margins: baseUnit
                visible: !modoEdicion
                padding: baseUnit
                
                background: Rectangle {
                    color: "#F8F9FA"
                    border.color: lightGrayColor
                    border.width: 1
                    radius: baseUnit * 0.5
                }
                
                ColumnLayout {
                    width: parent.width
                    spacing: baseUnit
                    
                    // Título dentro del contenedor
                    RowLayout {
                        Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                        
                        Rectangle {
                            width: stockLabel.width + baseUnit
                            height: baseUnit * 2.5
                            color: "#17a2b8"
                            radius: baseUnit * 0.25
                            
                            Text {
                                id: stockLabel
                                anchors.centerIn: parent
                                text: "📦 Stock Inicial"
                                color: "white"
                                font.bold: true
                                font.pixelSize: fontBaseSize * 0.8
                            }
                        }
                    }
                    
                    // GridLayout 2 columnas para stock
                    GridLayout {
                        width: parent.width
                        columns: 2
                        columnSpacing: baseUnit
                        rowSpacing: baseUnit
                        
                        // Stock en Cajas
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit * 0.5
                            
                            Text {
                                text: "Stock en Cajas"
                                color: textColor
                                font.bold: true
                                font.pixelSize: fontBaseSize
                            }
                            
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: baseUnit * 0.5
                                
                                Rectangle {
                                    Layout.preferredWidth: baseUnit * 3
                                    Layout.preferredHeight: baseUnit * 3.5
                                    color: "#E3F2FD"
                                    border.color: "#17a2b8"
                                    border.width: 1
                                    radius: baseUnit * 0.5
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "📦"
                                        font.pixelSize: fontBaseSize * 1.1
                                    }
                                }
                                
                                TextField {
                                    id: stockCajaField
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: baseUnit * 3.5
                                    placeholderText: "0"
                                    text: "0"
                                    font.pixelSize: fontBaseSize
                                    validator: IntValidator {
                                        bottom: 0
                                    }
                                    
                                    background: Rectangle {
                                        color: "white"
                                        border.color: parent.activeFocus ? "#17a2b8" : lightGrayColor
                                        border.width: 1
                                        radius: baseUnit * 0.5
                                    }
                                }
                            }
                        }
                        
                        // Stock Unitario
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit * 0.5
                            
                            Text {
                                text: "Stock Unitario"
                                color: textColor
                                font.bold: true
                                font.pixelSize: fontBaseSize
                            }
                            
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: baseUnit * 0.5
                                
                                Rectangle {
                                    Layout.preferredWidth: baseUnit * 3
                                    Layout.preferredHeight: baseUnit * 3.5
                                    color: "#E8F5E8"
                                    border.color: successColor
                                    border.width: 1
                                    radius: baseUnit * 0.5
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "🔢"
                                        font.pixelSize: fontBaseSize * 1.1
                                    }
                                }
                                
                                TextField {
                                    id: stockUnitarioField
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: baseUnit * 3.5
                                    placeholderText: "0"
                                    text: "0"
                                    font.pixelSize: fontBaseSize
                                    validator: IntValidator {
                                        bottom: 0
                                    }
                                    
                                    background: Rectangle {
                                        color: "white"
                                        border.color: parent.activeFocus ? successColor : lightGrayColor
                                        border.width: 1
                                        radius: baseUnit * 0.5
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // ===============================
    // PIE DE PÁGINA CON BOTONES
    // ===============================
    
    footer: Rectangle {
        height: baseUnit * 7
        color: "#F8F9FA"
        border.color: lightGrayColor
        border.width: 1
        radius: baseUnit
        
        // Solo redondear esquinas inferiores
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: baseUnit
            color: "#F8F9FA"
        }
        
        // RowLayout para organizar horizontalmente los elementos del pie
        RowLayout {
            anchors.fill: parent
            anchors.margins: baseUnit
            spacing: baseUnit
            
            // Barra de notificación
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: baseUnit * 4
                color: formularioValido ? "#d4edda" : "#f8d7da"
                border.color: formularioValido ? successColor : dangerColor
                border.width: 1
                radius: baseUnit * 0.5
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: baseUnit * 0.5
                    spacing: baseUnit * 0.5
                    
                    Text {
                        text: formularioValido ? "✅" : "⚠️"
                        font.pixelSize: fontBaseSize * 1.2
                    }
                    
                    Text {
                        Layout.fillWidth: true
                        text: formularioValido ? 
                              "Formulario completo - Listo para guardar" : 
                              "Complete los campos obligatorios (*)"
                        color: formularioValido ? "#155724" : "#721c24"
                        font.pixelSize: fontBaseSize * 0.9
                        font.bold: true
                        wrapMode: Text.WordWrap
                    }
                }
            }
            
            // Botones a la derecha
            RowLayout {
                spacing: baseUnit
                
                // Botón Cancelar
                Button {
                    Layout.preferredWidth: baseUnit * 10
                    Layout.preferredHeight: baseUnit * 4
                    text: "Cancelar"
                    
                    background: Rectangle {
                        color: parent.pressed ? Qt.darker("#6c757d", 1.2) : "#6c757d"
                        radius: baseUnit * 0.5
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
                        cerrarSolicitado()
                        crearProductoDialog.close()
                    }
                }
                
                // Botón Guardar
                Button {
                    Layout.preferredWidth: baseUnit * 12
                    Layout.preferredHeight: baseUnit * 4
                    text: modoEdicion ? "Actualizar" : "Crear"
                    enabled: formularioValido
                    
                    background: Rectangle {
                        color: parent.enabled ? 
                              (parent.pressed ? Qt.darker(successColor, 1.2) : successColor) : 
                              "#cccccc"
                        radius: baseUnit * 0.5
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
                        crearProductoDialog.close()
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
    
    // Función para abrir el diálogo
    function abrirDialog(modo = false, datos = null) {
        modoEdicion = modo
        productoData = datos
        if (modoEdicion && datos) {
            cargarDatosProducto()
        } else {
            limpiarFormulario()
        }
        open()
    }
}