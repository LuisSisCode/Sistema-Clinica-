import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

// Componente principal del módulo de Proveedores
Item {
    id: proveedoresRoot
    objectName: "proveedoresRoot"
    
    // Propiedades de control
    property var proveedorModel: appController ? appController.proveedor_model_instance : null
    property bool showProveedorDetailsDialog: false
    property bool showCreateProveedorDialog: false
    property bool showDeleteConfirmDialog: false
    property var selectedProveedor: null
    property var proveedorToDelete: null
    property bool editMode: false
    
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
    
    // CONEXIÓN CON DATOS CENTRALES
    Connections {
        target: proveedorModel
        function onProveedoresChanged() {
            console.log("🏢 Proveedores: Lista actualizada")
        }
        function onOperacionExitosa(mensaje) {
            console.log("✅ Operación exitosa:", mensaje)
            showNotification(mensaje, "success")
        }
        function onOperacionError(mensaje) {
            console.log("❌ Error:", mensaje)
            showNotification(mensaje, "error")
        }
        function onProveedorCreado(id, nombre) {
            console.log("✅ Proveedor creado:", nombre)
            showCreateProveedorDialog = false
        }
        function onProveedorActualizado(id, nombre) {
            console.log("✅ Proveedor actualizado:", nombre)
            showCreateProveedorDialog = false
        }
        function onProveedorEliminado(id, nombre) {
            console.log("🗑️ Proveedor eliminado:", nombre)
            showDeleteConfirmDialog = false
        }
    }
    Connections {
        target: typeof compraModel !== 'undefined' ? compraModel : null
        function onCompraCreada(compraId, total) {
            console.log("🛒 Nueva compra detectada:", compraId, "Total:", total)
            console.log("🔄 Refrescando proveedores automáticamente...")
            
            // Refresh automático después de 1 segundo
            Qt.callLater(function() {
                if (proveedorModel) {
                    proveedorModel.force_complete_refresh()
                }
            })
        }
        
        function onProveedorDatosActualizados() {
            console.log("📢 Signal: Datos de proveedores actualizados por compra")
            // El refresh ya se hizo automáticamente
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
            
            // Información del módulo - SECCIÓN ACTUALIZADA CON NUEVO ICONO
            RowLayout {
                spacing: 12
                
                // ✅ CONTENEDOR DEL ICONO - USANDO MEDIDAS DE ENFERMERÍA
                Rectangle {
                    Layout.preferredWidth: 60  // Fallback para compatibilidad
                    Layout.preferredHeight: 60
                    color: "transparent"
                    
                    Image {
                        anchors.centerIn: parent
                        width: Math.min(48, parent.width * 0.8)
                        height: Math.min(48, parent.height * 0.8)
                        source: "Resources/iconos/proveedor.png"  // ✅ ICONO ACTUALIZADO
                        fillMode: Image.PreserveAspectFit
                        antialiasing: true  // ✅ MEJORA VISUAL
                        smooth: true
                        
                        // ✅ DEBUGGING - VERIFICAR CARGA DEL ICONO
                        onStatusChanged: {
                            if (status === Image.Error) {
                                console.log("❌ Error cargando icono de proveedor:", source)
                            } else if (status === Image.Ready) {
                                console.log("✅ Icono de proveedor cargado correctamente:", source)
                            }
                        }
                    }
                    
                    // ✅ INTERACCIÓN VISUAL MEJORADA
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
                    
                    // ✅ GESTIÓN DE PROVEEDORES CON ICONO
                    RowLayout {
                        spacing: 8  // Espacio entre icono y texto
                        
                        
                        Label {
                            text: "Gestión de Proveedores"
                            color: darkGrayColor
                            font.pixelSize: 14
                        }
                    }
                }
            }
            
            Item { Layout.fillWidth: true }
            
            // Estadísticas en tiempo real
            RowLayout {
                spacing: 16
                
                Rectangle {
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 60
                    color: "#E8F5E8"
                    radius: 8
                    border.color: successColor
                    border.width: 1
                    
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        
                        Label {
                            text: "Total:"
                            font.pixelSize: 10
                            color: darkGrayColor
                            Layout.alignment: Qt.AlignHCenter
                        }
                        
                        Label {
                            text: proveedorModel ? proveedorModel.total_proveedores.toString() : "0"
                            font.pixelSize: 18
                            font.bold: true
                            color: successColor
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
                
                Rectangle {
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 60
                    color: "#E3F2FD"
                    radius: 8
                    border.color: blueColor
                    border.width: 1
                    
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        
                        Label {
                            text: "Activos:"
                            font.pixelSize: 10
                            color: darkGrayColor
                            Layout.alignment: Qt.AlignHCenter
                        }
                        
                        Label {
                            text: {
                                if (!proveedorModel || !proveedorModel.resumen) return "0"
                                var resumen = proveedorModel.resumen.resumen || {}
                                return (resumen.Proveedores_Activos || 0).toString()
                            }
                            font.pixelSize: 18
                            font.bold: true
                            color: blueColor
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }
            
            // Botón de Nuevo Proveedor
            Button {
                id: nuevoProveedorButton
                Layout.preferredWidth: 230
                Layout.preferredHeight: 75
                
                background: Rectangle {
                    color: parent.pressed ? Qt.darker(successColor, 1.2) : successColor
                    radius: 8
                    
                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                    
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
                        text: "Nuevo Proveedor"
                        color: whiteColor
                        font.bold: true
                        font.pixelSize: 18
                    }
                }
                
                onClicked: {
                    console.log("🏢 Abriendo modal Nuevo Proveedor")
                    editMode = false
                    selectedProveedor = null
                    showCreateProveedorDialog = true
                }
                
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

        // Filtros de búsqueda y controles
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 12
            spacing: 16
            
            Label {
                text: "🔍"
                font.pixelSize: 16
            }
            
            TextField {
                id: searchField
                Layout.preferredWidth: 300
                Layout.preferredHeight: 40
                placeholderText: "Buscar proveedores por nombre, dirección o contacto..."
                
                background: Rectangle {
                    color: lightGrayColor
                    radius: 8
                    border.color: searchField.activeFocus ? primaryColor : darkGrayColor
                    border.width: searchField.activeFocus ? 2 : 1
                    
                    Behavior on border.color {
                        ColorAnimation { duration: 150 }
                    }
                }
                
                onTextChanged: {
                    if (proveedorModel) {
                        proveedorModel.buscar_proveedores(text)
                    }
                }
            }

            Button {
                Layout.preferredWidth: 100
                Layout.preferredHeight: 40
                text: "Limpiar"
                
                background: Rectangle {
                    color: parent.pressed ? Qt.darker(warningColor, 1.1) : warningColor
                    radius: 8
                }
                
                contentItem: Label {
                    text: parent.text
                    color: whiteColor
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: {
                    searchField.text = ""
                    if (proveedorModel) {
                        proveedorModel.limpiar_busqueda()
                    }
                }
            }

            Item { Layout.fillWidth: true }
            
            Button {
                id: refreshButton
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                
                property bool isRefreshing: false
                property int refreshCounter: 0
                
                background: Rectangle {
                    color: {
                        if (refreshButton.isRefreshing) return "#f39c12"  // Orange cuando está refrescando
                        if (parent.pressed) return Qt.darker("#3498db", 1.2)
                        return "#3498db"  // Blue normal
                    }
                    radius: 20
                    
                    // Animación de rotación cuando está refrescando
                    RotationAnimation {
                        id: rotationAnimation
                        target: refreshIcon
                        from: 0
                        to: 360
                        duration: 1000
                        running: refreshButton.isRefreshing
                        loops: Animation.Infinite
                    }
                }
                
                contentItem: Label {
                    id: refreshIcon
                    text: refreshButton.isRefreshing ? "⏳" : "🔄"
                    color: "#ffffff"
                    font.pixelSize: 16
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: {
                    performCompleteRefresh()
                }
                
                ToolTip.visible: hovered
                ToolTip.text: {
                    if (isRefreshing) return "Actualizando proveedores..."
                    if (refreshCounter > 0) return `Actualizado ${refreshCounter} veces`
                    return "Actualizar lista de proveedores (fuerza recarga desde BD)"
                }
            }
        }

        // Tabla de proveedores
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: whiteColor
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
                            Layout.preferredWidth: 80
                            Layout.fillHeight: true
                            color: "#F8F9FA"
                            border.color: "#D5DBDB"
                            border.width: 1
                            
                            Label {
                                anchors.centerIn: parent
                                text: "ID"
                                color: textColor
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
                                text: "NOMBRE"
                                color: textColor
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
                                text: "DIRECCIÓN"
                                color: textColor
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
                                text: "COMPRAS"
                                color: textColor
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
                                text: "TOTAL GASTADO"
                                color: textColor
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
                                text: "ESTADO"
                                color: textColor
                                font.bold: true
                                font.pixelSize: 12
                            }
                        }
                        
                        Rectangle {
                            Layout.preferredWidth: 150
                            Layout.fillHeight: true
                            color: "#F8F9FA"
                            border.color: "#D5DBDB"
                            border.width: 1
                            
                            Label {
                                anchors.centerIn: parent
                                text: "ACCIONES"
                                color: textColor
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
                        id: proveedoresTable
                        anchors.fill: parent
                        model: proveedorModel ? proveedorModel.proveedores : []
                        
                        delegate: Item {
                            width: proveedoresTable.width
                            height: 70
                            
                            // ✅ AGREGAR DEBUG PARA VER LOS DATOS
                            Component.onCompleted: {
                                console.log("🔍 DEBUG Proveedor item:", JSON.stringify(modelData))
                            }
                            
                            Rectangle {
                                anchors.fill: parent
                                color: proveedoresTable.currentIndex === index ? "#E3F2FD" : "transparent"
                                opacity: 0.3
                            }
                            
                            RowLayout {
                                anchors.fill: parent
                                spacing: 0
                                
                                // ID - ✅ CORREGIDO
                                Rectangle {
                                    Layout.preferredWidth: 80
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#D5DBDB"
                                    border.width: 1
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: modelData.id || model.id || 0  // ✅ PROBAR AMBAS PROPIEDADES
                                        color: blueColor
                                        font.bold: true
                                        font.pixelSize: 14
                                    }
                                }
                                
                                // NOMBRE - ✅ CORREGIDO
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
                                            text: modelData.Nombre || model.Nombre || "Proveedor sin nombre"  // ✅ PROBAR AMBAS
                                            color: textColor
                                            font.bold: true
                                            font.pixelSize: 13
                                            elide: Text.ElideRight
                                            Layout.maximumWidth: 180
                                        }
                                        
                                        Label {
                                            text: "Proveedor"  // ✅ TEXTO FIJO YA QUE NO HAY CONTACTO
                                            color: darkGrayColor
                                            font.pixelSize: 10
                                            elide: Text.ElideRight
                                            Layout.maximumWidth: 180
                                        }
                                    }
                                }
                                
                                // DIRECCIÓN - ✅ CORREGIDO
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
                                        spacing: 2
                                        
                                        Label {
                                            text: modelData.Direccion || model.Direccion || "Sin dirección especificada"  // ✅ PROBAR AMBAS
                                            color: textColor
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                            Layout.maximumWidth: 230
                                            Layout.fillWidth: true
                                        }
                                        
                                        Label {
                                            text: ""  // ✅ VACÍO YA QUE NO HAY EMAIL/TELÉFONO
                                            color: darkGrayColor
                                            font.pixelSize: 10
                                            elide: Text.ElideRight
                                            Layout.maximumWidth: 230
                                        }
                                    }
                                }
                                
                                // COMPRAS - ✅ CORREGIDO
                                Rectangle {
                                    Layout.preferredWidth: 120
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#D5DBDB"
                                    border.width: 1
                                    
                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 4
                                        
                                        Rectangle {
                                            Layout.alignment: Qt.AlignHCenter
                                            width: 35
                                            height: 20
                                            color: blueColor
                                            radius: 10
                                            
                                            Label {
                                                anchors.centerIn: parent
                                                text: getProveedorField(modelData, model, "Total_Compras", 0)
                                                color: whiteColor
                                                font.bold: true
                                                font.pixelSize: 10
                                            }
                                        }
                                        
                                        Label {
                                            text: {
                                                var fecha = getSafeDate(modelData, model, "Ultima_Compra")
                                                if (!fecha) return "Sin compras"
                                                return "Última: " + formatDate(fecha)
                                            }
                                            color: darkGrayColor
                                            font.pixelSize: 9
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                    }
                                }
                                
                                // TOTAL GASTADO - ✅ CORREGIDO
                                Rectangle {
                                    Layout.preferredWidth: 120
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#D5DBDB"
                                    border.width: 1
                                    
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 100
                                        height: 28
                                        color: successColor
                                        radius: 14
                                        
                                        Label {
                                            anchors.centerIn: parent
                                            text: {
                                                var monto = getProveedorField(modelData, model, "Monto_Total", 0)
                                                return "Bs" + parseFloat(monto).toFixed(2)
                                            }
                                            color: whiteColor
                                            font.bold: true
                                            font.pixelSize: 10
                                        }
                                    }
                                }
                                
                                // ESTADO - ✅ CORREGIDO
                                Rectangle {
                                    Layout.preferredWidth: 100
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#D5DBDB"
                                    border.width: 1
                                    
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 80
                                        height: 24
                                        color: {
                                            var estado = modelData.Estado || model.Estado || "Sin_Compras"
                                            switch(estado) {
                                                case "Activo": return successColor
                                                case "Inactivo": return warningColor
                                                case "Sin_Compras": return darkGrayColor
                                                case "Obsoleto": return dangerColor
                                                default: return darkGrayColor
                                            }
                                        }
                                        radius: 12
                                        
                                        Label {
                                            anchors.centerIn: parent
                                            text: {
                                                var estado = modelData.Estado || model.Estado || "Sin_Compras"
                                                switch(estado) {
                                                    case "Activo": return "Activo"
                                                    case "Inactivo": return "Inactivo"
                                                    case "Sin_Compras": return "Sin Compras"
                                                    case "Obsoleto": return "Obsoleto"
                                                    default: return "Desconocido"
                                                }
                                            }
                                            color: whiteColor
                                            font.bold: true
                                            font.pixelSize: 9
                                        }
                                    }
                                }
                                
                                // ACCIONES - ✅ MANTENER IGUAL PERO CORREGIR IDs
                                Rectangle {
                                    Layout.preferredWidth: 150
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#D5DBDB"
                                    border.width: 1
                                    
                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        
                                        // Botón Ver
                                        Button {
                                            width: 32
                                            height: 32
                                            
                                            background: Rectangle {
                                                color: parent.pressed ? Qt.darker(blueColor, 1.2) : blueColor
                                                radius: 16
                                            }
                                            
                                            contentItem: Label {
                                                text: "👁️"
                                                color: whiteColor
                                                font.pixelSize: 12
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            
                                            onClicked: {
                                                var id = modelData.id || model.id || 0  // ✅ CORREGIDO
                                                console.log("👁️ Ver detalles proveedor:", id)
                                                selectedProveedor = modelData || model
                                                if (proveedorModel && id > 0) {
                                                    proveedorModel.seleccionar_proveedor(id)
                                                }
                                                showProveedorDetailsDialog = true
                                            }
                                        }
                                        
                                        // Botón Editar
                                        Button {
                                            width: 32
                                            height: 32
                                            
                                            background: Rectangle {
                                                color: parent.pressed ? Qt.darker(warningColor, 1.2) : warningColor
                                                radius: 16
                                            }
                                            
                                            contentItem: Label {
                                                text: "✏️"
                                                color: whiteColor
                                                font.pixelSize: 12
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            
                                            onClicked: {
                                                var id = modelData.id || model.id || 0  // ✅ CORREGIDO
                                                console.log("✏️ Editar proveedor:", id)
                                                editMode = true
                                                selectedProveedor = modelData || model
                                                showCreateProveedorDialog = true
                                            }
                                        }
                                        
                                        // Botón Eliminar
                                        Button {
                                            width: 32
                                            height: 32
                                            
                                            background: Rectangle {
                                                color: parent.pressed ? Qt.darker(dangerColor, 1.2) : dangerColor
                                                radius: 16
                                            }
                                            
                                            contentItem: Label {
                                                text: "🗑️"
                                                color: whiteColor
                                                font.pixelSize: 12
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            
                                            onClicked: {
                                                var id = modelData.id || model.id || 0  // ✅ CORREGIDO
                                                console.log("🗑️ Confirmar eliminar proveedor:", id)
                                                proveedorToDelete = modelData || model
                                                showDeleteConfirmDialog = true
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // MouseArea para seleccionar fila - ✅ CORREGIDO
                            MouseArea {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                anchors.rightMargin: 150
                                
                                onClicked: {
                                    proveedoresTable.currentIndex = index
                                }
                                
                                onDoubleClicked: {
                                    var id = modelData.id || model.id || 0  // ✅ CORREGIDO
                                    selectedProveedor = modelData || model
                                    if (proveedorModel && id > 0) {
                                        proveedorModel.seleccionar_proveedor(id)
                                    }
                                    showProveedorDetailsDialog = true
                                }
                            }
                        }
                        
                        // Estado vacío
                        Item {
                            anchors.centerIn: parent
                            visible: !proveedorModel || (proveedorModel.proveedores && proveedorModel.proveedores.length === 0)
                            width: 300
                            height: 200
                            
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 16
                                
                                Label {
                                    text: "🏢"
                                    font.pixelSize: 48
                                    color: lightGrayColor
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                
                                Label {
                                    text: "No hay proveedores registrados"
                                    color: darkGrayColor
                                    font.pixelSize: 16
                                    font.bold: true
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                
                                Label {
                                    text: "Los proveedores aparecerán aquí cuando se registren"
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
                            enabled: proveedorModel ? proveedorModel.pagina_actual > 1 : false
                            
                            background: Rectangle {
                                color: parent.enabled ? 
                                    (parent.pressed ? Qt.darker(successColor, 1.1) : successColor) :
                                    "#E5E7EB"
                                radius: 18
                                
                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                            
                            contentItem: Label {
                                text: parent.text
                                color: parent.enabled ? whiteColor : "#9CA3AF"
                                font.bold: true
                                font.pixelSize: 14
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: {
                                if (proveedorModel) {
                                    proveedorModel.pagina_anterior()
                                }
                            }
                        }

                        Label {
                            text: {
                                if (!proveedorModel) return "Página 1 de 1"
                                return `Página ${proveedorModel.pagina_actual} de ${Math.max(1, proveedorModel.total_paginas)}`
                            }
                            color: textColor
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }

                        Button {
                            Layout.preferredWidth: 110
                            Layout.preferredHeight: 36
                            text: "Siguiente →"
                            enabled: proveedorModel ? proveedorModel.pagina_actual < proveedorModel.total_paginas : false
                            
                            background: Rectangle {
                                color: parent.enabled ? 
                                    (parent.pressed ? Qt.darker(successColor, 1.1) : successColor) : 
                                    "#E5E7EB"
                                radius: 18
                                
                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                            
                            contentItem: Label {
                                text: parent.text
                                color: parent.enabled ? whiteColor : "#9CA3AF"
                                font.bold: true
                                font.pixelSize: 14
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: {
                                if (proveedorModel) {
                                    proveedorModel.pagina_siguiente()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // DIALOG CREAR/EDITAR PROVEEDOR - DISEÑO ORIGINAL MANTENIDO
    Dialog {
        id: crearProveedorDialog
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.9, 480)
        height: Math.min(parent.height * 10, 450)
        modal: true
        closePolicy: Popup.NoAutoClose
        visible: showCreateProveedorDialog
        
        title: ""
        
        background: Rectangle {
            color: whiteColor
            radius: 12
            border.color: "#E0E0E0"
            border.width: 1
        }
        
        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            
            // Header con diseño original
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 80
                color: whiteColor
                radius: 12
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 16
                    
                    // Ícono circular a la izquierda
                    Rectangle {
                        Layout.preferredWidth: 50
                        Layout.preferredHeight: 50
                        color: editMode ? "#FF9800" : "#4CAF50"  // Naranja para editar, verde para nuevo
                        radius: 25
                        
                        Label {
                            anchors.centerIn: parent
                            text: editMode ? "✏️" : "➕"
                            font.pixelSize: 20
                        }
                    }
                    
                    // Título
                    ColumnLayout {
                        spacing: 4
                        
                        Label {
                            text: editMode ? "Editar Proveedor" : "Nuevo Proveedor"
                            color: textColor
                            font.bold: true
                            font.pixelSize: 20
                            font.family: "Segoe UI, Arial, sans-serif"
                        }
                        
                        Label {
                            text: editMode ? "Modifica los datos del proveedor" : "Ingresa los datos del nuevo proveedor"
                            color: darkGrayColor
                            font.pixelSize: 12
                            font.family: "Segoe UI, Arial, sans-serif"
                        }
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    // Botón X rojo a la derecha
                    Button {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        
                        background: Rectangle {
                            color: "#F44336"
                            radius: 15
                        }
                        
                        contentItem: Label {
                            text: "✕"
                            color: whiteColor
                            font.bold: true
                            font.pixelSize: 14
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: {
                            showCreateProveedorDialog = false
                        }
                    }
                }
            }
            
            // Contenido del formulario
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 24
                spacing: 20
                
                // Campo Nombre del Proveedor
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    
                    Label {
                        text: "Nombre del Proveedor *"
                        color: textColor
                        font.bold: true
                        font.pixelSize: 14
                        font.family: "Segoe UI, Arial, sans-serif"
                    }
                    
                    TextField {
                        id: nombreProveedorField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 45
                        placeholderText: editMode ? (selectedProveedor ? selectedProveedor.Nombre || "Ej. Laboratorios DROGUERÍA SA" : "Ej. Laboratorios DROGUERÍA SA") : "Ej. Laboratorios DROGUERÍA SA"
                        font.pixelSize: 14
                        font.family: "Segoe UI, Arial, sans-serif"
                        
                        background: Rectangle {
                            color: whiteColor
                            border.color: nombreProveedorField.activeFocus ? "#2196F3" : "#E0E0E0"
                            border.width: nombreProveedorField.activeFocus ? 2 : 1
                            radius: 8
                        }
                        
                        leftPadding: 12
                        rightPadding: 12
                    }
                }
                
                // Campo Dirección
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    
                    Label {
                        text: "Dirección *"
                        color: textColor
                        font.bold: true
                        font.pixelSize: 14
                        font.family: "Segoe UI, Arial, sans-serif"
                    }
                    
                    TextField {
                        id: direccionProveedorField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 45
                        placeholderText: editMode ? (selectedProveedor ? selectedProveedor.Direccion || "Ej. Av. Cristo Redentor #123, Santa Cruz" : "Ej. Av. Cristo Redentor #123, Santa Cruz") : "Ej. Av. Cristo Redentor #123, Santa Cruz"
                        font.pixelSize: 14
                        font.family: "Segoe UI, Arial, sans-serif"
                        
                        background: Rectangle {
                            color: whiteColor
                            border.color: direccionProveedorField.activeFocus ? "#2196F3" : "#E0E0E0"
                            border.width: direccionProveedorField.activeFocus ? 2 : 1
                            radius: 8
                        }
                        
                        leftPadding: 12
                        rightPadding: 12
                    }
                }
                
                // Mensaje informativo
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    color: "#E3F2FD"
                    radius: 8
                    border.color: "#2196F3"
                    border.width: 1
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8
                        
                        Rectangle {
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            color: "#2196F3"
                            radius: 10
                            
                            Label {
                                anchors.centerIn: parent
                                text: "ℹ"
                                color: whiteColor
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }
                        
                        Label {
                            text: "Solo se requiere nombre y dirección del proveedor"
                            color: "#1976D2"
                            font.pixelSize: 12
                            font.family: "Segoe UI, Arial, sans-serif"
                        }
                    }
                }
                
                Item { Layout.fillHeight: true }
                
                // Botones
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    
                    Item { Layout.fillWidth: true }
                    
                    Button {
                        Layout.preferredWidth: 100
                        Layout.preferredHeight: 40
                        text: "Cancelar"
                        
                        background: Rectangle {
                            color: parent.pressed ? "#E0E0E0" : "#F5F5F5"
                            radius: 20
                            border.color: "#BDBDBD"
                            border.width: 1
                        }
                        
                        contentItem: Label {
                            text: parent.text
                            color: "#616161"
                            font.bold: true
                            font.pixelSize: 14
                            font.family: "Segoe UI, Arial, sans-serif"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: {
                            showCreateProveedorDialog = false
                        }
                    }
                    
                    Button {
                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 40
                        text: editMode ? "Actualizar" : "Guardar"
                        enabled: nombreProveedorField.text.trim().length > 0 && direccionProveedorField.text.trim().length > 0
                        
                        background: Rectangle {
                            color: {
                                if (!parent.enabled) return "#CCCCCC"
                                if (parent.pressed) return "#388E3C"
                                return "#4CAF50"
                            }
                            radius: 20
                        }
                        
                        contentItem: Label {
                            text: parent.text
                            color: parent.enabled ? whiteColor : "#888888"
                            font.bold: true
                            font.pixelSize: 14
                            font.family: "Segoe UI, Arial, sans-serif"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: {
                            if (editMode) {
                                console.log("Actualizando proveedor:", nombreProveedorField.text, direccionProveedorField.text)
                                // Aquí iría la lógica de actualización
                                if (proveedorModel && selectedProveedor) {
                                    proveedorModel.actualizar_proveedor(selectedProveedor.id, nombreProveedorField.text.trim(), direccionProveedorField.text.trim())
                                }
                            } else {
                                console.log("Creando nuevo proveedor:", nombreProveedorField.text, direccionProveedorField.text)
                                // Aquí iría la lógica de creación
                                if (proveedorModel) {
                                    proveedorModel.crear_proveedor(nombreProveedorField.text.trim(), direccionProveedorField.text.trim())
                                }
                            }
                            showCreateProveedorDialog = false
                        }
                    }
                }
            }
        }
        
        // Cargar datos cuando se abre en modo edición
        onVisibleChanged: {
            if (visible) {
                if (editMode && selectedProveedor) {
                    nombreProveedorField.text = selectedProveedor.Nombre || ""
                    direccionProveedorField.text = selectedProveedor.Direccion || ""
                } else if (!editMode) {
                    nombreProveedorField.text = ""
                    direccionProveedorField.text = ""
                }
                
                // Dar foco al primer campo
                Qt.callLater(function() {
                    nombreProveedorField.forceActiveFocus()
                })
            }
        }
    }

    // DIALOG CONFIRMACIÓN ELIMINAR - BLOQUEADO
    Dialog {
        id: deleteConfirmDialog
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.9, 450)
        height: Math.min(parent.height * 0.6, 300)
        modal: true
        closePolicy: Popup.NoAutoClose
        visible: showDeleteConfirmDialog
        
        title: ""
        
        background: Rectangle {
            color: whiteColor
            radius: 12
            border.color: "#dee2e6"
            border.width: 2
        }
        
        ColumnLayout {
            anchors.fill: parent
            spacing: 20
            
            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                
                Rectangle {
                    Layout.preferredWidth: 50
                    Layout.preferredHeight: 50
                    color: dangerColor
                    radius: 25
                    
                    Label {
                        anchors.centerIn: parent
                        text: "⚠️"
                        font.pixelSize: 24
                    }
                }
                
                ColumnLayout {
                    spacing: 4
                    
                    Label {
                        text: "Confirmar Eliminación"
                        color: textColor
                        font.bold: true
                        font.pixelSize: 18
                    }
                    
                    Label {
                        text: proveedorToDelete ? proveedorToDelete.Nombre || "Proveedor" : "Proveedor"
                        color: darkGrayColor
                        font.pixelSize: 14
                    }
                }
                
                Item { Layout.fillWidth: true }
            }
            
            // Mensaje
            Label {
                text: "¿Está seguro de eliminar este proveedor?\n\n• Solo se puede eliminar si no tiene compras asociadas\n• Esta acción NO se puede deshacer"
                color: "#495057"
                font.pixelSize: 14
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                Layout.fillHeight: true
                verticalAlignment: Text.AlignVCenter
            }
            
            // Botones
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                
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
                        proveedorToDelete = null
                    }
                }
                
                Button {
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 36
                    text: "Eliminar"
                    
                    background: Rectangle {
                        color: parent.pressed ? Qt.darker(dangerColor, 1.1) : dangerColor
                        radius: 18
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        color: whiteColor
                        font.bold: true
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        if (proveedorToDelete && proveedorModel) {
                            console.log("🗑️ Eliminando proveedor:", proveedorToDelete.id)
                            proveedorModel.eliminar_proveedor(proveedorToDelete.id)
                        }
                        
                        showDeleteConfirmDialog = false
                        proveedorToDelete = null
                    }
                }
            }
        }
    }

    // DIALOG DETALLES PROVEEDOR - BLOQUEADO
    Dialog {
        id: proveedorDetailsDialog
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.9, 700)
        height: Math.min(parent.height * 0.9, 600)
        modal: true
        closePolicy: Popup.NoAutoClose
        visible: showProveedorDetailsDialog
        
        title: ""
        
        background: Rectangle {
            color: whiteColor
            radius: 16
            border.color: "#dee2e6"
            border.width: 2
        }
        
        ColumnLayout {
            anchors.fill: parent
            spacing: 20
            
            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                
                Rectangle {
                    Layout.preferredWidth: 50
                    Layout.preferredHeight: 50
                    color: blueColor
                    radius: 25
                    
                    Label {
                        anchors.centerIn: parent
                        text: "🏢"
                        font.pixelSize: 20
                    }
                }
                
                ColumnLayout {
                    spacing: 4
                    
                    Label {
                        text: "Detalles del Proveedor"
                        color: textColor
                        font.bold: true
                        font.pixelSize: 24
                    }
                    
                    Label {
                        text: selectedProveedor ? selectedProveedor.Nombre : "Proveedor"
                        color: darkGrayColor
                        font.pixelSize: 16
                    }
                }
                
                Item { Layout.fillWidth: true }
                
                Button {
                    Layout.preferredWidth: 35
                    Layout.preferredHeight: 35
                    
                    background: Rectangle {
                        color: parent.pressed ? Qt.darker(dangerColor, 1.2) : dangerColor
                        radius: 17
                    }
                    
                    contentItem: Label {
                        text: "✕"
                        color: whiteColor
                        font.bold: true
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        showProveedorDetailsDialog = false
                    }
                }
            }
            
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                
                ColumnLayout {
                    width: parent.width - 20
                    spacing: 24
                    
                    // Información básica
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 120
                        color: "#F8F9FA"
                        radius: 12
                        border.color: "#E9ECEF"
                        border.width: 1
                        
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 12
                            
                            Label {
                                text: "Información Básica"
                                font.bold: true
                                font.pixelSize: 16
                                color: textColor
                            }
                            
                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2
                                columnSpacing: 30
                                rowSpacing: 8
                                
                                Label {
                                    text: "Nombre:"
                                    font.bold: true
                                    color: darkGrayColor
                                }
                                
                                Label {
                                    text: selectedProveedor ? selectedProveedor.Nombre : "N/A"
                                    color: textColor
                                    Layout.fillWidth: true
                                }
                                
                                Label {
                                    text: "Dirección:"
                                    font.bold: true
                                    color: darkGrayColor
                                }
                                
                                Label {
                                    text: selectedProveedor ? selectedProveedor.Direccion : "N/A"
                                    color: textColor
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                    
                    // Estadísticas de compras
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 160
                        color: "#E8F5E8"
                        radius: 12
                        border.color: successColor
                        border.width: 1
                        
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 16
                            
                            Label {
                                text: "Estadísticas de Compras"
                                font.bold: true
                                font.pixelSize: 16
                                color: textColor
                            }
                            
                            GridLayout {
                                Layout.fillWidth: true
                                columns: 4
                                columnSpacing: 20
                                rowSpacing: 12
                                
                                // Total Compras
                                ColumnLayout {
                                    spacing: 4
                                    
                                    Label {
                                        text: "Total Compras"
                                        font.pixelSize: 12
                                        color: darkGrayColor
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: 60
                                        Layout.preferredHeight: 35
                                        color: blueColor
                                        radius: 18
                                        Layout.alignment: Qt.AlignHCenter
                                        
                                        Label {
                                            anchors.centerIn: parent
                                            text: selectedProveedor ? getProveedorField(selectedProveedor, {}, "Total_Compras", 0) : "0"
                                            color: whiteColor
                                            font.bold: true
                                            font.pixelSize: 14
                                        }
                                    }
                                }
                                
                                // Monto Total
                                ColumnLayout {
                                    spacing: 4
                                    
                                    Label {
                                        text: "Monto Total"
                                        font.pixelSize: 12
                                        color: darkGrayColor
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: 90
                                        Layout.preferredHeight: 35
                                        color: successColor
                                        radius: 18
                                        Layout.alignment: Qt.AlignHCenter
                                        
                                        Label {
                                            anchors.centerIn: parent
                                            text: {
                                                if (!selectedProveedor) return "Bs0.00"
                                                var monto = getProveedorField(selectedProveedor, {}, "Monto_Total", 0)
                                                return "Bs" + parseFloat(monto).toFixed(2)
                                            }
                                            color: whiteColor
                                            font.bold: true
                                            font.pixelSize: 12
                                        }
                                    }
                                }
                                
                                // Compra Promedio
                                ColumnLayout {
                                    spacing: 4
                                    
                                    Label {
                                        text: "Promedio"
                                        font.pixelSize: 12
                                        color: darkGrayColor
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: 90
                                        Layout.preferredHeight: 35
                                        color: warningColor
                                        radius: 18
                                        Layout.alignment: Qt.AlignHCenter
                                        
                                        Label {
                                            anchors.centerIn: parent
                                            text: {
                                                if (!selectedProveedor) return "Bs0.00"
                                                var promedio = getProveedorField(selectedProveedor, {}, "Compra_Promedio", 0)
                                                return "Bs" + parseFloat(promedio).toFixed(2)
                                            }
                                            color: whiteColor
                                            font.bold: true
                                            font.pixelSize: 12
                                        }
                                    }
                                }
                                
                                // Estado
                                ColumnLayout {
                                    spacing: 4
                                    
                                    Label {
                                        text: "Estado"
                                        font.pixelSize: 12
                                        color: darkGrayColor
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: 80
                                        Layout.preferredHeight: 35
                                        color: {
                                            if (!selectedProveedor) return darkGrayColor
                                            var estado = getProveedorField(selectedProveedor, {}, "Estado", "Sin_Compras")
                                            switch(estado) {
                                                case "Activo": return successColor
                                                case "Inactivo": return warningColor
                                                case "Sin_Compras": return darkGrayColor
                                                case "Obsoleto": return dangerColor
                                                default: return darkGrayColor
                                            }
                                        }
                                        radius: 18
                                        Layout.alignment: Qt.AlignHCenter
                                        
                                        Label {
                                            anchors.centerIn: parent
                                            text: {
                                                if (!selectedProveedor) return "N/A"
                                                var estado = getProveedorField(selectedProveedor, {}, "Estado", "Sin_Compras")
                                                switch(estado) {
                                                    case "Activo": return "Activo"
                                                    case "Inactivo": return "Inactivo"
                                                    case "Sin_Compras": return "Sin Compras"
                                                    case "Obsoleto": return "Obsoleto"
                                                    default: return "Desconocido"
                                                }
                                            }
                                            color: whiteColor
                                            font.bold: true
                                            font.pixelSize: 10
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // Información Adicional
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 180
                        color: "#FFF9E6"
                        radius: 12
                        border.color: warningColor
                        border.width: 1
                        
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 16
                            
                            Label {
                                text: "Información Adicional"
                                font.bold: true
                                font.pixelSize: 16
                                color: textColor
                            }
                            
                            Label {
                                text: {
                                    if (!selectedProveedor) return "No hay información disponible"
                                    
                                    var fecha = getSafeDate(selectedProveedor, {}, "Ultima_Compra")
                                    if (!fecha) {
                                        return "No hay compras registradas"
                                    }
                                    
                                    return "Última compra: " + formatDate(fecha)
                                }
                                color: darkGrayColor
                                font.pixelSize: 14
                            }
                            
                            Label {
                                text: selectedProveedor ? `ID del proveedor: ${selectedProveedor.id}` : "N/A"
                                color: darkGrayColor
                                font.pixelSize: 12
                            }
                            
                            Item {
                                Layout.fillHeight: true
                            }
                        }
                    }
                }
            }
            
            // Botones de acción
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                
                Item { Layout.fillWidth: true }
                
                Button {
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 40
                    text: "Editar"
                    
                    background: Rectangle {
                        color: parent.pressed ? Qt.darker(warningColor, 1.1) : warningColor
                        radius: 20
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        color: whiteColor
                        font.bold: true
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        editMode = true
                        showProveedorDetailsDialog = false
                        showCreateProveedorDialog = true
                    }
                }
                
                Button {
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 40
                    text: "Cerrar"
                    
                    background: Rectangle {
                        color: parent.pressed ? "#e9ecef" : "#f8f9fa"
                        radius: 20
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
                        showProveedorDetailsDialog = false
                    }
                }
            }
        }
    }

    function performCompleteRefresh() {
        console.log("🔄 REFRESH COMPLETO iniciado por usuario")
        
        if (!proveedorModel) {
            console.log("❌ ProveedorModel no disponible")
            return
        }
        
        // Estado visual
        refreshButton.isRefreshing = true
        refreshButton.refreshCounter++
        
        // Logs para debug
        console.log("📊 Estado antes del refresh:")
        console.log("   - Proveedores en lista:", proveedorModel.total_proveedores)
        console.log("   - Página actual:", proveedorModel.pagina_actual)
        
        // Ejecutar refresh
        try {
            proveedorModel.force_complete_refresh()
            
            // Esperar un momento y verificar resultado
            Qt.callLater(function() {
                console.log("📊 Estado después del refresh:")
                console.log("   - Proveedores en lista:", proveedorModel.total_proveedores)
                
                // Finalizar estado visual
                refreshButton.isRefreshing = false
                
                // Feedback visual adicional
                refreshIcon.text = "✅"
                Qt.callLater(function() {
                    refreshIcon.text = "🔄"
                })
            })
            
        } catch (error) {
            console.log("❌ Error en refresh:", error)
            refreshButton.isRefreshing = false
        }
    }

    // ✅ NUEVA FUNCIÓN: Auto-refresh periódico
    Timer {
        id: autoRefreshTimer
        interval: 60000  // 1 minuto
        running: false   // Desactivado por defecto, se puede activar
        repeat: true
        onTriggered: {
            console.log("⏰ Auto-refresh de proveedores")
            if (proveedorModel && !refreshButton.isRefreshing) {
                proveedorModel.refresh_proveedores()
            }
        }
    }

    // FUNCIONES AUXILIARES
    function formatDate(dateString) {
        if (!dateString || dateString === null || dateString === undefined) {
            return "Sin compras"
        }
        
        if (typeof dateString === 'string') {
            dateString = dateString.trim()
            if (dateString === '' || dateString === 'null' || dateString === 'undefined') {
                return "Sin compras"
            }
        }
        
        try {
            // Crear fecha en zona horaria local
            var date = new Date(dateString + 'T00:00:00')
            
            if (isNaN(date.getTime())) {
                return "Sin compras"
            }

            // Ajustar por diferencia de zona horaria
            var timezoneOffset = date.getTimezoneOffset() * 60000
            var adjustedDate = new Date(date.getTime() + timezoneOffset)
            
            return adjustedDate.toLocaleDateString("es-ES", {
                day: "2-digit",
                month: "2-digit", 
                year: "numeric"
            })
        } catch (e) {
            console.log("⚠️ Error formateando fecha:", dateString, e)
            return "Sin compras"
        }
    }
    
    function showNotification(message, type) {
        console.log(`[${type.toUpperCase()}] ${message}`)
        // TODO: Implementar sistema de notificaciones visual
    }
    
    function getProveedorField(modelData, model, field, defaultValue = "") {
        return modelData[field] || model[field] || defaultValue
    }

    // ✅ FUNCIÓN AUXILIAR PARA OBTENER FECHA SEGURA
    function getSafeDate(modelData, model, field) {
        var fecha = modelData[field] || model[field]
        if (!fecha || fecha === null || fecha === undefined) {
            return null
        }
        return fecha
    }

    Component.onCompleted: {
        console.log("🏢 Módulo Proveedores inicializado")
        
        // Verificar disponibilidad de models
        if (proveedorModel) {
            console.log("✅ ProveedorModel disponible")
            console.log("📊 Proveedores iniciales:", proveedorModel.total_proveedores)
        } else {
            console.log("❌ ProveedorModel no disponible")
        }
        
        // Verificar si CompraModel está disponible para sync
        if (typeof compraModel !== 'undefined' && compraModel) {
            console.log("✅ CompraModel disponible para sync automático")
            
            // Configurar sync si es posible
            if (proveedorModel && typeof proveedorModel.set_compra_model_reference === 'function') {
                proveedorModel.set_compra_model_reference(compraModel)
                console.log("🔗 Sync automático configurado")
            }
        } else {
            console.log("⚠️ CompraModel no disponible - sin sync automático")
        }
    }
    function debugProveedoresInfo() {
        if (!proveedorModel) {
            console.log("❌ DEBUG: ProveedorModel no disponible")
            return
        }
        
        console.log("🔍 DEBUG INFO PROVEEDORES:")
        console.log("   - Total proveedores:", proveedorModel.total_proveedores)
        console.log("   - Página actual:", proveedorModel.pagina_actual)
        console.log("   - Total páginas:", proveedorModel.total_paginas)
        console.log("   - Búsqueda actual:", proveedorModel.termino_busqueda || "sin filtro")
        console.log("   - Estado loading:", proveedorModel.loading)
        
        // Verificar lista de proveedores
        var proveedoresList = proveedorModel.proveedores || []
        console.log("   - Proveedores en memoria:", proveedoresList.length)
        
        if (proveedoresList.length > 0) {
            console.log("📋 Últimos 3 proveedores:")
            for (var i = Math.max(0, proveedoresList.length - 3); i < proveedoresList.length; i++) {
                var prov = proveedoresList[i]
                console.log(`     ${i+1}. ${prov.Nombre || 'Sin nombre'} - Compras: ${prov.Total_Compras || 0} - Monto: Bs${prov.Monto_Total || 0}`)
            }
        }
    }
    function editarProveedor(proveedor) {
        console.log("✏️ Editando proveedor:", proveedor.Nombre)
        
        if (crearProveedorModal) {
            crearProveedorModal.editMode = true
            crearProveedorModal.proveedorData = proveedor
            crearProveedorModal.visible = true
        }
    }

    function verDetalles(proveedorId) {
        console.log("👁️ Ver detalles proveedor:", proveedorId)
        
        if (proveedorModel) {
            proveedorModel.seleccionar_proveedor(proveedorId)
            
            // Refresh automático de datos después de seleccionar
            Qt.callLater(function() {
                console.log("📊 Proveedor seleccionado, datos actualizados")
            })
        }
    }
}