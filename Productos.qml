import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// Componente principal del módulo de Productos de Farmacia
Item {
    id: productosRoot
    
    // Referencia al módulo principal de farmacia
    property var farmaciaData: parent.farmaciaData
    
    // Propiedades de colores heredadas del tema principal
    readonly property color primaryColor: "#273746"
    readonly property color primaryDarkColor: "#34495E"
    readonly property color successColor: "#27ae60"
    readonly property color dangerColor: "#E74C3C"
    readonly property color warningColor: "#f39c12"
    readonly property color lightGrayColor: "#ECF0F1"
    readonly property color darkGrayColor: "#7f8c8d"
    readonly property color textColor: "#2c3e50"
    readonly property color whiteColor: "#FFFFFF"
    readonly property color blueColor: "#3498db"
    
    // Estados de los diálogos y funcionalidades
    property bool editarPrecioDialogOpen: false
    property bool agregarProductoDialogOpen: false
    property bool verDetallesDialogOpen: false
    property var productoSeleccionado: null
    property int currentFilter: 0 // 0=Todos, 1=Vigentes, 2=Próx.Vencer, 3=Vencidos, 4=BajoStock
    property string searchText: ""
    property var productosOriginales: []
    property var fechaActual: new Date()
    
    // Propiedades de paginación
    property int itemsPerPage: 10
    property int currentPage: 0
    property int totalPages: 0
    property var allFilteredProducts: []

    // Función para cargar productos desde el centro de datos
    function cargarProductosDesdeCentro() {
        console.log("📦 Productos: Cargando desde centro de datos...")
        
        if (!farmaciaData) {
            console.log("❌ farmaciaData no disponible")
            return
        }
        
        var productos = farmaciaData.obtenerProductosParaInventario()
        
        // Limpiar modelo actual
        productosFilteredModel.clear()
        
        // Cargar productos desde el centro
        for (var i = 0; i < productos.length; i++) {
            productosFilteredModel.append(productos[i])
        }
        
        console.log("✅ Productos cargados desde centro:", productos.length)
    }

    // Función para actualizar datos cuando el centro cambie
    function actualizarDesdeDataCentral() {
        // Obtener productos actualizados del centro
        var productos = farmaciaData ? farmaciaData.obtenerProductosParaInventario() : []
        
        // Actualizar productosOriginales
        productosOriginales = []
        for (var i = 0; i < productos.length; i++) {
            productosOriginales.push(productos[i])
        }
        
        // Aplicar filtros con los nuevos datos
        updateFilteredModel()
        
        console.log("🔄 Productos actualizados desde centro de datos")
    }    
    
    // Modelo que se sincroniza con datos centrales
    ListModel {
        id: productosFilteredModel
    }
    
    // Modelo de lotes para cada producto
    ListModel {
        id: lotesModel
        
        // Datos de ejemplo de lotes
        Component.onCompleted: {
            // Lotes para Paracetamol 500mg (ID: 1)
            append({
                idProducto: 1,
                lote: "L-001",
                fechaVencimiento: "2025-07-04",
                stock: 0,
                estado: "Agotado"
            })
            append({
                idProducto: 1,
                lote: "L-002", 
                fechaVencimiento: "2025-07-10",
                stock: 80,
                estado: "Disponible"
            })
            append({
                idProducto: 1,
                lote: "L-003",
                fechaVencimiento: "2025-07-15", 
                stock: 50,
                estado: "Disponible"
            })
            
            // Lotes para Amoxicilina 500mg (ID: 2)
            append({
                idProducto: 2,
                lote: "L-004",
                fechaVencimiento: "2025-08-01",
                stock: 40,
                estado: "Disponible"
            })
            
            // Lotes para Ibuprofeno 400mg (ID: 3)
            append({
                idProducto: 3,
                lote: "L-005",
                fechaVencimiento: "2025-09-15",
                stock: 120,
                estado: "Disponible"
            })
        }
    }

    // Modelo filtrado para mostrar lotes del producto seleccionado
    ListModel {
        id: lotesFiltradosModel
    }
    // CONEXIÓN CON DATOS CENTRALES: Escuchar cambios
    Connections {
        target: farmaciaData
        function onDatosActualizados() {
            console.log("📦 Productos: Señal datosActualizados() recibida")
            actualizarDesdeDataCentral()
        }
    }

    // AGREGAR ESTE MODELO NUEVO
    ListModel {
        id: productosPaginadosModel
    }

    // Layout principal del módulo de productos
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 24
        
        // Header del módulo con título y información
        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            
            // Información del módulo
            RowLayout {
                spacing: 12
                
                Label {
                    text: "📦"
                    font.pixelSize: 32
                    color: primaryColor
                }
                
                ColumnLayout {
                    spacing: 4
                    
                    Label {
                        text: "Módulo de Farmacia"
                        font.pixelSize: 24
                        font.bold: true
                        color: textColor
                    }
                    
                    Label {
                        text: "Inventario de Productos"
                        font.pixelSize: 16
                        color: darkGrayColor
                    }
                }
            }
            
            Item { Layout.fillWidth: true }
            
            // Botón Añadir Producto
            Button {
                text: "➕ Añadir Producto"
                
                background: Rectangle {
                    color: parent.pressed ? Qt.darker(successColor, 1.2) : successColor
                    radius: 8
                    
                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                }
                
                contentItem: Label {
                    text: parent.text
                    color: whiteColor
                    font.bold: true
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: {
                    agregarProductoDialogOpen = true
                }
            }
            
            // Información en tiempo real
            Rectangle {
                Layout.preferredWidth: 150
                Layout.preferredHeight: 60
                color: "#E3F2FD"
                radius: 8
                border.color: blueColor
                border.width: 1
                
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    
                    Label {
                        text: "Total Productos:"
                        font.pixelSize: 12
                        color: darkGrayColor
                        Layout.alignment: Qt.AlignHCenter
                    }
                    
                    Label {
                        text: getTotalCount().toString()
                        font.pixelSize: 20
                        font.bold: true
                        color: blueColor
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }
        
        // Sección de filtros y búsqueda
        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            
            // Filtros de estado de productos
            RowLayout {
                spacing: 8
                
                FilterButton {
                    text: "Todos"
                    count: getTotalCount()
                    active: currentFilter === 0
                    backgroundColor: blueColor
                    onClicked: {
                        currentFilter = 0
                        updateFilteredModel()
                    }
                }
                FilterButton {
                    text: "Próx. Vencer"
                    count: getProximosVencerCount()
                    active: currentFilter === 1
                    backgroundColor: warningColor
                    onClicked: {
                        currentFilter = 1
                        updateFilteredModel()
                    }
                }
                
                FilterButton {
                    text: "Vencidos"
                    count: getVencidosCount()
                    active: currentFilter === 2
                    backgroundColor: dangerColor
                    onClicked: {
                        currentFilter = 2
                        updateFilteredModel()
                    }
                }
                
                FilterButton {
                    text: "Bajo Stock"
                    count: getBajoStockCount()
                    active: currentFilter === 3
                    backgroundColor: "#8e44ad"
                    onClicked: {
                        currentFilter = 3
                        updateFilteredModel()
                    }
                }
            }
            
            Item { Layout.fillWidth: true }
            
            // Campo de búsqueda
            RowLayout {
                spacing: 12
                
                Rectangle {
                    Layout.preferredWidth: 300
                    Layout.preferredHeight: 40
                    color: whiteColor
                    border.color: lightGrayColor
                    border.width: 2
                    radius: 8
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8
                        
                        Label {
                            text: "🔍"
                            font.pixelSize: 16
                            color: darkGrayColor
                        }
                        
                        TextField {
                            id: searchField
                            Layout.fillWidth: true
                            placeholderText: "Buscar por nombre o código..."
                            font.pixelSize: 14
                            color: textColor
                            
                            background: Rectangle {
                                color: "transparent"
                            }
                            
                            onTextChanged: {
                                searchText = text
                                updateFilteredModel()
                            }
                        }
                        
                        Button {
                            visible: searchField.text.length > 0
                            text: "✕"
                            
                            background: Rectangle {
                                color: parent.pressed ? Qt.darker(lightGrayColor, 1.2) : lightGrayColor
                                radius: 4
                                width: 24
                                height: 24
                            }
                            
                            contentItem: Label {
                                text: parent.text
                                color: darkGrayColor
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: {
                                searchField.text = ""
                                searchText = ""
                                updateFilteredModel()
                            }
                        }
                    }
                }
                
                Button {
                    text: "🔄 Actualizar"
                    
                    background: Rectangle {
                        color: parent.pressed ? Qt.darker(blueColor, 1.2) : blueColor
                        radius: 8
                        
                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        color: whiteColor
                        font.bold: true
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        updateFilteredModel()
                        console.log("📦 Productos actualizados manualmente")
                    }
                }
            }
        }
        
        // Tabla principal de productos mejorada
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#FFFFFF"
            border.color: "#D5DBDB"
            border.width: 1
            radius: 8
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 0
                spacing: 0
                
                // Header de la tabla
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50
                    color: "#F8F9FA"
                    border.color: "#D5DBDB"
                    border.width: 1
                    
                    RowLayout {
                        anchors.fill: parent
                        spacing: 0
                        
                        // Header ID
                        Rectangle {
                            Layout.preferredWidth: 60
                            Layout.fillHeight: true
                            color: "transparent"
                            border.color: "#D5DBDB"
                            border.width: 1
                            
                            Label {
                                anchors.centerIn: parent
                                text: "ID"
                                color: "#2C3E50"
                                font.bold: true
                                font.pixelSize: 12
                            }
                        }
                        
                        // Header CÓDIGO
                        Rectangle {
                            Layout.preferredWidth: 90
                            Layout.fillHeight: true
                            color: "transparent"
                            border.color: "#D5DBDB"
                            border.width: 1
                            
                            Label {
                                anchors.centerIn: parent
                                text: "CÓDIGO"
                                color: "#2C3E50"
                                font.bold: true
                                font.pixelSize: 12
                            }
                        }
                      
                        // Header NOMBRE
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 250
                            Layout.fillHeight: true
                            color: "transparent"
                            border.color: "#D5DBDB"
                            border.width: 1
                            
                            Label {
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: "NOMBRE"
                                color: "#2C3E50"
                                font.bold: true
                                font.pixelSize: 12
                            }
                        }
                       
                        // Header DETALLES
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 250
                            Layout.fillHeight: true
                            color: "transparent"
                            border.color: "#D5DBDB"
                            border.width: 1
                            
                            Label {
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: "DETALLES"
                                color: "#2C3E50"
                                font.bold: true
                                font.pixelSize: 12
                            }
                        }
                        
                        // Header PRECIO COMPRA
                        Rectangle {
                            Layout.preferredWidth: 110
                            Layout.fillHeight: true
                            color: "transparent"
                            border.color: "#D5DBDB"
                            border.width: 1
                            
                            Label {
                                anchors.centerIn: parent
                                text: "PRECIO COMPRA"
                                color: "#2C3E50"
                                font.bold: true
                                font.pixelSize: 12
                            }
                        }
                        
                        // Header PRECIO VENTA
                        Rectangle {
                            Layout.preferredWidth: 110
                            Layout.fillHeight: true
                            color: "transparent"
                            border.color: "#D5DBDB"
                            border.width: 1
                            
                            Label {
                                anchors.centerIn: parent
                                text: "PRECIO VENTA"
                                color: "#2C3E50"
                                font.bold: true
                                font.pixelSize: 12
                            }
                        }
                        
                        // Header STOCK CAJA
                        Rectangle {
                            Layout.preferredWidth: 90
                            Layout.fillHeight: true
                            color: "transparent"
                            border.color: "#D5DBDB"
                            border.width: 1
                            
                            Label {
                                anchors.centerIn: parent
                                text: "STOCK CAJA"
                                color: "#2C3E50"
                                font.bold: true
                                font.pixelSize: 12
                            }
                        }
                        
                        // Header STOCK UNITARIO
                        Rectangle {
                            Layout.preferredWidth: 100
                            Layout.fillHeight: true
                            color: "transparent"
                            border.color: "#D5DBDB"
                            border.width: 1
                            
                            Label {
                                anchors.centerIn: parent
                                text: "STOCK UNITARIO"
                                color: "#2C3E50"
                                font.bold: true
                                font.pixelSize: 12
                            }
                        }
                        
                        // Header UNIDAD MEDIDA
                        Rectangle {
                            Layout.preferredWidth: 100
                            Layout.fillHeight: true
                            color: "transparent"
                            border.color: "#D5DBDB"
                            border.width: 1
                            
                            Label {
                                anchors.centerIn: parent
                                text: "UNIDAD"
                                color: "#2C3E50"
                                font.bold: true
                                font.pixelSize: 12
                            }
                        }
                        
                        // Header ID MARCA
                        Rectangle {
                            Layout.preferredWidth: 90
                            Layout.fillHeight: true
                            color: "transparent"
                            border.color: "#D5DBDB"
                            border.width: 1
                            
                            Label {
                                anchors.centerIn: parent
                                text: "MARCA"
                                color: "#2C3E50"
                                font.bold: true
                                font.pixelSize: 12
                            }
                        }

                        // Header ACCIÓN
                        Rectangle {
                            Layout.preferredWidth: 120
                            Layout.fillHeight: true
                            color: "transparent"
                            border.color: "#D5DBDB"
                            border.width: 1
                            
                            Label {
                                anchors.centerIn: parent
                                text: "ACCIÓN"
                                color: "#2C3E50"
                                font.bold: true
                                font.pixelSize: 12
                            }
                        }
                    }
                }
                
                // Contenido de la tabla
                ListView {
                    id: productosTable
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: productosPaginadosModel
                    clip: true
                    
                    delegate: Rectangle {
                        width: productosTable.width
                        height: 60
                        color: productosTable.currentIndex === index ? "#E3F2FD" : "#FFFFFF"
                        border.color: "#D5DBDB"
                        border.width: 1
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 0
                            spacing: 0
                            
                            // ID
                            Rectangle {
                                Layout.preferredWidth: 60
                                Layout.fillHeight: true
                                color: "transparent"
                                border.color: "#D5DBDB"
                                border.width: 1
                                
                                Label {
                                    anchors.centerIn: parent
                                    text: model.id ? model.id.toString() : ""
                                    color: "#2C3E50"
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                            }
                            
                            // CÓDIGO
                            Rectangle {
                                Layout.preferredWidth: 90
                                Layout.fillHeight: true
                                color: "transparent"
                                border.color: "#D5DBDB"
                                border.width: 1
                                
                                Label {
                                    anchors.centerIn: parent
                                    text: model.codigo || ""
                                    color: "#3498DB"
                                    font.bold: true
                                    font.pixelSize: 12
                                }
                            }
                            
                            // NOMBRE
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 250
                                Layout.fillHeight: true
                                color: "transparent"
                                border.color: "#D5DBDB"
                                border.width: 1
                                
                                Label {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    anchors.right: parent.right
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: model.nombre || ""
                                    color: "#2C3E50"
                                    font.bold: true
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                            }
                            
                            // DETALLES
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 250
                                Layout.fillHeight: true
                                color: "transparent"
                                border.color: "#D5DBDB"
                                border.width: 1
                                
                                Label {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    anchors.right: parent.right
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: model.detalles || ""
                                    color: "#7f8c8d"
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                            }
                            
                            // PRECIO COMPRA
                            Rectangle {
                                Layout.preferredWidth: 110
                                Layout.fillHeight: true
                                color: "transparent"
                                border.color: "#D5DBDB"
                                border.width: 1
                                
                                Label {
                                    anchors.centerIn: parent
                                    text: "Bs" + (model.precioCompra ? model.precioCompra.toFixed(2) : "0.00")
                                    color: "#27AE60"
                                    font.bold: true
                                    font.pixelSize: 12
                                }
                            }
                            
                            // PRECIO VENTA
                            Rectangle {
                                Layout.preferredWidth: 110
                                Layout.fillHeight: true
                                color: "transparent"
                                border.color: "#D5DBDB"
                                border.width: 1
                                
                                Label {
                                    anchors.centerIn: parent
                                    text: "Bs" + (model.precioVenta ? model.precioVenta.toFixed(2) : "0.00")
                                    color: "#F39C12"
                                    font.bold: true
                                    font.pixelSize: 12
                                }
                            }
                            
                            // STOCK CAJA
                            Rectangle {
                                Layout.preferredWidth: 90
                                Layout.fillHeight: true
                                color: "transparent"
                                border.color: "#D5DBDB"
                                border.width: 1
                                
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 40
                                    height: 20
                                    color: getStockColor(model.stockUnitario || 0)
                                    radius: 10
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: (model.stockCaja || 0).toString()
                                        color: "#FFFFFF"
                                        font.bold: true
                                        font.pixelSize: 12
                                    }
                                }
                            }
                            
                            // STOCK UNITARIO
                            Rectangle {
                                Layout.preferredWidth: 100
                                Layout.fillHeight: true
                                color: "transparent"
                                border.color: "#D5DBDB"
                                border.width: 1
                                
                                Label {
                                    anchors.centerIn: parent
                                    text: (model.stockUnitario || 0).toString()
                                    color: "#2C3E50"
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                            }
                            
                            // UNIDAD MEDIDA
                            Rectangle {
                                Layout.preferredWidth: 100
                                Layout.fillHeight: true
                                color: "transparent"
                                border.color: "#D5DBDB"
                                border.width: 1
                                
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 60
                                    height: 18
                                    color: "#9b59b6"
                                    radius: 9
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: model.unidadMedida || "mg"
                                        color: "#FFFFFF"
                                        font.bold: true
                                        font.pixelSize: 8
                                    }
                                }
                            }
                            
                            // ID MARCA
                            Rectangle {
                                Layout.preferredWidth: 90
                                Layout.fillHeight: true
                                color: "transparent"
                                border.color: "#D5DBDB"
                                border.width: 1
                                
                                Label {
                                    anchors.centerIn: parent
                                    text: model.idMarca || "N/A"
                                    color: "#34495e"
                                    font.bold: true
                                    font.pixelSize: 12
                                }
                            }

                            // ACCIÓN
                            Rectangle {
                                Layout.preferredWidth: 120
                                Layout.fillHeight: true
                                color: "transparent"
                                border.color: "#D5DBDB"
                                border.width: 1
                                
                                Button {
                                    anchors.centerIn: parent
                                    width: 100
                                    height: 32
                                    text: "Ver Detalles"
                                    
                                    background: Rectangle {
                                        color: parent.pressed ? Qt.darker(blueColor, 1.2) : blueColor
                                        radius: 6
                                        
                                        Behavior on color {
                                            ColorAnimation { duration: 150 }
                                        }
                                    }
                                    
                                    contentItem: Label {
                                        text: parent.text
                                        color: whiteColor
                                        font.bold: true
                                        font.pixelSize: 12
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    
                                    onClicked: {
                                        productoSeleccionado = model
                                        verDetallesDialogOpen = true
                                    }
                                }
                            }
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            z: -1  // Para que el botón tenga prioridad
                            
                            onClicked: {
                                productosTable.currentIndex = index
                            }
                            
                            onPressed: {
                                if (mouse.button === Qt.RightButton) {
                                    productosTable.currentIndex = index
                                    contextMenu.popup()
                                }
                            }
                        }
                        
                        // Menú contextual
                        Menu {
                            id: contextMenu
                            
                            MenuItem {
                                text: "✏️ Editar Precio venta"
                                onTriggered: {
                                    productoSeleccionado = model
                                    editarPrecioDialogOpen = true
                                }
                            }
                            
                            MenuItem {
                                text: "🗑️ Eliminar Producto"
                                enabled: (model.stockUnitario || 0) === 0
                                onTriggered: {
                                    eliminarProducto(model)
                                }
                            }
                        }
                    }
                    
                    // Estado vacío mejorado
                    Item {
                        anchors.centerIn: parent
                        visible: productosFilteredModel.count === 0
                        width: 300
                        height: 200
                        
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 16
                            
                            Label {
                                text: searchText.length > 0 ? "🔍" : "📦"
                                font.pixelSize: 48
                                color: lightGrayColor
                                Layout.alignment: Qt.AlignHCenter
                            }
                            
                            Label {
                                text: searchText.length > 0 ? "No se encontraron productos" : "No hay productos en esta categoría"
                                color: darkGrayColor
                                font.pixelSize: 16
                                font.bold: true
                                Layout.alignment: Qt.AlignHCenter
                            }
                            
                            Label {
                                text: searchText.length > 0 ? 
                                      "Intenta con otro término de búsqueda" : 
                                      "Los productos aparecerán aquí cuando se registren compras"
                                color: darkGrayColor
                                font.pixelSize: 12
                                Layout.alignment: Qt.AlignHCenter
                                wrapMode: Text.WordWrap
                                Layout.maximumWidth: 250
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }
                }
                
                // Control de Paginación - Centrado con indicador
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
                            enabled: currentPage > 0
                            
                            background: Rectangle {
                                color: parent.enabled ? 
                                    (parent.pressed ? Qt.darker("#10B981", 1.1) : "#10B981") :   // ✅ VERDE
                                    "#E5E7EB"
                                radius: 18
                                
                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                            
                            contentItem: Label {
                                text: parent.text
                                color: parent.enabled ? "#FFFFFF" : "#9CA3AF"   // ✅ BLANCO cuando activo
                                font.bold: true
                                font.pixelSize: 14
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: {
                                if (currentPage > 0) {
                                    currentPage--
                                    updatePaginatedModel()
                                }
                            }
                        }
                        
                        // Indicador de página
                        Label {
                            text: "Página " + (currentPage + 1) + " de " + Math.max(1, totalPages)
                            color: "#374151"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }
                                                
                        // Botón Siguiente CORREGIDO
                        Button {
                            Layout.preferredWidth: 110
                            Layout.preferredHeight: 36
                            text: "Siguiente →"
                            enabled: currentPage < totalPages - 1  // ✅ CORREGIDO
                            
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
                                font.pixelSize: 14
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: {
                                if (currentPage < totalPages - 1) {  // ✅ CORREGIDO
                                    currentPage++
                                    updatePaginatedModel()  // ✅ CORREGIDO
                                }
                            }
                        }
                    }
                }
            }
        }

    }

    
    // Diálogo para Añadir Producto con diseño moderno
    Dialog {
        id: agregarProductoDialog
        anchors.centerIn: parent
        width: Math.min(450, parent.width * 0.85)
        height: Math.min(600, parent.height * 0.75)
        modal: true
        visible: agregarProductoDialogOpen 
        background: Rectangle {
            color: whiteColor
            radius: 8
            border.color: "#E5E7EB"
            border.width: 1
        } 
        onVisibleChanged: {
            if (!visible) {
                agregarProductoDialogOpen = false
                limpiarCampos()
            } else if (visible) {
                codigoField.focus = true
            }
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 0
            spacing: 0
            
            // Header compacto
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 55
                color: "#F8FAFC"
                radius: 8
                
                Rectangle {
                    anchors.fill: parent
                    anchors.bottomMargin: 8
                    color: parent.color
                    radius: parent.radius
                }
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12
                    
                    Rectangle {
                        width: 28
                        height: 28
                        color: successColor
                        radius: 6
                        
                        Label {
                            anchors.centerIn: parent
                            text: "+"
                            font.pixelSize: 16
                            font.bold: true
                            color: whiteColor
                        }
                    }
                    Label {
                        text: "Añadir Nuevo Producto"
                        font.pixelSize: 18
                        font.bold: true
                        color: textColor
                    }   
                    Item { Layout.fillWidth: true }
                    
                    Button {
                        width: 28
                        height: 28
                        
                        background: Rectangle {
                            color: parent.pressed ? "#F3F4F6" : "transparent"
                            radius: 6
                            border.color: parent.hovered ? "#E5E7EB" : "transparent"
                            border.width: 1
                        }
                        
                        contentItem: Label {
                            text: "×"
                            color: "#6B7280"
                            font.pixelSize: 16
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: {
                            agregarProductoDialogOpen = false
                        }
                    }
                }
            }  
            // Formulario compacto
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                
                ColumnLayout {
                    width: parent.width
                    spacing: 16
                    
                    // Información Básica
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.margins: 20
                        spacing: 12
                        
                        // Código y Nombre en una fila
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16
                            
                            // Código
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                
                                Label {
                                    text: "Código"
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: textColor
                                }
                                
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 36
                                    color: whiteColor
                                    border.color: codigoField.activeFocus ? "#3B82F6" : "#D1D5DB"
                                    border.width: codigoField.activeFocus ? 2 : 1
                                    radius: 6
                                    
                                    TextField {
                                        id: codigoField
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        placeholderText: "MED004"
                                        font.pixelSize: 13
                                        color: "#1F2937"
                                        selectByMouse: true
                                        verticalAlignment: TextInput.AlignVCenter
                                        
                                        background: Rectangle { color: "transparent" }
                                    }
                                }
                            }
                            
                            // Nombre
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 36
                                spacing: 6
                                
                                Label {
                                    text: "Nombre del Producto *"
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: textColor
                                }
                                
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 36
                                    color: whiteColor
                                    border.color: nombreField.activeFocus ? "#3B82F6" : "#D1D5DB"
                                    border.width: nombreField.activeFocus ? 2 : 1
                                    radius: 6
                                    
                                    TextField {
                                        id: nombreField
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        placeholderText: "Aspirina 500mg"
                                        font.pixelSize: 13
                                        color: "#1F2937"
                                        selectByMouse: true
                                        verticalAlignment: TextInput.AlignVCenter
                                        
                                        background: Rectangle { color: "transparent" }
                                    }
                                }
                            }
                        } 
                        // Detalles
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            
                            Label {
                                text: "Detalles"
                                font.pixelSize: 13
                                font.bold: true
                                color: textColor
                            }
                            
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 50
                                color: whiteColor
                                border.color: detallesField.activeFocus ? "#3B82F6" : "#D1D5DB"
                                border.width: detallesField.activeFocus ? 2 : 1
                                radius: 6
                                
                                ScrollView {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    
                                    TextArea {
                                        id: detallesField
                                        placeholderText: "Descripción del producto..."
                                        font.pixelSize: 12
                                        color: "#1F2937"
                                        wrapMode: TextArea.Wrap
                                        selectByMouse: true
                                        
                                        background: Rectangle { color: "transparent" }
                                    }
                                }
                            }
                        }  
                        // Precios
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16
                            
                            // Precio Compra
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                
                                Label {
                                    text: "Precio Compra *"
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: textColor
                                }
                                
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 36
                                    color: whiteColor
                                    border.color: precioCompraField.activeFocus ? "#3B82F6" : "#D1D5DB"
                                    border.width: precioCompraField.activeFocus ? 2 : 1
                                    radius: 6
                                    
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 6
                                        
                                        Label {
                                            text: "Bs"
                                            font.pixelSize: 13
                                            font.bold: true
                                            color: textColor
                                        }
                                        
                                        TextField {
                                            id: precioCompraField
                                            Layout.fillWidth: true
                                            placeholderText: "0.00"
                                            font.pixelSize: 13
                                            color: "#1F2937"
                                            selectByMouse: true
                                            verticalAlignment: TextInput.AlignVCenter
                                            validator: DoubleValidator {
                                                bottom: 0.01
                                                decimals: 2
                                            }
                                            
                                            background: Rectangle { color: "transparent" }
                                        }
                                    }
                                }
                            } 
                            // Precio Venta
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                
                                Label {
                                    text: "Precio Venta"
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: textColor
                                }
                                
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 36
                                    color: whiteColor
                                    border.color: precioVentaField.activeFocus ? "#3B82F6" : "#D1D5DB"
                                    border.width: precioVentaField.activeFocus ? 2 : 1
                                    radius: 6
                                    
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 6
                                        
                                        Label {
                                            text: "Bs"
                                            font.pixelSize: 13
                                            font.bold: true
                                            color: textColor
                                        }
                                        
                                        TextField {
                                            id: precioVentaField
                                            Layout.fillWidth: true
                                            placeholderText: "0.00"
                                            font.pixelSize: 13
                                            color: "#1F2937"
                                            selectByMouse: true
                                            verticalAlignment: TextInput.AlignVCenter
                                            validator: DoubleValidator {
                                                bottom: 0.01
                                                decimals: 2
                                            }
                                            
                                            background: Rectangle { color: "transparent" }
                                        }
                                    }
                                }
                            }
                        }
                        // Stock
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16
                            
                            // Stock Cajas
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                
                                Label {
                                    text: "Stock Cajas"
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: textColor
                                }
                                
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 36
                                    color: whiteColor
                                    border.color: stockCajaField.activeFocus ? "#3B82F6" : "#D1D5DB"
                                    border.width: stockCajaField.activeFocus ? 2 : 1
                                    radius: 6
                                    
                                    TextField {
                                        id: stockCajaField
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        placeholderText: "0"
                                        font.pixelSize: 13
                                        color: "#1F2937"
                                        selectByMouse: true
                                        verticalAlignment: TextInput.AlignVCenter
                                        validator: IntValidator { bottom: 0 }
                                        
                                        background: Rectangle { color: "transparent" }
                                    }
                                }
                            }
                            // Stock Unitario
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                
                                Label {
                                    text: "Stock Unitario"
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: textColor
                                }
                                
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 36
                                    color: whiteColor
                                    border.color: stockUnitarioField.activeFocus ? "#3B82F6" : "#D1D5DB"
                                    border.width: stockUnitarioField.activeFocus ? 2 : 1
                                    radius: 6
                                    
                                    TextField {
                                        id: stockUnitarioField
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        placeholderText: "0"
                                        font.pixelSize: 13
                                        color: "#1F2937"
                                        selectByMouse: true
                                        verticalAlignment: TextInput.AlignVCenter
                                        validator: IntValidator { bottom: 0 }
                                        
                                        background: Rectangle { color: "transparent" }
                                    }
                                }
                            }
                        }
                        
                        // Clasificación
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16
                            
                            // Unidad de Medida
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                
                                Label {
                                    text: "Unidad"
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: textColor
                                }
                                
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 36
                                    color: whiteColor
                                    border.color: "#D1D5DB"
                                    border.width: 1
                                    radius: 6
                                    
                                    ComboBox {
                                        id: unidadMedidaCombo
                                        anchors.fill: parent
                                        anchors.margins: 1
                                        
                                        model: ["Tableta", "Cápsula", "ml", "mg", "g", "Ampolla", "Frasco", "Tubo", "Sobre"]
                                        
                                        background: Rectangle {
                                            color: whiteColor
                                            radius: 5
                                        }
                                        
                                        contentItem: Text {
                                            text: parent.displayText
                                            font.pixelSize: 13
                                            color: "#1F2937"
                                            verticalAlignment: Text.AlignVCenter
                                            leftPadding: 8
                                        }
                                        
                                        indicator: Label {
                                            anchors.right: parent.right
                                            anchors.rightMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "▼"
                                            font.pixelSize: 8
                                            color: "#6B7280"
                                        }
                                    }
                                }
                            }
                            
                            // Marca
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                
                                Label {
                                    text: "Marca"
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: textColor
                                }
                                
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 36
                                    color: whiteColor
                                    border.color: "#D1D5DB"
                                    border.width: 1
                                    radius: 6
                                    
                                    ComboBox {
                                        id: marcaCombo
                                        anchors.fill: parent
                                        anchors.margins: 1
                                        
                                        model: ["BAYER", "PFIZER", "ROCHE", "NOVARTIS", "SANOFI", "GSK", "MERCK", "ABBOTT", "JOHNSON & JOHNSON"]
                                        
                                        background: Rectangle {
                                            color: whiteColor
                                            radius: 5
                                        }
                                        contentItem: Text {
                                            text: parent.displayText
                                            font.pixelSize: 13
                                            color: "#1F2937"
                                            verticalAlignment: Text.AlignVCenter
                                            leftPadding: 8
                                        }
                                        indicator: Label {
                                            anchors.right: parent.right
                                            anchors.rightMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "▼"
                                            font.pixelSize: 8
                                            color: "#6B7280"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            // Footer compacto
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                color: "#F8FAFC"
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 10
                    
                    Item { Layout.fillWidth: true }
                    
                    Button {
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: 32
                        
                        background: Rectangle {
                            color: parent.pressed ? "#F3F4F6" : whiteColor
                            radius: 6
                            border.color: "#D1D5DB"
                            border.width: 1
                        }
                        contentItem: Label {
                            text: "Cancelar"
                            color: textColor
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: {
                            agregarProductoDialogOpen = false
                        }
                    }
                    
                    Button {
                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 32
                        enabled: codigoField.text.length > 0 && 
                                nombreField.text.length > 0 && 
                                precioCompraField.text.length > 0 && 
                                precioVentaField.text.length > 0 &&
                                stockCajaField.text.length > 0 &&
                                stockUnitarioField.text.length > 0
                        
                        background: Rectangle {
                            color: parent.enabled ? 
                                (parent.pressed ? Qt.darker(successColor, 1.1) : successColor) : 
                                "#D1D5DB"
                            radius: 6
                        }
                        
                        contentItem: Label {
                            text: "Guardar"
                            color: parent.parent.enabled ? whiteColor : "#9CA3AF"
                            font.pixelSize: 13
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: {
                            guardarNuevoProducto()
                        }
                    }
                }
            }
        }

        function limpiarCampos() {
            codigoField.text = ""
            nombreField.text = ""
            detallesField.text = ""
            precioCompraField.text = ""
            precioVentaField.text = ""
            stockCajaField.text = ""
            stockUnitarioField.text = ""
            unidadMedidaCombo.currentIndex = 0
            marcaCombo.currentIndex = 0
        }
    }
    // Función para guardar nuevo producto
    function guardarNuevoProducto() {
        // Validar campos obligatorios
        if (!codigoField.text || !nombreField.text || 
            !precioCompraField.text || !precioVentaField.text ||
            !stockCajaField.text || !stockUnitarioField.text) {
            console.log("❌ Campos obligatorios vacíos")
            return
        }
        
        // Validar precios
        var precioCompra = parseFloat(precioCompraField.text)
        var precioVenta = parseFloat(precioVentaField.text)
        var stockCaja = parseInt(stockCajaField.text)
        var stockUnitario = parseInt(stockUnitarioField.text)
        
        if (isNaN(precioCompra) || precioCompra <= 0 ||
            isNaN(precioVenta) || precioVenta <= 0 ||
            isNaN(stockCaja) || stockCaja < 0 ||
            isNaN(stockUnitario) || stockUnitario < 0) {
            console.log("❌ Valores numéricos inválidos")
            return
        }
        
        // Verificar que el código no exista
        for (var i = 0; i < productosFilteredModel.count; i++) {
            if (productosFilteredModel.get(i).codigo === codigoField.text) {
                console.log("❌ El código ya existe:", codigoField.text)
                return
            }
        }
        
        // Generar nuevo ID
        var nuevoId = productosFilteredModel.count + 1
        for (var j = 0; j < productosFilteredModel.count; j++) {
            if (productosFilteredModel.get(j).id >= nuevoId) {
                nuevoId = productosFilteredModel.get(j).id + 1
            }
        }
        
        // Crear nuevo producto
        var nuevoProducto = {
            id: nuevoId,
            codigo: codigoField.text,
            nombre: nombreField.text,
            detalles: detallesField.text || "Sin descripción",
            precioCompra: precioCompra,
            precioVenta: precioVenta,
            stockCaja: stockCaja,
            stockUnitario: stockUnitario,
            unidadMedida: unidadMedidaCombo.currentText,
            idMarca: marcaCombo.currentText
        }
        
        // Añadir al modelo filtrado Y a los datos originales
        productosFilteredModel.append(nuevoProducto)
        productosOriginales.push(nuevoProducto)  // ← ESTA LÍNEA ES CRUCIAL
        
        console.log("✅ Producto agregado exitosamente:", nuevoProducto.codigo, nuevoProducto.nombre)
        
        // Cerrar diálogo y limpiar campos
        agregarProductoDialogOpen = false
        limpiarCampos()
        
        // Actualizar vista SIN resetear página
        productosOriginales.push(nuevoProducto)
        productosFilteredModel.append(nuevoProducto)
        updatePaginatedModel()  
    }
    // Diálogo para Editar Precio de Venta
    Dialog {
        id: editarPrecioDialog
        anchors.centerIn: parent
        width: Math.min(500, parent.width * 0.8)
        height: Math.min(400, parent.height * 0.6)
        modal: true
        visible: editarPrecioDialogOpen
        
        background: Rectangle {
            color: whiteColor
            radius: 16
            border.color: lightGrayColor
            border.width: 1
        }
        
        onVisibleChanged: {
            if (!visible) {
                editarPrecioDialogOpen = false
            } else if (visible && productoSeleccionado) {
                precioVentaEditField.text = productoSeleccionado.precioVenta.toFixed(2)
                precioVentaEditField.selectAll()
                precioVentaEditField.focus = true
            }
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 20
            
            // Header del diálogo
            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                
                Label {
                    text: "💰"
                    font.pixelSize: 24
                    color: successColor
                }
                
                Label {
                    text: "Editar Precio de Venta"
                    font.pixelSize: 20
                    font.bold: true
                    color: textColor
                }
                
                Item { Layout.fillWidth: true }
                
                Button {
                    text: "✕"
                    
                    background: Rectangle {
                        color: parent.pressed ? Qt.darker(dangerColor, 1.2) : dangerColor
                        radius: 20
                        width: 40
                        height: 40
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        color: whiteColor
                        font.bold: true
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        editarPrecioDialogOpen = false
                    }
                }
            }
            
            // Información del producto
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 80
                color: "#F8F9FA"
                radius: 8
                border.color: lightGrayColor
                border.width: 1
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 8
                    
                    Label {
                        text: "Producto: " + (productoSeleccionado ? productoSeleccionado.nombre : "")
                        font.bold: true
                        font.pixelSize: 14
                        color: textColor
                    }
                    
                    Label {
                        text: "Código: " + (productoSeleccionado ? productoSeleccionado.codigo : "")
                        font.pixelSize: 12
                        color: darkGrayColor
                    }
                    
                    Label {
                        text: "Precio Compra: $" + (productoSeleccionado ? productoSeleccionado.precioCompra.toFixed(2) : "0.00")
                        font.pixelSize: 12
                        color: successColor
                    }
                }
            }
            
            // Campo para editar precio
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12
                
                Label {
                    text: "Nuevo Precio de Venta:"
                    font.bold: true
                    color: textColor
                }
                
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50
                    color: whiteColor
                    border.color: warningColor
                    border.width: 2
                    radius: 8
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8
                        
                        Label {
                            text: "$"
                            font.bold: true
                            font.pixelSize: 18
                            color: textColor
                        }
                        
                        TextField {
                            id: precioVentaEditField
                            Layout.fillWidth: true
                            font.pixelSize: 16
                            font.bold: true
                            color: textColor
                            placeholderText: "0.00"
                            validator: DoubleValidator {
                                bottom: 0.01
                                decimals: 2
                            }
                            
                            background: Rectangle {
                                color: "transparent"
                            }
                            
                            Keys.onReturnPressed: {
                                guardarPrecioVenta()
                            }
                        }
                    }
                }
            }
            
            Item { Layout.fillHeight: true }
            
            // Botones
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                
                Item { Layout.fillWidth: true }
                
                Button {
                    text: "Cancelar"
                    
                    background: Rectangle {
                        color: parent.pressed ? Qt.darker(darkGrayColor, 1.2) : darkGrayColor
                        radius: 8
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        color: whiteColor
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        editarPrecioDialogOpen = false
                    }
                }
                
                Button {
                    text: "Guardar"
                    enabled: precioVentaEditField.text.length > 0 && parseFloat(precioVentaEditField.text) > 0
                    
                    background: Rectangle {
                        color: parent.enabled ? (parent.pressed ? Qt.darker(warningColor, 1.2) : warningColor) : lightGrayColor
                        radius: 8
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        color: parent.parent.enabled ? whiteColor : darkGrayColor
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        guardarPrecioVenta()
                    }
                }
            }
        }
    }

    // Diálogo para Ver Detalles de Lotes
    Dialog {
        id: verDetallesDialog
        anchors.centerIn: parent
        width: Math.min(800, parent.width * 0.9)
        height: Math.min(600, parent.height * 0.8)
        modal: true
        visible: verDetallesDialogOpen
        
        background: Rectangle {
            color: whiteColor
            radius: 12
            border.color: "#E5E7EB"
            border.width: 1
        }
        
        onVisibleChanged: {
            if (!visible) {
                verDetallesDialogOpen = false
            } else if (visible && productoSeleccionado) {
                cargarLotesDelProducto()
            }
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 0
            spacing: 0
            
            // Header del diálogo
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 70
                color: "#F8FAFC"
                radius: 12
                
                Rectangle {
                    anchors.fill: parent
                    anchors.bottomMargin: 12
                    color: parent.color
                    radius: parent.radius
                }
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 16
                    
                    Rectangle {
                        width: 36
                        height: 36
                        color: blueColor
                        radius: 8
                        
                        Label {
                            anchors.centerIn: parent
                            text: "📦"
                            font.pixelSize: 16
                            color: whiteColor
                        }
                    }
                    
                    ColumnLayout {
                        spacing: 4
                        
                        Label {
                            text: "Detalles de Lotes"
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                            color: textColor
                        }
                        
                        Label {
                            text: productoSeleccionado ? productoSeleccionado.nombre : ""
                            font.pixelSize: 14
                            color: darkGrayColor
                        }
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    Button {
                        width: 36
                        height: 36
                        
                        background: Rectangle {
                            color: parent.pressed ? "#F3F4F6" : "transparent"
                            radius: 8
                            border.color: parent.hovered ? "#E5E7EB" : "transparent"
                            border.width: 1
                        }
                        
                        contentItem: Label {
                            text: "X"
                            color: "#6B7280"
                            font.pixelSize: 20
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: {
                            verDetallesDialogOpen = false
                        }
                    }
                }
            }
            
            // Información del producto
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 80
                Layout.margins: 24
                color: "#F8F9FA"
                radius: 8
                border.color: lightGrayColor
                border.width: 1
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 24
                    
                    ColumnLayout {
                        spacing: 4
                        
                        Label {
                            text: "Código: " + (productoSeleccionado ? productoSeleccionado.codigo : "")
                            font.bold: true
                            font.pixelSize: 12
                            color: blueColor
                        }
                        
                        Label {
                            text: "Stock Total: " + (productoSeleccionado ? productoSeleccionado.stockUnitario : 0)
                            font.pixelSize: 11
                            color: textColor
                        }
                    }
                    
                    ColumnLayout {
                        spacing: 4
                        
                        Label {
                            text: "Precio Venta: Bs" + (productoSeleccionado ? productoSeleccionado.precioVenta.toFixed(2) : "0.00")
                            font.bold: true
                            font.pixelSize: 12
                            color: successColor
                        }
                        
                        Label {
                            text: "Marca: " + (productoSeleccionado ? productoSeleccionado.idMarca : "")
                            font.pixelSize: 11
                            color: textColor
                        }
                    }
                }
            }
            
            // Tabla de lotes
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 24
                Layout.topMargin: 0
                color: whiteColor
                border.color: "#D5DBDB"
                border.width: 1
                radius: 8
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 0
                    spacing: 0
                    
                    // Header de la tabla de lotes
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 45
                        color: "#F8F9FA"
                        border.color: "#D5DBDB"
                        border.width: 1
                        
                        Row {
                            anchors.fill: parent
                            
                            Rectangle {
                                width: 145
                                height: parent.height
                                color: "transparent"
                                border.color: "#D5DBDB"
                                border.width: 1
                                
                                Label {
                                    anchors.centerIn: parent
                                    text: "LOTE"
                                    color: textColor
                                    font.bold: true
                                    font.pixelSize: 11
                                }
                            }
                            
                            Rectangle {
                                width: 250
                                height: parent.height
                                color: "transparent"
                                border.color: "#D5DBDB"
                                border.width: 1
                                
                                Label {
                                    anchors.centerIn: parent
                                    text: "FECHA VENCIMIENTO"
                                    color: textColor
                                    font.bold: true
                                    font.pixelSize: 11
                                }
                            }
                            
                            Rectangle {
                                width: 140
                                height: parent.height
                                color: "transparent"
                                border.color: "#D5DBDB"
                                border.width: 1
                                
                                Label {
                                    anchors.centerIn: parent
                                    text: "STOCK"
                                    color: textColor
                                    font.bold: true
                                    font.pixelSize: 11
                                }
                            }
                            
                            Rectangle {
                                width: 170
                                height: parent.height
                                color: "transparent"
                                border.color: "#D5DBDB"
                                border.width: 1
                                
                                Label {
                                    anchors.centerIn: parent
                                    text: "ESTADO"
                                    color: textColor
                                    font.bold: true
                                    font.pixelSize: 11
                                }
                            }
                        }
                    }
                    
                    // Lista de lotes
                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: lotesFiltradosModel
                        clip: true
                        
                        delegate: Rectangle {
                            width: parent.width
                            height: 50
                            color: index % 2 === 0 ? "#FFFFFF" : "#F8F9FA"
                            border.color: "#D5DBDB"
                            border.width: 1
                            
                            Row {
                                anchors.fill: parent
                                
                                Rectangle {
                                    width: 145
                                    height: parent.height
                                    color: "transparent"
                                    border.color: "#D5DBDB"
                                    border.width: 1
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: model.lote || ""
                                        color: blueColor
                                        font.bold: true
                                        font.pixelSize: 12
                                    }
                                }
                                
                                Rectangle {
                                    width: 250
                                    height: parent.height
                                    color: "transparent"
                                    border.color: "#D5DBDB"
                                    border.width: 1
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: model.fechaVencimiento || ""
                                        color: textColor
                                        font.pixelSize: 11
                                    }
                                }
                                
                                Rectangle {
                                    width: 140
                                    height: parent.height
                                    color: "transparent"
                                    border.color: "#D5DBDB"
                                    border.width: 1
                                    
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 50
                                        height: 25
                                        color: getEstadoColor(model.estado || "")
                                        radius: 12
                                        
                                        Label {
                                            anchors.centerIn: parent
                                            text: model.stock || 0
                                            color: whiteColor
                                            font.bold: true
                                            font.pixelSize: 11
                                        }
                                    }
                                }
                                
                                Rectangle {
                                    width: 170
                                    height: parent.height
                                    color: "transparent"
                                    border.color: "#D5DBDB"
                                    border.width: 1
                                    
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 80
                                        height: 25
                                        color: getEstadoColor(model.estado || "")
                                        radius: 12
                                        
                                        Label {
                                            anchors.centerIn: parent
                                            text: model.estado || ""
                                            color: whiteColor
                                            font.bold: true
                                            font.pixelSize: 12
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Estado vacío
                        Item {
                            anchors.centerIn: parent
                            visible: lotesFiltradosModel.count === 0
                            width: 200
                            height: 100
                            
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 12
                                
                                Label {
                                    text: "📦"
                                    font.pixelSize: 32
                                    color: lightGrayColor
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                
                                Label {
                                    text: "No hay lotes registrados"
                                    color: darkGrayColor
                                    font.pixelSize: 14
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }
                    }
                }
            }
        }
    }
   
    // Componente reutilizable para los botones de filtro
    component FilterButton: Rectangle {
        property string text: ""
        property int count: 0
        property bool active: false
        property color backgroundColor: blueColor
        signal clicked()
        
        Layout.preferredHeight: 36
        Layout.preferredWidth: implicitWidth + 20
        
        property int implicitWidth: textLabel.implicitWidth + countLabel.implicitWidth + 40
        
        color: active ? backgroundColor : "transparent"
        border.color: backgroundColor
        border.width: 2
        radius: 18
        
        Behavior on color {
            ColorAnimation { duration: 200 }
        }
        
        RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8
            
            Label {
                id: textLabel
                text: parent.parent.text
                color: active ? whiteColor : backgroundColor
                font.bold: true
                font.pixelSize: 13
                
                Behavior on color {
                    ColorAnimation { duration: 200 }
                }
            }
            
            Rectangle {
                id: countLabel
                Layout.preferredWidth: 24
                Layout.preferredHeight: 20
                color: active ? whiteColor : backgroundColor
                radius: 10
                
                Behavior on color {
                    ColorAnimation { duration: 200 }
                }
                
                Label {
                    anchors.centerIn: parent
                    text: parent.parent.parent.count.toString()
                    color: active ? backgroundColor : whiteColor
                    font.bold: true
                    font.pixelSize: 11
                    
                    Behavior on color {
                        ColorAnimation { duration: 200 }
                    }
                }
            }
        }
        
        MouseArea {
            anchors.fill: parent
            onClicked: parent.clicked()
        }
    }
    
    // ===== FUNCIONES PARA OBTENER CONTEOS =====
    
    function getTotalCount() {
        if (productosOriginales.length === 0) {
            return productosFilteredModel.count
        }
        return productosOriginales.length
    }
    
    function getVigentesCount() {
        var count = 0
        var productos = productosOriginales.length > 0 ? productosOriginales : []
        
        // Si no hay productos originales, usar el modelo actual
        if (productos.length === 0) {
            for (var i = 0; i < productosFilteredModel.count; i++) {
                productos.push(productosFilteredModel.get(i))
            }
        }
        
        for (var j = 0; j < productos.length; j++) {
            if (esVigente(productos[j])) {
                count++
            }
        }
        return count
    }
    
    function getProximosVencerCount() {
        var count = 0
        var productos = productosOriginales.length > 0 ? productosOriginales : []
        
        if (productos.length === 0) {
            for (var i = 0; i < productosFilteredModel.count; i++) {
                productos.push(productosFilteredModel.get(i))
            }
        }
        
        for (var j = 0; j < productos.length; j++) {
            if (esProximoVencer(productos[j])) {
                count++
            }
        }
        return count
    }
        
    function getVencidosCount() {
        var count = 0
        var productos = productosOriginales.length > 0 ? productosOriginales : []
        
        if (productos.length === 0) {
            for (var i = 0; i < productosFilteredModel.count; i++) {
                productos.push(productosFilteredModel.get(i))
            }
        }
        
        for (var j = 0; j < productos.length; j++) {
            if (esVencido(productos[j])) {
                count++
            }
        }
        return count
    }

    function getBajoStockCount() {
        var count = 0
        var productos = productosOriginales.length > 0 ? productosOriginales : []
        
        if (productos.length === 0) {
            for (var i = 0; i < productosFilteredModel.count; i++) {
                productos.push(productosFilteredModel.get(i))
            }
        }
        
        for (var j = 0; j < productos.length; j++) {
            if (esBajoStock(productos[j])) {
                count++
            }
        }
        return count
    }
  
    // ===== FUNCIONES DE PAGINACIÓN =====
    
    function updateFilteredModel() {
        console.log("📦 Actualizando modelo filtrado, filtro:", currentFilter, "búsqueda:", searchText)
        
        // Guardar datos originales si no existen
        if (productosOriginales.length === 0) {
            for (var i = 0; i < productosFilteredModel.count; i++) {
                productosOriginales.push({
                    id: productosFilteredModel.get(i).id,
                    codigo: productosFilteredModel.get(i).codigo,
                    nombre: productosFilteredModel.get(i).nombre,
                    detalles: productosFilteredModel.get(i).detalles,
                    precioCompra: productosFilteredModel.get(i).precioCompra,
                    precioVenta: productosFilteredModel.get(i).precioVenta,
                    stockCaja: productosFilteredModel.get(i).stockCaja,
                    stockUnitario: productosFilteredModel.get(i).stockUnitario,
                    unidadMedida: productosFilteredModel.get(i).unidadMedida,
                    idMarca: productosFilteredModel.get(i).idMarca
                })
            }
        }
        
        // Limpiar el modelo filtrado
        productosFilteredModel.clear()
        
        // Aplicar filtros
        var productosFiltrados = []
        
        for (var j = 0; j < productosOriginales.length; j++) {
            var producto = productosOriginales[j]
            var pasaFiltro = false
            
            // Aplicar filtro por categoría
            switch(currentFilter) {
                case 0: // Todos
                    pasaFiltro = true
                    break
                case 1: // Próximos a vencer
                    pasaFiltro = esProximoVencer(producto)
                    break
                case 2: // Vencidos
                    pasaFiltro = esVencido(producto)
                    break
                case 3: // Bajo Stock
                    pasaFiltro = esBajoStock(producto)
                    break
            }
            
            // Aplicar filtro de búsqueda si pasa el filtro de categoría
            if (pasaFiltro && searchText.length > 0) {
                var textoSearch = searchText.toLowerCase()
                var nombreMatch = producto.nombre.toLowerCase().includes(textoSearch)
                var codigoMatch = producto.codigo.toLowerCase().includes(textoSearch)
                pasaFiltro = nombreMatch || codigoMatch
            }
            
            if (pasaFiltro) {
                productosFiltrados.push(producto)
            }
        }
        
        // Agregar productos filtrados al modelo
        for (var k = 0; k < productosFiltrados.length; k++) {
            productosFilteredModel.append(productosFiltrados[k])
        }

        console.log("✅ Filtro aplicado. Productos mostrados:", productosFiltrados.length)
        
        // IMPORTANTE: Resetear a primera página y actualizar paginación
        currentPage = 0
        updatePaginatedModel()
    }

    function esVigente(producto) {
        // Un producto es vigente si tiene stock y no está próximo a vencer ni vencido
        return producto.stockUnitario > 15 && !esProximoVencer(producto) && !esVencido(producto)
    }

    function esProximoVencer(producto) {
        // Simular lógica de próximo a vencer basada en lotes
        // En una implementación real, consultarías la tabla de lotes
        var lotesProducto = obtenerLotesDelProducto(producto.id)
        
        for (var i = 0; i < lotesProducto.length; i++) {
            var lote = lotesProducto[i]
            if (lote.stock > 0) {
                var fechaVenc = new Date(lote.fechaVencimiento)
                var diasRestantes = Math.ceil((fechaVenc - fechaActual) / (1000 * 60 * 60 * 24))
                
                if (diasRestantes > 0 && diasRestantes <= 30) {
                    return true
                }
            }
        }
        return false
    }

    function esVencido(producto) {
        // Buscar si tiene lotes ya vencidos con stock
        for (var i = 0; i < lotesModel.count; i++) {
            var lote = lotesModel.get(i)
            
            // Solo revisar lotes de este producto que tengan stock
            if (lote.idProducto === producto.id && lote.stock > 0) {
                var fechaVenc = new Date(lote.fechaVencimiento)
                
                // Si ya venció (fecha vencimiento <= fecha actual)
                if (fechaVenc <= fechaActual) {
                    return true
                }
            }
        }
        return false
    }
    function esBajoStock(producto) {
        // Producto con bajo stock (menos de 15 unidades)
        return producto.stockUnitario > 0 && producto.stockUnitario <= 50
    }

    function obtenerLotesDelProducto(idProducto) {
        var lotes = []
        for (var i = 0; i < lotesModel.count; i++) {
            var lote = lotesModel.get(i)
            if (lote.idProducto === idProducto) {
                lotes.push(lote)
            }
        }
        return lotes
    }
  
    // FUNCIÓN CORREGIDA: updatePaginatedModel()
    function updatePaginatedModel() {
        console.log("📄 Productos: Actualizando paginación - Página:", currentPage + 1)
        
        // Limpiar modelo paginado
        productosPaginadosModel.clear()
        
        // Calcular total de páginas basado en productos filtrados
        var totalItems = productosFilteredModel.count
        totalPages = Math.ceil(totalItems / itemsPerPage)
        
        // Ajustar página actual si es necesario
        if (currentPage >= totalPages && totalPages > 0) {
            currentPage = totalPages - 1
        }
        if (currentPage < 0) {
            currentPage = 0
        }
        
        // Calcular índices
        var startIndex = currentPage * itemsPerPage
        var endIndex = Math.min(startIndex + itemsPerPage, totalItems)
        
        // Agregar elementos de la página actual
        for (var i = startIndex; i < endIndex; i++) {
            var producto = productosFilteredModel.get(i)
            productosPaginadosModel.append(producto)
        }
        
        console.log("📄 Productos: Página", currentPage + 1, "de", totalPages,
                    "- Mostrando", productosPaginadosModel.count, "de", totalItems)
    }
    
    // Función para limpiar campos del formulario
    function limpiarCampos() {
        codigoField.text = ""
        nombreField.text = ""
        detallesField.text = ""
        precioCompraField.text = ""
        precioVentaField.text = ""
        stockCajaField.text = ""
        stockUnitarioField.text = ""
        unidadMedidaCombo.currentIndex = 0
        marcaCombo.currentIndex = 0
    }

    // Función para guardar precio de venta - CONECTADA AL CENTRO
    function guardarPrecioVenta() {
        if (!productoSeleccionado) {
            console.log("❌ No hay producto seleccionado")
            return
        }
        
        var nuevoPrecio = parseFloat(precioVentaEditField.text)
        if (isNaN(nuevoPrecio) || nuevoPrecio <= 0) {
            console.log("❌ Precio inválido:", precioVentaEditField.text)
            return
        }
        
        console.log("💰 Solicitando actualización de precio:", productoSeleccionado.codigo, "a Bs", nuevoPrecio)
        
        // Usar función del centro de datos
        if (farmaciaData && farmaciaData.actualizarPrecioVentaProducto) {
            var exito = farmaciaData.actualizarPrecioVentaProducto(productoSeleccionado.codigo, nuevoPrecio)
            if (exito) {
                editarPrecioDialogOpen = false
                console.log("✅ Precio actualizado exitosamente en centro de datos")
                // Los datos se actualizarán automáticamente por la señal datosActualizados()
            } else {
                console.log("❌ Error al actualizar precio en centro de datos")
            }
        } else {
            console.log("❌ Función actualizarPrecioVentaProducto no disponible")
        }
    }
        
    // Función para eliminar producto - CONECTADA AL CENTRO
    function eliminarProducto(producto) {
        console.log("🗑️ Solicitando eliminación de producto:", producto.codigo)
        
        if (farmaciaData && farmaciaData.eliminarProductoInventario) {
            var exito = farmaciaData.eliminarProductoInventario(producto.codigo)
            if (exito) {
                console.log("✅ Producto eliminado exitosamente del centro de datos")
                // Los datos se actualizarán automáticamente por la señal datosActualizados()
            } else {
                console.log("❌ No se pudo eliminar el producto (probablemente tiene stock)")
            }
        } else {
            console.log("❌ Función eliminarProductoInventario no disponible")
        }
    }
    
    // Funciones auxiliares para colores
    function getStockColor(stock) {
        if (stock <= 0) {
            return dangerColor
        } else if (stock <= 15) {
            return "#8e44ad"
        } else {
            return successColor
        }
    }
    
    function getFechaVencColor(diasVencimiento) {
        if (diasVencimiento <= 0) {
            return dangerColor
        } else if (diasVencimiento <= 30) {
            return warningColor
        } else {
            return successColor
        }
    }
    
    Component.onCompleted: {
        console.log("📦 Módulo Productos iniciado")
        
        // Cargar datos iniciales desde el centro
        if (farmaciaData) {
            actualizarDesdeDataCentral()
            // Asegurar que la paginación se inicialice
            updatePaginatedModel()  // ✅ AGREGADO
        } else {
            console.log("⚠️ farmaciaData no disponible al iniciar")
        }
    }

    // Función para cargar lotes del producto seleccionado
    function cargarLotesDelProducto() {
        if (!productoSeleccionado) return
        
        console.log("📦 Cargando lotes para producto ID:", productoSeleccionado.id)
        
        // Limpiar modelo filtrado
        lotesFiltradosModel.clear()
        
        // Filtrar lotes por ID del producto
        for (var i = 0; i < lotesModel.count; i++) {
            var lote = lotesModel.get(i)
            if (lote.idProducto === productoSeleccionado.id) {
                lotesFiltradosModel.append({
                    lote: lote.lote,
                    fechaVencimiento: lote.fechaVencimiento,
                    stock: lote.stock,
                    estado: lote.estado
                })
            }
        } 
        console.log("✅ Lotes cargados:", lotesFiltradosModel.count)
    }

    // Función para obtener color según el estado
    function getEstadoColor(estado) {
        switch(estado) {
            case "Disponible":
                return successColor
            case "Agotado":
                return dangerColor
            case "Próximo a vencer":
                return warningColor
            default:
                return darkGrayColor
        }
    }
}