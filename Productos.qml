import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// Componente principal del módulo de Productos de Farmacia - CORREGIDO
Item {
    id: productosRoot
    
    // Referencia al módulo principal de farmacia
    property var farmaciaData: parent.farmaciaData
    property var inventarioModel: parent.inventarioModel
    
    // ESTADO PRINCIPAL: controla qué vista mostrar
    property bool mostrandoCrearProducto: false
    property bool modoEdicionProducto: false
    property var productoParaEditar: null
    
    // Estados del diálogo y funcionalidades
    property bool editarPrecioDialogOpen: false
    property var productoSeleccionado: null
    property int currentFilter: 0
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
    
    // MARCAS
    property var marcasModel: []
    property bool marcasCargando: false
    property bool marcasYaCargadas: false

    // DATOS DE LOTES - CORREGIDO
    property var lotesProximosVencer: []
    property var lotesVencidos: []
    property var productosConLotesBajoStock: []
    property bool datosLotesCargados: false

    // Propiedades de colores
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

    // ===== CONEXIONES CORREGIDAS =====
    
    Connections {
        target: inventarioModel
        function onProductosChanged() {
            console.log("📦 Productos actualizados desde InventarioModel")
            // CORREGIDO: Forzar recarga completa de datos
            Qt.callLater(function() {
                cargarDatosParaFiltros()
                actualizarDesdeDataCentral()
            })
        }
        function onLotesChanged() {
            console.log("📅 Lotes cambiaron - Actualizando filtros")
            Qt.callLater(cargarDatosParaFiltros)
        }
        function onOperacionExitosa(mensaje) {
            console.log("✅", mensaje)
            if (mensaje.includes("creado") || mensaje.includes("lote") || mensaje.includes("actualizado")) {
                Qt.callLater(function() {
                    cargarDatosParaFiltros()
                    actualizarDesdeDataCentral()
                })
            }
        }
        function onOperacionError(mensaje) {
            console.log("❌", mensaje)
        }
        function onMarcasChanged() {
            if (!marcasCargando && !marcasYaCargadas) {
                console.log("🏷️ Productos: Marcas cambiaron, recargando...")
                cargarMarcasDesdeModel()
            }
        }
    }
    
    Connections {
        target: farmaciaData
        function onDatosActualizados() {
            console.log("=== DATOS ACTUALIZADOS SIGNAL ===")
            cargarDatosParaFiltros()
            actualizarDesdeDataCentral()
            console.log("=== FIN DATOS ACTUALIZADOS ===")
        }
    }

    focus: true
    Keys.onEscapePressed: {
        console.log("Tecla Escape presionada en Productos.qml")
        
        if (mostrandoCrearProducto) {
            console.log("Cerrando CrearProducto con Escape")
            volverAListaProductos()
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

    // FUNCIÓN PARA CARGAR DATOS DE LOTES - CORREGIDA
    function cargarDatosParaFiltros() {
        if (!inventarioModel) {
            console.log("❌ InventarioModel no disponible para filtros")
            datosLotesCargados = false
            return
        }
        
        console.log("🔄 Cargando datos para filtros...")
        
        try {
            // CORREGIDO: Verificar que los métodos existan
            if (typeof inventarioModel.get_lotes_por_vencer === 'function') {
                var proximosVencer = inventarioModel.get_lotes_por_vencer(60)
                lotesProximosVencer = proximosVencer || []
                console.log("📅 Lotes próximos a vencer:", lotesProximosVencer.length)
            } else {
                console.log("⚠️ Método get_lotes_por_vencer no disponible")
                lotesProximosVencer = []
            }
            
            if (typeof inventarioModel.get_lotes_vencidos === 'function') {
                var vencidos = inventarioModel.get_lotes_vencidos()
                lotesVencidos = vencidos || []
                console.log("⚠️ Lotes vencidos:", lotesVencidos.length)
            } else {
                console.log("⚠️ Método get_lotes_vencidos no disponible")
                lotesVencidos = []
            }
            
            if (typeof inventarioModel.get_productos_bajo_stock === 'function') {
                var bajoStock = inventarioModel.get_productos_bajo_stock(10)
                productosConLotesBajoStock = bajoStock || []
                console.log("📊 Productos bajo stock:", productosConLotesBajoStock.length)
            } else {
                console.log("⚠️ Método get_productos_bajo_stock no disponible")
                productosConLotesBajoStock = []
            }
            
            datosLotesCargados = true
            console.log("✅ Datos de filtros cargados exitosamente")
            
        } catch (error) {
            console.log("❌ Error cargando datos para filtros:", error)
            lotesProximosVencer = []
            lotesVencidos = []
            productosConLotesBajoStock = []
            datosLotesCargados = false
        }
    }

    // FUNCIONES PARA MANEJO DE CREAR PRODUCTO
    function abrirCrearProducto() {
        console.log("🆕 Abriendo CrearProducto en pantalla completa")
        
        if (!marcasYaCargadas) {
            cargarMarcasDesdeModel()
        }
        
        modoEdicionProducto = false
        productoParaEditar = null
        mostrandoCrearProducto = true
        
        Qt.callLater(function() {
            if (crearProductoComponent.item) {
                crearProductoComponent.item.inventarioModel = inventarioModel
                crearProductoComponent.item.farmaciaData = farmaciaData
                
                if (marcasYaCargadas && marcasModel.length > 0) {
                    crearProductoComponent.item.marcasModel = marcasModel
                    crearProductoComponent.item.marcasCargadas = true
                }
                
                crearProductoComponent.item.abrirCrearProducto(false, null)
            }
        })
    }
    
    function abrirEditarProducto(producto) {
        console.log("🔧 Abriendo edición de producto:", producto.codigo)
        
        if (!marcasYaCargadas) {
            cargarMarcasDesdeModel()
        }
        
        modoEdicionProducto = true
        
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
        
        mostrandoCrearProducto = true
        
        Qt.callLater(function() {
            if (crearProductoComponent.item) {
                crearProductoComponent.item.abrirCrearProducto(true, productoParaEditar)
            }
        })
    }
    
    function volverAListaProductos() {
        console.log("🔙 Volviendo a lista de productos")
        mostrandoCrearProducto = false
        modoEdicionProducto = false
        productoParaEditar = null
        
        // CORREGIDO: Forzar recarga completa
        Qt.callLater(function() {
            cargarDatosParaFiltros()
            actualizarDesdeDataCentral()
        })
    }

    function cargarMarcasDesdeModel() {
        if (marcasCargando || marcasYaCargadas) {
            console.log("🏷️ Marcas ya cargadas o cargando, saltando...")
            return
        }
        
        marcasCargando = true
        
        if (!inventarioModel) {
            console.log("❌ InventarioModel no disponible para cargar marcas")
            marcasCargando = false
            return
        }
        
        try {
            console.log("🏷️ Productos: Iniciando carga de marcas...")
            if (typeof inventarioModel.get_marcas_disponibles === 'function') {
                var marcas = inventarioModel.get_marcas_disponibles()
                if (marcas && marcas.length > 0) {
                    marcasModel = marcas
                    marcasYaCargadas = true
                    console.log("✅ Marcas cargadas exitosamente:", marcas.length)
                } else {
                    console.log("⚠️ No se obtuvieron marcas del model")
                    marcasModel = []
                }
            } else {
                console.log("❌ Método get_marcas_disponibles no disponible")
                marcasModel = []
            }
        } catch (error) {
            console.log("❌ Error cargando marcas:", error)
            marcasModel = []
        }
        
        marcasCargando = false
    }

    function actualizarDesdeDataCentral() {
        console.log("🔄 Productos: Actualizando desde centro de datos...")
        
        // Conservar estado del detalle si está abierto
        var productoDetalleAnterior = null
        if (mostrandoDetalleProducto && productoParaDetalle && productoParaDetalle.codigo) {
            productoDetalleAnterior = {
                id: productoParaDetalle.id,
                codigo: productoParaDetalle.codigo,
                nombre: productoParaDetalle.nombre,
                detalles: productoParaDetalle.detalles,
                precioCompra: productoParaDetalle.precioCompra,
                precioVenta: productoParaDetalle.precioVenta,
                stockCaja: productoParaDetalle.stockCaja,
                stockUnitario: productoParaDetalle.stockUnitario,
                idMarca: productoParaDetalle.idMarca,
                unidadMedida: productoParaDetalle.unidadMedida
            }
        }
        
        // Obtener productos actualizados
        var productos = farmaciaData ? farmaciaData.obtenerProductosParaInventario() : []
        
        productosOriginales = []
        for (var i = 0; i < productos.length; i++) {
            productosOriginales.push(productos[i])
        }
        
        // Restaurar detalle si estaba abierto
        if (productoDetalleAnterior && mostrandoDetalleProducto) {
            var productoActualizado = null
            
            for (var j = 0; j < productos.length; j++) {
                if (productos[j].codigo === productoDetalleAnterior.codigo) {
                    productoActualizado = productos[j]
                    break
                }
            }
            
            if (productoActualizado) {
                productoParaDetalle = {
                    id: productoActualizado.id,
                    codigo: productoActualizado.codigo || "",
                    nombre: productoActualizado.nombre || "",
                    detalles: productoActualizado.detalles || "",
                    precioCompra: productoActualizado.precioCompra || 0,
                    precioVenta: productoActualizado.precioVenta || 0,
                    stockCaja: productoActualizado.stockCaja || 0,
                    stockUnitario: productoActualizado.stockUnitario || 0,
                    idMarca: productoActualizado.idMarca || "",
                    unidadMedida: productoActualizado.unidadMedida || "mg"
                }
            } else {
                productoParaDetalle = productoDetalleAnterior
            }
        }
        
        updateFilteredModel()
        
        console.log("✅ Productos actualizados desde centro de datos:", productos.length)
    }

    // Modelo que se sincroniza con datos centrales
    ListModel {
        id: productosFilteredModel
    }

    // VISTA PRINCIPAL
    StackLayout {
        anchors.fill: parent
        currentIndex: mostrandoCrearProducto ? 1 : 0
        
        // VISTA 0: LISTA DE PRODUCTOS
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            
            // Diálogo modal para detalle de producto - CORREGIDO
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

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(700, parent.width * 0.9)
                    height: Math.min(550, parent.height * 0.9)
                    radius: 8
                    color: "#ffffff"

                    DetalleProducto {
                        id: detalleProductoComponent
                        anchors.fill: parent
                        productoData: productoParaDetalle
                        mostrarStock: true
                        mostrarAcciones: true
                        // CORREGIDO: Asegurar que el inventarioModel esté disponible
                        inventarioModel: productosRoot.inventarioModel

                        onEditarSolicitado: function(producto) {
                            mostrandoDetalleProducto = false
                            abrirEditarProducto(producto)
                        }

                        onEliminarSolicitado: function(producto) {
                            eliminarProducto(producto)
                            mostrandoDetalleProducto = false
                        }

                        onAjustarStockSolicitado: function(producto) {
                            console.log("Ajustar stock de:", producto.codigo)
                        }

                        onCerrarSolicitado: {
                            mostrandoDetalleProducto = false
                            productoParaDetalle = null
                        }
                    }
                }
            }
            
            // INTERFAZ PRINCIPAL
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 24
                
                // Header del módulo
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16
                    
                    RowLayout {
                        spacing: 12
                        
                        Image {
                            source: "Resources/iconos/productos.png"
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
                    
                    Button {
                        Layout.preferredWidth: 230
                        Layout.preferredHeight: 75
                        
                        background: Rectangle {
                            color: parent.pressed ? Qt.darker(successColor, 1.2) : successColor
                            radius: 8
                            
                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }
                            
                            Rectangle {
                                anchors.fill: parent
                                anchors.topMargin: 2
                                color: "#00000020"
                                radius: 8
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
                                text: "Añadir Producto"
                                color: whiteColor
                                font.bold: true
                                font.pixelSize: 18
                            }
                        }
                        
                        onClicked: {
                            abrirCrearProducto()
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
                
                // Sección de filtros y búsqueda - CORREGIDA
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16
                    
                    RowLayout {
                        spacing: 8
                        
                        FilterButton {
                            text: "Todos"
                            count: getTotalCount()
                            active: currentFilter === 0
                            backgroundColor: blueColor
                            onClicked: {
                                console.log("🔍 Filtro: Todos")
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
                                console.log("🔍 Filtro: Próximos a vencer")
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
                                console.log("🔍 Filtro: Vencidos")
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
                                console.log("🔍 Filtro: Bajo stock")
                                currentFilter = 3
                                updateFilteredModel()
                            }
                        }
                    }
                    
                    Item { Layout.fillWidth: true }
                    
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
                                        console.log("🔍 Búsqueda:", searchText)
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
                                console.log("🔄 Actualizando manualmente...")
                                cargarDatosParaFiltros()
                                updateFilteredModel()
                            }
                        }
                    }
                }
                
                // Tabla principal de productos (mantener estructura original)
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
                                            
                                            property bool procesando: false
                                            
                                            background: Rectangle {
                                                color: parent.pressed ? Qt.darker(blueColor, 1.2) : blueColor
                                                radius: 6
                                                Behavior on color { ColorAnimation { duration: 150 } }
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
                                                if (procesando) return
                                                
                                                procesando = true
                                                console.log("📘 Click en Ver Detalles para:", model.codigo)
                                                
                                                productoSeleccionado = model
                                                mostrarDetalleProducto(model)
                                                
                                                resetTimer.restart()
                                            }
                                            
                                            Timer {
                                                id: resetTimer
                                                interval: 500
                                                running: false
                                                repeat: false
                                                onTriggered: parent.procesando = false
                                            }
                                        }
                                    }
                                }
                                
                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    z: -1
                                    
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
                                            abrirEditarProducto(model)
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
                            
                            // Estado vacío
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
                                    enabled: currentPage > 0
                                    
                                    background: Rectangle {
                                        color: parent.enabled ? 
                                            (parent.pressed ? Qt.darker("#10B981", 1.1) : "#10B981") :   
                                            "#E5E7EB"
                                        radius: 18
                                        Behavior on color { ColorAnimation { duration: 150 } }
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
                                
                                Label {
                                    text: "Página " + (currentPage + 1) + " de " + Math.max(1, totalPages)
                                    color: "#374151"
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                }
                                                            
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
                                        Behavior on color { ColorAnimation { duration: 150 } }
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

            // Diálogo para Editar Precio de Venta (mantener igual)
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
                    forceActiveFocus()
                }
            }
        }
        
        // VISTA 1: CREAR/EDITAR PRODUCTO
        Loader {
            id: crearProductoComponent
            Layout.fillWidth: true
            Layout.fillHeight: true
            source: mostrandoCrearProducto ? "CrearProducto.qml" : ""
            
            onLoaded: {
                if (item) {
                    console.log("🚀 CrearProducto.qml cargado como pantalla completa")
                    
                    item.inventarioModel = productosRoot.inventarioModel
                    item.farmaciaData = productosRoot.farmaciaData
                    
                    if (marcasYaCargadas && marcasModel.length > 0) {
                        item.marcasModel = productosRoot.marcasModel
                        item.marcasCargadas = true
                    }
                    
                    // Conectar señales
                    item.productoCreado.connect(function(producto) {
                        console.log("✅ Producto creado:", producto.codigo)
                        
                        if (farmaciaData) {
                            farmaciaData.crearProductoUnico(JSON.stringify(producto))
                        }
                        
                        volverAListaProductos()
                    })
                    
                    item.productoActualizado.connect(function(producto) {
                        console.log("✅ Producto actualizado:", producto.codigo)
                        volverAListaProductos()
                    })
                    
                    item.cancelarCreacion.connect(function() {
                        console.log("❌ Creación cancelada")
                        volverAListaProductos()
                    })
                    
                    item.volverALista.connect(function() {
                        console.log("🔙 Volver a lista solicitado")
                        volverAListaProductos()
                    })
                    
                    console.log("✅ Señales conectadas correctamente")
                }
            }
            
            onStatusChanged: {
                if (status === Loader.Error) {
                    console.error("❌ Error cargando CrearProducto.qml")
                    mostrandoCrearProducto = false
                }
            }
        }
    }
    
    // FilterButton component
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
        
        Behavior on color { ColorAnimation { duration: 200 } }
        
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
                Behavior on color { ColorAnimation { duration: 200 } }
            }
            
            Rectangle {
                id: countLabel
                Layout.preferredWidth: 24
                Layout.preferredHeight: 20
                color: active ? whiteColor : backgroundColor
                radius: 10
                Behavior on color { ColorAnimation { duration: 200 } }
                
                Label {
                    anchors.centerIn: parent
                    text: parent.parent.parent.count.toString()
                    color: active ? backgroundColor : whiteColor
                    font.bold: true
                    font.pixelSize: 11
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }
        }
        
        MouseArea {
            anchors.fill: parent
            onClicked: parent.clicked()
        }
    }
    
    // ===== FUNCIONES CORREGIDAS =====

    function getTotalCount() {
        if (productosOriginales.length === 0) {
            return productosFilteredModel.count
        }
        return productosOriginales.length
    }

    function getProximosVencerCount() {
        if (!datosLotesCargados) return 0
        
        var productosUnicos = new Set()
        
        for (var i = 0; i < lotesProximosVencer.length; i++) {
            var lote = lotesProximosVencer[i]
            if ((lote.Stock_Lote || 0) > 0) {
                productosUnicos.add(lote.Codigo)
            }
        }
        
        return productosUnicos.size
    }
     
    function getVencidosCount() {
        if (!datosLotesCargados) return 0
        
        var productosUnicos = new Set()
        
        for (var i = 0; i < lotesVencidos.length; i++) {
            var lote = lotesVencidos[i]
            if ((lote.Stock_Lote || 0) > 0) {
                productosUnicos.add(lote.Codigo)
            }
        }
        
        return productosUnicos.size
    }

    function getBajoStockCount() {
        if (!datosLotesCargados) return 0
        return productosConLotesBajoStock.length
    }

    // FUNCIÓN DE FILTRADO CORREGIDA
    function updateFilteredModel() {
        console.log("🔍 Actualizando modelo filtrado, filtro:", currentFilter, "búsqueda:", searchText)
        console.log("  - Datos de lotes cargados:", datosLotesCargados)
        console.log("  - Productos originales:", productosOriginales.length)
        
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
        
        productosFilteredModel.clear()
        
        var productosFiltrados = []
        
        for (var j = 0; j < productosOriginales.length; j++) {
            var producto = productosOriginales[j]
            var pasaFiltro = false
            
            switch(currentFilter) {
                case 0:
                    pasaFiltro = true
                    break
                case 1:
                    pasaFiltro = esProximoVencer(producto)
                    console.log("  Producto", producto.codigo, "próximo vencer:", pasaFiltro)
                    break
                case 2:
                    pasaFiltro = esVencido(producto)
                    console.log("  Producto", producto.codigo, "vencido:", pasaFiltro)
                    break
                case 3:
                    pasaFiltro = esBajoStock(producto)
                    console.log("  Producto", producto.codigo, "bajo stock:", pasaFiltro)
                    break
            }
            
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
        
        for (var k = 0; k < productosFiltrados.length; k++) {
            productosFilteredModel.append(productosFiltrados[k])
        }

        console.log("✅ Filtro aplicado. Productos mostrados:", productosFiltrados.length)
        
        currentPage = 0
        updatePaginatedModel()
    }

    // FUNCIONES DE EVALUACIÓN CORREGIDAS
    function esProximoVencer(producto) {
        if (!producto || !producto.codigo || !datosLotesCargados) return false
        
        for (var i = 0; i < lotesProximosVencer.length; i++) {
            var lote = lotesProximosVencer[i]
            if (lote.Codigo === producto.codigo && (lote.Stock_Lote || 0) > 0) {
                return true
            }
        }     
        return false
    }

    function esVencido(producto) {
        if (!producto || !producto.codigo || !datosLotesCargados) return false
        
        for (var i = 0; i < lotesVencidos.length; i++) {
            var lote = lotesVencidos[i]
            if (lote.Codigo === producto.codigo && (lote.Stock_Lote || 0) > 0) {
                return true
            }
        }     
        return false
    }
    
    function esBajoStock(producto) {
        if (!producto || !producto.codigo || !datosLotesCargados) return false
        
        for (var i = 0; i < productosConLotesBajoStock.length; i++) {
            var productoBajoStock = productosConLotesBajoStock[i]
            if (productoBajoStock.Codigo === producto.codigo) {
                return true
            }
        }
        return false
    }
  
    function updatePaginatedModel() {
        productosPaginadosModel.clear()
        
        var totalItems = productosFilteredModel.count
        totalPages = Math.ceil(totalItems / itemsPerPage)
        
        if (currentPage >= totalPages && totalPages > 0) {
            currentPage = totalPages - 1
        }
        if (currentPage < 0) {
            currentPage = 0
        }
        
        var startIndex = currentPage * itemsPerPage
        var endIndex = Math.min(startIndex + itemsPerPage, totalItems)
        
        for (var i = startIndex; i < endIndex; i++) {
            var producto = productosFilteredModel.get(i)
            productosPaginadosModel.append(producto)
        }
    }
    
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
        
        if (farmaciaData && farmaciaData.actualizarPrecioVentaProducto) {
            var exito = farmaciaData.actualizarPrecioVentaProducto(productoSeleccionado.codigo, nuevoPrecio)
            if (exito) {
                editarPrecioDialogOpen = false
                console.log("✅ Precio actualizado exitosamente en centro de datos")
            } else {
                console.log("❌ Error al actualizar precio en centro de datos")
            }
        } else {
            console.log("❌ Función actualizarPrecioVentaProducto no disponible")
        }
    }
        
    function eliminarProducto(producto) {
        console.log("🗑️ Solicitando eliminación de producto:", producto.codigo)
        
        if (farmaciaData && farmaciaData.eliminarProductoInventario) {
            var exito = farmaciaData.eliminarProductoInventario(producto.codigo)
            if (exito) {
                console.log("✅ Producto eliminado exitosamente del centro de datos")
            } else {
                console.log("❌ No se pudo eliminar el producto (probablemente tiene stock)")
            }
        } else {
            console.log("❌ Función eliminarProductoInventario no disponible")
        }
    }
    
    function obtenerMarcasModel() {
        return marcasModel
    }
    
    function getStockColor(stock) {
        if (stock <= 0) {
            return dangerColor
        } else if (stock <= 15) {
            return "#8e44ad"
        } else {
            return successColor
        }
    }
    
    // FUNCIÓN MOSTRAR DETALLE CORREGIDA
    function mostrarDetalleProducto(producto) {
        if (!producto) {
            console.log("❌ No se puede mostrar detalle: producto nulo")
            return
        }
        
        console.log("🔍 Mostrando detalle de producto:", producto.codigo)
        
        productoParaDetalle = {
            id: producto.id || 0,
            codigo: producto.codigo || "",
            nombre: producto.nombre || "",
            detalles: producto.detalles || "",
            precioCompra: producto.precioCompra || producto.precio_compra || 0,
            precioVenta: producto.precioVenta || producto.precio_venta || 0,
            stockCaja: producto.stockCaja || producto.stock_caja || 0,
            stockUnitario: producto.stockUnitario || producto.stock_unitario || 0,
            idMarca: producto.idMarca || producto.marca_nombre || producto.Marca_Nombre || "",
            unidadMedida: producto.unidadMedida || producto.Unidad_Medida || "mg"
        }
        
        mostrandoDetalleProducto = true
        
        // CORREGIDO: Forzar recarga de lotes
        Qt.callLater(function() {
            if (detalleProductoComponent && detalleProductoComponent.inventarioModel) {
                // Forzar recarga de lotes
                detalleProductoComponent.recargarLotes()
            }
        })
    }

    Component.onCompleted: {
        console.log("📦 Módulo Productos iniciado (FILTROS Y LOTES CORREGIDOS)")
        console.log("🔗 InventarioModel disponible:", !!inventarioModel)
        console.log("🔗 FarmaciaData disponible:", !!farmaciaData)
        
        if (inventarioModel) {
            console.log("📊 Productos en InventarioModel:", inventarioModel.total_productos)
            
            // PASO 1: Cargar marcas
            cargarMarcasDesdeModel()
            
            // PASO 2: Cargar datos para filtros
            cargarDatosParaFiltros()
            
            // PASO 3: Cargar productos
            if (farmaciaData) {
                actualizarDesdeDataCentral()
                updatePaginatedModel()
            }
        } else {
            console.log("❌ InventarioModel no disponible - filtros no funcionarán")
        }
    }
}