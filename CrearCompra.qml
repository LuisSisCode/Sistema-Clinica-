import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15

Item {
    id: crearCompraRoot
    
    // Propiedades de comunicación
    property var inventarioModel: parent.inventarioModel || null
    property var ventaModel: null
    property var compraModel: null
    
    // PROPIEDADES PARA EDICIÓN
    property bool modoEdicion: compraModel ? compraModel.modo_edicion : false
    property int compraIdEdicion: compraModel ? compraModel.compra_id_edicion : 0
    property var datosOriginales: compraModel ? compraModel.datos_originales : {}
    
    // PROPIEDAD: Índice del producto editando
    property int productoEditandoIndex: -1
    
    // Señales
    signal compraCompletada()
    signal cancelarCompra()
    signal solicitarCrearProducto(string nombreProducto)
    
    // SISTEMA DE MÉTRICAS
    readonly property real fontBaseSize: Math.max(12, height / 70)
    readonly property real fontSmall: fontBaseSize * 0.85
    readonly property real fontMedium: fontBaseSize
    readonly property real fontLarge: fontBaseSize * 1.2
    
    // Espaciados
    readonly property real spacing4: 4
    readonly property real spacing6: 6
    readonly property real spacing8: 8
    readonly property real spacing12: 12
    
    // Alturas
    readonly property real inputHeight: 36
    readonly property real buttonHeight: 36
    readonly property real headerHeight: 60

    // COLORES
    property color primaryColor: modoEdicion ? "#2C3E50" : "#273746"
    property color accentColor: modoEdicion ? "#3498DB" : "#3498db"
    property color successColor: "#27ae60"
    property color warningColor: "#f39c12"
    property color dangerColor: "#e74c3c"
    property color errorColor: "#c62828"
    property color blueColor: "#3498db"
    property color whiteColor: "#ffffff"
    property color textColor: "#2c3e50"
    property color darkGrayColor: "#7f8c8d"
    property color lightGrayColor: "#bdc3c7"

    // Estados
    property bool showSuccessMessage: false
    property string successMessage: ""
    property bool showProductDropdown: false
    property bool mostrarAyuda: false
    property bool mostrarButtonCrearProducto: false
    property bool formularioActivo: false
    property bool creandoProducto: false

    property bool procesandoCompra: false
    property int contadorClics: 0 
    
    // Datos compra
    property string newPurchaseProvider: ""
    property string newPurchaseDate: ""
    property string newPurchaseId: ""
    property real newPurchaseTotal: 0.0
    
    // 🚀 CAMPOS DEL PRODUCTO - TODOS DISPONIBLES DESDE EL INICIO
    property string inputProductCode: ""
    property string inputProductName: ""
    property int inputProductId: 0
    property int inputCantidad: 0
    property real inputPrecioTotalCompra: 0.0
    property real inputPrecioUnitarioCalculado: 0.0
    property real inputPrecioVentaUnitario: 0.0
    property string inputExpiryDate: ""
    property bool inputNoExpiry: false
    property bool isNewProduct: true
    property bool esPrimeraCompra: false
    property bool productoValidoParaAgregar: false
    
    // Propiedad para crear producto
    property var abrirModalCrearProductoFunction: null

    // Modelos
    ListModel {
        id: productSearchResultsModel
    }
    
    property var providerNames: ["Seleccionar proveedor..."]

    // CONEXIONES
    Connections {
        target: compraModel
        
        function onModoEdicionChanged() {
            if (compraModel.modo_edicion) cargarDatosEdicion()
        }
        
        function onCompraActualizada(compraId, total) {
            showSuccess(`Compra #${compraId} actualizada: Bs${total.toFixed(2)}`)
            Qt.callLater(compraCompletada)
        }
        
        function onProveedoresChanged() {
            updateProviderNames()
        }
    }
    
    Timer {
        id: successTimer
        interval: 3000
        onTriggered: showSuccessMessage = false
    }

    Timer {
        id: resetButtonTimer
        interval: 2000
        onTriggered: {
            completarCompraButton.text = modoEdicion ? "💾 Guardar" : "📦 Completar"
            procesandoCompra = false
            contadorClics = 0
        }
    }
    
    // ============================================================================
    // FUNCIONES PRINCIPALES
    // ============================================================================
    
    function calcularPreciosAutomaticos() {
        if (inputCantidad > 0 && inputPrecioTotalCompra > 0) {
            inputPrecioUnitarioCalculado = inputPrecioTotalCompra / inputCantidad
            console.log("📊 Cálculo precios:", {
                cantidad: inputCantidad,
                total: inputPrecioTotalCompra,
                unitario: inputPrecioUnitarioCalculado,
                precioVentaActual: inputPrecioVentaUnitario
            })
            
            // Solo sugerir precio venta si es primera compra y no hay precio establecido
            if (esPrimeraCompra && inputPrecioVentaUnitario <= 0) {
                var sugerido = Math.ceil(inputPrecioUnitarioCalculado * 1.3 * 20) / 20
                inputPrecioVentaUnitario = sugerido
                console.log("💰 Precio venta sugerido:", sugerido)
                
                // Actualizar campo visual
                Qt.callLater(function() {
                    if (precioVentaField) {
                        precioVentaField.text = sugerido.toFixed(2)
                    }
                })
            }
        } else {
            inputPrecioUnitarioCalculado = 0
        }
        validarProductoParaAgregar()
    }
    
    function validarProductoParaAgregar() {
        // Para modo edición, el precio de venta puede ya existir o puede ser 0
        var precioVentaValido = true
        if (esPrimeraCompra) {
            precioVentaValido = inputPrecioVentaUnitario > 0
        }
        
        var nombreValido = inputProductName.trim().length > 0
        var cantidadValida = inputCantidad > 0
        var precioTotalValido = inputPrecioTotalCompra > 0
        var vencimientoValido = (inputNoExpiry || (inputExpiryDate.length > 0 && validateExpiryDate(inputExpiryDate)))
        var margenValido = inputPrecioVentaUnitario > inputPrecioUnitarioCalculado
        
        productoValidoParaAgregar = (
            nombreValido &&
            cantidadValida &&
            precioTotalValido &&
            vencimientoValido &&
            precioVentaValido &&
            margenValido
        )
        
        console.log("✅ Validación producto:", {
            nombre: nombreValido,
            cantidad: cantidadValida,
            precioTotal: precioTotalValido,
            vencimiento: vencimientoValido,
            precioVenta: precioVentaValido,
            margen: margenValido,
            valido: productoValidoParaAgregar,
            precioUnitario: inputPrecioUnitarioCalculado,
            precioVentaInput: inputPrecioVentaUnitario
        })
    }
    
    function buscarProductosExistentes(texto) {
        productSearchResultsModel.clear()
        if (!inventarioModel || texto.length < 2) {
            showProductDropdown = false
            mostrarButtonCrearProducto = false
            return
        }
        
        var textoBusqueda = texto.toLowerCase()
        if (inventarioModel) inventarioModel.buscar_productos(textoBusqueda)
        
        Qt.callLater(function() {
            var resultados = inventarioModel.search_results || []
            if (resultados.length > 0) {
                for (var i = 0; i < resultados.length; i++) {
                    var producto = resultados[i]
                    productSearchResultsModel.append({
                        id: producto.id || producto.Id || 0,
                        codigo: producto.Codigo || producto.codigo || "",
                        nombre: producto.Nombre || producto.nombre || "",
                        precioVentaBase: producto.Precio_venta || producto.precioVentaBase || 0
                    })
                }
                showProductDropdown = true
                mostrarButtonCrearProducto = false
            } else {
                showProductDropdown = false
                mostrarButtonCrearProducto = true
            }
        })
    }

    function seleccionarProductoExistente(productoId, codigo, nombre) {
        console.log("🎯 Seleccionando producto:", codigo, nombre)
        
        inputProductId = productoId
        inputProductCode = codigo
        inputProductName = nombre
        
        // Obtener datos del producto incluyendo información de vencimiento
        if (compraModel && inputProductCode) {
            var datosProducto = compraModel.obtener_datos_precio_producto(inputProductCode)
            
            console.log("📊 Datos del producto obtenidos:", JSON.stringify(datosProducto))
            
            if (datosProducto && Object.keys(datosProducto).length > 0) {
                // 1. Establecer si es primera compra
                esPrimeraCompra = datosProducto.es_primera || false
                
                // 2. Auto-completar precio de venta SIEMPRE que exista
                if (datosProducto.precio_venta && datosProducto.precio_venta > 0) {
                    inputPrecioVentaUnitario = datosProducto.precio_venta
                    console.log("💰 Precio venta auto-completado:", inputPrecioVentaUnitario)
                    
                    // ✅ CORRECCIÓN: Actualizar campo visual inmediatamente usando Qt.callLater
                    Qt.callLater(function() {
                        if (precioVentaField) {
                            precioVentaField.text = inputPrecioVentaUnitario.toFixed(2)
                            console.log("✅ Campo precioVentaField actualizado:", precioVentaField.text)
                        }
                    })
                } else {
                    // Si no hay precio de venta, limpiar el campo
                    inputPrecioVentaUnitario = 0
                    Qt.callLater(function() {
                        if (precioVentaField) {
                            precioVentaField.text = ""
                            console.log("❌ No hay precio venta, campo limpiado")
                        }
                    })
                }
                
                // 3. Verificar si el producto NO tiene vencimiento conocido
                var tieneVencimientoConocido = compraModel.verificarProductoTieneVencimiento(codigo)
                
                if (tieneVencimientoConocido === false) {
                    // Si sabemos que NO tiene vencimiento, marcar automáticamente
                    inputNoExpiry = true
                    inputExpiryDate = ""
                    console.log("📅 Producto sin vencimiento conocido - Campo desactivado automáticamente")
                    
                    // Actualizar UI
                    if (expiryField) {
                        expiryField.text = ""
                        expiryField.enabled = false
                    }
                    
                    // Marcar checkbox "Sin venc." como checked
                    if (noExpiryCheckbox) {
                        noExpiryCheckbox.checked = true
                    }
                } else if (tieneVencimientoConocido === true) {
                    // Si SABEMOS que tiene vencimiento, mantener campo activo
                    inputNoExpiry = false
                    console.log("📅 Producto con vencimiento conocido - Campo activado")
                    
                    if (expiryField) {
                        expiryField.enabled = true
                    }
                    
                    if (noExpiryCheckbox) {
                        noExpiryCheckbox.checked = false
                    }
                }
                // Si es null (no sabemos), dejar que el usuario decida
            }
        }
        
        showProductDropdown = false
        
        // Enfocar campo de cantidad después de seleccionar
        Qt.callLater(function() {
            if (cantidadField) {
                cantidadField.focus = true
                cantidadField.selectAll()
                console.log("🎯 Enfocando campo cantidad")
            }
        })
    }
    
    function agregarProductoACompra() {
        if (!productoValidoParaAgregar || !compraModel) return false
        
        console.log("✅ Agregando producto:", inputProductCode)
        
        try {
            var datosLote = {
                "Cantidad_Unitario": inputCantidad,
                "Precio_Compra": inputPrecioTotalCompra,
                "Vencimiento": inputNoExpiry ? null : inputExpiryDate
            }
            
            // ✅ ENVIAR PRECIO VENTA SIEMPRE
            if (inputPrecioVentaUnitario > 0) {
                datosLote["Precio_Venta"] = inputPrecioVentaUnitario
                console.log("💰 Precio venta enviado:", inputPrecioVentaUnitario)
            } else {
                console.log("⚠️ Precio venta es 0, no se enviará")
            }
            
            if (productoEditandoIndex >= 0) {
                // EDITAR - Usar el método del modelo
                console.log("✏️ Editando producto en índice:", productoEditandoIndex)
                var exito = compraModel.actualizar_item_compra(
                    productoEditandoIndex,
                    datosLote
                )
                
                if (exito) {
                    showSuccess("✏️ Producto actualizado")
                    productoEditandoIndex = -1
                    limpiarFormulario()
                    
                    // ✅ FORZAR ACTUALIZACIÓN DE LA VISTA
                    Qt.callLater(function() {
                        if (compraModel) {
                            compraModel.itemsCompraCambiado()
                        }
                    })
                    return true
                }
            } else {
                // AGREGAR NUEVO
                console.log("➕ Agregando nuevo producto")
                var agregado = compraModel.agregar_producto_a_compra(
                    inputProductCode,
                    datosLote
                )
                
                if (agregado) {
                    showSuccess("✅ Producto agregado")
                    limpiarFormulario()
                    return true
                }
            }
            
            showError("❌ No se pudo agregar el producto")
            return false
            
        } catch (error) {
            console.log("❌ Error:", error)
            showError("Error: " + error.toString())
            return false
        }
    }
    
    function limpiarFormulario() {
        inputProductCode = ""
        inputProductName = ""
        inputProductId = 0
        inputCantidad = 0
        inputPrecioTotalCompra = 0.0
        inputPrecioUnitarioCalculado = 0.0
        inputPrecioVentaUnitario = 0.0
        inputExpiryDate = ""
        inputNoExpiry = false
        esPrimeraCompra = false
        productoEditandoIndex = -1
        
        if (productCodeField) productCodeField.text = ""
        if (cantidadField) cantidadField.text = ""
        if (precioTotalField) precioTotalField.text = ""
        if (precioVentaField) precioVentaField.text = ""
        if (expiryField) expiryField.text = ""
    }
    
    function updatePurchaseTotal() {
        var total = 0.0
        if (compraModel && compraModel.items_compra) {
            var items = compraModel.items_compra
            for (var i = 0; i < items.length; i++) {
                total += parseFloat(items[i].subtotal || 0)
            }
        }
        newPurchaseTotal = total
    }
    
    function validateExpiryDate(dateStr) {
        if (dateStr === "" || dateStr === "Sin vencimiento") return true
        var regex = /^\d{4}-\d{2}-\d{2}$/
        if (!regex.test(dateStr)) return false
        var parts = dateStr.split('-')
        var year = parseInt(parts[0], 10)
        var month = parseInt(parts[1], 10)
        var day = parseInt(parts[2], 10)
        if (month < 1 || month > 12) return false
        if (day < 1 || day > 31) return false
        if (year < 2020 || year > 2050) return false
        var daysInMonth = new Date(year, month, 0).getDate()
        return day <= daysInMonth
    }
    
    function completarCompra() {
        if (!compraModel || !providerCombo || providerCombo.currentIndex <= 0) {
            showError("Error: Complete todos los campos")
            return false
        }
        
        if (productoEditandoIndex >= 0) {
            showError("Termine de editar el producto primero")
            return false
        }
        
        // Obtener ID del proveedor
        var proveedor_id = 0
        var proveedores = compraModel.proveedores
        for (var i = 0; i < proveedores.length; i++) {
            var proveedor = proveedores[i]
            if ((proveedor.Nombre || proveedor.nombre) === newPurchaseProvider) {
                proveedor_id = proveedor.id
                break
            }
        }
        
        if (proveedor_id <= 0) {
            showError("Error: Proveedor no válido")
            return false
        }
        
        // ✅ CORRECCIÓN: Si está en modo edición, usar actualizar_compra en lugar de completar_compra
        var resultado = false
        if (modoEdicion) {
            console.log("✏️ Actualizando compra existente...")
            resultado = compraModel.actualizar_compra(proveedor_id)
        } else {
            console.log("🛒 Creando nueva compra...")
            resultado = compraModel.completar_compra(proveedor_id)
        }
        
        if (resultado) {
            showSuccess("✅ " + (modoEdicion ? "Compra actualizada" : "Compra completada") + " exitosamente")
            limpiarFormulario()
            return true
        } else {
            showError("❌ Error al " + (modoEdicion ? "actualizar" : "completar") + " la compra")
            return false
        }
    }
    
    function showSuccess(message) {
        successMessage = message
        showSuccessMessage = true
        successTimer.restart()
    }
    
    function showError(mensaje) {
        successMessage = mensaje
        showSuccessMessage = true
        successTimer.restart()
    }

    // ============================================================================
    // INTERFAZ REDISEÑADA - UX PRIORITARIA
    // ============================================================================
    
    Rectangle {
        anchors.fill: parent
        color: "#f5f7fa"
        
        // HEADER COMPACTO
        Rectangle {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: headerHeight
            color: whiteColor
            border.color: "#e0e0e0"
            border.width: 1
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: spacing8
                spacing: spacing8
                
                Button {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    background: Rectangle {
                        color: "transparent"
                    }
                    contentItem: Label {
                        text: "←"
                        color: blueColor
                        font.bold: true
                        font.pixelSize: 20
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: cancelarCompra()
                }
                
                ColumnLayout {
                    spacing: 2
                    Label {
                        text: modoEdicion ? "✏️ EDITAR COMPRA" : "🛒 NUEVA COMPRA"
                        color: textColor
                        font.bold: true
                        font.pixelSize: fontLarge
                    }
                    Label {
                        text: newPurchaseId + " • " + newPurchaseDate
                        color: darkGrayColor
                        font.pixelSize: fontSmall
                    }
                }
                
                Item { Layout.fillWidth: true }
                
                Rectangle {
                    Layout.preferredWidth: 150
                    Layout.preferredHeight: 40
                    color: "#e8f5e9"
                    radius: 6
                    border.color: successColor
                    border.width: 1
                    
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 2
                        Label {
                            text: "TOTAL COMPRA"
                            color: "#2e7d32"
                            font.bold: true
                            font.pixelSize: 9
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Label {
                            text: "Bs " + newPurchaseTotal.toFixed(2)
                            color: successColor
                            font.bold: true
                            font.pixelSize: fontMedium
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }
        }
        
        // CONTENIDO PRINCIPAL CON SCROLL
        ScrollView {
            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            clip: true
            
            ScrollBar.vertical.policy: ScrollBar.AsNeeded
            
            // CORRECCIÓN: Usar Item como contenedor con márgenes
            Item {
                width: parent.width
                implicitHeight: mainColumn.implicitHeight + 2 * spacing12
                
                ColumnLayout {
                    id: mainColumn
                    anchors.fill: parent
                    anchors.margins: spacing12  // ✅ CORREGIDO: Usar anchors.margins en lugar de padding
                    spacing: spacing12
                    
                    // SECCIÓN PROVEEDOR
                    Rectangle {
                        Layout.fillWidth: true
                        height: 70
                        color: whiteColor
                        radius: 8
                        border.color: "#e0e0e0"
                        border.width: 1
                        
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: spacing8
                            spacing: spacing4
                            
                            Label {
                                text: "PROVEEDOR"
                                color: textColor
                                font.bold: true
                                font.pixelSize: fontSmall
                            }
                            
                            RowLayout {
                                spacing: spacing8
                                ComboBox {
                                    id: providerCombo
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 36
                                    model: crearCompraRoot.providerNames
                                    font.pixelSize: fontSmall
                                    
                                    background: Rectangle {
                                        color: whiteColor
                                        border.color: darkGrayColor
                                        border.width: 1
                                        radius: 6
                                    }
                                    
                                    onCurrentTextChanged: {
                                        if (currentIndex > 0) newPurchaseProvider = currentText
                                        else newPurchaseProvider = ""
                                    }
                                }
                                
                                Button {
                                    text: "🔄"
                                    Layout.preferredWidth: 36
                                    Layout.preferredHeight: 36
                                    font.pixelSize: 16
                                    
                                    ToolTip.visible: hovered
                                    ToolTip.text: "Actualizar proveedores"
                                    ToolTip.delay: 500
                                    
                                    background: Rectangle {
                                        color: '#829db1' ? '#1b79bd' : "transparent"
                                        border.color: parent.hovered ? blueColor : "transparent"
                                        border.width: 1 
                                        radius: 4
                                    }
                                    
                                    onClicked: {
                                        if (compraModel) compraModel.force_refresh_proveedores()
                                    }
                                }
                            }
                        }
                    }
                    
                    // SECCIÓN BÚSQUEDA DE PRODUCTO
                    Rectangle {
                        Layout.fillWidth: true
                        height: 90
                        color: whiteColor
                        radius: 8
                        border.color: "#e0e0e0"
                        border.width: 1
                        
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: spacing8
                            spacing: spacing4
                            
                            Label {
                                text: "🔍 BUSCAR O CREAR PRODUCTO"
                                color: textColor
                                font.bold: true
                                font.pixelSize: fontSmall
                            }
                            
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 50
                                color: "#f8f9fa"
                                radius: 6
                                border.color: productCodeField.activeFocus ? blueColor : "#ddd"
                                border.width: 2
                                
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: spacing8
                                    spacing: spacing8
                                    
                                    TextInput {
                                        id: productCodeField
                                        Layout.fillWidth: true
                                        font.pixelSize: fontMedium
                                        color: textColor
                                        verticalAlignment: Text.AlignVCenter
                                        selectByMouse: true
                                        
                                        onTextChanged: {
                                            inputProductName = text
                                            if (text.length >= 2) buscarProductosExistentes(text)
                                            else {
                                                showProductDropdown = false
                                                mostrarButtonCrearProducto = false
                                            }
                                        }
                                        
                                        onFocusChanged: if (focus) selectAll()
                                        
                                        Text {
                                            anchors.fill: parent
                                            text: "Escribe el nombre del producto..."
                                            color: "#999"
                                            font.pixelSize: fontSmall
                                            verticalAlignment: Text.AlignVCenter
                                            visible: parent.text.length === 0
                                        }
                                    }
                                    
                                    Button {
                                        text: "➕ Crear"
                                        visible: mostrarButtonCrearProducto
                                        Layout.preferredHeight: 40
                                        Layout.preferredWidth: 80
                                        font.pixelSize: 16
                                        
                                        background: Rectangle {
                                            color: parent.hovered ? '#4359a0' : successColor
                                            radius: 4
                                        }
                                        
                                        contentItem: Label {
                                            text: parent.text
                                            color: whiteColor
                                            font.pixelSize: 10
                                            font.bold: true
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        
                                        onClicked: {
                                            var nombre = productCodeField.text.trim()
                                            if (nombre.length > 0) {
                                                crearCompraRoot.solicitarCrearProducto(nombre)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // ✅ RESULTADOS DE BÚSQUEDA (ABAJO DEL INPUT)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(200, productSearchResultsModel.count * 40)
                        visible: showProductDropdown
                        color: whiteColor
                        border.color: blueColor
                        border.width: 1
                        radius: 8
                        
                        ListView {
                            anchors.fill: parent
                            anchors.margins: 1
                            model: productSearchResultsModel
                            clip: true
                            spacing: 1
                            
                            delegate: Rectangle {
                                width: ListView.view.width
                                height: 40
                                color: mouseArea.containsMouse ? "#e3f2fd" : "white"
                                
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: spacing8
                                    spacing: spacing8
                                    
                                    Rectangle {
                                        Layout.preferredWidth: 60
                                        Layout.preferredHeight: 24
                                        color: blueColor
                                        radius: 4
                                        
                                        Label {
                                            anchors.centerIn: parent
                                            text: model.codigo
                                            color: whiteColor
                                            font.bold: true
                                            font.pixelSize: 9
                                        }
                                    }
                                    
                                    Label {
                                        text: model.nombre
                                        color: textColor
                                        font.pixelSize: fontSmall
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                    
                                    Label {
                                        text: "Bs " + (model.precioVentaBase || 0).toFixed(2)
                                        color: successColor
                                        font.bold: true
                                        font.pixelSize: fontSmall
                                    }
                                }
                                
                                MouseArea {
                                    id: mouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: seleccionarProductoExistente(model.id, model.codigo, model.nombre)
                                }
                            }
                        }
                    }
                    
                    // 🚀 DATOS DE COMPRA - TODO EN UNA FILA
                    Rectangle {
                        Layout.fillWidth: true
                        height: 100
                        color: whiteColor
                        radius: 8
                        border.color: "#e0e0e0"
                        border.width: 1
                        
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: spacing8
                            spacing: spacing6
                            
                            Label {
                                text: "📝 DATOS DE LA COMPRA"
                                color: textColor
                                font.bold: true
                                font.pixelSize: fontSmall
                            }
                            
                            // ✅ TODOS LOS CAMPOS EN UNA SOLA FILA
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: spacing6
                                
                                // CANTIDAD
                                ColumnLayout {
                                    spacing: 2
                                    Layout.preferredWidth: 100
                                    
                                    Label {
                                        text: "Cantidad:"
                                        color: textColor
                                        font.bold: true
                                        font.pixelSize: 12
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: 100
                                        height: 32
                                        color: "#f8f9fa"
                                        radius: 4
                                        border.color: cantidadField.activeFocus ? blueColor : "#ddd"
                                        border.width: 1
                                        
                                        TextInput {
                                            id: cantidadField
                                            anchors.fill: parent
                                            anchors.margins: 6
                                            font.pixelSize: fontMedium
                                            font.bold: true
                                            color: textColor
                                            validator: IntValidator { bottom: 1 }
                                            horizontalAlignment: Text.AlignRight
                                            verticalAlignment: Text.AlignVCenter
                                            
                                            onTextChanged: {
                                                inputCantidad = parseInt(text) || 0
                                                calcularPreciosAutomaticos()
                                            }
                                            
                                            onFocusChanged: if (focus) selectAll()
                                        }
                                    }
                                }
                                
                                // PRECIO TOTAL
                                ColumnLayout {
                                    spacing: 2
                                    Layout.preferredWidth: 120
                                    
                                    Label {
                                        text: "Precio TOTAL:"
                                        color: textColor
                                        font.bold: true
                                        font.pixelSize: 12
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: 120
                                        height: 32
                                        color: "#fff8e1"
                                        radius: 4
                                        border.color: precioTotalField.activeFocus ? "#ffb74d" : "#ffecb3"
                                        border.width: 1
                                        
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 4
                                            spacing: 2
                                            
                                            Label {
                                                text: "Bs"
                                                color: "#f57c00"
                                                font.bold: true
                                                font.pixelSize: 12
                                            }
                                            
                                            TextInput {
                                                id: precioTotalField
                                                Layout.fillWidth: true
                                                font.pixelSize: fontMedium
                                                font.bold: true
                                                color: "#f57c00"
                                                validator: RegularExpressionValidator { regularExpression: /^\d*\.?\d{0,2}$/ }
                                                horizontalAlignment: Text.AlignRight
                                                verticalAlignment: Text.AlignVCenter
                                                
                                                onTextChanged: {
                                                    inputPrecioTotalCompra = parseFloat(text) || 0.0
                                                    calcularPreciosAutomaticos()
                                                }
                                                
                                                onFocusChanged: if (focus) selectAll()
                                            }
                                        }
                                    }
                                }
                                
                                // COSTO UNITARIO
                                ColumnLayout {
                                    spacing: 2
                                    Layout.preferredWidth: 100
                                    
                                    Label {
                                        text: "Costo c/u:"
                                        color: textColor
                                        font.bold: true
                                        font.pixelSize: 12
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: 100
                                        height: 32
                                        color: "#e3f2fd"
                                        radius: 4
                                        border.color: "#2196f3"
                                        border.width: 1
                                        
                                        Label {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            text: "Bs " + inputPrecioUnitarioCalculado.toFixed(2)
                                            color: "#1565c0"
                                            font.bold: true
                                            font.pixelSize: 12
                                            horizontalAlignment: Text.AlignRight
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                }
                                
                                // PRECIO VENTA
                                ColumnLayout {
                                    spacing: 2
                                    Layout.preferredWidth: 120
                                    
                                    Label {
                                        text: "Precio VENTA:"
                                        color: textColor
                                        font.bold: true
                                        font.pixelSize: 12
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: 120
                                        height: 32
                                        color: "#e8f5e9"
                                        radius: 4
                                        border.color: precioVentaField.activeFocus ? "#4caf50" : "#a5d6a7"
                                        border.width: 1
                                        
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 4
                                            spacing: 2
                                            
                                            Label {
                                                text: "Bs"
                                                color: "#2e7d32"
                                                font.bold: true
                                                font.pixelSize: 12
                                            }
                                            
                                            TextInput {
                                                id: precioVentaField
                                                Layout.fillWidth: true
                                                font.pixelSize: fontMedium
                                                font.bold: true
                                                color: "#2e7d32"
                                                validator: RegularExpressionValidator { regularExpression: /^\d*\.?\d{0,2}$/ }
                                                horizontalAlignment: Text.AlignRight
                                                verticalAlignment: Text.AlignVCenter
                                                
                                                text: inputPrecioVentaUnitario > 0 ? inputPrecioVentaUnitario.toFixed(2) : ""
                                                
                                                onTextChanged: {
                                                    inputPrecioVentaUnitario = parseFloat(text) || 0.0
                                                    validarProductoParaAgregar()
                                                }
                                                
                                                onFocusChanged: if (focus) selectAll()
                                            }
                                        }
                                    }
                                }
                                
                                // VENCIMIENTO
                                ColumnLayout {
                                    spacing: 2
                                    Layout.preferredWidth: 150
                                    
                                    Label {
                                        text: "Vencimiento:"
                                        color: textColor
                                        font.bold: true
                                        font.pixelSize: 12
                                    }
                                    
                                    RowLayout {
                                        spacing: 4
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 100
                                            height: 32
                                            color: inputNoExpiry ? "#f5f5f5" : "white"
                                            radius: 4
                                            border.color: expiryField.activeFocus ? "#9c27b0" : "#ddd"
                                            border.width: 1
                                            
                                            TextInput {
                                                id: expiryField
                                                anchors.fill: parent
                                                anchors.margins: 6
                                                font.pixelSize: 14
                                                color: textColor
                                                enabled: !inputNoExpiry
                                                horizontalAlignment: Text.AlignCenter
                                                verticalAlignment: Text.AlignVCenter
                                                
                                                text: inputExpiryDate
                                                
                                                onTextChanged: {
                                                    if (!inputNoExpiry) inputExpiryDate = text
                                                    validarProductoParaAgregar()
                                                }
                                                
                                                onFocusChanged: if (focus) selectAll()
                                                
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "AAAA-MM-DD"
                                                    color: "#999"
                                                    font.pixelSize: 14
                                                    visible: parent.text.length === 0 && !inputNoExpiry
                                                }
                                            }
                                        }
                                        
                                        CheckBox {
                                            id: noExpiryCheckbox
                                            text: "Sin venc."
                                            font.pixelSize: 12
                                            checked: inputNoExpiry
                                            Layout.preferredHeight: 40
                                            onCheckedChanged: {
                                                inputNoExpiry = checked
                                                if (checked) {
                                                    inputExpiryDate = ""
                                                    expiryField.text = ""
                                                }
                                                validarProductoParaAgregar()
                                            }
                                        }
                                    }
                                }
                                
                                // BOTÓN AGREGAR
                                Button {
                                    Layout.preferredWidth: 140
                                    Layout.preferredHeight: 40
                                    Layout.alignment: Qt.AlignVCenter
                                    enabled: productoValidoParaAgregar
                                    text: productoEditandoIndex >= 0 ? "✏️ ACTUALIZAR" : "➕ AGREGAR"
                                    
                                    background: Rectangle {
                                        color: parent.enabled ? (parent.hovered ? "#1976d2" : blueColor) : lightGrayColor
                                        radius: 4
                                    }
                                    
                                    contentItem: Label {
                                        text: parent.text
                                        color: whiteColor
                                        font.bold: true
                                        font.pixelSize: 12
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    
                                    onClicked: agregarProductoACompra()
                                }
                            }
                        }
                    }
                    
                    // LISTA DE PRODUCTOS - COMPACTA CON ENCABEZADOS (MEJORADA)
                    Rectangle {
                        Layout.fillWidth: true
                        height: 400  // ✅ AUMENTADA DE 350 A 400
                        color: whiteColor
                        radius: 8
                        border.color: "#e0e0e0"
                        border.width: 1
                        
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: spacing8
                            spacing: spacing4
                            
                            RowLayout {
                                Label {
                                    text: "🛒 PRODUCTOS EN LA COMPRA"
                                    color: textColor
                                    font.bold: true
                                    font.pixelSize: fontSmall
                                }
                                
                                Item { Layout.fillWidth: true }
                                
                                Label {
                                    text: compraModel ? compraModel.items_en_compra + " items" : "0 items"
                                    color: darkGrayColor
                                    font.pixelSize: fontSmall
                                }
                            }
                            
                            // ✅ ENCABEZADOS DE COLUMNA (CON PRECIO VENTA)
                            Rectangle {
                                Layout.fillWidth: true
                                height: 40  // ✅ AUMENTADA DE 35 A 40
                                color: "#1976d2"
                                radius: 4
                                
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: spacing8
                                    spacing: spacing8
                                    
                                    // CÓDIGO
                                    Label {
                                        text: "CÓDIGO"
                                        color: whiteColor
                                        font.bold: true
                                        font.pixelSize: 12  // ✅ AUMENTADO
                                        Layout.preferredWidth: 80
                                    }
                                    
                                    // PRODUCTO
                                    Label {
                                        text: "PRODUCTO"
                                        color: whiteColor
                                        font.bold: true
                                        font.pixelSize: 12  // ✅ AUMENTADO
                                        Layout.fillWidth: true
                                    }
                                    
                                    // CANTIDAD
                                    Label {
                                        text: "CANT."
                                        color: whiteColor
                                        font.bold: true
                                        font.pixelSize: 12  // ✅ AUMENTADO
                                        Layout.preferredWidth: 60  // ✅ AUMENTADO
                                        horizontalAlignment: Text.AlignRight
                                    }
                                    
                                    // PRECIO VENTA (NUEVA COLUMNA)
                                    Label {
                                        text: "PRECIO V."
                                        color: whiteColor
                                        font.bold: true
                                        font.pixelSize: 12  // ✅ AUMENTADO
                                        Layout.preferredWidth: 80  // ✅ AUMENTADO
                                        horizontalAlignment: Text.AlignRight
                                    }
                                    
                                    // VENCIMIENTO
                                    Label {
                                        text: "VENCIMIENTO"
                                        color: whiteColor
                                        font.bold: true
                                        font.pixelSize: 12  // ✅ AUMENTADO
                                        Layout.preferredWidth: 100
                                        horizontalAlignment: Text.AlignCenter
                                    }
                                    
                                    // TOTAL
                                    Label {
                                        text: "TOTAL"
                                        color: whiteColor
                                        font.bold: true
                                        font.pixelSize: 12  // ✅ AUMENTADO
                                        Layout.preferredWidth: 90  // ✅ AUMENTADO
                                        horizontalAlignment: Text.AlignRight
                                    }
                                    
                                    // ACCIONES
                                    Label {
                                        text: "ACCIONES"
                                        color: whiteColor
                                        font.bold: true
                                        font.pixelSize: 12  // ✅ AUMENTADO
                                        Layout.preferredWidth: 80  // ✅ AUMENTADO
                                        horizontalAlignment: Text.AlignCenter
                                    }
                                }
                            }
                            
                            // ✅ LISTA COMPACTA CON DATOS CORRECTOS (MEJORADA)
                            ListView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                model: compraModel ? compraModel.items_compra : []
                                spacing: 2
                                
                                delegate: Rectangle {
                                    width: parent ? parent.width : 0
                                    height: 44  // ✅ AUMENTADA DE 40 A 44
                                    color: index % 2 === 0 ? '#f5f5f5' : whiteColor
                                    radius: 4
                                    
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: spacing6  // ✅ AUMENTADO DE spacing4 A spacing6
                                        spacing: spacing8
                                        
                                        // CÓDIGO
                                        Label {
                                            text: modelData.codigo || ""
                                            color: textColor
                                            font.bold: true
                                            font.pixelSize: fontMedium  // ✅ AUMENTADO DE Small A Medium
                                            Layout.preferredWidth: 80
                                            elide: Text.ElideRight
                                        }
                                        
                                        // NOMBRE
                                        Label {
                                            text: modelData.nombre || ""
                                            color: textColor
                                            font.pixelSize: fontMedium  // ✅ AUMENTADO DE Small A Medium
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }
                                        
                                        // CANTIDAD
                                        Label {
                                            text: modelData.cantidad || 0
                                            color: blueColor
                                            font.bold: true
                                            font.pixelSize: fontMedium  // ✅ AUMENTADO DE Small A Medium
                                            Layout.preferredWidth: 60  // ✅ AUMENTADO
                                            horizontalAlignment: Text.AlignRight
                                        }
                                        
                                        // ✅ PRECIO VENTA
                                        Label {
                                            text: {
                                                var precio = modelData.precio_venta
                                                if (precio !== undefined && precio !== null && parseFloat(precio) > 0) {
                                                    return "Bs " + parseFloat(precio).toFixed(2)
                                                } else {
                                                    return "—"
                                                }
                                            }
                                            color: {
                                                var precio = modelData.precio_venta
                                                if (precio !== undefined && precio !== null && parseFloat(precio) > 0) {
                                                    return "#2e7d32"
                                                } else {
                                                    return darkGrayColor
                                                }
                                            }
                                            font.bold: modelData.precio_venta !== undefined && modelData.precio_venta !== null && parseFloat(modelData.precio_venta) > 0
                                            font.pixelSize: fontMedium
                                            Layout.preferredWidth: 80
                                            horizontalAlignment: Text.AlignRight
                                        }
                                        
                                        // FECHA DE VENCIMIENTO
                                        Label {
                                            text: modelData.vencimiento || "Sin venc."
                                            color: modelData.vencimiento ? "#ff9800" : darkGrayColor
                                            font.pixelSize: 11  // ✅ AUMENTADO DE 10 A 11
                                            Layout.preferredWidth: 100
                                            horizontalAlignment: Text.AlignCenter
                                            elide: Text.ElideRight
                                        }
                                        
                                        // TOTAL
                                        Label {
                                            text: "Bs " + (modelData.subtotal || 0).toFixed(2)
                                            color: successColor
                                            font.bold: true
                                            font.pixelSize: fontMedium  // ✅ AUMENTADO
                                            Layout.preferredWidth: 90  // ✅ AUMENTADO
                                            horizontalAlignment: Text.AlignRight
                                        }
                                        
                                        // BOTONES EDITAR/ELIMINAR CON ICONOS SVG
                                        RowLayout {
                                            spacing: spacing6  // ✅ AUMENTADO DE spacing4 A spacing6
                                            Layout.preferredWidth: 80  // ✅ AUMENTADO
                                            Layout.alignment: Qt.AlignHCenter
                                            
                                            // BOTÓN EDITAR CON SVG
                                            Button {
                                                Layout.preferredWidth: 32  // ✅ AUMENTADO
                                                Layout.preferredHeight: 32  // ✅ AUMENTADO
                                                padding: 0
                                                
                                                background: Rectangle {
                                                    color: parent.hovered ? "#e3f2fd" : "transparent"
                                                    radius: 4
                                                    border.color: parent.hovered ? blueColor : "transparent"
                                                    border.width: 1
                                                }
                                                
                                                contentItem: Text {
                                                    text: "✎" // O "Editar", "E", etc.
                                                    font.pixelSize: 16
                                                    font.bold: true
                                                    anchors.centerIn: parent
                                                    color: "blue" // O tu color preferido
                                                }
                                                
                                                onClicked: {
                                                    console.log("📝 Editando producto:", index)
                                                    
                                                    // Usar código, no ID (los items no tienen ID, solo código)
                                                    inputProductCode = modelData.codigo || ""
                                                    inputProductName = modelData.nombre || ""
                                                    inputCantidad = modelData.cantidad || 0
                                                    inputPrecioTotalCompra = modelData.subtotal || 0
                                                    inputPrecioUnitarioCalculado = modelData.precio_unitario || 0
                                                    
                                                    // ✅ CORRECCIÓN: Precio de venta - usar correctamente el campo del modelo
                                                    if (modelData.precio_venta !== undefined && modelData.precio_venta > 0) {
                                                        inputPrecioVentaUnitario = parseFloat(modelData.precio_venta)
                                                        console.log("💰 Precio venta cargado para edición:", inputPrecioVentaUnitario)
                                                    } else {
                                                        inputPrecioVentaUnitario = 0
                                                        console.log("💰 No hay precio venta en el producto")
                                                    }
                                                    
                                                    // Fecha de vencimiento
                                                    var venc = modelData.vencimiento || ""
                                                    inputExpiryDate = venc === "Sin vencimiento" ? "" : venc
                                                    inputNoExpiry = (venc === "" || venc === "Sin vencimiento")
                                                    
                                                    productoEditandoIndex = index
                                                    
                                                    // ✅ CORRECCIÓN: Actualizar campos visuales usando Qt.callLater para asegurar que se actualicen
                                                    Qt.callLater(function() {
                                                        if (productCodeField) productCodeField.text = inputProductName
                                                        if (cantidadField) cantidadField.text = inputCantidad.toString()
                                                        if (precioTotalField) precioTotalField.text = inputPrecioTotalCompra.toFixed(2)
                                                        if (expiryField) expiryField.text = inputExpiryDate
                                                        if (precioVentaField) {
                                                            precioVentaField.text = inputPrecioVentaUnitario > 0 ? inputPrecioVentaUnitario.toFixed(2) : ""
                                                            console.log("✅ Campo precioVentaField actualizado a:", precioVentaField.text)
                                                        }
                                                        
                                                        calcularPreciosAutomaticos()
                                                    })
                                                }
                                            }
                                            
                                            // BOTÓN ELIMINAR CON SVG
                                            Button {
                                                Layout.preferredWidth: 32  // ✅ AUMENTADO
                                                Layout.preferredHeight: 32  // ✅ AUMENTADO
                                                padding: 0
                                                
                                                background: Rectangle {
                                                    color: parent.hovered ? "#ffebee" : "transparent"
                                                    radius: 4
                                                    border.color: parent.hovered ? errorColor : "transparent"
                                                    border.width: 1
                                                }
                                                
                                                contentItem: Text {
                                                    text: "X" // Icono de eliminar de FontAwesome
                                                    font.family: "FontAwesome"
                                                    font.pixelSize: 16  // ✅ AUMENTADO
                                                    anchors.centerIn: parent
                                                    color: "red"
                                                }
                                                
                                                onClicked: {
                                                    console.log("🗑️ Eliminando producto:", index)
                                                    if (compraModel) {
                                                        var eliminado = compraModel.remover_item_compra(index)
                                                        if (eliminado) {
                                                            showSuccess("Producto eliminado")
                                                            // Si estaba editando este producto, limpiar
                                                            if (productoEditandoIndex === index) {
                                                                limpiarFormulario()
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // ✅ Mensaje lista vacía
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                color: "transparent"
                                visible: !compraModel || compraModel.items_en_compra === 0
                                
                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: spacing8
                                    
                                    Label {
                                        text: "📭"
                                        font.pixelSize: 24
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                    
                                    Label {
                                        text: "No hay productos en la compra"
                                        color: darkGrayColor
                                        font.pixelSize: fontSmall
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                    
                                    Label {
                                        text: "Agrega productos usando el formulario de arriba"
                                        color: "#999"
                                        font.pixelSize: 10
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // BOTONES INFERIORES FIJOS
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 70
            color: whiteColor
            border.color: "#e0e0e0"
            border.width: 1
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: spacing12
                spacing: spacing12
                
                Button {
                    text: "❌ CANCELAR"
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 42
                    font.bold: true
                    
                    background: Rectangle {
                        color: parent.pressed ? "#d32f2f" : dangerColor
                        radius: 6
                    }
                    
                    onClicked: cancelarCompra()
                }
                
                Item { Layout.fillWidth: true }
                
                Button {
                    id: completarCompraButton
                    text: modoEdicion ? "💾 GUARDAR CAMBIOS" : "✅ COMPLETAR COMPRA"
                    Layout.preferredWidth: 200
                    Layout.preferredHeight: 42
                    font.bold: true
                    
                    enabled: (
                        providerCombo && providerCombo.currentIndex > 0 &&
                        compraModel && compraModel.items_en_compra > 0 &&
                        !procesandoCompra
                    )
                    
                    background: Rectangle {
                        color: parent.enabled ? (parent.pressed ? "#388e3c" : successColor) : "#bdbdbd"
                        radius: 6
                    }
                    
                    onClicked: {
                        if (completarCompra()) {
                            procesandoCompra = true
                            completarCompraButton.text = "⏳ PROCESANDO..."
                            resetButtonTimer.start()
                        }
                    }
                }
            }
        }
        
        // MENSAJE DE ÉXITO
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 80
            width: Math.min(parent.width * 0.8, 400)
            height: 50
            color: "#4caf50"
            radius: 8
            visible: showSuccessMessage
            z: 1000
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: spacing8
                spacing: spacing8
                
                Label {
                    text: "✅"
                    font.pixelSize: 20
                }
                
                Label {
                    text: successMessage
                    color: whiteColor
                    font.bold: true
                    font.pixelSize: fontSmall
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                }
            }
        }
    }

    // CONEXIONES
    Connections {
        target: compraModel
        function onItemsCompraCambiado() {
            updatePurchaseTotal()
        }
    }

    Component.onCompleted: {
        console.log("✅ CrearCompra.qml - UX Mejorada")
        
        // Configurar fecha actual
        var fecha = new Date()
        newPurchaseDate = fecha.getDate().toString().padStart(2, '0') + "/" +
                         (fecha.getMonth() + 1).toString().padStart(2, '0') + "/" +
                         fecha.getFullYear()
        
        if (!modoEdicion && compraModel) {
            newPurchaseId = "C" + String((compraModel.total_compras_mes || 0) + 1).padStart(3, '0')
        }
        
        // Cargar proveedores
        Qt.callLater(function() {
            if (compraModel) {
                compraModel.force_refresh_proveedores()
                Qt.callLater(function() {
                    updateProviderNames()
                }, 500)
            }
        })
        
        // Conectar señal para crear producto
        crearCompraRoot.solicitarCrearProducto.connect(function(nombreProducto) {
            if (abrirModalCrearProductoFunction) {
                abrirModalCrearProductoFunction(nombreProducto)
            }
        })
    }
    
    // FUNCIÓN AÑADIDA FALTANTE
    function updateProviderNames() {
        var names = ["Seleccionar proveedor..."]
        if (compraModel && compraModel.proveedores) {
            var proveedores = compraModel.proveedores
            for (var i = 0; i < proveedores.length; i++) {
                var provider = proveedores[i]
                if (provider && (provider.Nombre || provider.nombre)) {
                    var nombreProveedor = provider.Nombre || provider.nombre
                    names.push(nombreProveedor)
                }
            }
        }
        providerNames = names
    }
    
    // FUNCIÓN AÑADIDA FALTANTE
    function cargarDatosEdicion() {
        if (!modoEdicion || !compraModel) return
        
        console.log("📋 Cargando datos para edición - Compra:", compraIdEdicion)
        
        newPurchaseId = `C${String(compraIdEdicion).padStart(3, '0')}`
        
        var datosOrig = datosOriginales
        if (datosOrig && datosOrig.proveedor) {
            newPurchaseProvider = datosOrig.proveedor
            
            for (var i = 0; i < providerNames.length; i++) {
                if (providerNames[i] === datosOrig.proveedor) {
                    if (providerCombo) providerCombo.currentIndex = i
                    break
                }
            }
        }
        
        if (datosOrig && datosOrig.fecha) {
            try {
                var fechaStr = datosOrig.fecha.toString()
                if (fechaStr && fechaStr.length > 0) newPurchaseDate = fechaStr
            } catch (e) {
                console.log("⚠️ Error al convertir fecha:", e)
                var fechaActual = new Date()
                var dia = fechaActual.getDate().toString().padStart(2, '0')
                var mes = (fechaActual.getMonth() + 1).toString().padStart(2, '0')
                var año = fechaActual.getFullYear()
                newPurchaseDate = dia + "/" + mes + "/" + año
            }
        }
        
        updatePurchaseTotal()
        showSuccess("Compra cargada para edición")
    }
}