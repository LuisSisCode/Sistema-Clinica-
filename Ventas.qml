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
    signal navegarAEditarVenta(int ventaId)

    property bool mostrandoMenuContextual: false
    property var ventaMenuContextual: null
    property var selectedSale: null
    property bool showDeleteConfirmDialog: false
    property var ventaToDelete: null
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

    // Propiedades de permisos de usuario
    property bool usuarioEsMedico: ventaModel ? ventaModel.mostrar_informacion_limitada : false
    property bool puedeVerTodasVentas: ventaModel ? ventaModel.puede_ver_todas_ventas : false

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
        function onOperacionExitosa() {
            // Actualizar propiedades de permisos cuando cambie el usuario
            usuarioEsMedico = Qt.binding(function() { return ventaModel ? ventaModel.mostrar_informacion_limitada : false })
            puedeVerTodasVentas = Qt.binding(function() { return ventaModel ? ventaModel.puede_ver_todas_ventas : false })
        }
    }

    // FUNCIÓN para actualizar paginación de ventas
    function actualizarPaginacionVentas() {
        if (!ventaModel) return
        
        var totalItems = ventaModel ? ventaModel.total_ventas_hoy : 0
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
                        // CORREGIDO: Extraer valores con prioridad correcta
                        var cantidad = parseFloat(detalle.Cantidad_Unitario || detalle.cantidad || 0)
                        var precio = parseFloat(detalle.Precio_Unitario || detalle.precio || 0)
                        var subtotalBD = parseFloat(detalle.Subtotal || detalle.subtotal || 0)
                        
                        // CORREGIDO: Usar subtotal de BD o calcular como fallback
                        var subtotalFinal = subtotalBD > 0 ? subtotalBD : (cantidad * precio)
                        
                        productosDetalleModel.append({
                            codigo: String(detalle.Producto_Codigo || detalle.codigo || "N/A"),
                            nombre: String(detalle.Producto_Nombre || detalle.nombre || "Producto desconocido"),
                            precio: precio,
                            cantidad: cantidad,
                            subtotal: subtotalFinal  // USAR SUBTOTAL CORRECTO
                        })
                        
                        console.log("Producto agregado:", {
                            codigo: detalle.Producto_Codigo || detalle.codigo,
                            cantidad: cantidad,
                            precio: precio,
                            subtotalBD: subtotalBD,
                            subtotalFinal: subtotalFinal
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
            console.log("Detalle de venta mostrado con", productosDetalleModel.count, "productos")
            
        } catch (e) {
            console.log("Error mostrando detalle:", e.message)
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
            
            // Botón de Nueva Venta - REEMPLAZADO CON RECTANGLE + MOUSEAREA
            Rectangle {
                id: nuevaVentaButton
                Layout.preferredWidth: 230
                Layout.preferredHeight: 75
                color: mouseArea.pressed ? Qt.darker(successColor, 1.2) : successColor
                radius: radiusMedium
                
                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 2
                    color: "#00000020"
                    radius: radiusMedium
                    z: -1
                }
                
                RowLayout {
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
                
                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: parent.scale = 1.02
                    onExited: parent.scale = 1.0
                    onClicked: navegarACrearVenta()
                }
                
                Behavior on scale {
                    NumberAnimation { duration: 100 }
                }
                
                Behavior on color {
                    ColorAnimation { duration: 150 }
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
                                color: {
                                    if (selectedSale && selectedSale.idVenta === model.idVenta) {
                                        return "#E3F2FD"  // Azul claro para fila seleccionada
                                    } else if (ventasTable.currentIndex === index) {
                                        return "#F5F5F5"  // Gris muy claro para hover
                                    } else {
                                        return "transparent"
                                    }
                                }
                                opacity: selectedSale && selectedSale.idVenta === model.idVenta ? 0.8 : 0.4
                                
                                // Animación suave al cambiar color
                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                                
                                Behavior on opacity {
                                    NumberAnimation { duration: 150 }
                                }
                            }
            
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.color: selectedSale && selectedSale.idVenta === model.idVenta ? "#2196F3" : "transparent"
                                border.width: selectedSale && selectedSale.idVenta === model.idVenta ? 2 : 0
                                radius: 0
                                
                                Behavior on border.color {
                                    ColorAnimation { duration: 150 }
                                }
                                
                                Behavior on border.width {
                                    NumberAnimation { duration: 150 }
                                }
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
                                    
                                    // REEMPLAZADO CON RECTANGLE + MOUSEAREA
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 70
                                        height: 30
                                        color: blueColor
                                        radius: 15
                                        
                                        Label {
                                            anchors.centerIn: parent
                                            text: "Ver"
                                            color: whiteColor
                                            font.bold: true
                                            font.pixelSize: fontSmall
                                        }
                                        
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: mostrarDetalleVenta(index)
                                        }
                                    }
                                }
                            }
                            
                            MouseArea {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                anchors.rightMargin: 100  // Mantener margen para botón Ver
                                
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                z: -1
                                
                                onClicked: function(mouse) {
                                    if (mouse.button === Qt.LeftButton) {
                                        // Clic izquierdo: seleccionar fila
                                        ventasTable.currentIndex = index
                                        selectedSale = model
                                        // Ocultar menú contextual si estaba visible
                                        mostrandoMenuContextual = false
                                        ventaMenuContextual = null
                                    } else if (mouse.button === Qt.RightButton) {
                                        // Clic derecho: mostrar menú contextual solo si la fila está seleccionada
                                        if (selectedSale && selectedSale.idVenta === model.idVenta) {
                                            mostrandoMenuContextual = true
                                            ventaMenuContextual = model
                                        }
                                    }
                                }
                            }
                            // Menú contextual superpuesto
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                visible: mostrandoMenuContextual && ventaMenuContextual && ventaMenuContextual.idVenta === model.idVenta
                                z: 10
                                
                                // Cuadro contenedor estilo menú contextual
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 120
                                    height: 50
                                    color: "#F8F9FA"
                                    border.width: 0
                                    radius: 4
                                    
                                    // Sombra sutil
                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.topMargin: 2
                                        anchors.leftMargin: 2
                                        color: "#00000015"
                                        radius: 4
                                        z: -1
                                    }
                                    
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 0
                                        spacing: 0
                                        
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 25
                                            color: editarHover.containsMouse ? "#E3F2FD" : "transparent"
                                            radius: 0
                                            
                                            Label {
                                                anchors.centerIn: parent
                                                text: "Editar"
                                                color: editarHover.containsMouse ? "#1976D2" : "#2C3E50"
                                                font.pixelSize: 11
                                                font.weight: Font.Medium
                                            }
                                            
                                            MouseArea {
                                                id: editarHover
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: {
                                                    console.log("Editando venta:", model.idVenta)
                                                    editarVenta(model.idVenta)
                                                    mostrandoMenuContextual = false
                                                    ventaMenuContextual = null
                                                    selectedSale = null
                                                }
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 25
                                            color: eliminarHover.containsMouse ? "#FFEBEE" : "transparent"
                                            radius: 0
                                            
                                            Label {
                                                anchors.centerIn: parent
                                                text: "Eliminar"
                                                color: eliminarHover.containsMouse ? "#D32F2F" : "#2C3E50"
                                                font.pixelSize: 11
                                                font.weight: Font.Medium
                                            }
                                            
                                            MouseArea {
                                                id: eliminarHover
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: {
                                                    console.log("Eliminando venta:", model.idVenta)
                                                    confirmarEliminarVenta(model)
                                                    mostrandoMenuContextual = false
                                                    ventaMenuContextual = null
                                                    selectedSale = null
                                                }
                                            }
                                        }
                                    }
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
                        
                        // REEMPLAZADO CON RECTANGLE + MOUSEAREA
                        Rectangle {
                            id: btnAnterior
                            Layout.preferredWidth: 100
                            Layout.preferredHeight: 36
                            color: enabled ? (mouseAreaAnterior.pressed ? Qt.darker("#10B981", 1.1) : "#10B981") : "#E5E7EB"
                            radius: 18
                            enabled: currentPageVentas > 0
                            
                            Label {
                                text: "← Anterior"
                                color: parent.enabled ? "#FFFFFF" : "#9CA3AF"
                                font.bold: true
                                font.pixelSize: fontMedium
                                anchors.centerIn: parent
                            }
                            
                            MouseArea {
                                id: mouseAreaAnterior
                                anchors.fill: parent
                                enabled: parent.enabled
                                onClicked: {
                                    if (currentPageVentas > 0) {
                                        currentPageVentas--
                                        actualizarPaginacionVentas()
                                    }
                                }
                            }
                            
                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }
                        }

                        Label {
                            text: "Página " + (currentPageVentas + 1) + " de " + Math.max(1, totalPagesVentas)
                            color: "#374151"
                            font.pixelSize: fontMedium
                            font.weight: Font.Medium
                        }

                        // REEMPLAZADO CON RECTANGLE + MOUSEAREA
                        Rectangle {
                            id: btnSiguiente
                            Layout.preferredWidth: 110
                            Layout.preferredHeight: 36
                            color: enabled ? (mouseAreaSiguiente.pressed ? Qt.darker("#10B981", 1.1) : "#10B981") : "#E5E7EB"
                            radius: 18
                            enabled: currentPageVentas < totalPagesVentas - 1
                            
                            Label {
                                text: "Siguiente →"
                                color: parent.enabled ? "#FFFFFF" : "#9CA3AF"
                                font.bold: true
                                font.pixelSize: fontMedium
                                anchors.centerIn: parent
                            }
                            
                            MouseArea {
                                id: mouseAreaSiguiente
                                anchors.fill: parent
                                enabled: parent.enabled
                                onClicked: {
                                    if (currentPageVentas < totalPagesVentas - 1) {
                                        currentPageVentas++
                                        actualizarPaginacionVentas()
                                    }
                                }
                            }
                            
                            Behavior on color {
                                ColorAnimation { duration: 150 }
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
                        
                        // REEMPLAZADO CON RECTANGLE + MOUSEAREA
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
                                onClicked: detalleVentaDialogOpen = false
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
                            MouseArea {
                                anchors.fill: parent
                                visible: mostrandoMenuContextual
                                z: 5
                                onClicked: {
                                    mostrandoMenuContextual = false
                                    ventaMenuContextual = null
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
                            text: ventaSeleccionada ? "Bs " + parseFloat(ventaSeleccionada.total || 0).toFixed(2) : "Bs 0.00"
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
                
                // REEMPLAZADO CON RECTANGLE + MOUSEAREA
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
                        onClicked: detalleVentaDialogOpen = false
                    }
                }
            }
        }
    }
    function editarVenta(ventaId) {
        console.log("Editando venta ID:", ventaId)
        
        // Verificar permisos antes de editar
        if (!ventaModel.puede_editar_ventas) {
            mostrarMensajeError("No tiene permisos para editar ventas")
            return
        }
        
        navegarAEditarVenta(parseInt(ventaId))
    }

    function confirmarEliminarVenta(venta) {
        console.log("🗑️ Confirmando eliminación de venta:", venta.idVenta)
        
        // ✅ VERIFICAR PERMISOS SOLO PARA ADMIN
        
        // Establecer venta a eliminar y mostrar diálogo
        ventaToDelete = venta
        showDeleteConfirmDialog = true
        console.log("✅ Diálogo de confirmación mostrado")
    }

    function eliminarVentaConfirmada() {
        if (!ventaModel || !ventaToDelete) return
        
        var ventaId = parseInt(ventaToDelete.idVenta)
        var exito = ventaModel.eliminar_venta(ventaId)
        
        if (exito) {
            // AGREGAR: Actualización inmediata después de eliminar
            Qt.callLater(function() {
                actualizarPaginacionVentas()
                ventaModel.refresh_ventas_hoy()
                ventaModel.refresh_estadisticas()
            })
        }
        
        showDeleteConfirmDialog = false
        ventaToDelete = null
    }

    Component.onCompleted: {
        console.log("=== MODULO DE VENTAS CON FILTROS INICIALIZADO ===")
        
        if (!ventaModel || !inventarioModel || !compraModel) {
            console.log("❌ ERROR: Models no están disponibles")
            return
        }
        console.log("✅ Models conectados correctamente")
        console.log("🔐 Usuario es médico:", usuarioEsMedico)
        console.log("👁️ Puede ver todas las ventas:", puedeVerTodasVentas)
        actualizarPaginacionVentas()
        console.log("=== MÓDULO LISTO ===")
    }
    
    Item {
        anchors.fill: parent
        focus: true
        
        Keys.onEscapePressed: {
            console.log("Escape pressed in Ventas.qml")
            ventasRoot.forceActiveFocus()
        }
        
        z: -1
    }
    // Modal de confirmación para eliminar venta
    Rectangle {
        id: deleteConfirmOverlay
        anchors.fill: parent
        color: "#000000"
        opacity: 0.7
        visible: showDeleteConfirmDialog
        z: 3000
        
        MouseArea {
            anchors.fill: parent
            onClicked: {
                showDeleteConfirmDialog = false
                ventaToDelete = null
            }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 400
        height: 220
        color: "#ffffff"
        radius: radiusLarge
        border.color: "#dee2e6"
        border.width: 1
        visible: showDeleteConfirmDialog
        z: 3001
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: marginLarge
            spacing: marginMedium
            
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8
                
                Text {
                    text: "⚠️"
                    font.pixelSize: fontLarge
                    color: dangerColor
                }
                
                Label {
                    text: "Confirmar Eliminación"
                    font.bold: true
                    font.pixelSize: fontLarge
                    color: dangerColor
                }
            }
            
            Label {
                text: ventaToDelete ? 
                    "¿Está seguro de eliminar la venta #" + ventaToDelete.idVenta + 
                    " por un total de Bs " + ventaToDelete.total.toFixed(2) + "?" : ""
                font.pixelSize: fontMedium
                color: textColor
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                Layout.maximumWidth: 350
            }
            
            Label {
                text: "Esta acción no se puede deshacer y restaurará el stock de los productos."
                font.pixelSize: fontSmall
                color: darkGrayColor
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                Layout.maximumWidth: 350
            }
            
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: marginMedium
                
                Rectangle {
                    width: 100
                    height: 40
                    color: cancelDeleteMouseArea.pressed ? "#6c757d" : "#495057"
                    radius: radiusMedium
                    
                    Label {
                        anchors.centerIn: parent
                        text: "Cancelar"
                        color: whiteColor
                        font.bold: true
                        font.pixelSize: fontMedium
                    }
                    
                    MouseArea {
                        id: cancelDeleteMouseArea
                        anchors.fill: parent
                        onClicked: {
                            showDeleteConfirmDialog = false
                            ventaToDelete = null
                        }
                    }
                }
                
                Rectangle {
                    width: 100
                    height: 40
                    color: confirmDeleteMouseArea.pressed ? "#C62828" : dangerColor
                    radius: radiusMedium
                    
                    Label {
                        anchors.centerIn: parent
                        text: "Eliminar"
                        color: whiteColor
                        font.bold: true
                        font.pixelSize: fontMedium
                    }
                    
                    MouseArea {
                        id: confirmDeleteMouseArea
                        anchors.fill: parent
                        onClicked: eliminarVentaConfirmada()
                    }
                }
            }
        }
    }

    // ✅ FUNCIÓN PARA MOSTRAR MENSAJES DE ERROR
    function mostrarMensajeError(mensaje) {
        console.log("⚠️ Error:", mensaje)
        
        // Crear y mostrar un toast temporal
        var toast = Qt.createQmlObject('
            import QtQuick 2.15
            import QtQuick.Controls 2.15
            Rectangle {
                id: errorToast
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.topMargin: 20
                z: 9999
                width: Math.min(400, parent.width - 40)
                height: 60
                color: "#f8d7da"
                border.color: "#f5c6cb"
                radius: 6
                
                Text {
                    anchors.centerIn: parent
                    text: "⚠️ " + "' + mensaje + '"
                    color: "#721c24"
                    font.pixelSize: 14
                    wrapMode: Text.WordWrap
                    width: parent.width - 20
                    horizontalAlignment: Text.AlignHCenter
                }
                
                Timer {
                    interval: 3000
                    running: true
                    onTriggered: errorToast.destroy()
                }
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: errorToast.destroy()
                }
            }
        ', ventasRoot, "errorToast")
    }

}