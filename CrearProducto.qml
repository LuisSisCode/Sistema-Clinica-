import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15

// ===============================================================================
// CREAR PRODUCTO - FIFO 2.0 (DISEÑO MODAL CENTRADO)
// ===============================================================================
// Versión Rectangle con overlay semi-transparente + modal centrado
// - Sin sombra (más simple y rápido)
// - Click en overlay NO cierra (más seguro)
// - Modal flotante de 900x550px centrado
// ===============================================================================

Rectangle {
    id: overlayRoot
    anchors.fill: parent
    color: "#80000000"  // Overlay semi-transparente (negro 50%)
    
    // ===============================
    // PROPIEDADES DE COMUNICACIÓN
    // ===============================
    property var inventarioModel: null
    property var farmaciaData: null
    property bool modoEdicion: false
    property var productoData: null
    property var marcasModel: []
    
    // ===============================
    // SEÑALES
    // ===============================
    signal productoCreado(var producto)
    signal productoActualizado(var producto) 
    signal cancelarCreacion()
    signal volverALista() 
    
    // ===============================
    // MÉTRICAS DEL DISEÑO
    // ===============================
    readonly property real baseSpacing: 12
    readonly property real cardPadding: 16
    readonly property real inputHeight: 40
    readonly property real buttonHeight: 45
    readonly property real headerHeight: 60
    readonly property real sectionSpacing: 12
    
    // ===============================
    // COLORES (CONSERVADOS)
    // ===============================
    readonly property color primaryBlue: "#2563EB"
    readonly property color successGreen: "#059669"
    readonly property color warningAmber: "#D97706"
    readonly property color dangerRed: "#DC2626"
    readonly property color grayLight: "#F3F4F6"
    readonly property color grayMedium: "#6B7280"
    readonly property color grayDark: "#374151"
    readonly property color white: "#FFFFFF"
    readonly property color borderColor: "#D1D5DB"
    
    // ===============================
    // ESTADOS
    // ===============================
    property bool showSuccessMessage: false
    property string successMessage: ""
    property bool showErrorMessage: false
    property string errorMessage: ""
    property bool marcasCargadas: false
    
    // ===============================
    // DATOS DEL FORMULARIO - FIFO 2.0
    // ===============================
    property string inputProductCode: ""
    property string inputProductName: ""
    property string inputProductDetails: ""
    property string inputMeasureUnit: "Tabletas"
    property string inputMarca: ""
    property int inputStockMinimo: 10
    property int inputStockMaximo: 100

    // ===============================
    // PROPIEDADES DE MARCA
    // ===============================
    property int marcaIdSeleccionada: 0
    property string marcaSeleccionadaNombre: ""
    property bool marcasListenerConnected: false

    // ===============================
    // TIMERS
    // ===============================
    Timer {
        id: successTimer
        interval: 3000
        onTriggered: showSuccessMessage = false
    }

    Timer {
        id: errorTimer
        interval: 4000
        onTriggered: showErrorMessage = false
    }

    // ===============================
    // FUNCIONES DE VALIDACIÓN
    // ===============================
    
    function generarCodigoAutomatico() {
        return "PROD" + String(Date.now()).slice(-6)
    }

    function validarNombreProducto() {
        if (inputProductName.trim().length === 0) {
            return {valido: false, mensaje: "El nombre del producto es obligatorio"}
        }
        if (inputProductName.trim().length < 2) {
            return {valido: false, mensaje: "El nombre del producto debe tener al menos 2 caracteres"}
        }
        if (inputProductName.trim().length > 100) {
            return {valido: false, mensaje: "El nombre del producto no puede exceder 100 caracteres"}
        }
        return {valido: true, mensaje: ""}
    }

    function validarMarca() {
        console.log("🔍 Validando marca - ID:", marcaIdSeleccionada, "Nombre:", marcaSeleccionadaNombre)
        
        if (marcaIdSeleccionada === 0 || !marcaSeleccionadaNombre) {
            console.log("❌ Validación falló: Marca no seleccionada")
            return {valido: false, mensaje: "Debe seleccionar una marca válida para el producto"}
        }
        
        // Verificar que la marca existe en el modelo
        var marcaExiste = false
        if (marcasModel && marcasModel.length > 0) {
            for (var i = 0; i < marcasModel.length; i++) {
                var marca = marcasModel[i]
                if (marca.id === marcaIdSeleccionada) {
                    marcaExiste = true
                    break
                }
            }
        }
        
        if (!marcaExiste) {
            console.log("❌ Validación falló: Marca no encontrada en modelo")
            return {valido: false, mensaje: "La marca seleccionada no es válida"}
        }
        
        console.log("✅ Validación de marca exitosa")
        return {valido: true, mensaje: ""}
    }

    function validarStockMinimo() {
        if (inputStockMinimo < 0) {
            return {valido: false, mensaje: "El stock mínimo no puede ser negativo"}
        }
        return {valido: true, mensaje: ""}
    }

    function validarStockMaximo() {
        if (inputStockMaximo < inputStockMinimo) {
            return {valido: false, mensaje: "El stock máximo debe ser mayor al stock mínimo"}
        }
        return {valido: true, mensaje: ""}
    }
    
    // ===============================
    // FUNCIÓN GUARDAR PRODUCTO
    // ===============================
    function guardarProducto() {
        console.log("💾 Iniciando guardado de producto FIFO 2.0")
        console.log("   - marcaIdSeleccionada:", marcaIdSeleccionada)
        console.log("   - marcaSeleccionadaNombre:", marcaSeleccionadaNombre)
        console.log("   - stockMinimo:", inputStockMinimo)
        console.log("   - stockMaximo:", inputStockMaximo)

        // ✅ VALIDACIÓN CRÍTICA DE MARCA
        if (marcaIdSeleccionada === 0 || !marcaSeleccionadaNombre) {
            console.log("❌ GUARDADO BLOQUEADO: Marca no seleccionada")
            showError("Debe seleccionar una marca válida para el producto")
            if (marcaComboBox) {
                marcaComboBox.forceActiveFocus()
            }
            return false
        }

        // Generar código automático si está vacío (solo en creación)
        if (!modoEdicion && inputProductCode.trim().length === 0) {
            inputProductCode = generarCodigoAutomatico()
            if (codigoField) {
                codigoField.text = inputProductCode
            }
        }

        // Validaciones específicas
        var validacionNombre = validarNombreProducto()
        if (!validacionNombre.valido) {
            showError(validacionNombre.mensaje)
            if (nombreField) nombreField.forceActiveFocus()
            return false
        }

        var validacionMarca = validarMarca()
        if (!validacionMarca.valido) {
            showError(validacionMarca.mensaje)
            return false
        }

        var validacionStockMin = validarStockMinimo()
        if (!validacionStockMin.valido) {
            showError(validacionStockMin.mensaje)
            return false
        }

        var validacionStockMax = validarStockMaximo()
        if (!validacionStockMax.valido) {
            showError(validacionStockMax.mensaje)
            return false
        }

        // ✅ CREAR OBJETO PRODUCTO FIFO 2.0
        var producto = {
            codigo: inputProductCode.trim(),
            nombre: inputProductName.trim(),
            detalles: inputProductDetails.trim(),
            unidad_medida: inputMeasureUnit,
            marca_id: marcaIdSeleccionada,
            marca: marcaSeleccionadaNombre,
            stock_minimo: inputStockMinimo,
            stock_maximo: inputStockMaximo
        }

        console.log("📦 Producto a guardar:", JSON.stringify(producto))

        // GUARDAR EN BASE DE DATOS
        if (!inventarioModel) {
            showError("Sistema no disponible")
            return false
        }

        try {
            var exito = false
            
            if (modoEdicion) {
                console.log("✏️ Actualizando producto existente")
                exito = inventarioModel.actualizar_producto(producto.codigo, JSON.stringify(producto))
                
                if (exito) {
                    console.log("✅ Producto actualizado exitosamente")
                    showMessage("Producto actualizado correctamente")
                    productoActualizado(producto)
                    
                    Qt.callLater(function() {
                        volverALista()
                    })
                } else {
                    showError("Error al actualizar el producto")
                    return false
                }
            } else {
                console.log("🆕 Creando nuevo producto")
                exito = inventarioModel.crear_producto(JSON.stringify(producto))
                
                if (exito) {
                    console.log("✅ Producto creado exitosamente")
                    showMessage("Producto creado correctamente")
                    productoCreado(producto)
                    
                    Qt.callLater(function() {
                        volverALista()
                    })
                } else {
                    showError("Error al crear el producto")
                    return false
                }
            }
            
            return exito
            
        } catch (error) {
            console.log("❌ Error guardando producto:", error.toString())
            showError("Error: " + error.toString())
            return false
        }
    }

    function limpiarFormularioSeguro() {
        try {
            inputProductCode = ""
            inputProductName = ""
            inputProductDetails = ""
            inputMeasureUnit = "Tabletas"
            inputStockMinimo = 10
            inputStockMaximo = 100
            marcaIdSeleccionada = 0
            marcaSeleccionadaNombre = ""
            
            if (codigoField) codigoField.text = ""
            if (nombreField) nombreField.text = ""
            if (detallesField) detallesField.text = ""
            if (stockMinimoField) stockMinimoField.text = "10"
            if (stockMaximoField) stockMaximoField.text = "100"
            if (unidadCombo) unidadCombo.currentIndex = 0
            if (marcaComboBox) marcaComboBox.reset()
            
            showSuccessMessage = false
            showErrorMessage = false
            
            console.log("🧹 Formulario limpiado")
        } catch (error) {
            console.log("⚠️ Error en limpieza:", error)
        }
    }
    
    // ===============================
    // MENSAJES
    // ===============================
    function showMessage(mensaje) {
        try {
            successMessage = mensaje
            showSuccessMessage = true
            showErrorMessage = false
            successTimer.restart()
            console.log("📢 Mostrando mensaje:", mensaje)
        } catch (error) {
            console.log("⚠️ Error mostrando mensaje:", error)
        }
    }

    function showError(mensaje) {
        try {
            errorMessage = mensaje
            showErrorMessage = true
            showSuccessMessage = false
            errorTimer.restart()
            console.log("❌ Mostrando error:", mensaje)
        } catch (error) {
            console.log("⚠️ Error mostrando error:", error)
        }
    }

    // ===============================
    // FUNCIONES DE MARCAS
    // ===============================
    function cargarMarcasDisponibles() {
        if (!inventarioModel) {
            console.log("⚠️ No hay inventarioModel disponible para cargar marcas")
            return
        }
        
        try {
            var marcasDisponibles = inventarioModel.marcasDisponibles || []
            console.log("🏷️ Marcas disponibles cargadas:", marcasDisponibles.length)
            marcasModel = marcasDisponibles
            marcasCargadas = true
        } catch (error) {
            console.log("❌ Error cargando marcas:", error)
        }
    }

    // ===============================
    // INICIALIZACIÓN
    // ===============================
    function inicializarParaCrear() {
        console.log("🆕 Inicializando para CREAR producto")
        modoEdicion = false
        limpiarFormularioSeguro()
        cargarMarcasDisponibles()
        
        // Campos editables
        if (codigoField) codigoField.readOnly = false
    }

    function inicializarParaEditar(producto) {
        console.log("✏️ Inicializando para EDITAR producto:", producto.codigo)
        modoEdicion = true
        productoData = producto
        
        // Cargar datos del producto
        inputProductCode = producto.codigo || ""
        inputProductName = producto.nombre || ""
        inputProductDetails = producto.detalles || ""
        inputMeasureUnit = producto.unidad_medida || "Tabletas"
        inputStockMinimo = producto.stock_minimo || 10
        inputStockMaximo = producto.stock_maximo || 100
        
        marcaIdSeleccionada = producto.marca_id || 0
        marcaSeleccionadaNombre = producto.marca || ""
        
        // Actualizar UI
        if (codigoField) {
            codigoField.text = inputProductCode
            codigoField.readOnly = true  // Código no editable en modo edición
        }
        if (nombreField) nombreField.text = inputProductName
        if (detallesField) detallesField.text = inputProductDetails
        if (stockMinimoField) stockMinimoField.text = inputStockMinimo.toString()
        if (stockMaximoField) stockMaximoField.text = inputStockMaximo.toString()
        
        // Buscar índice de unidad de medida
        if (unidadCombo) {
            var unidades = ["Tabletas", "Cápsulas", "ml", "mg", "g", "Unidades", "Sobres", "Frascos", "Ampollas", "Jeringas"]
            var indice = unidades.indexOf(inputMeasureUnit)
            if (indice !== -1) {
                unidadCombo.currentIndex = indice
            }
        }
        
        // Cargar marcas y seleccionar la correcta
        cargarMarcasDisponibles()
        
        if (marcaComboBox && marcaIdSeleccionada > 0) {
            Qt.callLater(function() {
                marcaComboBox.forzarSeleccion(marcaIdSeleccionada, marcaSeleccionadaNombre)
            })
        }
    }

    // ===============================
    // MODAL CENTRADO
    // ===============================
    Rectangle {
        id: modalContent
        width: 900
        height: 550
        anchors.centerIn: parent
        color: white
        radius: 12
        border.color: borderColor
        border.width: 1
        
        // Detiene propagación de clicks al overlay
        MouseArea {
            anchors.fill: parent
            onClicked: {} // No hace nada, solo detiene propagación
        }
        
        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            
            // ===============================
            // HEADER (MEJORADO)
            // ===============================
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: headerHeight
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
                    anchors.leftMargin: cardPadding
                    anchors.rightMargin: cardPadding
                    spacing: baseSpacing
                    
                    Rectangle {
                        Layout.preferredWidth: 4
                        Layout.fillHeight: true
                        Layout.topMargin: 8
                        Layout.bottomMargin: 8
                        color: "#3498db"
                        radius: 2
                    }
                    
                    Column {
                        spacing: 2
                        
                        Text {
                            text: modoEdicion ? "✏️ Editar Producto" : "➕ Nuevo Producto"
                            font.pixelSize: 18
                            font.bold: true
                            color: "white"
                        }
                        
                        Text {
                            text: modoEdicion ? "Actualizar información del producto" : "Crear producto base (stock y precio en primera compra)"
                            font.pixelSize: 12
                            color: "white"
                            opacity: 0.9
                        }
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    Button {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        
                        background: Rectangle {
                            color: parent.pressed ? "#34495E" : "transparent"
                            border.color: "white"
                            border.width: 1
                            radius: 8
                        }
                        
                        contentItem: Text {
                            text: "×"
                            color: "white"
                            font.pixelSize: 18
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: {
                            cancelarCreacion()
                        }
                    }
                }
            }

            // ===============================
            // CONTENIDO PRINCIPAL
            // ===============================
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: grayLight
                
                ScrollView {
                    anchors.fill: parent
                    anchors.margins: baseSpacing
                    clip: true
                    
                    Rectangle {
                        width: parent.width
                        height: allContent.height + cardPadding * 2
                        color: white
                        radius: 8
                        border.color: borderColor
                        border.width: 1
                        
                        ColumnLayout {
                            id: allContent
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: cardPadding
                            spacing: 16
                            
                            // ===============================
                            // ℹ️ BANNER INFORMATIVO FIFO 2.0
                            // ===============================
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: bannerContent.height + 20
                                color: "#EFF6FF"
                                border.color: "#3B82F6"
                                border.width: 2
                                radius: 8
                                visible: !modoEdicion
                                
                                ColumnLayout {
                                    id: bannerContent
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.margins: 12
                                    spacing: 8
                                    
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        
                                        Text {
                                            text: "ℹ️"
                                            font.pixelSize: 18
                                            color: "#3B82F6"
                                        }
                                        
                                        Text {
                                            text: "INFORMACIÓN IMPORTANTE"
                                            font.pixelSize: 13
                                            font.bold: true
                                            color: grayDark
                                        }
                                    }
                                    
                                    Text {
                                        Layout.fillWidth: true
                                        text: "• El stock se calculará automáticamente al registrar compras"
                                        font.pixelSize: 12
                                        color: grayDark
                                        wrapMode: Text.WordWrap
                                    }
                                    
                                    Text {
                                        Layout.fillWidth: true
                                        text: "• El precio de venta se definirá en la primera compra del producto"
                                        font.pixelSize: 12
                                        color: grayDark
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }
                            
                            // ===============================
                            // FILA 1: Código, Nombre, Marca
                            // ===============================
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12
                                
                                // CÓDIGO
                                ColumnLayout {
                                    Layout.preferredWidth: 120
                                    spacing: 4
                                    
                                    Text {
                                        text: "Código"
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: grayDark
                                    }
                                    
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: inputHeight
                                        color: modoEdicion ? grayLight : white
                                        border.color: codigoField.activeFocus ? primaryBlue : borderColor
                                        border.width: 1
                                        radius: 6
                                        
                                        TextEdit {
                                            id: codigoField
                                            anchors.fill: parent
                                            anchors.margins: 10
                                            verticalAlignment: TextEdit.AlignVCenter
                                            selectByMouse: true
                                            font.pixelSize: 12
                                            color: grayDark
                                            readOnly: modoEdicion
                                            
                                            onTextChanged: inputProductCode = text
                                            
                                            Text {
                                                text: "Auto"
                                                color: grayMedium
                                                visible: !parent.text && !modoEdicion
                                                font: parent.font
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                        }
                                    }
                                }
                                
                                // NOMBRE DEL PRODUCTO
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    
                                    Text {
                                        text: "Nombre del Producto *"
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: grayDark
                                    }
                                    
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: inputHeight
                                        color: white
                                        border.color: nombreField.activeFocus ? primaryBlue : borderColor
                                        border.width: 1
                                        radius: 6
                                        
                                        TextEdit {
                                            id: nombreField
                                            anchors.fill: parent
                                            anchors.margins: 10
                                            verticalAlignment: TextEdit.AlignVCenter
                                            selectByMouse: true
                                            font.pixelSize: 12
                                            color: grayDark
                                            
                                            onTextChanged: inputProductName = text
                                            
                                            Text {
                                                text: "Paracetamol 500mg"
                                                color: grayMedium
                                                visible: !parent.text
                                                font: parent.font
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                        }
                                    }
                                }
                                
                                // MARCA
                                ColumnLayout {
                                    Layout.preferredWidth: 200
                                    spacing: 4
                                    
                                    Text {
                                        text: "Marca *"
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: grayDark
                                    }
                                    
                                    MarcaComboBox {
                                        id: marcaComboBox
                                        Layout.fillWidth: true
                                        marcasModel: inventarioModel ? inventarioModel.marcasDisponibles : []
                                        required: true

                                        onMarcaCambiada: function(marcaNombre, marcaId) {
                                            console.log("📡 Señal recibida - Marca:", marcaNombre, "ID:", marcaId)
                                            overlayRoot.marcaIdSeleccionada = marcaId
                                            overlayRoot.marcaSeleccionadaNombre = marcaNombre
                                            console.log("✅ Propiedades actualizadas - ID:", overlayRoot.marcaIdSeleccionada, 
                                                       "Nombre:", overlayRoot.marcaSeleccionadaNombre)
                                        }

                                        onNuevaMarcaCreada: function(nombreMarca) {
                                            console.log("🆕 Solicitando crear marca:", nombreMarca)
                                            if (inventarioModel) {
                                                var nuevaMarcaId = inventarioModel.crear_marca_desde_qml(nombreMarca)
                                                console.log("🔍 Resultado crear_marca_desde_qml - ID:", nuevaMarcaId)
                                                
                                                if (nuevaMarcaId > 0) {
                                                    console.log("✅ Nueva marca creada con ID:", nuevaMarcaId)
                                                    marcaIdSeleccionada = nuevaMarcaId
                                                    marcaSeleccionadaNombre = nombreMarca
                                                    
                                                    if (marcaComboBox) {
                                                        marcaComboBox.forzarSeleccion(nuevaMarcaId, nombreMarca)
                                                    }
                                                    
                                                    Qt.callLater(function() {
                                                        cargarMarcasDisponibles()
                                                    })
                                                    
                                                    showMessage("Marca creada: " + nombreMarca)
                                                } else if (nuevaMarcaId === 0) {
                                                    console.log("⚠️ Marca ya existe")
                                                    showError("Esta marca ya existe en el sistema")
                                                } else {
                                                    console.log("❌ Error creando marca")
                                                    showError("Error al crear la marca")
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // ===============================
                            // FILA 2: Unidad, Stock Min/Max
                            // ===============================
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12
                                
                                // UNIDAD DE MEDIDA
                                ColumnLayout {
                                    Layout.preferredWidth: 150
                                    spacing: 4
                                    
                                    Text {
                                        text: "Unidad de Medida"
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: grayDark
                                    }
                                    
                                    ComboBox {
                                        id: unidadCombo
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: inputHeight
                                        model: ["Tabletas", "Cápsulas", "ml", "mg", "g", "Unidades", "Sobres", "Frascos", "Ampollas", "Jeringas"]
                                        
                                        onCurrentTextChanged: {
                                            inputMeasureUnit = currentText
                                        }
                                        
                                        background: Rectangle {
                                            color: white
                                            border.color: parent.activeFocus ? primaryBlue : borderColor
                                            border.width: 1
                                            radius: 6
                                        }
                                    }
                                }
                                
                                // STOCK MÍNIMO
                                ColumnLayout {
                                    Layout.preferredWidth: 120
                                    spacing: 4
                                    
                                    Text {
                                        text: "Stock Mínimo *"
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: grayDark
                                    }
                                    
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: inputHeight
                                        color: white
                                        border.color: stockMinimoField.activeFocus ? primaryBlue : borderColor
                                        border.width: 1
                                        radius: 6
                                        
                                        TextEdit {
                                            id: stockMinimoField
                                            anchors.fill: parent
                                            anchors.margins: 10
                                            verticalAlignment: TextEdit.AlignVCenter
                                            selectByMouse: true
                                            font.pixelSize: 12
                                            color: grayDark
                                            text: "10"
                                            
                                            onTextChanged: {
                                                var valor = parseInt(text)
                                                if (!isNaN(valor)) {
                                                    inputStockMinimo = valor
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                // STOCK MÁXIMO
                                ColumnLayout {
                                    Layout.preferredWidth: 120
                                    spacing: 4
                                    
                                    Text {
                                        text: "Stock Máximo *"
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: grayDark
                                    }
                                    
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: inputHeight
                                        color: white
                                        border.color: stockMaximoField.activeFocus ? primaryBlue : borderColor
                                        border.width: 1
                                        radius: 6
                                        
                                        TextEdit {
                                            id: stockMaximoField
                                            anchors.fill: parent
                                            anchors.margins: 10
                                            verticalAlignment: TextEdit.AlignVCenter
                                            selectByMouse: true
                                            font.pixelSize: 12
                                            color: grayDark
                                            text: "100"
                                            
                                            onTextChanged: {
                                                var valor = parseInt(text)
                                                if (!isNaN(valor)) {
                                                    inputStockMaximo = valor
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                Item { Layout.fillWidth: true }
                            }
                            
                            // ===============================
                            // DETALLES DEL PRODUCTO
                            // ===============================
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                
                                Text {
                                    text: "Detalles / Observaciones"
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: grayDark
                                }
                                
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 80
                                    color: white
                                    border.color: detallesField.activeFocus ? primaryBlue : borderColor
                                    border.width: 1
                                    radius: 6
                                    
                                    ScrollView {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        clip: true
                                        
                                        TextArea {
                                            id: detallesField
                                            selectByMouse: true
                                            wrapMode: TextArea.Wrap
                                            font.pixelSize: 12
                                            color: grayDark
                                            
                                            onTextChanged: inputProductDetails = text
                                            
                                            background: Rectangle {
                                                color: "transparent"
                                            }
                                            
                                            placeholderText: "Información adicional del producto..."
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ===============================
            // FOOTER (MEJORADO)
            // ===============================
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
                    anchors.fill: parent
                    anchors.margins: cardPadding
                    spacing: baseSpacing
                    
                    // Mensajes
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        
                        Rectangle {
                            anchors.fill: parent
                            visible: showSuccessMessage
                            color: "#D1FAE5"
                            border.color: successGreen
                            border.width: 1
                            radius: 6
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 8
                                
                                Text {
                                    text: "✓"
                                    color: successGreen
                                    font.bold: true
                                    font.pixelSize: 14
                                }
                                
                                Text {
                                    Layout.fillWidth: true
                                    text: successMessage
                                    color: successGreen
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                            }
                        }
                        
                        Rectangle {
                            anchors.fill: parent
                            visible: showErrorMessage
                            color: "#FEE2E2"
                            border.color: dangerRed
                            border.width: 1
                            radius: 6
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 8
                                
                                Text {
                                    text: "⚠"
                                    color: dangerRed
                                    font.bold: true
                                    font.pixelSize: 14
                                }
                                
                                Text {
                                    Layout.fillWidth: true
                                    text: errorMessage
                                    color: dangerRed
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                    
                    // Botón Cancelar
                    Button {
                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 40
                        text: "Cancelar"
                        
                        background: Rectangle {
                            color: parent.pressed ? "#E5E7EB" : "#F3F4F6"
                            border.color: borderColor
                            border.width: 1
                            radius: 6
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            color: grayDark
                            font.bold: true
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: {
                            cancelarCreacion()
                        }
                    }
                    
                    // Botón Guardar
                    Button {
                        Layout.preferredWidth: 160
                        Layout.preferredHeight: 40
                        text: modoEdicion ? "💾 Guardar Cambios" : "➕ Crear Producto"
                        
                        background: Rectangle {
                            color: parent.pressed ? "#1D4ED8" : primaryBlue
                            radius: 6
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            color: white
                            font.bold: true
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: guardarProducto()
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        console.log("🚀 CrearProducto.qml (Modal centrado) cargado")
        console.log("   - InventarioModel:", !!inventarioModel)
        console.log("   - FarmaciaData:", !!farmaciaData)
    }
}
