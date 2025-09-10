import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: detalleProductoComponent
    
    // Propiedades públicas
    property var productoData: null
    property bool mostrarStock: true
    property bool mostrarAcciones: true
    property color primaryColor: "#2c3e50"
    property color successColor: "#27ae60"
    property color dangerColor: "#e74c3c"
    property color warningColor: "#f39c12"
    property color infoColor: "#3498db"
    property color lightGrayColor: "#ecf0f1"
    property color darkGrayColor: "#7f8c8d"
    property color textColor: "#2c3e50"
    property real baseUnit: 8
    property real fontBaseSize: 14
    
    // NUEVAS PROPIEDADES PARA LOTES
    property var lotesData: []
    property bool lotesLoaded: false
    property bool loadingLotes: false
    property var inventarioModel: null
    
    // Señales
    signal editarSolicitado(var producto)
    signal eliminarSolicitado(var producto)
    signal ajustarStockSolicitado(var producto)
    signal cerrarSolicitado()
    signal agregarLoteSolicitado(var producto)
    signal editarLoteSolicitado(var lote)
    signal eliminarLoteSolicitado(var lote)
    
    // CORRECCIÓN EN Component.onCompleted:
    Component.onCompleted: {
        console.log("=== DETALLE PRODUCTO COMPONENT LOADED (CORREGIDO) ===")
        console.log("  - Producto inicial:", productoData ? productoData.codigo : "NULL")
        console.log("  - InventarioModel disponible:", !!inventarioModel)
        
        // Cargar lotes inmediatamente si tenemos datos
        if (productoData && inventarioModel) {
            // Usar timer para asegurar que el componente esté completamente cargado
            Qt.callLater(function() {
                cargarLotesProducto()
            })
        } else {
            console.log("⚠️ Faltan datos para cargar lotes inicialmente")
        }
        console.log("=== FIN COMPONENT LOADED ===")
    }

    // CORRECCIÓN EN onProductoDataChanged:
    onProductoDataChanged: {
        console.log("=== PRODUCTO DATA CHANGED (CORREGIDO) ===")
        console.log("  - Nuevo producto:", productoData ? productoData.codigo : "NULL")
        
        if (productoData) {
            console.log("  - ID:", productoData.id)
            console.log("  - Código:", productoData.codigo)
            console.log("  - Nombre:", productoData.nombre)
            
            // Recargar lotes para el nuevo producto
            if (inventarioModel) {
                Qt.callLater(function() {
                    cargarLotesProducto()
                })
            }
        } else {
            // Limpiar datos si no hay producto
            lotesData = []
            lotesLoaded = false
        }
        console.log("=== FIN DATA CHANGED ===")
    }


    Connections {
        target: inventarioModel
        function onProductosChanged() {
            console.log("📦 Productos cambiaron - Recargando lotes si es necesario")
            if (productoData && productoData.codigo) {
                // Recargar lotes solo si el componente está visible
                Qt.callLater(cargarLotesProducto)
            }
        }
        function onOperacionExitosa(mensaje) {
            console.log("✅ Operación exitosa:", mensaje)
            // Si se creó o modificó un lote, recargar
            if (mensaje.includes("lote") || mensaje.includes("stock")) {
                Qt.callLater(cargarLotesProducto)
            }
        }
    }

    function debugProductoYLotes() {
        console.log("=== DEBUG PRODUCTO Y LOTES ===")
        console.log("ProductoData:", JSON.stringify(productoData, null, 2))
        console.log("LotesData length:", lotesData.length)
        console.log("LotesLoaded:", lotesLoaded)
        console.log("LoadingLotes:", loadingLotes)
        
        if (lotesData.length > 0) {
            console.log("Primer lote:", JSON.stringify(lotesData[0], null, 2))
        }
        console.log("=== FIN DEBUG ===")
    }

    function recargarLotes() {
        console.log("🔄 Recarga forzada de lotes solicitada")
        cargarLotesProducto()
    }

    // FUNCIONES PARA MANEJO DE LOTES
    function cargarLotesProducto() {
        if (!productoData || !inventarioModel) {
            console.log("❌ No se pueden cargar lotes: faltan datos básicos")
            console.log("  - productoData:", !!productoData)
            console.log("  - inventarioModel:", !!inventarioModel)
            return
        }
        
        // Usar el CÓDIGO del producto en lugar del ID
        var codigo = productoData.codigo
        if (!codigo) {
            console.log("❌ Producto sin código válido")
            return
        }
        
        loadingLotes = true
        console.log("🔄 Cargando lotes para producto:", codigo)
        
        try {
            // MÉTODO CORREGIDO: Usar get_producto_detalle_completo
            var detallesCompletos = inventarioModel.get_producto_detalle_completo(codigo)
            
            if (detallesCompletos && detallesCompletos.lotes) {
                lotesData = detallesCompletos.lotes
                lotesLoaded = true
                
                console.log("✅ Lotes cargados para", codigo + ":")
                console.log("  - Total lotes:", lotesData.length)
                console.log("  - Lotes activos:", detallesCompletos.lotes_count || 0)
                console.log("  - Stock total:", detallesCompletos.stock_total || 0)
                
                // DEBUG: Mostrar detalles de cada lote
                for (var i = 0; i < lotesData.length; i++) {
                    var lote = lotesData[i]
                    console.log("  📦 Lote", i + 1 + ":")
                    console.log("    - ID:", lote.id)
                    console.log("    - Vencimiento:", lote.Fecha_Vencimiento)
                    console.log("    - Stock:", (lote.Cantidad_Caja || 0) + (lote.Cantidad_Unitario || 0))
                }
            } else {
                console.log("⚠️ No se obtuvieron lotes para", codigo)
                lotesData = []
                lotesLoaded = true
            }
            
        } catch (error) {
            console.log("❌ Error cargando lotes:", error)
            lotesData = []
            lotesLoaded = true
        }
        
        loadingLotes = false
    }
    
    function obtenerEstadoVencimiento(fechaVencimiento) {
        if (!fechaVencimiento) return "unknown"
        
        var hoy = new Date()
        var vencimiento = new Date(fechaVencimiento)
        var diferenciaDias = Math.ceil((vencimiento.getTime() - hoy.getTime()) / (1000 * 3600 * 24))
        
        if (diferenciaDias < 0) return "vencido"
        if (diferenciaDias <= 30) return "proximo_vencer"
        if (diferenciaDias <= 90) return "vigente_proximo"
        return "vigente"
    }
    
    function obtenerColorEstado(estado) {
        switch(estado) {
            case "vencido": return dangerColor
            case "proximo_vencer": return warningColor
            case "vigente_proximo": return infoColor
            case "vigente": return successColor
            default: return darkGrayColor
        }
    }
    
    function obtenerTextoEstado(estado) {
        switch(estado) {
            case "vencido": return "VENCIDO"
            case "proximo_vencer": return "POR VENCER"
            case "vigente_proximo": return "VIGENTE"
            case "vigente": return "VIGENTE"
            default: return "DESCONOCIDO"
        }
    }
    
    function calcularDiasRestantes(fechaVencimiento) {
        if (!fechaVencimiento) return "---"
        
        var hoy = new Date()
        var vencimiento = new Date(fechaVencimiento)
        var diferenciaDias = Math.ceil((vencimiento.getTime() - hoy.getTime()) / (1000 * 3600 * 24))
        
        if (diferenciaDias < 0) return diferenciaDias + " días vencido"
        if (diferenciaDias === 0) return "Vence hoy"
        if (diferenciaDias === 1) return "1 día"
        return diferenciaDias + " días"
    }
    
    function obtenerTotalStock() {
        var total = 0
        for (var i = 0; i < lotesData.length; i++) {
            total += (lotesData[i].Stock_Lote || 0)
        }
        return total
    }
    
    function obtenerLotesActivos() {
        var activos = 0
        for (var i = 0; i < lotesData.length; i++) {
            if ((lotesData[i].Stock_Lote || 0) > 0) {
                activos++
            }
        }
        return activos
    }

    // Propiedades calculadas
    property real margenGanancia: {
        if (!productoData) return 0
        
        var compra = productoData.precioCompra || 0
        var venta = productoData.precioVenta || 0
        
        if (compra > 0 && venta > 0) {
            return ((venta - compra) / compra) * 100
        }
        return 0
    }

    // Configuración del componente
    width: 900
    height: 700
    color: "#ffffff"
    radius: 8
    border.color: "#e1e8ed"
    border.width: 1
    
    // Layout principal
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 0
        
        // === HEADER ===
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            color: "#f8f9fa"
            border.color: "#dee2e6"
            border.width: 1
            
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                
                Column {
                    spacing: 4
                    Layout.fillWidth: true
                    
                    Label {
                        text: "Detalles del Producto: " + (productoData ? (productoData.codigo || "SIN-CÓDIGO") : "---")
                        color: "#2c3e50"
                        font.bold: true
                        font.pixelSize: 18
                    }
                    
                    Label {
                        text: (productoData ? (productoData.nombre || "Sin nombre") : "---")
                        color: "#6c757d"
                        font.pixelSize: 14
                    }
                }
                
                // Indicadores de estado
                Row {
                    spacing: 12
                    
                    Rectangle {
                        width: 80
                        height: 32
                        color: lotesLoaded ? "#d4edda" : "#f8d7da"
                        border.color: lotesLoaded ? "#28a745" : "#dc3545"
                        border.width: 1
                        radius: 16
                        
                        Text {
                            anchors.centerIn: parent
                            text: lotesLoaded ? obtenerLotesActivos() + " Lotes" : "Sin datos"
                            color: lotesLoaded ? "#155724" : "#721c24"
                            font.bold: true
                            font.pixelSize: 11
                        }
                    }
                    
                    Rectangle {
                        width: 90
                        height: 32
                        color: "#d1ecf1"
                        border.color: "#bee5eb"
                        border.width: 1
                        radius: 16
                        
                        Text {
                            anchors.centerIn: parent
                            text: obtenerTotalStock() + " Unidades"
                            color: "#0c5460"
                            font.bold: true
                            font.pixelSize: 11
                        }
                    }
                }
                
                Button {
                    text: "✕"
                    width: 32
                    height: 32
                    
                    background: Rectangle {
                        color: parent.pressed ? "#e9ecef" : "#f8f9fa"
                        border.color: "#dee2e6"
                        border.width: 1
                        radius: 16
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        color: "#6c757d"
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: cerrarSolicitado()
                }
            }
        }
        
        // === INFORMACIÓN BÁSICA DEL PRODUCTO ===
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 120
            color: "#ffffff"
            border.color: "#dee2e6"
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                
                // Header de información básica
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 35
                    color: "#f8f9fa"
                    border.color: "#dee2e6"
                    border.width: 1
                    
                    Label {
                        anchors.left: parent.left
                        anchors.leftMargin: 15
                        anchors.verticalCenter: parent.verticalCenter
                        text: "INFORMACIÓN DEL PRODUCTO"
                        color: "#495057"
                        font.bold: true
                        font.pixelSize: 13
                    }
                }
                
                // Contenido información básica
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#ffffff"
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 15
                        spacing: 20
                        
                        // Columna 1: Datos básicos
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            
                            Row {
                                spacing: 8
                                Label {
                                    text: "Código:"
                                    color: "#6c757d"
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                                Label {
                                    text: productoData ? (productoData.codigo || "---") : "---"
                                    color: "#007bff"
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                            }
                            
                            Row {
                                spacing: 8
                                Label {
                                    text: "Marca:"
                                    color: "#6c757d"
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                                Label {
                                    text: productoData ? (productoData.idMarca || "---") : "---"
                                    color: "#28a745"
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                            }
                        }
                        
                        // Columna 2: Precios
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            
                            Row {
                                spacing: 8
                                Label {
                                    text: "Precio Compra:"
                                    color: "#6c757d"
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                                Label {
                                    text: productoData ? `Bs ${(productoData.precioCompra || 0).toFixed(2)}` : "Bs 0.00"
                                    color: "#28a745"
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                            }
                            
                            Row {
                                spacing: 8
                                Label {
                                    text: "Precio Venta:"
                                    color: "#6c757d"
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                                Label {
                                    text: productoData ? `Bs ${(productoData.precioVenta || 0).toFixed(2)}` : "Bs 0.00"
                                    color: "#ffc107"
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                            }
                        }
                        
                        // Columna 3: Margen
                        ColumnLayout {
                            Layout.preferredWidth: 100
                            spacing: 8
                            
                            Label {
                                text: "MARGEN"
                                color: "#6c757d"
                                font.pixelSize: 10
                                font.bold: true
                                Layout.alignment: Qt.AlignHCenter
                            }
                            
                            Rectangle {
                                Layout.preferredWidth: 80
                                Layout.preferredHeight: 24
                                Layout.alignment: Qt.AlignHCenter
                                color: margenGanancia >= 30 ? "#28a745" : 
                                       margenGanancia >= 15 ? "#ffc107" : "#dc3545"
                                radius: 12
                                
                                Label {
                                    anchors.centerIn: parent
                                    text: `${margenGanancia.toFixed(1)}%`
                                    color: "#ffffff"
                                    font.bold: true
                                    font.pixelSize: 11
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // === TABLA DE LOTES ===
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#ffffff"
            border.color: "#dee2e6"
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                
                // Header de lotes
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    color: "#f8f9fa"
                    border.color: "#dee2e6"
                    border.width: 1
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 15
                        anchors.rightMargin: 15
                        
                        Label {
                            text: "LOTES DE INVENTARIO"
                            color: "#495057"
                            font.bold: true
                            font.pixelSize: 13
                            Layout.fillWidth: true
                        }
                        
                        Button {
                            Layout.preferredWidth: 100
                            Layout.preferredHeight: 28
                            text: "+ Nuevo Lote"
                            
                            background: Rectangle {
                                color: parent.pressed ? "#0056b3" : "#007bff"
                                radius: 4
                            }
                            
                            contentItem: Label {
                                text: parent.text
                                color: "#ffffff"
                                font.bold: true
                                font.pixelSize: 11
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: agregarLoteSolicitado(productoData)
                        }
                    }
                }
                
                // Header de la tabla
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 35
                    color: "#e9ecef"
                    border.color: "#dee2e6"
                    border.width: 1
                    
                    RowLayout {
                        anchors.fill: parent
                        spacing: 0
                        
                        Rectangle {
                            Layout.preferredWidth: 60
                            Layout.fillHeight: true
                            color: "transparent"
                            border.color: "#dee2e6"
                            border.width: 1
                            Label {
                                anchors.centerIn: parent
                                text: "LOTE #"
                                color: "#495057"
                                font.bold: true
                                font.pixelSize: 10
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
                                text: "VENCIMIENTO"
                                color: "#495057"
                                font.bold: true
                                font.pixelSize: 10
                            }
                        }
                        
                        Rectangle {
                            Layout.preferredWidth: 80
                            Layout.fillHeight: true
                            color: "transparent"
                            border.color: "#dee2e6"
                            border.width: 1
                            Label {
                                anchors.centerIn: parent
                                text: "DÍAS REST."
                                color: "#495057"
                                font.bold: true
                                font.pixelSize: 10
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
                                text: "CAJAS"
                                color: "#495057"
                                font.bold: true
                                font.pixelSize: 10
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
                                text: "UNIDADES"
                                color: "#495057"
                                font.bold: true
                                font.pixelSize: 10
                            }
                        }
                        
                        Rectangle {
                            Layout.preferredWidth: 80
                            Layout.fillHeight: true
                            color: "transparent"
                            border.color: "#dee2e6"
                            border.width: 1
                            Label {
                                anchors.centerIn: parent
                                text: "TOTAL"
                                color: "#495057"
                                font.bold: true
                                font.pixelSize: 10
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
                                text: "ESTADO"
                                color: "#495057"
                                font.bold: true
                                font.pixelSize: 10
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
                                text: "ACCIONES"
                                color: "#495057"
                                font.bold: true
                                font.pixelSize: 10
                            }
                        }
                    }
                }
                
                // Lista de lotes
                ListView {
                    id: lotesListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: lotesData
                    clip: true
                    
                    delegate: Rectangle {
                        width: lotesListView.width
                        height: 45
                        color: index % 2 === 0 ? "#ffffff" : "#f8f9fa"
                        border.color: "#dee2e6"
                        border.width: 1
                        
                        property var loteData: lotesData[index]
                        property string estadoVenc: obtenerEstadoVencimiento(loteData.Fecha_Vencimiento)
                        
                        RowLayout {
                            anchors.fill: parent
                            spacing: 0
                            
                            // Lote #
                            Rectangle {
                                Layout.preferredWidth: 60
                                Layout.fillHeight: true
                                color: "transparent"
                                border.color: "#dee2e6"
                                border.width: 1
                                Label {
                                    anchors.centerIn: parent
                                    text: "L" + String(loteData.id).padStart(3, '0')
                                    color: "#007bff"
                                    font.bold: true
                                    font.pixelSize: 11
                                }
                            }
                            
                            // Vencimiento
                            Rectangle {
                                Layout.preferredWidth: 100
                                Layout.fillHeight: true
                                color: "transparent"
                                border.color: "#dee2e6"
                                border.width: 1
                                Label {
                                    anchors.centerIn: parent
                                    text: loteData.Fecha_Vencimiento ? 
                                          new Date(loteData.Fecha_Vencimiento).toLocaleDateString('es-ES') : "---"
                                    color: "#212529"
                                    font.pixelSize: 11
                                }
                            }
                            
                            // Días restantes
                            Rectangle {
                                Layout.preferredWidth: 80
                                Layout.fillHeight: true
                                color: "transparent"
                                border.color: "#dee2e6"
                                border.width: 1
                                Label {
                                    anchors.centerIn: parent
                                    text: calcularDiasRestantes(loteData.Fecha_Vencimiento)
                                    color: obtenerColorEstado(estadoVenc)
                                    font.pixelSize: 10
                                    font.bold: true
                                }
                            }
                            
                            // Cajas
                            Rectangle {
                                Layout.preferredWidth: 70
                                Layout.fillHeight: true
                                color: "transparent"
                                border.color: "#dee2e6"
                                border.width: 1
                                Label {
                                    anchors.centerIn: parent
                                    text: (loteData.Cantidad_Caja || 0).toString()
                                    color: "#17a2b8"
                                    font.bold: true
                                    font.pixelSize: 12
                                }
                            }
                            
                            // Unidades
                            Rectangle {
                                Layout.preferredWidth: 70
                                Layout.fillHeight: true
                                color: "transparent"
                                border.color: "#dee2e6"
                                border.width: 1
                                Label {
                                    anchors.centerIn: parent
                                    text: (loteData.Cantidad_Unitario || 0).toString()
                                    color: "#6f42c1"
                                    font.bold: true
                                    font.pixelSize: 12
                                }
                            }
                            
                            // Total
                            Rectangle {
                                Layout.preferredWidth: 80
                                Layout.fillHeight: true
                                color: "transparent"
                                border.color: "#dee2e6"
                                border.width: 1
                                Label {
                                    anchors.centerIn: parent
                                    text: (loteData.Stock_Lote || 0).toString()
                                    color: "#28a745"
                                    font.bold: true
                                    font.pixelSize: 12
                                }
                            }
                            
                            // Estado
                            Rectangle {
                                Layout.preferredWidth: 90
                                Layout.fillHeight: true
                                color: "transparent"
                                border.color: "#dee2e6"
                                border.width: 1
                                
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 75
                                    height: 20
                                    color: obtenerColorEstado(estadoVenc)
                                    radius: 10
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: obtenerTextoEstado(estadoVenc)
                                        color: "#ffffff"
                                        font.bold: true
                                        font.pixelSize: 8
                                    }
                                }
                            }
                            
                            // Acciones
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                color: "transparent"
                                border.color: "#dee2e6"
                                border.width: 1
                                
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    
                                    Button {
                                        width: 28
                                        height: 24
                                        text: "✏"
                                        
                                        background: Rectangle {
                                            color: parent.pressed ? "#0056b3" : "#007bff"
                                            radius: 3
                                        }
                                        
                                        contentItem: Label {
                                            text: parent.text
                                            color: "#ffffff"
                                            font.pixelSize: 10
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        
                                        onClicked: editarLoteSolicitado(loteData)
                                    }
                                    
                                    Button {
                                        width: 28
                                        height: 24
                                        text: "🗑"
                                        enabled: (loteData.Stock_Lote || 0) === 0
                                        
                                        background: Rectangle {
                                            color: parent.enabled ? 
                                                    (parent.pressed ? "#c82333" : "#dc3545") : "#e9ecef"
                                            radius: 3
                                        }
                                        
                                        contentItem: Label {
                                            text: parent.text
                                            color: parent.parent.enabled ? "#ffffff" : "#6c757d"
                                            font.pixelSize: 10
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        
                                        onClicked: eliminarLoteSolicitado(loteData)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Estado vacío
                    Rectangle {
                        anchors.centerIn: parent
                        width: 300
                        height: 100
                        visible: !loadingLotes && lotesData.length === 0
                        color: "transparent"
                        
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 12
                            
                            Label {
                                text: "📦"
                                font.pixelSize: 32
                                color: "#6c757d"
                                Layout.alignment: Qt.AlignHCenter
                            }
                            
                            Label {
                                text: "No hay lotes registrados"
                                color: "#6c757d"
                                font.pixelSize: 14
                                Layout.alignment: Qt.AlignHCenter
                            }
                            
                            Button {
                                text: "Agregar Primer Lote"
                                Layout.alignment: Qt.AlignHCenter
                                
                                background: Rectangle {
                                    color: parent.pressed ? "#0056b3" : "#007bff"
                                    radius: 4
                                }
                                
                                contentItem: Label {
                                    text: parent.text
                                    color: "#ffffff"
                                    font.bold: true
                                    font.pixelSize: 12
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                
                                onClicked: agregarLoteSolicitado(productoData)
                            }
                        }
                    }
                    
                    // Estado cargando
                    Rectangle {
                        anchors.centerIn: parent
                        width: 200
                        height: 60
                        visible: loadingLotes
                        color: "transparent"
                        
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 8
                            
                            BusyIndicator {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                            }
                            
                            Label {
                                text: "Cargando lotes..."
                                color: "#6c757d"
                                font.pixelSize: 12
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }
                }
            }
        }
        
        // === FOOTER CON ACCIONES DEL PRODUCTO ===
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            visible: mostrarAcciones
            color: "#f8f9fa"
            border.color: "#dee2e6"
            border.width: 1
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8
                
                Button {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    text: "✏ Editar Producto"
                    
                    background: Rectangle {
                        color: parent.pressed ? "#0056b3" : "#007bff"
                        radius: 4
                        border.color: "#0056b3"
                        border.width: 1
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        color: "#ffffff"
                        font.bold: true
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: editarSolicitado(productoData)
                }
                
                Button {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    text: "📦 Gestionar Stock"
                    
                    background: Rectangle {
                        color: parent.pressed ? "#e0a800" : "#ffc107"
                        radius: 4
                        border.color: "#e0a800"
                        border.width: 1
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        color: "#212529"
                        font.bold: true
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: ajustarStockSolicitado(productoData)
                }
                
                Button {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    text: "🗑 Eliminar Producto"
                    enabled: obtenerTotalStock() === 0
                    
                    background: Rectangle {
                        color: parent.enabled ? 
                                (parent.pressed ? "#c82333" : "#dc3545") : "#e9ecef"
                        radius: 4
                        border.color: parent.enabled ? "#c82333" : "#dee2e6"
                        border.width: 1
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        color: parent.parent.enabled ? "#ffffff" : "#6c757d"
                        font.bold: true
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: eliminarSolicitado(productoData)
                }
            }
        }
    }
}