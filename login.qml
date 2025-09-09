// login.qml - Interfaz de login con controles de ventana corregidos
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15

ApplicationWindow {
    id: mainWindow
    visible: true
    width: 800
    height: 500
    title: "Clínica App - Sistema de Acceso"
    
    // SOLUCIÓN: Cambiar las flags para que aparezca en la barra de tareas
    flags: Qt.Window | Qt.FramelessWindowHint
    // Alternativa si quieres que aparezca en la barra de tareas:
    // flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    
    color: "transparent"

    // Propiedades de diseño
    property color colorFondo: "#f8f9fa"
    property color colorTitulo: "#203436"
    property color colorTexto: "#636e72"
    property color colorBordes: "#dfe6e9"
    property color colorBoton: "#e30909"
    property color colorHover: "#74b9ff"
    property color colorSombra: "#80000000"
    property color colorHeaderBar: "#203436"
    
    // Estados de la aplicación
    property bool isLoading: false
    property bool isClosing: false
    property string statusMessage: "Sistema inicializando..."
    property bool connectionOk: false
    property var currentUser: null
    
    // NUEVA PROPIEDAD: Para controlar si debe cerrar toda la app o solo la ventana
    property bool closeApplicationOnExit: false

    // Conexiones con el backend integrado
    Connections {
        target: backend
        
        function onConnectionStatus(connected, message) {
            connectionOk = connected
            statusMessage = message
            console.log("Estado conexión:", connected, message)
        }
        
        function onLoginResult(success, message, userData) {
            isLoading = false
            
            if (success) {
                console.log("✅ Login exitoso:", JSON.stringify(userData))
                currentUser = userData
                statusMessage = "Acceso concedido - Iniciando aplicación..."
                
                // Guardar credenciales si está marcado recordar
                if (rememberPassword.checked) {
                    saveCredentials(usernameField.text, userData.token)
                }
                
                // Mostrar animación de éxito y luego cerrar
                successAnimation.start()
                
            } else {
                console.log("❌ Login fallido:", message)
                statusMessage = message
                showErrorAnimation()
                
                // Limpiar contraseña en caso de error
                passwordField.clear()
                passwordField.focus = true
            }
        }
        
        function onUserAuthenticated(userData) {
            console.log("Usuario autenticado:", JSON.stringify(userData))
            // Aquí puedes añadir lógica adicional después de la autenticación
        }
    }

    // Funciones auxiliares
    function saveCredentials(email, token) {
        // En un entorno real, usar almacenamiento seguro
        console.log("Guardando credenciales para:", email)
    }
    
    function showErrorAnimation() {
        errorShake.start()
        errorTimer.start()
    }
    
    function launchMainApp() {
        console.log("🚀 Lanzando aplicación principal...")
        // NO cerrar la aplicación, solo cerrar la ventana de login
        mainWindow.visible = false
        // Si necesitas crear/mostrar otra ventana aquí sería el lugar
        // mainAppWindow.show()
    }
    
    // NUEVA FUNCIÓN: Para manejar el cierre de la ventana
    function handleWindowClose() {
        if (closeApplicationOnExit) {
            Qt.quit()
        } else {
            mainWindow.hide()
        }
    }
    
    // NUEVA FUNCIÓN: Para restaurar la ventana desde la bandeja del sistema
    function restoreWindow() {
        mainWindow.show()
        mainWindow.raise()
        mainWindow.requestActivate()
    }

    // Permite mover la ventana sin borde
    MouseArea {
        id: dragArea
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 40
        property point clickPos: "0,0"
        
        onPressed: function(mouse) {
            clickPos = Qt.point(mouse.x, mouse.y)
        }
        
        onPositionChanged: function(mouse) {
            if (pressed) {
                var delta = Qt.point(mouse.x - clickPos.x, mouse.y - clickPos.y)
                mainWindow.x += delta.x
                mainWindow.y += delta.y
            }
        }
        
        // MEJORADO: Doble clic para maximizar/restaurar
        onDoubleClicked: {
            if (mainWindow.visibility === Window.Maximized) {
                mainWindow.showNormal()
            } else {
                mainWindow.showMaximized()
            }
        }
    }

    Rectangle {
        id: mainRect
        anchors.fill: parent
        radius: 15
        color: colorFondo
        border.color: "#ffffff"
        border.width: 1
        clip: true
        
        // Animación de error
        NumberAnimation {
            id: errorShake
            target: mainRect
            property: "x"
            from: 0; to: 10; duration: 50
            loops: 6
            easing.type: Easing.InOutQuad
            onFinished: mainRect.x = 0
        }

        // Barra superior con botones de control
        Rectangle {
            id: headerBar
            width: parent.width
            height: 40
            color: colorHeaderBar
            radius: 15
            
            Rectangle {
                width: parent.width
                height: parent.height / 2
                color: colorHeaderBar
                anchors.bottom: parent.bottom
            }
            
            RowLayout {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 10
                spacing: 10
                
                // Botón minimizar CORREGIDO
                Rectangle {
                    width: 16
                    height: 16
                    radius: 8
                    color: minimizeMouseArea.containsMouse ? "#FFD700" : "#FFBD44"
                    
                    // Icono de minimizar
                    Rectangle {
                        width: 8
                        height: 1
                        color: "#000"
                        anchors.centerIn: parent
                        opacity: 0.7
                    }
                    
                    MouseArea {
                        id: minimizeMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        
                        onClicked: {
                            console.log("🔽 Minimizando ventana...")
                            mainWindow.showMinimized()
                        }
                        
                        // Tooltip para ayuda
                        ToolTip.visible: containsMouse
                        ToolTip.text: "Minimizar (F9 para restaurar)"
                        ToolTip.delay: 1000
                    }
                }
                
                // Botón cerrar CORREGIDO
                Rectangle {
                    width: 16
                    height: 16
                    radius: 8
                    color: closeMouseArea.containsMouse ? "#FF0000" : "#FF605C"
                    
                    // Icono X
                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: "#000"
                        font.pixelSize: 10
                        font.bold: true
                        opacity: 0.7
                    }
                    
                    MouseArea {
                        id: closeMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        
                        onClicked: {
                            console.log("❌ Cerrando ventana...")
                            handleWindowClose()
                        }
                        
                        // Tooltip
                        ToolTip.visible: containsMouse
                        ToolTip.text: closeApplicationOnExit ? "Cerrar aplicación" : "Cerrar ventana"
                        ToolTip.delay: 1000
                    }
                }
            }
            
            // Título e indicador de conexión
            RowLayout {
                anchors.left: parent.left
                anchors.leftMargin: 15
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                
                Text {
                    text: "CLÍNICA APP"
                    font.pixelSize: 12
                    font.bold: true
                    color: "white"
                }
                
                // Indicador de conexión
                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: connectionOk ? "#00d63f" : "#ff3838"
                    
                    SequentialAnimation on opacity {
                        running: !connectionOk
                        loops: Animation.Infinite
                        NumberAnimation { from: 1; to: 0.3; duration: 500 }
                        NumberAnimation { from: 0.3; to: 1; duration: 500 }
                    }
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            anchors.topMargin: 50
            spacing: 20

            Rectangle {
                id: contenedor
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "white"
                radius: 15
                border.color: colorBordes
                border.width: 1
                
                Rectangle {
                    z: -1
                    anchors.fill: parent
                    anchors.margins: -3
                    radius: 18
                    color: colorSombra
                    opacity: 0.2
                }

                RowLayout {
                    anchors.fill: parent
                    spacing: 0
                    
                    // Columna izquierda (decorativa)
                    Rectangle {
                        Layout.fillHeight: true
                        Layout.preferredWidth: parent.width * 0.45
                        color: "#203436"
                        radius: 15
                        
                        Rectangle {
                            width: parent.width / 2
                            height: parent.height
                            anchors.right: parent.right
                            color: "#203436"
                        }
                        
                        Rectangle {
                            id: logoContainer
                            anchors.centerIn: parent
                            width: parent.width * 0.8
                            height: width
                            color: "transparent"
                            
                            Image {
                                id: loginImage
                                anchors.fill: parent
                                source: "Image/Image_login/logologinn.png"
                                fillMode: Image.PreserveAspectFit
                                opacity: 0.8
                                visible: status === Image.Ready
                                
                                NumberAnimation on y {
                                    from: -5; to: 5
                                    duration: 3000
                                    loops: Animation.Infinite
                                    easing.type: Easing.InOutQuad
                                    running: loginImage.visible
                                }
                            }
                            
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                visible: loginImage.status !== Image.Ready
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "🏥"
                                    font.pixelSize: 120
                                    color: "white"
                                    opacity: 0.6
                                }
                            }
                        }
                        
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 40
                            text: "BIENVENIDO"
                            font.pixelSize: 24
                            font.bold: true
                            color: "white"
                        }
                        
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 20
                            text: "Sistema de gestión médica"
                            font.pixelSize: 14
                            color: "white"
                            opacity: 0.8
                        }
                    }
                    
                    // Columna derecha (formulario) - MISMO CÓDIGO...
                    Rectangle {
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        color: "transparent"
                        
                        ColumnLayout {
                            anchors.centerIn: parent
                            width: parent.width * 0.8
                            spacing: 8
                            
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Iniciar Sesión"
                                font.pixelSize: 30
                                font.bold: true
                                color: colorTitulo
                            }
                            
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Introduzca sus credenciales"
                                font.pixelSize: 14
                                color: colorTexto
                                opacity: 0.7
                            }
                            
                            Item { Layout.preferredHeight: 20 }

                            // Campo de email
                            Rectangle {
                                Layout.fillWidth: true
                                height: 50
                                radius: 5
                                border.color: usernameField.activeFocus ? colorBoton : colorBordes
                                border.width: 1
                                
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 10
                                    
                                    Rectangle {
                                        Layout.preferredWidth: 24
                                        Layout.preferredHeight: 24
                                        color: "transparent"
                                        
                                        Text {
                                            anchors.centerIn: parent
                                            text: "📧"
                                            font.pixelSize: 18
                                            opacity: 0.6
                                        }
                                    }
                                    
                                    TextField {
                                        id: usernameField
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        placeholderText: "Email del usuario"
                                        font.pixelSize: 14
                                        selectByMouse: true
                                        background: null
                                        enabled: !isLoading
                                        
                                        scale: 1
                                        Behavior on scale { NumberAnimation { duration: 200 } }
                                        onFocusChanged: if (activeFocus) scale = 1.02; else scale = 1
                                    }
                                }
                            }

                            // Campo de contraseña
                            Rectangle {
                                Layout.fillWidth: true
                                height: 50
                                radius: 5
                                border.color: passwordField.activeFocus ? colorBoton : colorBordes
                                border.width: 1
                                
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 10
                                    
                                    Rectangle {
                                        Layout.preferredWidth: 24
                                        Layout.preferredHeight: 24
                                        color: "transparent"
                                        
                                        Text {
                                            anchors.centerIn: parent
                                            text: "🔒"
                                            font.pixelSize: 16
                                            opacity: 0.6
                                        }
                                    }
                                    
                                    TextField {
                                        id: passwordField
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        placeholderText: "Contraseña"
                                        font.pixelSize: 14
                                        echoMode: TextField.Password
                                        selectByMouse: true
                                        background: null
                                        enabled: !isLoading
                                        
                                        scale: 1
                                        Behavior on scale { NumberAnimation { duration: 200 } }
                                        onFocusChanged: if (activeFocus) scale = 1.02; else scale = 1
                                        
                                        Keys.onReturnPressed: {
                                            if (!isLoading) loginButton.clicked()
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: 22
                                        Layout.preferredHeight: 22
                                        color: "transparent"
                                        
                                        Text {
                                            anchors.centerIn: parent
                                            text: passwordField.echoMode === TextField.Password ? "👁️" : "🙈"
                                            font.pixelSize: 16
                                            opacity: 0.6
                                        }
                                        
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                passwordField.echoMode = passwordField.echoMode === TextField.Password 
                                                    ? TextField.Normal : TextField.Password
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // Opción recordar y configuración de cierre
                            RowLayout {
                                Layout.fillWidth: true
                                
                                CheckBox {
                                    id: rememberPassword
                                    text: "Recordar credenciales"
                                    font.pixelSize: 12
                                    checked: false
                                    enabled: !isLoading
                                }
                                
                                Item { Layout.fillWidth: true }
                                
                                // NUEVA OPCIÓN: Checkbox para controlar comportamiento de cierre
                                CheckBox {
                                    id: closeAppCheckbox
                                    text: "Cerrar app al salir"
                                    font.pixelSize: 10
                                    checked: closeApplicationOnExit
                                    enabled: !isLoading
                                    
                                    onCheckedChanged: {
                                        closeApplicationOnExit = checked
                                    }
                                    
                                    ToolTip.visible: hovered
                                    ToolTip.text: "Si está marcado, cerrar la ventana terminará toda la aplicación"
                                }
                            }
                            
                            // Link de problemas de acceso
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "¿Problemas de acceso?"
                                font.pixelSize: 12
                                color: colorBoton
                                
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: !isLoading
                                    onClicked: {
                                        console.log("Recuperar contraseña")
                                    }
                                }
                            }

                            // Botón de login (mismo código anterior)
                            Button {
                                id: loginButton
                                Layout.fillWidth: true
                                Layout.preferredHeight: 50
                                text: isLoading ? "VERIFICANDO..." : "INGRESAR"
                                font.pixelSize: 16
                                font.bold: true
                                enabled: !isLoading && connectionOk && 
                                        usernameField.text.length > 0 && 
                                        passwordField.text.length > 0

                                contentItem: Text {
                                    text: parent.text
                                    font: parent.font
                                    color: "white"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                background: Rectangle {
                                    radius: 5
                                    color: {
                                        if (!parent.enabled) return "#cccccc"
                                        if (parent.down) return Qt.darker(colorBoton, 1.2)
                                        if (parent.hovered) return colorHover
                                        return colorBoton
                                    }
                                    
                                    gradient: Gradient {
                                        GradientStop { 
                                            position: 0.0
                                            color: parent.enabled ? Qt.lighter(parent.color, 1.1) : "#cccccc"
                                        }
                                        GradientStop { 
                                            position: 1.0
                                            color: parent.color
                                        }
                                    }
                                    
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }

                                scale: loginButton.down ? 0.98 : 1.0
                                Behavior on scale { NumberAnimation { duration: 100 } }
                                
                                onClicked: {
                                    if (!connectionOk) {
                                        statusMessage = "Error: No hay conexión con la base de datos"
                                        return
                                    }
                                    
                                    isLoading = true
                                    statusMessage = "Verificando credenciales..."
                                    
                                    // Llamar al backend para autenticar
                                    backend.authenticateUser(usernameField.text.trim(), passwordField.text)
                                }
                            }
                            
                            // Indicador de carga
                            BusyIndicator {
                                id: loadingIndicator
                                Layout.alignment: Qt.AlignHCenter
                                running: isLoading
                                visible: running
                                Layout.preferredHeight: 32
                                Layout.preferredWidth: 32
                            }
                            
                            // Estado del sistema
                            Text {
                                id: statusText
                                Layout.fillWidth: true
                                text: statusMessage
                                horizontalAlignment: Text.AlignHCenter
                                color: connectionOk ? colorTexto : "#ff3838"
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap

                                opacity: 0
                                Behavior on opacity { NumberAnimation { duration: 300 } }
                                
                                Component.onCompleted: {
                                    opacity = 0.8
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Timer para limpiar mensajes de error
    Timer {
        id: errorTimer
        interval: 5000
        onTriggered: {
            if (!isLoading) {
                statusMessage = connectionOk ? "Sistema listo para autenticar" : "Error de conexión"
            }
        }
    }
    
    // Animación de éxito
    SequentialAnimation {
        id: successAnimation
        
        NumberAnimation {
            target: contenedor
            property: "scale"
            from: 1; to: 1.05
            duration: 200
            easing.type: Easing.OutQuad
        }
        
        PauseAnimation { duration: 300 }
        
        ParallelAnimation {
            NumberAnimation {
                target: mainWindow
                property: "opacity"
                from: 1; to: 0
                duration: 500
                easing.type: Easing.InQuad
            }
            
            NumberAnimation {
                target: contenedor
                property: "scale"
                from: 1.05; to: 0.95
                duration: 500
                easing.type: Easing.InQuad
            }
        }
        
        onFinished: {
            console.log("🚀 Cerrando login y abriendo aplicación principal")
            launchMainApp()
        }
    }
    
    // Animación de entrada
    Component.onCompleted: {
        mainWindow.opacity = 0
        startupAnimation.start()
        
        // Enfocar campo de usuario al iniciar
        usernameField.forceActiveFocus()
    }
    
    PropertyAnimation {
        id: startupAnimation
        target: mainWindow
        property: "opacity"
        from: 0; to: 1
        duration: 800
        easing.type: Easing.OutQuad
    }
    
    // MEJORADO: Manejo de teclas globales con más opciones
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_F12) {
            // Toggle panel de debug (si lo tienes)
            event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
            handleWindowClose()
            event.accepted = true
        } else if (event.key === Qt.Key_F9) {
            // Restaurar ventana si está minimizada
            restoreWindow()
            event.accepted = true
        } else if (event.key === Qt.Key_F11) {
            // Toggle pantalla completa
            if (mainWindow.visibility === Window.FullScreen) {
                mainWindow.showNormal()
            } else {
                mainWindow.showFullScreen()
            }
            event.accepted = true
        }
    }
    
    // NUEVO: Manejo de eventos de la ventana
    onVisibilityChanged: {
        if (visibility === Window.Minimized) {
            console.log("🔽 Ventana minimizada")
        } else if (visibility === Window.Windowed || visibility === Window.Maximized) {
            console.log("🔼 Ventana restaurada")
        }
    }
}