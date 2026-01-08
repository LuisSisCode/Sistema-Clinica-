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
// - Modal flotante de 950x500px centrado
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
    property real inputPrecioCompra: 0.0
    property real inputPrecioVenta: 0.0

    // ===============================
    // PROPIEDADES DE MARCA
    // ===============================
    property int marcaIdSeleccionada: 0
    property string marcaSeleccionadaNombre: ""
    property bool marcasListenerConnected: false
    
    // ===============================
    // PROPIEDADES DE GUARDADO
    // ===============================
    property bool guardando: false

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

    // Timer para configuración retardada de marca
    Timer {
        id: marcaConfigTimer
        interval: 300
        onTriggered: {
            configurarMarca()
        }
    }

    // ===============================
    // FUNCIONES DE VALIDACIÓN
    // ===============================
    
    function generarCodigoAutomatico() {
        var timestamp = Date.now()
        var random = Math.floor(Math.random() * 1000)
        return "PROD" + (timestamp % 1000000).toString() + random.toString().padStart(3, '0')
    }

    function validarNombreProducto() {
        var nombre = inputProductName.trim()
        
        if (nombre.length === 0) {
            return {valido: false, mensaje: "El nombre del producto es obligatorio"}
        }
        if (nombre.length < 2) {
            return {valido: false, mensaje: "El nombre del producto debe tener al menos 2 caracteres"}
        }
        if (nombre.length > 100) {
            return {valido: false, mensaje: "El nombre del producto no puede exceder 100 caracteres"}
        }
        
        return {valido: true, mensaje: ""}
    }

    function validarMarcaDirecta() {
        if (marcaIdSeleccionada === 0 || !marcaSeleccionadaNombre) {
            return {valido: false, mensaje: "Debe seleccionar una marca válida"}
        }
        
        // Consultar directamente al inventarioModel
        if (inventarioModel) {
            var marcas = inventarioModel.marcasDisponibles || []
            var encontrada = marcas.some(function(marca) {
                return marca.id === marcaIdSeleccionada
            })
            
            if (encontrada) {
                return {valido: true, mensaje: ""}
            }
        }
        
        return {valido: false, mensaje: "Marca no válida"}
    }

    function validarStockMinimo() {
        if (inputStockMinimo < 0) {
            return {valido: false, mensaje: "El stock mínimo no puede ser negativo"}
        }
        if (inputStockMinimo > 9999) {
            return {valido: false, mensaje: "El stock mínimo no puede exceder 9999 unidades"}
        }
        return {valido: true, mensaje: ""}
    }
    
    // ===============================
    // FUNCIÓN GUARDAR PRODUCTO - CORREGIDA COMPLETAMENTE
    // ===============================
    function guardarProducto() {
        console.log("💾 INICIANDO GUARDADO DE PRODUCTO FIFO 2.0")
        
        // Evitar múltiples clics
        if (guardando) {
            console.log("⏭️ Ya se está guardando, omitiendo...")
            return false
        }
        
        guardando = true
        
        // 📊 DEBUG: Mostrar datos completos
        console.log("   - Código:", inputProductCode)
        console.log("   - Nombre:", inputProductName)
        console.log("   - Marca ID:", marcaIdSeleccionada)
        console.log("   - Marca Nombre:", marcaSeleccionadaNombre)
        console.log("   - Stock mínimo:", inputStockMinimo)
        console.log("   - Unidad medida:", inputMeasureUnit)
        console.log("   - Precio compra:", inputPrecioCompra)
        console.log("   - Precio venta:", inputPrecioVenta)

        // ✅ VALIDACIÓN 1: MARCA (CORREGIDA - SIN DEPENDER DE marcasModel)
        if (marcaIdSeleccionada === 0 || !marcaSeleccionadaNombre) {
            console.log("❌ GUARDADO BLOQUEADO: Marca no seleccionada")
            showError("Debe seleccionar una marca válida para el producto")
            if (marcaComboBox) {
                marcaComboBox.forceActiveFocus()
            }
            guardando = false
            return false
        }
        
        // ✅ VALIDACIÓN 2: VERIFICAR MARCA EN SISTEMA (CONSULTA DIRECTA)
        var marcaValida = false
        if (inventarioModel && inventarioModel.marcasDisponibles) {
            var marcas = inventarioModel.marcasDisponibles
            console.log("🔍 Verificando marca ID", marcaIdSeleccionada, "en", marcas.length, "marcas disponibles")
            
            for (var i = 0; i < marcas.length; i++) {
                var marca = marcas[i]
                console.log("   - Marca #" + (i+1) + ": ID=" + marca.id + ", Nombre=" + marca.nombre)
                if (marca.id === marcaIdSeleccionada) {
                    marcaValida = true
                    console.log("✅ Marca encontrada en sistema:", marca.nombre)
                    break
                }
            }
        }
        
        if (!marcaValida) {
            console.log("❌ Marca ID", marcaIdSeleccionada, "no encontrada en sistema")
            showError("La marca seleccionada no existe en el sistema. Por favor, seleccione una marca válida.")
            if (marcaComboBox) {
                marcaComboBox.forceActiveFocus()
            }
            guardando = false
            return false
        }

        // ✅ VALIDACIÓN 3: GENERAR CÓDIGO AUTOMÁTICO SI ES NECESARIO (SOLO EN CREACIÓN)
        if (!modoEdicion && (!inputProductCode || inputProductCode.trim().length === 0)) {
            inputProductCode = generarCodigoAutomatico()
            console.log("🔤 Código generado automáticamente:", inputProductCode)
            if (codigoField) {
                codigoField.text = inputProductCode
            }
        }

        // ✅ VALIDACIÓN 4: NOMBRE DEL PRODUCTO
        var validacionNombre = validarNombreProducto()
        if (!validacionNombre.valido) {
            console.log("❌ Validación de nombre falló:", validacionNombre.mensaje)
            showError(validacionNombre.mensaje)
            if (nombreField) {
                nombreField.forceActiveFocus()
            }
            guardando = false
            return false
        }

        // ✅ VALIDACIÓN 5: STOCK MÍNIMO
        var validacionStockMin = validarStockMinimo()
        if (!validacionStockMin.valido) {
            console.log("❌ Validación de stock mínimo falló:", validacionStockMin.mensaje)
            showError(validacionStockMin.mensaje)
            if (stockMinimoField) {
                stockMinimoField.forceActiveFocus()
            }
            guardando = false
            return false
        }

        // ✅ VALIDACIÓN 6: PRECIOS (OPCIONAL EN CREACIÓN)
        if (inputPrecioCompra < 0 || inputPrecioVenta < 0) {
            console.log("❌ Los precios no pueden ser negativos")
            showError("Los precios no pueden ser negativos")
            guardando = false
            return false
        }

        if (inputPrecioCompra > 0 && inputPrecioVenta > 0 && inputPrecioVenta <= inputPrecioCompra) {
            console.log("❌ El precio de venta debe ser mayor al precio de compra")
            showError("El precio de venta debe ser mayor al precio de compra")
            guardando = false
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
            precio_compra: inputPrecioCompra,
            precio_venta: inputPrecioVenta
        }

        console.log("📦 Producto a guardar:", JSON.stringify(producto))
        console.log("   - Modo:", modoEdicion ? "EDICIÓN" : "CREACIÓN")
        console.log("   - Usuario ID (si aplica):", inventarioModel ? inventarioModel.usuario_actual_id : "No disponible")

        // ✅ GUARDAR EN BASE DE DATOS
        if (!inventarioModel) {
            console.log("❌ InventarioModel no disponible")
            showError("Sistema no disponible. Intente nuevamente.")
            guardando = false
            return false
        }

        try {
            var exito = false
            
            if (modoEdicion) {
                console.log("✏️ Actualizando producto existente...")
                exito = inventarioModel.actualizar_producto(producto.codigo, JSON.stringify(producto))
                
                if (exito) {
                    console.log("✅ Producto actualizado exitosamente:", producto.codigo)
                    showMessage("Producto actualizado correctamente")
                    
                    // Emitir señal de producto actualizado
                    productoActualizado(producto)
                    
                    // Cerrar modal después de un breve retraso
                    Qt.callLater(function() {
                        volverALista()
                    })
                    
                } else {
                    console.log("❌ Error al actualizar el producto")
                    showError("Error al actualizar el producto. Verifique los datos e intente nuevamente.")
                    guardando = false
                    return false
                }
            } else {
                console.log("🆕 Creando nuevo producto...")
                exito = inventarioModel.crear_producto(JSON.stringify(producto))
                
                if (exito) {
                    console.log("✅ Producto creado exitosamente:", producto.codigo)
                    showMessage("Producto creado correctamente")
                    
                    // Emitir señal de producto creado
                    productoCreado(producto)
                    
                    // Cerrar modal después de un breve retraso
                    Qt.callLater(function() {
                        volverALista()
                    })
                    
                } else {
                    console.log("❌ Error al crear el producto")
                    showError("Error al crear el producto. Verifique los datos e intente nuevamente.")
                    guardando = false
                    return false
                }
            }
            
            // Limpiar formulario después de éxito
            Qt.callLater(function() {
                if (!modoEdicion) {
                    limpiarFormularioSeguro()
                }
            })
            
            guardando = false
            return exito
            
        } catch (error) {
            console.log("❌ Error en guardarProducto:", error.toString())
            showError("Error: " + error.toString())
            guardando = false
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
            inputPrecioCompra = 0.0
            inputPrecioVenta = 0.0
            marcaIdSeleccionada = 0
            marcaSeleccionadaNombre = ""
            
            if (codigoField) codigoField.text = ""
            if (nombreField) nombreField.text = ""
            if (detallesField) detallesField.text = ""
            if (stockMinimoField) stockMinimoField.text = "10"
            if (unidadCombo) unidadCombo.currentIndex = 0
            if (marcaComboBox) {
                marcaComboBox.reset()
                marcaComboBox.searchField.text = ""
            }
            
            showSuccessMessage = false
            showErrorMessage = false
            guardando = false
            
            console.log("🧹 Formulario limpiado completamente")
        } catch (error) {
            console.log("⚠️ Error en limpieza de formulario:", error)
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
            // ✅ FORZAR recarga de marcas
            inventarioModel.refresh_marcas()
            
            var marcasDisponibles = inventarioModel.marcasDisponibles || []
            console.log("🏷️ Marcas disponibles cargadas:", marcasDisponibles.length)
            
            // Mostrar las primeras 3 marcas para debug
            for (var i = 0; i < Math.min(3, marcasDisponibles.length); i++) {
                var marca = marcasDisponibles[i]
                console.log("   " + (i+1) + ". ID: " + marca.id + ", Nombre: " + marca.nombre)
            }
            
            marcasModel = marcasDisponibles
            marcasCargadas = true
            
        } catch (error) {
            console.log("❌ Error cargando marcas:", error)
        }
    }
    // ===============================
    // FUNCIÓN PARA CONFIGURAR MARCA
    // ===============================
    function configurarMarca() {
        console.log("🔧 Configurando marca en CrearProducto.qml...")
        console.log("   - MarcaComboBox disponible:", !!marcaComboBox)
        console.log("   - ID Marca:", marcaIdSeleccionada)
        console.log("   - Nombre Marca:", marcaSeleccionadaNombre)
        
        if (!marcaComboBox) {
            console.log("⏳ MarcaComboBox no disponible aún")
            return
        }
        
        // OPCIÓN A: setMarcaById
        if (typeof marcaComboBox.setMarcaById === 'function' && marcaIdSeleccionada > 0) {
            console.log("🎯 Usando setMarcaById con ID:", marcaIdSeleccionada)
            marcaComboBox.setMarcaById(marcaIdSeleccionada)
        } 
        // OPCIÓN B: Establecer texto directamente
        else if (marcaComboBox.searchField) {
            console.log("🎯 Estableciendo texto de marca directamente")
            marcaComboBox.searchField.text = marcaSeleccionadaNombre
        }
        // OPCIÓN C: forzarSeleccion
        else if (typeof marcaComboBox.forzarSeleccion === 'function') {
            console.log("🎯 Usando forzarSeleccion")
            marcaComboBox.forzarSeleccion(marcaIdSeleccionada, marcaSeleccionadaNombre)
        }
        
        console.log("✅ Marca configurada exitosamente")
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
        console.log("📝 INICIO: Inicializando para editar:", producto.codigo)
        console.log("🔍 Datos recibidos en inicializarParaEditar:", JSON.stringify(producto))
        
        // ✅ PASO 1: Cargar propiedades locales (SINCRÓNICO)
        inputProductCode = producto.codigo || ""
        inputProductName = producto.nombre || ""
        inputProductDetails = producto.detalles || ""
        inputStockMinimo = producto.stock_minimo || 10
        inputPrecioCompra = producto.precio_compra || 0
        inputPrecioVenta = producto.precio_venta || 0
        marcaIdSeleccionada = producto.marca_id || 0
        marcaSeleccionadaNombre = producto.marca || ""
        
        // ✅ DEBUG: Verificar unidad de medida
        console.log("🎯 Unidad de medida en datos recibidos:", producto.unidad_medida)
        
        // ✅ PASO 2: Actualizar campos de texto INMEDIATAMENTE
        if (codigoField) {
            codigoField.text = inputProductCode
            console.log("✅ Código:", inputProductCode)
        }
        if (nombreField) {
            nombreField.text = inputProductName
            console.log("✅ Nombre:", inputProductName)
        }
        if (detallesField) {
            detallesField.text = inputProductDetails
            console.log("✅ Detalles:", inputProductDetails)
        }
        if (stockMinimoField) {
            stockMinimoField.text = inputStockMinimo.toString()
            console.log("✅ Stock mínimo:", inputStockMinimo)
        }
        
        // ✅ PASO 3: Unidad de medida - CORREGIDO (manejar "Cápsula" vs "Cápsulas")
        var unidades = ["Tableta", "Cápsulas", "ml", "mg", "g", "Unidad", "Sobres", "Frascos", "Tubo", "Inhalador", "Ampolla"]
        var unidadProducto = producto.unidad_medida || "Tableta"
        
        // ⚠️ CORRECCIÓN CRÍTICA: Manejar "Cápsula" (singular) vs "Cápsulas" (plural)
        if (unidadProducto === "Cápsula") {
            unidadProducto = "Cápsulas"
            console.log("🔄 Normalizando 'Cápsula' a 'Cápsulas'")
        }
        
        var indexUnidad = unidades.indexOf(unidadProducto)
        
        console.log("🔍 Buscando unidad:", unidadProducto, "en array:", unidades)
        console.log("🔍 Índice encontrado:", indexUnidad)
        
        if (indexUnidad >= 0 && unidadCombo) {
            unidadCombo.currentIndex = indexUnidad
            inputMeasureUnit = unidadProducto
            console.log("✅ Unidad establecida:", unidadProducto)
        } else {
            // Fallback a la primera opción
            if (unidadCombo) {
                unidadCombo.currentIndex = 0
            }
            inputMeasureUnit = "Tableta"
            console.log("⚠️ Unidad no encontrada, usando Tableta por defecto")
        }
        
        // ✅ PASO 4: Marca - USAR TIMER EN LUGAR DE setTimeout
        console.log("⏳ Programando configuración de marca con Timer...")
        marcaConfigTimer.restart()
        
        console.log("✅ INICIALIZACIÓN COMPLETADA para:", producto.codigo)
    }

    // ===============================
    // MODAL CENTRADO
    // ===============================
    Rectangle {
        id: modalContent
        width: Math.min(550, parent.width * 0.95)
        height: Math.min(500, parent.height * 0.88)
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
                    
                    ColumnLayout {
                        width: parent.width - 20
                        spacing: 12
                        
                        // ===============================
                        // ℹ️ BANNER INFORMATIVO FIFO 2.0
                        // ===============================
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 65
                            color: "#EFF6FF"
                            border.color: "#3B82F6"
                            border.width: 1
                            radius: 6
                            visible: !modoEdicion
                            
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 6
                                
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    
                                    Text {
                                        text: "ℹ️"
                                        font.pixelSize: 18
                                    }
                                    
                                    Text {
                                        text: "IMPORTANTE"
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: grayDark
                                    }
                                }
                                
                                Text {
                                    Layout.fillWidth: true
                                    text: "El stock se calculará en la primera compra • El precio de venta se define al comprar"
                                    font.pixelSize: 11
                                    color: grayDark
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                        
                        // ===============================
                        // 📊 INFORMACIÓN CONTEXTUAL (SOLO EN EDICIÓN)
                        // ===============================
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: infoColumn.implicitHeight + 20
                            color: "#FEF3C7"
                            border.color: "#F59E0B"
                            border.width: 1
                            radius: 6
                            visible: modoEdicion
                            
                            ColumnLayout {
                                id: infoColumn
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 8
                                
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    
                                    Text {
                                        text: "📊"
                                        font.pixelSize: 16
                                    }
                                    
                                    Text {
                                        text: "INFORMACIÓN ACTUAL DEL PRODUCTO"
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: "#92400E"
                                    }
                                }
                                
                                // Grid de información
                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 2
                                    rowSpacing: 6
                                    columnSpacing: 20
                                    
                                    // Stock
                                    RowLayout {
                                        spacing: 6
                                        Text {
                                            text: "📦 Stock:"
                                            font.pixelSize: 11
                                            color: "#92400E"
                                        }
                                        Text {
                                            text: productoData ? (productoData.stock || productoData.stockUnitario || "0") + " " + (productoData.unidad_medida || "unidades") : "0 unidades"
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: "#78350F"
                                        }
                                    }
                                    
                                    // Precio Venta
                                    RowLayout {
                                        spacing: 6
                                        Text {
                                            text: "💰 Precio Venta:"
                                            font.pixelSize: 11
                                            color: "#92400E"
                                        }
                                        Text {
                                            text: productoData ? "Bs " + (productoData.precioVenta || productoData.precio_venta || "0.00").toFixed(2) : "Bs 0.00"
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: "#78350F"
                                        }
                                    }
                                    
                                    // Lotes Totales
                                    RowLayout {
                                        spacing: 6
                                        Text {
                                            text: "📋 Lotes:"
                                            font.pixelSize: 11
                                            color: "#92400E"
                                        }
                                        Text {
                                            text: productoData ? (productoData.lotesTotales || "0") + " registrados" : "0 registrados"
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: "#78350F"
                                        }
                                    }
                                    
                                    // Código
                                    RowLayout {
                                        spacing: 6
                                        Text {
                                            text: "🏷️ Código:"
                                            font.pixelSize: 11
                                            color: "#92400E"
                                        }
                                        Text {
                                            text: productoData ? (productoData.codigo || "N/A") : "N/A"
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: "#78350F"
                                        }
                                    }
                                }
                                
                                // Nota importante
                                Text {
                                    Layout.fillWidth: true
                                    Layout.topMargin: 4
                                    text: "💡 Los precios y stock se gestionan desde Compras y Lotes"
                                    font.pixelSize: 10
                                    font.italic: true
                                    color: "#92400E"
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
                                Layout.preferredWidth: 150
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
                                    color: modoEdicion ? "#F3F4F6" : white
                                    border.color: modoEdicion ? "#D1D5DB" : (codigoField.activeFocus ? primaryBlue : borderColor)
                                    border.width: 1
                                    radius: 6
                                    
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 6
                                        
                                        // 🔒 Icono de candado (solo en modo edición)
                                        Text {
                                            text: "🔒"
                                            font.pixelSize: 12
                                            visible: modoEdicion
                                        }
                                        
                                        TextInput {
                                            id: codigoField
                                            Layout.fillWidth: true
                                            verticalAlignment: TextInput.AlignVCenter
                                            selectByMouse: true
                                            font.pixelSize: 11
                                            color: modoEdicion ? "#9CA3AF" : grayDark
                                            readOnly: modoEdicion
                                            
                                            onTextChanged: inputProductCode = text
                                            
                                            Text {
                                                text: "Auto"
                                                color: grayMedium
                                                visible: !parent.text && !modoEdicion
                                                font.pixelSize: 11
                                            }
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
                                Layout.preferredWidth: 230
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
                        // FILA 2: Unidad, Stock Min/Max
                        // ===============================
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            
                            // UNIDAD DE MEDIDA
                            ColumnLayout {
                                Layout.preferredWidth: 180
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
                                    model: ["Tableta", "Cápsulas", "ml", "mg", "g", "Unidad", "Sobres", "Frascos", "Tubo", "Inhalador", "Ampolla"]
                                    
                                    onCurrentTextChanged: {
                                        inputMeasureUnit = currentText
                                        console.log("📏 Unidad de medida cambiada a:", currentText)
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
                                Layout.preferredWidth: 140
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
                                Layout.preferredHeight: 75
                                color: white
                                border.color: detallesField.activeFocus ? primaryBlue : borderColor
                                border.width: 1
                                radius: 6
                                
                                ScrollView {
                                    anchors.fill: parent
                                    anchors.margins: 5
                                    clip: true
                                    
                                    TextArea {
                                        id: detallesField
                                        selectByMouse: true
                                        wrapMode: TextArea.Wrap
                                        font.pixelSize: 11
                                        color: grayDark
                                        
                                        onTextChanged: inputProductDetails = text
                                        
                                        background: Rectangle {
                                            color: "transparent"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ===============================
            // FOOTER
            // ===============================
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 65
                color: "#F9FAFB"
                radius: 12
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12
                    
                    Item { Layout.fillWidth: true }
                    
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
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: cancelarCreacion()
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

    Component.onCompleted: {
        console.log("🚀 CrearProducto.qml (Modal centrado) cargado")
        console.log("   - InventarioModel:", !!inventarioModel)
        console.log("   - FarmaciaData:", !!farmaciaData)
        
        // Cargar marcas inmediatamente
        if (inventarioModel) {
            console.log("🏷️ Cargando marcas disponibles...")
            Qt.callLater(function() {
                cargarMarcasDisponibles()
            })
        }
        
        // Inicializar según modo
        if (modoEdicion && productoData) {
            console.log("📝 Modo edición detectado, inicializando con datos del producto")
            Qt.callLater(function() {
                inicializarParaEditar(productoData)
            })
        } else {
            console.log("🆕 Modo creación detectado")
            // Generar código automático para nuevo producto
            inputProductCode = generarCodigoAutomatico()
            if (codigoField) {
                codigoField.text = inputProductCode
            }
        }
    }
}