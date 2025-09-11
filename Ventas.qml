import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// Componente principal del módulo de Ventas - Vista con filtros modernos
Item {
    id: ventasRoot
    
    // Referencia al módulo principal de farmacia
    property var inventarioModel: parent.inventarioModel
    property var ventaModel: parent.ventaModel
    property var compraModel: parent.compraModel
    
    // Señal para navegar a crear venta
    signal navegarACrearVenta()
    
    // Propiedades de control de vistas
    property bool detalleVentaDialogOpen: false
    property var ventaSeleccionada: null

    // Propiedades de filtros
    property string filtroTemporal: "Hoy"
    property string filtroEstado: "Todas"
    property string busquedaID: ""
    property string fechaDesde: ""
    property string fechaHasta: ""
    property bool mostrarRangoPersonalizado: false

    // Propiedades de paginación para ventas
    property int itemsPerPageVentas: 10
    property int currentPageVentas: 0
    property int totalPagesVentas: 0

    // SISTEMA DE MÉTRICAS COHERENTE CON MAIN.QML
    readonly property real scaleFactor: Math.min(width / 1400, height / 900)
    readonly property real baseUnit: Math.max(8, height / 100)
    readonly property real fontBaseSize: Math.max(12, height / 70)
    
    // Tamaños de fuente escalables
    readonly property real fontTiny: fontBaseSize * 0.75
    readonly property real fontSmall: fontBaseSize * 0.85
    readonly property real fontMedium: fontBaseSize
    readonly property real fontLarge: fontBaseSize * 1.15
    readonly property real fontXLarge: fontBaseSize * 1.4
    
    // Espaciados
    readonly property real marginTiny: baseUnit * 0.5
    readonly property real marginSmall: baseUnit * 0.75
    readonly property real marginMedium: baseUnit
    readonly property real marginLarge: baseUnit * 1.5
    
    // Radios
    readonly property real radiusSmall: baseUnit * 0.5
    readonly property real radiusMedium: baseUnit * 0.75
    readonly property real radiusLarge: baseUnit
    
    // Alturas de controles
    readonly property real controlHeight: Math.max(40, baseUnit * 5)
    readonly property real buttonHeight: Math.max(36, baseUnit * 4.5)
    readonly property real headerHeight: Math.max(60, baseUnit * 7.5)

    // Colores del tema
    property color primaryColor: "#3498db"
    property color successColor: "#27ae60"
    property color warningColor: "#f39c12"
    property color dangerColor: "#e74c3c"
    property color blueColor: "#3498db"
    property color whiteColor: "#ffffff"
    property color textColor: "#2c3e50"
    property color darkGrayColor: "#7f8c8d"
    property color lightGrayColor: "#bdc3c7"

    // MODELO PARA DETALLES DE VENTA
    ListModel {
        id: productosDetalleModel
    }

    // MODELO PARA VENTAS PAGINADAS
    ListModel {
        id: ventasPaginadasModel
    }

    // CONEXIÓN CON DATOS CENTRALES
    Connections {
        target: ventaModel
        function onVentasHoyChanged() {
            console.log("🛒 Ventas: Ventas del día actualizadas")
            actualizarPaginacionVentas()
        }
    }

    // FUNCIÓN para actualizar paginación de ventas
    function actualizarPaginacionVentas() {
        if (!ventaModel) return
        
        var totalItems = ventaModel.total_ventas_hoy
        totalPagesVentas = Math.ceil(totalItems / itemsPerPageVentas)
        
        if (currentPageVentas >= totalPagesVentas && totalPagesVentas > 0) {
            currentPageVentas = totalPagesVentas - 1
        }
        if (currentPageVentas < 0) {
            currentPageVentas = 0
        }
        
        ventasPaginadasModel.clear()
        
        var startIndex = currentPageVentas * itemsPerPageVentas
        var endIndex = Math.min(startIndex + itemsPerPageVentas, totalItems)
        
        var ventasArray = ventaModel.ventas_hoy || []
        for (var i = startIndex; i < endIndex; i++) {
            if (i < ventasArray.length) {
                ventasPaginadasModel.append(ventasArray[i])
            }
        }
    }

    // Función para aplicar filtros
    function aplicarFiltros() {
        console.log("🔍 Aplicando filtros:", filtroTemporal, filtroEstado, busquedaID)
        
        if (!ventaModel) {
            console.log("❌ VentaModel no disponible")
            return
        }
        
        // Llamar al nuevo slot del VentaModel
        ventaModel.aplicar_filtros(
            filtroTemporal,     // "Hoy", "Ayer", "7 días", "30 días", "Personalizado"
            filtroEstado,       // "Todas", "Activas", "Anuladas"  
            busquedaID,         // ID de venta a buscar
            fechaDesde,         // Fecha desde (formato YYYY-MM-DD)
            fechaHasta          // Fecha hasta (formato YYYY-MM-DD)
        )
    }

    // Función para mostrar detalles de venta
    function mostrarDetalleVenta(index) {
        if (!ventaModel) return
        
        var ventasArray = ventaModel.ventas_hoy || []
        if (index < 0 || index >= ventasArray.length) return
        
        try {
            ventaSeleccionada = ventasArray[index]
            var ventaId = ventaSeleccionada.id || ventaSeleccionada.idVenta
            if (!ventaId) return
            
            productosDetalleModel.clear()
            var detalleVenta = ventaModel.obtener_detalle_venta(parseInt(ventaId))
            
            if (!detalleVenta || typeof detalleVenta !== 'object') {
                productosDetalleModel.append({
                    codigo: "---",
                    nombre: "Error obteniendo detalles",
                    precio: 0,
                    cantidad: 0,
                    subtotal: 0
                })
                detalleVentaDialogOpen = true
                return
            }
            
            var detallesArray = detalleVenta.detalles || []
            
            if (detallesArray && typeof detallesArray === 'object' && detallesArray.length > 0) {
                for (var i = 0; i < detallesArray.length; i++) {
                    var detalle = detallesArray[i]
                    if (detalle && typeof detalle === 'object') {
                        var cantidad = parseFloat(detalle.cantidad || detalle.Cantidad_Unitario || 0)
                        var precio = parseFloat(detalle.precio || detalle.Precio_Unitario || 0)
                        
                        productosDetalleModel.append({
                            codigo: String(detalle.codigo || detalle.Producto_Codigo || "N/A"),
                            nombre: String(detalle.nombre || detalle.Producto_Nombre || "Producto desconocido"),
                            precio: precio,
                            cantidad: cantidad,
                            subtotal: cantidad * precio
                        })
                    }
                }
            } else {
                productosDetalleModel.append({
                    codigo: "---",
                    nombre: "No hay productos registrados",
                    precio: 0,
                    cantidad: 0,
                    subtotal: 0
                })
            }
            
            detalleVentaDialogOpen = true
            
        } catch (e) {
            productosDetalleModel.clear()
            productosDetalleModel.append({
                codigo: "ERROR",
                nombre: "Error: " + e.message,
                precio: 0,
                cantidad: 0,
                subtotal: 0
            })
            detalleVentaDialogOpen = true
        }
    }

    // CONTENEDOR PRINCIPAL - VISTA DE VENTAS
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: marginMedium
        spacing: marginMedium
        
        // Header del módulo con título y botones de acción
        RowLayout {
            Layout.fillWidth: true
            spacing: marginMedium
            
            // Información del módulo
            RowLayout {
                spacing: 12
                            
                Image {
                    source: "Resources/iconos/ventas.png"
                    Layout.preferredWidth: 60
                    Layout.preferredHeight: 60
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: parent.opacity = 0.8
                        onExited: parent.opacity = 1.0
                    }
                    
                    Behavior on opacity {
                        NumberAnimation { duration: 150 }
                    }
                }
                
                ColumnLayout {
                    spacing: marginTiny
                    
                    Label {
                        text: "Módulo de Farmacia"
                        font.pixelSize: 24
                        font.bold: true
                        color: textColor
                    }
                    
                    Label {
                        text: "Gestión de Ventas"
                        font.pixelSize: 16
                        color: darkGrayColor
                    }
                }
            }            
            Item { Layout.fillWidth: true }
            
            // Información en tiempo real
            Rectangle {
                Layout.preferredWidth: 150
                Layout.preferredHeight: 60
                color: "#E8F5E8"
                radius: radiusSmall
                border.color: successColor
                border.width: 1
                
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: marginTiny
                    
                    Label {
                        text: "Productos Disponibles:"
                        font.pixelSize: fontTiny
                        color: darkGrayColor
                        Layout.alignment: Qt.AlignHCenter
                    }
                    
                    Label {
                        text: inventarioModel ? inventarioModel.total_productos.toString() : "0"
                        font.pixelSize: fontLarge
                        font.bold: true
                        color: successColor
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
            
            // Botón de Nueva Venta
            Button {
                id: nuevaVentaButton
                Layout.preferredWidth: 230
                Layout.preferredHeight: 75
                
                background: Rectangle {
                    color: parent.pressed ? Qt.darker(successColor, 1.2) : successColor
                    radius: radiusMedium
                    
                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                    
                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: 2
                        color: "#00000020"
                        radius: radiusMedium
                        z: -1
                    }
                }
                
                contentItem: RowLayout {
                    spacing: 8
                    anchors.centerIn: parent
                    
                    Image {
                        source: "Resources/iconos/añadirProducto.png"
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }
                    
                    Label {
                        text: "Nueva Venta"
                        color: whiteColor
                        font.bold: true
                        font.pixelSize: 18
                    }
                }
                
                onClicked: {
                    navegarACrearVenta()
                }
                
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: parent.scale = 1.02
                    onExited: parent.scale = 1.0
                    onClicked: parent.clicked()
                }
                
                Behavior on scale {
                    NumberAnimation { duration: 100 }
                }
            }
        }

        // SECCIÓN DE FILTROS MODERNOS
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: mostrarRangoPersonalizado ? 140 : 90
            color: "#f8f9fa"
            radius: radiusMedium
            border.color: "#e9ecef"
            border.width: 1
            
            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
            }
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: marginMedium
                spacing: marginMedium
                
                // Primera fila de filtros
                RowLayout {
                    Layout.fillWidth: true
                    spacing: marginMedium
                    
                    // Filtros Temporales
                    ColumnLayout {
                        spacing: marginTiny
                        
                        Label {
                            text: "📅 Período"
                            color: textColor
                            font.bold: true
                            font.pixelSize: fontSmall + 4
                        }
                        
                        RowLayout {
                            spacing: marginTiny
                            
                            Repeater {
                                model: ["Hoy", "Ayer", "7 días", "30 días", "Personalizado"]
                                
                                Button {
                                    property bool isSelected: {
                                        if (modelData === "Personalizado") return mostrarRangoPersonalizado
                                        return filtroTemporal === modelData
                                    }
                                    
                                    Layout.preferredHeight: buttonHeight
                                    
                                    background: Rectangle {
                                        color: {
                                            if (parent.isSelected) return primaryColor
                                            if (parent.pressed) return Qt.lighter(primaryColor, 1.8)
                                            if (parent.hovered) return Qt.lighter(primaryColor, 1.6)
                                            return "transparent"
                                        }
                                        border.color: parent.isSelected ? primaryColor : lightGrayColor
                                        border.width: 1
                                        radius: radiusSmall + 10
                                        
                                        Behavior on color {
                                            ColorAnimation { duration: 150 }
                                        }
                                    }
                                    
                                    contentItem: Label {
                                        text: modelData
                                        color: parent.isSelected ? whiteColor : textColor
                                        font.bold: parent.isSelected
                                        font.pixelSize: fontSmall + 4
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    
                                    hoverEnabled: true
                                    
                                    onClicked: {
                                        if (modelData === "Personalizado") {
                                            mostrarRangoPersonalizado = !mostrarRangoPersonalizado
                                            if (mostrarRangoPersonalizado) {
                                                filtroTemporal = "Personalizado"
                                            }
                                        } else {
                                            mostrarRangoPersonalizado = false
                                            filtroTemporal = modelData
                                        }
                                        aplicarFiltros()
                                    }
                                }
                            }
                        }
                    }
                    
                    // Separador vertical
                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.fillHeight: true
                        color: lightGrayColor
                        Layout.topMargin: marginSmall
                        Layout.bottomMargin: marginSmall
                    }
                    
                    // Filtros por Estado
                    ColumnLayout {
                        spacing: marginTiny
                        
                        Label {
                            text: "🔄 Estado"
                            color: textColor
                            font.bold: true
                            font.pixelSize: fontSmall + 4
                        }
                        
                        RowLayout {
                            spacing: marginTiny
                            
                            Repeater {
                                model: [
                                    {text: "Todas", color: "#6c757d"},
                                    {text: "Activas", color: "#28a745"},
                                    {text: "Anuladas", color: "#dc3545"}
                                ]
                                
                                Button {
                                    property bool isSelected: filtroEstado === modelData.text
                                    
                                    Layout.preferredHeight: buttonHeight
                                    
                                    background: Rectangle {
                                        color: {
                                            if (parent.isSelected) return modelData.color
                                            if (parent.pressed) return Qt.lighter(modelData.color, 1.8)
                                            if (parent.hovered) return Qt.lighter(modelData.color, 1.6)
                                            return "transparent"
                                        }
                                        border.color: parent.isSelected ? modelData.color : lightGrayColor
                                        border.width: 1
                                        radius: radiusSmall+ 5
                                        
                                        Behavior on color {
                                            ColorAnimation { duration: 150 }
                                        }
                                    }
                                    
                                    contentItem: Label {
                                        text: modelData.text
                                        color: parent.isSelected ? whiteColor : textColor
                                        font.bold: parent.isSelected
                                        font.pixelSize: fontSmall + 4
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    
                                    hoverEnabled: true
                                    
                                    onClicked: {
                                        filtroEstado = modelData.text
                                        aplicarFiltros()
                                    }
                                }
                            }
                        }
                    }
                    
                    // Separador vertical
                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.fillHeight: true
                        color: lightGrayColor
                        Layout.topMargin: marginSmall
                        Layout.bottomMargin: marginSmall
                    }
                    
                    // Búsqueda por ID
                    ColumnLayout {
                        spacing: marginTiny
                        
                        Label {
                            text: "🔍 Buscar ID"
                            color: textColor
                            font.bold: true
                            font.pixelSize: fontSmall + 4
                        }
                        
                        RowLayout {
                            spacing: marginTiny
                            
                            Rectangle {
                                Layout.preferredWidth: 160
                                Layout.preferredHeight: buttonHeight
                                color: whiteColor
                                border.color: busquedaTextField.activeFocus ? primaryColor : lightGrayColor
                                border.width: busquedaTextField.activeFocus ? 2 : 1
                                radius: radiusSmall
                                
                                Behavior on border.color {
                                    ColorAnimation { duration: 150 }
                                }
                                
                                TextField {
                                    id: busquedaTextField
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    
                                    placeholderText: "ID de venta..."
                                    font.pixelSize: fontSmall + 4
                                    color: textColor
                                    
                                    background: Rectangle {
                                        color: "transparent"
                                    }
                                    
                                    onTextChanged: {
                                        busquedaID = text
                                        if (text.length === 0 || text.length >= 2) {
                                            aplicarFiltros()
                                        }
                                    }
                                }
                            }
                            
                            Button {
                                Layout.preferredWidth: 50
                                Layout.preferredHeight: buttonHeight
                                
                                background: Rectangle {
                                    color: parent.pressed ? Qt.darker(primaryColor, 1.2) : primaryColor
                                    radius: radiusSmall + 5
                                    
                                    Behavior on color {
                                        ColorAnimation { duration: 150 }
                                    }
                                }
                                
                                contentItem: Label {
                                    text: "🔍"
                                    color: whiteColor
                                    font.pixelSize: fontMedium
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                
                                onClicked: {
                                    aplicarFiltros()
                                }
                            }
                        }
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    // Botón limpiar filtros
                    Button {
                        Layout.preferredHeight: buttonHeight
                        
                        background: Rectangle {
                            color: parent.pressed ? Qt.darker(warningColor, 1.2) : "transparent"
                            border.color: warningColor
                            border.width: 1
                            radius: radiusSmall
                            
                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }
                        }
                        
                        contentItem: RowLayout {
                            spacing: marginTiny
                            
                            Label {
                                text: "🗑️"
                                font.pixelSize: fontSmall + 4
                            }
                            
                            Label {
                                text: "Limpiar"
                                color: warningColor
                                font.bold: true
                                font.pixelSize: fontSmall + 4
                            }
                        }
                        
                        onClicked: {
                            filtroTemporal = "Hoy"
                            filtroEstado = "Todas"
                            busquedaID = ""
                            busquedaTextField.text = ""
                            mostrarRangoPersonalizado = false
                            fechaDesde = ""
                            fechaHasta = ""
                            aplicarFiltros()
                        }
                    }
                }
                
                // Segunda fila - Rango personalizado (solo visible cuando se selecciona)
                RowLayout {
                    Layout.fillWidth: true
                    visible: mostrarRangoPersonalizado
                    spacing: marginMedium
                    
                    Label {
                        text: "📅 Rango personalizado:"
                        color: textColor
                        font.bold: true
                        font.pixelSize: fontSmall + 4
                    }
                    
                    RowLayout {
                        spacing: marginTiny
                        
                        Label {
                            text: "Desde:"
                            color: darkGrayColor
                            font.pixelSize: fontSmall + 4
                        }
                        
                        Rectangle {
                            Layout.preferredWidth: 140
                            Layout.preferredHeight: controlHeight
                            color: whiteColor
                            border.color: fechaDesdeField.activeFocus ? primaryColor : lightGrayColor
                            border.width: fechaDesdeField.activeFocus ? 2 : 1
                            radius: radiusSmall
                            
                            TextField {
                                id: fechaDesdeField
                                anchors.fill: parent
                                anchors.margins: 2
                                
                                placeholderText: "YYYY-MM-DD"
                                font.pixelSize: fontSmall + 4
                                color: textColor
                                text: fechaDesde
                                
                                background: Rectangle {
                                    color: "transparent"
                                }
                                
                                onTextChanged: {
                                    fechaDesde = text
                                }
                            }
                        }
                        
                        Label {
                            text: "Hasta:"
                            color: darkGrayColor
                            font.pixelSize: fontSmall + 4
                        }
                        
                        Rectangle {
                            Layout.preferredWidth: 140
                            Layout.preferredHeight: controlHeight
                            color: whiteColor
                            border.color: fechaHastaField.activeFocus ? primaryColor : lightGrayColor
                            border.width: fechaHastaField.activeFocus ? 2 : 1
                            radius: radiusSmall + 10
                            
                            TextField {
                                id: fechaHastaField
                                anchors.fill: parent
                                anchors.margins: 2
                                
                                placeholderText: "YYYY-MM-DD"
                                font.pixelSize: fontSmall + 4
                                color: textColor
                                text: fechaHasta
                                
                                background: Rectangle {
                                    color: "transparent"
                                }
                                
                                onTextChanged: {
                                    fechaHasta = text
                                }
                            }
                        }
                        
                        Button {
                            Layout.preferredHeight: controlHeight
                            
                            background: Rectangle {
                                color: parent.pressed ? Qt.darker(successColor, 1.2) : successColor
                                radius: radiusSmall + 5
                                
                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                            
                            contentItem: Label {
                                text: "Aplicar"
                                color: whiteColor
                                font.bold: true
                                font.pixelSize: fontSmall + 4
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: {
                                aplicarFiltros()
                            }
                        }
                    }
                    
                    Item { Layout.fillWidth: true }
                }
            }
        }

        // Tabla de ventas 
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#FFFFFF"
            border.color: "#D5DBDB"
            border.width: 1
            radius: radiusMedium
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 0
                spacing: 0
                
                // Header de la tabla
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: controlHeight
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
                                text: "ID VENTA"
                                color: "#2C3E50"
                                font.bold: true
                                font.pixelSize: fontSmall
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
                                anchors.leftMargin: marginSmall
                                anchors.verticalCenter: parent.verticalCenter
                                text: "USUARIO"
                                color: "#2C3E50"
                                font.bold: true
                                font.pixelSize: fontSmall
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
                                font.pixelSize: fontSmall
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
                                font.pixelSize: fontSmall
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
                                text: "HORA"
                                color: "#2C3E50"
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
                                text: "ACCIÓN"
                                color: "#2C3E50"
                                font.bold: true
                                font.pixelSize: fontSmall
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
                        id: ventasTable
                        anchors.fill: parent
                        model: ventasPaginadasModel
                        
                        delegate: Item {
                            width: ventasTable.width
                            height: 60
                            
                            Rectangle {
                                anchors.fill: parent
                                color: ventasTable.currentIndex === index ? "#E3F2FD" : "transparent"
                                opacity: 0.3
                            }
                            
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
                                        text: model.idVenta
                                        color: "#3498DB"
                                        font.bold: true
                                        font.pixelSize: fontMedium
                                    }
                                }
                                
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 200
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#D5DBDB"
                                    border.width: 1
                                    
                                    ColumnLayout {
                                        anchors.left: parent.left
                                        anchors.leftMargin: marginSmall
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2
                                        
                                        Label {
                                            text: model.usuario
                                            color: "#2C3E50"
                                            font.bold: true
                                            font.pixelSize: fontMedium
                                            elide: Text.ElideRight
                                            Layout.maximumWidth: parent.parent.width - 24
                                        }
                                        
                                        RowLayout {
                                            spacing: 6
                                            
                                            Label {
                                                text: "👤"
                                                font.pixelSize: fontTiny
                                            }
                                            
                                            Label {
                                                text: "Vendedor"
                                                color: "#7F8C8D"
                                                font.pixelSize: fontSmall
                                                elide: Text.ElideRight
                                                Layout.maximumWidth: 150
                                            }
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
                                        width: 80
                                        height: 28
                                        color: "#27AE60"
                                        radius: 14
                                        
                                        Label {
                                            anchors.centerIn: parent
                                            text: "Bs " + model.total.toFixed(2)
                                            color: "#FFFFFF"
                                            font.bold: true
                                            font.pixelSize: fontSmall
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
                                            text: "📅"
                                            font.pixelSize: fontSmall
                                            color: "#3498DB"
                                        }
                                        
                                        Label {
                                            text: model.fecha
                                            color: "#2C3E50"
                                            font.pixelSize: fontSmall
                                            font.bold: true
                                        }
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 120
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#D5DBDB"
                                    border.width: 1
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: model.hora
                                        color: "#7F8C8D"
                                        font.pixelSize: fontSmall
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 100
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#D5DBDB"
                                    border.width: 1
                                    
                                    Button {
                                        anchors.centerIn: parent
                                        width: 70
                                        height: 30
                                        text: "Ver"
                                        
                                        background: Rectangle {
                                            color: parent.pressed ? Qt.darker(blueColor, 1.2) : blueColor
                                            radius: 15
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
                                            mostrarDetalleVenta(index)
                                        }
                                    }
                                }
                            }
                            
                            MouseArea {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                anchors.rightMargin: 100
                                
                                onClicked: {
                                    ventasTable.currentIndex = index
                                }
                            }
                        }
                        
                        // Estado vacío
                        Item {
                            anchors.centerIn: parent
                            visible: ventaModel ? ventaModel.total_ventas_hoy === 0 : true
                            width: 300
                            height: 200
                            
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: marginMedium
                                
                                Label {
                                    text: "🛒"
                                    font.pixelSize: 48
                                    color: lightGrayColor
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                
                                Label {
                                    text: "No hay ventas registradas"
                                    color: darkGrayColor
                                    font.pixelSize: fontMedium
                                    font.bold: true
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                
                                Label {
                                    text: "Las ventas aparecerán aquí cuando se completen"
                                    color: darkGrayColor
                                    font.pixelSize: fontSmall
                                    Layout.alignment: Qt.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    Layout.maximumWidth: 250
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }
                    }
                }

                // Control de Paginación
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
                            enabled: currentPageVentas > 0
                            
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
                                font.pixelSize: fontMedium
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: {
                                if (currentPageVentas > 0) {
                                    currentPageVentas--
                                    actualizarPaginacionVentas()
                                }
                            }
                        }

                        Label {
                            text: "Página " + (currentPageVentas + 1) + " de " + Math.max(1, totalPagesVentas)
                            color: "#374151"
                            font.pixelSize: fontMedium
                            font.weight: Font.Medium
                        }

                        Button {
                            Layout.preferredWidth: 110
                            Layout.preferredHeight: 36
                            text: "Siguiente →"
                            enabled: currentPageVentas < totalPagesVentas - 1
                            
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
                                font.pixelSize: fontMedium
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: {
                                if (currentPageVentas < totalPagesVentas - 1) {
                                    currentPageVentas++
                                    actualizarPaginacionVentas()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MODAL DE DETALLE DE VENTA (sin cambios)
    Rectangle {
        id: modalOverlay
        anchors.fill: parent
        color: "#000000"
        opacity: 0.5
        visible: detalleVentaDialogOpen
        z: 1000
        
        MouseArea {
            anchors.fill: parent
            onClicked: {
                detalleVentaDialogOpen = false
            }
        }
    }

    Rectangle {
        id: modalContainer
        anchors.centerIn: parent
        width: Math.min(900, parent.width * 0.9)
        height: Math.min(700, parent.height * 0.9)
        
        visible: detalleVentaDialogOpen
        z: 1001
        
        color: "#ffffff"
        radius: radiusLarge
        border.color: "#dee2e6"
        border.width: 1
        
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 4
            anchors.leftMargin: 4
            color: "#00000020"
            radius: parent.radius
            z: -1
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: marginLarge
            spacing: marginLarge
            
            // CABECERA DEL MODAL
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 120
                color: "#f8f9fa"
                radius: radiusLarge
                border.color: "#e9ecef"
                border.width: 1
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 16
                    
                    RowLayout {
                        Layout.fillWidth: true
                        
                        Label {
                            text: "Detalle de Venta: " + (ventaSeleccionada ? ventaSeleccionada.idVenta : "---")
                            font.pixelSize: fontLarge
                            font.bold: true
                            color: "#2c3e50"
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        Rectangle {
                            width: 32
                            height: 32
                            color: cerrarMouseArea.pressed ? "#c0392b" : "#e74c3c"
                            radius: 16
                            
                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                color: "#ffffff"
                                font.bold: true
                                font.pixelSize: fontMedium
                            }
                            
                            MouseArea {
                                id: cerrarMouseArea
                                anchors.fill: parent
                                onClicked: {
                                    detalleVentaDialogOpen = false
                                }
                            }
                        }
                    }
                    
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 40
                        
                        RowLayout {
                            spacing: 8
                            
                            Text {
                                text: "📅"
                                font.pixelSize: fontMedium
                                color: "#3498db"
                            }
                            
                            ColumnLayout {
                                spacing: 4
                                
                                Label {
                                    text: "Fecha y Hora:"
                                    font.pixelSize: fontSmall
                                    color: "#6c757d"
                                    font.bold: true
                                }
                                
                                Label {
                                    text: ventaSeleccionada ? 
                                        ventaSeleccionada.fecha + " | " + ventaSeleccionada.hora : "---"
                                    font.pixelSize: fontMedium
                                    color: "#2c3e50"
                                    font.bold: true
                                }
                            }
                        }
                        
                        RowLayout {
                            spacing: 8
                            
                            Text {
                                text: "👤"
                                font.pixelSize: fontMedium
                                color: "#3498db"
                            }
                            
                            ColumnLayout {
                                spacing: 4
                                
                                Label {
                                    text: "Vendido por:"
                                    font.pixelSize: fontSmall
                                    color: "#6c757d"
                                    font.bold: true
                                }
                                
                                Label {
                                    text: ventaSeleccionada ? ventaSeleccionada.usuario : "---"
                                    font.pixelSize: fontMedium
                                    color: "#2c3e50"
                                    font.bold: true
                                }
                            }
                        }
                        
                        Item { Layout.fillWidth: true }
                    }
                }
            }
            
            // CUERPO DEL MODAL - LISTA DE PRODUCTOS
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12
                
                Label {
                    text: "📦 Productos vendidos:"
                    font.bold: true
                    color: "#2c3e50"
                    font.pixelSize: fontMedium
                }
                
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#ffffff"
                    border.color: "#dee2e6"
                    border.width: 1
                    radius: radiusMedium
                    
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0
                        
                        // ENCABEZADO DE LA TABLA
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 45
                            color: "#f8f9fa"
                            
                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: 1
                                color: "#dee2e6"
                            }
                            
                            RowLayout {
                                anchors.fill: parent
                                spacing: 0
                                
                                Rectangle {
                                    Layout.preferredWidth: 50
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#dee2e6"
                                    border.width: 1
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "#"
                                        font.bold: true
                                        color: "#495057"
                                        font.pixelSize: fontSmall
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 100
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#dee2e6"
                                    border.width: 1
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "CÓDIGO"
                                        font.bold: true
                                        color: "#495057"
                                        font.pixelSize: fontSmall
                                    }
                                }
                                
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#dee2e6"
                                    border.width: 1
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "PRODUCTO"
                                        font.bold: true
                                        color: "#495057"
                                        font.pixelSize: fontSmall
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 70
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#dee2e6"
                                    border.width: 1
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "CANT."
                                        font.bold: true
                                        color: "#495057"
                                        font.pixelSize: fontSmall
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 90
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#dee2e6"
                                    border.width: 1
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "PRECIO UNIT."
                                        font.bold: true
                                        color: "#495057"
                                        font.pixelSize: fontSmall
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 90
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#dee2e6"
                                    border.width: 1
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "SUBTOTAL"
                                        font.bold: true
                                        color: "#495057"
                                        font.pixelSize: fontSmall
                                    }
                                }
                            }
                        }
                        
                        // LISTA DE PRODUCTOS
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            
                            ListView {
                                anchors.fill: parent
                                model: productosDetalleModel
                                
                                delegate: Rectangle {
                                    width: parent ? parent.width : 0
                                    height: 50
                                    color: index % 2 === 0 ? "#ffffff" : "#f8f9fa"
                                    
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        width: parent.width
                                        height: 1
                                        color: "#dee2e6"
                                    }
                                    
                                    RowLayout {
                                        anchors.fill: parent
                                        spacing: 0
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 50
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#dee2e6"
                                            border.width: 1
                                            
                                            Label {
                                                anchors.right: parent.right
                                                anchors.rightMargin: 8
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: (index + 1).toString()
                                                color: "#6c757d"
                                                font.pixelSize: fontSmall
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 100
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#dee2e6"
                                            border.width: 1
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.leftMargin: 8
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: model.codigo || "---"
                                                color: "#007bff"
                                                font.bold: true
                                                font.pixelSize: fontSmall
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#dee2e6"
                                            border.width: 1
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.leftMargin: marginSmall
                                                anchors.right: parent.right
                                                anchors.rightMargin: marginSmall
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: model.nombre || "Sin nombre"
                                                color: "#2c3e50"
                                                font.pixelSize: fontSmall
                                                elide: Text.ElideRight
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 70
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#dee2e6"
                                            border.width: 1
                                            
                                            Label {
                                                anchors.right: parent.right
                                                anchors.rightMargin: marginSmall
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: (model.cantidad || 0).toString()
                                                color: "#fd7e14"
                                                font.bold: true
                                                font.pixelSize: fontSmall
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 90
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#dee2e6"
                                            border.width: 1
                                            
                                            Label {
                                                anchors.right: parent.right
                                                anchors.rightMargin: marginSmall
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "Bs " + (model.precio || 0).toFixed(2)
                                                color: "#28a745"
                                                font.bold: true
                                                font.pixelSize: fontSmall
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 90
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#dee2e6"
                                            border.width: 1
                                            
                                            Label {
                                                anchors.right: parent.right
                                                anchors.rightMargin: marginSmall
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "Bs " + (model.subtotal || 0).toFixed(2)
                                                color: "#007bff"
                                                font.bold: true
                                                font.pixelSize: fontSmall
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // PIE DEL MODAL - RESUMEN FINANCIERO
            RowLayout {
                Layout.fillWidth: true
                
                Item { Layout.fillWidth: true }
                
                Rectangle {
                    Layout.preferredWidth: baseUnit * 32
                    Layout.preferredHeight: baseUnit * 8
                    color: "#f8f9fa"
                    radius: radiusSmall
                    border.color: "#dee2e6"
                    border.width: 1
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: marginSmall
                        
                        Label {
                            text: "TOTAL:"
                            color: "#2c3e50"
                            font.pixelSize: fontMedium
                            font.bold: true
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        Label {
                            text: {
                                var total = 0
                                for (var i = 0; i < productosDetalleModel.count; i++) {
                                    var item = productosDetalleModel.get(i)
                                    if (item && item.subtotal) {
                                        total += item.subtotal
                                    }
                                }
                                return "Bs " + total.toFixed(2)
                            }
                            color: "#e74c3c"
                            font.pixelSize: fontLarge
                            font.bold: true
                        }
                    }
                }
            }
            
            // PIE DEL MODAL - BOTONES DE ACCIÓN
            RowLayout {
                Layout.fillWidth: true
                
                Item { Layout.fillWidth: true }
                
                Rectangle {
                    Layout.preferredWidth: baseUnit * 20
                    Layout.preferredHeight: baseUnit * 8
                    color: cerrarBtnMouseArea.pressed ? "#5a6268" : "#6c757d"
                    radius: radiusMedium
                    border.color: "#495057"
                    border.width: 1
                    
                    Label {
                        anchors.centerIn: parent
                        text: "Cerrar"
                        color: "#ffffff"
                        font.bold: true
                        font.pixelSize: fontMedium
                    }
                    
                    MouseArea {
                        id: cerrarBtnMouseArea
                        anchors.fill: parent
                        onClicked: {
                            detalleVentaDialogOpen = false
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        console.log("=== MÓDULO DE VENTAS CON FILTROS INICIALIZADO ===")
        
        if (!ventaModel || !inventarioModel || !compraModel) {
            console.log("❌ ERROR: Models no están disponibles")
            return
        }
        
        console.log("✅ Models conectados correctamente")
        actualizarPaginacionVentas()
        console.log("=== MÓDULO LISTO ===")
    }
    
    Item {
        anchors.fill: parent
        focus: true
        
        Keys.onEscapePressed: {
            console.log("Escape pressed in Ventas.qml")
            ventasMainRoot.forceActiveFocus()
        }
        
        z: -1
    }
}