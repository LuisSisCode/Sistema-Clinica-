import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15

Popup {
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
    
    // Estado de carga de marcas
    property bool marcasCargadas: false
    property bool datosProductoCargados: false
    
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
    
    modal: true
    closePolicy: Popup.CloseOnEscape
    
    // Tamaño y posición
    width: Math.min(800, parent.width * 0.9)
    height: Math.min(700, parent.height * 0.9)
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2
    
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
        console.log("🔧 Modo edición:", modoEdicion)
        console.log("🏷️ Marcas recibidas:", marcasModel.length)
        
        // Esperar un momento antes de cargar datos para evitar condiciones de carrera
        inicializacionTimer.start()
    }
    
    // Timer para inicialización controlada
    Timer {
        id: inicializacionTimer
        interval: 100
        running: false
        repeat: false
        
        onTriggered: {
            // Verificar si tenemos marcas
            if (marcasModel.length === 0) {
                console.log("⚠️ Esperando carga de marcas...")
                esperarMarcasTimer.start()
                return
            }
            
            marcasCargadas = true
            
            if (modoEdicion && productoData) {
                console.log("📦 Cargando datos para edición...")
                cargarDatosProducto()
            }
        }
    }
    
    // Timer para esperar marcas
    Timer {
        id: esperarMarcasTimer
        interval: 250
        running: false
        repeat: true
        
        property int intentos: 0
        readonly property int maxIntentos: 10
        
        onTriggered: {
            intentos++
            
            if (marcasModel.length > 0) {
                console.log("✅ Marcas cargadas exitosamente:", marcasModel.length)
                marcasCargadas = true
                stop()
                
                if (modoEdicion && productoData) {
                    cargarDatosProducto()
                }
            } else if (intentos >= maxIntentos) {
                console.log("❌ Timeout esperando marcas, abriendo sin marcas")
                stop()
            }
        }
        
        onRunningChanged: {
            if (!running) {
                intentos = 0
            }
        }
    }
    
    onClosed: {
        limpiarFormulario()
        datosProductoCargados = false
    }
    
    // ===============================
    // CONTENIDO PRINCIPAL
    // ===============================
    
    contentItem: ColumnLayout {
        spacing: 0
        
        // ===============================
        // ENCABEZADO PERSONALIZADO
        // ===============================
        
        Rectangle {
            Layout.fillWidth: true
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
        // CONTENIDO PRINCIPAL (SCROLLABLE)
        // ===============================
        
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
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
                            
                            // Campo Marca - CORREGIDO
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
                                    
                                    // MEJORA: Placeholder cuando no hay marcas
                                    displayText: {
                                        if (!marcasCargadas) {
                                            return "Cargando marcas..."
                                        }
                                        if (currentIndex === -1) {
                                            return "Seleccionar marca..."
                                        }
                                        return currentText
                                    }
                                    
                                    enabled: marcasCargadas && marcasModel.length > 0
                                    
                                    background: Rectangle {
                                        color: parent.enabled ? "white" : "#f5f5f5"
                                        border.color: parent.activeFocus ? primaryColor : "#D1D9E0"
                                        border.width: parent.activeFocus ? 2 : 1
                                        radius: baseUnit * 0.5
                                    }
                                    
                                    onCurrentIndexChanged: {
                                        if (currentIndex >= 0) {
                                            console.log("🏷️ Marca seleccionada:", currentText)
                                        }
                                    }
                                    
                                    // Indicador de carga mejorado
                                    indicator: BusyIndicator {
                                        visible: !marcasCargadas
                                        running: !marcasCargadas
                                        anchors.right: parent.right
                                        anchors.rightMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 16
                                        height: 16
                                    }
                                }
                            }
                        }
                        
                        // Fila 2: Descripción (ancho completo) - CORREGIDO
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
                                    id: descripcionField  // CAMBIADO: Mantener nombre consistente
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
                                            text: "Bs"
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
                                        text: "Bs"
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
    
    Rectangle {
        Layout.fillWidth: true
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
                        text: {
                            if (!marcasCargadas) {
                                return "Cargando marcas..."
                            }
                            return formularioValido ? 
                                  "Formulario completo - Listo para guardar" : 
                                  "Complete los campos obligatorios (*)"
                        }
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
                    enabled: formularioValido && marcasCargadas
                    
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
}

    // ===============================
    // FUNCIONES - CORREGIDAS
    // ===============================
    
    function cargarDatosProducto() {
        if (!productoData) {
            console.log("❌ No hay datos de producto para cargar")
            return
        }
        
        console.log("📦 Cargando datos del producto...")
        
        // CORREGIDO: Cargar campos básicos con manejo robusto de diferentes formatos
        codigoField.text = obtenerValorCampo(productoData, ["codigo", "Codigo"]) || ""
        nombreField.text = obtenerValorCampo(productoData, ["nombre", "Nombre"]) || ""
        
        // CORREGIDO: Cargar descripción con múltiples nombres posibles
        var detalles = obtenerValorCampo(productoData, [
            "detalles", "Detalles", "Producto_Detalles", 
            "descripcion", "descripcion", "Descripcion"
        ]) || ""
        descripcionField.text = detalles
        
        // CORREGIDO: Cargar precios con conversión segura
        var precioCompra = obtenerValorNumerico(productoData, [
            "precioCompra", "precio_compra", "Precio_compra"
        ]) || 0
        var precioVenta = obtenerValorNumerico(productoData, [
            "precioVenta", "precio_venta", "Precio_venta"
        ]) || 0
        
        precioCompraField.text = precioCompra.toFixed(2)
        precioVentaField.text = precioVenta.toFixed(2)
        
        // CORREGIDO: Cargar marca con búsqueda mejorada
        cargarMarcaDelProducto()
        
        // Calcular margen
        calcularMargen()
        
        datosProductoCargados = true
        console.log("✅ Datos del producto cargados exitosamente")
    }
    
    // NUEVA FUNCIÓN: Obtener valor de campo con múltiples nombres posibles
    function obtenerValorCampo(objeto, nombres) {
        for (var i = 0; i < nombres.length; i++) {
            var valor = objeto[nombres[i]]
            if (valor !== undefined && valor !== null && valor !== "") {
                return valor
            }
        }
        return null
    }
    
    // NUEVA FUNCIÓN: Obtener valor numérico con conversión segura
    function obtenerValorNumerico(objeto, nombres) {
        var valor = obtenerValorCampo(objeto, nombres)
        if (valor === null) return 0
        
        var numero = parseFloat(valor)
        return isNaN(numero) ? 0 : numero
    }
    
    // NUEVA FUNCIÓN: Cargar marca del producto
    function cargarMarcaDelProducto() {
        if (!marcasCargadas || marcasModel.length === 0) {
            console.log("⚠️ No se pueden cargar marcas todavía")
            return
        }
        
        // CORREGIDO: Buscar marca con múltiples campos posibles
        var marcaId = obtenerValorNumerico(productoData, [
            "idMarca", "id_marca", "ID_Marca", "Marca_ID"
        ])
        var marcaNombre = obtenerValorCampo(productoData, [
            "marcaNombre", "marca_nombre", "Marca_Nombre", "idMarca"
        ])
        
        console.log("🏷️ Buscando marca - ID:", marcaId, "Nombre:", marcaNombre)
        
        var encontrado = false
        
        // Buscar por ID primero
        if (marcaId > 0) {
            for (var i = 0; i < marcasModel.length; i++) {
                if (marcasModel[i].id == marcaId) {
                    marcaCombo.currentIndex = i
                    console.log("✅ Marca encontrada por ID:", marcasModel[i].Nombre)
                    encontrado = true
                    break
                }
            }
        }
        
        // Si no se encontró por ID, buscar por nombre
        if (!encontrado && marcaNombre) {
            for (var j = 0; j < marcasModel.length; j++) {
                if (marcasModel[j].Nombre === marcaNombre) {
                    marcaCombo.currentIndex = j
                    console.log("✅ Marca encontrada por nombre:", marcasModel[j].Nombre)
                    encontrado = true
                    break
                }
            }
        }
        
        if (!encontrado) {
            console.log("⚠️ No se encontró la marca en la lista")
            marcaCombo.currentIndex = -1
        }
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
    
    // CORREGIDO: Crear producto con campo detalles correcto
    function crearProducto() {
        var producto = {
            codigo: codigoField.text.trim(),
            nombre: nombreField.text.trim(),
            detalles: descripcionField.text.trim(),  // CORREGIDO: usar "detalles" no "descripcion"
            id_marca: marcaCombo.currentValue,
            precio_compra: parseFloat(precioCompraField.text || "0"),
            precio_venta: parseFloat(precioVentaField.text || "0"),
            stock_caja: parseInt(stockCajaField.text || "0"),
            stock_unitario: parseInt(stockUnitarioField.text || "0")
        }
        
        console.log("📦 Creando producto:", producto.codigo)
        productoCreado(producto)
    }
    
    // CORREGIDO: Actualizar producto con campo detalles correcto  
    function actualizarProducto() {
        var producto = {
            id: productoData.id,
            codigo: codigoField.text.trim(),
            nombre: nombreField.text.trim(),
            detalles: descripcionField.text.trim(),  // CORREGIDO: usar "detalles" no "descripcion"
            id_marca: marcaCombo.currentValue,
            precio_compra: parseFloat(precioCompraField.text || "0"),
            precio_venta: parseFloat(precioVentaField.text || "0")
        }
        
        console.log("📝 Actualizando producto:", producto.codigo)
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
        datosProductoCargados = false
    }
    
    // Función para abrir el diálogo - MEJORADA
    function abrirDialog(modo = false, datos = null) {
        console.log("🚀 Abriendo diálogo - Modo edición:", modo)
        
        modoEdicion = modo
        productoData = datos
        
        // Limpiar estado previo
        limpiarFormulario()
        datosProductoCargados = false
        
        // Iniciar proceso de carga
        inicializacionTimer.start()
        open()
    }
}