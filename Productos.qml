import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// Componente principal del módulo de Productos de Farmacia - CORREGIDO
Item {
    id: productosRoot
    
    // Referencia al módulo principal de farmacia
    property var farmaciaData: parent.farmaciaData
    property var inventarioModel: parent.inventarioModel
    
    // CORREGIDO: Estado del diálogo con mejor manejo
    property bool mostrandoDialogoCrear: false
    property var productoParaEditar: null
    property bool marcasDisponibles: false
    
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
    property var productoSeleccionado: null
    property int currentFilter: 0 // 0=Todos, 1=Prox.Vencer, 2=Vencidos, 3=BajoStock
    property string searchText: ""
    property var productosOriginales: []
    property var fechaActual: new Date()
    
    // Propiedades de paginación
    property int itemsPerPage: 10
    property int currentPage: 0
    property int totalPages: 0
    property var allFilteredProducts: []

    property bool mostrandoDetalleProducto: false
    property var productoParaDetalle: null
    
    // CORREGIDO: Mejor manejo de marcas
    property var marcasModel: []
    property bool marcasCargando: true

    // ===== CONEXIONES CON INVENTARIO MODEL - CORREGIDAS =====
    
    Connections {
        target: inventarioModel
        function onProductosChanged() {
            console.log("📦 Productos actualizados desde InventarioModel")
            actualizarDesdeDataCentral()
        }
        function onOperacionExitosa(mensaje) {
            console.log("✅", mensaje)
        }
        function onOperacionError(mensaje) {
            console.log("❌", mensaje)
        }
        function onMarcasChanged() {
            cargarMarcasDesdeModel()
        }
    }
    
    // Conexión con datos centrales
    Connections {
        target: farmaciaData
        function onDatosActualizados() {
            console.log("📦 Productos: Señal datosActualizados() recibida")
            actualizarDesdeDataCentral()
        }
    }
    focus: true
    Keys.onEscapePressed: {
        console.log("Tecla Escape presionada en Productos.qml")
        if (mostrandoDialogoCrear) {
            console.log("Cerrando diálogo con Escape")
            cerrarDialogo()
        } else if (mostrandoDetalleProducto) {
            console.log("Cerrando detalle de producto con Escape")
            mostrandoDetalleProducto = false
            productoParaDetalle = null
        } else if (editarPrecioDialogOpen) {
            console.log("Cerrando diálogo de precio con Escape")
            editarPrecioDialogOpen = false
        }
    }

    // MODELO PAGINADO
    ListModel {
        id: productosPaginadosModel
    }

    // CORREGIDO: Función para cargar marcas con mejor manejo de errores
    function cargarMarcasDesdeModel() {
        marcasCargando = true
        
        if (!inventarioModel) {
            console.log("❌ InventarioModel no disponible para cargar marcas")
            marcasCargando = false
            return
        }
        
        try {
            // CORREGIDO: Usar la función corregida del model
            var marcas = inventarioModel.get_marcas_disponibles()
            
            if (marcas && marcas.length > 0) {
                marcasModel = marcas
                marcasDisponibles = true
                console.log("✅ Marcas cargadas exitosamente:", marcas.length)
                
            } else {
                console.log("⚠️ No se obtuvieron marcas del model")
                marcasModel = []
                marcasDisponibles = false
            }
        } catch (error) {
            console.log("❌ Error cargando marcas:", error)
            marcasModel = []
            marcasDisponibles = false
        }
        
        marcasCargando = false
    }

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

    // Diálogo modal para detalle de producto
    Rectangle {
        id: detalleOverlay
        anchors.fill: parent
        color: "#80000000"
        visible: mostrandoDetalleProducto
        z: 1000

        MouseArea {
            anchors.fill: parent
            onClicked: {
                mostrandoDetalleProducto = false
                productoParaDetalle = null
            }
        }

        // Contenedor del diálogo
        Rectangle {
            anchors.centerIn: parent
            width: Math.min(700, parent.width * 0.9)
            height: Math.min(550, parent.height * 0.9)
            radius: 8
            color: "#ffffff"

            // Componente de detalle
            DetalleProducto {
                id: detalleProductoComponent
                anchors.fill: parent
                productoData: productoParaDetalle
                mostrarStock: true
                mostrarAcciones: true

                onEditarSolicitado: function(producto) {
                    mostrandoDetalleProducto = false
                    abrirDialogoEditar(producto)
                }

                onEliminarSolicitado: function(producto) {
                    eliminarProducto(producto)
                    mostrandoDetalleProducto = false
                }

                onAjustarStockSolicitado: function(producto) {
                    console.log("Ajustar stock de:", producto.codigo)
                    // TODO: Implementar lógica de ajuste de stock
                }

                onCerrarSolicitado: {
                    mostrandoDetalleProducto = false
                    productoParaDetalle = null
                }
            }
        }
    }
    
    // INTERFAZ PRINCIPAL - Layout que contiene todo
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 24
        
        // Header del módulo con título e información
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
            
            // Botón Añadir Producto - MEJORADO
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
                    abrirDialogoCrear()
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
                                text: "DESCRIPCIÓN"
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
                                    text: "Bs " + (model.precioCompra ? model.precioCompra.toFixed(2) : "0.00")
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
                                    text: "Bs " + (model.precioVenta ? model.precioVenta.toFixed(2) : "0.00")
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
                                        mostrarDetalleProducto(model)
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
                                text: "✏️ Editar Producto"
                                onTriggered: {
                                    console.log("🔧 Intentando editar producto:", model.codigo)
                                    abrirDialogoEditar(model)
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
                                                
                        // Botón Siguiente
                        Button {
                            Layout.preferredWidth: 110
                            Layout.preferredHeight: 36
                            text: "Siguiente →"
                            enabled: currentPage < totalPages - 1
                            
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
                                if (currentPage < totalPages - 1) {
                                    currentPage++
                                    updatePaginatedModel()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ===== OVERLAY MODAL PARA CREAR/EDITAR PRODUCTO - MEJORADO =====
    Rectangle {
        id: modalOverlay
        anchors.fill: parent
        color: "#40000000"
        visible: mostrandoDialogoCrear
        z: 1000
        focus: visible
        Keys.onEscapePressed: {
            console.log("Escape en overlay - cerrando diálogo")
            cerrarDialogo()
        }
        // Animación de entrada/salida
        opacity: mostrandoDialogoCrear ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
        }
        
        // Cerrar al hacer clic en el fondo
        MouseArea {
            anchors.fill: parent
            onClicked: {
                cerrarDialogo()
            }
        }
        
        // Contenedor del diálogo centrado
        Rectangle {
            id: dialogContainer
            anchors.centerIn: parent
            width: Math.min(900, parent.width * 0.95)
            height: Math.min(750, parent.height * 0.95)
            color: "transparent"
            
            // Componente CrearProducto cargado dinámicamente - CORREGIDO
            Loader {
                id: crearProductoLoader
                anchors.fill: parent
                source: mostrandoDialogoCrear ? "CrearProducto.qml" : ""
                focus: false

                onLoaded: {
                    if (item) {
                        console.log("🚀 CrearProducto.qml cargado exitosamente")
                        
                        // CORREGIDO: Configurar propiedades del diálogo
                        item.modoEdicion = (productoParaEditar !== null)
                        item.productoData = productoParaEditar
                        item.marcasModel = marcasModel
                        
                        console.log("🏷️ Marcas pasadas al diálogo:", marcasModel.length)
                        console.log("🔧 Modo edición:", item.modoEdicion)
                        
                        if (productoParaEditar) {
                            console.log("📝 Producto para editar:", productoParaEditar.codigo)
                        }
                        
                        // CORREGIDO: Conectar señales con función anónimas
                        item.productoCreado.connect(function(producto) {
                            console.log("✅ Producto creado:", producto.codigo)
                            cerrarDialogo()
                            
                            if (farmaciaData) {
                                farmaciaData.crearProductoUnico(JSON.stringify(producto))
                            }
                        })
                        
                        item.productoActualizado.connect(function(producto) {
                            console.log("✅ Producto actualizado:", producto.codigo)
                            cerrarDialogo()
                            updateFilteredModel()
                        })
                        
                        item.cancelado.connect(function() {
                            cerrarDialogo()
                        })
                        
                        item.cerrarSolicitado.connect(function() {
                            cerrarDialogo()
                        })
                        
                        // CORREGIDO: Abrir el diálogo usando la función del componente
                        if (typeof item.abrirDialog === "function") {
                            item.abrirDialog(item.modoEdicion, item.productoData)
                        }
                        item.focus = false
                    }
                }
                
                onStatusChanged: {
                    if (status === Loader.Error) {
                        console.error("❌ Error cargando CrearProducto.qml")
                        mostrandoDialogoCrear = false
                    }
                }
            }
        }
        
        // Prevenir que el clic en el diálogo cierre el overlay
        MouseArea {
            anchors.fill: dialogContainer
            onClicked: {
                // No hacer nada - evita que el clic se propague
            }
        }
    }

    // CORREGIDO: Funciones para manejar diálogos
    function abrirDialogoCrear() {
        console.log("🆕 Abriendo diálogo para crear producto")
        
        // Cargar marcas antes de abrir
        cargarMarcasDesdeModel()
        
        productoParaEditar = null
        mostrandoDialogoCrear = true
    }
    
    function abrirDialogoEditar(producto) {
        console.log("📝 Abriendo diálogo para editar producto:", producto.codigo)
        
        // Cargar marcas antes de abrir
        cargarMarcasDesdeModel()
        
        // CORREGIDO: Crear una copia limpia del producto sin referencias circulares
        productoParaEditar = {
            id: producto.id,
            codigo: producto.codigo,
            nombre: producto.nombre,
            detalles: producto.detalles || "",
            precioCompra: producto.precioCompra || 0,
            precioVenta: producto.precioVenta || 0,
            stockCaja: producto.stockCaja || 0,
            stockUnitario: producto.stockUnitario || 0,
            idMarca: producto.idMarca || "",
            unidadMedida: producto.unidadMedida || "Tabletas"
        }
        
        mostrandoDialogoCrear = true
    }
    
    function cerrarDialogo() {
        mostrandoDialogoCrear = false
        productoParaEditar = null
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
                        text: "Precio Compra: Bs " + (productoSeleccionado ? productoSeleccionado.precioCompra.toFixed(2) : "0.00")
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
                            text: "Bs"
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
        onOpened: {
            precioVentaEditField.forceActiveFocus()
            precioVentaEditField.selectAll()
        }

        onClosed: {
            // Asegurar que el foco vuelva al componente principal
            forceActiveFocus()
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
    
    // ===== FUNCIONES (mantener las existentes) =====
    
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
        return Math.random() < 0.1 // 10% simulado
    }

    function esVencido(producto) {
        // Simular lógica de vencido
        return Math.random() < 0.05 // 5% simulado
    }
    
    function esBajoStock(producto) {
        // Producto con bajo stock (menos de 15 unidades)
        return producto.stockUnitario > 0 && producto.stockUnitario <= 50
    }
  
    // FUNCIÓN CORREGIDA: updatePaginatedModel()
    function updatePaginatedModel() {
        console.log("🔄 Productos: Actualizando paginación - Página:", currentPage + 1)
        
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
        
        console.log("🔄 Productos: Página", currentPage + 1, "de", totalPages,
                    "- Mostrando", productosPaginadosModel.count, "de", totalItems)
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
    
    // Función para obtener marcas (simulada)
    function obtenerMarcasModel() {
        return marcasModel
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
    
    Component.onCompleted: {
        console.log("📦 Módulo Productos iniciado")
        console.log("🔗 InventarioModel disponible:", !!inventarioModel)
        
        if (inventarioModel) {
            console.log("📊 Productos en InventarioModel:", inventarioModel.total_productos)
            // CORREGIDO: Cargar marcas al inicio
            cargarMarcasDesdeModel()
        }
        
        if (farmaciaData) {
            actualizarDesdeDataCentral()
            updatePaginatedModel()
        }
    }
    
    function mostrarDetalleProducto(producto) {
        productoParaDetalle = producto
        mostrandoDetalleProducto = true
    }
    
    function editarProductoDesdeDetalle(producto) {
        mostrandoDetalleProducto = false
        abrirDialogoEditar(producto)
    }
    
    function ajustarStockProducto(producto) {
        console.log("Ajustar stock de:", producto.codigo)
        // TODO: Implementar lógica de ajuste de stock
    }
    
    function cerrarDetalleProducto() {
        mostrandoDetalleProducto = false
        productoParaDetalle = null
    }
}