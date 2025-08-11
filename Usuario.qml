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
    // Modelo para usuarios existentes
    property var usuariosModel: [
        {
            usuarioId: "1",
            nombreCompleto: "Luis López",
            nombreUsuario: "luis.lopez",
            correoElectronico: "luis.lopez@clinica.com",
            rolPerfil: "Administrador",
            estado: "Activo",
            ultimoAcceso: "2025-06-21 08:30",
            fechaRegistro: "2025-01-01"
        },
        {
            usuarioId: "2",
            nombreCompleto: "Dr. Juan Carlos Mendoza",
            nombreUsuario: "juan.mendoza",
            correoElectronico: "juan.mendoza@clinica.com",
            rolPerfil: "Médico",
            estado: "Activo",
            ultimoAcceso: "2025-06-21 07:45",
            fechaRegistro: "2025-01-15"
        },
        {
            usuarioId: "3",
            nombreCompleto: "María Elena Vargas",
            nombreUsuario: "maria.vargas",
            correoElectronico: "maria.vargas@clinica.com",
            rolPerfil: "Recepcionista",
            estado: "Activo",
            ultimoAcceso: "2025-06-20 18:00",
            fechaRegistro: "2025-02-10"
        },
        {
            usuarioId: "4",
            nombreCompleto: "Ana Patricia Silva",
            nombreUsuario: "ana.silva",
            correoElectronico: "ana.silva@clinica.com",
            rolPerfil: "Enfermero",
            estado: "Inactivo",
            ultimoAcceso: "2025-06-15 16:30",
            fechaRegistro: "2025-01-08"
        },
        {
            usuarioId: "5",
            nombreCompleto: "Roberto García",
            nombreUsuario: "roberto.garcia",
            correoElectronico: "roberto.garcia@clinica.com",
            rolPerfil: "Laboratorista",
            estado: "Bloqueado",
            ultimoAcceso: "2025-06-10 14:15",
            fechaRegistro: "2025-03-01"
        }
    ]

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
                                showNewUserDialog = true
                            }
                        }
                    }
                }
                
                // Filtros y búsqueda - FIJO
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    color: "transparent"
                    z: 10
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 32
                        spacing: 16
                        
                        Label {
                            text: "Filtrar por:"
                            font.bold: true
                            color: textColor
                        }
                        
                        ComboBox {
                            id: filtroRol
                            Layout.preferredWidth: 150
                            model: ["Todos los roles", "Administrador", "Médico", "Recepcionista", "Enfermero", "Laboratorista", "Cajero"]
                            currentIndex: 0
                            onCurrentIndexChanged: aplicarFiltros()
                        }
                        
                        Label {
                            text: "Estado:"
                            font.bold: true
                            color: textColor
                        }
                        
                        ComboBox {
                            id: filtroEstado
                            Layout.preferredWidth: 120
                            model: ["Todos", "Activo", "Inactivo", "Bloqueado"]
                            currentIndex: 0
                            onCurrentIndexChanged: aplicarFiltros()
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        TextField {
                            id: campoBusqueda
                            Layout.preferredWidth: 200
                            placeholderText: "Buscar usuario..."
                            onTextChanged: aplicarFiltros()
                            
                            background: Rectangle {
                                color: whiteColor
                                border.color: "#e0e0e0"
                                border.width: 1
                                radius: 8
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
                            model: ListModel {
                                id: usuariosListModel
                                Component.onCompleted: {
                                    // Cargar datos iniciales
                                    for (var i = 0; i < usuariosModel.length; i++) {
                                        append(usuariosModel[i])
                                    }
                                }
                            }
                            
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
                                            text: "ÚLTIMO ACCESO"
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
                                            text: model.usuarioId
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
                                            text: model.nombreCompleto
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
                                            text: model.nombreUsuario || ""
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
                                            text: model.correoElectronico
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
                                            text: model.rolPerfil
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
                                                switch(model.estado) {
                                                    case "Activo": return successColor
                                                    case "Inactivo": return "#95a5a6"
                                                    case "Bloqueado": return dangerColor
                                                    default: return "#95a5a6"
                                                }
                                            }
                                            radius: 12
                                            
                                            Label {
                                                anchors.centerIn: parent
                                                text: model.estado
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
                                        
                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 4
                                            spacing: 2
                                            
                                            Label { 
                                                Layout.fillWidth: true
                                                text: {
                                                    var fecha = model.ultimoAcceso.split(" ")[0]
                                                    return fecha
                                                }
                                                color: textColor
                                                font.pixelSize: 10
                                                font.bold: true
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                            Label { 
                                                Layout.fillWidth: true
                                                text: {
                                                    var hora = model.ultimoAcceso.split(" ")[1]
                                                    return hora || ""
                                                }
                                                color: "#7f8c8d"
                                                font.pixelSize: 9
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                        }
                                    }
                                }
                                
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        selectedRowIndex = index
                                        console.log("Seleccionado usuario ID:", model.usuarioId)
                                    }
                                }
                                
                                // Botones de acción que aparecen cuando se selecciona la fila
                                RowLayout {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: 8
                                    spacing: 4
                                    visible: selectedRowIndex === index
                                    z: 10
                                    
                                    Button {
                                        id: editButton
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
                                            var usuario = usuariosListModel.get(index)
                                            console.log("Editando usuario:", JSON.stringify(usuario))
                                            showNewUserDialog = true
                                        }
                                    }
                                    
                                    Button {
                                        id: deleteButton
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
                                            usuariosListModel.remove(index)
                                            selectedRowIndex = -1
                                            console.log("Usuario eliminado en índice:", index)
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

    // Diálogo Nuevo Usuario / Editar Usuario Optimizado
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
            if (isEditMode && editingIndex >= 0) {
                var usuario = usuariosListModel.get(editingIndex)
                
                // Cargar datos del usuario
                nombreCompleto.text = usuario.nombreCompleto || ""
                nombreUsuario.text = usuario.nombreUsuario || ""
                correoElectronico.text = usuario.correoElectronico || ""
                rolField.text = usuario.rolPerfil || ""
                
                // Configurar estado
                switch(usuario.estado) {
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
                
                // Cargar permisos si existen
                if (usuario.permisos) {
                    userForm.selectedPermisos = usuario.permisos
                }
            }
        }
        
        onVisibleChanged: {
            if (visible && isEditMode) {
                loadEditData()
            } else if (visible && !isEditMode) {
                // Limpiar formulario para nuevo usuario
                nombreCompleto.text = ""
                nombreUsuario.text = ""
                correoElectronico.text = ""
                rolField.text = ""
                contrasenaField.text = ""
                confirmarContrasenaField.text = ""
                activoRadio.checked = true
                userForm.selectedPermisos = {}
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
                        
                        // Nombre Completo
                        TextField {
                            id: nombreCompleto
                            Layout.fillWidth: true
                            placeholderText: "Nombre completo"
                            background: Rectangle {
                                color: whiteColor
                                border.color: lightGrayColor
                                border.width: 1
                                radius: 4
                            }
                        }
                        
                        // Nombre de Usuario (acceso al sistema)
                        TextField {
                            id: nombreUsuario
                            Layout.fillWidth: true
                            placeholderText: "Nombre de usuario (acceso)"
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
                        TextField {
                            id: rolField
                            Layout.fillWidth: true
                            placeholderText: "Rol del usuario"
                            background: Rectangle {
                                color: whiteColor
                                border.color: lightGrayColor
                                border.width: 1
                                radius: 4
                            }
                        }
                        
                        Item { Layout.fillHeight: true }
                    }
                }
                
                // COLUMNA DERECHA - Permisos y Estado
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
                            text: "Permisos de Acceso"
                            font.bold: true
                            font.pixelSize: 14
                            color: textColor
                        }
                        
                        // Lista de permisos
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            
                            ColumnLayout {
                                width: parent.width
                                spacing: 6
                                
                                Repeater {
                                    model: userForm.modulosDisponibles
                                    
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 32
                                        color: permisoCheck.checked ? "#e3f2fd" : "transparent"
                                        radius: 4
                                        border.color: permisoCheck.checked ? primaryColor : "transparent"
                                        border.width: 1
                                        
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 8
                                            
                                            CheckBox {
                                                id: permisoCheck
                                                checked: userForm.selectedPermisos[modelData] || false
                                                onCheckedChanged: {
                                                    var permisos = userForm.selectedPermisos
                                                    if (checked) {
                                                        permisos[modelData] = true
                                                    } else {
                                                        delete permisos[modelData]
                                                    }
                                                    userForm.selectedPermisos = permisos
                                                }
                                            }
                                            
                                            Label {
                                                Layout.fillWidth: true
                                                text: modelData
                                                color: textColor
                                                font.pixelSize: 13
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: lightGrayColor
                        }
                        
                        // Estado
                        Label {
                            text: "Estado"
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
                    }
                }
                
                Button {
                    text: isEditMode ? "Actualizar" : "Guardar"
                    Layout.preferredWidth: 100
                    enabled: nombreCompleto.text.length > 0 &&
                            nombreUsuario.text.length > 0 &&
                            correoElectronico.text.length > 0 &&
                            rolField.text.length > 0 &&
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
                        // Crear datos de usuario
                        var estado = activoRadio.checked ? "Activo" : 
                                    inactivoRadio.checked ? "Inactivo" : "Bloqueado"
                        
                        var usuarioData = {
                            nombreCompleto: nombreCompleto.text,
                            nombreUsuario: nombreUsuario.text,
                            correoElectronico: correoElectronico.text,
                            rolPerfil: rolField.text,
                            permisos: userForm.selectedPermisos,
                            estado: estado,
                            ultimoAcceso: isEditMode ? usuariosListModel.get(editingIndex).ultimoAcceso : "Nunca",
                            fechaRegistro: new Date().toISOString().split('T')[0]
                        }
                        
                        if (isEditMode && editingIndex >= 0) {
                            // Actualizar usuario existente
                            var usuarioExistente = usuariosListModel.get(editingIndex)
                            usuarioData.usuarioId = usuarioExistente.usuarioId
                            
                            usuariosListModel.set(editingIndex, usuarioData)
                            console.log("Usuario actualizado:", JSON.stringify(usuarioData))
                        } else {
                            // Crear nuevo usuario
                            usuarioData.usuarioId = (usuariosListModel.count + 1).toString()
                            usuariosListModel.append(usuarioData)
                            console.log("Nuevo usuario guardado:", JSON.stringify(usuarioData))
                        }
                        
                        // Limpiar y cerrar
                        showNewUserDialog = false
                        selectedRowIndex = -1
                        isEditMode = false
                        editingIndex = -1
                    }
                }
            }
        }
    }

    // Función para aplicar filtros
    function aplicarFiltros() {
        usuariosListModel.clear()
        
        var textoBusqueda = campoBusqueda.text.toLowerCase()
        
        for (var i = 0; i < usuariosModel.length; i++) {
            var usuario = usuariosModel[i]
            var mostrar = true
            
            // Filtro por rol
            if (filtroRol.currentIndex > 0 && mostrar) {
                var rolSeleccionado = filtroRol.model[filtroRol.currentIndex]
                if (usuario.rolPerfil !== rolSeleccionado) {
                    mostrar = false
                }
            }
            
            // Filtro por estado
            if (filtroEstado.currentIndex > 0 && mostrar) {
                var estadoSeleccionado = filtroEstado.model[filtroEstado.currentIndex]
                if (usuario.estado !== estadoSeleccionado) {
                    mostrar = false
                }
            }
            
            // Búsqueda por texto en nombre o correo
            if (textoBusqueda.length > 0 && mostrar) {
                if (!usuario.nombreCompleto.toLowerCase().includes(textoBusqueda) && 
                    !usuario.correoElectronico.toLowerCase().includes(textoBusqueda)) {
                    mostrar = false
                }
            }
            
            if (mostrar) {
                usuariosListModel.append(usuario)
            }
        }
    }
}