import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15

// Componente independiente para crear nueva venta
Item {
    id: crearVentaRoot
    
    // Propiedades de comunicación con el componente padre
    property var inventarioModel: null
    property var ventaModel: null
    property var compraModel: null
    
    // Señales para comunicación
    signal ventaCompletada()
    signal cancelarVenta()
    
    // SISTEMA DE MÉTRICAS COHERENTE
    readonly property real scaleFactor: Math.min(width / 1400, height / 900)
    readonly property real baseUnit: Math.max(8, height / 100)
    readonly property real fontBaseSize: Math.max(12, height / 70)
    
    // Tamaños de fuente escalables
    readonly property real fontTiny: fontBaseSize * 0.75
    readonly property real fontSmall: fontBaseSize * 0.85
    readonly property real fontMedium: fontBaseSize
    readonly property real fontLarge: fontBaseSize * 1.15
    readonly property real fontXLarge: fontBaseSize * 1.4
    
    // Espaciados
    readonly property real marginTiny: baseUnit * 0.5
    readonly property real marginSmall: baseUnit * 0.75
    readonly property real marginMedium: baseUnit
    readonly property real marginLarge: baseUnit * 1.5
    
    // Radios
    readonly property real radiusSmall: baseUnit * 0.5
    readonly property real radiusMedium: baseUnit * 0.75
    readonly property real radiusLarge: baseUnit
    
    // Alturas de controles
    readonly property real controlHeight: Math.max(40, baseUnit * 5)
    readonly property real buttonHeight: Math.max(36, baseUnit * 4.5)
    readonly property real headerHeight: Math.max(60, baseUnit * 7.5)

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

    Connections {
        target: inventarioModel
        function onSearchResultsChanged() {
            console.log("🔍 Resultados de búsqueda actualizados")
        }
    }

    // MODELOS PARA LA NUEVA VENTA
    ListModel {
        id: productosVentaModel
    }

    ListModel {
        id: resultadosBusquedaModel
    }

    // FUNCIONES DE NEGOCIO
    
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

    // Función para buscar productos
    function buscarProductos(textoBusqueda) {
        console.log("🔍 CrearVenta: Buscando productos con:", textoBusqueda)
        
        resultadosBusquedaModel.clear()
        
        if (!textoBusqueda || textoBusqueda.length < 2) {
            return
        }
        
        if (inventarioModel) {
            try {
                inventarioModel.buscar_productos(textoBusqueda)
                var resultados = inventarioModel.search_results || []
                console.log("🔍 Resultados encontrados:", resultados.length)
                
                for (var i = 0; i < resultados.length; i++) {
                    var producto = resultados[i]
                    resultadosBusquedaModel.append({
                        codigo: producto.Codigo || producto.codigo,
                        nombre: producto.Nombre || producto.nombre,
                        precio: producto.Precio_venta || producto.precio || 0,
                        stock: producto.Stock_Total || producto.stock || 0
                    })
                }
            } catch (e) {
                console.log("❌ Error en búsqueda:", e.message)
                usarDatosDePrueba(textoBusqueda)
            }
        } else {
            usarDatosDePrueba(textoBusqueda)
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
                resultadosBusquedaModel.append(prod)
            }
        }
    }

    // Función para agregar producto a venta
    function agregarProductoAVenta(codigo, cantidad) {
        console.log("🛒 Agregando producto:", codigo, "Cantidad:", cantidad)
        
        if (!codigo || cantidad <= 0) {
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
            return false
        }
        
        // Verificar stock
        if (cantidad > productoEncontrado.stock) {
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
                return false
            }
            
            productosVentaModel.setProperty(indiceExistente, "cantidad", nuevaCantidad)
            productosVentaModel.setProperty(indiceExistente, "subtotal", nuevoSubtotal)
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
        }
        
        limpiarCamposBusqueda()
        return true
    }

    // Función para completar venta
    function completarVenta() {
        console.log("🛒 Completando venta...")
        
        if (productosVentaModel.count === 0) {
            return false
        }
        
        if (!ventaModel) {
            console.log("❌ VentaModel no disponible")
            return false
        }
        
        // Limpiar carrito previo
        ventaModel.limpiar_carrito()
        
        // Agregar productos al carrito del model
        for (var i = 0; i < productosVentaModel.count; i++) {
            var prod = productosVentaModel.get(i)
            ventaModel.agregar_item_carrito(prod.codigo, prod.cantidad, prod.precio)
        }
        
        // Procesar venta
        var exito = ventaModel.procesar_venta_carrito()
        if (exito) {
            limpiarTodo()
            ventaCompletada() // Emitir señal
            
            // ✅ AGREGAR: Regresar automáticamente
            Qt.callLater(function() {
                console.log("🔙 Venta completada, regresando a lista...")
                stackView.pop() // Regresar a Ventas.qml
            })
            
            return true
        }
        
        return false
    }

    // Función para limpiar campos de búsqueda
    function limpiarCamposBusqueda() {
        busquedaField.text = ""
        cantidadField.text = "1"
        resultadosBusquedaModel.clear()
        
        Qt.callLater(function() {
            busquedaField.focus = true
        })
    }

    // Función para limpiar todo
    function limpiarTodo() {
        productosVentaModel.clear()
        limpiarCamposBusqueda()
    }

    // Función auxiliar para agregar producto desde input
    function agregarProductoDesdeInput() {
        var texto = busquedaField.text.trim()
        var cantidadTexto = cantidadField.text.trim()
        var cantidad = parseInt(cantidadTexto) || 1
        
        if (!texto) {
            busquedaField.focus = true
            return
        }
        
        if (cantidad <= 0) {
            cantidad = 1
        }
        
        if (resultadosBusquedaModel.count > 0) {
            var primerProducto = resultadosBusquedaModel.get(0)
            agregarProductoAVenta(primerProducto.codigo, cantidad)
        } else {
            buscarProductos(texto)
            Qt.callLater(function() {
                if (resultadosBusquedaModel.count > 0) {
                    var producto = resultadosBusquedaModel.get(0)
                    agregarProductoAVenta(producto.codigo, cantidad)
                }
            })
        }
    }

    // INTERFAZ DE USUARIO
    Rectangle {
        anchors.fill: parent
        color: "#f8f9fa"
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: marginMedium
            spacing: marginMedium
            
            // HEADER CON BOTÓN DE REGRESO
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
                                cancelarVenta() // Emitir señal para regresar
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
                            text: "No. Venta: V" + String((ventaModel ? ventaModel.total_ventas_hoy : 0) + 1).padStart(3, '0')
                            color: blueColor
                            font.pixelSize: fontMedium
                            font.bold: true
                        }
                    }
                }
            }
            
            // SECCIÓN DE BÚSQUEDA DE PRODUCTOS
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 120
                color: "#ffffff"
                radius: radiusLarge
                border.color: "#e1e8ed"
                border.width: 1
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 16
                    
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
                    
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 50
                        color: "transparent"
                        
                        RowLayout {
                            anchors.fill: parent
                            spacing: 16
                            
                            // Campo de búsqueda
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                color: "#ffffff"
                                border.color: "#3498db"
                                border.width: 2
                                radius: 8
                                
                                TextInput {
                                    id: busquedaField
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    
                                    font.pixelSize: fontMedium
                                    color: "#000000"
                                    verticalAlignment: Text.AlignVCenter
                                    
                                    clip: true
                                    selectByMouse: true
                                    
                                    onTextChanged: {
                                        if (text.length >= 2) {
                                            buscarProductos(text)
                                        } else {
                                            resultadosBusquedaModel.clear()
                                        }
                                    }
                                    
                                    Keys.onReturnPressed: {
                                        agregarProductoDesdeInput()
                                    }
                                    
                                    Keys.onEscapePressed: {
                                        text = ""
                                        resultadosBusquedaModel.clear()
                                    }
                                }
                                
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
                            
                            Text {
                                text: "Cantidad:"
                                font.pixelSize: fontMedium
                                font.bold: true
                                color: "#000000"
                                Layout.alignment: Qt.AlignVCenter
                            }
                            
                            Rectangle {
                                Layout.preferredWidth: 70
                                Layout.fillHeight: true
                                color: "#ffffff"
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
                                    color: "#000000"
                                    
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    
                                    clip: true
                                    selectByMouse: true
                                    validator: IntValidator { bottom: 1; top: 999 }
                                    
                                    Keys.onReturnPressed: {
                                        agregarProductoDesdeInput()
                                    }
                                    
                                    onActiveFocusChanged: {
                                        if (activeFocus) {
                                            selectAll()
                                        }
                                    }
                                }
                            }
                            
                            Rectangle {
                                Layout.preferredWidth: 120
                                Layout.fillHeight: true
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
                                    onClicked: agregarProductoDesdeInput()
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
            
            // TABLA DE PRODUCTOS EN LA VENTA
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8
                
                Label {
                    text: "🛒 Productos en la venta:"
                    font.bold: true
                    color: textColor
                    font.pixelSize: fontMedium
                }
                
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
                        spacing: 0
                        
                        // Header de tabla
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
                        
                        // Lista de productos
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            
                            ListView {
                                anchors.fill: parent
                                model: productosVentaModel
                                
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
                                                color: "#007bff"
                                                font.bold: true
                                                font.pixelSize: fontSmall
                                            }
                                        }
                                        
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
                                            }
                                        }
                                        
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
                                                color: "#28a745"
                                                font.bold: true
                                                font.pixelSize: fontSmall
                                            }
                                        }
                                        
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
                                                color: "#fd7e14"
                                                font.bold: true
                                                font.pixelSize: fontSmall
                                            }
                                        }
                                        
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
                                                color: "#007bff"
                                                font.bold: true
                                                font.pixelSize: fontSmall
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 80
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#dee2e6"
                                            border.width: 1
                                            
                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: 32
                                                height: 32
                                                color: eliminarMouseArea.pressed ? "#c0392b" : "#E74C3C"
                                                radius: 16
                                                
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "🗑️"
                                                    color: "#ffffff"
                                                    font.pixelSize: fontMedium
                                                    font.bold: true
                                                }
                                                
                                                Behavior on color {
                                                    ColorAnimation { duration: 150 }
                                                }
                                                
                                                MouseArea {
                                                    id: eliminarMouseArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    
                                                    onClicked: {
                                                        productosVentaModel.remove(index)
                                                    }
                                                    
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
                                
                                // Estado vacío
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

            // FOOTER CON TOTALES Y BOTONES
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
                        
                        onClicked: limpiarTodo()
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
                            limpiarTodo()
                            cancelarVenta() // Emitir señal
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

    // Inicialización
    Component.onCompleted: {
        console.log("✅ CrearVenta.qml inicializado")
        
        if (!inventarioModel || !ventaModel) {
            console.log("⚠️ Models no disponibles aún")
        } else {
            console.log("✅ Models conectados correctamente")
        }
        
        Qt.callLater(function() {
            if (busquedaField) {
                busquedaField.focus = true
            }
        })
    }
}