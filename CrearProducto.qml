import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15

// ===============================================================================
// CREAR PRODUCTO - FIFO 2.0 (DISEÑO MODAL CENTRADO OPTIMIZADO)
// ===============================================================================
// Versión mejorada con mejor uso del espacio
// - Eliminado espacio en blanco en lado derecho
// - Mejor distribución de elementos
// - Mantiene compatibilidad con MarcaComboBox
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
    readonly property real baseSpacing: 10
    readonly property real cardPadding: 16
    readonly property real inputHeight: 38
    readonly property real buttonHeight: 44
    readonly property real headerHeight: 55
    readonly property real sectionSpacing: 10
    
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
    
    // ===============================
    // FUNCIÓN GUARDAR PRODUCTO
    // ===============================
    function guardarProducto() {
        console.log("💾 Iniciando guardado de producto FIFO 2.0")
        console.log("   - marcaIdSeleccionada:", marcaIdSeleccionada)
        console.log("   - marcaSeleccionadaNombre:", marcaSeleccionadaNombre)
        console.log("   - stockMinimo:", inputStockMinimo)

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

        // ✅ CREAR OBJETO PRODUCTO FIFO 2.0
        var producto = {
            codigo: inputProductCode.trim(),
            nombre: inputProductName.trim(),
            detalles: inputProductDetails.trim(),
            unidad_medida: inputMeasureUnit,
            marca_id: marcaIdSeleccionada,
            marca: marcaSeleccionadaNombre,
            stock_minimo: inputStockMinimo,
            precio_compra: 0.0,
            precio_venta: 0.0
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
            marcaIdSeleccionada = 0
            marcaSeleccionadaNombre = ""
            
            if (codigoField) codigoField.text = ""
            if (nombreField) nombreField.text = ""
            if (detallesField) detallesField.text = ""
            if (stockMinimoField) stockMinimoField.text = "10"
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
        
        // ✅ CORREGIR: Buscar marca_id si solo viene el nombre
        var marcaNombre = producto.marca || ""
        var marcaId = producto.marca_id || 0
        
        // Si no hay marca_id pero SÍ hay nombre de marca, buscarlo
        if (marcaId === 0 && marcaNombre && marcasModel && marcasModel.length > 0) {
            console.log("🔍 Buscando marca_id para:", marcaNombre)
            for (var i = 0; i < marcasModel.length; i++) {
                var marca = marcasModel[i]
                if (marca && (marca.nombre === marcaNombre || marca.Nombre === marcaNombre)) {
                    marcaId = marca.id || 0
                    console.log("✅ Marca encontrada - ID:", marcaId)
                    break
                }
            }
        }
        
        marcaIdSeleccionada = marcaId
        marcaSeleccionadaNombre = marcaNombre
        
        console.log("🏷️ Marca para edición - ID:", marcaIdSeleccionada, "Nombre:", marcaSeleccionadaNombre)
        
        // Actualizar UI
        if (codigoField) {
            codigoField.text = inputProductCode
            codigoField.readOnly = true
        }
        if (nombreField) nombreField.text = inputProductName
        if (detallesField) detallesField.text = inputProductDetails
        if (stockMinimoField) stockMinimoField.text = inputStockMinimo.toString()
        
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
                console.log("🎯 Llamando a forzarSeleccion:", marcaIdSeleccionada, marcaSeleccionadaNombre)
                marcaComboBox.forzarSeleccion(marcaIdSeleccionada, marcaSeleccionadaNombre)
            })
        } else {
            console.log("⚠️ No se puede forzar selección - ID:", marcaIdSeleccionada)
        }
    }

    // ===============================
    // MODAL CENTRADO MEJORADO
    // ===============================
    Rectangle {
        id: modalContent
        width: Math.min(900, parent.width * 0.92)
        height: Math.min(520, parent.height * 0.85)
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        color: white
        radius: 12
        border.color: borderColor
        border.width: 1
        z: 10001
    
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
            // CONTENIDO PRINCIPAL OPTIMIZADO
            // ===============================
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: grayLight
                
                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 14
                    clip: true
                    
                    ColumnLayout {
                        width: parent.width
                        spacing: 12
                        
                        // ===============================
                        // ℹ️ BANNER INFORMATIVO FIFO 2.0
                        // ===============================
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 60
                            color: "#EFF6FF"
                            border.color: "#3B82F6"
                            border.width: 1
                            radius: 6
                            visible: !modoEdicion
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 8
                                
                                Text {
                                    text: "ℹ️"
                                    font.pixelSize: 20
                                }
                                
                                ColumnLayout {
                                    spacing: 4
                                    
                                    Text {
                                        text: "IMPORTANTE"
                                        font.pixelSize: 13
                                        font.bold: true
                                        color: "#1E40AF"
                                    }
                                    
                                    Text {
                                        Layout.fillWidth: true
                                        text: "El stock se calculará en la primera compra • El precio de venta se define al comprar"
                                        font.pixelSize: 11
                                        color: "#374151"
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }
                        }
                        
                        // ===============================
                        // FILA 1: Código, Nombre, Marca
                        // ===============================
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 3
                            columnSpacing: 12
                            rowSpacing: 4
                            
                            // CÓDIGO
                            ColumnLayout {
                                Layout.fillWidth: true
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
                                    
                                    TextInput {
                                        id: codigoField
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        verticalAlignment: TextInput.AlignVCenter
                                        selectByMouse: true
                                        font.pixelSize: 11
                                        color: grayDark
                                        readOnly: modoEdicion
                                        
                                        onTextChanged: inputProductCode = text
                                        
                                        Text {
                                            text: "Auto-generado"
                                            color: grayMedium
                                            visible: !parent.text && !modoEdicion
                                            font.pixelSize: 11
                                        }
                                    }
                                }
                            }
                            
                            // NOMBRE DEL PRODUCTO
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.columnSpan: 2
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
                                    
                                    TextInput {
                                        id: nombreField
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        verticalAlignment: TextInput.AlignVCenter
                                        selectByMouse: true
                                        font.pixelSize: 11
                                        color: grayDark
                                        
                                        onTextChanged: inputProductName = text
                                        
                                        Text {
                                            text: "Ej: Paracetamol 500mg"
                                            color: grayMedium
                                            visible: !parent.text
                                            font.pixelSize: 11
                                        }
                                    }
                                }
                            }
                            
                            // MARCA
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.columnSpan: 3
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
                                        overlayRoot.marcaIdSeleccionada = marcaId
                                        overlayRoot.marcaSeleccionadaNombre = marcaNombre
                                    }

                                    onNuevaMarcaCreada: function(nombreMarca) {
                                        if (inventarioModel) {
                                            var nuevaMarcaId = inventarioModel.crear_marca_desde_qml(nombreMarca)
                                            
                                            if (nuevaMarcaId > 0) {
                                                marcaIdSeleccionada = nuevaMarcaId
                                                marcaSeleccionadaNombre = nombreMarca
                                                
                                                if (marcaComboBox) {
                                                    marcaComboBox.forzarSeleccion(nuevaMarcaId, nombreMarca)
                                                }
                                                
                                                Qt.callLater(function() {
                                                    cargarMarcasDisponibles()
                                                })
                                                
                                                showMessage("Marca creada: " + nombreMarca)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // ===============================
                        // FILA 2: Unidad y Stock Mínimo
                        // ===============================
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 3
                            columnSpacing: 12
                            rowSpacing: 4
                            
                            // UNIDAD DE MEDIDA
                            ColumnLayout {
                                Layout.fillWidth: true
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
                                    
                                    contentItem: Text {
                                        text: parent.displayText
                                        font.pixelSize: 11
                                        color: grayDark
                                        verticalAlignment: Text.AlignVCenter
                                        horizontalAlignment: Text.AlignLeft
                                        leftPadding: 8
                                    }
                                    
                                    popup: Popup {
                                        y: parent.height
                                        width: parent.width
                                        implicitHeight: contentItem.implicitHeight
                                        
                                        contentItem: ListView {
                                            clip: true
                                            implicitHeight: contentHeight
                                            model: parent.parent.model
                                            currentIndex: parent.parent.currentIndex
                                            
                                            delegate: ItemDelegate {
                                                width: parent.width
                                                height: 30
                                                text: modelData
                                                font.pixelSize: 11
                                                highlighted: parent.currentIndex === index
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // STOCK MÍNIMO
                            ColumnLayout {
                                Layout.fillWidth: true
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
                                    
                                    TextInput {
                                        id: stockMinimoField
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        verticalAlignment: TextInput.AlignVCenter
                                        selectByMouse: true
                                        font.pixelSize: 11
                                        color: grayDark
                                        text: "10"
                                        validator: IntValidator { bottom: 0 }
                                        
                                        onTextChanged: {
                                            var valor = parseInt(text)
                                            if (!isNaN(valor)) {
                                                inputStockMinimo = valor
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // ESPACIO ADICIONAL (para futuros campos)
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                
                                Text {
                                    text: " "
                                    font.pixelSize: 12
                                    color: "transparent"
                                }
                                
                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: inputHeight
                                }
                            }
                        }
                        
                        // ===============================
                        // DETALLES DEL PRODUCTO (ALTURA MEJORADA)
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
                                Layout.preferredHeight: 90
                                color: white
                                border.color: detallesField.activeFocus ? primaryBlue : borderColor
                                border.width: 1
                                radius: 6
                                
                                ScrollView {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    clip: true
                                    
                                    TextArea {
                                        id: detallesField
                                        selectByMouse: true
                                        wrapMode: TextArea.Wrap
                                        font.pixelSize: 11
                                        color: grayDark
                                        placeholderText: "Información adicional, composición, presentación, etc."
                                        
                                        onTextChanged: inputProductDetails = text
                                        
                                        background: Rectangle {
                                            color: "transparent"
                                        }
                                    }
                                }
                            }
                        }
                        
                        // ===============================
                        // MENSAJES DE ESTADO
                        // ===============================
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            color: showSuccessMessage ? "#DCFCE7" : (showErrorMessage ? "#FEE2E2" : "transparent")
                            radius: 6
                            visible: showSuccessMessage || showErrorMessage
                            border.color: showSuccessMessage ? successGreen : (showErrorMessage ? dangerRed : "transparent")
                            border.width: 1
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 8
                                
                                Text {
                                    text: showSuccessMessage ? "✅" : "❌"
                                    font.pixelSize: 14
                                }
                                
                                Text {
                                    Layout.fillWidth: true
                                    text: showSuccessMessage ? successMessage : errorMessage
                                    font.pixelSize: 11
                                    color: showSuccessMessage ? successGreen : dangerRed
                                    wrapMode: Text.WordWrap
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }

            // ===============================
            // FOOTER MEJORADO
            // ===============================
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 70
                color: "#F9FAFB"
                radius: 12
                
                // Borde superior sutil
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: "#E5E7EB"
                }
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12
                    
                    // Información contextual
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        
                        Text {
                            text: modoEdicion ? 
                                "Los cambios se aplicarán inmediatamente" : 
                                "Todos los campos marcados con * son obligatorios"
                            font.pixelSize: 10
                            color: grayMedium
                        }
                        
                        Text {
                            text: "FIFO 2.0 • Gestión de Inventario Inteligente"
                            font.pixelSize: 9
                            color: grayMedium
                            opacity: 0.7
                        }
                    }
                    
                    // Botones
                    RowLayout {
                        spacing: 8
                        
                        // Botón Cancelar
                        Button {
                            Layout.preferredWidth: 110
                            Layout.preferredHeight: 38
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
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: cancelarCreacion()
                        }
                        
                        // Botón Guardar
                        Button {
                            Layout.preferredWidth: 160
                            Layout.preferredHeight: 38
                            text: modoEdicion ? "💾 Guardar Cambios" : "➕ Crear Producto"
                            
                            background: Rectangle {
                                color: parent.pressed ? "#1D4ED8" : primaryBlue
                                radius: 6
                            }
                            
                            contentItem: Text {
                                text: parent.text
                                color: white
                                font.bold: true
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: guardarProducto()
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        console.log("🚀 CrearProducto.qml (Modal centrado OPTIMIZADO) cargado")
        console.log("   - InventarioModel:", !!inventarioModel)
        console.log("   - FarmaciaData:", !!farmaciaData)
    }
}