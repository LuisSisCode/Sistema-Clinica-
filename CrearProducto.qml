import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15

// Dialog para crear/editar producto - SIN CAJAS - SOLO STOCK UNITARIO
Dialog {
    id: crearProductoDialog
    
    // Propiedades del Dialog
    modal: true
    dim: true
    closePolicy: Popup.NoAutoClose
    anchors.centerIn: parent
    width: Math.min(parent.width * 0.9, 900)
    height: Math.min(parent.height * 0.9, 550)
    
    // Propiedades de comunicación
    property var inventarioModel: null
    property var farmaciaData: null
    property bool modoEdicion: false
    property var productoData: null
    property var marcasModel: []
    
    // Señales
    signal productoCreado(var producto)
    signal productoActualizado(var producto) 
    signal cancelarCreacion()
    signal volverALista() 
    
    // Métricas del diseño
    readonly property real baseSpacing: 12
    readonly property real cardPadding: 16
    readonly property real inputHeight: 40
    readonly property real buttonHeight: 45
    readonly property real headerHeight: 60
    readonly property real sectionSpacing: 12
    
    // Colores
    readonly property color primaryBlue: "#2563EB"
    readonly property color successGreen: "#059669"
    readonly property color warningAmber: "#D97706"
    readonly property color dangerRed: "#DC2626"
    readonly property color grayLight: "#F3F4F6"
    readonly property color grayMedium: "#6B7280"
    readonly property color grayDark: "#374151"
    readonly property color white: "#FFFFFF"
    readonly property color borderColor: "#D1D5DB"
    
    // Estados
    property bool showSuccessMessage: false
    property string successMessage: ""
    property bool marcasCargadas: false
    
    // Datos del formulario - PRODUCTO
    property string inputProductCode: ""
    property string inputProductName: ""
    property string inputProductDetails: ""
    property real inputPurchasePrice: 0.0
    property real inputSalePrice: 0.0
    property string inputMeasureUnit: "Tabletas"
    property string inputMarca: ""

    // Datos del formulario - PRIMER LOTE SIN CAJAS
    property string inputExpirationDate: ""
    property bool inputNoExpiry: false
    property int inputStockUnit: 0  // Solo stock unitario
    property string inputSupplier: ""

    // AGREGAR estas propiedades:
    property int marcaIdSeleccionada: 0
    property string marcaSeleccionadaNombre: ""
    
    onClosed: {
        try {
            showSuccessMessage = false
            if (successTimer.running) {
                successTimer.stop()
            }
            console.log("🚪 Diálogo cerrado - estado limpiado")
        } catch (error) {
            console.log("⚠️ Error limpiando al cerrar:", error)
        }
    }

    Timer {
        id: successTimer
        interval: 3000
        onTriggered: showSuccessMessage = false
    }

    // FUNCIONES
    function cargarMarcasDisponibles() {
        if (!inventarioModel || !crearProductoDialog) {
            marcasCargadas = false
            return
        }
        
        try {
            var marcas = inventarioModel.get_marcas_disponibles()
            if (marcas && marcas.length > 0) {
                marcasModel = marcas
                marcasCargadas = true
                console.log("Marcas cargadas:", marcas.length)
            } else {
                marcasModel = []
                marcasCargadas = true
            }
        } catch (error) {
            console.error("Error al cargar marcas:", error)
            marcasModel = []
            marcasCargadas = false
        }
    }

    function autoFormatDate(input) {
        // Permitir solo números y guiones
        var cleaned = input.replace(/[^\d\-]/g, '')
        
        // Si está vacío, permitirlo
        if (cleaned.length === 0) {
            return ""
        }
        
        // Auto-agregar guiones para YYYY-MM-DD
        if (cleaned.length === 4 && !cleaned.includes('-')) {
            return cleaned + '-'
        }
        if (cleaned.length === 7 && cleaned.indexOf('-') === 4 && cleaned.lastIndexOf('-') === 4) {
            return cleaned + '-'
        }

        if (cleaned.length > 10) {
            cleaned = cleaned.substring(0, 10)
        }
        
        return cleaned
    }

    function validateExpiryDate(dateStr) {
        // Permitir vacío cuando inputNoExpiry es true
        if (inputNoExpiry || dateStr === "" || dateStr === "Sin vencimiento") return true;
        
        // Validar formato YYYY-MM-DD
        var regex = /^\d{4}-\d{2}-\d{2}$/;
        if (!regex.test(dateStr)) return false;
        
        var parts = dateStr.split('-');
        var year = parseInt(parts[0], 10);
        var month = parseInt(parts[1], 10);
        var day = parseInt(parts[2], 10);
        
        if (month < 1 || month > 12) return false;
        if (day < 1 || day > 31) return false;
        if (year < 2020 || year > 2050) return false;
        
        // Validar días por mes
        var daysInMonth = new Date(year, month, 0).getDate();
        if (day > daysInMonth) return false;
        
        return true;
    }
    
    function formatearFechaParaBD() {
        if (inputNoExpiry) {
            return null  // Explícitamente null para sin vencimiento
        }
        if (!inputExpirationDate || inputExpirationDate.length === 0) {
            return null  // También null si no hay fecha
        }
        return inputExpirationDate
    }

    function generarCodigoAutomatico() {
        return "PROD" + String(Date.now()).slice(-6)
    }
    
    function guardarProducto() {
        // Guard para prevenir errores de contexto
        if (!crearProductoDialog || !crearProductoDialog.visible) {
            return false
        }
        
        // Generar código automático si está vacío
        if (inputProductCode.trim().length === 0) {
            inputProductCode = generarCodigoAutomatico()
            if (codigoField) {
                codigoField.text = inputProductCode
            }
        }
        
        if (!calcularValidacion()) {  // ← Cambiar aquí también
            showMessage("Complete todos los campos obligatorios")
            return false
        }
        
        // Validación de fecha
        if (!modoEdicion && !inputNoExpiry && !validateExpiryDate(inputExpirationDate)) {
            showMessage("Fecha de vencimiento inválida (YYYY-MM-DD)")
            return false
        }
        
        // SIN CAJAS: producto solo con stock unitario
        var producto = {
            codigo: inputProductCode.trim(),
            nombre: inputProductName.trim(),
            detalles: inputProductDetails.trim(),
            id_marca: marcaIdSeleccionada,  // ✅ Enviar ID numérico
            marca: marcaSeleccionadaNombre.trim(),  // Nombre para logging
            precio_compra: inputPurchasePrice,
            precio_venta: inputSalePrice,
            unidad_medida: inputMeasureUnit,
            stock_unitario: inputStockUnit,
            fecha_vencimiento: formatearFechaParaBD(),
            proveedor: inputSupplier.trim(),
            sin_vencimiento: inputNoExpiry
        }
        
        try {
            // MOSTRAR MENSAJE DE ÉXITO INMEDIATAMENTE (mientras el contexto es válido)
            var mensajeExito = ""
            
            if (modoEdicion) {
                producto.id = productoData.id
                mensajeExito = "Producto actualizado correctamente"
                
                // ✅ LLAMAR AL INVENTARIOMODEL PARA ACTUALIZAR EN BD
                if (!inventarioModel) {
                    showMessage("Error: Sistema no disponible")
                    return false
                }
                
                var exito = inventarioModel.actualizar_producto(
                    productoData.codigo, 
                    JSON.stringify(producto)
                )
                
                if (!exito) {
                    showMessage("Error al actualizar producto")
                    return false
                }
            } else {
                mensajeExito = "Producto y primer lote creados correctamente"
                var tipoVencimiento = inputNoExpiry ? " (sin vencimiento)" : ""
                mensajeExito += tipoVencimiento
            }
            
            // MOSTRAR MENSAJE ANTES de cualquier operación de cierre
            showMessage(mensajeExito)
            
            // LIMPIAR FORMULARIO INMEDIATAMENTE (mientras el contexto es válido)
            limpiarFormularioSeguro()
            
            // EMITIR SEÑAL Y CERRAR (sin más llamadas a funciones del diálogo)
            if (modoEdicion) {
                productoActualizado(producto)
                console.log("✅ Producto actualizado correctamente")
            } else {
                productoCreado(producto)
                console.log("✅ Producto y primer lote creados correctamente")
            }
            
            // CERRAR DIÁLOGO CON DELAY MÍNIMO
            Qt.callLater(function() {
                close()
            })
            
            return true
            
        } catch (error) {
            console.error("Error al guardar producto:", error)
            // NO llamar showMessage aquí porque puede estar en contexto inválido
            return false
        }
    }
    
    function limpiarFormularioSeguro() {
        // GUARDS MÚLTIPLES para prevenir errores de contexto
        if (!crearProductoDialog) {
            console.log("⚠️ Dialog no disponible para limpieza")
            return
        }
        
        try {
            // Limpiar propiedades primero
            inputProductCode = ""
            inputProductName = ""
            inputProductDetails = ""
            inputPurchasePrice = 0.0
            inputSalePrice = 0.0
            inputMarca = ""
            inputExpirationDate = ""
            inputNoExpiry = false
            inputStockUnit = 0
            inputSupplier = ""

            marcaIdSeleccionada = 0
            marcaSeleccionadaNombre = ""
            
            // Limpiar campos UI con verificación individual
            if (typeof codigoField !== 'undefined' && codigoField) {
                codigoField.text = ""
            }
            if (typeof nombreField !== 'undefined' && nombreField) {
                nombreField.text = ""
            }
            if (typeof detallesField !== 'undefined' && detallesField) {
                detallesField.text = ""
            }
            if (typeof precioCompraField !== 'undefined' && precioCompraField) {
                precioCompraField.text = ""
            }
            if (typeof precioVentaField !== 'undefined' && precioVentaField) {
                precioVentaField.text = ""
            }
            if (typeof marcaComboBox !== 'undefined' && marcaComboBox) {
                marcaComboBox.reset()
            }
            if (typeof fechaVencimientoField !== 'undefined' && fechaVencimientoField) {
                fechaVencimientoField.text = ""
            }
            if (typeof stockUnitarioField !== 'undefined' && stockUnitarioField) {
                stockUnitarioField.text = ""
            }
            if (typeof proveedorField !== 'undefined' && proveedorField) {
                proveedorField.text = ""
            }
            
            // Resetear ComboBox con verificación
            if (typeof unidadCombo !== 'undefined' && unidadCombo && 
                typeof unidadCombo.currentIndex !== 'undefined') {
                unidadCombo.currentIndex = 0
            }
            
            console.log("🧹 Formulario limpiado exitosamente")
            
        } catch (error) {
            console.log("⚠️ Error en limpieza (no crítico):", error)
            // No propagar el error para evitar crashes
        }
    }
    
    function showMessage(mensaje) {
        if (!crearProductoDialog || !crearProductoDialog.visible) {
            console.log("📢 Mensaje:", mensaje)
            return
        }
        
        try {
            successMessage = mensaje
            showSuccessMessage = true
            successTimer.restart()
            console.log("📢 Mostrando mensaje:", mensaje)
        } catch (error) {
            console.log("⚠️ Error mostrando mensaje:", error)
        }
    }

    function crearNuevaMarcaEnBackend(nombreMarca) {
        if (!inventarioModel) {
            console.log("❌ InventarioModel no disponible")
            showMessage("Error: Sistema no disponible")
            return
        }
        
        console.log("🏷️ Creando marca:", nombreMarca)
        
        // Llamar método Python
        var marcaId = inventarioModel.crear_marca_rapida(nombreMarca)
        
        if (marcaId > 0) {
            console.log("✅ Marca creada con ID:", marcaId)
            
            // Recargar marcas
            cargarMarcasDisponibles()
            
            // Esperar un momento para que se actualice el modelo
            Qt.callLater(function() {
                // Seleccionar la nueva marca automáticamente en el ComboBox
                if (marcaComboBox) {
                    marcaComboBox.setMarcaById(marcaId)
                }
            })
            
            showMessage("Marca creada: " + nombreMarca)
        } else {
            console.log("❌ Error creando marca")
            showMessage("Error al crear la marca")
        }
    }
    
    function abrirCrearProducto(modo = false, datos = null) {
        console.log("🚀 Abriendo CrearProducto - Modo edición:", modo)
        
        modoEdicion = modo
        productoData = datos
        
        // ✅ CARGAR MARCAS Y ESPERAR A QUE SE COMPLETE
        cargarMarcasDisponibles()
        
        // ✅ FORZAR marcasCargadas a true si hay marcas disponibles
        if (marcasModel && marcasModel.length > 0) {
            marcasCargadas = true
            console.log("✅ Marcas disponibles confirmadas:", marcasModel.length)
        }
        
        // Limpiar formulario de forma segura
        limpiarFormularioSeguro()
        
        if (modoEdicion && productoData) {
            console.log("📝 Modo edición detectado, cargando datos...")
            Qt.callLater(function() {
                Qt.callLater(function() {
                    if (crearProductoDialog && crearProductoDialog.visible) {
                        cargarDatosProducto()
                    }
                })
            })
        }
        
        open()
        
        // ✅ VERIFICAR ESTADO FINAL
        console.log("🔍 Estado al abrir: marcasCargadas =", marcasCargadas)
    }
    
    function cargarDatosProducto() {
        if (!productoData) {
            console.log("❌ No hay datos de producto para cargar")
            return
        }
        
        console.log("📋 Cargando datos del producto:", JSON.stringify(productoData))
        
        // ✅ ASIGNAR VALORES A LAS PROPIEDADES
        inputProductCode = productoData.codigo || ""
        inputProductName = productoData.nombre || ""
        inputProductDetails = productoData.detalles || ""
        inputPurchasePrice = productoData.precio_compra || 0
        inputSalePrice = productoData.precio_venta || 0
        inputMeasureUnit = productoData.unidad_medida || "Tabletas"
        
        // ✅ ASIGNAR VALORES A LOS CAMPOS DE TEXTO (sin marca todavía)
        if (codigoField) codigoField.text = inputProductCode
        if (nombreField) nombreField.text = inputProductName
        if (detallesField) detallesField.text = inputProductDetails
        if (precioCompraField) precioCompraField.text = inputPurchasePrice.toString()
        if (precioVentaField) precioVentaField.text = inputSalePrice.toString()
        
        // ✅ ESTABLECER COMBOBOX DE UNIDAD
        if (unidadCombo) {
            var unidadIndex = unidadCombo.model.indexOf(inputMeasureUnit)
            if (unidadIndex >= 0) {
                unidadCombo.currentIndex = unidadIndex
            }
        }
        
        // ✅ CARGAR MARCA AL FINAL, DESHABILITANDO TEMPORALMENTE LAS SEÑALES
        if (productoData.ID_Marca || productoData.id_marca) {
            var marcaId = productoData.ID_Marca || productoData.id_marca
            marcaIdSeleccionada = marcaId
            
            // Desconectar temporalmente la señal para evitar activación
            if (marcaComboBox) {
                // Bloquear señales temporalmente
                var signalBlocked = true
                
                // Establecer marca sin disparar señales
                marcaComboBox.setMarcaById(marcaId)
                
                // Forzar la asignación después de un breve delay
                Qt.callLater(function() {
                    marcaIdSeleccionada = marcaId
                    console.log("✅ Marca establecida en modo edición: ID", marcaId)
                })
            }
        } else if (productoData.marca) {
            // Fallback: si solo viene el nombre de marca, buscarla
            inputMarca = productoData.marca
            console.log("⚠️ Solo nombre de marca disponible, buscando ID...")
            
            // Buscar ID de marca por nombre
            for (var i = 0; i < marcasModel.length; i++) {
                var marca = marcasModel[i]
                if ((marca.Nombre || marca.nombre) === productoData.marca) {
                    marcaIdSeleccionada = marca.id
                    if (marcaComboBox) {
                        marcaComboBox.setMarcaById(marca.id)
                    }
                    break
                }
            }
        }
        
        console.log("✅ Datos cargados en el formulario")
    }

    // Header personalizado
    header: Rectangle {
        height: headerHeight
        color: white
        radius: 12
        
        // Recortar esquinas inferiores para que solo las superiores sean redondeadas
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 12
            color: white
        }
        
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: borderColor
        }
        
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: baseSpacing
            anchors.rightMargin: baseSpacing
            spacing: baseSpacing
            
            RowLayout {
                spacing: 10
                
                Rectangle {
                    width: 36
                    height: 36
                    color: modoEdicion ? warningAmber : primaryBlue
                    radius: 8
                    
                    Text {
                        anchors.centerIn: parent
                        text: modoEdicion ? "✏" : "+"
                        color: white
                        font.pixelSize: 14
                        font.bold: true
                    }
                }
                
                Column {
                    spacing: 2
                    
                    Text {
                        text: modoEdicion ? "Editar Producto" : "Nuevo Producto + Primer Lote"
                        font.pixelSize: 18
                        font.bold: true
                        color: grayDark
                    }
                    
                    Text {
                        text: modoEdicion ? "Actualizar información del producto" : "Crear producto e inventario inicial (solo stock unitario)"
                        font.pixelSize: 12
                        color: grayMedium
                    }
                }
            }
            
            Item { Layout.fillWidth: true }
            
            Button {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                
                background: Rectangle {
                    color: parent.pressed ? "#E5E7EB" : "#F9FAFB"
                    border.color: borderColor
                    border.width: 1
                    radius: 8
                }
                
                contentItem: Text {
                    text: "×"
                    color: grayDark
                    font.pixelSize: 18
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: {
                    cancelarCreacion()
                    close()
                }
            }
        }
    }

    // Contenido principal
    contentItem: Rectangle {
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
                    spacing: 12
                    
                    // Fila 1: Código, Nombre del Producto, Marca
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        
                        // Código (ya no obligatorio)
                        ColumnLayout {
                            Layout.preferredWidth: 120
                            spacing: 4
                            
                            Text {
                                text: "Código (Opcional)"
                                font.pixelSize: 12
                                font.bold: true
                                color: grayDark
                            }
                            
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: inputHeight
                                color: white
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
                                    
                                    onTextChanged: inputProductCode = text
                                    
                                    Text {
                                        text: "Auto-generado"
                                        color: grayMedium
                                        visible: !parent.text
                                        font: parent.font
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                            }
                        }
                        
                        // Nombre del Producto
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
                        
                        // Marca
                        // Marca con ComboBox Inteligente
                        ColumnLayout {
                            Layout.preferredWidth: 200
                            spacing: 4
                            
                            Text {
                                text: "Marca *"
                                font.pixelSize: 12
                                font.bold: true
                                color: grayDark
                            }
                            
                            // Importar MarcaComboBox (asegúrate de tener el archivo en la misma carpeta)
                            MarcaComboBox {
                                id: marcaComboBox
                                Layout.fillWidth: true
                                Layout.preferredHeight: inputHeight
                                
                                // Pasar modelo de marcas
                                marcasModel: {
                                    var marcasFormateadas = []
                                    for (var i = 0; i < crearProductoDialog.marcasModel.length; i++) {
                                        var marca = crearProductoDialog.marcasModel[i]
                                        marcasFormateadas.push({
                                            id: marca.id,
                                            nombre: marca.Nombre || marca.nombre,
                                            detalles: marca.Detalles || marca.detalles || ""
                                        })
                                    }
                                    return marcasFormateadas
                                }
                                
                                placeholderText: "Buscar o crear marca..."
                                required: true
                                
                                // Colores adaptados al diseño
                                primaryColor: crearProductoDialog.primaryBlue
                                successColor: crearProductoDialog.successGreen
                                dangerColor: crearProductoDialog.dangerRed
                                lightGray: crearProductoDialog.grayLight
                                darkGray: crearProductoDialog.grayMedium
                                
                                // Cuando se selecciona una marca existente
                                onMarcaCambiada: function(marca, marcaId) {
                                    console.log("🏷️ MARCA CAMBIADA - Nombre:", marca, "ID:", marcaId)
                                    
                                    // ✅ ASIGNACIÓN DIRECTA E INMEDIATA
                                    crearProductoDialog.marcaIdSeleccionada = marcaId
                                    crearProductoDialog.marcaSeleccionadaNombre = marca
                                    crearProductoDialog.inputMarca = marca
                                    
                                    // Verificación inmediata
                                    console.log("🔍 Verificación inmediata:")
                                    console.log("  - marcaIdSeleccionada:", crearProductoDialog.marcaIdSeleccionada)
                                    console.log("  - Validación:", crearProductoDialog.calcularValidacion())
                                }
                                
                                // Cuando se solicita crear una nueva marca
                                onNuevaMarcaCreada: function(nombreMarca) {
                                    console.log("➕ Solicitando crear nueva marca:", nombreMarca)
                                    crearNuevaMarcaEnBackend(nombreMarca)
                                }
                            }
                        }
                    }
                    
                    // Fila 2: Unidad, P. Compra, P. Venta, Fecha Vencimiento
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        
                        // Unidad
                        ColumnLayout {
                            Layout.preferredWidth: 110
                            spacing: 4
                            
                            Text {
                                text: "Unidad"
                                font.pixelSize: 12
                                font.bold: true
                                color: grayDark
                            }
                            
                            ComboBox {
                                id: unidadCombo
                                Layout.fillWidth: true
                                Layout.preferredHeight: inputHeight
                                model: ["Tabletas", "Cápsulas", "ml", "mg", "g", "Unidades", "Sobres", "Frascos", "Ampollas", "Jeringas"]
                                font.pixelSize: 11
                                
                                background: Rectangle {
                                    color: white
                                    border.color: parent.activeFocus ? primaryBlue : borderColor
                                    border.width: 1
                                    radius: 6
                                }
                                
                                onCurrentTextChanged: inputMeasureUnit = currentText
                                
                                Component.onCompleted: {
                                    currentIndex = 0
                                    inputMeasureUnit = currentText
                                }
                            }
                        }
                        
                        // Precio Compra
                        ColumnLayout {
                            Layout.preferredWidth: 100
                            spacing: 4
                            
                            Text {
                                text: "P. Compra *"
                                font.pixelSize: 12
                                font.bold: true
                                color: grayDark
                            }
                            
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: inputHeight
                                color: white
                                border.color: precioCompraField.activeFocus ? successGreen : borderColor
                                border.width: 1
                                radius: 6
                                
                                TextInput {
                                    id: precioCompraField
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    verticalAlignment: TextInput.AlignVCenter
                                    selectByMouse: true
                                    font.pixelSize: 12
                                    color: grayDark
                                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                                    horizontalAlignment: TextInput.AlignHCenter
                                    
                                    onTextChanged: {
                                        var cleanText = text.replace(/[^0-9.]/g, '');
                                        if (cleanText !== text) {
                                            text = cleanText;
                                        }
                                        
                                        inputPurchasePrice = text.length > 0 ? (parseFloat(text) || 0.0) : 0.0;
                                    }
                                    
                                    Text {
                                        text: "0.00"
                                        color: grayMedium
                                        visible: !parent.text
                                        font: parent.font
                                        verticalAlignment: Text.AlignVCenter
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }
                            }
                        }
                        
                        // Precio Venta
                        ColumnLayout {
                            Layout.preferredWidth: 100
                            spacing: 4
                            
                            Text {
                                text: "P. Venta *"
                                font.pixelSize: 12
                                font.bold: true
                                color: grayDark
                            }
                            
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: inputHeight
                                color: white
                                border.color: precioVentaField.activeFocus ? primaryBlue : borderColor
                                border.width: 1
                                radius: 6
                                
                                TextInput {
                                    id: precioVentaField
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    verticalAlignment: TextInput.AlignVCenter
                                    selectByMouse: true
                                    font.pixelSize: 12
                                    color: grayDark
                                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                                    horizontalAlignment: TextInput.AlignHCenter
                                    
                                    onTextChanged: {
                                        var cleanText = text.replace(/[^0-9.]/g, '');
                                        if (cleanText !== text) {
                                            text = cleanText;
                                        }
                                        
                                        inputSalePrice = text.length > 0 ? (parseFloat(text) || 0.0) : 0.0;
                                    }
                                    
                                    Text {
                                        text: "0.00"
                                        color: grayMedium
                                        visible: !parent.text
                                        font: parent.font
                                        verticalAlignment: Text.AlignVCenter
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }
                            }
                        }
                        
                        // Fecha Vencimiento con checkbox
                        ColumnLayout {
                            Layout.preferredWidth: 200
                            spacing: 4
                            visible: !modoEdicion
                            
                            Text {
                                text: "Fecha Venc."
                                font.pixelSize: 12
                                font.bold: true
                                color: grayDark
                            }
                            
                            RowLayout {
                                spacing: 4
                                
                                Rectangle {
                                    Layout.preferredWidth: 120
                                    Layout.preferredHeight: inputHeight
                                    color: inputNoExpiry ? "#F5F5F5" : white
                                    border.color: fechaVencimientoField.activeFocus ? warningAmber : borderColor
                                    border.width: 1
                                    radius: 6
                                    
                                    TextInput {
                                        id: fechaVencimientoField
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        verticalAlignment: TextInput.AlignVCenter
                                        selectByMouse: true
                                        font.pixelSize: 12
                                        color: grayDark
                                        inputMethodHints: Qt.ImhDigitsOnly
                                        maximumLength: 10
                                        enabled: !inputNoExpiry
                                        
                                        onTextChanged: {
                                            if (!inputNoExpiry) {
                                                var formatted = autoFormatDate(text)
                                                if (formatted !== text) {
                                                    text = formatted
                                                }
                                                inputExpirationDate = formatted
                                            }
                                        }
                                        
                                        Text {
                                            text:"YYYY-MM-DD"
                                            color: grayMedium
                                            visible: !parent.text
                                            font: parent.font
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                }
                                
                                CheckBox {
                                    Layout.preferredWidth: 20
                                    Layout.preferredHeight: inputHeight
                                    checked: !inputNoExpiry
                                    
                                    indicator: Rectangle {
                                        width: 16
                                        height: 16
                                        anchors.centerIn: parent
                                        radius: 2
                                        border.color: borderColor
                                        border.width: 1
                                        color: parent.checked ? primaryBlue : white
                                        
                                        Text {
                                            anchors.centerIn: parent
                                            text: "✓"
                                            color: white
                                            font.pixelSize: 10
                                            visible: parent.parent.checked
                                        }
                                    }
                                    
                                    contentItem: Item {}
                                    
                                    onCheckedChanged: {
                                        inputNoExpiry = !checked
                                        if (!checked) {
                                            inputExpirationDate = ""
                                            fechaVencimientoField.text = ""
                                        }
                                    }
                                }
                                
                                Text {
                                    text: "Con vencimiento"
                                    font.pixelSize: 10
                                    color: grayMedium
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }
                        }
                        
                        Item { Layout.fillWidth: true }
                    }
                    
                    // Fila 3: Solo Stock Unitario y Proveedor (SIN CAJAS)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        visible: !modoEdicion
                        
                        // Stock 
                        ColumnLayout {
                            Layout.preferredWidth: 120
                            spacing: 4
                            
                            Text {
                                text: "Stock *"
                                font.pixelSize: 12
                                font.bold: true
                                color: grayDark
                            }
                            
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: inputHeight
                                color: white
                                border.color: stockUnitarioField.activeFocus ? primaryBlue : borderColor
                                border.width: 1
                                radius: 6
                                
                                TextInput {
                                    id: stockUnitarioField
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    verticalAlignment: TextInput.AlignVCenter
                                    selectByMouse: true
                                    font.pixelSize: 12
                                    color: grayDark
                                    inputMethodHints: Qt.ImhDigitsOnly
                                    horizontalAlignment: TextInput.AlignHCenter
                                    
                                    onTextChanged: {
                                        var cleanText = text.replace(/[^0-9]/g, '');
                                        if (cleanText !== text) {
                                            text = cleanText;
                                        }
                                        
                                        inputStockUnit = text.length > 0 ? (parseInt(text) || 0) : 0;
                                    }
                                    
                                    Text {
                                        text: "0"
                                        color: grayMedium
                                        visible: !parent.text
                                        font: parent.font
                                        verticalAlignment: Text.AlignVCenter
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }
                            }
                        }

                        // Proveedor
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            
                            Text {
                                text: "Proveedor (Opcional)"
                                font.pixelSize: 12
                                font.bold: true
                                color: grayDark
                            }
                            
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: inputHeight
                                color: white
                                border.color: proveedorField.activeFocus ? primaryBlue : borderColor
                                border.width: 1
                                radius: 6
                                
                                TextInput {
                                    id: proveedorField
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    verticalAlignment: TextInput.AlignVCenter
                                    selectByMouse: true
                                    font.pixelSize: 12
                                    color: grayDark
                                    
                                    onTextChanged: inputSupplier = text
                                    
                                    Text {
                                        text: "Nombre del proveedor..."
                                        color: grayMedium
                                        visible: !parent.text
                                        font: parent.font
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                            }
                        }
                    }
                    
                    // Fila 4: Descripción (fila completa)
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        
                        Text {
                            text: "Descripción (Opcional)"
                            font.pixelSize: 12
                            font.bold: true
                            color: grayDark
                        }
                        
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 60
                            color: white
                            border.color: detallesField.activeFocus ? primaryBlue : borderColor
                            border.width: 1
                            radius: 6
                            
                            Flickable {
                                id: flick
                                anchors.fill: parent
                                anchors.margins: 8
                                contentWidth: width
                                contentHeight: detallesField.implicitHeight
                                clip: true
                                
                                function ensureVisible(r) {
                                    if (contentY >= r.y)
                                        contentY = r.y;
                                    else if (contentY+height <= r.y+r.height)
                                        contentY = r.y+r.height-height;
                                }
                                
                                TextEdit {
                                    id: detallesField
                                    width: parent.width
                                    height: Math.max(implicitHeight, 44)
                                    wrapMode: TextEdit.Wrap
                                    selectByMouse: true
                                    font.pixelSize: 12
                                    color: grayDark
                                    
                                    onCursorRectangleChanged: flick.ensureVisible(cursorRectangle)
                                    onTextChanged: inputProductDetails = text
                                    
                                    Text {
                                        text: "Descripción detallada del medicamento..."
                                        color: grayMedium
                                        visible: !parent.text
                                        font: parent.font
                                    }
                                }
                            }
                        }
                    }
                    
                    // Botones de acción
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 20
                        Layout.alignment: Qt.AlignCenter
                        spacing: 12
                        
                        Button {
                            Layout.preferredWidth: 120
                            Layout.preferredHeight: buttonHeight
                            
                            background: Rectangle {
                                color: parent.pressed ? "#F3F4F6" : white
                                border.color: borderColor
                                border.width: 1
                                radius: 8
                            }
                            
                            contentItem: Text {
                                text: "Cancelar"
                                color: grayDark
                                font.pixelSize: 14
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: {
                                limpiarFormularioSeguro()
                                cancelarCreacion()
                                volverALista() 
                                close()
                            }
                        }
                        
                        Button {
                            Layout.preferredWidth: modoEdicion ? 180 : 200
                            Layout.preferredHeight: buttonHeight
                            
                            // ✅ BINDING MÁS EXPLÍCITO
                            enabled: {
                                var validacion = calcularValidacion()
                                var marcasOk = marcasCargadas || (marcasModel && marcasModel.length > 0)
                                return validacion && marcasOk
                            }
                            
                            background: Rectangle {
                                color: parent.enabled ? (parent.pressed ? "#1D4ED8" : primaryBlue) : "#E5E7EB"
                                radius: 8
                            }
                            
                            onEnabledChanged: {
                                console.log("🔘 Botón Guardar enabled:", enabled)
                                console.log("  - calcularValidacion():", calcularValidacion())  // ✅ CORREGIDO
                                console.log("  - marcasCargadas:", marcasCargadas)
                            }
                            
                            contentItem: Text {
                                text: modoEdicion ? "Actualizar Producto" : "Crear Producto + Lote"
                                color: parent.parent.enabled ? white : grayMedium
                                font.pixelSize: 14
                                font.bold: true
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

    // Notificación
    Rectangle {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 100
        width: Math.min(parent.width - baseSpacing * 2, 350)
        height: 40
        color: successGreen
        radius: 8
        visible: showSuccessMessage
        opacity: showSuccessMessage ? 1.0 : 0.0
        z: 100
        
        Behavior on opacity {
            NumberAnimation { duration: 300 }
        }
        
        Row {
            anchors.centerIn: parent
            spacing: 8
            
            Text {
                text: "✓"
                color: white
                font.pixelSize: 14
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
            
            Text {
                text: successMessage
                color: white
                font.pixelSize: 12
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    Component.onCompleted: {
        if (inventarioModel) {
            cargarMarcasDisponibles()
        }
    }

    onOpened: {
        Qt.callLater(function() {
            if (nombreField) {
                nombreField.forceActiveFocus()
            }
        })
    }

    function calcularValidacion() {
        var nombreValido = inputProductName.length > 0
        var precioCompraValido = inputPurchasePrice > 0
        var precioVentaValido = inputSalePrice > 0
        var marcaValida = marcaIdSeleccionada > 0
        
        var basicValidation = nombreValido && precioCompraValido && precioVentaValido && marcaValida
        
        console.log("🔍 VALIDACIÓN DETALLADA:")
        console.log("  - nombreValido:", nombreValido, "(", inputProductName, ")")
        console.log("  - precioCompraValido:", precioCompraValido, "(", inputPurchasePrice, ")")
        console.log("  - precioVentaValido:", precioVentaValido, "(", inputSalePrice, ")")
        console.log("  - marcaValida:", marcaValida, "(ID:", marcaIdSeleccionada, ")")
        
        if (modoEdicion) {
            console.log("  - MODO EDICIÓN: retorna", basicValidation)
            return basicValidation
        } else {
            var stockValido = inputStockUnit >= 0
            var fechaValida = inputNoExpiry || 
                            (inputExpirationDate.length > 0 && validateExpiryDate(inputExpirationDate))
            
            console.log("  - stockValido:", stockValido, "(", inputStockUnit, ")")
            console.log("  - inputNoExpiry:", inputNoExpiry)
            console.log("  - inputExpirationDate:", inputExpirationDate)
            console.log("  - fechaValida:", fechaValida)
            
            var resultado = basicValidation && stockValido && fechaValida
            console.log("  - RESULTADO FINAL:", resultado)
            
            return resultado
        }
    }
}