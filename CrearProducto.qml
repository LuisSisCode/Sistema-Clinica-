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
    // LAYOUT PRINCIPAL - COLUMNLAYOUT PARA ORGANIZAR VERTICALMENTE
    // ===============================
    
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        
        // ===============================
        // 1. SECCIÓN DE ENCABEZADO
        // ===============================
        
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: baseUnit * 8
            color: primaryColor
            radius: baseUnit * 0.75
            
            // RowLayout para organizar horizontalmente los elementos del encabezado
            RowLayout {
                anchors.fill: parent
                anchors.margins: baseUnit * 2
                spacing: baseUnit * 1.5
                
                // Ícono a la izquierda
                Rectangle {
                    Layout.preferredWidth: baseUnit * 5
                    Layout.preferredHeight: baseUnit * 5
                    Layout.alignment: Qt.AlignVCenter
                    color: "white"
                    radius: baseUnit * 2.5
                    
                    Text {
                        anchors.centerIn: parent
                        text: modoEdicion ? "✏️" : "➕"
                        font.pixelSize: fontBaseSize * 1.5
                    }
                }
                
                // Textos en el centro - expandirse para ocupar el espacio sobrante
                Column {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
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
                
                // Botón cerrar a la derecha
                Button {
                    Layout.preferredWidth: baseUnit * 5
                    Layout.preferredHeight: baseUnit * 5
                    Layout.alignment: Qt.AlignVCenter
                    
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
        // 2. CUERPO DEL FORMULARIO - SCROLLVIEW PARA CONTENIDO DESPLAZABLE
        // ===============================
        
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: baseUnit * 3
            clip: true
            contentWidth: availableWidth
            
            // ColumnLayout principal para apilar los grupos de campos
            ColumnLayout {
                width: parent.width
                spacing: baseUnit * 3

                
                // ===============================
                // GRUPO: INFORMACIÓN BÁSICA
                // ===============================

                GroupBox {
                    Layout.fillWidth: true
                    Layout.margins: 0
                    topPadding: baseUnit * 3
                    bottomPadding: baseUnit * 2
                    leftPadding: baseUnit * 2
                    rightPadding: baseUnit * 2
                    
                    background: Rectangle {
                        color: "#FAFBFC"
                        border.color: "#E1E8ED"
                        border.width: 1
                        radius: baseUnit
                    }
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: baseUnit
                        spacing: baseUnit * 2
                        
                        // Título dentro del contenedor
                        RowLayout {
                            Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                            Layout.topMargin: -baseUnit * 2  // Ajuste para posicionamiento
                            
                            Rectangle {
                                width: basicInfoLabel.width + baseUnit * 2
                                height: baseUnit * 3
                                color: primaryColor
                                radius: baseUnit * 0.375
                                
                                Text {
                                    id: basicInfoLabel
                                    anchors.centerIn: parent
                                    text: "📋 Información Básica"
                                    color: "white"
                                    font.bold: true
                                    font.pixelSize: fontBaseSize * 0.9  
                                }
                            }
                        }
                        
                        // Fila 1: Código y Nombre
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit * 2
                            
                            // Campo Código
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.preferredWidth: parent.width * 0.4
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
                                    Layout.preferredHeight: baseUnit * 5
                                    placeholderText: "Ej: PARA001"
                                    font.pixelSize: fontBaseSize
                                    leftPadding: baseUnit * 1.5
                                    rightPadding: baseUnit * 1.5
                                    
                                    background: Rectangle {
                                        color: "white"
                                        border.color: parent.activeFocus ? primaryColor : "#D1D9E0"
                                        border.width: parent.activeFocus ? 2 : 1
                                        radius: baseUnit * 0.75
                                    }
                                }
                            }
                            
                            // Campo Nombre
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.preferredWidth: parent.width * 0.6
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
                                    Layout.preferredHeight: baseUnit * 5
                                    placeholderText: "Ej: Paracetamol 500mg"
                                    font.pixelSize: fontBaseSize
                                    leftPadding: baseUnit * 1.5
                                    rightPadding: baseUnit * 1.5
                                    
                                    background: Rectangle {
                                        color: "white"
                                        border.color: parent.activeFocus ? primaryColor : "#D1D9E0"
                                        border.width: parent.activeFocus ? 2 : 1
                                        radius: baseUnit * 0.75
                                    }
                                }
                            }
                        }
                        
                        // Fila 2: Marca (ancho completo)
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
                                Layout.preferredHeight: baseUnit * 5
                                model: marcasModel
                                textRole: "nombre"
                                valueRole: "id"
                                font.pixelSize: fontBaseSize
                                leftPadding: baseUnit * 1.5
                                rightPadding: baseUnit * 1.5
                                
                                background: Rectangle {
                                    color: "white"
                                    border.color: parent.activeFocus ? primaryColor : "#D1D9E0"
                                    border.width: parent.activeFocus ? 2 : 1
                                    radius: baseUnit * 0.75
                                }
                                
                                popup: Popup {
                                    y: parent.height
                                    width: parent.width
                                    implicitHeight: contentItem.implicitHeight
                                    padding: 1
                                    
                                    contentItem: ListView {
                                        clip: true
                                        implicitHeight: contentHeight
                                        model: parent.parent.popup.visible ? parent.parent.delegateModel : null
                                        currentIndex: parent.parent.highlightedIndex
                                        
                                        ScrollIndicator.vertical: ScrollIndicator { }
                                    }
                                    
                                    background: Rectangle {
                                        border.color: "#D1D9E0"
                                        radius: baseUnit * 0.75
                                        color: "white"
                                    }
                                }
                            }
                        }
                        
                        // Fila 3: Descripción (ancho completo)
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
                                clip: true
                                
                                TextArea {
                                    id: descripcionField
                                    placeholderText: "Descripción del producto (opcional)"
                                    wrapMode: TextArea.Wrap
                                    font.pixelSize: fontBaseSize
                                    leftPadding: baseUnit * 1.5
                                    rightPadding: baseUnit * 1.5
                                    topPadding: baseUnit
                                    bottomPadding: baseUnit
                                    
                                    background: Rectangle {
                                        color: "white"
                                        border.color: parent.activeFocus ? primaryColor : "#D1D9E0"
                                        border.width: parent.activeFocus ? 2 : 1
                                        radius: baseUnit * 0.75
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
                    Layout.margins: 0
                    topPadding: baseUnit * 4
                    bottomPadding: baseUnit * 2
                    leftPadding: baseUnit * 2
                    rightPadding: baseUnit * 2
                    
                    background: Rectangle {
                        color: "#FAFBFC"
                        border.color: "#E1E8ED"
                        border.width: 1
                        radius: baseUnit
                    }
                    
                    ColumnLayout {
                        width: parent.width
                        spacing: baseUnit * 2.5
                        
                        // Título dentro del contenedor
                        RowLayout {
                            Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                            Layout.topMargin: -baseUnit * 3  // Ajuste para posicionamiento
                            
                            Rectangle {
                                width: preciosLabel.width + baseUnit * 4
                                height: baseUnit * 5
                                color: "#e67e22"
                                radius: baseUnit * 0.625
                                
                                Text {
                                    id: preciosLabel
                                    anchors.centerIn: parent
                                    text: "💰 Precios"
                                    color: "white"
                                    font.bold: true
                                    font.pixelSize: fontBaseSize * 1.1
                                }
                            }
                        }
                        
                        // Fila 1: Precio de Compra y Precio de Venta
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit * 3
                            
                            // Campo Precio de Compra
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: baseUnit
                                
                                Text {
                                    text: "Precio de Compra *"
                                    color: textColor
                                    font.bold: true
                                    font.pixelSize: fontBaseSize * 1.05
                                }
                                
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: baseUnit
                                    
                                    Rectangle {
                                        Layout.preferredWidth: baseUnit * 5
                                        Layout.preferredHeight: baseUnit * 7
                                        color: "#FFF3E0"
                                        border.color: "#e67e22"
                                        border.width: 2
                                        radius: baseUnit * 0.75
                                        
                                        Text {
                                            anchors.centerIn: parent
                                            text: "$"
                                            color: "#e67e22"
                                            font.bold: true
                                            font.pixelSize: fontBaseSize * 1.5
                                        }
                                    }
                                    
                                    TextField {
                                        id: precioCompraField
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: baseUnit * 7
                                        placeholderText: "0.00"
                                        font.pixelSize: fontBaseSize * 1.1
                                        leftPadding: baseUnit * 2
                                        rightPadding: baseUnit * 2
                                        validator: DoubleValidator {
                                            bottom: 0.0
                                            decimals: 2
                                        }
                                        
                                        onTextChanged: calcularMargen()
                                        
                                        background: Rectangle {
                                            color: "white"
                                            border.color: parent.activeFocus ? "#e67e22" : "#D1D9E0"
                                            border.width: parent.activeFocus ? 2 : 1
                                            radius: baseUnit * 0.75
                                        }
                                    }
                                }
                            }
                            
                            // Campo Precio de Venta
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: baseUnit
                                
                                Text {
                                    text: "Precio de Venta *"
                                    color: textColor
                                    font.bold: true
                                    font.pixelSize: fontBaseSize * 1.05
                                }
                                
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: baseUnit
                                    
                                    Rectangle {
                                        Layout.preferredWidth: baseUnit * 5
                                        Layout.preferredHeight: baseUnit * 7
                                        color: "#E8F5E8"
                                        border.color: successColor
                                        border.width: 2
                                        radius: baseUnit * 0.75
                                        
                                        Text {
                                            anchors.centerIn: parent
                                            text: "$"
                                            color: successColor
                                            font.bold: true
                                            font.pixelSize: fontBaseSize * 1.5
                                        }
                                    }
                                    
                                    TextField {
                                        id: precioVentaField
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: baseUnit * 7
                                        placeholderText: "0.00"
                                        font.pixelSize: fontBaseSize * 1.1
                                        leftPadding: baseUnit * 2
                                        rightPadding: baseUnit * 2
                                        validator: DoubleValidator {
                                            bottom: 0.0
                                            decimals: 2
                                        }
                                        
                                        onTextChanged: calcularMargen()
                                        
                                        background: Rectangle {
                                            color: "white"
                                            border.color: parent.activeFocus ? successColor : "#D1D9E0"
                                            border.width: parent.activeFocus ? 2 : 1
                                            radius: baseUnit * 0.75
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Fila 2: Margen de Ganancia (calculado automáticamente)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit
                            
                            Text {
                                text: "Margen de Ganancia"
                                color: textColor
                                font.bold: true
                                font.pixelSize: fontBaseSize * 1.05
                            }
                            
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: baseUnit * 7
                                color: "#F0F8FF"
                                border.color: "#3498db"
                                border.width: 2
                                radius: baseUnit * 0.75
                                
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: baseUnit * 2
                                    spacing: baseUnit * 2
                                    
                                    Text {
                                        text: "📈"
                                        font.pixelSize: fontBaseSize * 1.5
                                    }
                                    
                                    Text {
                                        text: "Margen:"
                                        color: "#3498db"
                                        font.bold: true
                                        font.pixelSize: fontBaseSize * 1.1
                                    }
                                    
                                    Text {
                                        id: margenText
                                        text: "0%"
                                        color: "#2c3e50"
                                        font.bold: true
                                        font.pixelSize: fontBaseSize * 1.3
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
                    visible: !modoEdicion
                    topPadding: baseUnit * 4
                    bottomPadding: baseUnit * 2
                    leftPadding: baseUnit * 2
                    rightPadding: baseUnit * 2
                    
                    background: Rectangle {
                        color: "#F8F9FA"
                        border.color: lightGrayColor
                        border.width: 1
                        radius: baseUnit
                    }
                    
                    ColumnLayout {
                        width: parent.width
                        spacing: baseUnit * 2
                        
                        // Título dentro del contenedor
                        RowLayout {
                            Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                            Layout.topMargin: -baseUnit * 3  // Ajuste para posicionamiento
                            
                            Rectangle {
                                width: stockLabel.width + baseUnit * 4
                                height: baseUnit * 5
                                color: "#17a2b8"
                                radius: baseUnit * 0.625
                                
                                Text {
                                    id: stockLabel
                                    anchors.centerIn: parent
                                    text: "📦 Stock Inicial"
                                    color: "white"
                                    font.bold: true
                                    font.pixelSize: fontBaseSize * 1.1
                                }
                            }
                        }
                        
                        // GridLayout 2 columnas para stock
                        GridLayout {
                            width: parent.width
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
        }
        
        // ===============================
        // 3. SECCIÓN DE PIE DE PÁGINA - ACCIONES
        // ===============================
        
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: baseUnit * 10
            color: "#F8F9FA"
            border.color: lightGrayColor
            border.width: 1
            
            // RowLayout para organizar horizontalmente los elementos del pie
            RowLayout {
                anchors.fill: parent
                anchors.margins: baseUnit * 2
                spacing: baseUnit * 2
                
                // Barra de notificación - expandirse para ocupar el espacio disponible
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
                
                // Botones a la derecha con espaciado definido entre ellos
                RowLayout {
                    spacing: baseUnit * 2
                    
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