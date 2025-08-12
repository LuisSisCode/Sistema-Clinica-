import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

Item {
    id: usuariosRoot
    objectName: "usuariosRoot"
    
    // Acceso a colores
    readonly property color primaryColor: "#3498DB"
    readonly property color successColor: "#27ae60"
    readonly property color dangerColor: "#E74C3C"
    readonly property color warningColor: "#f39c12"
    readonly property color lightGrayColor: "#ECF0F1"
    readonly property color textColor: "#2c3e50"
    readonly property color whiteColor: "#FFFFFF"
    readonly property color infoColor: "#17a2b8"
    readonly property color violetColor: "#9b59b6"
    
    // Propiedades para los diálogos
    property bool showNewUserDialog: false
    property bool showConfigRolesDialog: false
    property bool isEditMode: false
    property int editingIndex: -1
    property int selectedRowIndex: -1
    property var editingUser: null
    
    // Referencia al modelo de usuario
    property var usuarioModel: null
    property var rolesDisponibles: []
    
    // Inicialización cuando el model esté disponible
    Component.onCompleted: {
        if (appController && appController.usuario_model_instance) {
            usuarioModel = appController.usuario_model_instance
            rolesDisponibles = usuarioModel.obtenerRolesDisponibles()
        }
    }
    
    // Conexiones para manejar cuando los models estén listos
    Connections {
        target: appController
        function onModelsReady() {
            if (appController.usuario_model_instance) {
                usuarioModel = appController.usuario_model_instance
                rolesDisponibles = usuarioModel.obtenerRolesDisponibles()
                console.log("UsuarioModel conectado:", usuarioModel.totalUsuarios, "usuarios")
            }
        }
    }
    
    // Conexiones con el modelo de usuario
    Connections {
        target: usuarioModel
        
        function onUsuarioCreado(success, message) {
            if (success) {
                showNewUserDialog = false
                mostrarNotificacion("Éxito", message, successColor)
                limpiarFormulario()
            } else {
                mostrarNotificacion("Error", message, dangerColor)
            }
        }
        
        function onUsuarioActualizado(success, message) {
            if (success) {
                showNewUserDialog = false
                mostrarNotificacion("Éxito", message, successColor)
                limpiarFormulario()
                selectedRowIndex = -1
            } else {
                mostrarNotificacion("Error", message, dangerColor)
            }
        }
        
        function onUsuarioEliminado(success, message) {
            if (success) {
                mostrarNotificacion("Éxito", message, successColor)
                selectedRowIndex = -1
            } else {
                mostrarNotificacion("Error", message, dangerColor)
            }
        }
        
        function onErrorOccurred(title, message) {
            mostrarNotificacion(title, message, dangerColor)
        }
        
        function onSuccessMessage(message) {
            mostrarNotificacion("Éxito", message, successColor)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 40
        spacing: 32
        
        // Contenido principal
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: whiteColor
            radius: 20
            border.color: "#e0e0e0"
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                
                // Header de Usuarios - FIJO
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    color: "#f8f9fa"
                    border.color: "#e0e0e0"
                    border.width: 1
                    z: 10
                    Rectangle {
                        anchors.fill: parent
                        anchors.bottomMargin: 20
                        color: parent.color
                        radius: parent.radius
                    }
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        
                        RowLayout {
                            spacing: 12
                            
                            Label {
                                text: "👤"
                                font.pixelSize: 24
                                color: primaryColor
                            }
                            
                            Label {
                                text: "Gestión de Usuarios del Sistema"
                                font.pixelSize: 20
                                font.bold: true
                                color: textColor
                            }
                            
                            // Loading indicator
                            BusyIndicator {
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                visible: usuarioModel ? usuarioModel.loading : false
                                running: visible
                            }
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        Button {
                            objectName: "newUserButton"
                            text: "➕ Nuevo Usuario"
                            
                            background: Rectangle {
                                color: primaryColor
                                radius: 12
                            }
                            
                            contentItem: Label {
                                text: parent.text
                                color: whiteColor
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                            }
                            
                            onClicked: {
                                isEditMode = false
                                editingIndex = -1
                                editingUser = null
                                showNewUserDialog = true
                            }
                        }
                        
                        Button {
                            text: "🔄 Recargar"
                            
                            background: Rectangle {
                                color: infoColor
                                radius: 12
                            }
                            
                            contentItem: Label {
                                text: parent.text
                                color: whiteColor
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                            }
                            
                            onClicked: {
                                if (usuarioModel) {
                                    usuarioModel.recargarDatos()
                                }
                            }
                        }
                    }
                }
                
                // Filtros y búsqueda mejorados - FIJO
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 120  // Aumentado para dar más espacio
                    color: "#f8f9fa"
                    border.color: "#e9ecef"
                    border.width: 1
                    z: 10
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 24
                        spacing: 16
                        
                        // Fila superior - Título de filtros
                        RowLayout {
                            Layout.fillWidth: true
                            
                            Label {
                                text: "🔍 Filtros y Búsqueda"
                                font.bold: true
                                font.pixelSize: 16
                                color: textColor
                            }
                            
                            Item { Layout.fillWidth: true }
                            
                            // Contador de usuarios mejorado
                            Rectangle {
                                Layout.preferredWidth: 120
                                Layout.preferredHeight: 32
                                color: primaryColor
                                radius: 16
                                
                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    
                                    Label {
                                        text: "👥"
                                        color: whiteColor
                                        font.pixelSize: 14
                                    }
                                    
                                    Label {
                                        text: usuarioModel ? `${usuarioModel.totalUsuarios} usuarios` : "0 usuarios"
                                        font.bold: true
                                        font.pixelSize: 12
                                        color: whiteColor
                                    }
                                }
                            }
                        }
                        
                        // Fila inferior - Controles de filtro
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 20
                            
                            // Filtro por Rol
                            ColumnLayout {
                                spacing: 4
                                
                                Label {
                                    text: "Rol/Perfil"
                                    font.bold: true
                                    font.pixelSize: 12
                                    color: textColor
                                }
                                
                                ComboBox {
                                    id: filtroRol
                                    Layout.preferredWidth: 160
                                    Layout.preferredHeight: 36
                                    model: rolesDisponibles
                                    currentIndex: 0
                                    onCurrentTextChanged: aplicarFiltros()
                                    
                                    background: Rectangle {
                                        color: whiteColor
                                        border.color: "#dee2e6"
                                        border.width: 1
                                        radius: 8
                                    }
                                    
                                    contentItem: Text {
                                        text: parent.displayText
                                        font.pixelSize: 12
                                        color: textColor
                                        verticalAlignment: Text.AlignVCenter
                                        leftPadding: 12
                                    }
                                }
                            }
                            
                            // Filtro por Estado
                            ColumnLayout {
                                spacing: 4
                                
                                Label {
                                    text: "Estado"
                                    font.bold: true
                                    font.pixelSize: 12
                                    color: textColor
                                }
                                
                                ComboBox {
                                    id: filtroEstado
                                    Layout.preferredWidth: 140
                                    Layout.preferredHeight: 36
                                    model: usuarioModel ? usuarioModel.obtenerEstadosDisponibles() : ["Todos"]
                                    currentIndex: 0
                                    onCurrentTextChanged: aplicarFiltros()
                                    
                                    background: Rectangle {
                                        color: whiteColor
                                        border.color: "#dee2e6"
                                        border.width: 1
                                        radius: 8
                                    }
                                    
                                    contentItem: Text {
                                        text: parent.displayText
                                        font.pixelSize: 12
                                        color: textColor
                                        verticalAlignment: Text.AlignVCenter
                                        leftPadding: 12
                                    }
                                }
                            }
                            
                            // Espaciador flexible
                            Item { Layout.fillWidth: true }
                            
                            // Campo de búsqueda mejorado
                            ColumnLayout {
                                spacing: 4
                                
                                Label {
                                    text: "Búsqueda rápida"
                                    font.bold: true
                                    font.pixelSize: 12
                                    color: textColor
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 280
                                    Layout.preferredHeight: 36
                                    color: whiteColor
                                    border.color: campoBusqueda.activeFocus ? primaryColor : "#dee2e6"
                                    border.width: campoBusqueda.activeFocus ? 2 : 1
                                    radius: 8
                                    
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 8
                                        
                                        Label {
                                            text: "🔍"
                                            color: "#6c757d"
                                            font.pixelSize: 14
                                        }
                                        
                                        TextField {
                                            id: campoBusqueda
                                            Layout.fillWidth: true
                                            placeholderText: "Buscar por nombre, usuario o correo..."
                                            font.pixelSize: 12
                                            color: textColor
                                            onTextChanged: aplicarFiltros()
                                            
                                            background: Rectangle {
                                                color: "transparent"
                                            }
                                        }
                                        
                                        // Botón limpiar
                                        Button {
                                            Layout.preferredWidth: 20
                                            Layout.preferredHeight: 20
                                            visible: campoBusqueda.text.length > 0
                                            text: "✕"
                                            
                                            background: Rectangle {
                                                color: "transparent"
                                                radius: 10
                                            }
                                            
                                            contentItem: Label {
                                                text: parent.text
                                                color: "#6c757d"
                                                font.pixelSize: 10
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            
                                            onClicked: {
                                                campoBusqueda.text = ""
                                                campoBusqueda.focus = true
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
               
                // Contenedor para tabla con scroll limitado
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.margins: 32
                    
                    ScrollView {
                        anchors.fill: parent
                        clip: true
                        
                        ListView {
                            id: usuariosListView
                            model: usuarioModel ? usuarioModel.usuarios : []
                            
                            header: Rectangle {
                                width: parent.width
                                height: 40
                                color: "#f5f5f5"
                                border.color: "#d0d0d0"
                                border.width: 1
                                z: 5
                                
                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 0
                                    
                                    Rectangle {
                                        Layout.preferredWidth: Math.max(50, parent.width * 0.08)
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#d0d0d0"
                                        border.width: 1
                                        
                                        Label { 
                                            anchors.centerIn: parent
                                            text: "ID"
                                            font.bold: true
                                            font.pixelSize: 12
                                            color: textColor
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: Math.max(160, parent.width * 0.22)
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#d0d0d0"
                                        border.width: 1
                                        
                                        Label { 
                                            anchors.centerIn: parent
                                            text: "NOMBRE COMPLETO"
                                            font.bold: true
                                            font.pixelSize: 12
                                            color: textColor
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: Math.max(120, parent.width * 0.15)
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#d0d0d0"
                                        border.width: 1
                                        
                                        Label { 
                                            anchors.centerIn: parent
                                            text: "USUARIO"
                                            font.bold: true
                                            font.pixelSize: 12
                                            color: textColor
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: Math.max(180, parent.width * 0.20)
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#d0d0d0"
                                        border.width: 1
                                        
                                        Label { 
                                            anchors.centerIn: parent
                                            text: "CORREO ELECTRÓNICO"
                                            font.bold: true
                                            font.pixelSize: 12
                                            color: textColor
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: Math.max(120, parent.width * 0.15)
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#d0d0d0"
                                        border.width: 1
                                        
                                        Label { 
                                            anchors.centerIn: parent
                                            text: "ROL/PERFIL"
                                            font.bold: true
                                            font.pixelSize: 12
                                            color: textColor
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: Math.max(80, parent.width * 0.10)
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#d0d0d0"
                                        border.width: 1
                                        
                                        Label { 
                                            anchors.centerIn: parent
                                            text: "ESTADO"
                                            font.bold: true
                                            font.pixelSize: 12
                                            color: textColor
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#d0d0d0"
                                        border.width: 1
                                        
                                        Label { 
                                            anchors.centerIn: parent
                                            text: "ACCIONES"
                                            font.bold: true
                                            font.pixelSize: 12
                                            color: textColor
                                        }
                                    }
                                }
                            }
                            
                            delegate: Rectangle {
                                width: ListView.view.width
                                height: 80
                                color: {
                                    if (selectedRowIndex === index) return "#e3f2fd"
                                    return index % 2 === 0 ? "transparent" : "#fafafa"
                                }
                                border.color: selectedRowIndex === index ? primaryColor : "#e8e8e8"
                                border.width: selectedRowIndex === index ? 2 : 1
                                
                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 0
                                    
                                    Rectangle {
                                        Layout.preferredWidth: Math.max(50, parent.width * 0.08)
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#d0d0d0"
                                        border.width: 1
                                        
                                        Label { 
                                            anchors.centerIn: parent
                                            text: modelData.id || ""
                                            color: textColor
                                            font.bold: true
                                            font.pixelSize: 12
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: Math.max(160, parent.width * 0.22)
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#d0d0d0"
                                        border.width: 1
                                        
                                        Label { 
                                            anchors.fill: parent
                                            anchors.margins: 4
                                            text: (modelData.Nombre + " " + modelData.Apellido_Paterno + " " + modelData.Apellido_Materno) || ""
                                            color: primaryColor
                                            font.bold: true
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                            wrapMode: Text.WordWrap
                                            maximumLineCount: 2
                                            verticalAlignment: Text.AlignVCenter
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: Math.max(120, parent.width * 0.15)
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#d0d0d0"
                                        border.width: 1
                                        
                                        Label { 
                                            anchors.fill: parent
                                            anchors.margins: 4
                                            text: modelData.correo ? modelData.correo.split('@')[0] : ""
                                            color: "#7f8c8d"
                                            font.pixelSize: 11
                                            font.bold: true
                                            elide: Text.ElideRight
                                            verticalAlignment: Text.AlignVCenter
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: Math.max(180, parent.width * 0.20)
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#d0d0d0"
                                        border.width: 1
                                        
                                        Label { 
                                            anchors.fill: parent
                                            anchors.margins: 4
                                            text: modelData.correo || ""
                                            color: textColor
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                            wrapMode: Text.WordWrap
                                            maximumLineCount: 2
                                            verticalAlignment: Text.AlignVCenter
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: Math.max(120, parent.width * 0.15)
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#d0d0d0"
                                        border.width: 1
                                        
                                        Label { 
                                            anchors.fill: parent
                                            anchors.margins: 4
                                            text: modelData.rol_nombre || ""
                                            color: textColor
                                            font.pixelSize: 11
                                            font.bold: true
                                            elide: Text.ElideRight
                                            wrapMode: Text.WordWrap
                                            maximumLineCount: 2
                                            verticalAlignment: Text.AlignVCenter
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: Math.max(80, parent.width * 0.10)
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#d0d0d0"
                                        border.width: 1
                                        
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 65
                                            height: 20
                                            color: {
                                                switch(modelData.Estado ? "Activo" : "Inactivo") {
                                                    case "Activo": return successColor
                                                    case "Inactivo": return "#95a5a6"
                                                    case "Bloqueado": return dangerColor
                                                    default: return "#95a5a6"
                                                }
                                            }
                                            radius: 12
                                            
                                            Label {
                                                anchors.centerIn: parent
                                                text: modelData.Estado ? "Activo" : "Inactivo"
                                                color: whiteColor
                                                font.pixelSize: 9
                                                font.bold: true
                                            }
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#d0d0d0"
                                        border.width: 1
                                        
                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: 4
                                            
                                            Button {
                                                width: 32
                                                height: 32
                                                text: "✏️"
                                                
                                                background: Rectangle {
                                                    color: warningColor
                                                    radius: 6
                                                    border.color: "#f1c40f"
                                                    border.width: 1
                                                }
                                                
                                                contentItem: Label {
                                                    text: parent.text
                                                    color: whiteColor
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                    font.pixelSize: 12
                                                }
                                                
                                                onClicked: {
                                                    isEditMode = true
                                                    editingIndex = index
                                                    editingUser = modelData
                                                    selectedRowIndex = index
                                                    showNewUserDialog = true
                                                }
                                            }
                                            
                                            Button {
                                                width: 32
                                                height: 32
                                                text: "🗑️"
                                                
                                                background: Rectangle {
                                                    color: dangerColor
                                                    radius: 6
                                                    border.color: "#c0392b"
                                                    border.width: 1
                                                }
                                                
                                                contentItem: Label {
                                                    text: parent.text
                                                    color: whiteColor
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                    font.pixelSize: 12
                                                }
                                                
                                                onClicked: {
                                                    if (usuarioModel && modelData.id) {
                                                        usuarioModel.eliminarUsuario(modelData.id.toString())
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        selectedRowIndex = index
                                        console.log("Seleccionado usuario ID:", modelData.id)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Diálogo Nuevo Usuario / Editar Usuario
    Rectangle {
        id: newUserDialog
        anchors.fill: parent
        color: "black"
        opacity: showNewUserDialog ? 0.5 : 0
        visible: opacity > 0
        
        MouseArea {
            anchors.fill: parent
            onClicked: {
                showNewUserDialog = false
                selectedRowIndex = -1
            }
        }
        
        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }
    }

    Rectangle {
        id: userForm
        anchors.centerIn: parent
        width: 800
        height: 550
        color: whiteColor
        radius: 12
        border.color: lightGrayColor
        border.width: 1
        visible: showNewUserDialog
        
        property var selectedPermisos: ({})
        
        // Lista de módulos/permisos disponibles
        property var modulosDisponibles: [
            "Vista general",
            "Farmacia",
            "Consultas",
            "Laboratorio",
            "Enfermería",
            "Servicios Básicos",
            "Usuarios",
            "Trabajadores",
            "Configuración"
        ]
        
        // Función para cargar datos en modo edición
        function loadEditData() {
            if (isEditMode && editingUser) {
                // Cargar datos del usuario
                nombreCompleto.text = editingUser.Nombre || ""
                apellidoPaterno.text = editingUser.Apellido_Paterno || ""
                apellidoMaterno.text = editingUser.Apellido_Materno || ""
                correoElectronico.text = editingUser.correo || ""
                
                // Configurar rol
                var rolIndex = rolesDisponibles.indexOf(editingUser.rol_nombre)
                if (rolIndex >= 0) {
                    rolComboBox.currentIndex = rolIndex
                }
                
                // Configurar estado
                switch(editingUser.Estado ? "Activo" : "Inactivo") {
                    case "Activo":
                        activoRadio.checked = true
                        break
                    case "Inactivo":
                        inactivoRadio.checked = true
                        break
                    case "Bloqueado":
                        bloqueadoRadio.checked = true
                        break
                }
            }
        }
        
        onVisibleChanged: {
            if (visible && isEditMode) {
                loadEditData()
            } else if (visible && !isEditMode) {
                limpiarFormulario()
            }
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 25
            spacing: 15
            
            // Título
            Label {
                Layout.fillWidth: true
                text: isEditMode ? "Editar Usuario" : "Nuevo Usuario"
                font.pixelSize: 20
                font.bold: true
                color: textColor
                horizontalAlignment: Text.AlignHCenter
            }
            
            // Contenido principal en dos columnas
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 20
                
                // COLUMNA IZQUIERDA - Datos del Usuario
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#f8f9fa"
                    radius: 8
                    border.color: lightGrayColor
                    border.width: 1
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 15
                        spacing: 12
                        
                        Label {
                            text: "Datos del Usuario"
                            font.bold: true
                            font.pixelSize: 14
                            color: textColor
                        }
                        
                        // Nombre
                        TextField {
                            id: nombreCompleto
                            Layout.fillWidth: true
                            placeholderText: "Nombre"
                            background: Rectangle {
                                color: whiteColor
                                border.color: lightGrayColor
                                border.width: 1
                                radius: 4
                            }
                        }
                        
                        // Apellido Paterno
                        TextField {
                            id: apellidoPaterno
                            Layout.fillWidth: true
                            placeholderText: "Apellido Paterno"
                            background: Rectangle {
                                color: whiteColor
                                border.color: lightGrayColor
                                border.width: 1
                                radius: 4
                            }
                        }
                        
                        // Apellido Materno
                        TextField {
                            id: apellidoMaterno
                            Layout.fillWidth: true
                            placeholderText: "Apellido Materno"
                            background: Rectangle {
                                color: whiteColor
                                border.color: lightGrayColor
                                border.width: 1
                                radius: 4
                            }
                        }
                        
                        // Correo Electrónico
                        TextField {
                            id: correoElectronico
                            Layout.fillWidth: true
                            placeholderText: "correo@clinica.com"
                            background: Rectangle {
                                color: whiteColor
                                border.color: lightGrayColor
                                border.width: 1
                                radius: 4
                            }
                        }
                        
                        // Contraseñas (solo en modo nuevo usuario)
                        TextField {
                            id: contrasenaField
                            Layout.fillWidth: true
                            placeholderText: "Contraseña"
                            echoMode: TextInput.Password
                            visible: !isEditMode
                            background: Rectangle {
                                color: whiteColor
                                border.color: lightGrayColor
                                border.width: 1
                                radius: 4
                            }
                        }
                        
                        TextField {
                            id: confirmarContrasenaField
                            Layout.fillWidth: true
                            placeholderText: "Confirmar contraseña"
                            echoMode: TextInput.Password
                            visible: !isEditMode
                            background: Rectangle {
                                color: whiteColor
                                border.color: lightGrayColor
                                border.width: 1
                                radius: 4
                            }
                        }
                        
                        // Rol
                        ComboBox {
                            id: rolComboBox
                            Layout.fillWidth: true
                            model: rolesDisponibles.filter(rol => rol !== "Todos los roles")
                            displayText: currentIndex >= 0 ? model[currentIndex] : "Seleccione rol"
                        }
                        
                        Item { Layout.fillHeight: true }
                    }
                }
                
                // COLUMNA DERECHA - Estado
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#f8f9fa"
                    radius: 8
                    border.color: lightGrayColor
                    border.width: 1
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 15
                        spacing: 12
                        
                        Label {
                            text: "Estado del Usuario"
                            font.bold: true
                            font.pixelSize: 14
                            color: textColor
                        }
                        
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            
                            RadioButton {
                                id: activoRadio
                                text: "Activo"
                                checked: true
                                font.pixelSize: 13
                            }
                            
                            RadioButton {
                                id: inactivoRadio
                                text: "Inactivo"
                                font.pixelSize: 13
                            }
                            
                            RadioButton {
                                id: bloqueadoRadio
                                text: "Bloqueado"
                                font.pixelSize: 13
                            }
                        }
                        
                        Item { Layout.fillHeight: true }
                    }
                }
            }
            
            // Botones
            RowLayout {
                Layout.fillWidth: true
                
                Item { Layout.fillWidth: true }
                
                Button {
                    text: "Cancelar"
                    Layout.preferredWidth: 100
                    background: Rectangle {
                        color: lightGrayColor
                        radius: 6
                    }
                    contentItem: Label {
                        text: parent.text
                        color: textColor
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 13
                    }
                    onClicked: {
                        showNewUserDialog = false
                        selectedRowIndex = -1
                        isEditMode = false
                        editingIndex = -1
                        editingUser = null
                    }
                }
                
                Button {
                    text: isEditMode ? "Actualizar" : "Guardar"
                    Layout.preferredWidth: 100
                    enabled: nombreCompleto.text.length > 0 &&
                            apellidoPaterno.text.length > 0 &&
                            apellidoMaterno.text.length > 0 &&
                            correoElectronico.text.length > 0 &&
                            rolComboBox.currentIndex >= 0 &&
                            (isEditMode || (contrasenaField.text.length > 0 && contrasenaField.text === confirmarContrasenaField.text))
                    background: Rectangle {
                        color: parent.enabled ? primaryColor : "#bdc3c7"
                        radius: 6
                    }
                    contentItem: Label {
                        text: parent.text
                        color: whiteColor
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 13
                    }
                    onClicked: {
                        if (!usuarioModel) return
                        
                        var estado = activoRadio.checked ? "Activo" : 
                                    inactivoRadio.checked ? "Inactivo" : "Bloqueado"
                        
                        var rolIndex = rolComboBox.currentIndex
                        var rolesValidos = rolesDisponibles.filter(rol => rol !== "Todos los roles")
                        
                        if (isEditMode && editingUser) {
                            // Actualizar usuario existente
                            usuarioModel.actualizarUsuario(
                                editingUser.id.toString(),
                                nombreCompleto.text,
                                apellidoPaterno.text,
                                apellidoMaterno.text,
                                correoElectronico.text,
                                rolIndex + 1, // Ajustar índice para el backend
                                estado
                            )
                        } else {
                            // Crear nuevo usuario
                            usuarioModel.crearUsuario(
                                nombreCompleto.text,
                                apellidoPaterno.text,
                                apellidoMaterno.text,
                                correoElectronico.text,
                                contrasenaField.text,
                                confirmarContrasenaField.text,
                                rolIndex + 1, // Ajustar índice para el backend
                                estado
                            )
                        }
                    }
                }
            }
        }
    }

    // Componente de notificación
    Rectangle {
        id: notificationArea
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 20
        width: 300
        height: 80
        color: successColor
        radius: 8
        visible: false
        z: 1000
        
        property alias messageText: notificationLabel.text
        property alias titleText: notificationTitle.text
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 4
            
            Label {
                id: notificationTitle
                Layout.fillWidth: true
                font.bold: true
                color: whiteColor
                font.pixelSize: 14
            }
            
            Label {
                id: notificationLabel
                Layout.fillWidth: true
                color: whiteColor
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }
        }
        
        Timer {
            id: notificationTimer
            interval: 3000
            onTriggered: notificationArea.visible = false
        }
    }

    // Funciones auxiliares
    function aplicarFiltros() {
        if (usuarioModel) {
            usuarioModel.aplicarFiltros(
                filtroRol.currentText,
                filtroEstado.currentText,
                campoBusqueda.text
            )
        }
    }
    
    function limpiarFormulario() {
        nombreCompleto.text = ""
        apellidoPaterno.text = ""
        apellidoMaterno.text = ""
        correoElectronico.text = ""
        contrasenaField.text = ""
        confirmarContrasenaField.text = ""
        rolComboBox.currentIndex = -1
        activoRadio.checked = true
        isEditMode = false
        editingIndex = -1
        editingUser = null
    }
    
    function mostrarNotificacion(titulo, mensaje, color) {
        notificationArea.color = color
        notificationArea.titleText = titulo
        notificationArea.messageText = mensaje
        notificationArea.visible = true
        notificationTimer.restart()
    }
}