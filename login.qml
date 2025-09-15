// login.qml - Interfaz de login corregida
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
    
    flags: Qt.Window | Qt.FramelessWindowHint
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
    property string statusMessage: "Sistema listo para autenticar"
    property bool connectionOk: true
    property var currentUser: null
    property bool closeApplicationOnExit: true

    // Conexiones con AuthModel
    Connections {
        target: authModel
        
        function onLoginSuccessful(success, message, userData) {
            isLoading = false
            currentUser = userData
            statusMessage = "Acceso concedido - Iniciando aplicación..."
            successAnimation.start()
        }
        
        function onLoginFailed(message) {
            isLoading = false
            statusMessage = message
            showErrorAnimation()
            passwordField.clear()
            passwordField.forceActiveFocus()
        }
    }

    function showErrorAnimation() {
        errorShake.start()
        errorTimer.start()
    }
    
    function launchMainApp() {
        console.log("🚀 Lanzando aplicación principal...")
        mainWindow.visible = false
    }
    
    function handleWindowClose() {
        if (closeApplicationOnExit) {
            Qt.quit()
        } else {
            mainWindow.hide()
        }
    }

    // Permite mover la ventana sin borde
    MouseArea {
        id: dragArea
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 40
        property point clickPos: Qt.point(0, 0)
        
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
                
                // Botón minimizar
                Rectangle {
                    width: 16
                    height: 16
                    radius: 8
                    color: minimizeMouseArea.containsMouse ? "#FFD700" : "#FFBD44"
                    
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
                        onClicked: mainWindow.showMinimized()
                    }
                }
                
                // Botón cerrar
                Rectangle {
                    width: 16
                    height: 16
                    radius: 8
                    color: closeMouseArea.containsMouse ? "#FF0000" : "#FF605C"
                    
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
                        onClicked: handleWindowClose()
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
                
                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: connectionOk ? "#00d63f" : "#ff3838"
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
                            
                            // Icono alternativo si no encuentra la imagen
                            Text {
                                anchors.centerIn: parent
                                text: "🏥"
                                font.pixelSize: 120
                                color: "white"
                                opacity: 0.6
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
                    
                    // Columna derecha (formulario)
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

                            // Campo de usuario
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
                                            text: "👤"
                                            font.pixelSize: 18
                                            opacity: 0.6
                                        }
                                    }
                                    
                                    TextField {
                                        id: usernameField
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        placeholderText: "Nombre de usuario"
                                        font.pixelSize: 14
                                        selectByMouse: true
                                        background: null
                                        enabled: !isLoading
                                        
                                        Keys.onTabPressed: passwordField.forceActiveFocus()
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
                                        
                                        Keys.onReturnPressed: {
                                            if (!isLoading && loginButton.enabled) {
                                                loginButton.clicked()
                                            }
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
                            
                            // Opciones
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
                                
                                CheckBox {
                                    id: closeAppCheckbox
                                    text: "Cerrar app al salir"
                                    font.pixelSize: 10
                                    checked: closeApplicationOnExit
                                    enabled: !isLoading
                                    onCheckedChanged: closeApplicationOnExit = checked
                                }
                            }

                            // Botón de login personalizado
                            Rectangle {
                                id: loginButton
                                Layout.fillWidth: true
                                Layout.preferredHeight: 50
                                radius: 5
                                enabled: !isLoading && connectionOk && 
                                        usernameField.text.length > 0 && 
                                        passwordField.text.length > 0

                                // Color del botón basado en estado
                                color: {
                                    if (!enabled) return "#cccccc"
                                    if (mouseArea.pressed) return Qt.darker(colorBoton, 1.2)
                                    if (mouseArea.containsMouse) return colorHover
                                    return colorBoton
                                }

                                // Texto del botón
                                Text {
                                    anchors.centerIn: parent
                                    text: isLoading ? "VERIFICANDO..." : "INGRESAR"
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: "white"
                                }

                                // Efecto de mouse
                                MouseArea {
                                    id: mouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: loginButton.enabled
                                    onClicked: {
                                        if (!connectionOk) {
                                            statusMessage = "Error: No hay conexión con la base de datos"
                                            return
                                        }
                                        
                                        isLoading = true
                                        statusMessage = "Verificando credenciales..."
                                        
                                        // Usar AuthModel para login
                                        authModel.login(usernameField.text.trim(), passwordField.text)
                                    }
                                }
                            }
                            
                            // Indicador de carga
                            BusyIndicator {
                                Layout.alignment: Qt.AlignHCenter
                                running: isLoading
                                visible: running
                                Layout.preferredHeight: 32
                                Layout.preferredWidth: 32
                            }
                            
                            // Estado del sistema
                            Text {
                                Layout.fillWidth: true
                                text: statusMessage
                                horizontalAlignment: Text.AlignHCenter
                                color: connectionOk ? colorTexto : "#ff3838"
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                opacity: 0.8
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
        
        onFinished: launchMainApp()
    }
    
    // Animación de entrada
    Component.onCompleted: {
        mainWindow.opacity = 0
        startupAnimation.start()
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
    
    // Manejo de teclas
    Item {
        focus: true
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                handleWindowClose()
                event.accepted = true
            } else if (event.key === Qt.Key_F11) {
                if (mainWindow.visibility === Window.FullScreen) {
                    mainWindow.showNormal()
                } else {
                    mainWindow.showFullScreen()
                }
                event.accepted = true
            }
        }
    }
}