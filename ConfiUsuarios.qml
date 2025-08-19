import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

Item {
    id: confiUsuariosRoot
    objectName: "confiUsuariosRoot"
    
    // ===== SISTEMA DE ESCALADO RESPONSIVO =====
    readonly property real baseUnit: Math.min(width, height) / 100
    readonly property real fontBase: baseUnit * 2.0
    readonly property real marginSmall: baseUnit * 1
    readonly property real marginMedium: baseUnit * 2
    readonly property real marginLarge: baseUnit * 3
    
    // ===== PALETA DE COLORES PROFESIONAL =====
    readonly property string primaryColor: "#6366F1"
    readonly property string surfaceColor: "#F8FAFC"
    readonly property string borderColor: "#E5E7EB"
    readonly property string textColor: "#111827"
    readonly property string textSecondaryColor: "#6B7280"
    readonly property string successColor: "#059669"
    readonly property string warningColor: "#D97706"
    readonly property string dangerColor: "#DC2626"
    readonly property string backgroundColor: "#FFFFFF"
    readonly property string usuariosColor: "#EA580C"
    
    // ===== PROPIEDADES DE ESTADO =====
    property bool isEditMode: false
    property int editingIndex: -1
    property var editingUser: null
    property bool showModal: false
    
    // ===== REFERENCIA AL MODELO DE USUARIO =====
    property var usuarioModel: null
    property var rolesDisponibles: []
    
    // ===== MODELO FILTRADO PARA LA LISTA =====
    ListModel {
        id: usuariosFiltradosModel
    }
    
    // ===== DATOS ORIGINALES =====
    property var usuariosOriginales: []
    
    // ===== FUNCIÓN PARA VOLVER A LA VISTA PRINCIPAL =====
    signal backToMain()
    
    // ===== INICIALIZACIÓN =====
    Component.onCompleted: {
        if (appController && appController.usuario_model_instance) {
            usuarioModel = appController.usuario_model_instance
            rolesDisponibles = usuarioModel.obtenerRolesDisponibles()
            cargarDatosOriginales()
        }
    }
    
    // ===== CONEXIONES CON EL CONTROLADOR =====
    Connections {
        target: appController
        function onModelsReady() {
            if (appController.usuario_model_instance) {
                usuarioModel = appController.usuario_model_instance
                rolesDisponibles = usuarioModel.obtenerRolesDisponibles()
                cargarDatosOriginales()
            }
        }
    }
    
    // ===== CONEXIONES CON EL MODELO DE USUARIO =====
    Connections {
        target: usuarioModel
        
        function onUsuarioCreado(success, message) {
            if (success) {
                mostrarNotificacion("Éxito", message, successColor)
                limpiarFormulario()
                showModal = false
                usuarioModel.recargarDatos()
            } else {
                mostrarNotificacion("Error", message, dangerColor)
            }
        }
        
        function onUsuarioActualizado(success, message) {
            if (success) {
                mostrarNotificacion("Éxito", message, successColor)
                limpiarFormulario()
                showModal = false
                usuarioModel.recargarDatos()
            } else {
                mostrarNotificacion("Error", message, dangerColor)
            }
        }
        
        function onUsuarioEliminado(success, message) {
            if (success) {
                mostrarNotificacion("Éxito", message, successColor)
                usuarioModel.recargarDatos()
            } else {
                mostrarNotificacion("Error", message, dangerColor)
            }
        }
        
        function onDatosRecargados() {
            cargarDatosOriginales()
        }
    }
    
    // ===== LAYOUT PRINCIPAL =====
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        
        // ===== HEADER PRINCIPAL UNIFICADO (AZUL CON BOTÓN DE VOLVER) =====
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: baseUnit * 12
            gradient: Gradient {
                GradientStop { position: 0.0; color: usuariosColor }
                GradientStop { position: 1.0; color: Qt.darker(usuariosColor, 1.1) }
            }
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: marginLarge
                spacing: marginMedium
                
                // ===== BOTÓN DE VOLVER =====
                Button {
                    Layout.preferredWidth: baseUnit * 6
                    Layout.preferredHeight: baseUnit * 6
                    text: "←"
                    
                    background: Rectangle {
                        color: backgroundColor
                        radius: baseUnit * 0.8
                        opacity: parent.pressed ? 0.8 : 1.0
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        color: usuariosColor
                        font.pixelSize: baseUnit * 2.5
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        // Emitir señal para volver a la vista principal
                        if (typeof changeView !== "undefined") {
                            changeView("main")
                        } else {
                            backToMain()
                        }
                    }
                }
                
                // ===== ÍCONO DEL MÓDULO =====
                Rectangle {
                    Layout.preferredWidth: baseUnit * 8
                    Layout.preferredHeight: baseUnit * 8
                    color: backgroundColor
                    radius: baseUnit * 4
                    
                    Label {
                        anchors.centerIn: parent
                        text: "👤"
                        font.pixelSize: fontBase * 1.8
                    }
                }
                
                // ===== INFORMACIÓN DEL MÓDULO =====
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: marginSmall * 0.5
                    
                    Label {
                        text: "Configuraciones de Usuarios"
                        color: backgroundColor
                        font.pixelSize: fontBase * 1.4
                        font.bold: true
                        font.family: "Segoe UI"
                    }
                    
                    Label {
                        text: "Centro de control para gestionar usuarios, roles y permisos del sistema"
                        color: backgroundColor
                        font.pixelSize: fontBase * 0.9
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        opacity: 0.95
                        font.family: "Segoe UI"
                    }
                }
                
                // ===== BOTÓN NUEVO USUARIO =====
                Button {
                    Layout.preferredHeight: baseUnit * 6
                    text: "➕ Nuevo Usuario"
                    
                    background: Rectangle {
                        color: backgroundColor
                        radius: baseUnit
                        opacity: parent.pressed ? 0.8 : 1.0
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        color: usuariosColor
                        font.bold: true
                        font.pixelSize: fontBase * 0.9
                        horizontalAlignment: Text.AlignHCenter
                    }
                    
                    onClicked: {
                        limpiarFormulario()
                        showModal = true
                    }
                }
            }
        }
        
        // ===== ÁREA DE CONTENIDO =====
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: surfaceColor
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: marginLarge
                spacing: marginMedium
                
                // ===== FILTROS PARA LA LISTA =====
                RowLayout {
                    Layout.fillWidth: true
                    spacing: marginMedium
                    
                    Label {
                        text: "Filtrar:"
                        font.bold: true
                        color: textColor
                        font.pixelSize: fontBase * 0.9
                    }
                    
                    ComboBox {
                        id: filtroRol
                        Layout.preferredWidth: 180
                        model: rolesDisponibles
                        currentIndex: 0
                        onCurrentTextChanged: aplicarFiltros()
                        
                        background: Rectangle {
                            color: backgroundColor
                            border.color: borderColor
                            border.width: 1
                            radius: baseUnit * 0.5
                        }
                    }
                    
                    TextField {
                        id: campoBusqueda
                        Layout.fillWidth: true
                        placeholderText: "🔍 Buscar usuario..."
                        onTextChanged: aplicarFiltros()
                        
                        background: Rectangle {
                            color: backgroundColor
                            border.color: borderColor
                            border.width: 1
                            radius: baseUnit * 0.5
                        }
                    }
                    
                    Label {
                        text: "Total: " + usuariosFiltradosModel.count
                        color: textSecondaryColor
                        font.pixelSize: fontBase * 0.8
                    }
                }
                
                // ===== SECCIÓN DE LISTADO DE USUARIOS (MÁS PROMINENTE) =====
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: baseUnit * 40
                    color: backgroundColor
                    border.color: borderColor
                    border.width: 1
                    radius: baseUnit
                    
                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: marginMedium
                        clip: true
                        
                        ListView {
                            id: usuariosListView
                            model: usuariosFiltradosModel
                            spacing: marginSmall
                            
                            delegate: Rectangle {
                                width: ListView.view.width
                                height: baseUnit * 10
                                color: backgroundColor
                                radius: baseUnit * 0.8
                                border.color: borderColor
                                border.width: 1
                                
                                // Efecto hover
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: parent.border.color = primaryColor
                                    onExited: parent.border.color = borderColor
                                }
                                
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: marginMedium
                                    spacing: marginMedium
                                    
                                    // ===== LADO IZQUIERDO =====
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: marginMedium
                                        
                                        // Círculo con iniciales
                                        Rectangle {
                                            Layout.preferredWidth: baseUnit * 6
                                            Layout.preferredHeight: baseUnit * 6
                                            radius: baseUnit * 3
                                            color: primaryColor
                                            
                                            Label {
                                                anchors.centerIn: parent
                                                text: {
                                                    var nombre = model.Nombre || ""
                                                    var apellido = model.Apellido_Paterno || ""
                                                    return (nombre.charAt(0) + apellido.charAt(0)).toUpperCase()
                                                }
                                                color: backgroundColor
                                                font.bold: true
                                                font.pixelSize: fontBase
                                            }
                                        }
                                        
                                        // Información del usuario
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: marginSmall * 0.5
                                            
                                            Label {
                                                text: (model.Nombre + " " + model.Apellido_Paterno + " " + model.Apellido_Materno) || ""
                                                color: textColor
                                                font.bold: true
                                                font.pixelSize: fontBase
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                            
                                            RowLayout {
                                                spacing: marginMedium
                                                
                                                Label {
                                                    text: model.rol_nombre || ""
                                                    color: textSecondaryColor
                                                    font.pixelSize: fontBase * 0.8
                                                }
                                                
                                                Label {
                                                    text: "•"
                                                    color: textSecondaryColor
                                                    font.pixelSize: fontBase * 0.8
                                                }
                                                
                                                Label {
                                                    text: model.correo || ""
                                                    color: textSecondaryColor
                                                    font.pixelSize: fontBase * 0.8
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                            }
                                        }
                                    }
                                    
                                    // ===== LADO DERECHO =====
                                    RowLayout {
                                        spacing: marginMedium
                                        
                                        // Badge de estado
                                        Rectangle {
                                            width: baseUnit * 8
                                            height: baseUnit * 3
                                            color: model.Estado ? "#D1FAE5" : "#F3F4F6"
                                            radius: height / 2
                                            
                                            Label {
                                                anchors.centerIn: parent
                                                text: model.Estado ? "Activo" : "Inactivo"
                                                color: model.Estado ? "#047857" : "#6B7280"
                                                font.pixelSize: fontBase * 0.7
                                                font.bold: true
                                            }
                                        }
                                        
                                        // Botones de acción
                                        RowLayout {
                                            spacing: marginSmall
                                            
                                            Button {
                                                Layout.preferredWidth: baseUnit * 7
                                                Layout.preferredHeight: baseUnit * 3.5
                                                text: "✏️"
                                                
                                                background: Rectangle {
                                                    color: warningColor
                                                    radius: baseUnit * 0.5
                                                }
                                                
                                                contentItem: Label {
                                                    text: parent.text
                                                    color: backgroundColor
                                                    font.pixelSize: fontBase * 0.9
                                                    horizontalAlignment: Text.AlignHCenter
                                                }
                                                
                                                onClicked: editarUsuario(index)
                                            }
                                            
                                            Button {
                                                Layout.preferredWidth: baseUnit * 7
                                                Layout.preferredHeight: baseUnit * 3.5
                                                text: "🗑️"
                                                
                                                background: Rectangle {
                                                    color: dangerColor
                                                    radius: baseUnit * 0.5
                                                }
                                                
                                                contentItem: Label {
                                                    text: parent.text
                                                    color: backgroundColor
                                                    font.pixelSize: fontBase * 0.9
                                                    horizontalAlignment: Text.AlignHCenter
                                                }
                                                
                                                onClicked: {
                                                    var usuario = usuariosFiltradosModel.get(index)
                                                    if (usuarioModel && usuario.id) {
                                                        usuarioModel.eliminarUsuario(usuario.id.toString())
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // ===== ESTADO VACÍO =====
                        ColumnLayout {
                            anchors.centerIn: parent
                            visible: usuariosFiltradosModel.count === 0
                            spacing: marginLarge
                            
                            Label {
                                text: "👤"
                                font.pixelSize: fontBase * 4
                                color: "#E5E7EB"
                                Layout.alignment: Qt.AlignHCenter
                            }
                            
                            Label {
                                text: usuariosOriginales.length === 0 ? "No hay usuarios registrados" : "No hay usuarios que coincidan con los filtros"
                                color: textColor
                                font.bold: true
                                font.pixelSize: fontBase * 1.2
                                Layout.alignment: Qt.AlignHCenter
                            }
                            
                            Label {
                                text: usuariosOriginales.length === 0 ? 
                                      "Haz clic en 'Nuevo Usuario' para crear el primero" :
                                      "Prueba cambiando los filtros o limpiando la búsqueda"
                                color: textSecondaryColor
                                font.pixelSize: fontBase * 0.9
                                Layout.alignment: Qt.AlignHCenter
                                wrapMode: Text.WordWrap
                                horizontalAlignment: Text.AlignHCenter
                                Layout.maximumWidth: baseUnit * 40
                            }
                        }
                    }
                }
            }
        }
    }
    
    // ===== VENTANA MODAL PARA FORMULARIO =====
    Rectangle {
        id: modalOverlay
        anchors.fill: parent
        color: "black"
        opacity: 0.5
        visible: showModal
        z: 999
        
        MouseArea {
            anchors.fill: parent
            onClicked: {
                limpiarFormulario()
                showModal = false
            }
        }
    }
    
    Rectangle {
        id: modalWindow
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.9, baseUnit * 80)
        height: Math.min(parent.height * 0.8, baseUnit * 60)
        color: backgroundColor
        radius: baseUnit * 1.5
        visible: showModal
        z: 1000
        border.color: borderColor
        border.width: 1
        
        // Sombra simple usando Rectangle
        Rectangle {
            anchors.fill: parent
            anchors.margins: -baseUnit * 0.5
            color: "black"
            opacity: 0.1
            radius: parent.radius
            z: -1
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: marginLarge
            spacing: marginMedium
            
            // ===== HEADER DE LA MODAL =====
            RowLayout {
                Layout.fillWidth: true
                spacing: marginMedium
                
                Rectangle {
                    Layout.preferredWidth: baseUnit * 6
                    Layout.preferredHeight: baseUnit * 6
                    color: primaryColor
                    radius: baseUnit * 3
                    
                    Label {
                        anchors.centerIn: parent
                        text: isEditMode ? "✏️" : "➕"
                        color: backgroundColor
                        font.pixelSize: fontBase * 1.5
                    }
                }
                
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: marginSmall * 0.5
                    
                    Label {
                        text: isEditMode ? "Editar Usuario" : "Agregar Nuevo Usuario"
                        color: textColor
                        font.pixelSize: fontBase * 1.4
                        font.bold: true
                        font.family: "Segoe UI"
                    }
                    
                    Label {
                        text: isEditMode ? "Modifica los datos del usuario seleccionado" : "Complete los datos para crear un nuevo usuario"
                        color: textSecondaryColor
                        font.pixelSize: fontBase * 0.9
                        Layout.fillWidth: true
                    }
                }
                
                Button {
                    Layout.preferredWidth: baseUnit * 6
                    Layout.preferredHeight: baseUnit * 6
                    text: "✕"
                    
                    background: Rectangle {
                        color: "transparent"
                        radius: baseUnit * 3
                        border.color: borderColor
                        border.width: 1
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        color: textSecondaryColor
                        font.pixelSize: fontBase * 1.2
                        horizontalAlignment: Text.AlignHCenter
                    }
                    
                    onClicked: {
                        limpiarFormulario()
                        showModal = false
                    }
                }
            }
            
            // ===== LÍNEA SEPARADORA =====
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: borderColor
            }
            
            // ===== CONTENIDO DEL FORMULARIO =====
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                
                GridLayout {
                    width: parent.width
                    columns: width < baseUnit * 60 ? 1 : 2
                    columnSpacing: marginLarge
                    rowSpacing: marginMedium
                    
                    // ===== DATOS PERSONALES =====
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: marginMedium
                        
                        Label {
                            text: "📋 Datos Personales"
                            font.bold: true
                            font.pixelSize: fontBase * 1.1
                            color: textColor
                        }
                        
                        TextField {
                            id: nombreField
                            Layout.fillWidth: true
                            placeholderText: "Nombre"
                            font.pixelSize: fontBase * 0.9
                            
                            background: Rectangle {
                                color: backgroundColor
                                border.color: parent.focus ? primaryColor : borderColor
                                border.width: 2
                                radius: baseUnit * 0.8
                            }
                        }
                        
                        TextField {
                            id: apellidoPaternoField
                            Layout.fillWidth: true
                            placeholderText: "Apellido Paterno"
                            font.pixelSize: fontBase * 0.9
                            
                            background: Rectangle {
                                color: backgroundColor
                                border.color: parent.focus ? primaryColor : borderColor
                                border.width: 2
                                radius: baseUnit * 0.8
                            }
                        }
                        
                        TextField {
                            id: apellidoMaternoField
                            Layout.fillWidth: true
                            placeholderText: "Apellido Materno"
                            font.pixelSize: fontBase * 0.9
                            
                            background: Rectangle {
                                color: backgroundColor
                                border.color: parent.focus ? primaryColor : borderColor
                                border.width: 2
                                radius: baseUnit * 0.8
                            }
                        }
                    }
                    
                    // ===== CREDENCIALES Y ROL =====
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: marginMedium
                        
                        Label {
                            text: "🔐 Credenciales y Rol"
                            font.bold: true
                            font.pixelSize: fontBase * 1.1
                            color: textColor
                        }
                        
                        TextField {
                            id: correoField
                            Layout.fillWidth: true
                            placeholderText: "correo@clinica.com"
                            font.pixelSize: fontBase * 0.9
                            
                            background: Rectangle {
                                color: backgroundColor
                                border.color: parent.focus ? primaryColor : borderColor
                                border.width: 2
                                radius: baseUnit * 0.8
                            }
                        }
                        
                        TextField {
                            id: passwordField
                            Layout.fillWidth: true
                            placeholderText: "Contraseña"
                            echoMode: TextInput.Password
                            visible: !isEditMode
                            font.pixelSize: fontBase * 0.9
                            
                            background: Rectangle {
                                color: backgroundColor
                                border.color: parent.focus ? primaryColor : borderColor
                                border.width: 2
                                radius: baseUnit * 0.8
                            }
                        }
                        
                        TextField {
                            id: confirmPasswordField
                            Layout.fillWidth: true
                            placeholderText: "Confirmar Contraseña"
                            echoMode: TextInput.Password
                            visible: !isEditMode
                            font.pixelSize: fontBase * 0.9
                            
                            background: Rectangle {
                                color: backgroundColor
                                border.color: parent.focus ? primaryColor : borderColor
                                border.width: 2
                                radius: baseUnit * 0.8
                            }
                        }
                        
                        ComboBox {
                            id: rolComboBox
                            Layout.fillWidth: true
                            model: rolesDisponibles.filter(rol => rol !== "Todos los roles")
                            displayText: currentIndex >= 0 ? model[currentIndex] : "Seleccione rol"
                            font.pixelSize: fontBase * 0.9
                            
                            background: Rectangle {
                                color: backgroundColor
                                border.color: borderColor
                                border.width: 2
                                radius: baseUnit * 0.8
                            }
                        }
                        
                        // ===== ESTADO =====
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: marginSmall
                            
                            Label {
                                text: "⚡ Estado del Usuario"
                                font.bold: true
                                font.pixelSize: fontBase * 1.1
                                color: textColor
                            }
                            
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: marginLarge
                                
                                RadioButton {
                                    id: activoRadio
                                    text: "✅ Activo"
                                    checked: true
                                    font.pixelSize: fontBase * 0.9
                                }
                                
                                RadioButton {
                                    id: inactivoRadio
                                    text: "❌ Inactivo"
                                    font.pixelSize: fontBase * 0.9
                                }
                            }
                        }
                    }
                }
            }
            
            // ===== LÍNEA SEPARADORA =====
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: borderColor
            }
            
            // ===== BOTONES DE ACCIÓN =====
            RowLayout {
                Layout.fillWidth: true
                spacing: marginMedium
                
                Item { Layout.fillWidth: true }
                
                Button {
                    text: "Cancelar"
                    Layout.preferredHeight: baseUnit * 6
                    Layout.preferredWidth: baseUnit * 20
                    
                    background: Rectangle {
                        color: "transparent"
                        radius: baseUnit
                        border.color: borderColor
                        border.width: 2
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        color: textColor
                        font.pixelSize: fontBase
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                    
                    onClicked: {
                        limpiarFormulario()
                        showModal = false
                    }
                }
                
                Button {
                    text: isEditMode ? "💾 Actualizar Usuario" : "💾 Guardar Usuario"
                    Layout.preferredHeight: baseUnit * 6
                    Layout.preferredWidth: baseUnit * 25
                    enabled: nombreField.text.length > 0 &&
                            apellidoPaternoField.text.length > 0 &&
                            apellidoMaternoField.text.length > 0 &&
                            correoField.text.length > 0 &&
                            rolComboBox.currentIndex >= 0 &&
                            (isEditMode || (passwordField.text.length > 0 && passwordField.text === confirmPasswordField.text))
                    
                    background: Rectangle {
                        color: parent.enabled ? primaryColor : "#bdc3c7"
                        radius: baseUnit
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        color: backgroundColor
                        font.bold: true
                        font.pixelSize: fontBase
                        horizontalAlignment: Text.AlignHCenter
                    }
                    
                    onClicked: guardar()
                }
            }
        }
    }
    
    // ===== BANNER DE NOTIFICACIONES =====
    Rectangle {
        id: notificationArea
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: marginLarge
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
                color: backgroundColor
                font.pixelSize: fontBase * 1.1
            }
            
            Label {
                id: notificationLabel
                Layout.fillWidth: true
                color: backgroundColor
                font.pixelSize: fontBase * 0.9
                wrapMode: Text.WordWrap
            }
        }
        
        Timer {
            id: notificationTimer
            interval: 3000
            onTriggered: notificationArea.visible = false
        }
    }
    
    // ===== FUNCIONES JAVASCRIPT =====
    
    function cargarDatosOriginales() {
        if (!usuarioModel || !usuarioModel.usuarios) return
        
        console.log("📄 Cargando datos originales de usuarios...")
        
        usuariosOriginales = []
        
        for (var i = 0; i < usuarioModel.usuarios.length; i++) {
            usuariosOriginales.push(usuarioModel.usuarios[i])
        }
        
        console.log("✅ Usuarios originales cargados:", usuariosOriginales.length)
        aplicarFiltros()
    }
    
    function aplicarFiltros() {
        console.log("🔍 Aplicando filtros...")
        
        usuariosFiltradosModel.clear()
        
        var textoBusqueda = campoBusqueda.text.toLowerCase()
        var rolSeleccionado = filtroRol.currentText
        
        for (var i = 0; i < usuariosOriginales.length; i++) {
            var usuario = usuariosOriginales[i]
            var mostrar = true
            
            // Filtro por rol
            if (rolSeleccionado !== "Todos los roles" && mostrar) {
                if (usuario.rol_nombre !== rolSeleccionado) {
                    mostrar = false
                }
            }
            
            // Búsqueda por texto
            if (textoBusqueda.length > 0 && mostrar) {
                var nombreCompleto = (usuario.Nombre + " " + usuario.Apellido_Paterno + " " + usuario.Apellido_Materno).toLowerCase()
                var correo = (usuario.correo || "").toLowerCase()
                
                if (!nombreCompleto.includes(textoBusqueda) && !correo.includes(textoBusqueda)) {
                    mostrar = false
                }
            }
            
            if (mostrar) {
                usuariosFiltradosModel.append(usuario)
            }
        }
        
        console.log("✅ Filtros aplicados. Usuarios mostrados:", usuariosFiltradosModel.count)
    }
    
    function editarUsuario(index) {
        var usuario = usuariosFiltradosModel.get(index)
        isEditMode = true
        editingIndex = index
        editingUser = usuario
        showModal = true
        
        // Cargar datos en el formulario
        nombreField.text = usuario.Nombre || ""
        apellidoPaternoField.text = usuario.Apellido_Paterno || ""
        apellidoMaternoField.text = usuario.Apellido_Materno || ""
        correoField.text = usuario.correo || ""
        
        // Configurar rol
        var rolIndex = rolesDisponibles.indexOf(usuario.rol_nombre)
        if (rolIndex >= 0) {
            rolComboBox.currentIndex = rolIndex
        }
        
        // Configurar estado
        if (usuario.Estado) {
            activoRadio.checked = true
        } else {
            inactivoRadio.checked = true
        }
        
        console.log("Editando usuario:", usuario.Nombre)
    }
    
    function guardar() {
        if (!usuarioModel) return
        
        var estado = activoRadio.checked ? "Activo" : "Inactivo"
        var rolIndex = rolComboBox.currentIndex
        var rolesValidos = rolesDisponibles.filter(rol => rol !== "Todos los roles")
        
        if (isEditMode && editingUser) {
            // Actualizar usuario existente
            usuarioModel.actualizarUsuario(
                editingUser.id.toString(),
                nombreField.text,
                apellidoPaternoField.text,
                apellidoMaternoField.text,
                correoField.text,
                rolIndex + 1,
                estado
            )
        } else {
            // Crear nuevo usuario
            usuarioModel.crearUsuario(
                nombreField.text,
                apellidoPaternoField.text,
                apellidoMaternoField.text,
                correoField.text,
                passwordField.text,
                confirmPasswordField.text,
                rolIndex + 1,
                estado
            )
        }
    }
    
    function limpiarFormulario() {
        nombreField.text = ""
        apellidoPaternoField.text = ""
        apellidoMaternoField.text = ""
        correoField.text = ""
        passwordField.text = ""
        confirmPasswordField.text = ""
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