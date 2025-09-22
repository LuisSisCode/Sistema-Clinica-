// login.qml - Interfaz de login mejorada con credenciales persistentes
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15
import QtCore  // ✅ CAMBIADO: Era Qt.labs.settings 1.1

ApplicationWindow {
    id: mainWindow
    visible: true
    width: 800
    height: 500
    title: "Clínica App - Sistema de Acceso"
    
    flags: Qt.Window | Qt.FramelessWindowHint
    color: "transparent"

    // ===== CONFIGURACIÓN PERSISTENTE ===== 
    // ✅ CORREGIDO: Agregando category para mejor organización
    Settings {
        id: loginSettings
        category: "LoginCredentials"  // ✅ NUEVO: Recomendado para QtCore
        
        property string savedUsername: ""
        property string savedPassword: ""
        property bool rememberCredentials: false
        property bool autoLogin: false
        property bool closeAppOnExit: true
        property int loginAttempts: 0
        property string lastLoginDate: ""
    }

    // Propiedades de diseño
    property color colorFondo: "#f8f9fa"
    property color colorTitulo: "#203436"
    property color colorTexto: "#636e72"
    property color colorBordes: "#dfe6e9"
    property color colorBoton: "#e30909"
    property color colorHover: "#74b9ff"
    property color colorSombra: "#80000000"
    property color colorHeaderBar: "#203436"
    property color colorSuccess: "#00b894"
    property color colorError: "#e17055"
    property color colorWarning: "#fdcb6e"
    
    // Estados de la aplicación mejorados
    property bool isLoading: false
    property bool isClosing: false
    property bool isAutoLogin: false
    property string statusMessage: "Sistema listo para autenticar"
    property bool connectionOk: true
    property var currentUser: null
    property bool closeApplicationOnExit: loginSettings.closeAppOnExit
    property int maxLoginAttempts: 5
    property bool isBlocked: loginSettings.loginAttempts >= maxLoginAttempts
    property bool showPassword: false

    // ===== FUNCIONES DE CREDENCIALES =====
    function encodeCredentials(text) {
        // Codificación básica (NO es segura para producción)
        return Qt.btoa(text)
    }
    
    function decodeCredentials(encoded) {
        try {
            return Qt.atob(encoded)
        } catch (e) {
            return ""
        }
    }
    
    function saveCredentials() {
        if (rememberPassword.checked && usernameField.text && passwordField.text) {
            loginSettings.savedUsername = usernameField.text
            loginSettings.savedPassword = encodeCredentials(passwordField.text)
            loginSettings.rememberCredentials = true
            console.log("✅ Credenciales guardadas")
        }
    }
    
    function loadCredentials() {
        if (loginSettings.rememberCredentials && loginSettings.savedUsername) {
            usernameField.text = loginSettings.savedUsername
            passwordField.text = decodeCredentials(loginSettings.savedPassword)
            rememberPassword.checked = true
            
            // Auto-login si está habilitado
            if (autoLoginCheckbox.checked && !isBlocked) {
                statusMessage = "Ingreso automático..."
                autoLoginTimer.start()
            }
        }
    }
    
    function clearCredentials() {
        loginSettings.savedUsername = ""
        loginSettings.savedPassword = ""
        loginSettings.rememberCredentials = false
        usernameField.text = ""
        passwordField.text = ""
        rememberPassword.checked = false
    }
    
    function performLogin() {
        if (!connectionOk) {
            statusMessage = "Error: No hay conexión con la base de datos"
            showError()
            return
        }
        
        if (isBlocked) {
            statusMessage = `Demasiados intentos fallidos. Intente más tarde.`
            showError()
            return
        }
        
        if (!usernameField.text.trim() || !passwordField.text) {
            statusMessage = "Complete todos los campos"
            showWarning()
            return
        }
        
        isLoading = true
        statusMessage = "Verificando credenciales..."
        
        // Guardar credenciales si está marcado
        if (rememberPassword.checked) {
            saveCredentials()
        }
        
        // Usar AuthModel para login
        authModel.login(usernameField.text.trim(), passwordField.text)
    }
    
    function showError() {
        errorShake.start()
        statusColor.color = colorError
        errorTimer.start()
    }
    
    function showWarning() {
        statusColor.color = colorWarning
        errorTimer.start()
    }
    
    function showSuccess() {
        statusColor.color = colorSuccess
    }

    // ===== CONEXIONES CON AUTHMODEL =====
    Connections {
        target: authModel
        
        function onLoginSuccessful(success, message, userData) {
            isLoading = false
            currentUser = userData
            statusMessage = "Acceso concedido - Iniciando aplicación..."
            showSuccess()
            
            // Resetear intentos
            loginSettings.loginAttempts = 0
            loginSettings.lastLoginDate = new Date().toISOString()
            
            successAnimation.start()
        }
        
        function onLoginFailed(message) {
            isLoading = false
            statusMessage = message
            
            // Incrementar intentos fallidos
            loginSettings.loginAttempts += 1
            
            if (loginSettings.loginAttempts >= maxLoginAttempts) {
                statusMessage = `Cuenta bloqueada por ${maxLoginAttempts} intentos fallidos`
                isBlocked = true
                blockTimer.start()
            }
            
            showError()
            passwordField.clear()
            passwordField.forceActiveFocus()
        }
    }

    // ===== TIMERS =====
    Timer {
        id: autoLoginTimer
        interval: 1500
        onTriggered: {
            isAutoLogin = true
            performLogin()
        }
    }
    
    Timer {
        id: errorTimer
        interval: 5000
        onTriggered: {
            if (!isLoading) {
                statusMessage = connectionOk ? "Sistema listo para autenticar" : "Error de conexión"
                statusColor.color = connectionOk ? colorTexto : colorError
            }
        }
    }
    
    Timer {
        id: blockTimer
        interval: 300000 // 5 minutos
        onTriggered: {
            loginSettings.loginAttempts = 0
            isBlocked = false
            statusMessage = "Puede intentar nuevamente"
            statusColor.color = colorTexto
        }
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
        
        // Animación de error mejorada
        SequentialAnimation {
            id: errorShake
            NumberAnimation {
                target: mainRect
                property: "x"
                from: 0; to: -8; duration: 50
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: mainRect
                property: "x"
                from: -8; to: 8; duration: 100
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: mainRect
                property: "x"
                from: 8; to: -4; duration: 80
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: mainRect
                property: "x"
                from: -4; to: 4; duration: 60
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: mainRect
                property: "x"
                from: 4; to: 0; duration: 40
                easing.type: Easing.InOutQuad
            }
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
                        text: "×"
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
            
            // Título e indicador de conexión mejorado
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
                    
                    // Animación de pulso para conexión
                    SequentialAnimation on opacity {
                        running: true
                        loops: Animation.Infinite
                        NumberAnimation { from: 1; to: 0.3; duration: 1000 }
                        NumberAnimation { from: 0.3; to: 1; duration: 1000 }
                    }
                }
                
                // Contador de intentos
                Text {
                    text: isBlocked ? "BLOQUEADO" : `${loginSettings.loginAttempts}/${maxLoginAttempts}`
                    font.pixelSize: 10
                    color: isBlocked ? "#ff3838" : "white"
                    opacity: 0.8
                    visible: loginSettings.loginAttempts > 0
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
                            
                            // Icono alternativo animado
                            Text {
                                anchors.centerIn: parent
                                text: "🏥"
                                font.pixelSize: 120
                                color: "white"
                                opacity: 0.6
                                
                                SequentialAnimation on scale {
                                    running: isLoading
                                    loops: Animation.Infinite
                                    NumberAnimation { from: 1; to: 1.1; duration: 800 }
                                    NumberAnimation { from: 1.1; to: 1; duration: 800 }
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
                    
                    // Columna derecha (formulario mejorado)
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
                                text: isAutoLogin ? "Ingreso automático..." : "Introduzca sus credenciales"
                                font.pixelSize: 14
                                color: colorTexto
                                opacity: 0.7
                            }
                            
                            Item { Layout.preferredHeight: 20 }

                            // Campo de usuario mejorado
                            Rectangle {
                                Layout.fillWidth: true
                                height: 50
                                radius: 5
                                border.color: {
                                    if (usernameField.activeFocus) return colorBoton
                                    if (usernameField.text.length > 0) return colorSuccess
                                    return colorBordes
                                }
                                border.width: usernameField.activeFocus ? 2 : 1
                                
                                Behavior on border.color { ColorAnimation { duration: 200 } }
                                
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
                                            opacity: usernameField.text.length > 0 ? 1.0 : 0.6
                                            
                                            Behavior on opacity { NumberAnimation { duration: 200 } }
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
                                        enabled: !isLoading && !isBlocked
                                        
                                        Keys.onReturnPressed: {
                                            if (text.length > 0) {
                                                passwordField.forceActiveFocus()
                                            }
                                        }
                                        
                                        Keys.onTabPressed: passwordField.forceActiveFocus()
                                        
                                        onTextChanged: {
                                            // Validación en tiempo real
                                            if (text.length > 0 && passwordField.text.length > 0) {
                                                loginButton.highlighted = true
                                            }
                                        }
                                    }
                                    
                                    // Indicador de validación
                                    Text {
                                        text: usernameField.text.length > 2 ? "✓" : ""
                                        color: colorSuccess
                                        font.pixelSize: 16
                                        opacity: usernameField.text.length > 2 ? 1 : 0
                                        Behavior on opacity { NumberAnimation { duration: 200 } }
                                    }
                                }
                            }

                            // Campo de contraseña mejorado
                            Rectangle {
                                Layout.fillWidth: true
                                height: 50
                                radius: 5
                                border.color: {
                                    if (passwordField.activeFocus) return colorBoton
                                    if (passwordField.text.length > 0) return colorSuccess
                                    return colorBordes
                                }
                                border.width: passwordField.activeFocus ? 2 : 1
                                
                                Behavior on border.color { ColorAnimation { duration: 200 } }
                                
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
                                            opacity: passwordField.text.length > 0 ? 1.0 : 0.6
                                            
                                            Behavior on opacity { NumberAnimation { duration: 200 } }
                                        }
                                    }
                                    
                                    TextField {
                                        id: passwordField
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        placeholderText: "Contraseña"
                                        font.pixelSize: 14
                                        echoMode: showPassword ? TextField.Normal : TextField.Password
                                        selectByMouse: true
                                        background: null
                                        enabled: !isLoading && !isBlocked
                                        
                                        Keys.onReturnPressed: {
                                            if (!isLoading && loginButton.enabled) {
                                                performLogin()
                                            }
                                        }
                                        
                                        onTextChanged: {
                                            // Validación en tiempo real
                                            if (text.length > 0 && usernameField.text.length > 0) {
                                                loginButton.highlighted = true
                                            }
                                        }
                                    }
                                    
                                    // Botón mostrar/ocultar contraseña
                                    Rectangle {
                                        Layout.preferredWidth: 22
                                        Layout.preferredHeight: 22
                                        color: showPasswordMouseArea.containsMouse ? "#f0f0f0" : "transparent"
                                        radius: 11
                                        
                                        Text {
                                            anchors.centerIn: parent
                                            text: showPassword ? "🙈" : "👁️"
                                            font.pixelSize: 16
                                            opacity: 0.6
                                        }
                                        
                                        MouseArea {
                                            id: showPasswordMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: showPassword = !showPassword
                                        }
                                    }
                                    
                                    // Indicador de fortaleza
                                    Text {
                                        text: passwordField.text.length >= 6 ? "✓" : ""
                                        color: colorSuccess
                                        font.pixelSize: 16
                                        opacity: passwordField.text.length >= 6 ? 1 : 0
                                        Behavior on opacity { NumberAnimation { duration: 200 } }
                                    }
                                }
                            }
                            
                            // Opciones mejoradas
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                
                                CheckBox {
                                    id: rememberPassword
                                    text: "Recordar credenciales"
                                    font.pixelSize: 11
                                    checked: loginSettings.rememberCredentials
                                    enabled: !isLoading && !isBlocked
                                    
                                    onCheckedChanged: {
                                        if (!checked) {
                                            clearCredentials()
                                        }
                                    }
                                }
                                
                                Item { Layout.fillWidth: true }
                                
                                CheckBox {
                                    id: autoLoginCheckbox
                                    text: "Auto login"
                                    font.pixelSize: 11
                                    checked: loginSettings.autoLogin
                                    enabled: !isLoading && !isBlocked && rememberPassword.checked
                                    
                                    onCheckedChanged: loginSettings.autoLogin = checked
                                }
                            }
                            
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                
                                CheckBox {
                                    id: closeAppCheckbox
                                    text: "Cerrar app al salir"
                                    font.pixelSize: 10
                                    checked: closeApplicationOnExit
                                    enabled: !isLoading
                                    onCheckedChanged: {
                                        closeApplicationOnExit = checked
                                        loginSettings.closeAppOnExit = checked
                                    }
                                }
                                
                                Item { Layout.fillWidth: true }
                                
                                // Botón limpiar credenciales
                                Button {
                                    text: "Limpiar"
                                    font.pixelSize: 10
                                    enabled: !isLoading && loginSettings.rememberCredentials
                                    flat: true
                                    
                                    onClicked: {
                                        clearCredentials()
                                        autoLoginCheckbox.checked = false
                                        statusMessage = "Credenciales eliminadas"
                                        showSuccess()
                                    }
                                }
                            }

                            // Botón de login mejorado
                            Rectangle {
                                id: loginButton
                                Layout.fillWidth: true
                                Layout.preferredHeight: 50
                                radius: 5
                                
                                property bool highlighted: false
                                
                                enabled: !isLoading && connectionOk && !isBlocked &&
                                        usernameField.text.length > 0 && 
                                        passwordField.text.length > 0

                                // Color del botón basado en estado
                                color: {
                                    if (!enabled) return "#cccccc"
                                    if (isBlocked) return colorError
                                    if (mouseArea.pressed) return Qt.darker(colorBoton, 1.2)
                                    if (mouseArea.containsMouse || highlighted) return colorHover
                                    return colorBoton
                                }
                                
                                Behavior on color { ColorAnimation { duration: 200 } }

                                // Texto del botón
                                Text {
                                    anchors.centerIn: parent
                                    text: {
                                        if (isBlocked) return "BLOQUEADO"
                                        if (isLoading) return "VERIFICANDO..."
                                        if (isAutoLogin) return "INGRESO AUTOMÁTICO..."
                                        return "INGRESAR"
                                    }
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
                                    onClicked: performLogin()
                                }
                                
                                // Animación de carga en el botón
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: isLoading ? parent.width : 0
                                    height: parent.height
                                    color: Qt.lighter(colorBoton, 1.2)
                                    radius: parent.radius
                                    opacity: 0.3
                                    visible: isLoading
                                    
                                    Behavior on width { NumberAnimation { duration: 2000 } }
                                }
                            }
                            
                            // Indicador de carga mejorado
                            BusyIndicator {
                                Layout.alignment: Qt.AlignHCenter
                                running: isLoading
                                visible: running
                                Layout.preferredHeight: 32
                                Layout.preferredWidth: 32
                            }
                            
                            // Estado del sistema con color dinámico
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: statusText.contentHeight + 8
                                color: "transparent"
                                border.color: statusColor.color
                                border.width: statusMessage !== "Sistema listo para autenticar" ? 1 : 0
                                radius: 5
                                opacity: statusMessage !== "Sistema listo para autenticar" ? 0.1 : 0
                                
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                                
                                Rectangle {
                                    id: statusColor
                                    anchors.fill: parent
                                    color: connectionOk ? colorTexto : colorError
                                    radius: parent.radius
                                    opacity: 0.1
                                    
                                    Behavior on color { ColorAnimation { duration: 300 } }
                                }
                                
                                Text {
                                    id: statusText
                                    anchors.centerIn: parent
                                    text: statusMessage
                                    horizontalAlignment: Text.AlignHCenter
                                    color: statusColor.color
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                    font.bold: statusMessage.includes("Error") || isBlocked
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Animación de éxito mejorada
    SequentialAnimation {
        id: successAnimation
        
        ParallelAnimation {
            NumberAnimation {
                target: contenedor
                property: "scale"
                from: 1; to: 1.05
                duration: 200
                easing.type: Easing.OutQuad
            }
            
            ColorAnimation {
                target: contenedor
                property: "border.color"
                from: colorBordes; to: colorSuccess
                duration: 200
            }
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
    
    // Animación de entrada mejorada
    Component.onCompleted: {
        mainWindow.opacity = 0
        startupAnimation.start()
        
        // Cargar credenciales guardadas
        loadCredentials()
        
        // Focus inicial inteligente
        if (usernameField.text.length > 0) {
            passwordField.forceActiveFocus()
        } else {
            usernameField.forceActiveFocus()
        }
        
        // Verificar si está bloqueado
        if (isBlocked) {
            statusMessage = "Cuenta bloqueada por múltiples intentos fallidos"
            showError()
            blockTimer.start()
        }
    }
    
    PropertyAnimation {
        id: startupAnimation
        target: mainWindow
        property: "opacity"
        from: 0; to: 1
        duration: 800
        easing.type: Easing.OutQuad
    }
    
    // Manejo de teclas mejorado
    Item {
        focus: true
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                if (isLoading) {
                    // Cancelar operación si es posible
                    event.accepted = true
                } else {
                    handleWindowClose()
                    event.accepted = true
                }
            } else if (event.key === Qt.Key_F11) {
                if (mainWindow.visibility === Window.FullScreen) {
                    mainWindow.showNormal()
                } else {
                    mainWindow.showFullScreen()
                }
                event.accepted = true
            } else if (event.key === Qt.Key_F1) {
                statusMessage = "F11: Pantalla completa | ESC: Salir | Enter: Login"
                showSuccess()
                event.accepted = true
            } else if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_L) {
                clearCredentials()
                event.accepted = true
            }
        }
    }
}