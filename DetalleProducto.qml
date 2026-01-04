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

    // Cachés para detectar cambios
    property string codigoCache: ""
    property string nombreCache: ""

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
    
    // PROPIEDADES PARA ÚLTIMA VENTA
    property string ultimaVentaFecha: ""
    property real ultimaVentaCantidad: 0
    property bool cargandoUltimaVenta: false
    
    // ===============================
    // SEÑALES
    // ===============================
    
    signal editarSolicitado(var producto)
    signal eliminarSolicitado(var producto)
    signal cerrarSolicitado()
    signal editarLoteSolicitado(var lote)
    signal eliminarLoteSolicitado(var lote)
    signal loteActualizadoEnDialog()
    
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
            console.log("🔄 Cargando datos del producto:", productoData.codigo)
            
            // 1. Cargar lotes usando FIFO 2.0
            cargarLotesFIFO()
            
            // 2. Cargar datos de precios y márgenes
            cargarPreciosYMargenes()
            
            // 3. Si no hay stock, cargar última venta
            if (productoData.stockUnitario === 0 || productoData.stock === 0) {
                cargarUltimaVenta()
            }
            
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
            
            // ✅ CAMBIO: Usar método que devuelve TODOS los lotes (activos + agotados)
            var lotes = inventarioModel.get_lotes_producto_fifo(productoData.id)
            
            if (lotes && lotes.length > 0) {
                lotesData = lotes
                lotesLoaded = true
                
                console.log("✅ Lotes cargados:", lotes.length)
                console.log("   Primer lote:", JSON.stringify(lotes[0]))
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

    function cargarUltimaVenta() {
        if (!productoData || !productoData.id) {
            return
        }
        
        cargandoUltimaVenta = true
        ultimaVentaFecha = ""
        ultimaVentaCantidad = 0
        
        try {
            console.log("🔍 Buscando última venta para producto ID:", productoData.id)
            
            // Llamar al backend para obtener última venta
            var resultado = inventarioModel.get_ultima_venta_producto(productoData.id)
            
            if (resultado && resultado.Fecha_Venta) {
                ultimaVentaFecha = resultado.Fecha_Venta
                ultimaVentaCantidad = resultado.Cantidad_Total || 0
                console.log("✅ Última venta encontrada:", ultimaVentaFecha, "- Cantidad:", ultimaVentaCantidad)
            } else {
                console.log("⚠️ No hay historial de ventas para este producto")
            }
            
        } catch (error) {
            console.log("❌ Error cargando última venta:", error.toString())
        } finally {
            cargandoUltimaVenta = false
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
        if (diasNum < 0) return "HACE " + Math.abs(diasNum) + (Math.abs(diasNum) === 1 ? " día" : " días")
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
            // Limpiar y formatear el precio
            var precioTexto = nuevoPrecio.toString();
            
            // Reemplazar coma por punto para parseFloat
            precioTexto = precioTexto.replace(',', '.');
            
            // Asegurarse de que solo haya un punto decimal
            var partes = precioTexto.split('.');
            if (partes.length > 2) {
                // Si hay múltiples puntos, tomar solo el primero como parte entera
                precioTexto = partes[0] + '.' + partes.slice(1).join('');
            }
            
            // Convertir a número
            var precio = parseFloat(precioTexto);
            
            // Validaciones adicionales
            if (isNaN(precio) || precio <= 0) {
                console.log("❌ Precio inválido:", nuevoPrecio, "convertido a:", precio)
                
                // Mostrar mensaje de error (opcional)
                // Podrías agregar un tooltip o mensaje temporal
                
                return false
            }
            
            // Asegurar 2 decimales
            precio = parseFloat(precio.toFixed(2));
            
            console.log("💰 Actualizando precio de venta a:", precio, "de entrada:", nuevoPrecio)
            
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

    function formatearNumero(numero, decimales) {
        if (isNaN(numero) || numero === null || numero === undefined) {
            return "0.00";
        }
        
        var num = parseFloat(numero);
        return num.toLocaleString(Qt.locale("es_ES"), 'f', decimales || 2);
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
    
    onLoteActualizadoEnDialog: {
        console.log("🔄 Señal recibida: lote actualizado, recargando datos")
        cargarDatosProducto()
    }
    
    onProductoDataChanged: {
        // ✅ CORRECCIÓN PROBLEMA #3: Guardar datos en cache y permitir refreshes
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
                            text: nombreCache || (productoData ? productoData.nombre : "Detalle de Producto")
                            font.pixelSize: 18
                            font.bold: true
                            color: "white"
                        }
                        
                        Label {
                            text: codigoCache ? "Código: " + codigoCache : (productoData ? "Código: " + productoData.codigo : "")
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
                                            text: "Bs " + formatearPrecioParaMostrar(precioVenta)
                                            font.pixelSize: 20
                                            font.bold: true
                                            color: "#2c3e50"
                                            visible: !editandoPrecio
                                        }
                                        // Precio Venta
                                        TextField {
                                            id: precioVentaField
                                            Layout.preferredWidth: 140
                                            Layout.preferredHeight: 40
                                            text: editandoPrecio ? (precioVenta > 0 ? precioVenta.toFixed(2) : "") : ""
                                            font.pixelSize: 16
                                            visible: editandoPrecio
                                            
                                            // Permitir solo números, punto y coma
                                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                                            
                                            // Procesar entrada para manejar comas
                                            onTextChanged: {
                                                if (!editandoPrecio || text === "") return;
                                                
                                                // Reemplazar comas por puntos
                                                var cleanText = text.replace(',', '.');
                                                
                                                // Eliminar múltiples puntos decimales
                                                var dotCount = (cleanText.match(/\./g) || []).length;
                                                if (dotCount > 1) {
                                                    var parts = cleanText.split('.');
                                                    cleanText = parts[0] + '.' + parts.slice(1).join('');
                                                }
                                                
                                                // Si el texto limpio es diferente, actualizarlo
                                                if (cleanText !== text) {
                                                    text = cleanText;
                                                }
                                            }
                                            
                                            // Al recibir foco, seleccionar todo el texto
                                            onActiveFocusChanged: {
                                                if (activeFocus && editandoPrecio) {
                                                    selectAll();
                                                }
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
                                                    var precioTexto = precioVentaField.text.trim();
                                                    
                                                    console.log("📝 Texto a guardar:", precioTexto);
                                                    
                                                    if (precioTexto === "" || precioTexto === "." || precioTexto === ",") {
                                                        console.log("❌ Precio vacío o inválido");
                                                        return;
                                                    }
                                                    
                                                    // Convertir a número (manejar comas)
                                                    precioTexto = precioTexto.replace(',', '.');
                                                    
                                                    // Validar que sea un número válido
                                                    var precioNum = parseFloat(precioTexto);
                                                    if (isNaN(precioNum) || precioNum <= 0) {
                                                        console.log("❌ Número inválido:", precioTexto);
                                                        return;
                                                    }
                                                    
                                                    // Formatear a 2 decimales
                                                    precioNum = parseFloat(precioNum.toFixed(2));
                                                    
                                                    if (actualizarPrecioVenta(precioNum)) {
                                                        console.log("✅ Guardado exitoso, nuevo precio:", precioNum);
                                                        editandoPrecio = false;
                                                    } else {
                                                        console.log("❌ Error al guardar");
                                                    }
                                                } else {
                                                    // Editar
                                                    console.log("✏️ Iniciando edición. Precio actual:", precioVenta);
                                                    editandoPrecio = true;
                                                    
                                                    // Usar setTimeout para asegurar que el TextField esté visible
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
                                text: "Lotes:"
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
                                    text: "📦 LOTES"
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
                                    // ✅ Color diferente para lotes agotados
                                    color: {
                                        var stock = loteActual.Stock_Lote || loteActual.Stock_Actual || 0
                                        if (stock === 0) {
                                            return "#f0f0f0"  // Gris claro para agotados
                                        } else {
                                            return index % 2 === 0 ? "#ffffff" : "#f8f9fa"
                                        }
                                    }
                                    border.color: {
                                        var stock = loteActual.Stock_Lote || loteActual.Stock_Actual || 0
                                        return stock === 0 ? "#cccccc" : "#dee2e6"
                                    }
                                    border.width: 1
                                    opacity: {
                                        var stock = loteActual.Stock_Lote || loteActual.Stock_Actual || 0
                                        return stock === 0 ? 0.6 : 1.0  // Opacidad reducida para agotados
                                    }
                                    
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
                                            
                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: 70
                                                height: 24
                                                radius: 12
                                                // ✅ Color distintivo para stock agotado
                                                color: {
                                                    var stock = loteActual.Stock_Lote || loteActual.Stock_Actual || 0
                                                    return stock === 0 ? "#757575" : "#28a745"
                                                }
                                                
                                                Label {
                                                    anchors.centerIn: parent
                                                    text: {
                                                        var stock = loteActual.Stock_Lote || loteActual.Stock_Actual || 0
                                                        return stock === 0 ? "AGOTADO" : stock.toString()
                                                    }
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                    color: "#ffffff"
                                                }
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
                                                // ✅ Ocultar botones en lotes agotados
                                                visible: {
                                                    var stock = loteActual.Stock_Lote || loteActual.Stock_Actual || 0
                                                    return stock > 0
                                                }
                                                
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
                                                        // ✅ Capturar el objeto lote en una variable local
                                                        var loteParaEditar = {
                                                            "Id_Lote": loteActual.Id_Lote || loteActual.id,
                                                            "id": loteActual.Id_Lote || loteActual.id,
                                                            "Stock_Lote": loteActual.Stock_Lote || loteActual.Stock_Actual,
                                                            "Stock": loteActual.Stock_Lote || loteActual.Stock_Actual,
                                                            "Precio_Compra": loteActual.Precio_Compra,
                                                            "PrecioCompra": loteActual.Precio_Compra,
                                                            "Fecha_Vencimiento": loteActual.Fecha_Vencimiento || "",
                                                            "FechaVencimiento": loteActual.Fecha_Vencimiento || "",
                                                            "Cantidad_Inicial": loteActual.Cantidad_Inicial || loteActual.Stock_Lote,
                                                            "Producto_Nombre": loteActual.Producto_Nombre || productoData.nombre,
                                                            "Producto": loteActual.Producto_Nombre || productoData.nombre,
                                                            "Fecha_Compra": loteActual.Fecha_Compra || "",
                                                            "Estado_Lote": loteActual.Estado_Lote || "",
                                                            "Estado_Vencimiento": loteActual.Estado_Vencimiento || "",
                                                            "Dias_para_Vencer": loteActual.Dias_para_Vencer
                                                        }
                                                        
                                                        console.log("Editando lote:", loteParaEditar.Id_Lote)
                                                        console.log("📦 Datos del lote:", JSON.stringify(loteParaEditar))
                                                        
                                                        editarLoteSolicitado(loteParaEditar)
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
                                            
                                            // ✅ Mensaje para lotes agotados
                                            Label {
                                                anchors.centerIn: parent
                                                text: "Historial"
                                                font.pixelSize: 11
                                                font.italic: true
                                                color: "#999999"
                                                visible: {
                                                    var stock = loteActual.Stock_Lote || loteActual.Stock_Actual || 0
                                                    return stock === 0
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
                                        spacing: 20
                                        
                                        // Ícono
                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: lotesLoaded ? "📦" : "⏳"
                                            font.pixelSize: 64
                                            color: "#7f8c8d"
                                        }
                                        
                                        // Título
                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: lotesLoaded ? "Sin lotes disponibles" : "Cargando lotes..."
                                            font.pixelSize: 16
                                            font.bold: true
                                            color: lotesLoaded ? "#e74c3c" : "#7f8c8d"
                                        }
                                        
                                        // Mensaje explicativo (SIN BOTONES, solo texto)
                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            Layout.preferredWidth: 400
                                            text: {
                                                if (!lotesLoaded) return ""
                                                
                                                if (productoData && (productoData.stockUnitario === 0 || productoData.stock === 0)) {
                                                    // Producto sin stock - verificar si tiene historial de ventas
                                                    if (ultimaVentaFecha) {
                                                        return "Este producto está agotado.\n\nÚltima venta registrada:\n" + 
                                                               ultimaVentaFecha + " (" + ultimaVentaCantidad + " unidades)\n\n" +
                                                               "Realice una nueva compra para registrar lotes."
                                                    } else {
                                                        return "Este producto nunca ha sido comprado.\n\n" +
                                                               "No hay historial de lotes registrados.\n\n" +
                                                               "Realice la primera compra desde el módulo de Compras."
                                                    }
                                                } else {
                                                    return "No hay lotes registrados para este producto."
                                                }
                                            }
                                            font.pixelSize: 13
                                            color: "#95a5a6"
                                            horizontalAlignment: Text.AlignHCenter
                                            wrapMode: Text.WordWrap
                                            visible: lotesLoaded
                                            lineHeight: 1.4
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    Item { Layout.fillHeight: true }
                }
            }
        }
    }

    // Agrega esta función cerca de las otras funciones
    function formatearPrecioParaMostrar(precio) {
        if (!precio || precio <= 0) return "0.00";
        return parseFloat(precio).toFixed(2);
    }
}