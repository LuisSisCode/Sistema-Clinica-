import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15

// Componente principal del módulo de Ventas - Vista simplificada
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
    property string filtroActual: "Todos"
    property var ventaSeleccionada: null

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

    // Base de datos de productos vendidos (para detalles)
    property var productosVendidosDatabase: ({
        "V001": [
            {codigo: "MED001", nombre: "Paracetamol 500mg", precio: 15.50, cantidad: 2, subtotal: 31.00},
            {codigo: "MED002", nombre: "Ibuprofeno 400mg", precio: 15.25, cantidad: 4, subtotal: 61.00}
        ],
        "V002": [
            {codigo: "MED003", nombre: "Loratadina 10mg", precio: 18.90, cantidad: 1, subtotal: 18.90},
            {codigo: "MED002", nombre: "Amoxicilina 500mg", precio: 23.10, cantidad: 1, subtotal: 23.10}
        ]
    })

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
        if (!ventaModel) {
            console.log("🐛 DEBUG QML: ventaModel es null")
            return
        }
        
        console.log("🐛 DEBUG QML: ventaModel disponible:", ventaModel)
        console.log("🐛 DEBUG QML: ventaModel.total_ventas_hoy:", ventaModel.total_ventas_hoy)
        console.log("🐛 DEBUG QML: ventaModel.ventas_hoy:", ventaModel.ventas_hoy)
        console.log("🐛 DEBUG QML: Tipo de ventas_hoy:", typeof ventaModel.ventas_hoy)
        
        var totalItems = ventaModel.total_ventas_hoy
        console.log("🐛 DEBUG QML: totalItems calculado:", totalItems)
        totalPagesVentas = Math.ceil(totalItems / itemsPerPageVentas)
        
        // Ajustar página actual si es necesario
        if (currentPageVentas >= totalPagesVentas && totalPagesVentas > 0) {
            currentPageVentas = totalPagesVentas - 1
        }
        if (currentPageVentas < 0) {
            currentPageVentas = 0
        }
        
        // Limpiar modelo paginado
        ventasPaginadasModel.clear()
        
        // Calcular índices
        var startIndex = currentPageVentas * itemsPerPageVentas
        var endIndex = Math.min(startIndex + itemsPerPageVentas, totalItems)
        
        // Agregar elementos de la página actual
        var ventasArray = ventaModel.ventas_hoy || []
        for (var i = startIndex; i < endIndex; i++) {
            if (i < ventasArray.length) {
                ventasPaginadasModel.append(ventasArray[i])
            }
        }
        
        console.log("📄 Ventas: Página", currentPageVentas + 1, "de", totalPagesVentas,
                    "- Mostrando", ventasPaginadasModel.count, "de", totalItems)
    }

    // Función para mostrar detalles de venta
    function mostrarDetalleVenta(index) {
        console.log("🔍 Ventas: Mostrando detalle de venta, index:", index)
        console.log("🔍 Ventas: Tipo de index:", typeof index)
        
        if (!ventaModel) {
            console.log("❌ VentaModel no disponible")
            return
        }
        
        var ventasArray = ventaModel.ventas_hoy || []
        console.log("🔍 DEBUG: ventasArray:", JSON.stringify(ventasArray))
        console.log("🔍 DEBUG: ventasArray.length:", ventasArray.length)
        console.log("🔍 DEBUG: Tipo de ventasArray:", typeof ventasArray)
        
        // Validar índice
        if (typeof index !== 'number' || index < 0 || index >= ventasArray.length) {
            console.log("❌ Índice inválido:", index, "Array length:", ventasArray.length)
            return
        }
        
        try {
            ventaSeleccionada = ventasArray[index]
            console.log("🔍 DEBUG: Venta seleccionada:", JSON.stringify(ventaSeleccionada))
            console.log("🔍 DEBUG: Tipo de ventaSeleccionada:", typeof ventaSeleccionada)
            
            // Validar que la venta seleccionada es un objeto válido
            if (!ventaSeleccionada || typeof ventaSeleccionada !== 'object') {
                console.log("❌ Venta seleccionada no es válida:", typeof ventaSeleccionada)
                return
            }
            
            // Validar que tiene ID
            var ventaId = ventaSeleccionada.id || ventaSeleccionada.idVenta
            if (!ventaId) {
                console.log("❌ Venta sin ID válido:", ventaSeleccionada)
                return
            }
            
            // Limpiar modelo de detalles
            productosDetalleModel.clear()
            
            // Obtener detalles reales desde VentaModel
            console.log("📋 Obteniendo detalles de venta ID:", ventaId)
            console.log("📋 Tipo de ventaId:", typeof ventaId)
            
            var detalleVenta = ventaModel.obtener_detalle_venta(parseInt(ventaId))
            
            console.log("📦 Detalle de venta obtenido:", JSON.stringify(detalleVenta))
            console.log("📦 Tipo de detalleVenta:", typeof detalleVenta)
            
            // Validar respuesta del modelo
            if (!detalleVenta || typeof detalleVenta !== 'object') {
                console.log("❌ Detalle de venta no válido:", typeof detalleVenta)
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
            
            // Verificar si hay detalles de productos
            var detallesArray = detalleVenta.detalles || []
            console.log("📦 Detalles array:", JSON.stringify(detallesArray))
            console.log("📦 Tipo de detallesArray:", typeof detallesArray)
            console.log("📦 Longitud:", detallesArray.length)
            
            // ✅ CORRECCIÓN CRÍTICA: Arrays de Python en QML no siempre son Array.isArray() === true
            // Pero SÍ tienen la propiedad length y se pueden iterar
            if (detallesArray && typeof detallesArray === 'object' && detallesArray.length > 0) {
                console.log("✅ Procesando", detallesArray.length, "detalles válidos")
                
                for (var i = 0; i < detallesArray.length; i++) {
                    var detalle = detallesArray[i]
                    console.log("📦 Procesando detalle", i, ":", JSON.stringify(detalle))
                    
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
                        
                        console.log("✅ Detalle agregado:", detalle.codigo || detalle.Producto_Codigo)
                    } else {
                        console.log("⚠️ Detalle", i, "no es válido:", typeof detalle)
                    }
                }
            } else {
                console.log("📦 No hay detalles válidos - detallesArray:", detallesArray)
                console.log("📦 Tipo:", typeof detallesArray, "Length:", detallesArray ? detallesArray.length : "undefined")
                
                productosDetalleModel.append({
                    codigo: "---",
                    nombre: "No hay productos registrados",
                    precio: 0,
                    cantidad: 0,
                    subtotal: 0
                })
            }
            
            console.log("📋 Total items agregados al modelo:", productosDetalleModel.count)
            detalleVentaDialogOpen = true
            
        } catch (e) {
            console.log("❌ Error al mostrar detalle:", e.message)
            console.log("❌ Stack trace:", e.stack)
            
            // Mostrar modal con error
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
                    
                    // Efecto de hover opcional
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
                    
                    // Sombra sutil
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
                    console.log("🛒 Navegando a CrearVenta")
                    navegarACrearVenta() // Emitir señal para navegar
                }
                
                // Efecto hover
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

        // Filtros de período
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: marginSmall
            spacing: marginSmall
            
            Button {
                id: filtroTodos
                text: "Todos"
                
                property bool isSelected: filtroActual === "Todos"
                
                background: Rectangle {
                    color: parent.isSelected ? "#3498db" : (parent.pressed ? "#e3f2fd" : "transparent")
                    border.color: parent.isSelected ? "#3498db" : "#bdc3c7"
                    border.width: 1
                    radius: 20
                }
                
                contentItem: RowLayout {
                    spacing: marginTiny
                    
                    Label {
                        text: "📊"
                        font.pixelSize: fontSmall
                    }
                    
                    Label {
                        text: parent.parent.text
                        color: parent.parent.isSelected ? whiteColor : textColor
                        font.bold: parent.parent.isSelected
                        font.pixelSize: fontSmall
                    }
                    
                    Rectangle {
                        visible: parent.parent.isSelected
                        width: 20
                        height: 16
                        color: whiteColor
                        radius: 8
                        
                        Label {
                            anchors.centerIn: parent
                            text: ventaModel ? ventaModel.total_ventas_hoy.toString() : "0"
                            color: "#3498db"
                            font.bold: true
                            font.pixelSize: fontTiny
                        }
                    }
                }
                
                onClicked: {
                    filtroActual = "Todos"
                }
            }

            Item { Layout.fillWidth: true }
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
                                            console.log("👁️ Ver detalle de venta, index:", index)
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

    // MODAL DE DETALLE DE VENTA
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

    // Función para obtener total de ventas
    function getTotalVentasCount() {
        return ventaModel ? ventaModel.total_ventas_hoy : 0
    }

    Component.onCompleted: {
        console.log("=== MÓDULO DE VENTAS SIMPLIFICADO INICIALIZADO ===")
        
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
            // Forzar el foco de vuelta al padre y propagar el evento
            ventasMainRoot.forceActiveFocus()
            // También puedes emitir una señal si es necesario
        }
        
        // Asegurar que este elemento esté siempre al fondo en términos de foco
        z: -1
    }
}