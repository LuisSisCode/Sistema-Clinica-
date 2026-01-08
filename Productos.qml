import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15

// Con DetalleProducto.qml como modal de detalle
Item {
    id: productosRoot
    
    // Referencia al módulo principal de farmacia
    property var farmaciaData: parent.farmaciaData
    property var inventarioModel: parent.inventarioModel
    
    // ESTADO PRINCIPAL: controla qué vista mostrar
    // ❌ DESHABILITADO EN V2.0 - Productos se crean solo en Compras
    property bool modoEdicionProducto: false
    property var productoParaEditar: null
    property var selectedProduct: null
    
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

    // NUEVO: Modal de detalle de producto FIFO 2.0
    property bool mostrandoDetalleProducto: false
    property var productoParaDetalle: null
    
    // PROPIEDADES PARA MODALES
    property bool mostrandoEditarLote: false
    property var loteParaEditar: null
    
    // MARCAS
    property var marcasModel: []
    
    // ✅ NUEVO FIFO 2.0: MAPA DE STOCK PRECALCULADO (evita binding loops)
    property var mapaStock: ({})
    property bool stockCalculado: false

    property bool marcasCargando: false
    property bool marcasYaCargadas: false

    // DATOS DE LOTES - SIN CAJAS
    property var lotesProximosVencer: []
    property var lotesVencidos: []
    property var productosConLotesBajoStock: []
    property bool datosLotesCargados: false

    // 🆕 V2.0: Confirmación de eliminación
    property var productoParaEliminar: null
    property bool confirmDialogVisible: false
    property string confirmDialogTitle: ""
    property string confirmDialogMessage: ""
    property string confirmDialogAccion: ""
    
    // 🔧 NUEVO: Propiedades para menú contextual
    property bool mostrandoMenuContextual: false
    property var productoMenuContextual: null

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

    property color grayMedium: "#7f8c8d"
    
    // ✅ FIFO 2.0: Colores de estado de stock
    readonly property color stockNormalColor: '#2fb32f'    // Verde
    readonly property color stockBajoColor: "#FFB444"      // Naranja
    readonly property color stockCriticoColor: "#FF4444"   // Rojo

    property bool _actualizandoDatos: false

    // ===== CONEXIONES =====
    Connections {
        target: inventarioModel
        function onProductosChanged() {
            if (_actualizandoDatos) {
                console.log("⚠️ Ya hay actualización en curso, ignorando signal duplicado")
                return
            }
            
            console.log("🔄 Productos actualizados desde BD - Refrescando interfaz")
            
            // ✅ PRESERVAR el CÓDIGO del producto, no la referencia al objeto
            var codigoProductoActual = null
            if (mostrandoDetalleProducto && productoParaDetalle) {
                codigoProductoActual = productoParaDetalle.codigo
                console.log("💾 Guardando código de producto:", codigoProductoActual)
            }
            
            Qt.callLater(function() {
                cargarDatosParaFiltros()
                actualizarDesdeDataCentral()
                
                // ✅ RESTAURAR productoData buscando el producto actualizado por código
                if (mostrandoDetalleProducto && codigoProductoActual && detalleProductoLoader.item) {
                    console.log("🔍 Buscando producto actualizado:", codigoProductoActual)
                    
                    // Buscar el producto en el array actualizado
                    for (var i = 0; i < productosOriginales.length; i++) {
                        if (productosOriginales[i].codigo === codigoProductoActual) {
                            console.log("✅ Producto encontrado, restaurando productoData")
                            productoParaDetalle = productosOriginales[i]
                            detalleProductoLoader.item.productoData = productosOriginales[i]
                            break
                        }
                    }
                }
            })
        }
    }

    focus: true
    Keys.onEscapePressed: {
        console.log("Tecla Escape presionada en Productos.qml")
        
        if (modoEdicionProducto) {
            console.log("Cerrando EditarProducto con Escape")
            cerrarEditarProducto()
        } else if (mostrandoDetalleProducto) {
            console.log("Cerrando detalle de producto con Escape")
            cerrarDetalleProducto()
        } else if (editarPrecioDialogOpen) {
            console.log("Cerrando diálogo de precio con Escape")
            editarPrecioDialogOpen = false
        } else if (mostrandoEditarLote) {
            console.log("Cerrando editar lote con Escape")
            mostrandoEditarLote = false
            loteParaEditar = null
        } else if (confirmDialogVisible) {
            console.log("Cerrando diálogo de confirmación con Escape")
            confirmDialogVisible = false
        } else if (mostrandoMenuContextual) {
            console.log("Cerrando menú contextual con Escape")
            mostrandoMenuContextual = false
        }
    }

    // MODELO PAGINADO
    ListModel {
        id: productosPaginadosModel
    }

    function cargarDatosParaFiltros() {
        if (!inventarioModel) {
            console.log("❌ InventarioModel no disponible para filtros")
            datosLotesCargados = false
            return
        }
        
        console.log("🔄 Cargando datos para filtros desde InventarioModel...")
        
        try {
            // Cargar lotes próximos a vencer
            if (typeof inventarioModel.get_lotes_por_vencer === 'function') {
                var proximosVencer = inventarioModel.get_lotes_por_vencer(60)
                lotesProximosVencer = proximosVencer || []
                console.log("📅 Lotes próximos a vencer:", lotesProximosVencer.length)
            } else {
                console.log("⚠️ Método get_lotes_por_vencer no disponible")
                lotesProximosVencer = []
            }
            
            // Cargar lotes vencidos
            if (typeof inventarioModel.get_lotes_vencidos === 'function') {
                var vencidos = inventarioModel.get_lotes_vencidos()
                lotesVencidos = vencidos || []
                console.log("⚠️ Lotes vencidos:", lotesVencidos.length)
            } else {
                console.log("⚠️ Método get_lotes_vencidos no disponible")
                lotesVencidos = []
            }
            
            // Cargar productos bajo stock
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

    // ========================================
    // 🆕 FUNCIONES V2.0 - EDITAR Y ELIMINAR
    // ========================================

    function abrirEditarProducto(producto) {
        console.log("✏️ Abriendo edición de producto ID:", producto.id, "Código:", producto.codigo)
        
        // ✅ LLAMAR AL MÉTODO ESPECIALIZADO para obtener TODOS los datos
        if (inventarioModel && typeof inventarioModel.get_producto_para_edicion === 'function') {
            var productoCompleto = inventarioModel.get_producto_para_edicion(producto.id)
            
            if (!productoCompleto) {
                console.error("❌ No se pudo obtener datos completos del producto")
                return
            }
            
            console.log("📊 Datos completos del producto:", JSON.stringify(productoCompleto, null, 2))
            
            // ✅ Ahora usa productoCompleto que tiene TODOS los campos
            productoParaEditar = {
                id: productoCompleto.id,
                codigo: productoCompleto.codigo || "",
                nombre: productoCompleto.nombre || "",
                detalles: productoCompleto.detalles || "",
                precio_compra: productoCompleto.precioCompra || 0,
                precio_venta: productoCompleto.precioVenta || 0,
                stock: productoCompleto.stockTotal || productoCompleto.stockUnitario || 0,
                stockUnitario: productoCompleto.stockUnitario || 0,
                marca: productoCompleto.marca_nombre || productoCompleto.Marca_Nombre || "",
                marca_id: productoCompleto.ID_Marca || productoCompleto.id_marca || 0,
                unidad_medida: productoCompleto.unidadMedida || "Tabletas",
                stock_minimo: productoCompleto.Stock_Minimo || productoCompleto.stock_minimo || 10,
                lotesTotales: productoCompleto.lotesTotales || 0
            }
            
            modoEdicionProducto = true
        } else {
            console.error("❌ Método get_producto_para_edicion no disponible")
        }
    }
    
    function cerrarEditarProducto() {
        console.log("❌ Cerrando edición de producto")
        modoEdicionProducto = false
        productoParaEditar = null
    }

    function productoActualizado(producto) {
        console.log("✅ Producto actualizado:", producto.codigo || producto.Codigo)
        cerrarEditarProducto()
        
        // Refrescar datos
        if (inventarioModel && typeof inventarioModel.refresh_productos === 'function') {
            inventarioModel.refresh_productos()
        }
        
        mostrarMensajeExito("Producto actualizado correctamente")
    }

    function confirmarEliminarProducto(producto) {
        console.log("🗑️ Confirmar eliminación de:", producto.codigo)
        
        productoParaEliminar = producto
        confirmDialogTitle = "¿Eliminar Producto?"
        confirmDialogMessage = "¿Está seguro de eliminar el producto '" + producto.nombre + "'?\n\n" +
                              "Código: " + producto.codigo + "\n" +
                              "Esta acción es PERMANENTE.\n\n" +
                              "⚠️ Solo se puede eliminar si NO tiene ventas registradas."
        confirmDialogAccion = "eliminar_producto"
        confirmDialogVisible = true
    }

    function eliminarProductoConfirmado() {
        if (!productoParaEliminar) {
            console.error("❌ No hay producto para eliminar")
            return
        }
        
        console.log("🗑️ Eliminando producto:", productoParaEliminar.codigo)
        
        if (inventarioModel && typeof inventarioModel.eliminar_producto === 'function') {
            var resultado = inventarioModel.eliminar_producto(productoParaEliminar.codigo)
            
            if (resultado) {
                console.log("✅ Producto eliminado exitosamente")
                mostrarMensajeExito("Producto eliminado correctamente")
                
                // Refrescar datos
                Qt.callLater(function() {
                    cargarDatosParaFiltros()
                    actualizarDesdeDataCentral()
                    updateFilteredModel()
                })
            } else {
                console.error("❌ Error al eliminar producto")
                mostrarMensajeError("Error al eliminar el producto. Verifique que no tenga ventas registradas.")
            }
        } else {
            console.error("❌ Función eliminar_producto no disponible en inventarioModel")
            mostrarMensajeError("Función de eliminación no disponible")
        }
        
        productoParaEliminar = null
        confirmDialogVisible = false
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
        // ✅ Prevenir re-entrada
        if (_actualizandoDatos) {
            console.log("⏭️ Actualización ya en curso, omitiendo")
            return
        }
        
        if (!inventarioModel) {
            console.log("❌ InventarioModel no disponible")
            return
        }
        
        _actualizandoDatos = true  
        console.log("🔧 Productos: Actualizando desde centro de datos...")
        
        // ✅ CARGAR PRODUCTOS DESDE farmaciaData
        var productos = farmaciaData ? farmaciaData.obtenerProductosParaInventario() : []
        
        productosOriginales = []
        for (var i = 0; i < productos.length; i++) {
            productosOriginales.push(productos[i])
        }
        
        updateFilteredModel()
        
        console.log("✅ Productos actualizados desde centro de datos:", productos.length)
        
        // ✅ Liberar flag después de completar
        Qt.callLater(function() {
            _actualizandoDatos = false
        })
    }

    // Modelo que se sincroniza con datos centrales
    ListModel {
        id: productosFilteredModel
    }

    Item {
        anchors.fill: parent
        
        // ===============================
        // INTERFAZ PRINCIPAL
        // ===============================
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16
            
            // Header del módulo
            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                
                RowLayout {
                    spacing: 12
                    
                    Image {
                        source: "Resources/iconos/productos.png"
                        Layout.preferredWidth: 50
                        Layout.preferredHeight: 50
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
                            font.pixelSize: 20
                            font.bold: true
                            color: textColor
                        }
                        
                        Label {
                            text: "Inventario de Productos - V2.0"
                            font.pixelSize: 14
                            color: darkGrayColor
                        }
                    }
                }

                Item { Layout.fillWidth: true }
                
                // ❌ DESHABILITADO EN V2.0 - Productos se crean solo en Compras
                /*
                Button {
                    Layout.preferredWidth: 200
                    Layout.preferredHeight: 60
                    
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
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }
                        
                        Label {
                            text: "Añadir Producto"
                            color: whiteColor
                            font.bold: true
                            font.pixelSize: 16
                        }
                    }
                    
                    onClicked: {
                        abrirCrearProducto()
                    }
                    
                    Behavior on scale {
                        NumberAnimation { duration: 100 }
                    }
                }
                */
                
                Rectangle {
                    Layout.preferredWidth: 130
                    Layout.preferredHeight: 50
                    color: "#E3F2FD"
                    radius: 8
                    border.color: blueColor
                    border.width: 1
                    
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        
                        Label {
                            text: "Total Productos:"
                            font.pixelSize: 10
                            color: darkGrayColor
                            Layout.alignment: Qt.AlignHCenter
                        }
                        
                        Label {
                            text: getTotalCount().toString()
                            font.pixelSize: 18
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
                        Layout.preferredWidth: 280
                        Layout.preferredHeight: 36
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
                                font.pixelSize: 14
                                color: darkGrayColor
                            }
                            
                            // ALTERNATIVA: TextEdit configurado para una línea
                            Item {
                                id: searchContainer
                                Layout.fillWidth: true
                                Layout.preferredHeight: 20
                                
                                TextEdit {
                                    id: searchField
                                    anchors.fill: parent
                                    //verticalAlignment: TextEdit.AlignVCenter
                                    selectByMouse: true
                                    font.pixelSize: 12
                                    color: textColor
                                    
                                    // IMPORTANTE: Configurar para una sola línea
                                    clip: true
                                    wrapMode: TextEdit.NoWrap
                                    
                                    onTextChanged: {
                                        searchText = text
                                        console.log("🔍 Búsqueda:", searchText)
                                        updateFilteredModel()
                                    }
                                    
                                    // Placeholder mejor posicionado
                                    Text {
                                        text: "Buscar por nombre o código..."
                                        color: grayMedium
                                        visible: !parent.text
                                        font: parent.font
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: 0
                                    }
                                }
                            }
                            
                            Button {
                                visible: searchField.text.length > 0
                                text: "✕"
                                
                                background: Rectangle {
                                    color: lightGrayColor
                                    radius: 4
                                    width: 20
                                    height: 20
                                }
                                
                                contentItem: Label {
                                    text: parent.text
                                    color: darkGrayColor
                                    font.pixelSize: 10
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                
                                onClicked: {
                                    searchField.text = ""
                                    searchText = ""
                                    updateFilteredModel()
                                    searchField.focus = false  // Quitar foco
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
                            font.pixelSize: 12
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
            
            // Tabla principal de productos 
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
                    
                    // Header de la tabla - AJUSTADO PARA BOTÓN VER
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        color: "#F8F9FA"
                        border.color: "#D5DBDB"
                        border.width: 1
                        
                        RowLayout {
                            anchors.fill: parent
                            spacing: 0
                            
                            Rectangle {
                                Layout.preferredWidth: 40  // Reducido de 50
                                Layout.minimumWidth: 40
                                Layout.maximumWidth: 40
                                Layout.fillHeight: true
                                color: "transparent"
                                border.color: "#D5DBDB"
                                border.width: 1
                                Label {
                                    anchors.centerIn: parent
                                    text: "ID"
                                    color: "#2C3E50"
                                    font.bold: true
                                    font.pixelSize: 10
                                }
                            }
                            
                            Rectangle {
                                Layout.preferredWidth: 70  // Reducido de 80
                                Layout.minimumWidth: 70
                                Layout.maximumWidth: 70
                                Layout.fillHeight: true
                                color: "transparent"
                                border.color: "#D5DBDB"
                                border.width: 1
                                Label {
                                    anchors.centerIn: parent
                                    text: "CÓDIGO"
                                    color: "#2C3E50"
                                    font.bold: true
                                    font.pixelSize: 10
                                }
                            }
                            
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 180  // Aumentado de 150
                                Layout.preferredWidth: 220  // Aumentado de 200
                                Layout.fillHeight: true
                                color: "transparent"
                                border.color: "#D5DBDB"
                                border.width: 1
                                Label {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "NOMBRE"
                                    color: "#2C3E50"
                                    font.bold: true
                                    font.pixelSize: 12
                                }
                            }
                            
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 140  // Aumentado de 120
                                Layout.preferredWidth: 180  // Mantenido
                                Layout.fillHeight: true
                                color: "transparent"
                                border.color: "#D5DBDB"
                                border.width: 1
                                Label {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "DESCRIPCIÓN"
                                    color: "#2C3E50"
                                    font.bold: true
                                    font.pixelSize: 12
                                }
                            }
                            
                            Rectangle {
                                Layout.preferredWidth: 100  // Reducido de 120
                                Layout.minimumWidth: 90   // Reducido de 100
                                Layout.maximumWidth: 110  // Reducido de 140
                                Layout.fillHeight: true
                                color: "transparent"
                                border.color: "#D5DBDB"
                                border.width: 1
                                Label {
                                    anchors.centerIn: parent
                                    text: "PRECIO COMPRA"
                                    color: "#2C3E50"
                                    font.bold: true
                                    font.pixelSize: 10  // Reducido de 11
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                }
                            }
                            
                            Rectangle {
                                Layout.preferredWidth: 100  // Reducido de 120
                                Layout.minimumWidth: 90   // Reducido de 100
                                Layout.maximumWidth: 110  // Reducido de 140
                                Layout.fillHeight: true
                                color: "transparent"
                                border.color: "#D5DBDB"
                                border.width: 1
                                Label {
                                    anchors.centerIn: parent
                                    text: "PRECIO VENTA"
                                    color: "#2C3E50"
                                    font.bold: true
                                    font.pixelSize: 10  // Reducido de 11
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                }
                            }
                            
                            Rectangle {
                                Layout.preferredWidth: 70  // Reducido de 80
                                Layout.minimumWidth: 60   // Reducido de 70
                                Layout.maximumWidth: 75   // Reducido de 90
                                Layout.fillHeight: true
                                color: "transparent"
                                border.color: "#D5DBDB"
                                border.width: 1
                                Label {
                                    anchors.centerIn: parent
                                    text: "STOCK"
                                    color: "#2C3E50"
                                    font.bold: true
                                    font.pixelSize: 11  // Reducido de 12
                                }
                            }
                            
                            Rectangle {
                                Layout.preferredWidth: 70  // Reducido de 80
                                Layout.minimumWidth: 60   // Reducido de 70
                                Layout.maximumWidth: 75   // Reducido de 90
                                Layout.fillHeight: true
                                color: "transparent"
                                border.color: "#D5DBDB"
                                border.width: 1
                                Label {
                                    anchors.centerIn: parent
                                    text: "UNIDAD"
                                    color: "#2C3E50"
                                    font.bold: true
                                    font.pixelSize: 10  // Reducido de 11
                                }
                            }
                            
                            Rectangle {
                                Layout.preferredWidth: 90  // Reducido de 100
                                Layout.minimumWidth: 80   // Reducido de 90
                                Layout.maximumWidth: 100  // Reducido de 120
                                Layout.fillHeight: true
                                color: "transparent"
                                border.color: "#D5DBDB"
                                border.width: 1
                                Label {
                                    anchors.centerIn: parent
                                    text: "MARCA"
                                    color: "#2C3E50"
                                    font.bold: true
                                    font.pixelSize: 11  // Reducido de 12
                                }
                            }

                            // === HEADER ACCIONES - SOLO BOTÓN VER ===
                            Rectangle {
                                Layout.preferredWidth: 80
                                Layout.minimumWidth: 70
                                Layout.maximumWidth: 90
                                Layout.fillHeight: true
                                color: "transparent"
                                border.color: "#D5DBDB"
                                border.width: 1
                                Label {
                                    anchors.centerIn: parent
                                    text: "ACCIONES"
                                    color: "#2C3E50"
                                    font.bold: true
                                    font.pixelSize: 12
                                }
                            }
                        }
                    }
                    
                    // Lista de productos con paginación
                    ListView {
                        id: productosTable
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: productosPaginadosModel
                        
                        delegate: Rectangle {
                            id: delegateItem
                            width: productosTable.width
                            height: 50
                            color: productosTable.currentIndex === index ? "#E3F2FD" : "#FFFFFF"
                            border.color: "#D5DBDB"
                            border.width: 1
                            
                            // ✅ CALCULAR STOCK UNA SOLA VEZ - CON VALIDACIÓN
                            property var stockInfo: {
                                if (model && model.codigo && mapaStock && mapaStock[model.codigo]) {
                                    return mapaStock[model.codigo];
                                }
                                return { stock: 0, color: "#CCCCCC", estado: "SIN DATOS" };
                            }
                            property int stockActual: stockInfo && stockInfo.stock ? stockInfo.stock : 0
                            property color colorStock: stockInfo && stockInfo.color ? stockInfo.color : "#CCCCCC"
                            property string estadoStock: stockInfo && stockInfo.estado ? stockInfo.estado : "SIN DATOS"
                            
                            Rectangle {
                                anchors {
                                    left: parent.left
                                    top: parent.top
                                    bottom: parent.bottom
                                }
                                width: 4
                                color: parent.colorStock
                            }
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 0
                                spacing: 0
                                
                                Rectangle {
                                    Layout.preferredWidth: 40  // Reducido de 50
                                    Layout.minimumWidth: 40
                                    Layout.maximumWidth: 40
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#D5DBDB"
                                    border.width: 1
                                    Label {
                                        anchors.centerIn: parent
                                        text: model.id ? model.id.toString() : ""
                                        color: "#2C3E50"
                                        font.pixelSize: 11  // Reducido de 12
                                        font.bold: true
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 70  // Reducido de 80
                                    Layout.minimumWidth: 70
                                    Layout.maximumWidth: 70
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#D5DBDB"
                                    border.width: 1
                                    Label {
                                        anchors.centerIn: parent
                                        text: model.codigo || ""
                                        color: "#3498DB"
                                        font.bold: true
                                        font.pixelSize: 11  // Reducido de 12
                                    }
                                }
                                
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 180  // Aumentado de 150
                                    Layout.preferredWidth: 220  // Aumentado de 200
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#D5DBDB"
                                    border.width: 1
                                    Label {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 8
                                        anchors.right: parent.right
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: model.nombre || ""
                                        color: "#2C3E50"
                                        font.bold: true
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                        wrapMode: Text.NoWrap
                                    }
                                }
                                
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 140  // Aumentado de 120
                                    Layout.preferredWidth: 180  // Mantenido
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#D5DBDB"
                                    border.width: 1
                                    Label {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 8
                                        anchors.right: parent.right
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: model.detalles || ""
                                        color: "#7f8c8d"
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                        wrapMode: Text.NoWrap
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 100  // Reducido de 120
                                    Layout.minimumWidth: 90   // Reducido de 100
                                    Layout.maximumWidth: 110  // Reducido de 140
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#D5DBDB"
                                    border.width: 1
                                    Label {
                                        anchors.centerIn: parent
                                        text: "Bs " + (model.precioCompra ? model.precioCompra.toFixed(2) : "0.00")
                                        color: "#27AE60"
                                        font.bold: true
                                        font.pixelSize: 10  // Reducido de 11
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 100  // Reducido de 120
                                    Layout.minimumWidth: 90   // Reducido de 100
                                    Layout.maximumWidth: 110  // Reducido de 140
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#D5DBDB"
                                    border.width: 1
                                    Label {
                                        anchors.centerIn: parent
                                        text: "Bs " + (model.precioVenta ? model.precioVenta.toFixed(2) : "0.00")
                                        color: "#F39C12"
                                        font.bold: true
                                        font.pixelSize: 10  // Reducido de 11
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 70  // Reducido de 80
                                    Layout.minimumWidth: 60   // Reducido de 70
                                    Layout.maximumWidth: 75   // Reducido de 90
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#D5DBDB"
                                    border.width: 1
                                    
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 60  // Reducido de 70
                                        height: 22  // Reducido de 24
                                        color: delegateItem.colorStock
                                        radius: 4
                                        
                                        Label {
                                            anchors.centerIn: parent
                                            text: delegateItem.stockActual.toString()
                                            color: "#FFFFFF"
                                            font.bold: true
                                            font.pixelSize: 9  // Reducido de 10
                                        }
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 70  // Reducido de 80
                                    Layout.minimumWidth: 60   // Reducido de 70
                                    Layout.maximumWidth: 75   // Reducido de 90
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#D5DBDB"
                                    border.width: 1
                                    
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: Math.min(55, parent.width - 10)  // Reducido de 60
                                        height: 14
                                        color: "#9b59b6"
                                        radius: 7
                                        
                                        Label {
                                            anchors.centerIn: parent
                                            text: model.unidadMedida || "mg"
                                            color: "#FFFFFF"
                                            font.bold: true
                                            font.pixelSize: 9
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 90  // Reducido de 100
                                    Layout.minimumWidth: 80   // Reducido de 90
                                    Layout.maximumWidth: 100  // Reducido de 120
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#D5DBDB"
                                    border.width: 1
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        anchors.left: parent.left
                                        anchors.leftMargin: 4
                                        anchors.right: parent.right
                                        anchors.rightMargin: 4
                                        text: model.idMarca || "N/A"
                                        color: "#34495e"
                                        font.bold: true
                                        font.pixelSize: 10  // Reducido de 11
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                    }
                                }

                                // === BOTÓN VER (REEMPLAZA LOS 3 BOTONES) ===
                                Rectangle {
                                    Layout.preferredWidth: 80
                                    Layout.minimumWidth: 70
                                    Layout.maximumWidth: 90
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#D5DBDB"
                                    border.width: 1
                                    
                                    Button {
                                        anchors.centerIn: parent
                                        width: Math.min(70, parent.width - 10)
                                        height: 28
                                        text: "Ver"
                                        
                                        background: Rectangle {
                                            color: parent.pressed ? Qt.darker(blueColor, 1.2) : blueColor
                                            radius: 4
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }
                                        
                                        contentItem: Label {
                                            text: parent.text
                                            color: whiteColor
                                            font.bold: true
                                            font.pixelSize: 10
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        
                                        onClicked: {
                                            console.log("📘 Ver producto:", model.codigo)
                                            productoSeleccionado = model
                                            mostrarDetalleProducto(model)
                                        }
                                    }
                                }
                            }
                            
                            // 🔧 MODIFICADO: MouseArea con click derecho para menú contextual
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.RightButton
                                propagateComposedEvents: true
                                
                                onClicked: function(mouse) {
                                    if (mouse.button === Qt.LeftButton) {
                                        productosTable.currentIndex = index
                                        selectedProduct = model
                                        mostrandoMenuContextual = false
                                    } else if (mouse.button === Qt.RightButton) {
                                        productosTable.currentIndex = index
                                        selectedProduct = model
                                        mostrandoMenuContextual = true
                                        productoMenuContextual = model
                                        mouse.accepted = true
                                    }
                                }
                            }
                            
                            // 🔧 CAMBIO 1: Menú contextual con estilo antiguo
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                visible: mostrandoMenuContextual && productoMenuContextual && productoMenuContextual.id === model.id
                                z: 10
                                
                                // Cuadro contenedor estilo menú contextual - altura reducida
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
                                                    console.log("Editando producto:", model.codigo)
                                                    abrirEditarProducto(model)
                                                    mostrandoMenuContextual = false
                                                    productoMenuContextual = null
                                                    selectedProduct = null
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
                                                    console.log("Eliminando producto:", model.codigo)
                                                    confirmarEliminarProducto(model)
                                                    mostrandoMenuContextual = false
                                                    productoMenuContextual = null
                                                    selectedProduct = null
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
                        Layout.preferredHeight: 50
                        color: "#F8F9FA"
                        border.color: "#D5DBDB"
                        border.width: 1
                        
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 20
                            
                            Button {
                                Layout.preferredWidth: 80
                                Layout.preferredHeight: 30
                                text: "← Anterior"
                                enabled: currentPage > 0
                                
                                background: Rectangle {
                                    color: parent.enabled ? 
                                        (parent.pressed ? Qt.darker("#10B981", 1.1) : "#10B981") :   
                                        "#E5E7EB"
                                    radius: 15
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                                
                                contentItem: Label {
                                    text: parent.text
                                    color: parent.enabled ? "#FFFFFF" : "#9CA3AF"
                                    font.bold: true
                                    font.pixelSize: 12
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
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }
                                                            
                            Button {
                                Layout.preferredWidth: 80
                                Layout.preferredHeight: 30
                                text: "Siguiente →"
                                enabled: currentPage < totalPages - 1
                                
                                background: Rectangle {
                                    color: parent.enabled ? 
                                        (parent.pressed ? Qt.darker("#10B981", 1.1) : "#10B981") : 
                                        "#E5E7EB"
                                    radius: 15
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                                
                                contentItem: Label {
                                    text: parent.text
                                    color: parent.enabled ? "#FFFFFF" : "#9CA3AF"
                                    font.bold: true
                                    font.pixelSize: 12
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

        // ===============================
        // DIÁLOGOS (solo para editar precio)
        // ===============================
        
        // Diálogo para Editar Precio de Venta (este se mantiene como Dialog)
        Dialog {
            id: editarPrecioDialog
            anchors.centerIn: parent
            width: Math.min(450, parent.width * 0.8)
            height: Math.min(350, parent.height * 0.6)
            modal: true
            visible: editarPrecioDialogOpen
            closePolicy: Dialog.NoAutoClose
            
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
                anchors.margins: 16
                spacing: 16
                
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16
                    
                    Label {
                        text: "💰"
                        font.pixelSize: 20
                        color: successColor
                    }
                    
                    Label {
                        text: "Editar Precio de Venta"
                        font.pixelSize: 18
                        font.bold: true
                        color: textColor
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    Button {
                        text: "✕"
                        
                        background: Rectangle {
                            color: parent.pressed ? Qt.darker(dangerColor, 1.2) : dangerColor
                            radius: 16
                            width: 32
                            height: 32
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
                            editarPrecioDialogOpen = false
                        }
                    }
                }
                
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 70
                    color: "#F8F9FA"
                    radius: 8
                    border.color: lightGrayColor
                    border.width: 1
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 6
                        
                        Label {
                            text: "Producto: " + (productoSeleccionado ? productoSeleccionado.nombre : "")
                            font.bold: true
                            font.pixelSize: 12
                            color: textColor
                        }
                        
                        Label {
                            text: "Código: " + (productoSeleccionado ? productoSeleccionado.codigo : "")
                            font.pixelSize: 10
                            color: darkGrayColor
                        }
                        
                        Label {
                            text: "Precio Compra: Bs " + (productoSeleccionado ? productoSeleccionado.precioCompra.toFixed(2) : "0.00")
                            font.pixelSize: 10
                            color: successColor
                        }
                    }
                }
                
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    
                    Label {
                        text: "Nuevo Precio de Venta:"
                        font.bold: true
                        color: textColor
                        font.pixelSize: 12
                    }
                    
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        color: whiteColor
                        border.color: warningColor
                        border.width: 2
                        radius: 8
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8
                            
                            Label {
                                text: "Bs"
                                font.bold: true
                                font.pixelSize: 16
                                color: textColor
                            }
                            
                            TextField {
                                id: precioVentaEditField
                                Layout.fillWidth: true
                                font.pixelSize: 14
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
                    spacing: 10
                    
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
                            color: parent.enabled ? whiteColor : darkGrayColor
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
        
        // ===================================================
        // DIALOG DE CONFIRMACIÓN DE ELIMINACIÓN
        // ===================================================
        Dialog {
            id: confirmDialog
            visible: confirmDialogVisible
            modal: true
            anchors.centerIn: parent
            width: Math.min(parent.width * 0.8, 500)
            height: Math.min(parent.height * 0.5, 300)
            closePolicy: Dialog.NoAutoClose
            
            background: Rectangle {
                color: whiteColor
                radius: 12
                border.color: lightGrayColor
                border.width: 1
                
                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 2
                    anchors.leftMargin: 2
                    color: "#00000015"
                    radius: 12
                    z: -1
                }
            }
            
            header: Rectangle {
                color: "#F8F9FA"
                height: 50
                radius: 12
                
                Label {
                    anchors.centerIn: parent
                    text: confirmDialogTitle
                    font.pixelSize: 16
                    font.bold: true
                    color: textColor
                }
            }
            
            contentItem: ColumnLayout {
                spacing: 5
                
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 20
                    color: "transparent"
                    
                    RowLayout {
                        anchors.fill: parent
                        spacing: 12
                        
                        Rectangle {
                            width: 40
                            height: 40
                            color: '#f82020'
                            radius: 20
                            
                            Label {
                                anchors.centerIn: parent
                                text: "⚠️"
                                font.pixelSize: 20
                                color: dangerColor
                            }
                        }
                        
                        Label {
                            Layout.fillWidth: true
                            text: confirmDialogMessage
                            wrapMode: Text.WordWrap
                            font.pixelSize: 13
                            color: textColor
                        }
                    }
                }
            }
            
            footer: DialogButtonBox {
                alignment: Qt.AlignCenter
                
                Button {
                    text: "Cancelar"
                    DialogButtonBox.buttonRole: DialogButtonBox.RejectRole
                    
                    background: Rectangle {
                        color: parent.pressed ? Qt.darker(darkGrayColor, 1.2) : darkGrayColor
                        radius: 6
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        color: whiteColor
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                
                Button {
                    text: "Eliminar"
                    DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
                    
                    background: Rectangle {
                        color: parent.pressed ? Qt.darker(dangerColor, 1.2) : dangerColor
                        radius: 6
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        color: whiteColor
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
            
            onAccepted: {
                console.log("✅ Acción confirmada:", confirmDialogAccion)
                
                if (confirmDialogAccion === "eliminar_producto") {
                    eliminarProductoConfirmado()
                }
            }
            
            onRejected: {
                console.log("❌ Acción cancelada")
                confirmDialogVisible = false
                productoParaEliminar = null
            }
        }
    }

    // ===============================
    // FUNCIONES PARA DETALLE DE PRODUCTO
    // ===============================
    
    function mostrarDetalleProducto(producto) {
        console.log("👁️ Mostrando detalle de:", producto.codigo)
        
        productoParaDetalle = {
            id: producto.id,
            codigo: producto.codigo,
            nombre: producto.nombre,
            detalles: producto.detalles,
            stockUnitario: producto.stock || 0,
            precioVenta: producto.precioVenta,
            precioCompra: producto.precioCompra,
            unidadMedida: producto.unidadMedida,
            idMarca: producto.idMarca,
            stockMinimo: producto.stockMinimo
        }
        
        mostrandoDetalleProducto = true
    }

    function cerrarDetalleProducto() {
        console.log("❌ Cerrando detalle de producto")
        mostrandoDetalleProducto = false
        productoParaDetalle = null
    }

    // ===============================
    // 🔧 CAMBIO 2: Loader de DetalleProducto simplificado
    // ===============================
    Loader {
        id: detalleProductoLoader
        anchors.fill: parent
        z: 2000
        active: mostrandoDetalleProducto
        source: mostrandoDetalleProducto ? "DetalleProducto.qml" : ""
        
        onLoaded: {
            if (item) {
                console.log("🔍 DetalleProducto.qml cargado")
                item.inventarioModel = productosRoot.inventarioModel
                item.productoData = productoParaDetalle
                item.mostrarStock = true
                item.mostrarAcciones = true
                
                // Conectar señal de cerrar
                if (item.cerrarSolicitado) {
                    item.cerrarSolicitado.connect(function() {
                        mostrandoDetalleProducto = false
                        productoParaDetalle = null
                    })
                }
            }
        }
    }
    
    // ===============================
    // MODAL PARA EDITAR LOTE
    // ===============================
    Rectangle {
        id: editarLoteContainer
        anchors.fill: parent
        z: 3000
        visible: mostrandoEditarLote
        color: "#80000000" // Fondo oscuro semi-transparente
        
        Rectangle {
            anchors.centerIn: parent
            width: Math.min(600, parent.width * 0.8)
            height: Math.min(500, parent.height * 0.8)
            radius: 12
            color: whiteColor
            // Quitamos el borde externo para que no choque con el diseño del diálogo
            border.width: 0 
            clip: true // Asegura que el contenido del Loader respete el radio de las esquinas

            Loader {
                id: editarLoteLoader
                anchors.fill: parent
                source: mostrandoEditarLote ? "EditarLoteDialog.qml" : ""
                
                onLoaded: {
                    if (item) {
                        console.log("✏️ EditarLoteDialog.qml cargado")
                        item.inventarioModel = inventarioModel
                        item.loteData = loteParaEditar
                    }
                }
            }
        }
    }

    // ✅ LOADER DE EDITAR PRODUCTO - V2.0 (solo para edición)
    Rectangle {
        id: editarProductoContainer
        anchors.fill: parent
        z: 1000
        visible: modoEdicionProducto
        color: "transparent"
        
        Loader {
            id: crearProductoLoader
            anchors.fill: parent
            active: modoEdicionProducto
            
            sourceComponent: modoEdicionProducto ? crearProductoComponent : null
            
            Component {
                id: crearProductoComponent
                
                CrearProducto {
                    anchors.fill: parent
                    
                    inventarioModel: productosRoot.inventarioModel
                    farmaciaData: productosRoot.farmaciaData
                    modoEdicion: modoEdicionProducto
                    productoData: productoParaEditar
                    
                    onProductoActualizado: function(producto) {
                        console.log("📦 Producto actualizado:", producto.codigo || producto.Codigo)
                        productoActualizado(producto)
                    }
                    
                    onCancelarCreacion: {
                        console.log("❌ Edición cancelada")
                        cerrarEditarProducto()
                    }
                }
            }
            
            onLoaded: {
                if (item) {
                    console.log("🚀 CrearProducto.qml cargado en modo edición...")
                    
                    // ✅ CRÍTICO: Asignar marcasModel DIRECTAMENTE desde inventarioModel
                    if (inventarioModel && inventarioModel.marcasDisponibles) {
                        item.marcasModel = inventarioModel.marcasDisponibles
                        item.marcasCargadas = true
                        console.log("🏷️ Marcas asignadas directamente:", inventarioModel.marcasDisponibles.length)
                    }
                    
                    if (modoEdicionProducto && productoParaEditar) {
                        item.inicializarParaEditar(productoParaEditar)
                    }
                }
            }
        }
    }
    
    Connections {
        target: editarLoteLoader.item
        enabled: editarLoteLoader.item !== null
        
        function onLoteActualizado(datosActualizados) {
            console.log("✅ Lote actualizado, recargando DetalleProducto")
            
            // ✅ SIMPLIFICADO: Solo validar que el loader exista
            if (detalleProductoLoader.item && detalleProductoLoader.item.cargarDatosProducto) {
                detalleProductoLoader.item.cargarDatosProducto()
            }
            
            // Cerrar el diálogo de edición
            mostrandoEditarLote = false
            loteParaEditar = null
        }
        
        function onCancelado() {
            console.log("❌ Edición de lote cancelada")
            mostrandoEditarLote = false
            loteParaEditar = null
        }
    }
    
    Rectangle {
        id: notificacionFlotante
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 80
        
        width: Math.min(400, parent.width - 32)
        height: 50
        
        color: mensajeColor
        radius: 25
        
        visible: mostrandoMensaje
        opacity: mostrandoMensaje ? 1.0 : 0.0
        
        z: 2000
        
        Behavior on opacity {
            NumberAnimation { duration: 300 }
        }
        
        // Sombra
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 2
            color: "#00000030"
            radius: 25
            z: -1
        }
        
        RowLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12
            
            Label {
                text: {
                    switch(mensajeTipo) {
                        case "success": return "✅"
                        case "error": return "❌" 
                        case "warning": return "⚠️"
                        default: return "ℹ️"
                    }
                }
                font.pixelSize: 18
                color: whiteColor
            }
            
            Label {
                Layout.fillWidth: true
                text: mensajeTexto
                font.pixelSize: 12
                font.bold: true
                color: whiteColor
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }
        
        MouseArea {
            anchors.fill: parent
            onClicked: mostrandoMensaje = false
        }
    }

    // ✅ NUEVA FUNCIÓN: PRECALCULAR STOCK (evita binding loops)
    function precalcularStock() {
        console.log("📊 Precalculando stock de productos...")
        
        if (!inventarioModel || typeof inventarioModel.obtener_stock_actual !== 'function') {
            console.log("⚠️ InventarioModel no disponible")
            return
        }
        
        var datosStock = inventarioModel.obtener_stock_actual() || []
        console.log("📦 Datos de stock recibidos:", datosStock.length , "productos")
        
        // ✅ NUEVO DEBUG: Ver TODOS los códigos recibidos
        console.log("📋 Códigos recibidos:")
        for (var j = 0; j < datosStock.length; j++) {
            console.log("   -", datosStock[j].Codigo || datosStock[j].codigo, "| Stock:", datosStock[j].Stock_Real || datosStock[j].stock)
        }
        
        var nuevoMapa = {}
        
        for (var i = 0; i < datosStock.length; i++) {
            var producto = datosStock[i]
            
            // ✅ USAR COLUMNAS CORRECTAS DEL BACKEND - CON VALIDACIÓN
            var codigo = producto.Codigo || producto.codigo || ""
            if (!codigo) continue; // Saltar si no hay código
            
            var stock = producto.Stock_Real || producto.Stock_Total || producto.stock || 0
            var stockMin = producto.Stock_Minimo || producto.stock_minimo || 10
            var stockMax = producto.Stock_Maximo || producto.stock_maximo || 100
            
            var estado = "NORMAL"
            var color = stockNormalColor
            
            // Calcular estado según stock
            if (stock <= 0) {
                estado = "CRÍTICO"
                color = stockCriticoColor
            } else if (stock <= stockMin) {
                estado = "CRÍTICO"
                color = stockCriticoColor
            } else if (stock <= (stockMin + (stockMax - stockMin) * 0.3)) {
                estado = "BAJO"
                color = stockBajoColor
            }
            
            nuevoMapa[codigo] = {
                stock: stock,
                color: color,
                estado: estado
            }
            
            // Debug primeros 3 productos
            if (i < 3) {
                console.log("   🔍", codigo, "- Stock:", stock, "Estado:", estado)
            }
        }
        
        mapaStock = nuevoMapa
        stockCalculado = true
        
        console.log("✅ Stock precalculado para", Object.keys(mapaStock).length, "productos")
    }

    // ===============================
    // FUNCIONES PARA MODALES
    // ===============================

    function abrirEditarLote(lote) {
        console.log("✏️ Abriendo edición de lote:", lote.id || lote.Id_Lote)
        console.log("📦 Objeto lote completo:", JSON.stringify(lote))
        
        // ✅ Asignar PRIMERO el lote
        loteParaEditar = lote
        
        // ✅ Esperar un frame antes de mostrar el diálogo
        Qt.callLater(function() {
            mostrandoEditarLote = true
        })
    }

    function eliminarLote(lote) {
        console.log("🗑️ Eliminando lote:", lote.id || lote.Id_Lote)
        
        if (!inventarioModel) {
            console.log("❌ InventarioModel no disponible")
            return
        }
        
        var loteId = lote.id || lote.Id_Lote
        var exito = inventarioModel.eliminar_lote(loteId)
        
        if (exito) {
            console.log("✅ Lote eliminado exitosamente")
            mostrarMensajeExito("Lote eliminado correctamente")
            
            // Recargar datos
            if (inventarioModel) {
                inventarioModel.refresh_productos()
            }
            
            // ✅ CRÍTICO: Recargar DetalleProducto si está visible
            if (mostrandoDetalleProducto && detalleProductoLoader.item) {
                console.log("🔄 Forzando recarga de DetalleProducto después de eliminar lote")
                Qt.callLater(function() {
                    detalleProductoLoader.item.cargarDatosProducto()
                })
            }
            
            Qt.callLater(function() {
                precalcularStock()
                cargarDatosParaFiltros()
                actualizarDesdeDataCentral()
            })
        } else {
            console.log("❌ Error eliminando lote")
            mostrarMensajeError("Error al eliminar el lote")
        }
    }
    
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
            // SIN CAJAS: solo verificar stock unitario
            if ((lote.Cantidad_Unitario || lote.Stock_Lote || 0) > 0) {
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
            // SIN CAJAS: solo verificar stock unitario
            if ((lote.Cantidad_Unitario || lote.Stock_Lote || 0) > 0) {
                productosUnicos.add(lote.Codigo)
            }
        }
        
        return productosUnicos.size
    }

    function getBajoStockCount() {
        if (!datosLotesCargados) return 0
        return productosConLotesBajoStock.length
    }

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

    function esProximoVencer(producto) {
        if (!producto || !producto.codigo || !datosLotesCargados) return false
        
        for (var i = 0; i < lotesProximosVencer.length; i++) {
            var lote = lotesProximosVencer[i]
            // SIN CAJAS: solo cantidad unitaria
            var stockLote = lote.Cantidad_Unitario || lote.Stock_Lote || 0
            if (lote.Codigo === producto.codigo && stockLote > 0) {
                return true
            }
        }     
        return false
    }

    function esVencido(producto) {
        if (!producto || !producto.codigo || !datosLotesCargados) return false
        
        for (var i = 0; i < lotesVencidos.length; i++) {
            var lote = lotesVencidos[i]
            // SIN CAJAS: solo cantidad unitaria
            var stockLote = lote.Cantidad_Unitario || lote.Stock_Lote || 0
            if (lote.Codigo === producto.codigo && stockLote > 0) {
                return true
            }
        }     
        return false
    }

    function esBajoStock(producto) {
        if (!producto || !producto.codigo || !productosConLotesBajoStock) return false
        
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
    
    property bool mostrandoMensaje: false
    property string mensajeTexto: ""
    property string mensajeTipo: "info" // "success", "error", "warning", "info"
    property color mensajeColor: blueColor

    Timer {
        id: mensajeTimer
        interval: 4000
        onTriggered: mostrandoMensaje = false
    }

    function mostrarMensajeExito(mensaje) {
        mensajeTexto = mensaje
        mensajeTipo = "success"
        mensajeColor = successColor
        mostrandoMensaje = true
        mensajeTimer.restart()
        console.log("✅ Mensaje éxito:", mensaje)
    }

    function mostrarMensajeError(mensaje) {
        mensajeTexto = mensaje
        mensajeTipo = "error"
        mensajeColor = dangerColor
        mostrandoMensaje = true
        mensajeTimer.restart()
        console.log("❌ Mensaje error:", mensaje)
    }

    function mostrarMensajeWarning(mensaje) {
        mensajeTexto = mensaje
        mensajeTipo = "warning"
        mensajeColor = warningColor
        mostrandoMensaje = true
        mensajeTimer.restart()
        console.log("⚠️ Mensaje warning:", mensaje)
    }

    // FilterButton component
    component FilterButton: Rectangle {
        property string text: ""
        property int count: 0
        property bool active: false
        property color backgroundColor: blueColor
        signal clicked()
        
        Layout.preferredHeight: 32
        Layout.preferredWidth: implicitWidth + 16
        
        property int implicitWidth: textLabel.implicitWidth + countLabel.implicitWidth + 32
        
        color: active ? backgroundColor : "transparent"
        border.color: backgroundColor
        border.width: 2
        radius: 16
        
        Behavior on color { ColorAnimation { duration: 200 } }
        
        RowLayout {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 6
            
            Label {
                id: textLabel
                text: parent.parent.text
                color: active ? whiteColor : backgroundColor
                font.bold: true
                font.pixelSize: 11
                Behavior on color { ColorAnimation { duration: 200 } }
            }
            
            Rectangle {
                id: countLabel
                Layout.preferredWidth: 20
                Layout.preferredHeight: 16
                color: active ? whiteColor : backgroundColor
                radius: 8
                Behavior on color { ColorAnimation { duration: 200 } }
                
                Label {
                    anchors.centerIn: parent
                    text: parent.parent.parent.count.toString()
                    color: active ? backgroundColor : whiteColor
                    font.bold: true
                    font.pixelSize: 14
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }
        }
        
        MouseArea {
            anchors.fill: parent
            onClicked: parent.clicked()
        }
    }

    function cargarPreciosYMargenes() {
        if (!productoData) return
        
        try {
            // Precio de venta desde productoData
            precioVenta = productoData.precioVenta || productoData.Precio_venta || 0.0
            
            // ✅ NUEVO: Calcular costo promedio desde los lotes cargados
            if (lotesData && lotesData.length > 0) {
                var sumaCostos = 0
                var totalUnidades = 0
                
                for (var i = 0; i < lotesData.length; i++) {
                    var lote = lotesData[i]
                    var stock = lote.Stock_Lote || 0
                    var precio = lote.Precio_Compra || 0
                    
                    if (stock > 0) {
                        sumaCostos += (stock * precio)
                        totalUnidades += stock
                    }
                }
                
                if (totalUnidades > 0) {
                    costoPromedio = sumaCostos / totalUnidades
                    console.log("💰 Costo promedio calculado desde lotes:", costoPromedio)
                } else {
                    costoPromedio = 0
                    console.log("⚠️ No hay stock en lotes para calcular costo")
                }
            } else {
                costoPromedio = 0
                console.log("⚠️ No hay lotes para calcular costo promedio")
            }
            
            // Calcular margen
            if (precioVenta > 0 && costoPromedio > 0) {
                margenActual = precioVenta - costoPromedio
                porcentajeMargen = (margenActual / costoPromedio) * 100
            } else {
                margenActual = 0
                porcentajeMargen = 0
            }
            
            console.log("📊 Precios y márgenes:")
            console.log("   - Precio venta:", precioVenta)
            console.log("   - Costo promedio:", costoPromedio)
            console.log("   - Margen:", margenActual, "(", porcentajeMargen.toFixed(1), "%)")
            
        } catch (error) {
            console.log("❌ Error calculando precios:", error.toString())
        }
    }

    Component.onCompleted: {
        console.log("📦 Módulo Productos FIFO 2.0 V2.0 iniciado")
        console.log("   InventarioModel:", !!inventarioModel)
        console.log("   FarmaciaData:", !!farmaciaData)
        
        Qt.callLater(function() {
            if (inventarioModel) {
                precalcularStock()  // ✅ CALCULAR PRIMERO
                cargarMarcasDesdeModel()
                cargarDatosParaFiltros()
                actualizarDesdeDataCentral()
            }
        })
    }
}