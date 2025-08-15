import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

Item {
    id: usuariosRoot
    objectName: "usuariosRoot"
    
    // ACCESO A PROPIEDADES ADAPTATIVAS DEL MAIN
    readonly property real baseUnit: parent.baseUnit || Math.max(8, Screen.height / 100)
    readonly property real fontBaseSize: parent.fontBaseSize || Math.max(12, Screen.height / 70)
    readonly property real scaleFactor: parent.scaleFactor || Math.min(width / 1400, height / 900)
    
    // ===== COLORES MODERNOS =====
    readonly property color primaryColor: "#3498DB"
    readonly property color successColor: "#10B981"
    readonly property color successColorLight: "#D1FAE5"
    readonly property color dangerColor: "#E74C3C"
    readonly property color dangerColorLight: "#FEE2E2"
    readonly property color warningColor: "#f39c12"
    readonly property color warningColorLight: "#FEF3C7"
    readonly property color lightGrayColor: "#F8F9FA"
    readonly property color textColor: "#2c3e50"
    readonly property color textColorLight: "#6B7280"
    readonly property color whiteColor: "#FFFFFF"
    readonly property color borderColor: "#e0e0e0"
    readonly property color accentColor: "#10B981"
    readonly property color lineColor: "#D1D5DB" // Color para líneas verticales
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
    
    // ✅ NUEVA PROPIEDAD PARA DATOS ORIGINALES - PATRÓN DE DOS CAPAS
    property var usuariosOriginales: []
    
    // ✅ NUEVO LISTMODEL PARA DATOS FILTRADOS
    ListModel {
        id: usuariosFiltradosModel
    }
    
    // Distribución de columnas responsive
    readonly property real colId: 0.08
    readonly property real colNombre: 0.22
    readonly property real colUsuario: 0.15
    readonly property real colCorreo: 0.20
    readonly property real colRol: 0.15
    readonly property real colEstado: 0.10
    readonly property real colAcciones: 0.10
    
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
                
                // ✅ CARGAR DATOS INICIALES AL ARRAY LOCAL
                cargarDatosOriginales()
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
                // ✅ RECARGAR DATOS DESPUÉS DE CREAR
                usuarioModel.recargarDatos()
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
                // ✅ RECARGAR DATOS DESPUÉS DE ACTUALIZAR
                usuarioModel.recargarDatos()
            } else {
                mostrarNotificacion("Error", message, dangerColor)
            }
        }
        
        function onUsuarioEliminado(success, message) {
            if (success) {
                mostrarNotificacion("Éxito", message, successColor)
                selectedRowIndex = -1
                // ✅ RECARGAR DATOS DESPUÉS DE ELIMINAR
                usuarioModel.recargarDatos()
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
        
        // ✅ NUEVA CONEXIÓN PARA RECARGAR DATOS LOCALES
        function onDatosRecargados() {
            cargarDatosOriginales()
        }
    }

    // ✅ NUEVA FUNCIÓN PARA CARGAR DATOS ORIGINALES
    function cargarDatosOriginales() {
        if (!usuarioModel || !usuarioModel.usuarios) return
        
        console.log("🔄 Cargando datos originales de usuarios...")
        
        // Limpiar array original
        usuariosOriginales = []
        
        // Copiar todos los datos del backend al array local
        for (var i = 0; i < usuarioModel.usuarios.length; i++) {
            usuariosOriginales.push(usuarioModel.usuarios[i])
        }
        
        console.log("✅ Usuarios originales cargados:", usuariosOriginales.length)
        
        // Aplicar filtros iniciales para poblar la vista
        aplicarFiltros()
    }

    // ===== LAYOUT PRINCIPAL RESPONSIVO =====
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: baseUnit * 4
        spacing: baseUnit * 3
        
        // ===== CONTENIDO PRINCIPAL =====
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: whiteColor
            radius: baseUnit * 2
            border.color: borderColor
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                
                // ===== HEADER MODERNO =====
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: baseUnit * 8
                    color: lightGrayColor
                    border.color: borderColor
                    border.width: 1
                    
                    Rectangle {
                        anchors.fill: parent
                        anchors.bottomMargin: baseUnit * 2
                        color: parent.color
                        radius: parent.radius
                    }
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: baseUnit * 1.5
                        
                        RowLayout {
                            spacing: baseUnit
                            
                            Label {
                                text: "👤"
                                font.pixelSize: fontBaseSize * 1.8
                                color: primaryColor
                            }
                            
                            Label {
                                text: "Gestión de Usuarios del Sistema"
                                font.pixelSize: fontBaseSize * 1.4
                                font.bold: true
                                font.family: "Segoe UI, Arial, sans-serif"
                                color: textColor
                            }
                            
                            // Loading indicator
                            BusyIndicator {
                                Layout.preferredWidth: baseUnit * 2.5
                                Layout.preferredHeight: baseUnit * 2.5
                                visible: usuarioModel ? usuarioModel.loading : false
                                running: visible
                            }
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        Button {
                            objectName: "newUserButton"
                            text: "➕ Nuevo Usuario"
                            Layout.preferredHeight: baseUnit * 4.5
                            
                            background: Rectangle {
                                color: primaryColor
                                radius: baseUnit
                            }
                            
                            contentItem: Label {
                                text: parent.text
                                color: whiteColor
                                font.bold: true
                                font.pixelSize: fontBaseSize * 0.9
                                font.family: "Segoe UI, Arial, sans-serif"
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
                            Layout.preferredHeight: baseUnit * 4.5
                            
                            background: Rectangle {
                                color: infoColor
                                radius: baseUnit
                            }
                            
                            contentItem: Label {
                                text: parent.text
                                color: whiteColor
                                font.bold: true
                                font.pixelSize: fontBaseSize * 0.9
                                font.family: "Segoe UI, Arial, sans-serif"
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
                
                // ===== FILTROS ADAPTATIVOS =====
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: width < 1000 ? baseUnit * 16 : baseUnit * 8
                    color: "transparent"
                    z: 10
                    
                    GridLayout {
                        anchors.fill: parent
                        anchors.margins: baseUnit * 3
                        anchors.bottomMargin: baseUnit * 1.5
                        
                        columns: width < 1000 ? 2 : 4
                        rowSpacing: baseUnit
                        columnSpacing: baseUnit * 2
                        
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit
                            
                            Label {
                                text: "Filtrar por:"
                                font.bold: true
                                color: textColor
                                font.pixelSize: fontBaseSize * 0.9
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                            
                            ComboBox {
                                id: filtroRol
                                Layout.fillWidth: true
                                Layout.preferredHeight: baseUnit * 4
                                model: rolesDisponibles
                                currentIndex: 0
                                onCurrentTextChanged: aplicarFiltros()
                                
                                contentItem: Label {
                                    text: filtroRol.displayText
                                    font.pixelSize: fontBaseSize * 0.8
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    color: textColor
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: baseUnit
                                    elide: Text.ElideRight
                                }
                            }
                        }
                        
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit
                            
                            Label {
                                text: "Estado:"
                                font.bold: true
                                color: textColor
                                font.pixelSize: fontBaseSize * 0.9
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                            
                            ComboBox {
                                id: filtroEstado
                                Layout.fillWidth: true
                                Layout.preferredHeight: baseUnit * 4
                                model: ["Todos", "Activo", "Inactivo"]
                                currentIndex: 0
                                onCurrentTextChanged: aplicarFiltros()
                                
                                contentItem: Label {
                                    text: filtroEstado.displayText
                                    font.pixelSize: fontBaseSize * 0.8
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    color: textColor
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: baseUnit
                                }
                            }
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        TextField {
                            id: campoBusqueda
                            Layout.fillWidth: true
                            Layout.preferredHeight: baseUnit * 4
                            placeholderText: "Buscar usuario..."
                            onTextChanged: aplicarFiltros()
                            
                            background: Rectangle {
                                color: whiteColor
                                border.color: borderColor
                                border.width: 1
                                radius: baseUnit * 0.8
                            }
                            
                            leftPadding: baseUnit * 1.5
                            rightPadding: baseUnit * 1.5
                            font.pixelSize: fontBaseSize * 0.9
                            font.family: "Segoe UI, Arial, sans-serif"
                        }
                    }
                }
               
                // ===== TABLA MODERNA CON LÍNEAS VERTICALES =====
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.margins: baseUnit * 3
                    Layout.topMargin: 0
                    color: whiteColor
                    border.color: borderColor
                    border.width: 1
                    radius: baseUnit
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 0
                        spacing: 0
                        
                        // HEADER CON LÍNEAS VERTICALES
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: baseUnit * 5
                            color: lightGrayColor
                            border.color: borderColor
                            border.width: 1
                            z: 5
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: baseUnit * 1.5
                                anchors.rightMargin: baseUnit * 1.5
                                spacing: 0
                                
                                // ID COLUMN
                                Item {
                                    Layout.preferredWidth: parent.width * colId
                                    Layout.fillHeight: true
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "ID"
                                        font.bold: true
                                        font.pixelSize: fontBaseSize * 0.85
                                        font.family: "Segoe UI, Arial, sans-serif"
                                        color: textColor
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    
                                    Rectangle {
                                        anchors.right: parent.right
                                        width: 1
                                        height: parent.height
                                        color: lineColor
                                    }
                                }
                                
                                // NOMBRE COLUMN
                                Item {
                                    Layout.preferredWidth: parent.width * colNombre
                                    Layout.fillHeight: true
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "NOMBRE COMPLETO"
                                        font.bold: true
                                        font.pixelSize: fontBaseSize * 0.85
                                        font.family: "Segoe UI, Arial, sans-serif"
                                        color: textColor
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    
                                    Rectangle {
                                        anchors.right: parent.right
                                        width: 1
                                        height: parent.height
                                        color: lineColor
                                    }
                                }
                                
                                // USUARIO COLUMN
                                Item {
                                    Layout.preferredWidth: parent.width * colUsuario
                                    Layout.fillHeight: true
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "USUARIO"
                                        font.bold: true
                                        font.pixelSize: fontBaseSize * 0.85
                                        font.family: "Segoe UI, Arial, sans-serif"
                                        color: textColor
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    
                                    Rectangle {
                                        anchors.right: parent.right
                                        width: 1
                                        height: parent.height
                                        color: lineColor
                                    }
                                }
                                
                                // CORREO COLUMN
                                Item {
                                    Layout.preferredWidth: parent.width * colCorreo
                                    Layout.fillHeight: true
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "CORREO ELECTRÓNICO"
                                        font.bold: true
                                        font.pixelSize: fontBaseSize * 0.85
                                        font.family: "Segoe UI, Arial, sans-serif"
                                        color: textColor
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    
                                    Rectangle {
                                        anchors.right: parent.right
                                        width: 1
                                        height: parent.height
                                        color: lineColor
                                    }
                                }
                                
                                // ROL COLUMN
                                Item {
                                    Layout.preferredWidth: parent.width * colRol
                                    Layout.fillHeight: true
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "ROL/PERFIL"
                                        font.bold: true
                                        font.pixelSize: fontBaseSize * 0.85
                                        font.family: "Segoe UI, Arial, sans-serif"
                                        color: textColor
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    
                                    Rectangle {
                                        anchors.right: parent.right
                                        width: 1
                                        height: parent.height
                                        color: lineColor
                                    }
                                }
                                
                                // ESTADO COLUMN
                                Item {
                                    Layout.preferredWidth: parent.width * colEstado
                                    Layout.fillHeight: true
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "ESTADO"
                                        font.bold: true
                                        font.pixelSize: fontBaseSize * 0.85
                                        font.family: "Segoe UI, Arial, sans-serif"
                                        color: textColor
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    
                                    Rectangle {
                                        anchors.right: parent.right
                                        width: 1
                                        height: parent.height
                                        color: lineColor
                                    }
                                }
                                
                                // ACCIONES COLUMN
                                Item {
                                    Layout.preferredWidth: parent.width * colAcciones
                                    Layout.fillHeight: true
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "ACCIONES"
                                        font.bold: true
                                        font.pixelSize: fontBaseSize * 0.85
                                        font.family: "Segoe UI, Arial, sans-serif"
                                        color: textColor
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }
                            }
                        }
                        
                        // CONTENIDO DE TABLA CON SCROLL Y LÍNEAS VERTICALES
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            
                            ListView {
                                id: usuariosListView
                                // ✅ CAMBIO CRÍTICO: USAR MODELO FILTRADO EN LUGAR DEL BACKEND
                                model: usuariosFiltradosModel
                                
                                delegate: Rectangle {
                                    width: ListView.view.width
                                    height: baseUnit * 5
                                    color: {
                                        if (selectedRowIndex === index) return "#F8F9FA"
                                        return index % 2 === 0 ? whiteColor : "#FAFAFA"
                                    }
                                    
                                    // Borde horizontal sutil
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        height: 1
                                        color: borderColor
                                    }
                                    
                                    // Borde vertical de selección
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: baseUnit * 0.4
                                        color: selectedRowIndex === index ? accentColor : "transparent"
                                        radius: baseUnit * 0.2
                                        visible: selectedRowIndex === index
                                    }
                                    
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: baseUnit * 1.5
                                        anchors.rightMargin: baseUnit * 1.5
                                        spacing: 0
                                        
                                        // ID COLUMN
                                        Item {
                                            Layout.preferredWidth: parent.width * colId
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                text: model.id || ""
                                                color: textColor
                                                font.bold: false
                                                font.pixelSize: fontBaseSize * 0.9
                                                font.family: "Segoe UI, Arial, sans-serif"
                                            }
                                            
                                            Rectangle {
                                                anchors.right: parent.right
                                                width: 1
                                                height: parent.height
                                                color: lineColor
                                            }
                                        }
                                        
                                        // NOMBRE COLUMN
                                        Item {
                                            Layout.preferredWidth: parent.width * colNombre
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                anchors.rightMargin: baseUnit
                                                text: (model.Nombre + " " + model.Apellido_Paterno + " " + model.Apellido_Materno) || ""
                                                color: primaryColor
                                                font.bold: true
                                                font.pixelSize: fontBaseSize * 0.9
                                                font.family: "Segoe UI, Arial, sans-serif"
                                                elide: Text.ElideRight
                                                wrapMode: Text.WordWrap
                                                maximumLineCount: 2
                                            }
                                            
                                            Rectangle {
                                                anchors.right: parent.right
                                                width: 1
                                                height: parent.height
                                                color: lineColor
                                            }
                                        }
                                        
                                        // USUARIO COLUMN
                                        Item {
                                            Layout.preferredWidth: parent.width * colUsuario
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                anchors.rightMargin: baseUnit
                                                text: model.correo ? model.correo.split('@')[0] : ""
                                                color: textColorLight
                                                font.bold: true
                                                font.pixelSize: fontBaseSize * 0.85
                                                font.family: "Segoe UI, Arial, sans-serif"
                                                elide: Text.ElideRight
                                            }
                                            
                                            Rectangle {
                                                anchors.right: parent.right
                                                width: 1
                                                height: parent.height
                                                color: lineColor
                                            }
                                        }
                                        
                                        // CORREO COLUMN
                                        Item {
                                            Layout.preferredWidth: parent.width * colCorreo
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                anchors.rightMargin: baseUnit
                                                text: model.correo || ""
                                                color: textColor
                                                font.bold: false
                                                font.pixelSize: fontBaseSize * 0.85
                                                font.family: "Segoe UI, Arial, sans-serif"
                                                elide: Text.ElideRight
                                                wrapMode: Text.WordWrap
                                                maximumLineCount: 2
                                            }
                                            
                                            Rectangle {
                                                anchors.right: parent.right
                                                width: 1
                                                height: parent.height
                                                color: lineColor
                                            }
                                        }
                                        
                                        // ROL COLUMN
                                        Item {
                                            Layout.preferredWidth: parent.width * colRol
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                anchors.rightMargin: baseUnit
                                                text: model.rol_nombre || ""
                                                color: textColor
                                                font.bold: true
                                                font.pixelSize: fontBaseSize * 0.85
                                                font.family: "Segoe UI, Arial, sans-serif"
                                                elide: Text.ElideRight
                                                wrapMode: Text.WordWrap
                                                maximumLineCount: 2
                                            }
                                            
                                            Rectangle {
                                                anchors.right: parent.right
                                                width: 1
                                                height: parent.height
                                                color: lineColor
                                            }
                                        }
                                        
                                        // ESTADO COLUMN
                                        Item {
                                            Layout.preferredWidth: parent.width * colEstado
                                            Layout.fillHeight: true
                                            
                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: baseUnit * 6.5
                                                height: baseUnit * 2.5
                                                color: {
                                                    switch(model.Estado ? "Activo" : "Inactivo") {
                                                        case "Activo": return successColorLight
                                                        case "Inactivo": return "#F3F4F6"
                                                        case "Bloqueado": return dangerColorLight
                                                        default: return "#F3F4F6"
                                                    }
                                                }
                                                radius: height / 2
                                                
                                                Label {
                                                    anchors.centerIn: parent
                                                    text: model.Estado ? "Activo" : "Inactivo"
                                                    color: {
                                                        switch(model.Estado ? "Activo" : "Inactivo") {
                                                            case "Activo": return "#047857"
                                                            case "Inactivo": return "#6B7280"
                                                            case "Bloqueado": return "#DC2626"
                                                            default: return "#6B7280"
                                                        }
                                                    }
                                                    font.pixelSize: fontBaseSize * 0.7
                                                    font.bold: false
                                                    font.family: "Segoe UI, Arial, sans-serif"
                                                }
                                            }
                                            
                                            Rectangle {
                                                anchors.right: parent.right
                                                width: 1
                                                height: parent.height
                                                color: lineColor
                                            }
                                        }
                                        
                                        // ACCIONES COLUMN
                                        Item {
                                            Layout.preferredWidth: parent.width * colAcciones
                                            Layout.fillHeight: true
                                            
                                            RowLayout {
                                                anchors.centerIn: parent
                                                spacing: baseUnit * 0.5
                                                
                                                Button {
                                                    width: baseUnit * 3.5
                                                    height: baseUnit * 3.5
                                                    text: "✏️"
                                                    
                                                    background: Rectangle {
                                                        color: warningColor
                                                        radius: baseUnit * 0.8
                                                        border.color: "#e67e22"
                                                        border.width: 1
                                                    }
                                                    
                                                    contentItem: Label {
                                                        text: parent.text
                                                        color: whiteColor
                                                        horizontalAlignment: Text.AlignHCenter
                                                        verticalAlignment: Text.AlignVCenter
                                                        font.pixelSize: fontBaseSize * 0.85
                                                    }
                                                    
                                                    onClicked: {
                                                        // ✅ USAR DATOS DEL MODELO FILTRADO
                                                        isEditMode = true
                                                        editingIndex = index
                                                        editingUser = usuariosFiltradosModel.get(index)
                                                        selectedRowIndex = index
                                                        showNewUserDialog = true
                                                    }
                                                }
                                                
                                                Button {
                                                    width: baseUnit * 3.5
                                                    height: baseUnit * 3.5
                                                    text: "🗑️"
                                                    
                                                    background: Rectangle {
                                                        color: dangerColor
                                                        radius: baseUnit * 0.8
                                                        border.color: "#c0392b"
                                                        border.width: 1
                                                    }
                                                    
                                                    contentItem: Label {
                                                        text: parent.text
                                                        color: whiteColor
                                                        horizontalAlignment: Text.AlignHCenter
                                                        verticalAlignment: Text.AlignVCenter
                                                        font.pixelSize: fontBaseSize * 0.85
                                                    }
                                                    
                                                    onClicked: {
                                                        // ✅ USAR DATOS DEL MODELO FILTRADO
                                                        var usuario = usuariosFiltradosModel.get(index)
                                                        if (usuarioModel && usuario.id) {
                                                            usuarioModel.eliminarUsuario(usuario.id.toString())
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    
                                    // LÍNEAS VERTICALES CONTINUAS
                                    Repeater {
                                        model: 6 // Número de líneas verticales (todas menos la última columna)
                                        Rectangle {
                                            property real xPos: {
                                                var w = parent.width - baseUnit * 3
                                                switch(index) {
                                                    case 0: return baseUnit * 1.5 + w * colId
                                                    case 1: return baseUnit * 1.5 + w * (colId + colNombre)
                                                    case 2: return baseUnit * 1.5 + w * (colId + colNombre + colUsuario)
                                                    case 3: return baseUnit * 1.5 + w * (colId + colNombre + colUsuario + colCorreo)
                                                    case 4: return baseUnit * 1.5 + w * (colId + colNombre + colUsuario + colCorreo + colRol)
                                                    case 5: return baseUnit * 1.5 + w * (colId + colNombre + colUsuario + colCorreo + colRol + colEstado)
                                                }
                                            }
                                            x: xPos
                                            width: 1
                                            height: parent.height
                                            color: lineColor
                                            z: 1
                                        }
                                    }
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            selectedRowIndex = selectedRowIndex === index ? -1 : index
                                            console.log("Seleccionado usuario ID:", usuariosFiltradosModel.get(index).id)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                // ✅ ESTADO VACÍO PARA TABLA SIN DATOS
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: usuariosFiltradosModel.count === 0 && usuariosOriginales.length === 0
                    spacing: baseUnit * 3
                    
                    Item { Layout.fillHeight: true }
                    
                    ColumnLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: baseUnit * 1.5
                        
                        Label {
                            text: "👤"
                            font.pixelSize: fontBaseSize * 4
                            color: "#E5E7EB"
                            Layout.alignment: Qt.AlignHCenter
                        }
                        
                        Label {
                            text: "No hay usuarios registrados"
                            color: textColor
                            font.bold: true
                            font.pixelSize: fontBaseSize * 1.2
                            font.family: "Segoe UI, Arial, sans-serif"
                            Layout.alignment: Qt.AlignHCenter
                        }
                        
                        Label {
                            text: "Crea el primer usuario haciendo clic en \"➕ Nuevo Usuario\""
                            color: textColorLight
                            font.pixelSize: fontBaseSize * 0.9
                            font.family: "Segoe UI, Arial, sans-serif"
                            Layout.alignment: Qt.AlignHCenter
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                            Layout.maximumWidth: baseUnit * 40
                        }
                    }
                    
                    Item { Layout.fillHeight: true }
                }
                
                // ✅ MENSAJE DE NO RESULTADOS PARA FILTROS
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: usuariosFiltradosModel.count === 0 && usuariosOriginales.length > 0
                    spacing: baseUnit * 3
                    
                    Item { Layout.fillHeight: true }
                    
                    ColumnLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: baseUnit * 1.5
                        
                        Label {
                            text: "🔍"
                            font.pixelSize: fontBaseSize * 4
                            color: "#E5E7EB"
                            Layout.alignment: Qt.AlignHCenter
                        }
                        
                        Label {
                            text: "No hay usuarios que coincidan con los filtros"
                            color: textColor
                            font.bold: true
                            font.pixelSize: fontBaseSize * 1.2
                            font.family: "Segoe UI, Arial, sans-serif"
                            Layout.alignment: Qt.AlignHCenter
                        }
                        
                        Label {
                            text: "Prueba cambiando los filtros o limpiando la búsqueda"
                            color: textColorLight
                            font.pixelSize: fontBaseSize * 0.9
                            font.family: "Segoe UI, Arial, sans-serif"
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                    
                    Item { Layout.fillHeight: true }
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
        width: Math.min(800, parent.width * 0.9)
        height: Math.min(550, parent.height * 0.9)
        color: whiteColor
        radius: baseUnit * 1.5
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
            anchors.margins: baseUnit * 3
            spacing: baseUnit * 1.5
            
            // Título
            Label {
                Layout.fillWidth: true
                text: isEditMode ? "Editar Usuario" : "Nuevo Usuario"
                font.pixelSize: fontBaseSize * 1.6
                font.bold: true
                font.family: "Segoe UI, Arial, sans-serif"
                color: textColor
                horizontalAlignment: Text.AlignHCenter
            }
            
            // Contenido principal en dos columnas
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: baseUnit * 2
                
                // COLUMNA IZQUIERDA - Datos del Usuario
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: lightGrayColor
                    radius: baseUnit
                    border.color: borderColor
                    border.width: 1
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: baseUnit * 1.5
                        spacing: baseUnit
                        
                        Label {
                            text: "Datos del Usuario"
                            font.bold: true
                            font.pixelSize: fontBaseSize * 1.1
                            font.family: "Segoe UI, Arial, sans-serif"
                            color: textColor
                        }
                        
                        // Nombre
                        TextField {
                            id: nombreCompleto
                            Layout.fillWidth: true
                            Layout.preferredHeight: baseUnit * 4
                            placeholderText: "Nombre"
                            font.pixelSize: fontBaseSize * 0.9
                            font.family: "Segoe UI, Arial, sans-serif"
                            background: Rectangle {
                                color: whiteColor
                                border.color: borderColor
                                border.width: 1
                                radius: baseUnit * 0.5
                            }
                        }
                        
                        // Apellido Paterno
                        TextField {
                            id: apellidoPaterno
                            Layout.fillWidth: true
                            Layout.preferredHeight: baseUnit * 4
                            placeholderText: "Apellido Paterno"
                            font.pixelSize: fontBaseSize * 0.9
                            font.family: "Segoe UI, Arial, sans-serif"
                            background: Rectangle {
                                color: whiteColor
                                border.color: borderColor
                                border.width: 1
                                radius: baseUnit * 0.5
                            }
                        }
                        
                        // Apellido Materno
                        TextField {
                            id: apellidoMaterno
                            Layout.fillWidth: true
                            Layout.preferredHeight: baseUnit * 4
                            placeholderText: "Apellido Materno"
                            font.pixelSize: fontBaseSize * 0.9
                            font.family: "Segoe UI, Arial, sans-serif"
                            background: Rectangle {
                                color: whiteColor
                                border.color: borderColor
                                border.width: 1
                                radius: baseUnit * 0.5
                            }
                        }
                        
                        // Correo Electrónico
                        TextField {
                            id: correoElectronico
                            Layout.fillWidth: true
                            Layout.preferredHeight: baseUnit * 4
                            placeholderText: "correo@clinica.com"
                            font.pixelSize: fontBaseSize * 0.9
                            font.family: "Segoe UI, Arial, sans-serif"
                            background: Rectangle {
                                color: whiteColor
                                border.color: borderColor
                                border.width: 1
                                radius: baseUnit * 0.5
                            }
                        }
                        
                        // Contraseñas (solo en modo nuevo usuario)
                        TextField {
                            id: contrasenaField
                            Layout.fillWidth: true
                            Layout.preferredHeight: baseUnit * 4
                            placeholderText: "Contraseña"
                            echoMode: TextInput.Password
                            visible: !isEditMode
                            font.pixelSize: fontBaseSize * 0.9
                            font.family: "Segoe UI, Arial, sans-serif"
                            background: Rectangle {
                                color: whiteColor
                                border.color: borderColor
                                border.width: 1
                                radius: baseUnit * 0.5
                            }
                        }
                        
                        TextField {
                            id: confirmarContrasenaField
                            Layout.fillWidth: true
                            Layout.preferredHeight: baseUnit * 4
                            placeholderText: "Confirmar contraseña"
                            echoMode: TextInput.Password
                            visible: !isEditMode
                            font.pixelSize: fontBaseSize * 0.9
                            font.family: "Segoe UI, Arial, sans-serif"
                            background: Rectangle {
                                color: whiteColor
                                border.color: borderColor
                                border.width: 1
                                radius: baseUnit * 0.5
                            }
                        }
                        
                        // Rol
                        ComboBox {
                            id: rolComboBox
                            Layout.fillWidth: true
                            Layout.preferredHeight: baseUnit * 4
                            model: rolesDisponibles.filter(rol => rol !== "Todos los roles")
                            displayText: currentIndex >= 0 ? model[currentIndex] : "Seleccione rol"
                            
                            background: Rectangle {
                                color: whiteColor
                                border.color: borderColor
                                border.width: 1
                                radius: baseUnit * 0.5
                            }
                            
                            contentItem: Label {
                                text: rolComboBox.displayText
                                font.pixelSize: fontBaseSize * 0.9
                                font.family: "Segoe UI, Arial, sans-serif"
                                color: textColor
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: baseUnit
                                elide: Text.ElideRight
                            }
                        }
                        
                        Item { Layout.fillHeight: true }
                    }
                }
                
                // COLUMNA DERECHA - Estado
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: lightGrayColor
                    radius: baseUnit
                    border.color: borderColor
                    border.width: 1
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: baseUnit * 1.5
                        spacing: baseUnit
                        
                        Label {
                            text: "Estado del Usuario"
                            font.bold: true
                            font.pixelSize: fontBaseSize * 1.1
                            font.family: "Segoe UI, Arial, sans-serif"
                            color: textColor
                        }
                        
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit * 0.5
                            
                            RadioButton {
                                id: activoRadio
                                text: "Activo"
                                checked: true
                                font.pixelSize: fontBaseSize * 0.9
                                font.family: "Segoe UI, Arial, sans-serif"
                                
                                contentItem: Label {
                                    text: activoRadio.text
                                    font.pixelSize: fontBaseSize * 0.9
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    color: textColor
                                    leftPadding: activoRadio.indicator.width + activoRadio.spacing
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                            
                            RadioButton {
                                id: inactivoRadio
                                text: "Inactivo"
                                font.pixelSize: fontBaseSize * 0.9
                                font.family: "Segoe UI, Arial, sans-serif"
                                
                                contentItem: Label {
                                    text: inactivoRadio.text
                                    font.pixelSize: fontBaseSize * 0.9
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    color: textColor
                                    leftPadding: inactivoRadio.indicator.width + inactivoRadio.spacing
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                            
                            RadioButton {
                                id: bloqueadoRadio
                                text: "Bloqueado"
                                font.pixelSize: fontBaseSize * 0.9
                                font.family: "Segoe UI, Arial, sans-serif"
                                
                                contentItem: Label {
                                    text: bloqueadoRadio.text
                                    font.pixelSize: fontBaseSize * 0.9
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    color: textColor
                                    leftPadding: bloqueadoRadio.indicator.width + bloqueadoRadio.spacing
                                    verticalAlignment: Text.AlignVCenter
                                }
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
                    Layout.preferredWidth: baseUnit * 10
                    Layout.preferredHeight: baseUnit * 4
                    background: Rectangle {
                        color: lightGrayColor
                        radius: baseUnit * 0.8
                    }
                    contentItem: Label {
                        text: parent.text
                        color: textColor
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: fontBaseSize * 0.9
                        font.family: "Segoe UI, Arial, sans-serif"
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
                    Layout.preferredWidth: baseUnit * 10
                    Layout.preferredHeight: baseUnit * 4
                    enabled: nombreCompleto.text.length > 0 &&
                            apellidoPaterno.text.length > 0 &&
                            apellidoMaterno.text.length > 0 &&
                            correoElectronico.text.length > 0 &&
                            rolComboBox.currentIndex >= 0 &&
                            (isEditMode || (contrasenaField.text.length > 0 && contrasenaField.text === confirmarContrasenaField.text))
                    background: Rectangle {
                        color: parent.enabled ? primaryColor : "#bdc3c7"
                        radius: baseUnit * 0.8
                    }
                    contentItem: Label {
                        text: parent.text
                        color: whiteColor
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: fontBaseSize * 0.9
                        font.family: "Segoe UI, Arial, sans-serif"
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
        anchors.margins: baseUnit * 2
        width: baseUnit * 30
        height: baseUnit * 8
        color: successColor
        radius: baseUnit
        visible: false
        z: 1000
        
        property alias messageText: notificationLabel.text
        property alias titleText: notificationTitle.text
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: baseUnit
            spacing: baseUnit * 0.5
            
            Label {
                id: notificationTitle
                Layout.fillWidth: true
                font.bold: true
                color: whiteColor
                font.pixelSize: fontBaseSize * 1.1
                font.family: "Segoe UI, Arial, sans-serif"
            }
            
            Label {
                id: notificationLabel
                Layout.fillWidth: true
                color: whiteColor
                font.pixelSize: fontBaseSize * 0.9
                font.family: "Segoe UI, Arial, sans-serif"
                wrapMode: Text.WordWrap
            }
        }
        
        Timer {
            id: notificationTimer
            interval: 3000
            onTriggered: notificationArea.visible = false
        }
    }

    // ✅ NUEVA FUNCIÓN DE FILTRADO DEL LADO DEL CLIENTE
    function aplicarFiltros() {
        console.log("🔍 Aplicando filtros en el cliente...")
        
        // Limpiar el modelo filtrado
        usuariosFiltradosModel.clear()
        
        var textoBusqueda = campoBusqueda.text.toLowerCase()
        var rolSeleccionado = filtroRol.currentText
        var estadoSeleccionado = filtroEstado.currentText
        
        for (var i = 0; i < usuariosOriginales.length; i++) {
            var usuario = usuariosOriginales[i]
            var mostrar = true
            
            // Filtro por rol
            if (rolSeleccionado !== "Todos los roles" && mostrar) {
                if (usuario.rol_nombre !== rolSeleccionado) {
                    mostrar = false
                }
            }
            
            // Filtro por estado
            if (estadoSeleccionado !== "Todos" && mostrar) {
                var estadoUsuario = usuario.Estado ? "Activo" : "Inactivo"
                if (estadoUsuario !== estadoSeleccionado) {
                    mostrar = false
                }
            }
            
            // Búsqueda por texto en nombre, apellidos o correo
            if (textoBusqueda.length > 0 && mostrar) {
                var nombreCompleto = (usuario.Nombre + " " + usuario.Apellido_Paterno + " " + usuario.Apellido_Materno).toLowerCase()
                var correo = (usuario.correo || "").toLowerCase()
                var usuarioNombre = correo.split('@')[0] || ""
                
                if (!nombreCompleto.includes(textoBusqueda) &&
                    !correo.includes(textoBusqueda) &&
                    !usuarioNombre.includes(textoBusqueda)) {
                    mostrar = false
                }
            }
            
            if (mostrar) {
                usuariosFiltradosModel.append(usuario)
            }
        }
        
        console.log("✅ Filtros aplicados. Usuarios mostrados:", usuariosFiltradosModel.count, "de", usuariosOriginales.length)
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