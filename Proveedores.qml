import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

// Componente principal del módulo de Proveedores
Item {
    id: proveedoresRoot
    objectName: "proveedoresRoot"
    
    // Propiedades de control
    property var proveedorModel: parent.proveedorModel || null
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
                    source: "Resources/iconos/Trabajadores.png"
                    Layout.preferredWidth: 60
                    Layout.preferredHeight: 60
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    
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
                        text: "Gestión de Proveedores"
                        color: darkGrayColor
                        font.pixelSize: 14
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
                Layout.preferredWidth: 120
                Layout.preferredHeight: 40
                text: "🔄 Actualizar"
                
                background: Rectangle {
                    color: parent.pressed ? Qt.darker(blueColor, 1.1) : blueColor
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
                    if (proveedorModel) {
                        proveedorModel.refresh_proveedores()
                    }
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
                            
                            Rectangle {
                                anchors.fill: parent
                                color: proveedoresTable.currentIndex === index ? "#E3F2FD" : "transparent"
                                opacity: 0.3
                            }
                            
                            RowLayout {
                                anchors.fill: parent
                                spacing: 0
                                
                                // ID
                                Rectangle {
                                    Layout.preferredWidth: 80
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#D5DBDB"
                                    border.width: 1
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: model.id || 0
                                        color: blueColor
                                        font.bold: true
                                        font.pixelSize: 14
                                    }
                                }
                                
                                // NOMBRE
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
                                            text: model.Nombre || "Sin nombre"
                                            color: textColor
                                            font.bold: true
                                            font.pixelSize: 13
                                            elide: Text.ElideRight
                                            Layout.maximumWidth: 180
                                        }
                                        
                                        Label {
                                            text: model.Contacto || "Sin contacto"
                                            color: darkGrayColor
                                            font.pixelSize: 10
                                            elide: Text.ElideRight
                                            Layout.maximumWidth: 180
                                        }
                                    }
                                }
                                
                                // DIRECCIÓN
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
                                            text: model.Direccion || "Sin dirección"
                                            color: textColor
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                            Layout.maximumWidth: 230
                                            Layout.fillWidth: true
                                        }
                                        
                                        Label {
                                            text: model.Email || model.Telefono || ""
                                            color: darkGrayColor
                                            font.pixelSize: 10
                                            elide: Text.ElideRight
                                            Layout.maximumWidth: 230
                                        }
                                    }
                                }
                                
                                // COMPRAS
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
                                                text: model.Total_Compras || 0
                                                color: whiteColor
                                                font.bold: true
                                                font.pixelSize: 10
                                            }
                                        }
                                        
                                        Label {
                                            text: {
                                                var fecha = model.Ultima_Compra
                                                if (!fecha) return "Sin compras"
                                                return "Última: " + formatDate(fecha)
                                            }
                                            color: darkGrayColor
                                            font.pixelSize: 9
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                    }
                                }
                                
                                // TOTAL GASTADO
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
                                            text: "Bs" + (model.Monto_Total ? model.Monto_Total.toFixed(2) : "0.00")
                                            color: whiteColor
                                            font.bold: true
                                            font.pixelSize: 10
                                        }
                                    }
                                }
                                
                                // ESTADO
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
                                            var estado = model.Estado || "Sin_Compras"
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
                                                var estado = model.Estado || "Sin_Compras"
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
                                
                                // ACCIONES
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
                                                console.log("👁️ Ver detalles proveedor:", model.id)
                                                selectedProveedor = model
                                                if (proveedorModel) {
                                                    proveedorModel.seleccionar_proveedor(model.id)
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
                                                console.log("✏️ Editar proveedor:", model.id)
                                                editMode = true
                                                selectedProveedor = model
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
                                                console.log("🗑️ Confirmar eliminar proveedor:", model.id)
                                                proveedorToDelete = model
                                                showDeleteConfirmDialog = true
                                            }
                                        }
                                    }
                                }
                            }
                            
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
                                    selectedProveedor = model
                                    if (proveedorModel) {
                                        proveedorModel.seleccionar_proveedor(model.id)
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

    // MODAL CREAR/EDITAR PROVEEDOR
    CrearProveedor {
        id: crearProveedorModal
        visible: showCreateProveedorDialog
        editMode: proveedoresRoot.editMode
        proveedorData: selectedProveedor
        proveedorModel: proveedoresRoot.proveedorModel
        
        onDialogClosed: {
            showCreateProveedorDialog = false
        }
    }

    // MODAL DETALLES PROVEEDOR
    // TODO: Implementar modal de detalles
    
    // MODAL CONFIRMACIÓN ELIMINAR
    Rectangle {
        id: deleteConfirmOverlay
        anchors.fill: parent
        color: "#000000"
        opacity: 0.7
        visible: showDeleteConfirmDialog
        z: 2000
        
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
        width: 450
        height: 250
        
        visible: showDeleteConfirmDialog
        z: 2001
        
        color: whiteColor
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
                    color: dangerColor
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
                        color: textColor
                        font.bold: true
                        font.pixelSize: 16
                    }
                    
                    Label {
                        text: proveedorToDelete ? `${proveedorToDelete.Nombre}` : ""
                        color: darkGrayColor
                        font.pixelSize: 12
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

    // FUNCIONES AUXILIARES
    function formatDate(dateString) {
        if (!dateString) return "N/A"
        try {
            var date = new Date(dateString)
            return date.toLocaleDateString("es-ES", {
                day: "2-digit",
                month: "2-digit", 
                year: "numeric"
            })
        } catch (e) {
            return "N/A"
        }
    }
    
    function showNotification(message, type) {
        console.log(`[${type.toUpperCase()}] ${message}`)
        // TODO: Implementar sistema de notificaciones visual
    }

    Component.onCompleted: {
        console.log("=== MÓDULO DE PROVEEDORES INICIALIZADO ===")
        if (!proveedorModel) {
            console.log("❌ ERROR: ProveedorModel no está disponible")
            return
        }
        
        console.log("✅ ProveedorModel conectado correctamente")
        console.log("=== MÓDULO LISTO ===")
    }
}