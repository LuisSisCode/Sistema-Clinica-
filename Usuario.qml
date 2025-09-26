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
    readonly property color lineColor: "#D1D5DB"
    readonly property color infoColor: "#17a2b8"
    readonly property color violetColor: "#9b59b6"
    
    property int selectedRowIndex: -1
    
    // Referencia al modelo de usuario
    property var usuarioModel: null
    property var rolesDisponibles: []
    
    // NUEVA PROPIEDAD PARA DATOS ORIGINALES
    property var usuariosOriginales: []
    
    // NUEVO LISTMODEL PARA DATOS FILTRADOS
    ListModel {
        id: usuariosFiltradosModel
    }
    
    // Distribución de columnas responsive (SIN ESTADO Y ACCIONES)
    readonly property real colId: 0.10
    readonly property real colNombre: 0.30
    readonly property real colUsuario: 0.25
    readonly property real colRol: 0.35
    
    // Inicialización cuando el model esté disponible
    Component.onCompleted: {
        console.log("🚀 Usuario.qml iniciándose...")
        
        // Verificar disponibilidad del controlador
        if (typeof appController !== "undefined" && appController.usuario_model_instance) {
            console.log("📦 AppController disponible inmediatamente")
            usuarioModel = appController.usuario_model_instance
            rolesDisponibles = usuarioModel.obtenerRolesDisponibles()
            console.log("👥 Roles disponibles:", rolesDisponibles.length)
            cargarDatosOriginales()
        } else {
            console.log("⏳ Esperando que appController esté disponible...")
            // Timer de seguridad para reintentar la conexión
            timerInicializacion.start()
        }
    }

    // AGREGAR este Timer después de Component.onCompleted
    Timer {
        id: timerInicializacion
        interval: 100
        repeat: true
        triggeredOnStart: false
        running: false
        
        onTriggered: {
            if (typeof appController !== "undefined" && appController.usuario_model_instance) {
                console.log("📦 AppController conectado exitosamente (vía timer)")
                usuarioModel = appController.usuario_model_instance
                rolesDisponibles = usuarioModel.obtenerRolesDisponibles()
                cargarDatosOriginales()
                stop() // Detener el timer
            } else {
                console.log("⏳ Aún esperando appController...")
            }
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
                cargarDatosOriginales()
            }
        }
    }
    
    // Conexiones simplificadas con el modelo de usuario
    Connections {
        target: usuarioModel
        
        function onErrorOccurred(title, message) {
            mostrarNotificacion(title, message, dangerColor)
        }
        
        function onSuccessMessage(message) {
            mostrarNotificacion("Éxito", message, successColor)
        }
    }

    // AGREGAR ESTA CONEXIÓN EN Usuario.qml después de las conexiones existentes
    Connections {
        target: usuarioModel
        
        // Escuchar cuando los datos de usuarios cambian
        function onUsuariosChanged() {
            console.log("📊 Usuarios cambiaron - recargando datos en Usuario.qml")
            cargarDatosOriginales()
        }
        
        // Escuchar mensajes de éxito para recargar datos
        function onSuccessMessage(message) {
            console.log("✅ Mensaje de éxito recibido:", message)
            // Si el mensaje es sobre usuarios, recargar datos
            if (message.toLowerCase().includes("usuario")) {
                cargarDatosOriginales()
            }
        }
        
        // Escuchar cuando se recarga el modelo completo
        function onUsuarioCreado(success, message) {
            if (success) {
                console.log("👤 Usuario creado - recargando lista")
                cargarDatosOriginales()
            }
        }
        
        function onUsuarioActualizado(success, message) {
            if (success) {
                console.log("✏️ Usuario actualizado - recargando lista")
                cargarDatosOriginales()
            }
        }
        
        function onUsuarioEliminado(success, message) {
            if (success) {
                console.log("🗑️ Usuario eliminado - recargando lista")
                cargarDatosOriginales()
            }
        }
    }

    // REEMPLAZAR la función cargarDatosOriginales() en Usuario.qml
    function cargarDatosOriginales() {
        if (!usuarioModel) {
            console.log("⚠️ usuarioModel no está disponible aún")
            return
        }
        
        if (!usuarioModel.usuarios) {
            console.log("⚠️ usuarioModel.usuarios no está disponible")
            return
        }
        
        console.log("📄 Cargando datos originales de usuarios...")
        
        // Limpiar datos anteriores
        usuariosOriginales = []
        
        // Cargar nuevos datos desde el modelo
        for (var i = 0; i < usuarioModel.usuarios.length; i++) {
            usuariosOriginales.push(usuarioModel.usuarios[i])
        }
        // Aplicar filtros para actualizar la vista
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
                
                // ===== HEADER MODERNO ACTUALIZADO =====
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: baseUnit * 8  // Aumentado para hacerlo más grande
                    color: lightGrayColor
                    border.color: borderColor
                    border.width: 1
                    radius: baseUnit
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: baseUnit * 1.5
                        spacing: baseUnit * 1.5
                        
                        // SECCIÓN DEL LOGO Y TÍTULO - MÁS GRANDE
                        RowLayout {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: baseUnit * 1.5
                            
                            // Contenedor del icono con tamaño aumentado
                            Rectangle {
                                Layout.preferredWidth: baseUnit * 6
                                Layout.preferredHeight: baseUnit * 6
                                color: "transparent"
                                
                                Image {
                                    id: usuarioIcon
                                    anchors.centerIn: parent
                                    width: baseUnit * 4.8
                                    height: baseUnit * 4.8
                                    source: "Resources/iconos/usuario.png"
                                    fillMode: Image.PreserveAspectFit
                                    antialiasing: true
                                    
                                    onStatusChanged: {
                                        if (status === Image.Error) {
                                            console.log("Error cargando PNG de usuario:", source)
                                            // Fallback al emoji original
                                            visible = false
                                            usuarioFallbackLabel.visible = true
                                        } else if (status === Image.Ready) {
                                            console.log("PNG de usuario cargado correctamente:", source)
                                        }
                                    }
                                }
                                
                                // Fallback al emoji si no carga la imagen
                                Label {
                                    id: usuarioFallbackLabel
                                    anchors.centerIn: parent
                                    text: "👤"
                                    font.pixelSize: baseUnit * 4
                                    color: primaryColor
                                    visible: false
                                }
                            }
                            
                            // Título - Más grande
                            Label {
                                text: "Listado de Usuarios del Sistema"
                                font.pixelSize: fontBaseSize * 1.4  // Aumentado
                                font.bold: true
                                font.family: "Segoe UI, Arial, sans-serif"
                                color: textColor
                            }
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        // Loading indicator más grande
                        BusyIndicator {
                            Layout.preferredWidth: baseUnit * 3
                            Layout.preferredHeight: baseUnit * 3
                            visible: usuarioModel ? usuarioModel.loading : false
                            running: visible
                        }
                        
                        Button {
                            text: "🔄 Recargar"
                            Layout.preferredHeight: baseUnit * 4
                            Layout.preferredWidth: Math.max(baseUnit * 12, implicitWidth + baseUnit)
                            
                            background: Rectangle {
                                color: parent.pressed ? Qt.darker(infoColor, 1.1) : 
                                    (parent.hovered ? Qt.lighter(infoColor, 1.1) : infoColor)
                                radius: baseUnit * 0.8
                                border.width: 0
                                
                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                            
                            contentItem: Label {
                                text: parent.text
                                color: whiteColor
                                font.bold: true
                                font.pixelSize: fontBaseSize
                                font.family: "Segoe UI, Arial, sans-serif"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: {
                                if (usuarioModel) {
                                    usuarioModel.recargarDatos()
                                }
                            }
                        }
                    }
                }
                
                // ===== FILTROS SIMPLIFICADOS =====
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: width < 1000 ? baseUnit * 12 : baseUnit * 8
                    color: "transparent"
                    z: 10
                    
                    GridLayout {
                        anchors.fill: parent
                        anchors.margins: baseUnit * 3
                        anchors.bottomMargin: baseUnit * 1.5
                        
                        columns: width < 1000 ? 2 : 3
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
               
                // ===== TABLA MODERNA ACTUALIZADA =====
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
                        
                        // HEADER ACTUALIZADO
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
                                
                                // USUARIO COLUMN (ACTUALIZADA)
                                Item {
                                    Layout.preferredWidth: parent.width * colUsuario
                                    Layout.fillHeight: true
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "NOMBRE USUARIO"
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
                                }
                            }
                        }
                        
                        // CONTENIDO DE TABLA CON SCROLL
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            
                            ListView {
                                id: usuariosListView
                                model: usuariosFiltradosModel
                                
                                delegate: Rectangle {
                                    width: ListView.view.width
                                    height: baseUnit * 5
                                    color: {
                                        if (selectedRowIndex === index) return "#F8F9FA"
                                        return index % 2 === 0 ? whiteColor : "#FAFAFA"
                                    }
                                    
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        height: 1
                                        color: borderColor
                                    }
                                    
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
                                        
                                        // USUARIO COLUMN (ACTUALIZADA)
                                        Item {
                                            Layout.preferredWidth: parent.width * colUsuario
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                anchors.rightMargin: baseUnit
                                                text: model.nombre_usuario || ""
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
                                        }
                                    }
                                    
                                    // LÍNEAS VERTICALES (REDUCIDAS A 3)
                                    Repeater {
                                        model: 3 // Solo 3 líneas verticales
                                        Rectangle {
                                            property real xPos: {
                                                var w = parent.width - baseUnit * 3
                                                switch(index) {
                                                    case 0: return baseUnit * 1.5 + w * colId
                                                    case 1: return baseUnit * 1.5 + w * (colId + colNombre)
                                                    case 2: return baseUnit * 1.5 + w * (colId + colNombre + colUsuario)
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
                
                // ESTADO VACÍO PARA TABLA SIN DATOS
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
                            text: "Contacta al administrador para crear usuarios"
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
                
                // MENSAJE DE NO RESULTADOS PARA FILTROS
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

    // FUNCIÓN DE FILTRADO DEL LADO DEL CLIENTE
    function aplicarFiltros() {
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
            
            // Búsqueda por texto en nombre, apellidos o nombre de usuario
            if (textoBusqueda.length > 0 && mostrar) {
                var nombreCompleto = (usuario.Nombre + " " + usuario.Apellido_Paterno + " " + usuario.Apellido_Materno).toLowerCase()
                var nombreUsuario = (usuario.nombre_usuario || "").toLowerCase()
                
                if (!nombreCompleto.includes(textoBusqueda) &&
                    !nombreUsuario.includes(textoBusqueda)) {
                    mostrar = false
                }
            }
            
            if (mostrar) {
                usuariosFiltradosModel.append(usuario)
            }
        }
        
        //console.log("✅ Filtros aplicados. Usuarios mostrados:", usuariosFiltradosModel.count, "de", usuariosOriginales.length)
    }
    
    function mostrarNotificacion(titulo, mensaje, color) {
        notificationArea.color = color
        notificationArea.titleText = titulo
        notificationArea.messageText = mensaje
        notificationArea.visible = true
        notificationTimer.restart()
    }
}