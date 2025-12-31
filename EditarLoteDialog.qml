import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: editarLoteOverlay
    anchors.fill: parent
    color: "#80000000"
    z: 1000
    
    // ========== PROPIEDADES PÚBLICAS ==========
    property var inventarioModel: null
    property var loteData: null
    property bool modoEdicion: false
    
    signal loteActualizado(var lote)
    signal cancelado()
    
    // ========== COLORES ==========
    readonly property color dangerColor: "#e74c3c"
    readonly property color primaryColor: "#3498db"
    readonly property color successColor: "#27ae60"
    
    // ========== PROPIEDADES DE DATOS ==========
    property int loteId: 0
    property string productoNombre: ""
    property int cantidadInicial: 0
    property real precioCompra: 0.0
    property int stockActual: 0
    property string fechaVencimiento: ""
    property bool noVencimiento: false
    
    property bool guardando: false
    property bool errorVisible: false
    property string mensajeError: ""
    
    // Sombra simple usando Rectangle
    Rectangle {
        anchors.centerIn: parent
        width: dialogContainer.width + 4
        height: dialogContainer.height + 4
        radius: 12
        color: "#40000000"
        z: -1
    }
    
    Rectangle {
        id: dialogContainer
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.9, 550)
        height: Math.min(parent.height * 0.9, 620)
        radius: 10
        color: "#FFFFFF"
        border.color: "#dee2e6"
        border.width: 1
        
        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            
            // ========== HEADER ==========
            Rectangle {
                id: header
                Layout.fillWidth: true
                Layout.preferredHeight: 65
                radius: 10
                color: "#2c3e50"
                
                // Esquinas redondeadas solo arriba
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: parent.radius
                    color: parent.color
                }
                
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    spacing: 12
                    
                    Rectangle {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        radius: 8
                        color: primaryColor
                        
                        Text {
                            anchors.centerIn: parent
                            text: "📦"
                            font.pixelSize: 20
                        }
                    }
                    
                    ColumnLayout {
                        spacing: 3
                        
                        Label {
                            text: "Editar Lote"
                            font.pixelSize: 17
                            font.bold: true
                            color: "white"
                        }
                        
                        Label {
                            text: loteData ? "#" + (loteData.Id_Lote || loteData.id || "").toString() : ""
                            font.pixelSize: 13
                            color: "#bdc3c7"
                        }
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    // Botón cerrar
                    Button {
                        Layout.preferredWidth: 35
                        Layout.preferredHeight: 35
                        enabled: !guardando
                        
                        background: Rectangle {
                            radius: 6
                            color: parent.hovered ? "#e74c3c" : "transparent"
                            border.color: "#bdc3c7"
                            border.width: parent.hovered ? 0 : 1
                            
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        
                        contentItem: Text {
                            text: "✕"
                            font.pixelSize: 18
                            color: parent.hovered ? "white" : "#bdc3c7"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: cancelado()
                    }
                }
            }
            
            // ========== CONTENIDO PRINCIPAL ==========
            ScrollView {
                id: scrollView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                
                ColumnLayout {
                    id: columnLayout
                    width: scrollView.width
                    spacing: 20
                    
                    Item { height: 10 }
                    
                    // ========== INFORMACIÓN DEL PRODUCTO ==========
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 85
                        Layout.leftMargin: 20
                        Layout.rightMargin: 20
                        radius: 8
                        color: "#f8f9fa"
                        border.color: "#e9ecef"
                        border.width: 1
                        
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 15
                            spacing: 5
                            
                            Label {
                                text: "Producto"
                                font.pixelSize: 12
                                font.bold: true
                                color: "#6c757d"
                            }
                            
                            Label {
                                Layout.fillWidth: true
                                text: productoNombre || (loteData ? loteData.Producto_Nombre || loteData.Producto : "")
                                font.pixelSize: 15
                                font.bold: true
                                color: "#2c3e50"
                                wrapMode: Text.WordWrap
                                elide: Text.ElideRight
                                maximumLineCount: 2
                            }
                        }
                    }
                    
                    // ========== PRECIO DE COMPRA ==========
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 20
                        Layout.rightMargin: 20
                        spacing: 8
                        
                        Label {
                            text: "Precio de Compra (Bs) *"
                            font.pixelSize: 14
                            font.bold: true
                            color: "#2c3e50"
                        }
                        
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            radius: 8
                            color: "white"
                            border.color: precioCompraField.activeFocus ? primaryColor : "#ced4da"
                            border.width: 2
                            
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 8
                                
                                Text {
                                    text: "Bs"
                                    font.pixelSize: 15
                                    font.bold: true
                                    color: primaryColor
                                }
                                
                                Rectangle {
                                    width: 2
                                    Layout.fillHeight: true
                                    color: "#e9ecef"
                                }
                                
                                TextInput {
                                    id: precioCompraField
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    text: precioCompra.toFixed(2)
                                    font.pixelSize: 15
                                    color: "#2c3e50"
                                    verticalAlignment: TextInput.AlignVCenter
                                    selectByMouse: true
                                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                                    
                                    Text {
                                        visible: parent.text === ""
                                        text: "0.00"
                                        font.pixelSize: 15
                                        color: "#adb5bd"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    
                                    onTextChanged: {
                                        errorVisible = false
                                        
                                        // PRIMERO: Convertir TODAS las comas a puntos inmediatamente
                                        var textoConPuntos = text.replace(/,/g, '.')
                                        
                                        // SEGUNDO: Permitir solo números y UN punto
                                        var textoLimpio = textoConPuntos.replace(/[^0-9.]/g, '')
                                        
                                        // TERCERO: Asegurar que solo haya UN punto decimal
                                        var partes = textoLimpio.split('.')
                                        if (partes.length > 2) {
                                            // Mantener solo el primer punto
                                            textoLimpio = partes[0] + '.' + partes.slice(1).join('')
                                        }
                                        
                                        // CUARTO: Limitar decimales a 2 dígitos
                                        if (partes.length === 2 && partes[1].length > 2) {
                                            textoLimpio = partes[0] + '.' + partes[1].substring(0, 2)
                                        }
                                        
                                        // QUINTO: Limitar la parte entera a 10 dígitos
                                        var partesFinales = textoLimpio.split('.')
                                        if (partesFinales[0].length > 10) {
                                            partesFinales[0] = partesFinales[0].substring(0, 10)
                                            textoLimpio = partesFinales.join('.')
                                        }
                                        
                                        // SEXTO: Actualizar el campo si cambió
                                        if (textoLimpio !== text) {
                                            var cursorPos = cursorPosition
                                            text = textoLimpio
                                            // Ajustar cursor después del cambio
                                            cursorPosition = Math.min(cursorPos, text.length)
                                        }
                                    }
                                    
                                    onFocusChanged: {
                                        if (!focus && text !== "") {
                                            // Al perder el foco, formatear a 2 decimales
                                            var numero = parseFloat(text)
                                            if (!isNaN(numero) && numero >= 0) {
                                                text = numero.toFixed(2)
                                            } else if (text === "" || isNaN(parseFloat(text))) {
                                                // Si no es válido, restaurar valor anterior
                                                text = precioCompra > 0 ? precioCompra.toFixed(2) : "0.00"
                                            }
                                        }
                                    }
                                    
                                    Keys.onReturnPressed: stockActualField.forceActiveFocus()
                                }
                            }
                        }
                        
                        
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            visible: precioCompraField.activeFocus && precioCompraField.text !== ""
                            
                            Rectangle {
                                Layout.preferredWidth: 6
                                Layout.preferredHeight: 6
                                radius: 3
                                color: primaryColor
                            }
                            
                            Label {
                                Layout.fillWidth: true
                                text: {
                                    var valor = precioCompraField.text.replace(',', '.')
                                    var numero = parseFloat(valor)
                                    if (!isNaN(numero)) {
                                        return "Vista previa: Bs " + numero.toFixed(2)
                                    }
                                    return ""
                                }
                                font.pixelSize: 12
                                font.bold: true
                                color: primaryColor
                            }
                        }
                        
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            
                            Text {
                                text: "💡"
                                font.pixelSize: 14
                            }
                            
                            Label {
                                Layout.fillWidth: true
                                text: "Use punto (.) o coma (,) - la coma se convierte automáticamente. Ej: 27,50 → 27.50"
                                font.pixelSize: 11
                                color: "#6c757d"
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                    
                    // ========== STOCK ACTUAL ==========
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 20
                        Layout.rightMargin: 20
                        spacing: 8
                        
                        RowLayout {
                            Layout.fillWidth: true
                            
                            Label {
                                text: "Stock Actual *"
                                font.pixelSize: 14
                                font.bold: true
                                color: "#2c3e50"
                            }
                            
                            Item { Layout.fillWidth: true }
                            
                            Rectangle {
                                Layout.preferredWidth: contentLabel.implicitWidth + 16
                                Layout.preferredHeight: 24
                                radius: 12
                                color: "#e3f2fd"
                                
                                Label {
                                    id: contentLabel
                                    anchors.centerIn: parent
                                    text: "Máx: " + cantidadInicial
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: primaryColor
                                }
                            }
                        }
                        
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            radius: 8
                            color: "white"
                            border.color: stockActualField.activeFocus ? primaryColor : "#ced4da"
                            border.width: 2
                            
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 8
                                
                                Text {
                                    text: "📊"
                                    font.pixelSize: 16
                                }
                                
                                Rectangle {
                                    width: 2
                                    Layout.fillHeight: true
                                    color: "#e9ecef"
                                }
                                
                                TextInput {
                                    id: stockActualField
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    text: stockActual.toString()
                                    font.pixelSize: 15
                                    color: "#2c3e50"
                                    verticalAlignment: TextInput.AlignVCenter
                                    selectByMouse: true
                                    inputMethodHints: Qt.ImhDigitsOnly
                                    
                                    Text {
                                        visible: parent.text === ""
                                        text: "0"
                                        font.pixelSize: 15
                                        color: "#adb5bd"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    
                                    onTextChanged: {
                                        errorVisible = false
                                        
                                        // Permitir solo números
                                        var textoLimpio = text.replace(/[^0-9]/g, '')
                                        
                                        // Limitar longitud
                                        if (textoLimpio.length > 8) {
                                            textoLimpio = textoLimpio.substring(0, 8)
                                        }
                                        
                                        // Validar contra cantidad inicial
                                        if (textoLimpio !== "") {
                                            var valor = parseInt(textoLimpio)
                                            if (!isNaN(valor) && valor > cantidadInicial) {
                                                textoLimpio = cantidadInicial.toString()
                                            }
                                        }
                                        
                                        if (textoLimpio !== text) {
                                            var cursorPos = cursorPosition
                                            text = textoLimpio
                                            cursorPosition = Math.min(cursorPos, text.length)
                                        }
                                    }
                                    
                                    Keys.onReturnPressed: {
                                        if (!noVencimientoCheck.checked) {
                                            fechaVencimientoField.forceActiveFocus()
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // ========== FECHA DE VENCIMIENTO ==========
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 20
                        Layout.rightMargin: 20
                        spacing: 8
                        
                        Label {
                            text: "Fecha de Vencimiento"
                            font.pixelSize: 14
                            font.bold: true
                            color: "#2c3e50"
                        }
                        
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            radius: 8
                            color: noVencimientoCheck.checked ? "#f8f9fa" : "white"
                            border.color: fechaVencimientoField.activeFocus ? primaryColor : "#ced4da"
                            border.width: 2
                            opacity: noVencimientoCheck.checked ? 0.6 : 1.0
                            
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 8
                                
                                Text {
                                    text: "📅"
                                    font.pixelSize: 16
                                }
                                
                                Rectangle {
                                    width: 2
                                    Layout.fillHeight: true
                                    color: "#e9ecef"
                                }
                                
                                TextInput {
                                    id: fechaVencimientoField
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    text: fechaVencimiento
                                    font.pixelSize: 15
                                    color: "#2c3e50"
                                    verticalAlignment: TextInput.AlignVCenter
                                    selectByMouse: true
                                    enabled: !noVencimientoCheck.checked
                                    inputMethodHints: Qt.ImhDate
                                    
                                    Text {
                                        visible: parent.text === "" && parent.enabled
                                        text: "AAAA-MM-DD"
                                        font.pixelSize: 15
                                        color: "#adb5bd"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    
                                    onTextChanged: {
                                        errorVisible = false
                                        
                                        // Permitir solo números y guiones
                                        var textoLimpio = text.replace(/[^0-9-]/g, '')
                                        
                                        // Auto-formatear mientras escribe
                                        if (textoLimpio.length > 10) {
                                            textoLimpio = textoLimpio.substring(0, 10)
                                        }
                                        
                                        // Auto-agregar guiones
                                        if (textoLimpio.length >= 4 && textoLimpio.charAt(4) !== '-') {
                                            textoLimpio = textoLimpio.substring(0, 4) + '-' + textoLimpio.substring(4)
                                        }
                                        if (textoLimpio.length >= 7 && textoLimpio.charAt(7) !== '-') {
                                            textoLimpio = textoLimpio.substring(0, 7) + '-' + textoLimpio.substring(7)
                                        }
                                        
                                        if (textoLimpio !== text) {
                                            var cursorPos = cursorPosition
                                            text = textoLimpio
                                            cursorPosition = Math.min(cursorPos, text.length)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Checkbox "Sin vencimiento"
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 45
                            radius: 8
                            color: noVencimientoCheck.checked ? "#fff3cd" : "#f8f9fa"
                            border.color: noVencimientoCheck.checked ? "#ffc107" : "#e9ecef"
                            border.width: 1
                            
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 10
                                
                                CheckBox {
                                    id: noVencimientoCheck
                                    Layout.preferredWidth: 24
                                    Layout.preferredHeight: 24
                                    checked: noVencimiento
                                    
                                    indicator: Rectangle {
                                        implicitWidth: 24
                                        implicitHeight: 24
                                        radius: 4
                                        border.color: noVencimientoCheck.checked ? "#ffc107" : "#ced4da"
                                        border.width: 2
                                        color: noVencimientoCheck.checked ? "#ffc107" : "white"
                                        
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        Behavior on border.color { ColorAnimation { duration: 150 } }
                                        
                                        Text {
                                            anchors.centerIn: parent
                                            text: "✓"
                                            font.pixelSize: 16
                                            font.bold: true
                                            color: "white"
                                            visible: noVencimientoCheck.checked
                                        }
                                    }
                                    
                                    onCheckedChanged: {
                                        noVencimiento = checked
                                        if (checked) {
                                            fechaVencimientoField.text = ""
                                        }
                                    }
                                }
                                
                                ColumnLayout {
                                    spacing: 2
                                    
                                    Label {
                                        text: "Sin fecha de vencimiento"
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: "#2c3e50"
                                    }
                                    
                                    Label {
                                        text: "Marque si el producto no caduca"
                                        font.pixelSize: 11
                                        color: "#6c757d"
                                    }
                                }
                                
                                Item { Layout.fillWidth: true }
                            }
                        }
                    }
                    
                    // ========== MENSAJE DE ERROR ==========
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: errorVisible ? errorContent.implicitHeight + 20 : 0
                        Layout.leftMargin: 20
                        Layout.rightMargin: 20
                        visible: errorVisible
                        color: "#fff3cd"
                        radius: 8
                        border.color: "#ffc107"
                        border.width: 2
                        clip: true
                        
                        Behavior on Layout.preferredHeight {
                            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                        }
                        
                        RowLayout {
                            id: errorContent
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10
                            
                            Text {
                                text: "⚠️"
                                font.pixelSize: 20
                            }
                            
                            Label {
                                Layout.fillWidth: true
                                text: mensajeError
                                font.pixelSize: 13
                                color: "#856404"
                                wrapMode: Text.WordWrap
                            }
                            
                            Button {
                                Layout.preferredWidth: 30
                                Layout.preferredHeight: 30
                                
                                background: Rectangle {
                                    radius: 15
                                    color: parent.hovered ? "#ffc107" : "transparent"
                                    
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                                
                                contentItem: Text {
                                    text: "✕"
                                    font.pixelSize: 16
                                    color: "#856404"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                
                                onClicked: errorVisible = false
                            }
                        }
                    }
                    
                    Item { height: 10 }
                }
            }
            
            // ========== FOOTER ==========
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 75
                color: "#f8f9fa"
                
                // Línea separadora superior
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: "#dee2e6"
                }
                
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 15
                    
                    Button {
                        text: "Cancelar"
                        Layout.preferredWidth: 130
                        Layout.preferredHeight: 44
                        enabled: !guardando
                        
                        background: Rectangle {
                            radius: 8
                            color: parent.hovered ? "#6c757d" : "#adb5bd"
                            border.color: "#6c757d"
                            border.width: 0
                            
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            font.pixelSize: 14
                            font.bold: true
                            color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: cancelado()
                    }
                    
                    Button {
                        text: guardando ? "Guardando..." : "Guardar Cambios"
                        Layout.preferredWidth: 160
                        Layout.preferredHeight: 44
                        enabled: !guardando && precioCompraField.text !== "" && stockActualField.text !== ""
                        
                        background: Rectangle {
                            radius: 8
                            color: {
                                if (!parent.enabled) return "#ced4da"
                                return parent.hovered ? "#229954" : successColor
                            }
                            border.width: 0
                            
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        
                        contentItem: RowLayout {
                            spacing: 8
                            
                            Text {
                                text: guardando ? "⏳" : "💾"
                                font.pixelSize: 16
                            }
                            
                            Text {
                                text: parent.parent.text
                                font.pixelSize: 14
                                font.bold: true
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                        
                        onClicked: guardarCambios()
                    }
                }
            }
        }
    }
    
    // ========== TIMER PARA AUTO-OCULTAR ERRORES ==========
    Timer {
        id: errorTimer
        interval: 5000
        running: false
        repeat: false
        onTriggered: {
            errorVisible = false
            mensajeError = ""
        }
    }
    
    // ========== FUNCIONES ==========
    
    function cargarDatosLote(lote) {
        console.log("📦 Cargando datos del lote:", JSON.stringify(lote))
        
        try {
            // Conversión explícita a tipos JavaScript nativos
            var idLote = parseInt(lote.Id_Lote || lote.id || 0)
            var stock = parseInt(lote.Stock_Lote || lote.Stock || lote.Stock_Actual || 0)
            var precio = parseFloat(lote.Precio_Compra || lote.PrecioCompra || 0)
            var cantInicial = parseInt(lote.Cantidad_Inicial || stock)
            
            // Convertir nombre de producto a string
            var prodNombre = lote.Producto_Nombre || lote.Producto || ""
            prodNombre = String(prodNombre)
            
            // Manejo especial de fecha
            var fechaVenc = lote.Fecha_Vencimiento || lote.FechaVencimiento || ""
            
            // Verificar si es un objeto (datetime de Python)
            if (typeof fechaVenc === "object" && fechaVenc !== null) {
                try {
                    if (fechaVenc.toString && typeof fechaVenc.toString === "function") {
                        fechaVenc = fechaVenc.toString()
                    } else {
                        fechaVenc = ""
                    }
                } catch (e) {
                    console.log("⚠️ Error convirtiendo fecha objeto:", e)
                    fechaVenc = ""
                }
            }
            
            // Convertir a string y limpiar
            fechaVenc = String(fechaVenc).trim()
            
            // Limpiar valores no válidos
            if (fechaVenc === "" || 
                fechaVenc === "null" || 
                fechaVenc === "undefined" || 
                fechaVenc.includes("QVariant") || 
                fechaVenc.includes("PySide") ||
                fechaVenc.includes("datetime")) {
                fechaVenc = ""
            }
            
            // Asignar a las propiedades del componente
            loteId = idLote
            productoNombre = prodNombre
            cantidadInicial = cantInicial
            precioCompra = precio
            stockActual = stock
            
            // Asignar fecha
            if (fechaVenc === "") {
                fechaVencimiento = ""
                noVencimiento = true
            } else {
                fechaVencimiento = fechaVenc
                noVencimiento = false
            }
            
            // Asignar a los campos de texto
            precioCompraField.text = precio.toFixed(2)
            stockActualField.text = stock.toString()
            fechaVencimientoField.text = fechaVencimiento
            
            console.log("✅ Datos del lote cargados correctamente")
            
        } catch (error) {
            console.log("❌ Error cargando datos:", error.toString())
        }
    }
    
    function validarFormulario() {
        // Normalizar el texto del precio (convertir coma a punto)
        var precioTexto = precioCompraField.text.replace(',', '.')
        var precioValor = parseFloat(precioTexto)
        
        // Validar precio de compra
        if (precioCompraField.text === "" || isNaN(precioValor) || precioValor <= 0) {
            mostrarError("El precio de compra debe ser mayor a 0")
            precioCompraField.forceActiveFocus()
            return false
        }
        
        // Validar stock
        if (stockActualField.text === "") {
            mostrarError("Debe ingresar el stock actual")
            stockActualField.forceActiveFocus()
            return false
        }
        
        var stockValor = parseInt(stockActualField.text)
        
        if (isNaN(stockValor) || stockValor < 0) {
            mostrarError("El stock no puede ser negativo")
            stockActualField.forceActiveFocus()
            return false
        }
        
        // Validar que el stock no exceda la cantidad inicial
        if (stockValor > cantidadInicial) {
            mostrarError("El stock no puede ser mayor a la cantidad inicial (" + cantidadInicial + ")")
            stockActualField.forceActiveFocus()
            return false
        }
        
        // Validar fecha de vencimiento si no está marcado "sin vencimiento"
        if (!noVencimientoCheck.checked) {
            if (fechaVencimientoField.text === "") {
                mostrarError("Debe ingresar una fecha de vencimiento o marcar 'Sin vencimiento'")
                fechaVencimientoField.forceActiveFocus()
                return false
            }
            
            // Validar formato de fecha (YYYY-MM-DD)
            var fechaRegex = /^\d{4}-\d{2}-\d{2}$/
            if (!fechaRegex.test(fechaVencimientoField.text)) {
                mostrarError("El formato de la fecha debe ser AAAA-MM-DD")
                fechaVencimientoField.forceActiveFocus()
                return false
            }
            
            // Validar que sea una fecha válida
            var partes = fechaVencimientoField.text.split('-')
            var año = parseInt(partes[0])
            var mes = parseInt(partes[1])
            var dia = parseInt(partes[2])
            
            if (mes < 1 || mes > 12) {
                mostrarError("El mes debe estar entre 01 y 12")
                fechaVencimientoField.forceActiveFocus()
                return false
            }
            
            if (dia < 1 || dia > 31) {
                mostrarError("El día debe estar entre 01 y 31")
                fechaVencimientoField.forceActiveFocus()
                return false
            }
        }
        
        return true
    }
    
    function guardarCambios() {
        console.log("💾 Iniciando guardado de cambios...")
        
        // Validar formulario
        if (!validarFormulario()) {
            console.log("❌ Validación fallida")
            return
        }
        
        if (!inventarioModel) {
            mostrarError("Error: InventarioModel no disponible")
            return
        }
        
        if (guardando) {
            console.log("⚠️ Ya hay un guardado en proceso")
            return
        }
        
        guardando = true
        
        try {
            // Log del texto crudo del campo
            console.log("📝 Texto crudo del precio:", precioCompraField.text)
            
            // Preparar datos como objeto (sin id_lote)
            var precioTexto = precioCompraField.text.replace(',', '.')
            var precioNumero = parseFloat(precioTexto)
            
            console.log("📝 Precio después de replace:", precioTexto)
            console.log("📝 Precio como número:", precioNumero)
            
            var datosActualizados = {
                "stock": parseInt(stockActualField.text),
                "precio_compra": precioNumero,
                "fecha_vencimiento": noVencimientoCheck.checked ? null : fechaVencimientoField.text
            }
            
            // Convertir a JSON string
            var datosJSON = JSON.stringify(datosActualizados)
            
            console.log("📤 Enviando datos para lote ID:", loteId)
            console.log("   JSON:", datosJSON)
            
            // Llamar con 2 parámetros: (lote_id, json_string)
            var resultado = inventarioModel.actualizar_lote(loteId, datosJSON)
            
            if (resultado) {
                console.log("✅ Lote actualizado exitosamente")
                
                // Emitir señal con los datos actualizados
                loteActualizado(datosActualizados)
                
                // Cerrar diálogo
                Qt.callLater(function() {
                    console.log("🔒 Cerrando EditarLoteDialog")
                    editarLoteOverlay.visible = false
                })
            } else {
                console.log("❌ Error al actualizar lote")
                mostrarError("Error al actualizar el lote. Verifique los datos e intente nuevamente.")
            }
            
        } catch (error) {
            console.log("❌ Error en guardarCambios:", error.toString())
            mostrarError("Error inesperado: " + error.toString())
        } finally {
            guardando = false
        }
    }
    
    function mostrarError(mensaje) {
        mensajeError = mensaje
        errorVisible = true
        
        // Auto-ocultar después de 5 segundos
        errorTimer.restart()
    }
    
    // ========== INICIALIZACIÓN ==========
    onLoteDataChanged: {
        console.log("📦 loteData cambió:", loteData ? "con datos" : "null")
        if (loteData) {
            console.log("✅ Cargando datos del lote...")
            cargarDatosLote(loteData)
        }
    }
    
    Component.onCompleted: {
        console.log("✏️ EditarLoteDialog.qml cargado")
        if (loteData) {
            cargarDatosLote(loteData)
        } else {
            console.log("⚠️ No se recibieron datos de lote")
        }
    }
}
