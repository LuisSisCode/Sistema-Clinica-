import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: editarLoteOverlay
    anchors.fill: parent
    color: "#80000000"
    z: 1000
    
    Rectangle {
        anchors.centerIn: parent
        width: 700
        height: 550
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
                        source: "Resources/iconos/lote.png"
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        fillMode: Image.PreserveAspectFit
                    }
                    
                    Label {
                        text: "✏️ Editar Lote #" + (loteData ? (loteData.Id_Lote || loteData.id || "").toString() : "")
                        font.pixelSize: 18
                        font.bold: true
                        color: "white"
                        Layout.fillWidth: true
                        verticalAlignment: Text.AlignVCenter
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
                    spacing: 16
                    anchors.topMargin: 20
                    anchors.bottomMargin: 20
                    
                    // Información del producto (solo lectura)
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        
                        Label {
                            text: "Producto"
                            font.pixelSize: 12
                            color: "#2c3e50"
                        }
                        
                        Label {
                            text: productoNombre || (loteData ? loteData.Producto_Nombre || loteData.Producto : "")
                            font.pixelSize: 14
                            font.bold: true
                            color: "#34495e"
                            wrapMode: Text.WordWrap
                        }
                    }
                    
                    // Precio de compra
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        
                        Label {
                            text: "Precio de Compra (Bs) *"
                            font.pixelSize: 12
                            color: "#2c3e50"
                        }
                        
                        TextField {
                            id: precioCompraField
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            placeholderText: "0.00"
                            text: precioCompra.toFixed(2)
                            font.pixelSize: 14
                            
                            validator: DoubleValidator {
                                bottom: 0.01
                                decimals: 2
                                notation: DoubleValidator.StandardNotation
                            }
                            
                            background: Rectangle {
                                radius: 6
                                border.color: precioCompraField.activeFocus ? "#3498db" : "#bdc3c7"
                                border.width: 1
                                color: "white"
                            }
                            
                            onTextChanged: {
                                errorVisible = false
                            }
                        }
                    }
                    
                    // Stock actual
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        
                        RowLayout {
                            Layout.fillWidth: true
                            
                            Label {
                                text: "Stock Actual *"
                                font.pixelSize: 12
                                color: "#2c3e50"
                            }
                            
                            Label {
                                text: "(Máximo: " + cantidadInicial + ")"
                                font.pixelSize: 11
                                color: "#7f8c8d"
                            }
                        }
                        
                        TextField {
                            id: stockActualField
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            placeholderText: "0"
                            text: stockActual.toString()
                            font.pixelSize: 14
                            
                            validator: IntValidator {
                                bottom: 0
                                top: cantidadInicial
                            }
                            
                            background: Rectangle {
                                radius: 6
                                border.color: stockActualField.activeFocus ? "#3498db" : "#bdc3c7"
                                border.width: 1
                                color: "white"
                            }
                            
                            onTextChanged: {
                                errorVisible = false
                            }
                        }
                    }
                    
                    // Fecha de vencimiento
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        
                        Label {
                            text: "Fecha de Vencimiento"
                            font.pixelSize: 12
                            color: "#2c3e50"
                        }
                        
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            
                            TextField {
                                id: fechaVencimientoField
                                Layout.fillWidth: true
                                Layout.preferredHeight: 40
                                placeholderText: "YYYY-MM-DD"
                                text: fechaVencimiento
                                font.pixelSize: 14
                                enabled: !noVencimientoCheck.checked
                                
                                background: Rectangle {
                                    radius: 6
                                    border.color: fechaVencimientoField.activeFocus ? "#3498db" : "#bdc3c7"
                                    border.width: 1
                                    color: fechaVencimientoField.enabled ? "white" : "#ecf0f1"
                                }
                                
                                onTextChanged: {
                                    errorVisible = false
                                }
                            }
                            
                            CheckBox {
                                id: noVencimientoCheck
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 20
                                checked: noVencimiento
                                
                                onCheckedChanged: {
                                    noVencimiento = checked
                                    if (checked) {
                                        fechaVencimientoField.text = ""
                                    }
                                }
                            }
                            
                            Label {
                                text: "Sin vencimiento"
                                font.pixelSize: 14
                                color: "#2c3e50"
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                    
                    // Mensaje de error
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 50
                        visible: errorVisible
                        color: "#FFEBEE"
                        radius: 6
                        border.color: dangerColor
                        border.width: 1
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8
                            
                            Label {
                                text: "⚠️"
                                font.pixelSize: 16
                            }
                            
                            Label {
                                Layout.fillWidth: true
                                text: mensajeError
                                font.pixelSize: 12
                                color: dangerColor
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
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
                        text: "Cancelar"
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
                            cancelado()
                        }
                    }
                    
                    Button {
                        text: guardando ? "Guardando..." : "Guardar Cambios"
                        Layout.preferredWidth: 150
                        Layout.preferredHeight: 40
                        enabled: !guardando
                        
                        background: Rectangle {
                            radius: 6
                            color: parent.enabled ? (parent.hovered ? "#229954" : "#27ae60") : "#bdc3c7"
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
                            guardarCambios()
                        }
                    }
                }
            }
        }
    }
    
    // ========== PROPIEDADES PÚBLICAS ==========
    property var inventarioModel: null
    property var loteData: null
    property bool modoEdicion: false
    
    signal loteActualizado(var lote)
    signal cancelado()
    
    // ========== COLORES ==========
    readonly property color dangerColor: "#e74c3c"
    
    // ========== PROPIEDADES DE DATOS ==========
    property int loteId: 0
    property string productoNombre: ""
    property int cantidadInicial: 0
    property real precioCompra: 0.0
    property int stockActual: 0
    property string fechaVencimiento: ""
    property bool noVencimiento: false
    
    property bool guardando: false
    property bool errorVisible: false
    property string mensajeError: ""
    
    // ========== TIMER PARA AUTO-OCULTAR ERRORES ==========
    Timer {
        id: errorTimer
        interval: 5000
        running: false
        repeat: false
        onTriggered: {
            errorVisible = false
            mensajeError = ""
        }
    }
    
    // ========== FUNCIONES ==========
    
    function cargarDatosLote(lote) {
        console.log("📦 Cargando datos del lote:", JSON.stringify(lote))
        
        try {
            // ✅ CONVERSIÓN EXPLÍCITA A TIPOS JAVASCRIPT NATIVOS
            var idLote = parseInt(lote.Id_Lote || lote.id || 0)
            var stock = parseInt(lote.Stock_Lote || lote.Stock || lote.Stock_Actual || 0)
            var precio = parseFloat(lote.Precio_Compra || lote.PrecioCompra || 0)
            var cantInicial = parseInt(lote.Cantidad_Inicial || stock)
            
            // ✅ Convertir nombre de producto a string FORZADAMENTE
            var prodNombre = lote.Producto_Nombre || lote.Producto || ""
            prodNombre = String(prodNombre)
            
            // ✅ MANEJO ESPECIAL DE FECHA (puede ser datetime.date de Python)
            var fechaVenc = lote.Fecha_Vencimiento || lote.FechaVencimiento || ""
            
            // Verificar si es un objeto (datetime de Python)
            if (typeof fechaVenc === "object" && fechaVenc !== null) {
                // Es un objeto datetime, intentar convertir
                try {
                    // Si tiene método toString, usarlo
                    if (fechaVenc.toString && typeof fechaVenc.toString === "function") {
                        fechaVenc = fechaVenc.toString()
                    } else {
                        fechaVenc = ""
                    }
                } catch (e) {
                    console.log("⚠️ Error convirtiendo fecha objeto:", e)
                    fechaVenc = ""
                }
            }
            
            // Convertir a string y limpiar
            fechaVenc = String(fechaVenc).trim()
            
            // Limpiar valores no válidos
            if (fechaVenc === "" || 
                fechaVenc === "null" || 
                fechaVenc === "undefined" || 
                fechaVenc.includes("QVariant") || 
                fechaVenc.includes("PySide") ||
                fechaVenc.includes("datetime")) {
                fechaVenc = ""
            }
            
            // ✅ Asignar a las PROPIEDADES del componente
            loteId = idLote
            productoNombre = prodNombre
            cantidadInicial = cantInicial
            precioCompra = precio
            stockActual = stock
            
            // ✅ Asignar fecha
            if (fechaVenc === "") {
                fechaVencimiento = ""
                noVencimiento = true
            } else {
                fechaVencimiento = fechaVenc
                noVencimiento = false
            }
            
            // ✅ Asignar a los TEXTFIELDS
            precioCompraField.text = precio.toString()
            stockActualField.text = stock.toString()
            fechaVencimientoField.text = fechaVencimiento
            
            console.log("✅ Datos del lote cargados correctamente")
            console.log("   - Lote ID:", loteId)
            console.log("   - Producto:", productoNombre)
            console.log("   - Stock:", stockActual + "/" + cantInicial)
            console.log("   - Precio:", precioCompra)
            console.log("   - Fecha:", fechaVencimiento || "Sin vencimiento")
            
        } catch (error) {
            console.log("❌ Error cargando datos:", error.toString())
        }
    }
    
    function validarFormulario() {
        // Validar precio de compra
        if (precioCompraField.text === "" || parseFloat(precioCompraField.text) <= 0) {
            mostrarError("El precio de compra debe ser mayor a 0")
            return false
        }
        
        // Validar stock
        if (stockActualField.text === "" || parseInt(stockActualField.text) < 0) {
            mostrarError("El stock no puede ser negativo")
            return false
        }
        
        // Validar que el stock no exceda la cantidad inicial
        if (parseInt(stockActualField.text) > cantidadInicial) {
            mostrarError("El stock no puede ser mayor a la cantidad inicial (" + cantidadInicial + ")")
            return false
        }
        
        // Validar fecha de vencimiento si no está marcado "sin vencimiento"
        if (!noVencimientoCheck.checked) {
            if (fechaVencimientoField.text === "") {
                mostrarError("Debe ingresar una fecha de vencimiento o marcar 'Sin vencimiento'")
                return false
            }
            
            // Validar formato de fecha (YYYY-MM-DD)
            var fechaRegex = /^\d{4}-\d{2}-\d{2}$/
            if (!fechaRegex.test(fechaVencimientoField.text)) {
                mostrarError("El formato de la fecha debe ser YYYY-MM-DD")
                return false
            }
        }
        
        return true
    }
    
    function guardarCambios() {
        console.log("💾 Iniciando guardado de cambios...")
        
        // Validar formulario
        if (!validarFormulario()) {
            console.log("❌ Validación fallida")
            return
        }
        
        if (!inventarioModel) {
            mostrarError("Error: InventarioModel no disponible")
            return
        }
        
        if (guardando) {
            console.log("⚠️ Ya hay un guardado en proceso")
            return
        }
        
        guardando = true
        
        try {
            // Preparar datos actualizados
            var datosActualizados = {
                "id_lote": loteId,
                "stock": parseInt(stockActualField.text),
                "precio_compra": parseFloat(precioCompraField.text),
                "fecha_vencimiento": noVencimientoCheck.checked ? null : fechaVencimientoField.text
            }
            
            console.log("📤 Enviando datos:", JSON.stringify(datosActualizados))
            
            // Llamar al backend
            var resultado = inventarioModel.actualizar_lote(
                datosActualizados.id_lote,
                datosActualizados.stock,
                datosActualizados.precio_compra,
                datosActualizados.fecha_vencimiento
            )
            
            if (resultado) {
                console.log("✅ Lote actualizado exitosamente")
                loteActualizado(datosActualizados)
            } else {
                console.log("❌ Error al actualizar lote")
                mostrarError("Error al actualizar el lote. Verifique los datos e intente nuevamente.")
            }
            
        } catch (error) {
            console.log("❌ Error en guardarCambios:", error.toString())
            mostrarError("Error inesperado: " + error.toString())
        } finally {
            guardando = false
        }
    }
    
    function mostrarError(mensaje) {
        mensajeError = mensaje
        errorVisible = true
        
        // Auto-ocultar después de 5 segundos
        errorTimer.restart()
    }
    
    // ========== INICIALIZACIÓN ==========
    onLoteDataChanged: {
        console.log("📦 loteData cambió:", loteData ? "con datos" : "null")
        if (loteData) {
            console.log("✅ Cargando datos del lote...")
            cargarDatosLote(loteData)
        }
    }
    Component.onCompleted: {
        console.log("✏️ EditarLoteDialog.qml cargado")
        if (loteData) {
            cargarDatosLote(loteData)
        } else {
            console.log("⚠️ No se recibieron datos de lote")
        }
    }
}
