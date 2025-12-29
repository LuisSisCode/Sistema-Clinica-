import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// 🔍 DETALLEPRODUCTO.QML - FIFO 2.0 (CON DIÁLOGO DE CONFIRMACIÓN INTEGRADO)

Rectangle {
    id: detalleProductoComponent
    anchors.fill: parent
    color: "#80000000"
    z: 1000
    
    // ===============================
    // PROPIEDADES PÚBLICAS
    // ===============================
    
    property var productoData: null
    property bool mostrarStock: true
    property bool mostrarAcciones: true
    property var inventarioModel: null
    
    // PROPIEDADES PARA LOTES FIFO 2.0
    property var lotesData: []
    property bool lotesLoaded: false
    property bool loadingLotes: false
    
    // PROPIEDADES PARA PRECIOS Y MÁRGENES
    property real costoPromedio: 0.0
    property real precioVenta: 0.0
    property real margenActual: 0.0
    property real porcentajeMargen: 0.0
    property bool editandoPrecio: false
    
    // PROPIEDADES PARA DIÁLOGO DE CONFIRMACIÓN
    property bool mostrandoConfirmacion: false
    property string confirmacionTitulo: ""
    property string confirmacionMensaje: ""
    property string confirmacionDetalle: ""
    property var confirmacionDatos: null
    property var confirmacionCallback: null
    
    // CONTROL DE CARGA INICIAL
    property bool datosInicialmenteCargados: false
    
    // ===============================
    // SEÑALES
    // ===============================
    
    signal editarSolicitado(var producto)
    signal eliminarSolicitado(var producto)
    signal cerrarSolicitado()
    signal editarLoteSolicitado(var lote)
    signal eliminarLoteSolicitado(var lote)
    
    // ===============================
    // FUNCIONES
    // ===============================
    
    function cargarDatosProducto() {
        if (!productoData || !inventarioModel) {
            console.log("❌ No se pueden cargar datos")
            return
        }
        
        loadingLotes = true
        
        try {
            console.log("🔄 Cargando datos del producto:", productoData.codigo)
            
            // 1. Cargar lotes usando FIFO 2.0
            cargarLotesFIFO()
            
            // 2. Cargar datos de precios y márgenes
            cargarPreciosYMargenes()
            
        } catch (error) {
            console.log("❌ Error cargando datos:", error.toString())
        } finally {
            loadingLotes = false
        }
    }
    
    function cargarLotesFIFO() {
        if (!productoData || !productoData.id) {
            console.log("❌ No hay ID de producto para cargar lotes")
            return
        }
        
        try {
            console.log("📦 Cargando lotes FIFO 2.0 para producto ID:", productoData.id)
            
            // Llamar a método FIFO 2.0
            var lotes = inventarioModel.obtener_lotes_activos_vista(productoData.id)
            
            if (lotes) {
                lotesData = lotes
                lotesLoaded = true
                
                console.log("✅ Lotes cargados:", lotes.length)
                
                // Debug: mostrar estructura de lotes
                if (lotes.length > 0) {
                    console.log("   Primer lote:", JSON.stringify(lotes[0]))
                }
            } else {
                lotesData = []
                lotesLoaded = true
                console.log("⚠️ No se obtuvieron lotes")
            }
            
        } catch (error) {
            console.log("❌ Error cargando lotes FIFO:", error.toString())
            lotesData = []
            lotesLoaded = false
        }
    }
    
    function cargarPreciosYMargenes() {
        if (!productoData) return
        
        try {
            // Precio de venta desde productoData
            precioVenta = productoData.precioVenta || productoData.Precio_venta || 0.0
            
            // Obtener costo promedio desde vw_Costo_Inventario
            var valoracion = inventarioModel.obtener_costo_inventario()
            
            if (valoracion) {
                for (var i = 0; i < valoracion.length; i++) {
                    var item = valoracion[i]
                    if (item.Id_Producto === productoData.id || item.Codigo === productoData.codigo) {
                        costoPromedio = item.Costo_Promedio || 0.0
                        console.log("💰 Costo promedio encontrado:", costoPromedio)
                        break
                    }
                }
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
            console.log("❌ Error cargando precios:", error.toString())
        }
    }
    
    function limpiarDatos() {
        lotesData = []
        lotesLoaded = false
        costoPromedio = 0.0
        precioVenta = 0.0
        margenActual = 0.0
        porcentajeMargen = 0.0
    }
    
    function obtenerColorEstadoVencimiento(estadoVenc) {
        switch(estadoVenc) {
            case "VENCIDO":
                return "#FF0000"
            case "PRÓXIMO A VENCER":
                return "#FFA500"
            case "VIGENTE":
                return "#00AA00"
            default:
                return "#7f8c8d"
        }
    }
    
    function obtenerTextoEstadoVencimiento(estadoVenc) {
        if (!estadoVenc) return "DESCONOCIDO"
        return estadoVenc
    }
    
    function formatearDiasParaVencer(dias) {
        if (dias === null || dias === undefined) return "---"
        
        var diasNum = parseInt(dias)
        
        if (isNaN(diasNum)) return "---"
        if (diasNum < 0) return "VENCIDO"
        if (diasNum === 0) return "HOY"
        if (diasNum === 1) return "1 día"
        return diasNum + " días"
    }
    
    function actualizarPrecioVenta(nuevoPrecio) {
        if (!productoData || !inventarioModel) {
            console.log("❌ No se puede actualizar precio")
            return false
        }
        
        try {
            var precio = parseFloat(nuevoPrecio)
            
            if (isNaN(precio) || precio <= 0) {
                console.log("❌ Precio inválido")
                return false
            }
            
            console.log("💰 Actualizando precio de venta a:", precio)
            
            var resultado = inventarioModel.actualizar_precio_venta(productoData.codigo, precio)
            
            if (resultado) {
                precioVenta = precio
                
                // Recalcular margen
                if (costoPromedio > 0) {
                    margenActual = precioVenta - costoPromedio
                    porcentajeMargen = (margenActual / costoPromedio) * 100
                }
                
                console.log("✅ Precio actualizado exitosamente")
                return true
            } else {
                console.log("❌ Error actualizando precio")
                return false
            }
            
        } catch (error) {
            console.log("❌ Error:", error.toString())
            return false
        }
    }
    
    // FUNCIONES PARA DIÁLOGO DE CONFIRMACIÓN
    function mostrarConfirmacionEliminarLote(lote) {
        console.log("🗑️ Mostrando confirmación para eliminar lote:", lote.Id_Lote || lote.id)
        
        var loteId = lote.Id_Lote || lote.id || 0
        var stockLote = lote.Stock_Lote || lote.Stock_Actual || lote.Cantidad_Unitario || 0
        var productoNombre = lote.Producto_Nombre || lote.Producto || "producto"
        
        confirmacionTitulo = "Eliminar Lote"
        confirmacionMensaje = "¿Está seguro de eliminar el lote #" + loteId + "?"
        confirmacionDetalle = "Producto: " + productoNombre + "\n" +
                              "Stock: " + stockLote + " unidades\n" +
                              "Esta acción no se puede deshacer."
        confirmacionDatos = lote
        
        // Definir callback para confirmación
        confirmacionCallback = function() {
            console.log("✅ Confirmado eliminar lote:", loteId)
            eliminarLoteSolicitado(lote)
        }
        
        mostrandoConfirmacion = true
    }
    
    function cerrarConfirmacion() {
        mostrandoConfirmacion = false
        confirmacionTitulo = ""
        confirmacionMensaje = ""
        confirmacionDetalle = ""
        confirmacionDatos = null
        confirmacionCallback = null
    }
    
    // ===============================
    // EVENTOS
    // ===============================
    
    Component.onCompleted: {
        console.log("=== DETALLE PRODUCTO FIFO 2.0 CARGADO ===")
        console.log("  - Producto inicial:", productoData ? productoData.codigo : "NULL")
        console.log("  - InventarioModel disponible:", !!inventarioModel)
    }
    
    onProductoDataChanged: {
        if (productoData && inventarioModel && !datosInicialmenteCargados) {
            console.log("📦 Producto asignado por primera vez:", productoData.codigo)
            datosInicialmenteCargados = true
            Qt.callLater(cargarDatosProducto)
        }
    }

    Connections {
        target: inventarioModel
        
        function onOperacionExitosa(mensaje) {
            console.log("✅ Operación exitosa:", mensaje)
            if (mensaje.includes("lote") || mensaje.includes("precio")) {
                Qt.callLater(cargarDatosProducto)
            }
        }
    }
    
    // ===============================
    // LAYOUT PRINCIPAL (REDISEÑADO)
    // ===============================
    
    Rectangle {
        anchors.centerIn: parent
        width: 900
        height: 700
        radius: 12
        color: "white"
        
        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            
            // ========== HEADER ==========
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                color: "#2c3e50"
                radius: 12
                
                // Redondear solo arriba
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 12
                    color: parent.color
                }
                
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    spacing: 12
                    
                    Image {
                        source: "Resources/iconos/productos.png"
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        fillMode: Image.PreserveAspectFit
                    }
                    
                    Column {
                        Layout.fillWidth: true
                        spacing: 2
                        
                        Label {
                            text: productoData ? productoData.nombre : "Detalle de Producto"
                            font.pixelSize: 18
                            font.bold: true
                            color: "white"
                        }
                        
                        Label {
                            text: productoData ? "Código: " + productoData.codigo : ""
                            font.pixelSize: 12
                            color: "white"
                            opacity: 0.9
                        }
                    }
                    
                    Button {
                        text: "✕"
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        
                        background: Rectangle {
                            color: parent.pressed ? "#E5E7EB" : "transparent"
                            border.color: "white"
                            border.width: 1
                            radius: 8
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            color: "white"
                            font.pixelSize: 18
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
            
            // ========== CONTENT ==========
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                
                ColumnLayout {
                    width: parent.width - 40
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 20
                    anchors.topMargin: 20
                    anchors.bottomMargin: 20
                    
                    // === WIDGET DE PRECIOS Y MÁRGENES ===
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 200
                        color: "#f8f9fa"
                        radius: 8
                        border.color: "#dee2e6"
                        border.width: 1
                        
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 16
                            
                            Label {
                                text: "💰 PRECIOS Y MÁRGENES"
                                font.pixelSize: 14
                                font.bold: true
                                color: "#2c3e50"
                            }
                            
                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: "#dee2e6"
                            }
                            
                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2
                                rowSpacing: 16
                                columnSpacing: 32
                                
                                // Precio Venta
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    
                                    Label {
                                        text: "Precio de Venta"
                                        font.pixelSize: 13
                                        color: "#7f8c8d"
                                    }
                                    
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        
                                        Label {
                                            text: "Bs " + precioVenta.toFixed(2)
                                            font.pixelSize: 20
                                            font.bold: true
                                            color: "#2c3e50"
                                            visible: !editandoPrecio
                                        }
                                        
                                        TextField {
                                            id: precioVentaField
                                            Layout.preferredWidth: 140
                                            Layout.preferredHeight: 40
                                            text: precioVenta.toFixed(2)
                                            font.pixelSize: 16
                                            visible: editandoPrecio
                                            
                                            validator: DoubleValidator {
                                                bottom: 0.01
                                                top: 999999.99
                                                decimals: 2
                                                notation: DoubleValidator.StandardNotation
                                            }
                                            
                                            background: Rectangle {
                                                color: "white"
                                                border.color: parent.activeFocus ? "#3498db" : "#dee2e6"
                                                border.width: 1
                                                radius: 4
                                            }
                                        }
                                        
                                        Button {
                                            text: editandoPrecio ? "💾" : "✏️"
                                            Layout.preferredWidth: 44
                                            Layout.preferredHeight: 40
                                            
                                            background: Rectangle {
                                                color: parent.pressed ? "#2980b9" : "#3498db"
                                                radius: 4
                                            }
                                            
                                            contentItem: Label {
                                                text: parent.text
                                                color: "white"
                                                font.pixelSize: 14
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            
                                            onClicked: {
                                                if (editandoPrecio) {
                                                    // Guardar
                                                    if (actualizarPrecioVenta(precioVentaField.text)) {
                                                        editandoPrecio = false
                                                    }
                                                } else {
                                                    // Editar
                                                    editandoPrecio = true
                                                    precioVentaField.forceActiveFocus()
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                // Costo Promedio
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    
                                    Label {
                                        text: "Costo Promedio"
                                        font.pixelSize: 13
                                        color: "#7f8c8d"
                                    }
                                    
                                    Label {
                                        text: "Bs " + costoPromedio.toFixed(2)
                                        font.pixelSize: 20
                                        font.bold: true
                                        color: "#f39c12"
                                    }
                                }
                                
                                // Margen
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    
                                    Label {
                                        text: "Margen Actual"
                                        font.pixelSize: 13
                                        color: "#7f8c8d"
                                    }
                                    
                                    Label {
                                        text: "Bs " + margenActual.toFixed(2) + " (" + porcentajeMargen.toFixed(1) + "%)"
                                        font.pixelSize: 20
                                        font.bold: true
                                        color: margenActual > 0 ? "#27ae60" : "#e74c3c"
                                    }
                                }
                            }
                        }
                    }
                    
                    // === INFORMACIÓN DEL PRODUCTO ===
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: infoGrid.height + 32
                        color: "white"
                        radius: 8
                        border.color: "#dee2e6"
                        border.width: 1
                        
                        GridLayout {
                            id: infoGrid
                            anchors.fill: parent
                            anchors.margins: 16
                            columns: 2
                            rowSpacing: 12
                            columnSpacing: 24
                            
                            Label {
                                text: "Marca:"
                                font.pixelSize: 12
                                color: "#7f8c8d"
                            }
                            
                            Label {
                                text: productoData ? (productoData.marca || "Sin marca") : ""
                                font.pixelSize: 12
                                font.bold: true
                                color: "#2c3e50"
                            }
                            
                            Label {
                                text: "Stock Total:"
                                font.pixelSize: 12
                                color: "#7f8c8d"
                            }
                            
                            Label {
                                text: productoData ? (productoData.stockUnitario || 0) + " unidades" : "0"
                                font.pixelSize: 12
                                font.bold: true
                                color: "#2c3e50"
                            }
                            
                            Label {
                                text: "Lotes Activos:"
                                font.pixelSize: 12
                                color: "#7f8c8d"
                            }
                            
                            Label {
                                text: lotesData ? lotesData.length : 0
                                font.pixelSize: 12
                                font.bold: true
                                color: "#3498db"
                            }
                        }
                    }
                    
                    // === TABLA DE LOTES FIFO 2.0 ===
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 400
                        color: "white"
                        radius: 8
                        border.color: "#dee2e6"
                        border.width: 1
                        
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12
                            
                            RowLayout {
                                Layout.fillWidth: true
                                
                                Label {
                                    text: "📦 LOTES ACTIVOS (FIFO 2.0)"
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: "#2c3e50"
                                }
                                
                                Item { Layout.fillWidth: true }
                                
                                Label {
                                    text: lotesLoaded ? (lotesData.length + " lotes") : "Cargando..."
                                    font.pixelSize: 12
                                    color: "#7f8c8d"
                                }
                            }
                            
                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: "#dee2e6"
                            }
                            
                            // Header de tabla
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 36
                                color: "#f8f9fa"
                                radius: 4
                                
                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 0
                                    
                                    Rectangle {
                                        Layout.preferredWidth: 60
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        Label {
                                            anchors.centerIn: parent
                                            text: "LOTE #"
                                            font.pixelSize: 10
                                            font.bold: true
                                            color: "#495057"
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: 80
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        Label {
                                            anchors.centerIn: parent
                                            text: "STOCK"
                                            font.pixelSize: 10
                                            font.bold: true
                                            color: "#495057"
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: 90
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        Label {
                                            anchors.centerIn: parent
                                            text: "P. COMPRA"
                                            font.pixelSize: 10
                                            font.bold: true
                                            color: "#495057"
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: 100
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        Label {
                                            anchors.centerIn: parent
                                            text: "F. COMPRA"
                                            font.pixelSize: 10
                                            font.bold: true
                                            color: "#495057"
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: 100
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        Label {
                                            anchors.centerIn: parent
                                            text: "DÍAS P/VENCER"
                                            font.pixelSize: 10
                                            font.bold: true
                                            color: "#495057"
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: 110
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        Label {
                                            anchors.centerIn: parent
                                            text: "ESTADO"
                                            font.pixelSize: 10
                                            font.bold: true
                                            color: "#495057"
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        Label {
                                            anchors.centerIn: parent
                                            text: "ACCIONES"
                                            font.pixelSize: 10
                                            font.bold: true
                                            color: "#495057"
                                        }
                                    }
                                }
                            }
                            
                            // Lista de lotes
                            ListView {
                                id: lotesListView
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                spacing: 2
                                
                                model: lotesData
                                
                                delegate: Rectangle {
                                    width: lotesListView.width
                                    height: 45
                                    color: index % 2 === 0 ? "#ffffff" : "#f8f9fa"
                                    border.color: "#dee2e6"
                                    border.width: 1
                                    
                                    property var loteActual: modelData
                                    
                                    RowLayout {
                                        anchors.fill: parent
                                        spacing: 0
                                        
                                        // Lote #
                                        Rectangle {
                                            Layout.preferredWidth: 60
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            Label {
                                                anchors.centerIn: parent
                                                text: "#" + String(loteActual.Id_Lote || loteActual.id || 0).padStart(3, '0')
                                                font.pixelSize: 11
                                                font.bold: true
                                                color: "#007bff"
                                            }
                                        }
                                        
                                        // Stock
                                        Rectangle {
                                            Layout.preferredWidth: 80
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            Label {
                                                anchors.centerIn: parent
                                                text: (loteActual.Stock_Lote || loteActual.Stock_Actual || 0).toString()
                                                font.pixelSize: 12
                                                font.bold: true
                                                color: "#28a745"
                                            }
                                        }
                                        
                                        // Precio Compra
                                        Rectangle {
                                            Layout.preferredWidth: 90
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            Label {
                                                anchors.centerIn: parent
                                                text: "Bs " + (loteActual.Precio_Compra || 0).toFixed(2)
                                                font.pixelSize: 11
                                                color: "#212529"
                                            }
                                        }
                                        
                                        // Fecha Compra
                                        Rectangle {
                                            Layout.preferredWidth: 100
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            Label {
                                                anchors.centerIn: parent
                                                text: loteActual.Fecha_Compra 
                                                      ? new Date(loteActual.Fecha_Compra).toLocaleDateString('es-ES')
                                                      : "---"
                                                font.pixelSize: 11
                                                color: "#212529"
                                            }
                                        }
                                        
                                        // Días para Vencer
                                        Rectangle {
                                            Layout.preferredWidth: 100
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            Label {
                                                anchors.centerIn: parent
                                                text: formatearDiasParaVencer(loteActual.Dias_para_Vencer)
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: obtenerColorEstadoVencimiento(loteActual.Estado_Vencimiento)
                                            }
                                        }
                                        
                                        // Estado
                                        Rectangle {
                                            Layout.preferredWidth: 110
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            
                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: 95
                                                height: 22
                                                radius: 11
                                                color: obtenerColorEstadoVencimiento(loteActual.Estado_Vencimiento)
                                                
                                                Label {
                                                    anchors.centerIn: parent
                                                    text: obtenerTextoEstadoVencimiento(loteActual.Estado_Vencimiento)
                                                    font.pixelSize: 8
                                                    font.bold: true
                                                    color: "#ffffff"
                                                }
                                            }
                                        }
                                        
                                        // Acciones
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            
                                            RowLayout {
                                                anchors.centerIn: parent
                                                spacing: 6
                                                
                                                // Botón Editar
                                                Button {
                                                    Layout.preferredWidth: 70
                                                    Layout.preferredHeight: 28
                                                    text: "✏️ Editar"
                                                    
                                                    background: Rectangle {
                                                        color: parent.pressed ? "#2980b9" : "#3498db"
                                                        radius: 4
                                                    }
                                                    
                                                    contentItem: Label {
                                                        text: parent.text
                                                        color: "white"
                                                        font.pixelSize: 9
                                                        font.bold: true
                                                        horizontalAlignment: Text.AlignHCenter
                                                        verticalAlignment: Text.AlignVCenter
                                                    }
                                                    
                                                    onClicked: {
                                                        console.log("Editando lote:", loteActual.Id_Lote || loteActual.id)
                                                        editarLoteSolicitado(loteActual)
                                                    }
                                                }
                                                
                                                // Botón Eliminar
                                                Button {
                                                    Layout.preferredWidth: 80
                                                    Layout.preferredHeight: 28
                                                    text: "🗑️ Eliminar"
                                                    
                                                    background: Rectangle {
                                                        color: parent.pressed ? "#c0392b" : "#e74c3c"
                                                        radius: 4
                                                    }
                                                    
                                                    contentItem: Label {
                                                        text: parent.text
                                                        color: "white"
                                                        font.pixelSize: 9
                                                        font.bold: true
                                                        horizontalAlignment: Text.AlignHCenter
                                                        verticalAlignment: Text.AlignVCenter
                                                    }
                                                    
                                                    onClicked: {
                                                        mostrarConfirmacionEliminarLote(loteActual)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                // Mensaje cuando no hay lotes
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.width
                                    height: 150
                                    color: "transparent"
                                    visible: lotesListView.count === 0
                                    
                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 12
                                        
                                        Label {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: lotesLoaded ? "📦" : "⏳"
                                            font.pixelSize: 48
                                        }
                                        
                                        Label {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: lotesLoaded ? "No hay lotes activos" : "Cargando lotes..."
                                            font.pixelSize: 14
                                            color: "#7f8c8d"
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    Item { Layout.fillHeight: true }
                }
            }
            
            // ========== FOOTER ==========
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 70
                color: "#ecf0f1"
                radius: 12
                
                // Redondear solo abajo
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 12
                    color: parent.color
                }
                
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 12
                    
                    Button {
                        text: "Editar Producto"
                        Layout.preferredWidth: 140
                        Layout.preferredHeight: 40
                        
                        background: Rectangle {
                            radius: 6
                            color: parent.hovered ? "#2980b9" : "#3498db"
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            font.pixelSize: 14
                            font.bold: true
                            color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: {
                            if (productoData) {
                                editarSolicitado(productoData)
                            }
                        }
                    }
                    
                    Button {
                        text: "Eliminar Producto"
                        Layout.preferredWidth: 140
                        Layout.preferredHeight: 40
                        
                        background: Rectangle {
                            radius: 6
                            color: parent.hovered ? "#c0392b" : "#e74c3c"
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            font.pixelSize: 14
                            font.bold: true
                            color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: {
                            if (productoData) {
                                eliminarSolicitado(productoData)
                            }
                        }
                    }
                    
                    Button {
                        text: "Cerrar"
                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 40
                        
                        background: Rectangle {
                            radius: 6
                            color: parent.hovered ? "#7f8c8d" : "#95a5a6"
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            font.pixelSize: 14
                            font.bold: true
                            color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: {
                            cerrarSolicitado()
                        }
                    }
                }
            }
        }
    }
    
    // ===============================
    // DIÁLOGO DE CONFIRMACIÓN INTEGRADO
    // ===============================
    Rectangle {
        id: dialogoConfirmacion
        anchors.fill: parent
        visible: mostrandoConfirmacion
        z: 2000
        color: "#80000000"
        
        Rectangle {
            anchors.centerIn: parent
            width: 450
            height: 280
            radius: 12
            color: "white"
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 16
                
                // Header con icono de advertencia
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    
                    Rectangle {
                        width: 40
                        height: 40
                        color: "#f39c12"
                        radius: 20
                        
                        Label {
                            anchors.centerIn: parent
                            text: "⚠️"
                            font.pixelSize: 20
                            color: "white"
                        }
                    }
                    
                    Label {
                        text: confirmacionTitulo
                        font.pixelSize: 18
                        font.bold: true
                        color: "#2c3e50"
                        Layout.fillWidth: true
                    }
                    
                    Button {
                        text: "✕"
                        width: 32
                        height: 32
                        
                        background: Rectangle {
                            color: parent.pressed ? Qt.darker("#ecf0f1", 1.2) : "#ecf0f1"
                            radius: 16
                        }
                        
                        contentItem: Label {
                            text: parent.text
                            color: "#7f8c8d"
                            font.bold: true
                            font.pixelSize: 14
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: {
                            cerrarConfirmacion()
                        }
                    }
                }
                
                // Mensaje principal
                Label {
                    Layout.fillWidth: true
                    text: confirmacionMensaje
                    font.pixelSize: 14
                    color: "#2c3e50"
                    wrapMode: Text.WordWrap
                }
                
                // Detalles del mensaje
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    color: "#f8f9fa"
                    radius: 6
                    border.color: "#dee2e6"
                    border.width: 1
                    
                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: 8
                        clip: true
                        
                        Label {
                            width: parent.width
                            text: confirmacionDetalle
                            font.pixelSize: 12
                            color: "#7f8c8d"
                            wrapMode: Text.WordWrap
                        }
                    }
                }
                
                // Botones
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    
                    Item { Layout.fillWidth: true }
                    
                    Button {
                        text: "Cancelar"
                        Layout.preferredWidth: 100
                        Layout.preferredHeight: 40
                        
                        background: Rectangle {
                            color: parent.pressed ? Qt.darker("#95a5a6", 1.2) : "#95a5a6"
                            radius: 6
                        }
                        
                        contentItem: Label {
                            text: parent.text
                            color: "white"
                            font.bold: true
                            font.pixelSize: 14
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: {
                            cerrarConfirmacion()
                        }
                    }
                    
                    Button {
                        text: "Confirmar"
                        Layout.preferredWidth: 100
                        Layout.preferredHeight: 40
                        
                        background: Rectangle {
                            color: parent.pressed ? Qt.darker("#e74c3c", 1.2) : "#e74c3c"
                            radius: 6
                        }
                        
                        contentItem: Label {
                            text: parent.text
                            color: "white"
                            font.bold: true
                            font.pixelSize: 14
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: {
                            if (confirmacionCallback) {
                                confirmacionCallback()
                            }
                            cerrarConfirmacion()
                        }
                    }
                    
                    Item { Layout.fillWidth: true }
                }
            }
        }
    }
}