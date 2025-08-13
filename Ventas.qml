import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15

// Componente principal del módulo de Ventas de Farmacia
Item {
    id: ventasRoot
    
    // Referencia al módulo principal de farmacia
    property var farmaciaData: parent.farmaciaData
    
    // Propiedades de control de vistas
    property bool mostrarNuevaVenta: false
    property bool detalleVentaDialogOpen: false
    property string filtroActual: "Todos"
    property var ventaSeleccionada: null
    property bool debugMode: true

    // Propiedades de paginación para ventas
    property int itemsPerPageVentas: 10
    property int currentPageVentas: 0
    property int totalPagesVentas: 0

    // SISTEMA DE MÉTRICAS COHERENTE CON MAIN.QML
    readonly property real scaleFactor: Math.min(width / 1400, height / 900)
    readonly property real baseUnit: Math.max(8, height / 100) // Coherente con main.qml
    readonly property real fontBaseSize: Math.max(12, height / 70) // Coherente con main.qml
    
    // Tamaños de fuente escalables pero más conservadores
    readonly property real fontTiny: fontBaseSize * 0.75
    readonly property real fontSmall: fontBaseSize * 0.85
    readonly property real fontMedium: fontBaseSize
    readonly property real fontLarge: fontBaseSize * 1.15
    readonly property real fontXLarge: fontBaseSize * 1.4
    
    // Espaciados más conservadores
    readonly property real marginTiny: baseUnit * 0.5
    readonly property real marginSmall: baseUnit * 0.75
    readonly property real marginMedium: baseUnit
    readonly property real marginLarge: baseUnit * 1.5
    
    // Radios proporcionalmente más pequeños
    readonly property real radiusSmall: baseUnit * 0.5
    readonly property real radiusMedium: baseUnit * 0.75
    readonly property real radiusLarge: baseUnit
    
    // Alturas de controles más compactas
    readonly property real controlHeight: Math.max(40, baseUnit * 5)
    readonly property real buttonHeight: Math.max(36, baseUnit * 4.5)
    readonly property real headerHeight: Math.max(60, baseUnit * 7.5)

    // CONEXIÓN CON DATOS CENTRALES
    Connections {
        target: farmaciaData
        function onDatosActualizados() {
            console.log("🛒 Ventas: Datos centrales actualizados")
            actualizarPaginacionVentas()
            // Aquí podrías refrescar listas si es necesario
        }
    }

    // Colores del tema
    property color primaryColor: "#3498db"
    property color successColor: "#27ae60"
    property color warningColor: "#f39c12"
    property color dangerColor: "#e74c3c"
    property color blueColor: "#3498db"
    property color whiteColor: "#ffffff"
    property color textColor: "#2c3e50"
    property color darkGrayColor: "#7f8c8d"
    property color lightGrayColor: "#bdc3c7"

    // MODELO PARA PRODUCTOS EN NUEVA VENTA
    ListModel {
        id: productosVentaModel
    }

    // MODELO PARA DETALLES DE VENTA
    ListModel {
        id: productosDetalleModel
    }

    // MODELO PARA RESULTADOS DE BÚSQUEDA
    ListModel {
        id: resultadosBusquedaModel
    }

    // Base de datos de productos vendidos (para detalles)
    property var productosVendidosDatabase: ({
        "V001": [
            {codigo: "MED001", nombre: "Paracetamol 500mg", precio: 15.50, cantidad: 2, subtotal: 31.00},
            {codigo: "MED002", nombre: "Ibuprofeno 400mg", precio: 15.25, cantidad: 4, subtotal: 61.00}
        ],
        "V002": [
            {codigo: "MED003", nombre: "Loratadina 10mg", precio: 18.90, cantidad: 1, subtotal: 18.90},
            {codigo: "MED002", nombre: "Amoxicilina 500mg", precio: 23.10, cantidad: 1, subtotal: 23.10}
        ]
    })

    // AGREGAR ESTE MODELO NUEVO
    ListModel {
        id: ventasPaginadasModel
    }

    // CONEXIÓN CON DATOS CENTRALES: Escuchar cambios
    Connections {
        target: farmaciaData
        function onDatosActualizados() {
            console.log("💰 Ventas: Recibida señal de datos actualizados")
        }
    }

    // Función para calcular el total de la venta
    function calcularTotal() {
        var total = 0
        for (var i = 0; i < productosVentaModel.count; i++) {
            var producto = productosVentaModel.get(i)
            if (producto && producto.subtotal) {
                total += producto.subtotal
            }
        }
        return total
    }

    // Función para calcular unidades totales
    function calcularUnidadesTotales() {
        var unidades = 0
        for (var i = 0; i < productosVentaModel.count; i++) {
            var producto = productosVentaModel.get(i)
            if (producto && producto.cantidad) {
                unidades += producto.cantidad
            }
        }
        return unidades
    }

    // Función para calcular cantidad de productos diferentes
    function calcularProductos() {
        return productosVentaModel.count
    }

    // FUNCIÓN: Buscar productos usando datos centrales
    function buscarProductos(textoBusqueda) {
        console.log("🔍 Ventas: Buscando productos con:", textoBusqueda)
        
        // Limpiar resultados anteriores
        resultadosBusquedaModel.clear()
        
        if (!textoBusqueda || textoBusqueda.length < 2) {
            console.log("🔍 Texto muy corto, limpiando resultados")
            return
        }
        
        // Usar función central de farmaciaData
        if (farmaciaData && typeof farmaciaData.buscarProductosPorNombre === 'function') {
            try {
                var resultados = farmaciaData.buscarProductosPorNombre(textoBusqueda)
                console.log("🔍 Resultados desde centro:", resultados.length)
                
                for (var i = 0; i < resultados.length; i++) {
                    var producto = resultados[i]
                    resultadosBusquedaModel.append({
                        codigo: producto.codigo,
                        nombre: producto.nombre,
                        precio: producto.precioVenta || 0,
                        stock: producto.stockDisponible || 0
                    })
                }
                console.log("✅ Productos cargados en búsqueda:", resultadosBusquedaModel.count)
            } catch (e) {
                console.log("❌ Error en búsqueda central:", e.message)
            }
        } else {
            console.log("❌ farmaciaData.buscarProductosPorNombre no disponible")
        }
    }

    // Función auxiliar para datos de prueba
    function usarDatosDePrueba(texto) {
        var productosPrueba = [
            {codigo: "MED001", nombre: "Paracetamol 500mg", precio: 15.50, stock: 100},
            {codigo: "MED002", nombre: "Ibuprofeno 400mg", precio: 15.25, stock: 75},
            {codigo: "MED003", nombre: "Amoxicilina 500mg", precio: 23.10, stock: 50},
            {codigo: "MED004", nombre: "Loratadina 10mg", precio: 18.90, stock: 30},
            {codigo: "MED005", nombre: "Omeprazol 20mg", precio: 12.75, stock: 60}
        ]
        
        for (var i = 0; i < productosPrueba.length; i++) {
            var prod = productosPrueba[i]
            if (prod.nombre.toLowerCase().includes(texto.toLowerCase()) || 
                prod.codigo.toLowerCase().includes(texto.toLowerCase())) {
                resultadosBusquedaModel.append({
                    codigo: prod.codigo,
                    nombre: prod.nombre,
                    precio: prod.precio,
                    stock: prod.stock
                })
            }
        }
        console.log("✅ Usando datos de prueba, encontrados:", resultadosBusquedaModel.count)
    }

    // FUNCIÓN SIMPLIFICADA: Agregar producto a venta
    function agregarProductoAVenta(codigo, cantidad) {
        console.log("🛒 Agregando producto:", codigo, "Cantidad:", cantidad)
        
        if (!codigo || cantidad <= 0) {
            console.log("❌ Datos inválidos")
            return false
        }
        
        // Buscar el producto en los resultados de búsqueda
        var productoEncontrado = null
        for (var i = 0; i < resultadosBusquedaModel.count; i++) {
            var item = resultadosBusquedaModel.get(i)
            if (item.codigo === codigo) {
                productoEncontrado = item
                break
            }
        }
        
        if (!productoEncontrado) {
            console.log("❌ Producto no encontrado en resultados")
            return false
        }
        
        // Verificar stock
        if (cantidad > productoEncontrado.stock) {
            console.log("❌ Stock insuficiente")
            return false
        }
        
        // Verificar si ya existe en la venta
        var yaExiste = false
        var indiceExistente = -1
        
        for (var j = 0; j < productosVentaModel.count; j++) {
            var productoExistente = productosVentaModel.get(j)
            if (productoExistente.codigo === codigo) {
                yaExiste = true
                indiceExistente = j
                break
            }
        }
        
        if (yaExiste) {
            // Actualizar cantidad existente
            var productoActual = productosVentaModel.get(indiceExistente)
            var nuevaCantidad = productoActual.cantidad + cantidad
            var nuevoSubtotal = productoEncontrado.precio * nuevaCantidad
            
            if (nuevaCantidad > productoEncontrado.stock) {
                console.log("❌ Nueva cantidad excede stock")
                return false
            }
            
            productosVentaModel.setProperty(indiceExistente, "cantidad", nuevaCantidad)
            productosVentaModel.setProperty(indiceExistente, "subtotal", nuevoSubtotal)
            
            console.log("✅ Cantidad actualizada a:", nuevaCantidad)
        } else {
            // Agregar nuevo producto
            var subtotal = productoEncontrado.precio * cantidad
            
            productosVentaModel.append({
                codigo: productoEncontrado.codigo,
                nombre: productoEncontrado.nombre,
                precio: productoEncontrado.precio,
                cantidad: cantidad,
                subtotal: subtotal
            })
            
            console.log("✅ Producto agregado:", productoEncontrado.nombre)
        }
        
        // Limpiar campos usando la nueva función
        limpiarCamposBusqueda()
        
        return true
    }

    // FUNCIÓN: Completar venta usando sistema central
    function completarVenta() {
        console.log("🛒 === INICIANDO COMPLETAR VENTA ===")
        
        if (productosVentaModel.count === 0) {
            console.log("❌ No hay productos en la venta")
            return false
        }
        
        // Convertir productos a array
        var productosArray = []
        var totalCalculado = 0
        
        console.log("📦 Convirtiendo productos a array:")
        for (var i = 0; i < productosVentaModel.count; i++) {
            var prod = productosVentaModel.get(i)
            var productoVenta = {
                codigo: prod.codigo,
                nombre: prod.nombre,
                precio: prod.precio,
                cantidad: prod.cantidad,
                subtotal: prod.subtotal
            }
            productosArray.push(productoVenta)
            totalCalculado += prod.subtotal
            
            console.log("   " + (i+1) + ":", prod.codigo, "-", prod.nombre, "x" + prod.cantidad, "= $" + prod.subtotal)
        }
        
        console.log("💰 Total calculado:", totalCalculado)
        console.log("🛒 Array de productos creado, longitud:", productosArray.length)
        
        // Llamar al sistema central para realizar la venta
        var ventaId = null
        if (farmaciaData && typeof farmaciaData.realizarVenta === 'function') {
            try {
                console.log("🔄 Llamando a farmaciaData.realizarVenta...")
                ventaId = farmaciaData.realizarVenta("Dr. Admin", productosArray)
                console.log("✅ farmaciaData.realizarVenta retornó:", ventaId)
                
                if (ventaId) {
                    console.log("💾 Guardando productos en productosVendidosDatabase...")
                    console.log("   Clave:", ventaId)
                    console.log("   Productos a guardar:", productosArray.length)
                    
                    // GUARDAR productos para detalles
                    productosVendidosDatabase[ventaId] = productosArray
                    
                    console.log("✅ Productos guardados exitosamente")
                    console.log("🔍 Verificando guardado:")
                    console.log("   productosVendidosDatabase[" + ventaId + "]:", productosVendidosDatabase[ventaId])
                    console.log("   Longitud guardada:", productosVendidosDatabase[ventaId] ? productosVendidosDatabase[ventaId].length : "undefined")
                    
                    // Verificar que se agregó a la tabla de ventas
                    console.log("📊 Ventas en tabla después de agregar:", farmaciaData.ventasModel.count)
                    
                    // Limpiar y cerrar
                    productosVentaModel.clear()
                    limpiarCamposBusqueda()
                    mostrarNuevaVenta = false
                    actualizarPaginacionVentas()
                    
                    console.log("🎉 VENTA COMPLETADA EXITOSAMENTE")
                    return true
                } else {
                    console.log("❌ Error: farmaciaData.realizarVenta retornó null")
                    return false
                }
            } catch (e) {
                console.log("❌ Error en realizarVenta:", e.message)
                return false
            }
        } else {
            console.log("❌ farmaciaData.realizarVenta no disponible")
            return false
        }
    }

    // Función para limpiar campos de búsqueda
    function limpiarCamposBusqueda() {
        busquedaField.text = ""
        cantidadField.text = ""
        resultadosBusquedaModel.clear()
        
        // Dar foco de vuelta al campo de búsqueda
        Qt.callLater(function() {
            busquedaField.focus = true
        })
    }

    // Función auxiliar para agregar producto desde input MEJORADA
    function agregarProductoDesdeInput() {
        var texto = busquedaField.text.trim()
        var cantidadTexto = cantidadField.text.trim()
        var cantidad = parseInt(cantidadTexto) || 1
        
        if (!texto) {
            console.log("❌ Campo de búsqueda vacío")
            // Dar foco al campo de búsqueda
            busquedaField.focus = true
            return
        }
        
        // Validar cantidad
        if (cantidad <= 0) {
            cantidad = 1
        }
        
        console.log("🛒 Intentando agregar:", texto, "Cantidad:", cantidad)
        
        // Si hay resultados de búsqueda, usar el primero
        if (resultadosBusquedaModel.count > 0) {
            var primerProducto = resultadosBusquedaModel.get(0)
            if (agregarProductoAVenta(primerProducto.codigo, cantidad)) {
                // Limpiar campos después de agregar exitosamente
                limpiarCamposBusqueda()
            }
        } else {
            // Intentar agregar directamente por código
            console.log("🔍 Intentando agregar directamente:", texto)
            // Buscar primero
            buscarProductos(texto)
            // Esperar un momento para que se complete la búsqueda
            Qt.callLater(function() {
                if (resultadosBusquedaModel.count > 0) {
                    var producto = resultadosBusquedaModel.get(0)
                    if (agregarProductoAVenta(producto.codigo, cantidad)) {
                        limpiarCamposBusqueda()
                    }
                } else {
                    console.log("❌ Producto no encontrado:", texto)
                    // Mantener foco en búsqueda para nuevo intento
                    busquedaField.focus = true
                    busquedaField.selectAll()
                }
            })
        }
    }

    // FUNCIÓN CORREGIDA para Ventas.qml
    function actualizarPaginacionVentas() {
        if (!farmaciaData || !farmaciaData.ventasModel) return
        
        var totalItems = farmaciaData.ventasModel.count
        totalPagesVentas = Math.ceil(totalItems / itemsPerPageVentas)
        
        // Ajustar página actual si es necesario
        if (currentPageVentas >= totalPagesVentas && totalPagesVentas > 0) {
            currentPageVentas = totalPagesVentas - 1
        }
        if (currentPageVentas < 0) {
            currentPageVentas = 0
        }
        
        // Limpiar modelo paginado
        ventasPaginadasModel.clear()
        
        // Calcular índices
        var startIndex = currentPageVentas * itemsPerPageVentas
        var endIndex = Math.min(startIndex + itemsPerPageVentas, totalItems)
        
        // Agregar elementos de la página actual
        for (var i = startIndex; i < endIndex; i++) {
            var venta = farmaciaData.ventasModel.get(i)
            ventasPaginadasModel.append(venta)
        }
        
        console.log("📄 Ventas: Página", currentPageVentas + 1, "de", totalPagesVentas,
                    "- Mostrando", ventasPaginadasModel.count, "de", totalItems)
    }

    // CONTENEDOR PRINCIPAL CON DOS VISTAS
    Item {
        anchors.fill: parent
        
        // =============================================
        // VISTA PRINCIPAL DE VENTAS
        // =============================================
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: marginMedium
            spacing: marginMedium
            visible: !mostrarNuevaVenta
            
            // Header del módulo con título y botones de acción
            RowLayout {
                Layout.fillWidth: true
                spacing: marginMedium
                
                // Información del módulo
                RowLayout {
                    spacing: marginSmall
                    
                    Label {
                        text: "🛒"
                        font.pixelSize: fontXLarge
                        color: primaryColor
                    }
                    
                    ColumnLayout {
                        spacing: marginTiny
                        
                        Label {
                            text: "Módulo de Farmacia"
                            font.pixelSize: fontLarge
                            font.bold: true
                            color: textColor
                        }
                        
                        Label {
                            text: "Gestión de Ventas"
                            font.pixelSize: fontMedium
                            color: darkGrayColor
                        }
                    }
                }            
                Item { Layout.fillWidth: true }
                
                // Información en tiempo real
                Rectangle {
                    Layout.preferredWidth: 150
                    Layout.preferredHeight: 60
                    color: "#E8F5E8"
                    radius: radiusSmall
                    border.color: successColor
                    border.width: 1
                    
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: marginTiny
                        
                        Label {
                            text: "Productos Disponibles:"
                            font.pixelSize: fontTiny
                            color: darkGrayColor
                            Layout.alignment: Qt.AlignHCenter
                        }
                        
                        Label {
                            text: farmaciaData && farmaciaData.obtenerProductosUnicos ? 
                                  farmaciaData.obtenerProductosUnicos().length.toString() : "5"
                            font.pixelSize: fontLarge
                            font.bold: true
                            color: successColor
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
                
                // Botones de acción principal
                RowLayout {
                    spacing: marginSmall
                    
                    Button {
                        id: nuevaVentaButton
                        text: "➕Nueva Venta"
                        
                        background: Rectangle {
                            color: parent.pressed ? Qt.darker(successColor, 1.2) : successColor
                            radius: radiusMedium
                            
                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }
                        }
                        
                        contentItem: Label {
                            text: parent.text
                            color: whiteColor
                            font.bold: true
                            font.pixelSize: fontMedium
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: {
                            console.log("🛒 Abriendo Nueva Venta")
                            mostrarNuevaVenta = true
                            productosVentaModel.clear()
                            limpiarCamposBusqueda()
                            
                            Qt.callLater(function() {
                                if (busquedaField) {
                                    busquedaField.focus = true
                                }
                            })
                        }
                    }
                }
            }

            // Filtros de período
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: marginSmall
                spacing: marginSmall
                
                Button {
                    id: filtroTodos
                    text: "Todos"
                    
                    property bool isSelected: filtroActual === "Todos"
                    
                    background: Rectangle {
                        color: parent.isSelected ? "#3498db" : (parent.pressed ? "#e3f2fd" : "transparent")
                        border.color: parent.isSelected ? "#3498db" : "#bdc3c7"
                        border.width: 1
                        radius: 20
                    }
                    
                    contentItem: RowLayout {
                        spacing: marginTiny
                        
                        Label {
                            text: "📊"
                            font.pixelSize: fontSmall
                        }
                        
                        Label {
                            text: parent.parent.text
                            color: parent.parent.isSelected ? whiteColor : textColor
                            font.bold: parent.parent.isSelected
                            font.pixelSize: fontSmall
                        }
                        
                        Rectangle {
                            visible: parent.parent.isSelected
                            width: 20
                            height: 16
                            color: whiteColor
                            radius: 8
                            
                            Label {
                                anchors.centerIn: parent
                                text: farmaciaData ? farmaciaData.ventasModel.count.toString() : "0"
                                color: "#3498db"
                                font.bold: true
                                font.pixelSize: fontTiny
                            }
                        }
                    }
                    
                    onClicked: {
                        filtroActual = "Todos"
                    }
                }

                Item { Layout.fillWidth: true }
            }

            // Tabla de ventas 
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#FFFFFF"
                border.color: "#D5DBDB"
                border.width: 1
                radius: radiusMedium
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 0
                    spacing: 0
                    
                    // Header de la tabla
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: controlHeight
                        color: "#F8F9FA"
                        
                        RowLayout {
                            anchors.fill: parent
                            spacing: 0
                            
                            Rectangle {
                                Layout.preferredWidth: 120
                                Layout.fillHeight: true
                                color: "#F8F9FA"
                                border.color: "#D5DBDB"
                                border.width: 1
                                
                                Label {
                                    anchors.centerIn: parent
                                    text: "ID VENTA"
                                    color: "#2C3E50"
                                    font.bold: true
                                    font.pixelSize: fontSmall
                                }
                            }
                            
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 200
                                Layout.fillHeight: true
                                color: "#F8F9FA"
                                border.color: "#D5DBDB"
                                border.width: 1
                                
                                Label {
                                    anchors.left: parent.left
                                    anchors.leftMargin: marginSmall
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "USUARIO"
                                    color: "#2C3E50"
                                    font.bold: true
                                    font.pixelSize: fontSmall
                                }
                            }
                            
                            Rectangle {
                                Layout.preferredWidth: 120
                                Layout.fillHeight: true
                                color: "#F8F9FA"
                                border.color: "#D5DBDB"
                                border.width: 1
                                
                                Label {
                                    anchors.centerIn: parent
                                    text: "TOTAL"
                                    color: "#2C3E50"
                                    font.bold: true
                                    font.pixelSize: fontSmall
                                }
                            }
                            
                            Rectangle {
                                Layout.preferredWidth: 140
                                Layout.fillHeight: true
                                color: "#F8F9FA"
                                border.color: "#D5DBDB"
                                border.width: 1
                                
                                Label {
                                    anchors.centerIn: parent
                                    text: "FECHA"
                                    color: "#2C3E50"
                                    font.bold: true
                                    font.pixelSize: fontSmall
                                }
                            }
                            
                            Rectangle {
                                Layout.preferredWidth: 120
                                Layout.fillHeight: true
                                color: "#F8F9FA"
                                border.color: "#D5DBDB"
                                border.width: 1
                                
                                Label {
                                    anchors.centerIn: parent
                                    text: "HORA"
                                    color: "#2C3E50"
                                    font.bold: true
                                    font.pixelSize: fontSmall
                                }
                            }
                            
                            Rectangle {
                                Layout.preferredWidth: 100
                                Layout.fillHeight: true
                                color: "#F8F9FA"
                                border.color: "#D5DBDB"
                                border.width: 1
                                
                                Label {
                                    anchors.centerIn: parent
                                    text: "ACCIÓN"
                                    color: "#2C3E50"
                                    font.bold: true
                                    font.pixelSize: fontSmall
                                }
                            }
                        }
                    }
                    
                    // Contenido de la tabla
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        
                        ListView {
                            id: ventasTable
                            anchors.fill: parent
                            model: ventasPaginadasModel
                            
                            delegate: Item {
                                width: ventasTable.width
                                height: 60
                                
                                Rectangle {
                                    anchors.fill: parent
                                    color: ventasTable.currentIndex === index ? "#E3F2FD" : "transparent"
                                    opacity: 0.3
                                }
                                
                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 0
                                    
                                    Rectangle {
                                        Layout.preferredWidth: 120
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#D5DBDB"
                                        border.width: 1
                                        
                                        Label {
                                            anchors.centerIn: parent
                                            text: model.idVenta
                                            color: "#3498DB"
                                            font.bold: true
                                            font.pixelSize: fontMedium
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 200
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#D5DBDB"
                                        border.width: 1
                                        
                                        ColumnLayout {
                                            anchors.left: parent.left
                                            anchors.leftMargin: marginSmall
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 2
                                            
                                            Label {
                                                text: model.usuario
                                                color: "#2C3E50"
                                                font.bold: true
                                                font.pixelSize: fontMedium
                                                elide: Text.ElideRight
                                                Layout.maximumWidth: parent.parent.width - 24
                                            }
                                            
                                            RowLayout {
                                                spacing: 6
                                                
                                                Label {
                                                    text: "👤"
                                                    font.pixelSize: fontTiny
                                                }
                                                
                                                Label {
                                                    text: model.tipoUsuario
                                                    color: "#7F8C8D"
                                                    font.pixelSize: fontSmall
                                                    elide: Text.ElideRight
                                                    Layout.maximumWidth: 150
                                                }
                                            }
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: 120
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#D5DBDB"
                                        border.width: 1
                                        
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 80
                                            height: 28
                                            color: "#27AE60"
                                            radius: 14
                                            
                                            Label {
                                                anchors.centerIn: parent
                                                text: "$" + model.total.toFixed(2)
                                                color: "#FFFFFF"
                                                font.bold: true
                                                font.pixelSize: fontSmall
                                            }
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: 140
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#D5DBDB"
                                        border.width: 1
                                        
                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: 6
                                            
                                            Label {
                                                text: "📅"
                                                font.pixelSize: fontSmall
                                                color: "#3498DB"
                                            }
                                            
                                            Label {
                                                text: model.fecha
                                                color: "#2C3E50"
                                                font.pixelSize: fontSmall
                                                font.bold: true
                                            }
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: 120
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#D5DBDB"
                                        border.width: 1
                                        
                                        Label {
                                            anchors.centerIn: parent
                                            text: model.hora
                                            color: "#7F8C8D"
                                            font.pixelSize: fontSmall
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: 100
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#D5DBDB"
                                        border.width: 1
                                        
                                        Button {
                                            anchors.centerIn: parent
                                            width: 70
                                            height: 30
                                            text: "Ver"
                                            
                                            background: Rectangle {
                                                color: parent.pressed ? Qt.darker(blueColor, 1.2) : blueColor
                                                radius: 15
                                            }
                                            
                                            contentItem: Label {
                                                text: parent.text
                                                color: whiteColor
                                                font.bold: true
                                                font.pixelSize: fontSmall
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            
                                            onClicked: {
                                                console.log("==========================================")
                                                console.log("🔥 BOTÓN VER CLICKEADO!!!")
                                                console.log("📍 Index recibido:", index)
                                                console.log("📊 farmaciaData existe:", !!farmaciaData)
                                                console.log("📊 farmaciaData.ventasModel existe:", !!(farmaciaData && farmaciaData.ventasModel))
                                                console.log("📊 Total ventas:", farmaciaData ? farmaciaData.ventasModel.count : "N/A")
                                                console.log("📋 Index válido:", index >= 0 && index < (farmaciaData ? farmaciaData.ventasModel.count : 0))
                                                
                                                if (farmaciaData && farmaciaData.ventasModel && farmaciaData.ventasModel.count > index) {
                                                    var venta = farmaciaData.ventasModel.get(index)
                                                    console.log("📋 Datos de la venta:")
                                                    console.log("   - ID Venta:", venta.idVenta)
                                                    console.log("   - Usuario:", venta.usuario)
                                                    console.log("   - Total:", venta.total)
                                                    console.log("   - Fecha:", venta.fecha)
                                                    console.log("   - Hora:", venta.hora)
                                                } else {
                                                    console.log("❌ No se puede obtener datos de la venta")
                                                }
                                                
                                                console.log("🚀 Llamando a mostrarDetalleVenta...")
                                                mostrarDetalleVenta(index)
                                                console.log("✅ mostrarDetalleVenta llamada completada")
                                                console.log("🔍 Estado del modal después del llamado:")
                                                console.log("   - detalleVentaDialogOpen:", detalleVentaDialogOpen)
                                                console.log("==========================================")
                                            }
                                        }
                                    }
                                }
                                
                                MouseArea {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    anchors.right: parent.right
                                    anchors.rightMargin: 100  // Dejar espacio para el botón Ver
                                    
                                    onClicked: {
                                        console.log("🖱️ Click en fila, seleccionando index:", index)
                                        ventasTable.currentIndex = index
                                    }
                                }
                            }
                            
                            // Estado vacío
                            Item {
                                anchors.centerIn: parent
                                visible: (farmaciaData ? farmaciaData.ventasModel.count : 0) === 0
                                width: 300
                                height: 200
                                
                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: marginMedium
                                    
                                    Label {
                                        text: "🛒"
                                        font.pixelSize: 48
                                        color: lightGrayColor
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                    
                                    Label {
                                        text: "No hay ventas registradas"
                                        color: darkGrayColor
                                        font.pixelSize: fontMedium
                                        font.bold: true
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                    
                                    Label {
                                        text: "Las ventas aparecerán aquí cuando se completen"
                                        color: darkGrayColor
                                        font.pixelSize: fontSmall
                                        Layout.alignment: Qt.AlignHCenter
                                        wrapMode: Text.WordWrap
                                        Layout.maximumWidth: 250
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }
                            }
                        }
                    }

                    // Control de Paginación - Centrado con indicador
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60
                        color: "#F8F9FA"
                        border.color: "#D5DBDB"
                        border.width: 1
                        
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 20
                            
                            // Botón Anterior con flecha
                            Button {
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 36
                                text: "← Anterior"
                                enabled: currentPageVentas > 0
                                
                                background: Rectangle {
                                    color: parent.enabled ? 
                                        (parent.pressed ? Qt.darker("#10B981", 1.1) : "#10B981") :   // ✅ VERDE
                                        "#E5E7EB"
                                    radius: 18
                                    
                                    Behavior on color {
                                        ColorAnimation { duration: 150 }
                                    }
                                }
                                
                                contentItem: Label {
                                    text: parent.text
                                    color: parent.enabled ? "#FFFFFF" : "#9CA3AF"   // ✅ BLANCO cuando activo
                                    font.bold: true
                                    font.pixelSize: fontMedium
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                
                                onClicked: {
                                    if (currentPageVentas > 0) {
                                        currentPageVentas--
                                        actualizarPaginacionVentas()
                    
                                    }
                                }
                            }
                            

                            // 1. Indicador de página CORREGIDO:
                            Label {
                                text: "Página " + (currentPageVentas + 1) + " de " + Math.max(1, totalPagesVentas)
                                color: "#374151"
                                font.pixelSize: fontMedium
                                font.weight: Font.Medium
                            }

                            // 2. Botón Siguiente CORREGIDO:
                            Button {
                                Layout.preferredWidth: 110
                                Layout.preferredHeight: 36
                                text: "Siguiente →"
                                enabled: currentPageVentas < totalPagesVentas - 1  // ✅ CORREGIDO
                                
                                background: Rectangle {
                                    color: parent.enabled ? 
                                        (parent.pressed ? Qt.darker("#10B981", 1.1) : "#10B981") : 
                                        "#E5E7EB"
                                    radius: 18
                                    
                                    Behavior on color {
                                        ColorAnimation { duration: 150 }
                                    }
                                }
                                
                                contentItem: Label {
                                    text: parent.text
                                    color: parent.enabled ? "#FFFFFF" : "#9CA3AF"
                                    font.bold: true
                                    font.pixelSize: fontMedium
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                
                                onClicked: {
                                    if (currentPageVentas < totalPagesVentas - 1) {  // ✅ CORREGIDO
                                        currentPageVentas++
                                        actualizarPaginacionVentas()  // ✅ CORREGIDO
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // =============================================
        // VISTA DE NUEVA VENTA MEJORADA
        // =============================================
        Rectangle {
            anchors.fill: parent
            color: "#f8f9fa"
            visible: mostrarNuevaVenta
            z: 100
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: marginMedium
                spacing: marginMedium
                
                // Header con botón de regreso
                RowLayout {
                    Layout.fillWidth: true
                    spacing: marginSmall

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 120
                        color: "#ffffff"
                        radius: radiusLarge
                        border.color: "#e9ecef"
                        border.width: 1
                        
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 12
                            
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 20
                                
                                // Botón de regreso
                                Button {
                                    width: 40
                                    height: 40
                                    
                                    background: Rectangle {
                                        color: parent.pressed ? Qt.darker(blueColor, 1.2) : blueColor
                                        radius: 20
                                    }
                                    
                                    contentItem: Label {
                                        text: "←"
                                        color: whiteColor
                                        font.bold: true
                                        font.pixelSize: fontLarge
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    
                                    onClicked: {
                                        mostrarNuevaVenta = false
                                        productosVentaModel.clear()
                                        limpiarCamposBusqueda()
                                    }
                                }
                                
                                RowLayout {
                                    spacing: 12
                                    
                                    Rectangle {
                                        width: 32
                                        height: 32
                                        color: blueColor
                                        radius: 6
                                        
                                        Label {
                                            anchors.centerIn: parent
                                            text: "🛒"
                                            font.pixelSize: fontMedium
                                            color: whiteColor
                                        }
                                    }
                                    
                                    Label {
                                        text: "Nueva Venta"
                                        font.pixelSize: fontLarge
                                        font.bold: true
                                        color: textColor
                                    }
                                }
                                
                                Item { Layout.fillWidth: true }
                            }
                            
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 20
                                
                                Label {
                                    text: "Usuario: Dr. Admin"
                                    color: textColor
                                    font.pixelSize: fontMedium
                                }
                                
                                Label {
                                    text: {
                                        var fechaActual = new Date()
                                        var dia = fechaActual.getDate().toString().padStart(2, '0')
                                        var mes = (fechaActual.getMonth() + 1).toString().padStart(2, '0')
                                        var año = fechaActual.getFullYear()
                                        var hora = fechaActual.getHours().toString().padStart(2, '0')
                                        var minutos = fechaActual.getMinutes().toString().padStart(2, '0')
                                        return "Fecha: " + dia + "/" + mes + "/" + año + " " + hora + ":" + minutos
                                    }
                                    color: textColor
                                    font.pixelSize: fontMedium
                                }
                                
                                Item { Layout.fillWidth: true }
                                
                                Label {
                                    text: "No. Venta: V" + String((farmaciaData ? farmaciaData.ventasModel.count : 0) + 1).padStart(3, '0')
                                    color: blueColor
                                    font.pixelSize: fontMedium
                                    font.bold: true
                                }
                            }
                        }
                    }
                }
                
                // SECCIÓN DE BÚSQUEDA DE PRODUCTOS - VERSIÓN CORREGIDA
                Rectangle {
                    id: contenedorBusqueda
                    Layout.fillWidth: true
                    Layout.preferredHeight: 120
                    Layout.maximumWidth: 1200
                    Layout.alignment: Qt.AlignHCenter
                    
                    color: "#ffffff"
                    radius: radiusLarge
                    border.color: "#e1e8ed"
                    border.width: 1
                    
                    // Sombra sutil
                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: 2
                        anchors.leftMargin: 2
                        color: "#00000008"
                        radius: parent.radius
                        z: -1
                    }
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 16
                        
                        // CABECERA
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            
                            Label {
                                text: "🔍"
                                font.pixelSize: fontMedium
                                color: "#2c3e50"
                            }
                            
                            Label {
                                text: "BUSCAR PRODUCTO"
                                font.bold: true
                                font.pixelSize: fontMedium
                                color: "#2c3e50"
                            }
                            
                            Item { Layout.fillWidth: true }
                        }
                        
                        // CONTROLES - TODOS EN UNA FILA CON ALTURA FIJA
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 50  // ALTURA FIJA PARA TODOS
                            color: "transparent"
                            
                            RowLayout {
                                anchors.fill: parent
                                spacing: 16
                                
                                // CAMPO DE BÚSQUEDA
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true  // USA TODA LA ALTURA DISPONIBLE
                                    color: "#ffffff"  // FONDO BLANCO SÓLIDO
                                    border.color: "#3498db"
                                    border.width: 2
                                    radius: 8
                                    
                                    TextInput {
                                        id: busquedaField
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        
                                        font.pixelSize: fontMedium
                                        color: "#000000"  // NEGRO SÓLIDO
                                        verticalAlignment: Text.AlignVCenter
                                        
                                        clip: true
                                        selectByMouse: true
                                        
                                        onTextChanged: {
                                            if (text.length >= 2) {
                                                ventasRoot.buscarProductos(text)
                                            } else {
                                                resultadosBusquedaModel.clear()
                                            }
                                        }
                                        
                                        Keys.onReturnPressed: {
                                            ventasRoot.agregarProductoDesdeInput()
                                        }
                                        
                                        Keys.onEscapePressed: {
                                            text = ""
                                            resultadosBusquedaModel.clear()
                                        }
                                    }
                                    
                                    // PLACEHOLDER MANUAL
                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Buscar por nombre o código..."
                                        color: "#999999"
                                        font.pixelSize: fontMedium
                                        visible: busquedaField.text.length === 0
                                    }
                                }
                                
                                // ETIQUETA CANTIDAD
                                Text {
                                    text: "Cantidad:"
                                    font.pixelSize: fontMedium
                                    font.bold: true
                                    color: "#000000"
                                    Layout.alignment: Qt.AlignVCenter
                                }
                                
                                // CAMPO CANTIDAD
                                Rectangle {
                                    Layout.preferredWidth: 70
                                    Layout.fillHeight: true  // USA TODA LA ALTURA DISPONIBLE
                                    color: "#ffffff"  // FONDO BLANCO SÓLIDO
                                    border.color: "#3498db"
                                    border.width: 2
                                    radius: 8
                                    
                                    TextInput {
                                        id: cantidadField
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        
                                        text: "1"
                                        font.pixelSize: fontMedium
                                        font.bold: true
                                        color: "#000000"  // NEGRO SÓLIDO
                                        
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        
                                        clip: true
                                        selectByMouse: true
                                        validator: IntValidator { bottom: 1; top: 999 }
                                        
                                        Keys.onReturnPressed: {
                                            ventasRoot.agregarProductoDesdeInput()
                                        }
                                        
                                        onActiveFocusChanged: {
                                            if (activeFocus) {
                                                selectAll()
                                            }
                                        }
                                    }
                                }
                                
                                // BOTÓN AGREGAR
                                Rectangle {
                                    Layout.preferredWidth: 120
                                    Layout.fillHeight: true  // USA TODA LA ALTURA DISPONIBLE
                                    color: botonMouseArea.pressed ? "#218838" : "#28a745"
                                    radius: 8
                                    
                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        
                                        Text {
                                            text: "+"
                                            color: "#ffffff"
                                            font.bold: true
                                            font.pixelSize: fontMedium
                                        }
                                        
                                        Text {
                                            text: "Agregar"
                                            color: "#ffffff"
                                            font.bold: true
                                            font.pixelSize: fontMedium
                                        }
                                    }
                                    
                                    MouseArea {
                                        id: botonMouseArea
                                        anchors.fill: parent
                                        
                                        onClicked: {
                                            ventasRoot.agregarProductoDesdeInput()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Lista de resultados de búsqueda
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(120, resultadosBusquedaModel.count * 30)
                    color: whiteColor
                    border.color: "#dee2e6"
                    border.width: 1
                    radius: radiusMedium
                    visible: resultadosBusquedaModel.count > 0
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4
                        
                        Label {
                            text: "📦 " + resultadosBusquedaModel.count + " productos encontrados"
                            font.pixelSize: fontSmall
                            color: "#495057"
                            font.bold: true
                        }
                        
                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            model: resultadosBusquedaModel
                            clip: true
                            
                            delegate: Rectangle {
                                width: ListView.view.width
                                height: 28
                                color: mouseArea.containsMouse ? "#E3F2FD" : "transparent"
                                
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 12
                                    
                                    Label {
                                        text: model.codigo
                                        color: blueColor
                                        font.bold: true
                                        font.pixelSize: fontSmall
                                        Layout.preferredWidth: 70
                                    }
                                    
                                    Label {
                                        text: model.nombre
                                        color: textColor
                                        font.pixelSize: fontSmall
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                    
                                    Label {
                                        text: "$" + model.precio.toFixed(2)
                                        color: successColor
                                        font.bold: true
                                        font.pixelSize: fontSmall
                                        Layout.preferredWidth: 60
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: 35
                                        Layout.preferredHeight: 16
                                        color: model.stock > 10 ? successColor : (model.stock > 0 ? warningColor : dangerColor)
                                        radius: 8
                                        
                                        Label {
                                            anchors.centerIn: parent
                                            text: model.stock.toString()
                                            color: whiteColor
                                            font.bold: true
                                            font.pixelSize: fontTiny
                                        }
                                    }
                                }
                                
                                MouseArea {
                                    id: mouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    
                                    onClicked: {
                                        var cantidad = parseInt(cantidadField.text) || 1
                                        agregarProductoAVenta(model.codigo, cantidad)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // TABLA DE PRODUCTOS EN LA VENTA - VERSIÓN CORREGIDA
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 8
                    
                    // TÍTULO DE LA TABLA
                    Label {
                        text: "🛒 Productos en la venta:"
                        font.bold: true
                        color: textColor
                        font.pixelSize: fontMedium
                    }
                    
                    // CONTENEDOR DE LA TABLA CON BORDES
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 200
                        color: whiteColor
                        border.color: "#dee2e6"
                        border.width: 1
                        radius: 6
                        
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 0  // Sin márgenes para que los bordes lleguen al borde
                            spacing: 0
                            
                            // HEADER DE TABLA CON BORDES COMPLETOS
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 45
                                color: "#f8f9fa"
                                
                                // Borde inferior del header
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: 1
                                    color: "#dee2e6"
                                }
                                
                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 0  // Sin spacing para que los bordes se vean bien
                                    
                                    // COLUMNA #
                                    Rectangle {
                                        Layout.preferredWidth: 50
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#dee2e6"
                                        border.width: 1
                                        
                                        Label {
                                            anchors.centerIn: parent
                                            text: "#"
                                            font.bold: true
                                            color: "#495057"
                                            font.pixelSize: fontSmall
                                        }
                                    }
                                    
                                    // COLUMNA CÓDIGO
                                    Rectangle {
                                        Layout.preferredWidth: 100
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#dee2e6"
                                        border.width: 1
                                        
                                        Label {
                                            anchors.centerIn: parent
                                            text: "CÓDIGO"
                                            font.bold: true
                                            color: "#495057"
                                            font.pixelSize: fontSmall
                                        }
                                    }
                                    
                                    // COLUMNA NOMBRE
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#dee2e6"
                                        border.width: 1
                                        
                                        Label {
                                            anchors.centerIn: parent
                                            text: "NOMBRE"
                                            font.bold: true
                                            color: "#495057"
                                            font.pixelSize: fontSmall
                                        }
                                    }
                                    
                                    // COLUMNA PRECIO
                                    Rectangle {
                                        Layout.preferredWidth: 80
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#dee2e6"
                                        border.width: 1
                                        
                                        Label {
                                            anchors.centerIn: parent
                                            text: "PRECIO"
                                            font.bold: true
                                            color: "#495057"
                                            font.pixelSize: fontSmall
                                        }
                                    }
                                    
                                    // COLUMNA CANTIDAD
                                    Rectangle {
                                        Layout.preferredWidth: 70
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#dee2e6"
                                        border.width: 1
                                        
                                        Label {
                                            anchors.centerIn: parent
                                            text: "CANT."
                                            font.bold: true
                                            color: "#495057"
                                            font.pixelSize: fontSmall
                                        }
                                    }
                                    
                                    // COLUMNA SUBTOTAL
                                    Rectangle {
                                        Layout.preferredWidth: 90
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#dee2e6"
                                        border.width: 1
                                        
                                        Label {
                                            anchors.centerIn: parent
                                            text: "SUBTOTAL"
                                            font.bold: true
                                            color: "#495057"
                                            font.pixelSize: fontSmall
                                        }
                                    }
                                    
                                    // COLUMNA ACCIÓN
                                    Rectangle {
                                        Layout.preferredWidth: 80
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#dee2e6"
                                        border.width: 1
                                        
                                        Label {
                                            anchors.centerIn: parent
                                            text: "ACCIÓN"
                                            font.bold: true
                                            color: "#495057"
                                            font.pixelSize: fontSmall
                                        }
                                    }
                                }
                            }
                            
                            // LISTA DE PRODUCTOS CON BORDES COMPLETOS
                            ScrollView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                
                                ListView {
                                    id: productosListView
                                    anchors.fill: parent
                                    model: productosVentaModel
                                    
                                    delegate: Rectangle {
                                        width: parent ? parent.width : 0
                                        height: 50
                                        color: index % 2 === 0 ? "#ffffff" : "#f8f9fa"
                                        
                                        // Borde inferior de cada fila
                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            width: parent.width
                                            height: 1
                                            color: "#dee2e6"
                                        }
                                        
                                        RowLayout {
                                            anchors.fill: parent
                                            spacing: 0  // Sin spacing para bordes perfectos
                                            
                                            // CELDA #
                                            Rectangle {
                                                Layout.preferredWidth: 50
                                                Layout.fillHeight: true
                                                color: "transparent"
                                                border.color: "#dee2e6"
                                                border.width: 1
                                                
                                                Label {
                                                    anchors.right: parent.right
                                                    anchors.rightMargin: 8
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: (index + 1).toString()
                                                    color: "#6c757d"
                                                    font.pixelSize: fontSmall
                                                    // ALINEADO A LA DERECHA
                                                }
                                            }
                                            
                                            // CELDA CÓDIGO
                                            Rectangle {
                                                Layout.preferredWidth: 100
                                                Layout.fillHeight: true
                                                color: "transparent"
                                                border.color: "#dee2e6"
                                                border.width: 1
                                                
                                                Label {
                                                    anchors.left: parent.left
                                                    anchors.leftMargin: 8
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: model.codigo || ""
                                                    color: "#007bff"  // AZUL
                                                    font.bold: true
                                                    font.pixelSize: fontSmall
                                                    // ALINEADO A LA IZQUIERDA
                                                }
                                            }
                                            
                                            // CELDA NOMBRE
                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.fillHeight: true
                                                color: "transparent"
                                                border.color: "#dee2e6"
                                                border.width: 1
                                                
                                                Label {
                                                    anchors.left: parent.left
                                                    anchors.leftMargin: 8
                                                    anchors.right: parent.right
                                                    anchors.rightMargin: 8
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: model.nombre || ""
                                                    color: textColor
                                                    font.pixelSize: fontSmall
                                                    elide: Text.ElideRight
                                                    // ALINEADO A LA IZQUIERDA
                                                }
                                            }
                                            
                                            // CELDA PRECIO
                                            Rectangle {
                                                Layout.preferredWidth: 80
                                                Layout.fillHeight: true
                                                color: "transparent"
                                                border.color: "#dee2e6"
                                                border.width: 1
                                                
                                                Label {
                                                    anchors.right: parent.right
                                                    anchors.rightMargin: 8
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: model.precio ? "$" + model.precio.toFixed(2) : ""
                                                    color: "#28a745"  // VERDE
                                                    font.bold: true
                                                    font.pixelSize: fontSmall
                                                    // ALINEADO A LA DERECHA
                                                }
                                            }
                                            
                                            // CELDA CANTIDAD
                                            Rectangle {
                                                Layout.preferredWidth: 70
                                                Layout.fillHeight: true
                                                color: "transparent"
                                                border.color: "#dee2e6"
                                                border.width: 1
                                                
                                                Label {
                                                    anchors.right: parent.right
                                                    anchors.rightMargin: 8
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: model.cantidad ? model.cantidad.toString() : ""
                                                    color: "#fd7e14"  // NARANJA
                                                    font.bold: true
                                                    font.pixelSize: fontSmall
                                                    // ALINEADO A LA DERECHA
                                                }
                                            }
                                            
                                            // CELDA SUBTOTAL
                                            Rectangle {
                                                Layout.preferredWidth: 90
                                                Layout.fillHeight: true
                                                color: "transparent"
                                                border.color: "#dee2e6"
                                                border.width: 1
                                                
                                                Label {
                                                    anchors.right: parent.right
                                                    anchors.rightMargin: 8
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: model.subtotal ? "$" + model.subtotal.toFixed(2) : ""
                                                    color: "#007bff"  // AZUL
                                                    font.bold: true
                                                    font.pixelSize: fontSmall
                                                    // ALINEADO A LA DERECHA
                                                }
                                            }
                                            
                                            // CELDA ACCIÓN - BOTÓN ELIMINAR REDISEÑADO
                                            Rectangle {
                                                Layout.preferredWidth: 80
                                                Layout.fillHeight: true
                                                color: "transparent"
                                                border.color: "#dee2e6"
                                                border.width: 1
                                                
                                                // BOTÓN CIRCULAR DE ELIMINAR
                                                Rectangle {
                                                    anchors.centerIn: parent
                                                    width: 32
                                                    height: 32
                                                    color: eliminarMouseArea.pressed ? "#c0392b" : "#E74C3C"  // ROJO DE ADVERTENCIA
                                                    radius: 16  // CIRCULAR
                                                    
                                                    // ÍCONO DE PAPELERA BLANCO
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "🗑️"  // ÍCONO DE PAPELERA
                                                        color: "#ffffff"  // BLANCO
                                                        font.pixelSize: fontMedium
                                                        font.bold: true
                                                    }
                                                    
                                                    // EFECTO HOVER
                                                    Behavior on color {
                                                        ColorAnimation { duration: 150 }
                                                    }
                                                    
                                                    MouseArea {
                                                        id: eliminarMouseArea
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        
                                                        onClicked: {
                                                            console.log("🗑️ Eliminando producto índice:", index)
                                                            productosVentaModel.remove(index)
                                                        }
                                                        
                                                        // Efecto de escala en hover
                                                        onHoveredChanged: {
                                                            parent.scale = hovered ? 1.1 : 1.0
                                                        }
                                                    }
                                                    
                                                    Behavior on scale {
                                                        NumberAnimation { duration: 100 }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    
                                    // ESTADO VACÍO (sin cambios)
                                    Item {
                                        anchors.centerIn: parent
                                        visible: productosVentaModel.count === 0
                                        width: 300
                                        height: 120
                                        
                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: 12
                                            
                                            Label {
                                                text: "🛒"
                                                font.pixelSize: 32
                                                color: lightGrayColor
                                                Layout.alignment: Qt.AlignHCenter
                                            }
                                            
                                            Label {
                                                text: "No hay productos en la venta"
                                                color: darkGrayColor
                                                font.pixelSize: fontMedium
                                                Layout.alignment: Qt.AlignHCenter
                                            }
                                            
                                            Label {
                                                text: "Busque y agregue productos usando el campo de arriba"
                                                color: darkGrayColor
                                                font.pixelSize: fontSmall
                                                Layout.alignment: Qt.AlignHCenter
                                                wrapMode: Text.WordWrap
                                                Layout.maximumWidth: 250
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Footer con totales y botones
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16
                    
                    // Estadísticas
                    RowLayout {
                        spacing: 20
                        
                        Rectangle {
                            width: 80
                            height: 40
                            color: "#f8f9fa"
                            radius: 6
                            border.color: "#dee2e6"
                            border.width: 1
                            
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 2
                                
                                Label {
                                    text: "PRODUCTOS"
                                    font.bold: true
                                    color: "#495057"
                                    font.pixelSize: fontTiny
                                    horizontalAlignment: Text.AlignHCenter
                                }
                                
                                Label {
                                    text: calcularProductos().toString()
                                    font.bold: true
                                    color: blueColor
                                    font.pixelSize: fontMedium
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }
                        
                        Rectangle {
                            width: 80
                            height: 40
                            color: "#f8f9fa"
                            radius: 6
                            border.color: "#dee2e6"
                            border.width: 1
                            
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 2
                                
                                Label {
                                    text: "UNIDADES"
                                    font.bold: true
                                    color: "#495057"
                                    font.pixelSize: fontTiny
                                    horizontalAlignment: Text.AlignHCenter
                                }
                                
                                Label {
                                    text: calcularUnidadesTotales().toString()
                                    font.bold: true
                                    color: blueColor
                                    font.pixelSize: fontMedium
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    // Total
                    Rectangle {
                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 40
                        color: blueColor
                        radius: 6
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8
                            
                            Label {
                                text: "TOTAL"
                                color: whiteColor
                                font.bold: true
                                font.pixelSize: fontSmall
                            }
                            
                            Item { Layout.fillWidth: true }
                            
                            Label {
                                text: "$" + calcularTotal().toFixed(2)
                                color: whiteColor
                                font.bold: true
                                font.pixelSize: fontMedium
                            }
                        }
                    }
                    
                    // Botones de acción
                    RowLayout {
                        spacing: 8
                        
                        Button {
                            text: "🧹 Limpiar"
                            Layout.preferredHeight: 40
                            visible: productosVentaModel.count > 0
                            
                            background: Rectangle {
                                color: parent.pressed ? Qt.darker("#ffc107", 1.2) : "#ffc107"
                                radius: 6
                            }
                            
                            contentItem: Label {
                                text: parent.text
                                color: "#212529"
                                font.bold: true
                                font.pixelSize: fontSmall
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: {
                                productosVentaModel.clear()
                                limpiarCamposBusqueda()
                            }
                        }
                        
                        Button {
                            text: "✕ Cancelar"
                            Layout.preferredHeight: 40
                            
                            background: Rectangle {
                                color: parent.pressed ? Qt.darker("#dc3545", 1.2) : "#dc3545"
                                radius: 6
                            }
                            
                            contentItem: Label {
                                text: parent.text
                                color: whiteColor
                                font.bold: true
                                font.pixelSize: fontSmall
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: {
                                mostrarNuevaVenta = false
                                productosVentaModel.clear()
                                limpiarCamposBusqueda()
                            }
                        }
                        
                        Button {
                            id: completarVentaButton
                            text: "✓ Completar Venta"
                            Layout.preferredHeight: 40
                            enabled: productosVentaModel.count > 0
                            
                            background: Rectangle {
                                color: parent.enabled ? 
                                    (parent.pressed ? Qt.darker("#28a745", 1.2) : "#28a745") : 
                                    "#6c757d"
                                radius: 6
                            }
                            
                            contentItem: Label {
                                text: parent.text
                                color: whiteColor
                                font.bold: true
                                font.pixelSize: fontSmall
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: {
                                if (completarVenta()) {
                                    completarVentaButton.text = "✅ ¡Completado!"
                                    Qt.callLater(function() {
                                        completarVentaButton.text = "✓ Completar Venta"
                                    })
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // En el overlay del modal
    Rectangle {
        id: modalOverlay
        anchors.fill: parent
        color: "#000000"
        opacity: 0.5
        visible: detalleVentaDialogOpen
        z: 1000
        
        onVisibleChanged: {
            console.log("👁️ Modal Overlay cambió visible a:", visible)
            if (visible) {
                console.log("🎉 MODAL OVERLAY SE ESTÁ MOSTRANDO!")
            } else {
                console.log("🚫 Modal Overlay se está ocultando")
            }
        }
        
        MouseArea {
            anchors.fill: parent
            onClicked: {
                console.log("🖱️ Click en overlay, cerrando modal")
                detalleVentaDialogOpen = false
            }
        }
    }

    // CONTENEDOR DEL MODAL
    Rectangle {
        id: modalContainer
        anchors.centerIn: parent
        width: Math.min(900, parent.width * 0.9)
        height: Math.min(700, parent.height * 0.9)
        
        visible: detalleVentaDialogOpen
        z: 1001
        
        onVisibleChanged: {
            console.log("👁️ Modal Container visible:", visible)
            if (visible) {
                console.log("📏 Modal dimensions:", width, "x", height)
                console.log("📍 Modal position: center of", parent.width, "x", parent.height)
            }
        }       
        color: "#ffffff"
        radius: radiusLarge
        border.color: "#dee2e6"
        border.width: 1
        
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 4
            anchors.leftMargin: 4
            color: "#00000020"
            radius: parent.radius
            z: -1
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: marginLarge
            spacing: marginLarge
            
            // 1. CABECERA DEL MODAL
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 120
                color: "#f8f9fa"
                radius: radiusLarge
                border.color: "#e9ecef"
                border.width: 1
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 16
                    
                    // Título y botón cerrar
                    RowLayout {
                        Layout.fillWidth: true
                        
                        Label {
                            text: "Detalle de Venta: " + (ventaSeleccionada ? ventaSeleccionada.idVenta : "---")
                            font.pixelSize: fontLarge
                            font.bold: true
                            color: "#2c3e50"
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        Rectangle {
                            width: 32
                            height: 32
                            color: cerrarMouseArea.pressed ? "#c0392b" : "#e74c3c"
                            radius: 16
                            
                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                color: "#ffffff"
                                font.bold: true
                                font.pixelSize: fontMedium
                            }
                            
                            MouseArea {
                                id: cerrarMouseArea
                                anchors.fill: parent
                                onClicked: {
                                    detalleVentaDialogOpen = false
                                }
                            }
                        }
                    }
                    
                    // Información general de la venta
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 40
                        
                        // Fecha y Hora
                        RowLayout {
                            spacing: 8
                            
                            Text {
                                text: "📅"
                                font.pixelSize: fontMedium
                                color: "#3498db"
                            }
                            
                            ColumnLayout {
                                spacing: 4
                                
                                Label {
                                    text: "Fecha y Hora:"
                                    font.pixelSize: fontSmall
                                    color: "#6c757d"
                                    font.bold: true
                                }
                                
                                Label {
                                    text: ventaSeleccionada ? 
                                        ventaSeleccionada.fecha + " | " + ventaSeleccionada.hora : "---"
                                    font.pixelSize: fontMedium
                                    color: "#2c3e50"
                                    font.bold: true
                                }
                            }
                        }
                        
                        // Usuario
                        RowLayout {
                            spacing: 8
                            
                            Text {
                                text: "👤"
                                font.pixelSize: fontMedium
                                color: "#3498db"
                            }
                            
                            ColumnLayout {
                                spacing: 4
                                
                                Label {
                                    text: "Vendido por:"
                                    font.pixelSize: fontSmall
                                    color: "#6c757d"
                                    font.bold: true
                                }
                                
                                Label {
                                    text: ventaSeleccionada ? ventaSeleccionada.usuario : "---"
                                    font.pixelSize: fontMedium
                                    color: "#2c3e50"
                                    font.bold: true
                                }
                            }
                        }
                        
                        Item { Layout.fillWidth: true }
                    }
                }
            }
            
            // 2. CUERPO DEL MODAL - LISTA DE PRODUCTOS
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12
                
                Label {
                    text: "📦 Productos vendidos:"
                    font.bold: true
                    color: "#2c3e50"
                    font.pixelSize: fontMedium
                }
                
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#ffffff"
                    border.color: "#dee2e6"
                    border.width: 1
                    radius: radiusMedium
                    
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0
                        
                        // ENCABEZADO DE LA TABLA CON CUADRÍCULA
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 45
                            color: "#f8f9fa"
                            
                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: 1
                                color: "#dee2e6"
                            }
                            
                            RowLayout {
                                anchors.fill: parent
                                spacing: 0
                                
                                // #
                                Rectangle {
                                    Layout.preferredWidth: 50
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#dee2e6"
                                    border.width: 1
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "#"
                                        font.bold: true
                                        color: "#495057"
                                        font.pixelSize: fontSmall
                                    }
                                }
                                
                                // CÓDIGO
                                Rectangle {
                                    Layout.preferredWidth: 100
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#dee2e6"
                                    border.width: 1
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "CÓDIGO"
                                        font.bold: true
                                        color: "#495057"
                                        font.pixelSize: fontSmall
                                    }
                                }
                                
                                // PRODUCTO
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#dee2e6"
                                    border.width: 1
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "PRODUCTO"
                                        font.bold: true
                                        color: "#495057"
                                        font.pixelSize: fontSmall
                                    }
                                }
                                
                                // CANT.
                                Rectangle {
                                    Layout.preferredWidth: 70
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#dee2e6"
                                    border.width: 1
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "CANT."
                                        font.bold: true
                                        color: "#495057"
                                        font.pixelSize: fontSmall
                                    }
                                }
                                
                                // PRECIO UNIT.
                                Rectangle {
                                    Layout.preferredWidth: 90
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#dee2e6"
                                    border.width: 1
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "PRECIO UNIT."
                                        font.bold: true
                                        color: "#495057"
                                        font.pixelSize: fontSmall
                                    }
                                }
                                
                                // SUBTOTAL
                                Rectangle {
                                    Layout.preferredWidth: 90
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#dee2e6"
                                    border.width: 1
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "SUBTOTAL"
                                        font.bold: true
                                        color: "#495057"
                                        font.pixelSize: fontSmall
                                    }
                                }
                            }
                        }
                        
                        // LISTA DE PRODUCTOS CON CUADRÍCULA
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            
                            ListView {
                                anchors.fill: parent
                                model: productosDetalleModel
                                
                                delegate: Rectangle {
                                    width: parent ? parent.width : 0
                                    height: 50
                                    color: index % 2 === 0 ? "#ffffff" : "#f8f9fa"
                                    
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        width: parent.width
                                        height: 1
                                        color: "#dee2e6"
                                    }
                                    
                                    RowLayout {
                                        anchors.fill: parent
                                        spacing: 0
                                        
                                        // #
                                        Rectangle {
                                            Layout.preferredWidth: 50
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#dee2e6"
                                            border.width: 1
                                            
                                            Label {
                                                anchors.right: parent.right
                                                anchors.rightMargin: 8
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: (index + 1).toString()
                                                color: "#6c757d"
                                                font.pixelSize: fontSmall
                                            }
                                        }
                                        
                                        // CÓDIGO
                                        Rectangle {
                                            Layout.preferredWidth: 100
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#dee2e6"
                                            border.width: 1
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.leftMargin: 8
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: model.codigo || "---"
                                                color: "#007bff"
                                                font.bold: true
                                                font.pixelSize: fontSmall
                                            }
                                        }

                                        
                                        // PRODUCTO
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#dee2e6"
                                            border.width: 1
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.leftMargin: marginSmall
                                                anchors.right: parent.right
                                                anchors.rightMargin: marginSmall
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: model.nombre || "Sin nombre"
                                                color: "#2c3e50"
                                                font.pixelSize: fontSmall
                                                elide: Text.ElideRight
                                            }
                                        }
                                        
                                        // CANT.
                                        Rectangle {
                                            Layout.preferredWidth: parent.width * 0.10
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#dee2e6"
                                            border.width: 1
                                            
                                            Label {
                                                anchors.right: parent.right
                                                anchors.rightMargin: marginSmall
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: (model.cantidad || 0).toString()
                                                color: "#fd7e14"
                                                font.bold: true
                                                font.pixelSize: fontSmall
                                            }
                                        }
                                        
                                        // PRECIO UNIT.
                                        Rectangle {
                                            Layout.preferredWidth: parent.width * 0.15
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#dee2e6"
                                            border.width: 1
                                            
                                            Label {
                                                anchors.right: parent.right
                                                anchors.rightMargin: marginSmall
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "$" + (model.precio || 0).toFixed(2)
                                                color: "#28a745"
                                                font.bold: true
                                                font.pixelSize: fontSmall
                                            }
                                        }
                                        
                                        // SUBTOTAL
                                        Rectangle {
                                            Layout.preferredWidth: parent.width * 0.15
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#dee2e6"
                                            border.width: 1
                                            
                                            Label {
                                                anchors.right: parent.right
                                                anchors.rightMargin: marginSmall
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "$" + (model.subtotal || 0).toFixed(2)
                                                color: "#007bff"
                                                font.bold: true
                                                font.pixelSize: fontSmall
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // 3. PIE DEL MODAL - RESUMEN FINANCIERO
            RowLayout {
                Layout.fillWidth: true
                
                Item { Layout.fillWidth: true }
                
                Rectangle {
                    Layout.preferredWidth: baseUnit * 32
                    Layout.preferredHeight: baseUnit * 8
                    color: "#f8f9fa"
                    radius: radiusSmall
                    border.color: "#dee2e6"
                    border.width: 1
                    
                    // SOLO EL TOTAL - COMPACTO
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: marginSmall
                        
                        Label {
                            text: "TOTAL:"
                            color: "#2c3e50"
                            font.pixelSize: fontMedium
                            font.bold: true
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        Label {
                            text: {
                                var total = 0
                                for (var i = 0; i < productosDetalleModel.count; i++) {
                                    var item = productosDetalleModel.get(i)
                                    if (item && item.subtotal) {
                                        total += item.subtotal
                                    }
                                }
                                return "$" + total.toFixed(2)
                            }
                            color: "#e74c3c"
                            font.pixelSize: fontLarge
                            font.bold: true
                        }
                    }
                }
            }
            
            // 4. PIE DEL MODAL - BOTONES DE ACCIÓN
            RowLayout {
                Layout.fillWidth: true
                
                Item { Layout.fillWidth: true }
                
                // BOTÓN CERRAR
                Rectangle {
                    Layout.preferredWidth: baseUnit * 20
                    Layout.preferredHeight: baseUnit * 8
                    color: cerrarBtnMouseArea.pressed ? "#5a6268" : "#6c757d"
                    radius: radiusMedium
                    border.color: "#495057"
                    border.width: 1
                    
                    Label {
                        anchors.centerIn: parent
                        text: "Cerrar"
                        color: "#ffffff"
                        font.bold: true
                        font.pixelSize: fontMedium
                    }
                    
                    MouseArea {
                        id: cerrarBtnMouseArea
                        anchors.fill: parent
                        onClicked: {
                            detalleVentaDialogOpen = false
                        }
                    }
                }
            }
        }
    }

    // Función para mostrar detalles de venta
    function mostrarDetalleVenta(index) {
        console.log("🔍🔍🔍 FUNCIÓN MOSTRAR DETALLE EJECUTADA 🔍🔍🔍")
        console.log("📍 Index recibido:", index)
        console.log("🏥 farmaciaData disponible:", !!farmaciaData)
        
        if (!farmaciaData) {
            console.log("❌ SALIENDO: farmaciaData es null")
            return
        }
        
        console.log("📊 Cantidad de ventas:", farmaciaData.ventasModel.count)
        
        if (index < 0) {
            console.log("❌ SALIENDO: Index negativo:", index)
            return
        }
        
        if (index >= farmaciaData.ventasModel.count) {
            console.log("❌ SALIENDO: Index fuera de rango")
            return
        }
        
        console.log("✅ Todas las validaciones pasaron")
        console.log("🎯 Estableciendo detalleVentaDialogOpen = true")
        detalleVentaDialogOpen = true
        console.log("🔍 Estado después de establecer:", detalleVentaDialogOpen)
        
        try {
                ventaSeleccionada = farmaciaData.ventasModel.get(index)
                console.log("✅ Venta seleccionada:")
                console.log("   - ID:", ventaSeleccionada.idVenta)
                console.log("   - Usuario:", ventaSeleccionada.usuario)
                console.log("   - Total:", ventaSeleccionada.total)
            } catch (e) {
                console.log("❌ ERROR al obtener venta:", e.message)
                return
            }
            
            console.log("🔍 Buscando productos para venta:", ventaSeleccionada.idVenta)
            
            // AGREGAR DEBUG DETALLADO DE LA BASE DE DATOS
            console.log("📋 Estado actual de productosVendidosDatabase:")
            var keys = Object.keys(productosVendidosDatabase)
            console.log("   Claves disponibles:", keys)
            for (var k = 0; k < keys.length; k++) {
                var key = keys[k]
                var productos = productosVendidosDatabase[key]
                console.log("   " + key + ": " + (productos ? productos.length + " productos" : "undefined"))
            }
            
            var productos = productosVendidosDatabase[ventaSeleccionada.idVenta] || []
            console.log("📦 Productos encontrados para", ventaSeleccionada.idVenta + ":", productos.length)
        
        if (productos.length > 0) {
            console.log("📋 Cargando productos al modelo:")
            for (var i = 0; i < productos.length; i++) {
                var producto = productos[i]
                console.log("   " + (i+1) + ":", producto.codigo, "-", producto.nombre, "x" + producto.cantidad)
                productosDetalleModel.append({
                    codigo: producto.codigo,
                    nombre: producto.nombre,
                    precio: producto.precio,
                    cantidad: producto.cantidad,
                    subtotal: producto.subtotal
                })
            }
        } else {
            console.log("⚠️ No hay productos, agregando placeholder")
            productosDetalleModel.append({
                codigo: "---",
                nombre: "No hay productos registrados",
                precio: 0,
                cantidad: 0,
                subtotal: 0
            })
        }
        
        console.log("📊 Productos en modelo después de cargar:", productosDetalleModel.count)
        console.log("🚀 Abriendo modal...")
        detalleVentaDialogOpen = true
        console.log("✅ Estado del modal después de abrir:", detalleVentaDialogOpen)
        console.log("=== FIN MOSTRAR DETALLE ===")
    }

    // Función para obtener total de ventas
    function getTotalVentasCount() {
        return farmaciaData ? farmaciaData.ventasModel.count : 0
    }

    Component.onCompleted: {
        console.log("=== MÓDULO DE VENTAS INICIALIZADO ===")
        
        if (!farmaciaData) {
            console.log("❌ ERROR: farmaciaData no está disponible")
            return
        }
        
        console.log("✅ farmaciaData conectado correctamente")
        actualizarPaginacionVentas()  // ❌ AGREGAR esta línea
        console.log("=== MÓDULO LISTO ===")
    }
}