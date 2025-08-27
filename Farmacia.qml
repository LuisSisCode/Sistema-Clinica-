import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

Item {
    id: farmaciaRoot
    objectName: "farmaciaRoot"

    // ELIMINADO: Conexiones para navegación de productos - ya no es necesario
    
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
    
    // Estado de conectividad mejorado
    property bool modelsReady: {
        return appController && 
               appController.inventario_model_instance !== null && 
               appController.venta_model_instance !== null && 
               appController.compra_model_instance !== null
    }
    property bool dataLoading: false

    // Properties para acceso reactivo a models QObject (CONECTADOS A BD)
    property var proveedoresModel: compraModel ? compraModel.proveedores : []
    property var lotesModel: inventarioModel ? inventarioModel.lotes_activos : []
    property var ventasModel: ventaModel ? ventaModel.ventas_hoy : []
    property var productosUnicosModel: inventarioModel ? inventarioModel.productos : []
    property var comprasModel: compraModel ? compraModel.compras_recientes : []

    // Properties adicionales de estado (DATOS REALES)
    property var searchResults: inventarioModel ? inventarioModel.search_results : []
    property var alertas: inventarioModel ? inventarioModel.alertas : []
    property var carritoItems: ventaModel ? ventaModel.carrito_items : []

    // ===== INICIALIZACIÓN Y CONEXIÓN DE MODELS =====
    
    // Inicialización de models después de que estén listos
    Connections {
        target: appController
        function onModelsReady() {
            console.log("🔗 Farmacia: Conectando Models QObject a BD")
            inventarioModel = appController.inventario_model_instance
            ventaModel = appController.venta_model_instance
            compraModel = appController.compra_model_instance
            
            console.log("✅ Farmacia: Models conectados exitosamente")
            
            // Verificar conexión de cada model
            if (inventarioModel) {
                console.log("📦 InventarioModel disponible - Productos:", inventarioModel.total_productos)
            }
            if (ventaModel) {
                console.log("💰 VentaModel disponible")
            }
            if (compraModel) {
                console.log("🛒 CompraModel disponible")
                compraModel.force_refresh_compras()
            }

            // Cargar datos iniciales desde BD
            refrescarTodosLosDatos()
        }
    }

    // ===== CONNECTIONS PARA SIGNALS DE MODELS (BD) =====
    
    // Conectar signals de InventarioModel
    Connections {
        target: inventarioModel
        function onOperacionExitosa(mensaje) {
            console.log("✅ Inventario BD:", mensaje)
            mostrarNotificacion(mensaje, "success")
        }
        function onOperacionError(mensaje) {
            console.log("❌ Error Inventario BD:", mensaje)
            mostrarNotificacion(mensaje, "error")
        }
        function onStockBajoAlert(codigo, stock) {
            console.log("⚠️ Stock bajo BD:", codigo, "-", stock, "unidades")
            mostrarNotificacion(`Stock bajo: ${codigo} (${stock} unidades)`, "warning")
        }
        function onProductoVencidoAlert(codigo, fechaVencimiento) {
            console.log("⏰ Producto por vencer BD:", codigo, "-", fechaVencimiento)
            mostrarNotificacion(`Por vencer: ${codigo} (${fechaVencimiento})`, "warning")
        }
        function onProductosChanged() {
            console.log("📦 Productos actualizados desde BD")
            datosActualizados()
        }
        function onSearchResultsChanged() {
            console.log("🔍 Resultados de búsqueda BD actualizados")
        }
        function onLoadingChanged() {
            dataLoading = inventarioModel.loading
        }
        function onProductoCreado(codigo, datos) {
            console.log("✅ Producto creado en BD:", codigo)
            mostrarNotificacion(`Producto ${codigo} creado exitosamente`, "success")
        }
        function onProductoEliminado(codigo) {
            console.log("🗑️ Producto eliminado de BD:", codigo)
            mostrarNotificacion(`Producto ${codigo} eliminado`, "warning")
        }
    }

    // Conectar signals de VentaModel
    Connections {
        target: ventaModel
        function onVentaCreada(ventaId, total) {
            console.log("💰 Venta creada en BD:", ventaId, "Total:", total)
            mostrarNotificacion(`Venta creada: $${total.toFixed(2)}`, "success")
            // Refrescar inventario automáticamente
            if (inventarioModel) {
                inventarioModel.refresh_productos()
            }
        }
        function onOperacionError(mensaje) {
            console.log("❌ Error Venta BD:", mensaje)
            mostrarNotificacion(mensaje, "error")
        }
        function onOperacionExitosa(mensaje) {
            console.log("✅ Venta BD:", mensaje)
            mostrarNotificacion(mensaje, "success")
        }
        function onVentasHoyChanged() {
            console.log("💰 Ventas del día actualizadas desde BD")
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
            console.log("📦 Compra creada en BD:", compraId, "Total:", total)
            mostrarNotificacion(`Compra registrada: $${total.toFixed(2)}`, "success")
            // Refrescar inventario automáticamente
            if (inventarioModel) {
                inventarioModel.refresh_productos()
            }
        }
        function onOperacionError(mensaje) {
            console.log("❌ Error Compra BD:", mensaje)
            mostrarNotificacion(mensaje, "error")
        }
        function onOperacionExitosa(mensaje) {
            console.log("✅ Compra BD:", mensaje)
            mostrarNotificacion(mensaje, "success")
        }
        function onComprasRecientesChanged() {
            console.log("📦 Compras recientes actualizadas desde BD")
            datosActualizados()
        }
        function onProveedoresChanged() {
            console.log("🏢 Proveedores actualizados desde BD")
        }
    }
    // ELIMINADO: Conexiones para mostrarCrearProducto y mostrarDetalleProducto
    // Ya no necesitamos cambiar el contentLoader para estos casos
    // ===== FUNCIONES CENTRALES DE GESTIÓN DE DATOS (CONECTADAS A BD) =====
    
    // Función para verificar si un producto existe (BD)
    function productoExiste(codigo) {
        if (!inventarioModel || !codigo) return -1
        
        var producto = inventarioModel.get_producto_by_codigo(codigo)
        return producto && Object.keys(producto).length > 0 ? 1 : -1
    }
    
    // Función para crear un nuevo producto único (BD)
    function crearProductoUnico(datosJson) {
        if (!inventarioModel) {
            console.log("❌ InventarioModel no disponible para crear producto")
            mostrarNotificacion("Error: Sistema de inventario no disponible", "error")
            return 0
        }
        
        console.log("📦 Creando producto en BD...")
        var exito = inventarioModel.crear_producto(datosJson)
        return exito ? Date.now() : 0  // Retornar ID temporal si es exitoso
    }
    
    // Función para agregar nueva compra MEJORADA CON MODEL BD
    function agregarCompra(proveedor, usuario, productos) {
        console.log("=== AGREGANDO NUEVA COMPRA CON BD ===")
        
        if (!compraModel) {
            console.log("❌ CompraModel no disponible")
            mostrarNotificacion("Error: Sistema de compras no disponible", "error")
            return null
        }
        
        if (!productos || productos.length === 0) {
            mostrarNotificacion("Error: No hay productos para comprar", "error")
            return null
        }
        
        // Encontrar ID del proveedor en BD
        var proveedorId = 0
        var proveedores = compraModel.proveedores || []
        for (var i = 0; i < proveedores.length; i++) {
            var nombreProveedor = proveedores[i].Nombre || proveedores[i].nombre
            if (nombreProveedor === proveedor) {
                proveedorId = proveedores[i].id
                break
            }
        }
        
        if (proveedorId === 0) {
            console.log("🏢 Creando nuevo proveedor en BD:", proveedor)
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
        
        // Procesar la compra en BD
        var exito = compraModel.procesar_compra_actual()
        if (exito) {
            console.log("✅ Compra procesada exitosamente en BD")
            return "C-PROCESSED-BD"
        } else {
            console.log("❌ Error procesando compra en BD")
            return null
        }
    }

    // Alias para compatibilidad con Compras.qml
    function agregarCompraConDetalles(proveedor, usuario, productos, detalles) {
        console.log("📋 Detalles adicionales de compra:", detalles)
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
    
    // Función para obtener productos únicos para la vista principal (CON DATOS BD)
    function obtenerProductosParaVista() {
        if (!inventarioModel) {
            console.log("❌ InventarioModel no disponible para vista")
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
                lotesTotales: 1,
                lotesDisponibles: stockTotal > 0 ? 1 : 0,
                // Campos adicionales para compatibilidad
                precioCompra: parseFloat(producto.Precio_compra) || 0,
                precioVenta: precioVenta,
                detalles: producto.Detalles || "Sin detalles",
                stockCaja: stockCaja,
                stockUnitario: stockUnitario,
                marca_nombre: producto.marca_nombre || producto.Marca_Nombre || "GENÉRICO"
            })
        }
        
        console.log("📋 Productos para vista principal (BD):", productosVista.length)
        return productosVista
    }
    
    // Función para obtener lotes de un producto específico (CON DATOS BD)
    function obtenerLotesDeProducto(codigo) {
        if (!inventarioModel) {
            console.log("❌ InventarioModel no disponible para lotes")
            return []
        }
        
        // Buscar producto por código
        var producto = inventarioModel.get_producto_by_codigo(codigo)
        if (!producto || !producto.id) {
            return []
        }
        
        // Obtener lotes del producto desde BD
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
    
    // Función para agregar nuevo proveedor (CON MODEL BD)
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
    
    // Función para realizar venta MEJORADA (CON MODEL BD Y FIFO)
    function realizarVenta(usuario, productos) {
        console.log("=== REALIZANDO NUEVA VENTA CON BD ===")
        
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
        
        // Procesar venta en BD
        var exito = ventaModel.procesar_venta_carrito()
        if (exito) {
            console.log("✅ Venta procesada exitosamente en BD")
            return "V-PROCESSED-BD"
        } else {
            console.log("❌ Error procesando venta en BD")
            return null
        }
    }
    
    // Función para buscar productos disponibles por nombre parcial (CON MODEL BD)
    function buscarProductosPorNombre(textoBusqueda) {
        if (!inventarioModel) {
            console.log("❌ InventarioModel no disponible para búsqueda")
            return []
        }
        
        if (!textoBusqueda || textoBusqueda.length < 2) {
            return []
        }
        
        inventarioModel.buscar_productos(textoBusqueda)
        return inventarioModel.search_results || []
    }
    
    // Función para obtener stock total de un producto (CON MODEL BD)
    function obtenerStockProducto(codigo) {
        if (!inventarioModel || !codigo) return 0
        
        var producto = inventarioModel.get_producto_by_codigo(codigo)
        return producto ? ((producto.Stock_Caja || 0) + (producto.Stock_Unitario || 0)) : 0
    }

    // ===== FUNCIONES PARA SINCRONIZACIÓN CON PRODUCTOS.QML (BD) =====
    
    // Función para obtener productos formateados para la vista de inventario (CON DATOS BD)
    function obtenerProductosParaInventario() {
        if (!inventarioModel) {
            console.log("❌ InventarioModel no disponible para inventario")
            return []
        }
        
        var productos = inventarioModel.productos || []
        var productosFormateados = []
        
        for (var i = 0; i < productos.length; i++) {
            var prod = productos[i]
            
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
                idMarca: prod.marca_nombre || prod.Marca_Nombre || prod.ID_Marca || "GENÉRICO",
                // Campos adicionales para compatibilidad
                precioCompraBase: precioCompra,
                precioVentaBase: precioVenta,
                stockTotal: (parseInt(prod.Stock_Caja) || 0) + (parseInt(prod.Stock_Unitario) || 0)
            })
        }
        
        console.log("📋 Productos formateados para inventario (BD):", productosFormateados.length)
        return productosFormateados
    }

    // Función para actualizar precio de venta (CON MODEL BD)
    function actualizarPrecioVentaProducto(codigo, nuevoPrecio) {
        console.log("💰 Actualizando precio en BD:", codigo, nuevoPrecio)
        
        if (!inventarioModel) {
            console.log("❌ InventarioModel no disponible para actualizar precio")
            mostrarNotificacion("Error: Sistema de inventario no disponible", "error")
            return false
        }
        
        var exito = inventarioModel.actualizar_precio_venta(codigo, nuevoPrecio)
        if (exito) {
            mostrarNotificacion(`Precio actualizado: ${codigo} - Bs${nuevoPrecio.toFixed(2)}`, "success")
        }
        return exito
    }

    // Función para eliminar producto (CON MODEL BD)
    function eliminarProductoInventario(codigo) {
        console.log("🗑️ Eliminación en BD:", codigo)
        
        if (!inventarioModel) {
            console.log("❌ InventarioModel no disponible para eliminar")
            mostrarNotificacion("Error: Sistema de inventario no disponible", "error")
            return false
        }
        
        // TODO: Implementar eliminación en InventarioModel cuando esté disponible
        console.log("⚠️ Eliminación pendiente de implementar en InventarioModel")
        mostrarNotificacion("Función de eliminación en desarrollo", "warning")
        return false
    }

    // Función para obtener productos de una compra específica (BD)
    function obtenerProductosDeCompra(compraId) {
        if (!compraModel) {
            console.log("❌ CompraModel no disponible para obtener productos")
            return []
        }
        
        // Obtener detalle completo de la compra desde BD
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
        
        console.log("📦 Productos encontrados para compra BD", compraId, ":", productosCompra.length)
        return productosCompra
    }

    // Función auxiliar para obtener nombre del producto (CON MODEL BD)
    function obtenerNombreProducto(codigo) {
        if (!inventarioModel || !codigo) return "Producto no encontrado"
        
        var producto = inventarioModel.get_producto_by_codigo(codigo)
        return producto ? producto.Nombre : "Producto no encontrado"
    }
    
    // ===== FUNCIONES DE UTILIDADES =====
    
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
            default: prefijo = "📌"; break
        }
        console.log(`${prefijo} [${tipo.toUpperCase()}] ${mensaje}`)
        
        // TODO: Implementar notificación visual en UI
        // Por ahora solo log en consola
    }
    
    // Función de debug para inspeccionar datos BD
    function debugProductoData(codigo) {
        if (!inventarioModel) {
            console.log("❌ InventarioModel no disponible para debug")
            return
        }
        
        console.log("🔍 DEBUG BD - Buscando producto:", codigo)
        var producto = inventarioModel.get_producto_by_codigo(codigo)
        console.log("📦 Producto encontrado en BD:", JSON.stringify(producto, null, 2))
        
        if (producto && producto.id) {
            var lotes = inventarioModel.get_lotes_producto(producto.id)
            console.log("📋 Lotes del producto en BD:", JSON.stringify(lotes, null, 2))
        }
    }
    
    // Función para forzar actualización de datos desde BD
    function forzarActualizacionDatos() {
        if (!modelsReady) {
            console.log("⚠️ Models no están listos para actualización BD")
            return
        }
        
        console.log("🔄 Forzando actualización de todos los datos desde BD...")
        refrescarTodosLosDatos()
    }
    
    // Función centralizada para refrescar todos los datos
    function refrescarTodosLosDatos() {
        console.log("🔄 Refrescando todos los datos desde BD...")
        
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
        
        // Emitir signal de actualización
        datosActualizados()
    }
    
    // Señal para notificar cambios en los datos
    signal datosActualizados()
    
    // ===== INTERFAZ PRINCIPAL =====
    
    // Monitorear cambios en la subsección
    onCurrentSubSectionChanged: {
        console.log("Farmacia BD: Cambiando a subsección", currentSubSection)
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
                property var farmaciaData: farmaciaRoot  // Para compatibilidad
                
                function updateSource() {
                    var newSource = getSourceForSubsection(currentSubSection)
                    if (source.toString() !== newSource) {
                        source = newSource
                    }
                }
                
                function getSourceForSubsection(subsection) {
                    switch(subsection) {
                        case 0: return "VentasMain.qml"
                        case 1: return Qt.resolvedUrl("Productos.qml") // El nuevo Productos.qml conectado CON OVERLAY
                        case 2: return "ComprasMain.qml"
                        default: return "VentasMain.qml" 
                    }
                }
                
                Component.onCompleted: updateSource()
                
                onStatusChanged: {
                    if (status === Loader.Error) {
                        console.error("Error cargando el módulo BD:", source)
                        sourceComponent = errorComponent
                    } else if (status === Loader.Ready) {
                        console.log("Módulo BD cargado exitosamente:", source)
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
                            text: "Error al cargar el módulo BD"
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
            
            // Indicador de carga BD
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
                        text: dataLoading ? "Cargando datos BD..." : ("Cargando " + getCurrentSubSectionName() + "...")
                        color: textColor
                        font.pixelSize: 14
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }
    }
    
    // ===== FUNCIONES AUXILIARES =====
    
    function getCurrentSubSectionName() {
        const names = ["Gestión de Ventas", "Inventario de Productos", "Gestión de Compras"]
        return names[currentSubSection] || "Sección Desconocida"
    }
    
    function getCurrentSubSectionFile() {
        const files = ["VentasMain.qml", "Productos.qml", "ComprasMain.qml"]
        return files[currentSubSection] || "Archivo.qml"
    }
    
    function actualizarProductos() {
        if (inventarioModel && currentSubSection === 1) {
            inventarioModel.refresh_productos()
            console.log("🔄 Productos actualizados desde BD")
        }
    }
    
    function buscarProducto(codigo) {
        if (inventarioModel) {
            return inventarioModel.get_producto_by_codigo(codigo)
        }
        return null
    }
    
    function obtenerEstadisticasProductos() {
        if (inventarioModel) {
            var estadisticas = inventarioModel.get_estadisticas_inventario()
            return {
                total: estadisticas.total_productos || 0,
                con_stock: estadisticas.productos_con_stock || 0,
                stock_bajo: estadisticas.productos_bajo_stock || 0,
                sin_stock: estadisticas.productos_sin_stock || 0
            }
        }
        return { total: 0, con_stock: 0, stock_bajo: 0, sin_stock: 0 }
    }

    // ===== INICIALIZACIÓN =====
    
    Component.onCompleted: {
        console.log("=== MÓDULO DE FARMACIA INICIALIZADO (CONECTADO A BD) ===")
        console.log("🔄 Esperando conexión con Models BD...")
        console.log("Subsección inicial:", currentSubSection)
    }
    
    // Monitorear cuando los models estén listos
    onModelsReadyChanged: {
        if (modelsReady) {
            console.log("🚀 Models BD conectados:")
            console.log("📦 Productos disponibles BD:", productosUnicosModel.length)
            console.log("🏢 Proveedores BD:", proveedoresModel.length) 
            console.log("💰 Ventas del día BD:", ventasModel.length)
            
            // DEBUG ESPECÍFICO PARA COMPRAS BD
            if (compraModel) {
                console.log("🛒 CompraModel BD disponible:", !!compraModel)
                console.log("🛒 Compras recientes BD:", compraModel.compras_recientes ? compraModel.compras_recientes.length : "undefined")
                console.log("🛒 Total compras mes BD:", compraModel.total_compras_mes)
            }
            
            // Configurar alertas automáticas
            if (inventarioModel) {
                inventarioModel.configurar_stock_minimo(10)
                inventarioModel.verificar_vencimientos(90)
            }
            
            // Emitir actualización
            datosActualizados()
        }
    }    
    // Monitor de cambios en productos para debug BD
    onProductosUnicosModelChanged: {
        console.log("📊 ProductosUnicosModel BD actualizado - Total productos:", productosUnicosModel.length)
        if (productosUnicosModel.length > 0) {
            console.log("🔍 Ejemplo de producto BD:", JSON.stringify(productosUnicosModel[0]))
        }
    }
}