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
    
    // MODELO PARA COMPRAS PAGINADAS
    ListModel {
        id: comprasPaginadasModel
    }
    ListModel {
        id: detallesCompraModel
    }
    
    // CONEXIÓN CON DATOS CENTRALES
    Connections {
        target: compraModel
        function onComprasRecientesChanged() {
            console.log("🚚 Compras: Compras recientes actualizadas")
            actualizarPaginacionCompras()
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
                
                // Campos adicionales para compatibilidad
                "Proveedor_Nombre": compraRaw.Proveedor_Nombre || "",
                "Usuario": compraRaw.Usuario || "",
                "Total": compraRaw.Total || 0.0,
                "Id_Proveedor": compraRaw.Id_Proveedor || 0,
                "Id_Usuario": compraRaw.Id_Usuario || 0
            }
            comprasPaginadasModel.append(compraQML)
        }
        
        console.log("📄 Compras: Página", currentPageCompras + 1, "de", totalPagesCompras, 
                    "- Mostrando", comprasPaginadasModel.count, "de", totalItems)
        
        // DEBUG: Verificar modelo final
        if (comprasPaginadasModel.count > 0) {
            console.log("🔍 DEBUG QML - Primer elemento en modelo:", JSON.stringify(comprasPaginadasModel.get(0)))
        }
    }
    
    // Función para obtener detalles de una compra
    function obtenerDetallesCompra(compraId) {
        if (!compraModel) return
        
        console.log("🔍 Buscando detalles para:", compraId)
        
        // Limpiar modelo antes de cargar nuevos datos
        detallesCompraModel.clear()
        
        var detalleCompra = compraModel.get_compra_detalle(compraId)
        console.log("🔍 DEBUG: detalleCompra recibido:", JSON.stringify(detalleCompra))
        
        if (detalleCompra && detalleCompra.detalles) {
            console.log("🔍 DEBUG: detalles encontrados:", detalleCompra.detalles.length)
            var items = detalleCompra.detalles
            
            for (var i = 0; i < items.length; i++) {
                var item = items[i]
                detallesCompraModel.append({
                    codigo: item.Producto_Codigo || "",
                    nombre: item.Producto_Nombre || "Producto no encontrado",
                    cajas: item.Cantidad_Caja || 0,
                    stockTotal: (item.Cantidad_Caja || 0) + (item.Cantidad_Unitario || 0),
                    precioCompra: item.Precio_Unitario || 0
                })
            }
            
            console.log("📦 Items agregados al modelo:", detallesCompraModel.count)
        } else {
            console.log("❌ DEBUG: No se encontraron detalles")
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

        // Filtros de búsqueda
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 12
            spacing: 16
            
            Label {
                text: "🔍"
                font.pixelSize: 16
            }
            
            TextField {
                Layout.preferredWidth: 200
                placeholderText: "Buscar compras..."
                background: Rectangle {
                    color: lightGrayColor
                    radius: 8
                    border.color: darkGrayColor
                    border.width: 1
                }
            }

            Item { Layout.fillWidth: true }
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
                
                // Header de la tabla
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50
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
                                text: "ID COMPRA"
                                color: "#2C3E50"
                                font.bold: true
                                font.pixelSize: 12
                            }
                        }
                        
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
                                text: "PROVEEDOR"
                                color: "#2C3E50"
                                font.bold: true
                                font.pixelSize: 12
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
                                text: "USUARIO"
                                color: "#2C3E50"
                                font.bold: true
                                font.pixelSize: 12
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
                                text: "TOTAL"
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
                                text: "ACCIÓN"
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
                                color: comprasTable.currentIndex === index ? "#E3F2FD" : "transparent"
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
                                        text: model.id
                                        color: "#3498DB"
                                        font.bold: true
                                        font.pixelSize: 14
                                    }
                                }
                                
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 250
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
                                            Layout.maximumWidth: 220
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
                                            text: "👤"
                                            font.pixelSize: 12
                                        }
                                        
                                        Label {
                                            text: model.usuario
                                            color: "#2C3E50"
                                            font.pixelSize: 12
                                        }
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 140
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
                                                text: "📅"
                                                font.pixelSize: 10
                                                color: "#3498DB"
                                            }
                                            
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
                                
                                Rectangle {
                                    Layout.preferredWidth: 120
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#D5DBDB"
                                    border.width: 1
                                    
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 90
                                        height: 28
                                        color: "#27AE60"
                                        radius: 14
                                        
                                        Label {
                                            anchors.centerIn: parent
                                            text: "Bs" + model.total.toFixed(2)
                                            color: "#FFFFFF"
                                            font.bold: true
                                            font.pixelSize: 11
                                        }
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
                                            font.pixelSize: 12
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
                                anchors.rightMargin: 100
                                
                                onClicked: {
                                    comprasTable.currentIndex = index
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
        width: Math.min(700, parent.width * 0.9)
        height: Math.min(500, parent.height * 0.9)
        
        visible: showPurchaseDetailsDialog
        z: 1001
        
        color: "#ffffff"
        radius: 8
        border.color: "#dee2e6"
        border.width: 1
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16
            
            // Header
            RowLayout {
                Layout.fillWidth: true
                
                Label {
                    text: "Detalles de Compra: " + (selectedPurchase ? selectedPurchase.id : "")
                    color: "#2C3E50"
                    font.bold: true
                    font.pixelSize: 16
                }
                
                Item { Layout.fillWidth: true }
                
                Button {
                    text: "Cerrar"
                    width: 80
                    height: 32
                    background: Rectangle {
                        color: "#ECF0F1"
                        radius: 4
                        border.color: "#BDC3C7"
                        border.width: 1
                    }
                    contentItem: Label {
                        text: parent.text
                        color: "#5D6D7E"
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: showPurchaseDetailsDialog = false
                }
            }
            
            // Tabla de productos
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#FFFFFF"
                border.color: "#D5DBDB"
                border.width: 1
                
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0
                    
                    // Header de tabla
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
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
                                    text: "CÓDIGO"
                                    font.bold: true
                                    font.pixelSize: 12
                                }
                            }
                            
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                color: "#F8F9FA"
                                border.color: "#D5DBDB"
                                border.width: 1
                                Label {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "NOMBRE"
                                    font.bold: true
                                    font.pixelSize: 12
                                }
                            }
                            
                            Rectangle {
                                Layout.preferredWidth: 80
                                Layout.fillHeight: true
                                color: "#F8F9FA"
                                border.color: "#D5DBDB"
                                border.width: 1
                                Label {
                                    anchors.centerIn: parent
                                    text: "CAJA"
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
                                    text: "STOCK UNIDAD"
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
                                    text: "PRECIO COMPRA"
                                    font.bold: true
                                    font.pixelSize: 12
                                }
                            }
                        }
                    }
                    
                    // Contenido scrolleable
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        
                        ListView {
                            model: detallesCompraModel
                            
                            delegate: Rectangle {
                                width: ListView.view.width
                                height: 50
                                color: "#FFFFFF"
                                
                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 0
                                    
                                    Rectangle {
                                        Layout.preferredWidth: 100
                                        Layout.fillHeight: true
                                        border.color: "#D5DBDB"
                                        border.width: 1
                                        Label {
                                            anchors.centerIn: parent
                                            text: model.codigo || ""
                                            font.pixelSize: 11
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        border.color: "#D5DBDB"
                                        border.width: 1
                                        Label {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: model.nombre || ""
                                            font.pixelSize: 11
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: 80
                                        Layout.fillHeight: true
                                        border.color: "#D5DBDB"
                                        border.width: 1
                                        Label {
                                            anchors.centerIn: parent
                                            text: model.cajas || "0"
                                            font.pixelSize: 11
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: 100
                                        Layout.fillHeight: true
                                        border.color: "#D5DBDB"
                                        border.width: 1
                                        Label {
                                            anchors.centerIn: parent
                                            text: model.stockTotal || "0"
                                            font.pixelSize: 11
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: 120
                                        Layout.fillHeight: true
                                        border.color: "#D5DBDB"
                                        border.width: 1
                                        Label {
                                            anchors.centerIn: parent
                                            text: "Bs" + (model.precioCompra ? model.precioCompra.toFixed(2) : "0.00")
                                            font.pixelSize: 11
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Función para obtener total de compras
    function getTotalComprasCount() {
        return compraModel ? compraModel.total_compras_mes : 0
    }

    Component.onCompleted: {
        console.log("=== MÓDULO DE COMPRAS SIMPLIFICADO INICIALIZADO ===")

        if (!compraModel) {
            console.log("❌ ERROR: CompraModel no está disponible")
            return
        }
        
        console.log("✅ CompraModel conectado correctamente")
        actualizarPaginacionCompras()
        console.log("=== MÓDULO LISTO ===")
    }
}