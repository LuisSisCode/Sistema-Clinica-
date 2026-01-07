import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// 🔍 DETALLEPRODUCTO.QML - FIFO 2.0 (VISUALIZACIÓN DE HISTORIAL)
// ✅ VERSIÓN MEJORADA - SIN CANTIDAD INICIAL, MEJOR VISUALIZACIÓN

Rectangle {
    id: detalleProductoComponent
    anchors.fill: parent
    color: "#80000000"
    z: 1000
    
    // ===============================
    // PROPIEDADES PÚBLICAS
    // ===============================
    
    property var productoData: null
    property string codigoCache: ""
    property string nombreCache: ""
    property bool mostrarStock: true
    property bool mostrarAcciones: true
    property var inventarioModel: null
    
    // PROPIEDADES PARA LOTES FIFO 2.0
    property var lotesData: []
    property bool lotesLoaded: false
    property bool loadingLotes: false
    
    // PROPIEDADES PARA PRECIOS
    property real costoPromedio: 0.0
    property real precioVenta: 0.0
    property bool editandoPrecio: false
    
    // CONTROL DE CARGA INICIAL
    property bool datosInicialmenteCargados: false
    
    // ===============================
    // SEÑALES
    // ===============================
    
    signal cerrarSolicitado()
    signal abrirCompraOriginal(int compraId)
    signal productoActualizado(var producto)

    // ===============================
    // FUNCIONES
    // ===============================
    
    function cargarDatosProducto() {
        console.log("🔍 cargarDatosProducto() llamado - productoData:", productoData ? "EXISTS" : "NULL")
    
        if (!productoData) {
            console.log("⚠️ No se pueden cargar datos - productoData es null")
            return
        }
        
        console.log("🔄 Cargando datos del producto:", productoData.codigo)
        
        loadingLotes = true
        
        try {
            // 1. Cargar lotes usando FIFO 2.0
            cargarLotesFIFO()
            
            // 2. Cargar precios
            cargarPrecios()
            
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
            
            var lotes = inventarioModel.get_lotes_producto_fifo(productoData.id)
            
            if (lotes && lotes.length > 0) {
                lotesData = lotes
                lotesLoaded = true
                console.log("✅ Lotes cargados:", lotes.length)
            } else {
                lotesData = []
                lotesLoaded = true
                console.log("⚠️ No hay lotes para este producto")
            }
            
        } catch (error) {
            console.log("❌ Error cargando lotes FIFO:", error.toString())
            lotesData = []
            lotesLoaded = false
        }
    }
    
    function cargarPrecios() {
        console.log("💰 Cargando precios del producto...")
        
        if (!productoData) return
        
        try {
            // Precio de venta desde productoData
            precioVenta = productoData.precioVenta || productoData.Precio_venta || 0.0
            
            // Calcular costo promedio desde los lotes cargados
            if (lotesData && lotesData.length > 0) {
                var sumaCostos = 0
                var totalUnidades = 0
                
                for (var i = 0; i < lotesData.length; i++) {
                    var lote = lotesData[i]
                    var stock = lote.Stock_Lote || lote.Stock_Actual || 0
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
            
        } catch (error) {
            console.log("❌ Error calculando precios:", error.toString())
        }
    }
    
    function limpiarDatos() {
        lotesData = []
        lotesLoaded = false
        costoPromedio = 0.0
        precioVenta = 0.0
    }
    
    function obtenerColorEstadoVencimiento(estadoVenc) {
        switch(estadoVenc) {
            case "VENCIDO":
                return "#FF4444"
            case "PRÓXIMO A VENCER":
                return "#FFB444"
            case "VIGENTE":
                return "#2fb32f"
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
            var precioTexto = nuevoPrecio.toString();
            precioTexto = precioTexto.replace(',', '.');
            
            var partes = precioTexto.split('.');
            if (partes.length > 2) {
                precioTexto = partes[0] + '.' + partes.slice(1).join('');
            }
            
            var precio = parseFloat(precioTexto);
            
            if (isNaN(precio) || precio <= 0) {
                console.log("❌ Precio inválido:", nuevoPrecio, "convertido a:", precio)
                return false
            }
            
            precio = parseFloat(precio.toFixed(2));
            
            console.log("💰 Actualizando precio de venta a:", precio, "de entrada:", nuevoPrecio)
            
            var resultado = inventarioModel.actualizar_precio_venta(productoData.codigo, precio)
            
            if (resultado) {
                precioVenta = precio
                console.log("✅ Precio actualizado exitosamente")
                
                if (productoData) {
                    productoData.precioVenta = precio
                    productoData.Precio_venta = precio
                    productoActualizado(productoData)
                }
                
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
    
    function formatearPrecioParaMostrar(precio) {
        if (!precio || precio <= 0) return "0.00";
        return parseFloat(precio).toFixed(2);
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
        console.log("📦 productoData cambió:", productoData ? productoData.codigo : "NULL")
        if (productoData) {
            codigoCache = productoData.codigo || ""
            nombreCache = productoData.nombre || ""
            
            if (!datosInicialmenteCargados) {
                console.log("📦 Producto asignado por primera vez:", productoData.codigo)
                datosInicialmenteCargados = true
            }
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
    // LAYOUT PRINCIPAL MEJORADO
    // ===============================
    
    Rectangle {
        anchors.centerIn: parent
        width: Math.min(1000, parent.width * 0.9)
        height: Math.min(750, parent.height * 0.9)
        radius: 12
        color: "white"
        
        // Sombra
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 3
            anchors.leftMargin: 3
            color: "#40000000"
            radius: 12
            z: -1
        }
        
        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            
            // ========== HEADER ==========
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 70
                color: "#34495E"
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
                    anchors.leftMargin: 24
                    anchors.rightMargin: 24
                    spacing: 16
                    
                    Rectangle {
                        width: 30
                        height: 30
                        radius: 8
                        color: "#4A6572"
                        
                        Label {
                            anchors.centerIn: parent
                            text: "📦"
                            font.pixelSize: 20
                            color: "white"
                        }
                    }
                    
                    Column {
                        Layout.fillWidth: true
                        spacing: 2
                        
                        Label {
                            text: nombreCache || (productoData ? productoData.nombre : "Detalle de Producto")
                            font.pixelSize: 18
                            font.bold: true
                            color: "white"
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                        
                        Label {
                            text: codigoCache ? "Código: " + codigoCache : (productoData ? "Código: " + productoData.codigo : "")
                            font.pixelSize: 13
                            color: "#BDC3C7"
                            opacity: 0.9
                        }
                    }
                    
                    Button {
                        text: "✕"
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        
                        background: Rectangle {
                            color: parent.pressed ? "#E74C3C" : "transparent"
                            border.color: "white"
                            border.width: 1
                            radius: 6
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            color: "white"
                            font.pixelSize: 16
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
                    width: parent.width - 50
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10
                    anchors.topMargin: 10
                    anchors.bottomMargin: 10
                    
                    // === WIDGET DE PRECIOS ===
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 140
                        color: "#F8F9FA"
                        radius: 8
                        border.color: "#D5DBDB"
                        border.width: 1
                        
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 12
                            
                            Label {
                                text: "💰 PRECIOS DEL PRODUCTO"
                                font.pixelSize: 14
                                font.bold: true
                                color: "#2C3E50"
                            }
                            
                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: "#D5DBDB"
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
                                        color: "#7F8C8D"
                                    }
                                    
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        
                                        Label {
                                            text: "Bs " + formatearPrecioParaMostrar(precioVenta)
                                            font.pixelSize: 20
                                            font.bold: true
                                            color: "#2C3E50"
                                            visible: !editandoPrecio
                                        }
                                        
                                        TextField {
                                            id: precioVentaField
                                            Layout.preferredWidth: 140
                                            Layout.preferredHeight: 36
                                            text: editandoPrecio ? (precioVenta > 0 ? precioVenta.toFixed(2) : "") : ""
                                            font.pixelSize: 16
                                            visible: editandoPrecio
                                            
                                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                                            
                                            onTextChanged: {
                                                if (!editandoPrecio || text === "") return;
                                                
                                                var cleanText = text.replace(',', '.');
                                                
                                                var dotCount = (cleanText.match(/\./g) || []).length;
                                                if (dotCount > 1) {
                                                    var parts = cleanText.split('.');
                                                    cleanText = parts[0] + '.' + parts.slice(1).join('');
                                                }
                                                
                                                if (cleanText !== text) {
                                                    text = cleanText;
                                                }
                                            }
                                            
                                            onActiveFocusChanged: {
                                                if (activeFocus && editandoPrecio) {
                                                    selectAll();
                                                }
                                            }
                                            
                                            background: Rectangle {
                                                color: "white"
                                                border.color: parent.activeFocus ? "#3498DB" : "#D5DBDB"
                                                border.width: 1
                                                radius: 4
                                            }
                                        }
                                        
                                        Button {
                                            text: editandoPrecio ? "💾" : "✏️"
                                            Layout.preferredWidth: 40
                                            Layout.preferredHeight: 36
                                            
                                            background: Rectangle {
                                                color: parent.pressed ? "#2980B9" : "#3498DB"
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
                                                    var precioTexto = precioVentaField.text.trim();
                                                    
                                                    if (precioTexto === "" || precioTexto === "." || precioTexto === ",") {
                                                        return;
                                                    }
                                                    
                                                    precioTexto = precioTexto.replace(',', '.');
                                                    var precioNum = parseFloat(precioTexto);
                                                    if (isNaN(precioNum) || precioNum <= 0) {
                                                        return;
                                                    }
                                                    
                                                    precioNum = parseFloat(precioNum.toFixed(2));
                                                    
                                                    if (actualizarPrecioVenta(precioNum)) {
                                                        editandoPrecio = false;
                                                    }
                                                } else {
                                                    editandoPrecio = true;
                                                    Qt.callLater(function() {
                                                        if (precioVentaField) {
                                                            precioVentaField.forceActiveFocus();
                                                            precioVentaField.selectAll();
                                                        }
                                                    });
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
                                        color: "#7F8C8D"
                                    }
                                    
                                    Label {
                                        text: "Bs " + costoPromedio.toFixed(2)
                                        font.pixelSize: 20
                                        font.bold: true
                                        color: "#F39C12"
                                    }
                                }
                            }
                        }
                    }
                    
                    // === INFORMACIÓN RÁPIDA ===
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 50
                        color: "white"
                        radius: 10
                        border.color: "#D5DBDB"
                        border.width: 1
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 30
                            
                            Column {
                                spacing: 2
                                
                                Label {
                                    text: "Marca"
                                    font.pixelSize: 12
                                    color: "#7F8C8D"
                                }
                                
                                Label {
                                    text: productoData ? (productoData.idMarca || "Sin marca") : ""
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: "#2C3E50"
                                }
                            }
                            
                            Rectangle {
                                width: 1
                                height: 40
                                color: "#ECF0F1"
                            }
                            
                            Column {
                                spacing: 2
                                
                                Label {
                                    text: "Stock Total"
                                    font.pixelSize: 12
                                    color: "#7F8C8D"
                                }
                                
                                Label {
                                    text: productoData ? (productoData.stockUnitario || 0) + " uds" : "0"
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: "#2C3E50"
                                }
                            }
                            
                            Rectangle {
                                width: 1
                                height: 40
                                color: "#ECF0F1"
                            }
                            
                            Column {
                                spacing: 2
                                
                                Label {
                                    text: "Lotes Activos"
                                    font.pixelSize: 12
                                    color: "#7F8C8D"
                                }
                                
                                Label {
                                    text: {
                                        if (!lotesLoaded) return "..."
                                        var activos = 0
                                        for (var i = 0; i < lotesData.length; i++) {
                                            var stock = lotesData[i].Stock_Lote || lotesData[i].Stock_Actual || 0
                                            if (stock > 0) activos++
                                        }
                                        return activos + "/" + lotesData.length
                                    }
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: "#3498DB"
                                }
                            }
                        }
                    }
                    
                    // === TABLA DE LOTES MEJORADA ===
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 450
                        color: "white"
                        radius: 8
                        border.color: "#D5DBDB"
                        border.width: 1
                        
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12
                            
                            RowLayout {
                                Layout.fillWidth: true
                                
                                Label {
                                    text: "📦 HISTORIAL DE LOTES (FIFO)"
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: "#2C3E50"
                                }
                                
                                Item { Layout.fillWidth: true }
                                
                                Label {
                                    text: lotesLoaded ? (lotesData.length + " lotes") : "Cargando..."
                                    font.pixelSize: 12
                                    color: "#7F8C8D"
                                }
                            }
                            
                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: "#D5DBDB"
                            }
                            
                            // Header de tabla - MEJORADO
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 32
                                color: "#F8F9FA"
                                radius: 4
                                
                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 0
                                    
                                    Rectangle { // LOTE
                                        Layout.preferredWidth: 80
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        Label {
                                            anchors.centerIn: parent
                                            text: "LOTE"
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: "#2C3E50"
                                        }
                                    }
                                    
                                    Rectangle { // STOCK
                                        Layout.preferredWidth: 100
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        Label {
                                            anchors.centerIn: parent
                                            text: "STOCK"
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: "#2C3E50"
                                        }
                                    }
                                    
                                    Rectangle { // PRECIO
                                        Layout.preferredWidth: 110
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        Label {
                                            anchors.centerIn: parent
                                            text: "PRECIO COMPRA"
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: "#2C3E50"
                                        }
                                    }
                                    
                                    Rectangle { // FECHA COMPRA
                                        Layout.preferredWidth: 110
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        Label {
                                            anchors.centerIn: parent
                                            text: "F. COMPRA"
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: "#2C3E50"
                                        }
                                    }
                                    
                                    Rectangle { // VENCIMIENTO
                                        Layout.preferredWidth: 130
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        Label {
                                            anchors.centerIn: parent
                                            text: "VENCIMIENTO"
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: "#2C3E50"
                                        }
                                    }
                                    
                                    Rectangle { // DÍAS
                                        Layout.preferredWidth: 110
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        Label {
                                            anchors.centerIn: parent
                                            text: "DÍAS"
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: "#2C3E50"
                                        }
                                    }
                                    
                                    Rectangle { // ESTADO
                                        Layout.preferredWidth: 130
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        Label {
                                            anchors.centerIn: parent
                                            text: "ESTADO"
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: "#2C3E50"
                                        }
                                    }                                 
                                }
                            }
                            
                            // Lista de lotes - MEJORADA
                            ListView {
                                id: lotesListView
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                spacing: 1
                                
                                model: lotesData
                                
                                delegate: Rectangle {
                                    width: lotesListView.width
                                    height: 40
                                    color: {
                                        var stock = loteActual.Stock_Lote || loteActual.Stock_Actual || 0
                                        if (stock === 0) {
                                            return "#F5F5F5"
                                        } else {
                                            return index % 2 === 0 ? "#FFFFFF" : "#F8F9FA"
                                        }
                                    }
                                    border.color: "#ECF0F1"
                                    border.width: stock === 0 ? 0 : 1
                                    
                                    property var loteActual: modelData
                                    property int stockActual: loteActual.Stock_Lote || loteActual.Stock_Actual || 0
                                    
                                    RowLayout {
                                        anchors.fill: parent
                                        spacing: 0
                                        
                                        // Lote #
                                        Rectangle {
                                            Layout.preferredWidth: 80
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            Label {
                                                anchors.centerIn: parent
                                                text: "#" + String(loteActual.Id_Lote || loteActual.id || 0).padStart(3, '0')
                                                font.pixelSize: 11
                                                font.bold: true
                                                color: stockActual === 0 ? "#95A5A6" : "#3498DB"
                                            }
                                        }
                                        
                                        // Stock Actual
                                        Rectangle {
                                            Layout.preferredWidth: 100
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            
                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: 60
                                                height: 22
                                                radius: 11
                                                color: stockActual === 0 ? "#95A5A6" : (stockActual < 10 ? "#FFB444" : "#2fb32f")
                                                
                                                Label {
                                                    anchors.centerIn: parent
                                                    text: stockActual.toString()
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                    color: "#FFFFFF"
                                                }
                                            }
                                        }
                                        
                                        // Precio Compra
                                        Rectangle {
                                            Layout.preferredWidth: 110
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            Label {
                                                anchors.centerIn: parent
                                                text: "Bs " + (loteActual.Precio_Compra || 0).toFixed(2)
                                                font.pixelSize: 11
                                                color: stockActual === 0 ? "#95A5A6" : "#2C3E50"
                                            }
                                        }
                                        
                                        // Fecha Compra
                                        Rectangle {
                                            Layout.preferredWidth: 110
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            Label {
                                                anchors.centerIn: parent
                                                text: loteActual.Fecha_Compra 
                                                      ? new Date(loteActual.Fecha_Compra).toLocaleDateString('es-ES', {day: '2-digit', month: '2-digit', year: 'numeric'})
                                                      : "---"
                                                font.pixelSize: 10
                                                color: stockActual === 0 ? "#95A5A6" : "#2C3E50"
                                            }
                                        }
                                        
                                        // Fecha Vencimiento
                                        Rectangle {
                                            Layout.preferredWidth: 130
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            Label {
                                                anchors.centerIn: parent
                                                text: loteActual.Fecha_Vencimiento
                                                      ? new Date(loteActual.Fecha_Vencimiento).toLocaleDateString('es-ES', {day: '2-digit', month: '2-digit', year: 'numeric'})
                                                      : "SIN VENC."
                                                font.pixelSize: 10
                                                color: stockActual === 0 ? "#95A5A6" : "#2C3E50"
                                                font.italic: !loteActual.Fecha_Vencimiento
                                            }
                                        }
                                        
                                        // Días para Vencer
                                        Rectangle {
                                            Layout.preferredWidth: 110
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
                                            Layout.preferredWidth: 130
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            
                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: 100
                                                height: 20
                                                radius: 10
                                                color: obtenerColorEstadoVencimiento(loteActual.Estado_Vencimiento)
                                                
                                                Label {
                                                    anchors.centerIn: parent
                                                    text: obtenerTextoEstadoVencimiento(loteActual.Estado_Vencimiento)
                                                    font.pixelSize: 9
                                                    font.bold: true
                                                    color: "#FFFFFF"
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                // Mensaje cuando no hay lotes
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.width
                                    height: 200
                                    color: "transparent"
                                    visible: lotesListView.count === 0
                                    
                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 16
                                        
                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: lotesLoaded ? "📭" : "⏳"
                                            font.pixelSize: 48
                                            color: "#95A5A6"
                                        }
                                        
                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: lotesLoaded ? "Sin lotes disponibles" : "Cargando lotes..."
                                            font.pixelSize: 16
                                            font.bold: true
                                            color: lotesLoaded ? "#7F8C8D" : "#95A5A6"
                                        }
                                        
                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            Layout.preferredWidth: 400
                                            text: lotesLoaded ? 
                                                "No hay lotes registrados para este producto.\nLos lotes se crean automáticamente al realizar compras." :
                                                "Obteniendo información de lotes..."
                                            font.pixelSize: 13
                                            color: "#95A5A6"
                                            horizontalAlignment: Text.AlignHCenter
                                            wrapMode: Text.WordWrap
                                            lineHeight: 1.4
                                        }
                                    }
                                }
                            }
                            
                            // Nota informativa
                            Label {
                                Layout.fillWidth: true
                                Layout.topMargin: 8
                                text: "ℹ️ Solo lectura. Para editar lotes, vaya al Modulo de Compras."
                                font.pixelSize: 11
                                font.italic: true
                                color: "#7F8C8D"
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }
        }
    }
}