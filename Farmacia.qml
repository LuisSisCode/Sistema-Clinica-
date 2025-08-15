import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

Item {
    id: farmaciaRoot
    objectName: "farmaciaRoot"
    
    // Propiedades de colores consistentes
    readonly property color primaryColor: "#273746"
    readonly property color primaryDarkColor: "#34495E"
    readonly property color successColor: "#27ae60"
    readonly property color dangerColor: "#E74C3C"
    readonly property color warningColor: "#f39c12"
    readonly property color lightGrayColor: "#ECF0F1"
    readonly property color darkGrayColor: "#7f8c8d"
    readonly property color textColor: "#2c3e50"
    readonly property color whiteColor: "#FFFFFF"
    readonly property color blueColor: "#3498db"

    // Subsección actual (0=Ventas, 1=Productos, 2=Compras)
    property int currentSubSection: mainWindow.farmaciaSubsection
    
    // ===== MODELOS QOBJECT INTEGRADOS =====
    property var inventarioModel: null
    property var ventaModel: null 
    property var compraModel: null
    
    // Estado de conectividad
    property bool modelsReady: appController && appController.inventario_model_instance !== null && appController.venta_model_instance !== null && appController.compra_model_instance !== null
    property bool dataLoading: false

    // Properties para acceso reactivo a models QObject (SIN FALLBACK)
    property var proveedoresModel: compraModel ? compraModel.proveedores : []
    property var lotesModel: inventarioModel ? inventarioModel.lotes_activos : []
    property var ventasModel: ventaModel ? ventaModel.ventas_hoy : []
    property var productosUnicosModel: inventarioModel ? inventarioModel.productos : []
    property var comprasModel: compraModel ? compraModel.compras_recientes : []

    // Properties adicionales de estado
    property var searchResults: inventarioModel ? inventarioModel.search_results : []
    property var alertas: inventarioModel ? inventarioModel.alertas : []
    property var carritoItems: ventaModel ? ventaModel.carrito_items : []

    // ===== INICIALIZACIÓN Y CONEXIÓN DE MODELS =====
    
    // Inicialización de models después de que estén listos
    Connections {
        target: appController
        function onModelsReady() {
            console.log("🔗 Conectando Models QObject a Farmacia.qml")
            inventarioModel = appController.inventario_model_instance
            ventaModel = appController.venta_model_instance
            compraModel = appController.compra_model_instance
            
            console.log("✅ Models conectados a Farmacia")
            // Actualizar estado de conectividad
            if (compraModel) {
                console.log("🔄 Forzando refresh de CompraModel...")
                compraModel.force_refresh_compras()
            }

            // Cargar datos iniciales
            if (inventarioModel) {
                inventarioModel.refresh_productos()
                inventarioModel.actualizar_alertas()
            }
            if (ventaModel) {
                ventaModel.refresh_ventas_hoy()
                ventaModel.refresh_estadisticas()
            }
            if (compraModel) {
                compraModel.refresh_compras()
                compraModel.refresh_proveedores()
            }
        }
    }

    // ===== CONNECTIONS PARA SIGNALS DE MODELS =====
    
    // Conectar signals de InventarioModel
    Connections {
        target: inventarioModel
        function onOperacionExitosa(mensaje) {
            console.log("✅ Inventario:", mensaje)
            mostrarNotificacion(mensaje, "success")
        }
        function onOperacionError(mensaje) {
            console.log("❌ Error Inventario:", mensaje)
            mostrarNotificacion(mensaje, "error")
        }
        function onStockBajoAlert(codigo, stock) {
            console.log("⚠️ Stock bajo:", codigo, "-", stock, "unidades")
            mostrarNotificacion(`Stock bajo: ${codigo} (${stock} unidades)`, "warning")
        }
        function onProductoVencidoAlert(codigo, fechaVencimiento) {
            console.log("⏰ Producto por vencer:", codigo, "-", fechaVencimiento)
            mostrarNotificacion(`Por vencer: ${codigo} (${fechaVencimiento})`, "warning")
        }
        function onProductosChanged() {
            console.log("📦 Productos actualizados")
            // Emitir signal para actualizar vistas dependientes
            datosActualizados()
        }
        function onSearchResultsChanged() {
            console.log("🔍 Resultados de búsqueda actualizados")
        }
        function onLoadingChanged() {
            dataLoading = inventarioModel.loading
        }
    }

    // Conectar signals de VentaModel
    Connections {
        target: ventaModel
        function onVentaCreada(ventaId, total) {
            console.log("💰 Venta creada:", ventaId, "Total:", total)
            mostrarNotificacion(`Venta creada: $${total.toFixed(2)}`, "success")
            // Refrescar inventario automáticamente
            if (inventarioModel) {
                inventarioModel.refresh_productos()
            }
        }
        function onOperacionError(mensaje) {
            console.log("❌ Error Venta:", mensaje)
            mostrarNotificacion(mensaje, "error")
        }
        function onOperacionExitosa(mensaje) {
            console.log("✅ Venta:", mensaje)
            mostrarNotificacion(mensaje, "success")
        }
        function onVentasHoyChanged() {
            console.log("💰 Ventas del día actualizadas")
            datosActualizados()
        }
        function onCarritoCambiado() {
            console.log("🛒 Carrito actualizado")
        }
    }

    // Conectar signals de CompraModel
    Connections {
        target: compraModel
        function onCompraCreada(compraId, total) {
            console.log("📦 Compra creada:", compraId, "Total:", total)
            mostrarNotificacion(`Compra registrada: $${total.toFixed(2)}`, "success")
            // Refrescar inventario automáticamente
            if (inventarioModel) {
                inventarioModel.refresh_productos()
            }
        }
        function onOperacionError(mensaje) {
            console.log("❌ Error Compra:", mensaje)
            mostrarNotificacion(mensaje, "error")
        }
        function onOperacionExitosa(mensaje) {
            console.log("✅ Compra:", mensaje)
            mostrarNotificacion(mensaje, "success")
        }
        function onComprasRecientesChanged() {
            console.log("📦 Compras recientes actualizadas")
            datosActualizados()
        }
        function onProveedoresChanged() {
            console.log("🏢 Proveedores actualizados")
        }
    }
    
    // ===== FUNCIONES CENTRALES DE GESTIÓN DE DATOS (CONECTADAS A BD) =====
    
    // Función para verificar si un producto existe
    function productoExiste(codigo) {
        if (!inventarioModel || !codigo) return -1
        
        var producto = inventarioModel.get_producto_by_codigo(codigo)
        return producto && Object.keys(producto).length > 0 ? 1 : -1
    }
    
    // Función para crear un nuevo producto único
    function crearProductoUnico(datos) {
        console.log("⚠️ crearProductoUnico: Función pendiente de implementar en InventarioModel")
        // TODO: Implementar en InventarioModel
        // Por ahora retornamos un ID temporal
        return Date.now()
    }
    
    // Función para agregar nueva compra MEJORADA CON MODEL
    function agregarCompra(proveedor, usuario, productos) {
        console.log("=== AGREGANDO NUEVA COMPRA CON MODEL ===")
        
        if (!compraModel) {
            console.log("❌ CompraModel no disponible")
            mostrarNotificacion("Error: Sistema de compras no disponible", "error")
            return null
        }
        
        if (!productos || productos.length === 0) {
            mostrarNotificacion("Error: No hay productos para comprar", "error")
            return null
        }
        
        // Encontrar ID del proveedor
        var proveedorId = 0
        var proveedores = compraModel.proveedores || []
        for (var i = 0; i < proveedores.length; i++) {
            if (proveedores[i].nombre === proveedor) {
                proveedorId = proveedores[i].id
                break
            }
        }
        
        if (proveedorId === 0) {
            console.log("🏢 Creando nuevo proveedor:", proveedor)
            proveedorId = compraModel.crear_proveedor(proveedor, "Dirección no especificada")
            if (proveedorId === 0) {
                mostrarNotificacion("Error: No se pudo crear el proveedor", "error")
                return null
            }
        }
        
        // Establecer proveedor seleccionado
        compraModel.set_proveedor_seleccionado(proveedorId)
        
        // Limpiar items previos y agregar nuevos
        compraModel.limpiar_items_compra()
        
        for (var j = 0; j < productos.length; j++) {
            var prod = productos[j]
            compraModel.agregar_item_compra(
                prod.codigo,
                prod.cajas || 0,
                prod.stockTotal || prod.cantidad || 0,
                prod.precioCompra,
                prod.fechaVencimiento || "2025-12-31"
            )
        }
        
        // Procesar la compra
        var exito = compraModel.procesar_compra_actual()
        if (exito) {
            console.log("✅ Compra procesada exitosamente")
            return "C-PROCESSED"
        } else {
            console.log("❌ Error procesando compra")
            return null
        }
    }

    // Alias para compatibilidad con Compras.qml
    function agregarCompraConDetalles(proveedor, usuario, productos, detalles) {
        console.log("📝 Detalles adicionales de compra:", detalles)
        return agregarCompra(proveedor, usuario, productos)
    }
    
    // Función para determinar el estado de un lote
    function determinarEstadoLote(fechaVencimiento, stock) {
        if (stock <= 0) return "agotado"
        
        if (!fechaVencimiento || fechaVencimiento === "Sin fecha") return "disponible"
        
        var hoy = new Date()
        var fechaVenc = parsearFecha(fechaVencimiento)
        var diasHastaVencimiento = Math.floor((fechaVenc - hoy) / (1000 * 60 * 60 * 24))
        
        if (diasHastaVencimiento <= 0) {
            return "vencido"
        } else if (diasHastaVencimiento <= 30) {
            return "proximo_vencer"
        } else {
            return "disponible"
        }
    }
    
    // Función para obtener productos únicos para la vista principal (CON DATOS REALES)
    function obtenerProductosParaVista() {
        if (!inventarioModel) {
            return []
        }
        
        var productos = inventarioModel.productos || []
        var productosVista = []
        
        for (var i = 0; i < productos.length; i++) {
            var producto = productos[i]
            
            // Calcular stock total y convertir precios
            var stockCaja = parseInt(producto.Stock_Caja) || 0
            var stockUnitario = parseInt(producto.Stock_Unitario) || 0
            var stockTotal = stockCaja + stockUnitario
            var precioVenta = parseFloat(producto.Precio_venta) || 0
            
            productosVista.push({
                id: producto.id,
                codigo: producto.Codigo || "",
                nombre: producto.Nombre || "Producto sin nombre",
                stockTotal: stockTotal,
                precioUnitarioPromedio: precioVenta,
                lotesTotales: 1, // Se puede obtener de lotes_activos si es necesario
                lotesDisponibles: stockTotal > 0 ? 1 : 0,
                // Campos adicionales para compatibilidad
                precioCompra: parseFloat(producto.Precio_compra) || 0,
                precioVenta: precioVenta,
                detalles: producto.Detalles || "Sin detalles",
                stockCaja: stockCaja,
                stockUnitario: stockUnitario
            })
        }
        
        console.log("📋 Productos para vista principal:", productosVista.length)
        return productosVista
    }
    
    // Función para obtener lotes de un producto específico (CON DATOS REALES)
    function obtenerLotesDeProducto(codigo) {
        if (!inventarioModel) {
            console.log("❌ InventarioModel no disponible")
            return []
        }
        
        // Buscar producto por código
        var producto = inventarioModel.get_producto_by_codigo(codigo)
        if (!producto || !producto.id) {
            return []
        }
        
        // Obtener lotes del producto
        var lotes = inventarioModel.get_lotes_producto(producto.id) || []
        var lotesProducto = []
        
        for (var i = 0; i < lotes.length; i++) {
            var lote = lotes[i]
            lotesProducto.push({
                id: lote.id,
                numeroLote: lote.Numero_Lote || `L-${lote.id}`,
                fechaVencimiento: lote.Fecha_Vencimiento || "Sin fecha",
                stock: (lote.Cantidad_Caja || 0) + (lote.Cantidad_Unitario || 0),
                estado: determinarEstadoLote(lote.Fecha_Vencimiento, (lote.Cantidad_Caja || 0) + (lote.Cantidad_Unitario || 0)),
                fechaCompra: lote.Fecha_Compra || "No especificada",
                proveedor: lote.Proveedor_Nombre || "No especificado",
                precioCompra: lote.Precio_Compra || 0,
                precioVenta: lote.Precio_Venta || producto.Precio_venta || 0
            })
        }
        
        return lotesProducto
    }
    
    // Función para agregar nuevo proveedor (CON MODEL)
    function agregarProveedor(nombre, direccion, telefono, email) {
        if (!compraModel) {
            mostrarNotificacion("Error: Sistema de compras no disponible", "error")
            return false
        }
        
        if (!nombre || nombre.trim() === "") {
            mostrarNotificacion("Error: Nombre de proveedor requerido", "error")
            return false
        }
        
        var proveedorId = compraModel.crear_proveedor(
            nombre.trim(),
            direccion || "Dirección no especificada"
        )
        
        return proveedorId > 0
    }
    
    // Función para realizar venta MEJORADA (CON MODEL Y FIFO)
    function realizarVenta(usuario, productos) {
        console.log("=== REALIZANDO NUEVA VENTA CON MODEL ===")
        
        if (!ventaModel) {
            console.log("❌ VentaModel no disponible")
            mostrarNotificacion("Error: Sistema de ventas no disponible", "error")
            return null
        }
        
        if (!productos || productos.length === 0) {
            mostrarNotificacion("Error: No hay productos para vender", "error")
            return null
        }
        
        // Limpiar carrito previo
        ventaModel.limpiar_carrito()
        
        // Agregar productos al carrito
        for (var i = 0; i < productos.length; i++) {
            var prod = productos[i]
            ventaModel.agregar_item_carrito(
                prod.codigo,
                prod.cantidad,
                prod.precio || 0 // precio personalizado o 0 para usar precio del producto
            )
        }
        
        // Procesar venta
        var exito = ventaModel.procesar_venta_carrito()
        if (exito) {
            console.log("✅ Venta procesada exitosamente")
            return "V-PROCESSED"
        } else {
            console.log("❌ Error procesando venta")
            return null
        }
    }
    
    // Función para buscar productos disponibles por nombre parcial (CON MODEL)
    function buscarProductosPorNombre(textoBusqueda) {
        if (!inventarioModel) {
            console.log("❌ InventarioModel no disponible")
            return []
        }
        
        if (!textoBusqueda || textoBusqueda.length < 2) {
            return []
        }
        
        inventarioModel.buscar_productos(textoBusqueda)
        return inventarioModel.search_results || []
    }
    
    // Función para obtener stock total de un producto (CON MODEL)
    function obtenerStockProducto(codigo) {
        if (!inventarioModel || !codigo) return 0
        
        var producto = inventarioModel.get_producto_by_codigo(codigo)
        return producto ? ((producto.Stock_Caja || 0) + (producto.Stock_Unitario || 0)) : 0
    }

    // ===== FUNCIONES PARA SINCRONIZACIÓN CON PRODUCTOS.QML =====
    
    // Función para obtener productos formateados para la vista de inventario (CON DATOS REALES)
    function obtenerProductosParaInventario() {
        if (!inventarioModel) {
            console.log("❌ InventarioModel no disponible")
            return []
        }
        
        var productos = inventarioModel.productos || []
        var productosFormateados = []
        
        for (var i = 0; i < productos.length; i++) {
            var prod = productos[i]
            
            // Debug: mostrar estructura del producto
            console.log("📦 Producto estructurado:", JSON.stringify(prod))
            
            // Convertir precios a números para evitar errores de visualización
            var precioCompra = parseFloat(prod.Precio_compra) || 0
            var precioVenta = parseFloat(prod.Precio_venta) || 0
            
            productosFormateados.push({
                id: prod.id,
                codigo: prod.Codigo || "",
                nombre: prod.Nombre || "Producto sin nombre",
                detalles: prod.Detalles || prod.Producto_Detalles || "Sin detalles especificados",
                precioCompra: precioCompra,
                precioVenta: precioVenta,
                stockCaja: parseInt(prod.Stock_Caja) || 0,
                stockUnitario: parseInt(prod.Stock_Unitario) || 0,
                unidadMedida: prod.Unidad_Medida || "Unidades",
                idMarca: prod.Marca_Nombre || prod.ID_Marca || "GENÉRICO",
                // Campos adicionales para compatibilidad
                precioCompraBase: precioCompra,
                precioVentaBase: precioVenta,
                stockTotal: (parseInt(prod.Stock_Caja) || 0) + (parseInt(prod.Stock_Unitario) || 0)
            })
        }
        
        console.log("📋 Productos formateados para inventario:", productosFormateados.length)
        return productosFormateados
    }

    // Función para actualizar precio de venta (CON MODEL)
    function actualizarPrecioVentaProducto(codigo, nuevoPrecio) {
        console.log("💰 Actualizando precio con InventarioModel:", codigo, nuevoPrecio)
        
        if (!inventarioModel) {
            console.log("❌ InventarioModel no disponible")
            mostrarNotificacion("Error: Sistema de inventario no disponible", "error")
            return false
        }
        
        // TODO: Implementar actualización de precio en InventarioModel
        console.log("⚠️ Actualización de precio pendiente de implementar en Model")
        mostrarNotificacion("Función pendiente de implementar", "warning")
        return true
    }

    // Función para eliminar producto (CON MODEL)
    function eliminarProductoInventario(codigo) {
        console.log("🗑️ Eliminación con InventarioModel:", codigo)
        
        if (!inventarioModel) {
            console.log("❌ InventarioModel no disponible")
            mostrarNotificacion("Error: Sistema de inventario no disponible", "error")
            return false
        }
        
        // TODO: Implementar eliminación en InventarioModel
        console.log("⚠️ Eliminación pendiente de implementar en Model")
        mostrarNotificacion("Función pendiente de implementar", "warning")
        return false
    }

    // Función para obtener productos de una compra específica
    function obtenerProductosDeCompra(compraId) {
        if (!compraModel) {
            console.log("❌ CompraModel no disponible")
            return []
        }
        
        // Obtener detalle completo de la compra
        var compraDetalle = compraModel.get_compra_detalle(compraId)
        if (!compraDetalle || !compraDetalle.items) {
            return []
        }
        
        var productosCompra = []
        var items = compraDetalle.items
        
        for (var i = 0; i < items.length; i++) {
            var item = items[i]
            productosCompra.push({
                codigo: item.Codigo || item.codigo,
                nombre: item.Nombre || item.nombre || "Producto no encontrado",
                cajas: item.Cantidad_Caja || 0,
                stockTotal: (item.Cantidad_Caja || 0) + (item.Cantidad_Unitario || 0),
                precioCompra: item.Precio_Unitario || item.precioCompra || 0
            })
        }
        
        console.log("📦 Productos encontrados para", compraId, ":", productosCompra.length)
        return productosCompra
    }

    // Función auxiliar para obtener nombre del producto (CON MODEL)
    function obtenerNombreProducto(codigo) {
        if (!inventarioModel || !codigo) return "Producto no encontrado"
        
        var producto = inventarioModel.get_producto_by_codigo(codigo)
        return producto ? producto.Nombre : "Producto no encontrado"
    }
    
    // Función auxiliar para parsear fecha DD/MM/YYYY
    function parsearFecha(fechaStr) {
        if (!fechaStr) return new Date()
        
        // Manejar formato YYYY-MM-DD (de BD)
        if (fechaStr.includes('-')) {
            return new Date(fechaStr)
        }
        
        // Manejar formato DD/MM/YYYY
        var partes = fechaStr.split('/')
        if (partes.length !== 3) return new Date()
        
        var dia = parseInt(partes[0])
        var mes = parseInt(partes[1]) - 1 // Los meses en JS van de 0-11
        var año = parseInt(partes[2])
        
        return new Date(año, mes, dia)
    }
    
    // Función para mostrar notificaciones (mejorada)
    function mostrarNotificacion(mensaje, tipo) {
        var prefijo = ""
        switch(tipo) {
            case "success": prefijo = "✅"; break
            case "error": prefijo = "❌"; break
            case "warning": prefijo = "⚠️"; break
            case "info": prefijo = "ℹ️"; break
            default: prefijo = "📝"; break
        }
        console.log(`${prefijo} [${tipo.toUpperCase()}] ${mensaje}`)
        
        // TODO: Implementar notificación visual en UI
        // Por ahora solo log en consola
    }
    
    // Función de debug para inspeccionar datos
    function debugProductoData(codigo) {
        if (!inventarioModel) {
            console.log("❌ InventarioModel no disponible para debug")
            return
        }
        
        console.log("🔍 DEBUG - Buscando producto:", codigo)
        var producto = inventarioModel.get_producto_by_codigo(codigo)
        console.log("📦 Producto encontrado:", JSON.stringify(producto, null, 2))
        
        if (producto && producto.id) {
            var lotes = inventarioModel.get_lotes_producto(producto.id)
            console.log("📋 Lotes del producto:", JSON.stringify(lotes, null, 2))
        }
    }
    
    // Función para forzar actualización de datos
    function forzarActualizacionDatos() {
        if (!modelsReady) {
            console.log("⚠️ Models no están listos para actualización")
            return
        }
        
        console.log("🔄 Forzando actualización de todos los datos...")
        
        if (inventarioModel) {
            inventarioModel.refresh_productos()
        }
        if (ventaModel) {
            ventaModel.refresh_ventas_hoy()
            ventaModel.refresh_estadisticas()
        }
        if (compraModel) {
            compraModel.refresh_compras()
            compraModel.refresh_proveedores()
        }
        
        // Emitir signal de actualización
        datosActualizados()
    }
    
    // Señal para notificar cambios en los datos
    signal datosActualizados()
    
    // Monitorear cambios en la subsección
    onCurrentSubSectionChanged: {
        console.log("Farmacia: Cambiando a subsección", currentSubSection)
        contentLoader.updateSource()
    }
    
    // Layout principal
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: whiteColor
            
            Loader {
                id: contentLoader
                anchors.fill: parent
                
                // Propiedades que se pasan a los componentes cargados
                property int subsection: currentSubSection
                property var inventarioModel: farmaciaRoot.inventarioModel
                property var ventaModel: farmaciaRoot.ventaModel  
                property var compraModel: farmaciaRoot.compraModel
                
                function updateSource() {
                    var newSource = getSourceForSubsection(currentSubSection)
                    if (source.toString() !== newSource) {
                        source = newSource
                    }
                }
                
                function getSourceForSubsection(subsection) {
                    switch(subsection) {
                        case 0: return "VentasMain.qml"
                        case 1: return "Productos.qml"
                        case 2: return "ComprasMain.qml"
                        default: return "VentasMain.qml" 
                    }
                }
                
                Component.onCompleted: updateSource()
                
                onStatusChanged: {
                    if (status === Loader.Error) {
                        console.error("Error cargando el módulo:", source)
                        sourceComponent = errorComponent
                    } else if (status === Loader.Ready) {
                        console.log("Módulo cargado exitosamente:", source)
                    }
                }
                
                Behavior on opacity {
                    NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
                }
                
                onSourceChanged: {
                    opacity = 0
                    loadingTimer.restart()
                }
                
                Timer {
                    id: loadingTimer
                    interval: 50
                    onTriggered: contentLoader.opacity = 1
                }
            }
            
            // Componente de error
            Component {
                id: errorComponent
                
                Rectangle {
                    color: "#FFF5F5"
                    border.color: dangerColor
                    border.width: 2
                    radius: 12
                    
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 16
                        
                        Label {
                            text: "⚠️"
                            font.pixelSize: 48
                            color: dangerColor
                            Layout.alignment: Qt.AlignHCenter
                        }
                        
                        Label {
                            text: "Error al cargar el módulo"
                            font.pixelSize: 18
                            font.bold: true
                            color: dangerColor
                            Layout.alignment: Qt.AlignHCenter
                        }
                        
                        Label {
                            text: "El archivo " + getCurrentSubSectionFile() + " no se pudo cargar"
                            font.pixelSize: 14
                            color: darkGrayColor
                            Layout.alignment: Qt.AlignHCenter
                        }
                        
                        Button {
                            text: "🔄 Reintentar"
                            Layout.alignment: Qt.AlignHCenter
                            
                            background: Rectangle {
                                color: parent.pressed ? Qt.darker(primaryColor, 1.2) : primaryColor
                                radius: 8
                            }
                            
                            contentItem: Label {
                                text: parent.text
                                color: whiteColor
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: contentLoader.updateSource()
                        }
                    }
                }
            }
            
            // Indicador de carga
            Rectangle {
                anchors.centerIn: parent
                width: 200
                height: 100
                color: whiteColor
                radius: 12
                border.color: lightGrayColor
                border.width: 1
                visible: contentLoader.status === Loader.Loading || dataLoading
                
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 12
                    
                    BusyIndicator {
                        Layout.alignment: Qt.AlignHCenter
                        running: parent.parent.visible
                    }
                    
                    Label {
                        text: dataLoading ? "Cargando datos..." : ("Cargando " + getCurrentSubSectionName() + "...")
                        color: textColor
                        font.pixelSize: 14
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }
    }
    
    // Funciones auxiliares
    function getCurrentSubSectionName() {
        const names = ["Gestión de Ventas", "Inventario de Productos", "Gestión de Compras"]
        return names[currentSubSection] || "Sección Desconocida"
    }
    
    function getCurrentSubSectionFile() {
        const files = ["VentasMain.qml", "Productos.qml", "ComprasMain.qml"]  // ← CAMBIADO
        return files[currentSubSection] || "Archivo.qml"
    }
    
    // Inicialización
    Component.onCompleted: {
        console.log("=== MÓDULO DE FARMACIA INICIALIZADO (CONECTADO A BD) ===")
        console.log("🔄 Esperando conexión con Models...")
        console.log("Subsección inicial:", currentSubSection)
    }
    
    // Monitorear cuando los models están listos
    onModelsReadyChanged: {
        if (modelsReady) {
            console.log("🚀 Models conectados:")
            console.log("📦 Productos disponibles:", productosUnicosModel.length)
            console.log("🏢 Proveedores:", proveedoresModel.length) 

            // DEBUG ESPECÍFICO PARA COMPRAS
            if (compraModel) {
                console.log("🛒 CompraModel disponible:", !!compraModel)
                console.log("🛒 Compras recientes (direct):", compraModel.compras_recientes ? compraModel.compras_recientes.length : "undefined")
                console.log("🛒 Total compras mes (property):", compraModel.total_compras_mes)
            }
            console.log("💰 Ventas del día:", ventasModel.length)
            // Configurar alertas automáticas
            if (inventarioModel) {
                inventarioModel.configurar_stock_minimo(10)
                inventarioModel.verificar_vencimientos(90)
            }
            
            // Emitir actualización
            datosActualizados()
        }
    }
    
    // Monitor de cambios en productos para debug
    onProductosUnicosModelChanged: {
        console.log("📊 ProductosUnicosModel actualizado - Total productos:", productosUnicosModel.length)
        if (productosUnicosModel.length > 0) {
            console.log("📝 Ejemplo de producto:", JSON.stringify(productosUnicosModel[0]))
        }
    }
}