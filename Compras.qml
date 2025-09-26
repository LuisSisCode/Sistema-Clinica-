import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

// Componente principal del módulo de Compras - Vista simplificada solo para listar
Item {
    id: comprasRoot
    objectName: "comprasRoot"
    
    // Referencia al módulo principal de farmacia
    property var farmaciaData: parent.farmaciaData
    property var compraModel: parent.compraModel || (farmaciaData ? farmaciaData.compraModel : null)
    
    // Señal para navegar a crear compra
    signal navegarACrearCompra()
    signal navegarAEditarCompra(int compraId, var datosCompra)

    property bool mostrandoMenuContextual: false
    property var compraMenuContextual: null
    // Propiedades de control de vistas
    property bool showPurchaseDetailsDialog: false
    property var selectedPurchase: null
    property var purchaseDetails: []
    
    // Propiedades de paginación para compras
    property int itemsPerPageCompras: 10
    property int currentPageCompras: 0
    property int totalPagesCompras: 0
    
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
    
    property bool showDeleteConfirmDialog: false
    property var compraToDelete: null

    // MODELO PARA COMPRAS PAGINADAS
    ListModel {
        id: comprasPaginadasModel
    }
    ListModel {
        id: detallesCompraModel
    }
    
    // Detectar cuando el usuario regresa al módulo
    onVisibleChanged: {
        if (visible) {
            console.log("🔄 Módulo compras visible, actualizando lista")
            Qt.callLater(actualizarPaginacionCompras)
        }
    }
    
    // FUNCIÓN para actualizar paginación de compras
    function actualizarPaginacionCompras() {
        if (!compraModel) return
        
        var totalItems = compraModel.compras_recientes.length
        totalPagesCompras = Math.ceil(totalItems / itemsPerPageCompras)
        
        // Ajustar página actual si es necesario
        if (currentPageCompras >= totalPagesCompras && totalPagesCompras > 0) {
            currentPageCompras = totalPagesCompras - 1
        }
        if (currentPageCompras < 0) {
            currentPageCompras = 0
        }
        
        // Limpiar modelo paginado
        comprasPaginadasModel.clear()
        
        // Calcular índices
        var startIndex = currentPageCompras * itemsPerPageCompras
        var endIndex = Math.min(startIndex + itemsPerPageCompras, totalItems)
        
        // DEBUG: Ver datos antes de agregar al modelo
        console.log("🔍 DEBUG QML: Agregando", (endIndex - startIndex), "compras al modelo paginado")
        
        // Agregar elementos de la página actual - MÉTODO CORREGIDO
        for (var i = startIndex; i < endIndex; i++) {
            var compraRaw = compraModel.compras_recientes[i]
            
            // Crear objeto explícito para QML ListModel
            var compraQML = {
                "id": compraRaw.id || 0,
                "proveedor": compraRaw.proveedor || "Sin proveedor",
                "usuario": compraRaw.usuario || "Sin usuario", 
                "fecha": compraRaw.fecha || "Sin fecha",
                "hora": compraRaw.hora || "Sin hora",
                "total": compraRaw.total || 0.0,
                
                // NUEVOS CAMPOS - AGREGAR ESTAS LÍNEAS
                "productos_texto": compraRaw.productos_texto || "Sin productos",
                "total_productos": compraRaw.total_productos || 0,
                
                // Campos adicionales para compatibilidad
                "Proveedor_Nombre": compraRaw.Proveedor_Nombre || "",
                "Usuario": compraRaw.Usuario || "",
                "Total": compraRaw.Total || 0.0,
                "Id_Proveedor": compraRaw.Id_Proveedor || 0,
                "Id_Usuario": compraRaw.Id_Usuario || 0
            }
            comprasPaginadasModel.append(compraQML)
        }
        
        
    }
    
    // Función para obtener detalles de una compra
    function obtenerDetallesCompra(compraId) {
        if (!compraModel) return
        
        console.log("🔍 Obteniendo detalles mejorados para compra:", compraId)
        
        // Limpiar modelo antes de cargar nuevos datos
        detallesCompraModel.clear()
        
        var detalleCompra = compraModel.get_compra_detalle(compraId)
        console.log("📋 Detalle completo recibido:", JSON.stringify(detalleCompra))
        
        if (detalleCompra && detalleCompra.detalles) {
            console.log("✅ Procesando", detalleCompra.detalles.length, "productos")
            var items = detalleCompra.detalles
            
            for (var i = 0; i < items.length; i++) {
                var item = items[i]
                detallesCompraModel.append({
                    codigo: item.codigo || "",
                    nombre: item.nombre || "Producto no encontrado",
                    marca: item.marca || "Sin marca",
                    cantidad_unitario: item.cantidad_unitario || 0,
                    cantidad_total: item.cantidad_total || 0,
                    costo_total: item.costo_total || item.precio_unitario || item.subtotal || 0,
                    fecha_vencimiento: item.fecha_vencimiento || "Sin fecha"
                })
            }
            console.log("📦 Items procesados en modal:", detallesCompraModel.count)
        } else {
            console.log("❌ No se encontraron detalles de productos")
        }
    }

    // Función para cargar compra en edición
    function cargarCompraParaEdicion(compraId) {
        console.log("✏️ Cargando compra para edición:", compraId)
        
        // Llamar al método del modelo para cargar los datos
        var exito = compraModel.cargar_compra_para_edicion(compraId)
        
        if (exito) {
            // Emitir señal para navegar a CrearCompra
            navegarAEditarCompra(compraId, null)
        } else {
            console.log("❌ Error cargando compra para edición")
        }
    }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 24
        
        // Header del módulo con título y botones de acción
        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            
            // Información del módulo
            RowLayout {
                spacing: 12
                
                Image {
                    source: "Resources/iconos/compras.png"
                    Layout.preferredWidth: 60
                    Layout.preferredHeight: 60
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    
                    // Efecto de hover opcional
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: parent.opacity = 0.8
                        onExited: parent.opacity = 1.0
                    }
                    
                    Behavior on opacity {
                        NumberAnimation { duration: 150 }
                    }
                }
                
                ColumnLayout {
                    spacing: 4
                    
                    Label {
                        text: "Módulo de Farmacia"
                        color: textColor
                        font.pixelSize: 24
                        font.bold: true
                    }
                    
                    Label {
                        text: "Gestión de Compras"
                        color: darkGrayColor
                        font.pixelSize: 14
                    }
                }
            }
            
            Item { Layout.fillWidth: true }
            
            // Información en tiempo real
            Rectangle {
                Layout.preferredWidth: 150
                Layout.preferredHeight: 60
                color: "#E8F5E8"
                radius: 8
                border.color: successColor
                border.width: 1
                
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    
                    Label {
                        text: "Total Compras:"
                        font.pixelSize: 10
                        color: darkGrayColor
                        Layout.alignment: Qt.AlignHCenter
                    }
                    
                    Label {
                        text: compraModel ? compraModel.total_compras_mes.toString() : "0"
                        font.pixelSize: 18
                        font.bold: true
                        color: successColor
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
            
            // Botón de Nueva Compra
            Button {
                id: nuevaCompraButton
                Layout.preferredWidth: 230
                Layout.preferredHeight: 75
                
                background: Rectangle {
                    color: parent.pressed ? Qt.darker(successColor, 1.2) : successColor
                    radius: 8
                    
                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                    
                    // Sombra sutil
                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: 2
                        color: "#00000020"
                        radius: 8
                        z: -1
                    }
                }
                
                contentItem: RowLayout {
                    spacing: 8
                    anchors.centerIn: parent
                    
                    Image {
                        source: "Resources/iconos/añadirProducto.png"
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }
                    
                    Label {
                        text: "Nueva Compra"
                        color: whiteColor
                        font.bold: true
                        font.pixelSize: 18
                    }
                }
                
                onClicked: {
                    console.log("🚚 Navegando a CrearCompra")
                    navegarACrearCompra() // Emitir señal para navegar
                }
                
                // Efecto hover
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: parent.scale = 1.02
                    onExited: parent.scale = 1.0
                    onClicked: parent.clicked()
                }
                
                Behavior on scale {
                    NumberAnimation { duration: 100 }
                }
            }
        }
        
        // Tabla de compras
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#FFFFFF"
            border.color: "#D5DBDB"
            border.width: 1
            radius: 16
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 0
                spacing: 0
                
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50
                    color: "#F8F9FA"
                    
                    RowLayout {
                        anchors.fill: parent
                        spacing: 0
                        
                        Rectangle {
                            Layout.preferredWidth: 100
                            Layout.fillHeight: true
                            color: "#F8F9FA"
                            border.color: "#D5DBDB"
                            border.width: 1
                            
                            Label {
                                anchors.centerIn: parent
                                text: "ID COMPRA"
                                color: "#2C3E50"
                                font.bold: true
                                font.pixelSize: 12
                            }
                        }
                        
                        Rectangle {
                            Layout.preferredWidth: 200
                            Layout.fillHeight: true
                            color: "#F8F9FA"
                            border.color: "#D5DBDB"
                            border.width: 1
                            
                            Label {
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: "PROVEEDOR"
                                color: "#2C3E50"
                                font.bold: true
                                font.pixelSize: 12
                            }
                        }
                        
                        // NUEVA COLUMNA PRODUCTOS
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 250
                            Layout.fillHeight: true
                            color: "#F8F9FA"
                            border.color: "#D5DBDB"
                            border.width: 1
                            
                            Label {
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: "PRODUCTOS"
                                color: "#2C3E50"
                                font.bold: true
                                font.pixelSize: 12
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
                                text: "USUARIO"
                                color: "#2C3E50"
                                font.bold: true
                                font.pixelSize: 12
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
                                text: "FECHA"
                                color: "#2C3E50"
                                font.bold: true
                                font.pixelSize: 12
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
                                text: "TOTAL GASTADO"
                                color: "#2C3E50"
                                font.bold: true
                                font.pixelSize: 12
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
                                text: "DETALLE"  // CAMBIADO DE "ACCIONES"
                                color: "#2C3E50"
                                font.bold: true
                                font.pixelSize: 12
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
                        id: comprasTable
                        anchors.fill: parent
                        model: comprasPaginadasModel
                        
                        delegate: Item {
                            width: comprasTable.width
                            height: 60
                            
                            Rectangle {
                                anchors.fill: parent
                                color: selectedPurchase && selectedPurchase.id === model.id ? "#E3F2FD" : "transparent"
                                opacity: selectedPurchase && selectedPurchase.id === model.id ? 0.8 : 0.0
                            }
                            
                            RowLayout {
                                anchors.fill: parent
                                spacing: 0
                                
                                // ID COMPRA
                                Rectangle {
                                    Layout.preferredWidth: 100
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#D5DBDB"
                                    border.width: 1
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: model.id
                                        color: "#3498DB"
                                        font.bold: true
                                        font.pixelSize: 14
                                    }
                                }
                                
                                // PROVEEDOR
                                Rectangle {
                                    Layout.preferredWidth: 200
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#D5DBDB"
                                    border.width: 1
                                    
                                    ColumnLayout {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 4
                                        
                                        Label {
                                            text: model.proveedor
                                            color: "#2C3E50"
                                            font.bold: true
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                            Layout.maximumWidth: 180
                                        }
                                    }
                                }
                                
                                // NUEVA COLUMNA: PRODUCTOS
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 250
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#D5DBDB"
                                    border.width: 1
                                    
                                    RowLayout {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 8
                                        
                                        // Ícono de productos
                                        Rectangle {
                                            Layout.preferredWidth: 20
                                            Layout.preferredHeight: 20
                                            color: "#27AE60"
                                            radius: 10
                                            
                                            Label {
                                                anchors.centerIn: parent
                                                text: model.total_productos || 0
                                                color: "#FFFFFF"
                                                font.bold: true
                                                font.pixelSize: 10
                                            }
                                        }
                                        
                                        // Texto de productos
                                        Label {
                                            text: model.productos_texto || "Sin productos"
                                            color: "#2C3E50"
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                            Layout.maximumWidth: 200
                                            Layout.fillWidth: true
                                        }
                                    }
                                }
                                
                                // USUARIO
                                Rectangle {
                                    Layout.preferredWidth: 120
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#D5DBDB"
                                    border.width: 1
                                    
                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 6
                            
                                        Label {
                                           text: model.usuario
                                            color: "#2C3E50"
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                            Layout.maximumWidth: 80
                                        }
                                    }
                                }
                                
                                // FECHA
                                Rectangle {
                                    Layout.preferredWidth: 120
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#D5DBDB"
                                    border.width: 1
                                    
                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 2
                                        
                                        RowLayout {
                                            spacing: 4
                                                                                     
                                            Label {
                                                text: model.fecha
                                                color: "#3498DB"
                                                font.bold: true
                                                font.pixelSize: 11
                                            }
                                        }
                                        
                                        Label {
                                            text: model.hora
                                            color: "#7F8C8D"
                                            font.pixelSize: 10
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                    }
                                }
                                
                                // TOTAL GASTADO
                                Rectangle {
                                    Layout.preferredWidth: 100
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#D5DBDB"
                                    border.width: 1
                                    
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 85
                                        height: 28
                                        color: "#27AE60"
                                        radius: 14
                                        
                                        Label {
                                            anchors.centerIn: parent
                                            text: "Bs" + model.total.toFixed(2)
                                            color: "#FFFFFF"
                                            font.bold: true
                                            font.pixelSize: 10
                                        }
                                    }
                                }
                                
                                // BOTÓN VER SOLAMENTE
                                Rectangle {
                                    Layout.preferredWidth: 120
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#D5DBDB"
                                    border.width: 1
                                    
                                    Button {
                                        anchors.centerIn: parent
                                        width: 60
                                        height: 30
                                        
                                        background: Rectangle {
                                            color: parent.pressed ? Qt.darker(blueColor, 1.2) : blueColor
                                            radius: 15
                                        }
                                        
                                        contentItem: Label {
                                            text: "Ver"  
                                            color: whiteColor
                                            font.pixelSize: 11
                                            font.bold: true
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        
                                        onClicked: {
                                            console.log("👁️ Ver detalle de compra, index:", index)
                                            selectedPurchase = model
                                            obtenerDetallesCompra(model.id)
                                            showPurchaseDetailsDialog = true
                                        }
                                    }
                                }
                            }
                            MouseArea {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                anchors.rightMargin: 0  // Eliminar margen condicional
                                
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                z: -1
                                
                                onClicked: function(mouse) {
                                    if (mouse.button === Qt.LeftButton) {
                                        comprasTable.currentIndex = index
                                        selectedPurchase = model
                                        mostrandoMenuContextual = false
                                        compraMenuContextual = null
                                    } else if (mouse.button === Qt.RightButton) {
                                        if (selectedPurchase && selectedPurchase.id === model.id) {
                                            mostrandoMenuContextual = true
                                            compraMenuContextual = model
                                        }
                                    }
                                }
                            }
                            // BOTONES SUPERPUESTOS CENTRADOS EN TODA LA FILA
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                visible: mostrandoMenuContextual && compraMenuContextual && compraMenuContextual.id === model.id
                                z: 10
                                
                                // Cuadro contenedor estilo menú contextual
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 120
                                    height: 50
                                    color: "#F8F9FA"
                                    border.width: 0
                                    radius: 4
                                    
                                    // Sombra sutil
                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.topMargin: 2
                                        anchors.leftMargin: 2
                                        color: "#00000015"
                                        radius: 4
                                        z: -1
                                    }
                                    
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 0
                                        spacing: 0
                                        
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 25
                                            color: editarHover.containsMouse ? "#E3F2FD" : "transparent"
                                            radius: 0
                                            
                                            Label {
                                                anchors.centerIn: parent
                                                text: "Editar"
                                                color: editarHover.containsMouse ? "#1976D2" : "#2C3E50"
                                                font.pixelSize: 11
                                                font.weight: Font.Medium
                                            }
                                            
                                            MouseArea {
                                                id: editarHover
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: {
                                                    console.log("Editando compra:", model.id)
                                                    cargarCompraParaEdicion(model.id)
                                                    mostrandoMenuContextual = false
                                                    compraMenuContextual = null
                                                    selectedPurchase = null
                                                }
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 25
                                            color: eliminarHover.containsMouse ? "#FFEBEE" : "transparent"
                                            radius: 0
                                            
                                            Label {
                                                anchors.centerIn: parent
                                                text: "Eliminar"
                                                color: eliminarHover.containsMouse ? "#D32F2F" : "#2C3E50"
                                                font.pixelSize: 11
                                                font.weight: Font.Medium
                                            }
                                            
                                            MouseArea {
                                                id: eliminarHover
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: {
                                                    console.log("Eliminando compra:", model.id)
                                                    compraToDelete = model
                                                    showDeleteConfirmDialog = true
                                                    mostrandoMenuContextual = false
                                                    compraMenuContextual = null
                                                    selectedPurchase = null
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Estado vacío
                        Item {
                            anchors.centerIn: parent
                            visible: compraModel ? compraModel.total_compras_mes === 0 : true
                            width: 300
                            height: 200
                            
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 16
                                
                                Label {
                                    text: "🚚"
                                    font.pixelSize: 48
                                    color: lightGrayColor
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                
                                Label {
                                    text: "No hay compras registradas"
                                    color: darkGrayColor
                                    font.pixelSize: 16
                                    font.bold: true
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                
                                Label {
                                    text: "Las compras aparecerán aquí cuando se completen"
                                    color: darkGrayColor
                                    font.pixelSize: 12
                                    Layout.alignment: Qt.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    Layout.maximumWidth: 250
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }
                    }
                }
                

                // Control de Paginación
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    color: "#F8F9FA"
                    border.color: "#D5DBDB"
                    border.width: 1
                    
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 20
                        
                        Button {
                            Layout.preferredWidth: 100
                            Layout.preferredHeight: 36
                            text: "← Anterior"
                            enabled: currentPageCompras > 0
                            
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
                                font.pixelSize: 14
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: {
                                if (currentPageCompras > 0) {
                                    currentPageCompras--
                                    actualizarPaginacionCompras()
                                }
                            }
                        }

                        Label {
                            text: "Página " + (currentPageCompras + 1) + " de " + Math.max(1, totalPagesCompras)
                            color: "#374151"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }

                        Button {
                            Layout.preferredWidth: 110
                            Layout.preferredHeight: 36
                            text: "Siguiente →"
                            enabled: currentPageCompras < totalPagesCompras - 1
                            
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
                                font.pixelSize: 14
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: {
                                if (currentPageCompras < totalPagesCompras - 1) {
                                    currentPageCompras++
                                    actualizarPaginacionCompras()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MODAL DE DETALLE DE COMPRA
    Rectangle {
        id: modalOverlay
        anchors.fill: parent
        color: "#000000"
        opacity: 0.5
        visible: showPurchaseDetailsDialog
        z: 1000
        
        MouseArea {
            anchors.fill: parent
            onClicked: {
                showPurchaseDetailsDialog = false
            }
        }
    }

    Rectangle {
        id: modalContainer
        anchors.centerIn: parent
        width: Math.min(1000, parent.width * 0.95)  // Aumentado para nueva columna
        height: Math.min(600, parent.height * 0.9)
        
        visible: showPurchaseDetailsDialog
        z: 1001
        
        color: "#ffffff"
        radius: 12
        border.color: "#dee2e6"
        border.width: 2
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16
            
            // Header del modal
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 80
                color: "#F8F9FA"
                radius: 8
                border.color: "#DEE2E6"
                border.width: 1
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 16
                    
                    Rectangle {
                        Layout.preferredWidth: 50
                        Layout.preferredHeight: 50
                        color: "#3498DB"
                        radius: 25
                        
                    }
                    
                    ColumnLayout {
                        spacing: 4
                        
                        Label {
                            text: "Detalles de Compra #" + (selectedPurchase ? selectedPurchase.id : "")
                            color: "#2C3E50"
                            font.bold: true
                            font.pixelSize: 18
                        }
                        
                        RowLayout {
                            spacing: 20
                            
                            Label {
                                text: "Proveedor: " + (selectedPurchase ? selectedPurchase.proveedor : "")
                                color: "#7F8C8D"
                                font.pixelSize: 12
                            }
                            
                            Label {
                                text: "Usuario: " + (selectedPurchase ? selectedPurchase.usuario : "")
                                color: "#7F8C8D"
                                font.pixelSize: 12
                            }
                            
                            Label {
                                text: "Fecha: " + (selectedPurchase ? selectedPurchase.fecha : "")
                                color: "#7F8C8D"
                                font.pixelSize: 12
                            }
                        }
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    Button {
                        text: "✕"
                        width: 35
                        height: 35
                        background: Rectangle {
                            color: "#E74C3C"
                            radius: 17
                        }
                        contentItem: Label {
                            text: parent.text
                            color: "#FFFFFF"
                            font.bold: true
                            font.pixelSize: 16
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: showPurchaseDetailsDialog = false
                    }
                }
            }
            
            // Tabla de productos COMPLETAMENTE CORREGIDA
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#FFFFFF"
                border.color: "#D5DBDB"
                border.width: 1
                radius: 8
                
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0
                    
                    // Header de tabla mejorado
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 45
                        color: "#34495E"
                        
                        RowLayout {
                            anchors.fill: parent
                            spacing: 0
                            
                            Rectangle {
                                Layout.preferredWidth: 80
                                Layout.fillHeight: true
                                color: "#34495E"
                                border.color: "#2C3E50"
                                border.width: 1
                                Label {
                                    anchors.centerIn: parent
                                    text: "CÓDIGO"
                                    color: "#FFFFFF"
                                    font.bold: true
                                    font.pixelSize: 11
                                }
                            }
                            
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 150
                                Layout.fillHeight: true
                                color: "#34495E"
                                border.color: "#2C3E50"
                                border.width: 1
                                Label {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "PRODUCTO"
                                    color: "#FFFFFF"
                                    font.bold: true
                                    font.pixelSize: 11
                                }
                            }
                            
                            Rectangle {
                                Layout.preferredWidth: 100
                                Layout.fillHeight: true
                                color: "#34495E"
                                border.color: "#2C3E50"
                                border.width: 1
                                Label {
                                    anchors.centerIn: parent
                                    text: "MARCA"
                                    color: "#FFFFFF"
                                    font.bold: true
                                    font.pixelSize: 11
                                }
                            }
                            
                            Rectangle {
                                Layout.preferredWidth: 80
                                Layout.fillHeight: true
                                color: "#34495E"
                                border.color: "#2C3E50"
                                border.width: 1
                                Label {
                                    anchors.centerIn: parent
                                    text: "UNIDADES"
                                    color: "#FFFFFF"
                                    font.bold: true
                                    font.pixelSize: 11
                                }
                            }
                            
                            Rectangle {
                                Layout.preferredWidth: 90
                                Layout.fillHeight: true
                                color: "#34495E"
                                border.color: "#2C3E50"
                                border.width: 1
                                Label {
                                    anchors.centerIn: parent
                                    text: "COSTO TOTAL"
                                    color: "#FFFFFF"
                                    font.bold: true
                                    font.pixelSize: 11
                                }
                            }
                            
                            Rectangle {
                                Layout.preferredWidth: 110
                                Layout.fillHeight: true
                                color: "#34495E"
                                border.color: "#2C3E50"
                                border.width: 1
                                Label {
                                    anchors.centerIn: parent
                                    text: "F. VENCIM."
                                    color: "#FFFFFF"
                                    font.bold: true
                                    font.pixelSize: 11
                                }
                            }
                        }
                    }
                    
                    // Contenido scrolleable mejorado
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        
                        ListView {
                            model: detallesCompraModel
                            
                            delegate: Rectangle {
                                width: ListView.view.width
                                height: 55
                                color: index % 2 === 0 ? "#FFFFFF" : "#F8F9FA"
                                
                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 0
                                    
                                    // CÓDIGO
                                    Rectangle {
                                        Layout.preferredWidth: 80
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#D5DBDB"
                                        border.width: 1
                                        
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 65
                                            height: 25
                                            color: "#3498DB"
                                            radius: 12
                                            
                                            Label {
                                                anchors.centerIn: parent
                                                text: model.codigo || ""
                                                color: "#FFFFFF"
                                                font.bold: true
                                                font.pixelSize: 10
                                            }
                                        }
                                    }
                                    
                                    // PRODUCTO
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 150
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#D5DBDB"
                                        border.width: 1
                                        
                                        Label {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: model.nombre || ""
                                            color: "#2C3E50"
                                            font.bold: true
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                            Layout.maximumWidth: parent.width - 16
                                        }
                                    }
                                    
                                    // MARCA
                                    Rectangle {
                                        Layout.preferredWidth: 100
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#D5DBDB"
                                        border.width: 1
                                        
                                        Label {
                                            anchors.centerIn: parent
                                            text: model.marca || "Sin marca"
                                            color: "#7F8C8D"
                                            font.pixelSize: 10
                                            elide: Text.ElideRight
                                        }
                                    }
                                    
                                    // UNIDADES
                                    Rectangle {
                                        Layout.preferredWidth: 80
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#D5DBDB"
                                        border.width: 1
                                        
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 45
                                            height: 20
                                            color: "#9B59B6"
                                            radius: 10
                                            
                                            Label {
                                                anchors.centerIn: parent
                                                text: model.cantidad_unitario || "0"
                                                color: "#FFFFFF"
                                                font.bold: true
                                                font.pixelSize: 10
                                            }
                                        }
                                    }
                                    
                                    // COSTO TOTAL - NUEVA SECCIÓN AGREGADA
                                    Rectangle {
                                        Layout.preferredWidth: 90
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#D5DBDB"
                                        border.width: 1
                                        
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 75
                                            height: 25
                                            color: "#27AE60"
                                            radius: 12
                                            
                                            Label {
                                                anchors.centerIn: parent
                                                text: "Bs" + (model.costo_total || model.precio_unitario || 0).toFixed(2)
                                                color: "#FFFFFF"
                                                font.bold: true
                                                font.pixelSize: 10
                                            }
                                        }
                                    }
                                    
                                    // FECHA VENCIMIENTO
                                    Rectangle {
                                        Layout.preferredWidth: 110
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#D5DBDB"
                                        border.width: 1
                                        
                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: 2
                                            
                                            Label {
                                                text: model.fecha_vencimiento || "Sin fecha"
                                                color: "#E74C3C"
                                                font.bold: true
                                                font.pixelSize: 9
                                                Layout.alignment: Qt.AlignHCenter
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // Estado vacío
                            Rectangle {
                                anchors.centerIn: parent
                                width: 300
                                height: 100
                                color: "transparent"
                                visible: detallesCompraModel.count === 0
                                
                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    
                                    Label {
                                        text: "📦"
                                        font.pixelSize: 32
                                        color: "#BDC3C7"
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                    
                                    Label {
                                        text: "No se encontraron productos"
                                        color: "#7F8C8D"
                                        font.pixelSize: 14
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            visible: mostrandoMenuContextual
                            z: 5
                            onClicked: {
                                mostrandoMenuContextual = false
                                compraMenuContextual = null
                            }
                        }
                    }
                }
            }
            
            // RESUMEN CORREGIDO
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                color: "#2C3E50"
                radius: 8
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 30
                    
                    // Total productos
                    RowLayout {
                        spacing: 8
                        
                        Rectangle {
                            width: 30
                            height: 30
                            color: "#3498DB"
                            radius: 15
                            
                            Label {
                                anchors.centerIn: parent
                                text: "📦"
                                font.pixelSize: 14
                            }
                        }
                        
                        ColumnLayout {
                            spacing: 2
                            
                            Label {
                                text: "Productos:"
                                color: "#BDC3C7"
                                font.pixelSize: 11
                            }
                            
                            Label {
                                text: detallesCompraModel.count.toString()
                                color: "#FFFFFF"
                                font.bold: true
                                font.pixelSize: 14
                            }
                        }
                    }
             
                    // Total compra (CORREGIDO)
                    RowLayout {
                        spacing: 8
                        
                        Rectangle {
                            width: 35
                            height: 35
                            color: "#27AE60"
                            radius: 17
                            
                            Label {
                                anchors.centerIn: parent
                                text: "💰"
                                font.pixelSize: 16
                            }
                        }
                        
                        ColumnLayout {
                            spacing: 2
                            
                            Label {
                                text: "TOTAL GASTADO:"
                                color: "#BDC3C7"
                                font.pixelSize: 12
                                font.bold: true
                            }
                            
                            Label {
                                text: "Bs" + (selectedPurchase ? selectedPurchase.total.toFixed(2) : "0.00")
                                color: "#FFFFFF"
                                font.bold: true
                                font.pixelSize: 16
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MODAL DE CONFIRMACIÓN DE ELIMINACIÓN
    Rectangle {
        id: deleteConfirmOverlay
        anchors.fill: parent
        color: "#000000"
        opacity: 0.7
        visible: showDeleteConfirmDialog
        z: 1000
        
        MouseArea {
            anchors.fill: parent
            onClicked: {
                showDeleteConfirmDialog = false
            }
        }
    }

    Rectangle {
        id: deleteConfirmDialog
        anchors.centerIn: parent
        width: 400
        height: 200
        
        visible: showDeleteConfirmDialog
        z: 2001
        
        color: "#ffffff"
        radius: 12
        border.color: "#dee2e6"
        border.width: 2
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 20
            
            // Header
            RowLayout {
                Layout.fillWidth: true
                
                Rectangle {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    color: "#dc3545"
                    radius: 20
                    
                    Label {
                        anchors.centerIn: parent
                        text: "⚠️"
                        font.pixelSize: 20
                    }
                }
                
                ColumnLayout {
                    spacing: 4
                    
                    Label {
                        text: "Confirmar Eliminación"
                        color: "#2C3E50"
                        font.bold: true
                        font.pixelSize: 16
                    }
                    
                    Label {
                        text: compraToDelete ? `Compra #${compraToDelete.id} - Bs${compraToDelete.total}` : ""
                        color: "#7F8C8D"
                        font.pixelSize: 12
                    }
                }
                
                Item { Layout.fillWidth: true }
            }
            
            // Mensaje
            Label {
                text: "¿Está seguro de eliminar esta compra?\n\n• Se revertirá el stock de todos los productos\n• Esta acción NO se puede deshacer"
                color: "#495057"
                font.pixelSize: 14
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
            
            // Botones
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                
                Item { Layout.fillWidth: true }
                
                Button {
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 36
                    text: "Cancelar"
                    
                    background: Rectangle {
                        color: parent.pressed ? "#e9ecef" : "#f8f9fa"
                        radius: 18
                        border.color: "#dee2e6"
                        border.width: 1
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        color: "#6c757d"
                        font.bold: true
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        showDeleteConfirmDialog = false
                        compraToDelete = null
                    }
                }
                
                Button {
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 36
                    text: "Eliminar"
                    
                    background: Rectangle {
                        color: parent.pressed ? Qt.darker("#dc3545", 1.1) : "#dc3545"
                        radius: 18
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        color: "#FFFFFF"
                        font.bold: true
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        if (compraToDelete && compraModel && compraModel.eliminar_compra) {
                            console.log("🗑️ Eliminando compra:", compraToDelete.id)
                            var exito = compraModel.eliminar_compra(compraToDelete.id)
                            if (exito) {
                                showNotification("Compra eliminada exitosamente", "success")
                                actualizarPaginacionCompras()
                            }
                        }
                        
                        showDeleteConfirmDialog = false
                        compraToDelete = null
                        selectedPurchase = null  // Limpiar selección
                    }
                }
            }
        }
    }

    // SISTEMA DE NOTIFICACIÓN VISUAL - Agregar antes de Component.onCompleted
    Rectangle {
        id: notificationToast
        anchors.centerIn: parent
        anchors.right: parent.right
        anchors.margins: 20
        anchors.topMargin: 80
        width: 300
        height: 50
        color: "#27ae60"
        radius: 8
        visible: false
        opacity: 0
        z: 2000
        
        property string notificationText: ""
        
        Behavior on opacity {
            NumberAnimation { duration: 300 }
        }
        
        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8
            
            Rectangle {
                width: 20
                height: 20
                color: "#ffffff"
                radius: 10
                
                Label {
                    anchors.centerIn: parent
                    text: "✓"
                    color: "#27ae60"
                    font.bold: true
                    font.pixelSize: 12
                }
            }
            
            Label {
                text: notificationToast.notificationText
                color: "#ffffff"
                font.bold: true
                font.pixelSize: 12
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }
        }
        
        Timer {
            id: hideNotificationTimer
            interval: 3000
            onTriggered: {
                notificationToast.opacity = 0
                notificationToast.visible = false
            }
        }
        
        function showToast(message) {
            notificationText = message
            visible = true
            opacity = 1
            hideNotificationTimer.restart()
        }
    }

    // Función para obtener total de compras
    function getTotalComprasCount() {
        return compraModel ? compraModel.total_compras_mes : 0
    }
    
    // FUNCIÓN DE NOTIFICACIÓN (agregar si no existe)
    function showNotification(message, type) {
        console.log(`[${type.toUpperCase()}] ${message}`)
        if (notificationToast) {
            notificationToast.showToast(message)
        }
    }
    // Conexiones con el modelo
    Connections {
        target: compraModel
        
        function onOperacionExitosa(mensaje) {
            if (mensaje.includes("compra") || mensaje.includes("eliminad")) {
                console.log("📢 Operación exitosa:", mensaje)
                Qt.callLater(actualizarPaginacionCompras)
            }
        }
        
        function onComprasRecientesChanged() {

            actualizarPaginacionCompras()
        }
    }
 
    Component.onCompleted: {
        console.log("=== MÓDULO DE COMPRAS INICIALIZADO ===")
        
        if (!compraModel) {
            console.log("❌ ERROR: CompraModel no disponible")
            return
        }
        
        console.log("✅ CompraModel conectado")
        Qt.callLater(actualizarPaginacionCompras)
    }
}