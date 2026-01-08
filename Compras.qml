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
    property var selectedPurchase: null  // ✅ MANTENER - se usa para menú contextual
    
    // 🚨 NUEVA PROPIEDAD: Diálogo de advertencia por ventas
    property bool showVentasWarningDialog: false
    property var compraConVentas: null

    // MODELO PARA COMPRAS PAGINADAS
    ListModel {
        id: comprasPaginadasModel
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
    
    function obtenerDetallesCompra(compraId) {
        console.log("📋 Abriendo detalle de compra:", compraId)
        
        if (!detalleCompraDialog) {
            console.log("❌ detalleCompraDialog no disponible")
            return
        }
        
        // Abrir el nuevo modal
        detalleCompraDialog.abrir(compraId)
    }

    // Función para cargar compra en edición - MODIFICADA
    function cargarCompraParaEdicion(compraId) {
        console.log("✏️ Cargando compra para edición:", compraId)
        
        // Buscar los datos de la compra
        var compraData = null
        for (var i = 0; i < compraModel.compras_recientes.length; i++) {
            if (compraModel.compras_recientes[i].id === compraId) {
                compraData = compraModel.compras_recientes[i]
                break
            }
        }
        
        // 🚨 NUEVA VERIFICACIÓN: Usar la función del modelo para verificar ventas
        if (compraModel && typeof compraModel.verificar_compras_ventas === "function") {
            console.log("🔍 Verificando si compra tiene ventas asociadas...")
            
            // Llamar al método del backend para verificar ventas
            var tieneVentas = compraModel.verificar_compras_ventas(compraId)
            
            if (tieneVentas) {
                console.log("🚨 Compra", compraId, "TIENE ventas asociadas - No se puede editar")
                
                // Mostrar diálogo de advertencia
                compraConVentas = compraData
                showVentasWarningDialog = true
                
                // También mostrar notificación toast
                showNotification(
                    "No se puede editar esta compra",
                    "Ya tiene ventas asociadas en el sistema",
                    "error"
                )
                
                // NO NAVEGAR A EDICIÓN - SALIR AQUÍ
                return
            } else {
                console.log("✅ Compra", compraId, "NO tiene ventas asociadas - Proceder con edición")
            }
        } else {
            console.log("⚠️ Modelo no tiene función verificar_compras_ventas")
        }
        
        // Si llegamos aquí, no hay ventas o no podemos verificar - proceder con edición
        console.log("📝 Procediendo con edición de compra:", compraId)
        
        // Llamar al método del modelo para cargar los datos
        var exito = compraModel.cargar_compra_para_edicion(compraId)
        
        if (exito) {
            // Emitir señal para navegar a CrearCompra
            navegarAEditarCompra(compraId, compraData)
        } else {
            console.log("❌ Error cargando compra para edición")
            showNotification("Error", "No se pudo cargar la compra para edición", "error")
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
                                
                                // NUEVA COLUMNA: PRODUCTOS - Mejorada visualmente
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
                                        
                                        // Badge de cantidad mejorado
                                        Rectangle {
                                            Layout.preferredWidth: 28
                                            Layout.preferredHeight: 28
                                            color: "#2196F3"
                                            radius: 14
                                            border.color: "#1976D2"
                                            border.width: 1
                                            
                                            Label {
                                                anchors.centerIn: parent
                                                text: model.total_productos || 0
                                                color: "#FFFFFF"
                                                font.bold: true
                                                font.pixelSize: 12
                                            }
                                        }
                                        
                                        // Texto de productos mejorado
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
                                            console.log("👁️ Ver detalle de compra, ID:", model.id)
                                            obtenerDetallesCompra(model.id)
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

    // ============================================================================
    // MODAL DE DETALLE DE COMPRA - NUEVO COMPONENTE
    // ============================================================================
    DetalleCompra {
        id: detalleCompraDialog
        visible: false
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
        height: 300
        
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
    
    // 🚨 NUEVO: MODAL DE ADVERTENCIA POR VENTAS ASOCIADAS
    Rectangle {
        id: ventasWarningOverlay
        anchors.fill: parent
        color: "#000000"
        opacity: 0.7
        visible: showVentasWarningDialog
        z: 1000
        
        MouseArea {
            anchors.fill: parent
            onClicked: {
                showVentasWarningDialog = false
            }
        }
    }
    
    Rectangle {
        id: ventasWarningDialog
        anchors.centerIn: parent
        width: 450
        height: 320
        
        visible: showVentasWarningDialog
        z: 2001
        
        color: "#ffffff"
        radius: 12
        border.color: "#FF9800"
        border.width: 2
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 20
            
            // Header con icono de advertencia
            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                
                Rectangle {
                    Layout.preferredWidth: 50
                    Layout.preferredHeight: 50
                    color: "#FFF3E0"
                    radius: 25
                    border.color: "#FF9800"
                    border.width: 2
                    
                    Label {
                        anchors.centerIn: parent
                        text: "⚠️"
                        font.pixelSize: 24
                        color: "#FF9800"
                    }
                }
                
                ColumnLayout {
                    spacing: 4
                    
                    Label {
                        text: "Compra con ventas asociadas"
                        color: "#E65100"
                        font.bold: true
                        font.pixelSize: 18
                    }
                    
                    Label {
                        text: compraConVentas ? `Compra #${compraConVentas.id} - ${compraConVentas.proveedor}` : ""
                        color: "#7F8C8D"
                        font.pixelSize: 14
                    }
                }
            }
            
            // Mensaje de advertencia
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#FFF9C4"
                radius: 8
                border.color: "#FFD54F"
                border.width: 1
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12
                    
                    Label {
                        text: "🚨 No se puede editar esta compra"
                        color: "#E65100"
                        font.bold: true
                        font.pixelSize: 14
                    }
                    
                    ColumnLayout {
                        spacing: 8
                        
                        Label {
                            text: "• Tiene ventas asociadas en el sistema"
                            color: "#5D4037"
                            font.pixelSize: 12
                        }
                        
                        Label {
                            text: "• Los productos ya fueron vendidos parcial o totalmente"
                            color: "#5D4037"
                            font.pixelSize: 12
                        }
                        
                        Label {
                            text: "• Para modificar, debe eliminar primero las ventas"
                            color: "#5D4037"
                            font.pixelSize: 12
                        }
                        
                        Label {
                            text: "• O crear una nueva compra con los ajustes"
                            color: "#5D4037"
                            font.pixelSize: 12
                        }
                    }
                    
                    Label {
                        text: "📋 Consejo: Use la opción 'Ver' para revisar las ventas asociadas"
                        color: "#1976D2"
                        font.pixelSize: 11
                        font.italic: true
                    }
                }
            }
            
            // Botones
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                
                Item { Layout.fillWidth: true }
                
                Button {
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 40
                    text: "Ver Detalle"
                    
                    background: Rectangle {
                        color: parent.pressed ? Qt.darker(blueColor, 1.1) : blueColor
                        radius: 20
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        color: "#FFFFFF"
                        font.bold: true
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        if (compraConVentas) {
                            obtenerDetallesCompra(compraConVentas.id)
                        }
                        showVentasWarningDialog = false
                        compraConVentas = null
                    }
                }
                
                Button {
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 40
                    text: "Entendido"
                    
                    background: Rectangle {
                        color: parent.pressed ? "#E0E0E0" : "#F5F5F5"
                        radius: 20
                        border.color: "#BDBDBD"
                        border.width: 1
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        color: "#424242"
                        font.bold: true
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        showVentasWarningDialog = false
                        compraConVentas = null
                    }
                }
            }
        }
    }

    // 🚀 SISTEMA DE NOTIFICACIÓN 
    Rectangle {
        id: notificationToast
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 80
        width: 400
        height: 80
        color: notificationToast.notificationType === "fifo" ? "#2196F3" : 
               notificationToast.notificationType === "error" ? "#E74C3C" : "#27ae60"
        radius: 12
        visible: false
        opacity: 0
        z: 2000
        
        property string notificationText: ""
        property string notificationType: "success"  // "success", "fifo", "error"
        property string notificationSubtext: ""
        
        // Sombra simple con Rectangle
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 4
            color: "#40000000"
            radius: 12
            z: -1
        }
        
        Behavior on opacity {
            NumberAnimation { duration: 300 }
        }
        
        RowLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12
            
            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                color: "#ffffff"
                radius: 20
                
                Label {
                    anchors.centerIn: parent
                    text: notificationToast.notificationType === "fifo" ? "🚀" : 
                          notificationToast.notificationType === "error" ? "❌" : "✅"
                    font.pixelSize: 20
                }
            }
            
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                
                Label {
                    text: notificationToast.notificationText
                    color: "#ffffff"
                    font.bold: true
                    font.pixelSize: 14
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
                
                Label {
                    visible: notificationToast.notificationSubtext !== ""
                    text: notificationToast.notificationSubtext
                    color: "#E3F2FD"
                    font.pixelSize: 11
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }
        }
        
        Timer {
            id: hideNotificationTimer
            interval: 4000
            onTriggered: {
                notificationToast.opacity = 0
                notificationToast.visible = false
            }
        }
        
        function showToast(message, subtext, type) {
            notificationText = message
            notificationSubtext = subtext || ""
            notificationType = type || "success"
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
    function showNotification(message, subtext, type) {
        console.log(`[${(type || 'success').toUpperCase()}] ${message}`)
        if (notificationToast) {
            notificationToast.showToast(message, subtext || "", type || "success")
        }
    }
    
    // 🚀 Conexiones mejoradas con el modelo
    Connections {
        target: compraModel
        
        // 🚀 NUEVO: Detectar compras FIFO 2.0
        function onCompraCreada(compraId, total) {
            console.log("🚀 Nueva compra creada - ID:", compraId, "Total:", total)
            
            // Mostrar notificación FIFO 2.0
            showNotification(
                `Compra #${compraId} registrada exitosamente`,
                `Total: Bs${total.toFixed(2)} - Sistema FIFO 2.0`,
                "fifo"
            )
            
            // Actualizar lista
            Qt.callLater(actualizarPaginacionCompras)
        }
        
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