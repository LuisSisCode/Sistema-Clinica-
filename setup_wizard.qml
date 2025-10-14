// setup_wizard.qml
// Wizard de Configuración Inicial - Primera Ejecución
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15

ApplicationWindow {
    id: wizardWindow
    visible: true
    width: 1000
    height: 700
    title: "Configuración Inicial - Clínica María Inmaculada"
    
    flags: Qt.Window | Qt.FramelessWindowHint
    color: "#e8eaf6"
    
    // Colores del tema
    readonly property color primaryColor: "#1a237e"
    readonly property color accentColor: "#d32f2f"
    readonly property color successColor: "#2e7d32"
    readonly property color warningColor: "#ef6c00"
    readonly property color lightGray: "#f5f5f5"
    readonly property color darkGray: "#424242"
    readonly property color whiteColor: "#ffffff"
    
    // Estados del wizard
    property int currentStep: 0  // 0: Bienvenida, 1: Selección, 2: Progreso, 3: Completado
    property bool setupInProgress: false
    property var credenciales: ({})
    
    // Permite mover la ventana
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
                wizardWindow.x += delta.x
                wizardWindow.y += delta.y
            }
        }
    }
    
    Rectangle {
        id: mainContainer
        anchors.fill: parent
        radius: 15
        color: "#ffffff"
        border.color: primaryColor  // ✅ Azul oscuro visible
        border.width: 2
        
        
        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            
            // ===== BARRA SUPERIOR =====
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                color: primaryColor
                radius: 15
                
                Rectangle {
                    width: parent.width
                    height: parent.height / 2
                    anchors.bottom: parent.bottom
                    color: primaryColor
                }
                
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 10
                    
                    Image {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        source: "Resources/iconos/logo_CMI.svg"
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }
                    
                    Text {
                        text: "CONFIGURACIÓN INICIAL"
                        color: whiteColor
                        font.pixelSize: 18
                        font.bold: true
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    // Botón cerrar (solo si no está en progreso)
                    Rectangle {
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        radius: 10
                        color: closeMouseArea.containsMouse ? "#ff0000" : "#ff605c"
                        visible: !setupInProgress
                        
                        Text {
                            anchors.centerIn: parent
                            text: "×"
                            color: "#000"
                            font.pixelSize: 14
                            font.bold: true
                        }
                        
                        MouseArea {
                            id: closeMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: Qt.quit()
                        }
                    }
                }
            }
            
            // ===== CONTENIDO PRINCIPAL =====
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                
                StackLayout {
                    id: stackLayout
                    anchors.fill: parent
                    currentIndex: currentStep
                    
                    // ==================== PASO 0: BIENVENIDA ====================
                    Item {
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 30
                            width: parent.width * 0.7
                            
                            Image {
                                Layout.alignment: Qt.AlignHCenter
                                source: "Resources/iconos/logo_CMI.svg"
                                Layout.preferredWidth: 200
                                Layout.preferredHeight: 200
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }
                            
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "¡Bienvenido al Sistema!"
                                font.pixelSize: 32
                                font.bold: true
                                color: primaryColor
                            }
                            
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: parent.width
                                text: "Clínica María Inmaculada"
                                font.pixelSize: 20
                                color: darkGray
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                            }
                            
                            Rectangle {
                                Layout.preferredWidth: parent.width
                                Layout.preferredHeight: 2
                                color: lightGray
                            }
                            
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: parent.width
                                text: "Esta es la primera vez que ejecutas el sistema.\n\n" +
                                      "Te guiaremos para configurar la base de datos y crear\n" +
                                      "tu usuario administrador en unos simples pasos."
                                font.pixelSize: 16
                                color: darkGray
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                lineHeight: 1.5
                            }
                            
                            Rectangle {
                                width: 250
                                height: 60
                                radius: 30
                                color: mouseArea.pressed ? Qt.darker(accentColor, 1.2) : 
                                    mouseArea.containsMouse ? Qt.lighter(accentColor, 1.1) : accentColor
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "COMENZAR"
                                    font.pixelSize: 18
                                    font.bold: true
                                    color: whiteColor
                                }
                                
                                MouseArea {
                                    id: mouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: currentStep = 1
                                }
                            }
                        }
                    }
                    
                    // ==================== PASO 1: SELECCIÓN DE MODO ====================
                    Item {
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 20
                            width: parent.width * 0.8
                            
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Selecciona el Modo de Configuración"
                                font.pixelSize: 28
                                font.bold: true
                                color: primaryColor
                            }
                            
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Elige cómo deseas configurar el sistema"
                                font.pixelSize: 16
                                color: darkGray
                            }
                            
                            Item { Layout.preferredHeight: 20 }
                            
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 30
                                
                                // ===== OPCIÓN 1: SETUP AUTOMÁTICO =====
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 350
                                    radius: 15
                                    color: whiteColor
                                    border.color: autoMouseArea.containsMouse ? accentColor : lightGray
                                    border.width: 3
                                    
                                    Behavior on border.color { ColorAnimation { duration: 200 } }
                                    
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 30
                                        spacing: 20
                                        
                                        Rectangle {
                                            Layout.alignment: Qt.AlignHCenter
                                            Layout.preferredWidth: 80
                                            Layout.preferredHeight: 80
                                            radius: 40
                                            color: "#e8f5e9"
                                            
                                            Text {
                                                anchors.centerIn: parent
                                                text: "🚀"
                                                font.pixelSize: 40
                                            }
                                        }
                                        
                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: "Setup Automático"
                                            font.pixelSize: 22
                                            font.bold: true
                                            color: primaryColor
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: parent.width
                                            Layout.preferredHeight: 1
                                            color: lightGray
                                        }
                                        
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 10
                                            
                                            Text {
                                                text: "✅ Configuración en 1 click"
                                                font.pixelSize: 14
                                                color: darkGray
                                            }
                                            Text {
                                                text: "✅ Base de datos automática"
                                                font.pixelSize: 14
                                                color: darkGray
                                            }
                                            Text {
                                                text: "✅ Usuario admin creado"
                                                font.pixelSize: 14
                                                color: darkGray
                                            }
                                            Text {
                                                text: "✅ Listo en 30 segundos"
                                                font.pixelSize: 14
                                                color: darkGray
                                            }
                                        }
                                        
                                        Item { Layout.fillHeight: true }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: parent.width * 0.8
                                            Layout.preferredHeight: 30
                                            Layout.alignment: Qt.AlignHCenter
                                            radius: 15
                                            color: successColor
                                            
                                            Text {
                                                anchors.centerIn: parent
                                                text: "RECOMENDADO"
                                                font.pixelSize: 12
                                                font.bold: true
                                                color: whiteColor
                                            }
                                        }
                                    }
                                    
                                    MouseArea {
                                        id: autoMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        
                                        onClicked: {
                                            console.log("🚀 Setup Automático seleccionado")
                                            currentStep = 2
                                            iniciarSetupAutomatico()
                                        }
                                    }
                                }
                                
                                // ===== OPCIÓN 2: CONFIGURACIÓN MANUAL =====
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 350
                                    radius: 15
                                    color: whiteColor
                                    border.color: manualMouseArea.containsMouse ? accentColor : lightGray
                                    border.width: 3
                                    
                                    Behavior on border.color { ColorAnimation { duration: 200 } }
                                    
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 30
                                        spacing: 20
                                        
                                        Rectangle {
                                            Layout.alignment: Qt.AlignHCenter
                                            Layout.preferredWidth: 80
                                            Layout.preferredHeight: 80
                                            radius: 40
                                            color: "#fff3e0"
                                            
                                            Text {
                                                anchors.centerIn: parent
                                                text: "⚙️"
                                                font.pixelSize: 40
                                            }
                                        }
                                        
                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: "Configuración Avanzada"
                                            font.pixelSize: 22
                                            font.bold: true
                                            color: primaryColor
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: parent.width
                                            Layout.preferredHeight: 1
                                            color: lightGray
                                        }
                                        
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 10
                                            
                                            Text {
                                                text: "🔧 Configuración personalizada"
                                                font.pixelSize: 14
                                                color: darkGray
                                            }
                                            Text {
                                                text: "🔧 Elegir servidor SQL"
                                                font.pixelSize: 14
                                                color: darkGray
                                            }
                                            Text {
                                                text: "🔧 Nombre de base de datos"
                                                font.pixelSize: 14
                                                color: darkGray
                                            }
                                            Text {
                                                text: "🔧 Para usuarios avanzados"
                                                font.pixelSize: 14
                                                color: darkGray
                                            }
                                        }
                                        
                                        Item { Layout.fillHeight: true }
                                    }
                                    
                                    MouseArea {
                                        id: manualMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        enabled: false  // Deshabilitar por ahora
                                        
                                        onClicked: {
                                            console.log("⚙️ Setup Manual seleccionado")
                                            // TODO: Implementar setup manual
                                        }
                                    }
                                    
                                    // Overlay de "Próximamente"
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 15
                                        color: "#80000000"
                                        
                                        Text {
                                            anchors.centerIn: parent
                                            text: "Próximamente"
                                            font.pixelSize: 18
                                            font.bold: true
                                            color: whiteColor
                                        }
                                    }
                                }
                            }
                            
                            Item { Layout.preferredHeight: 20 }
                            
                            Button {
                                Layout.alignment: Qt.AlignHCenter
                                text: "← VOLVER"
                                flat: true
                                
                                contentItem: Text {
                                    text: parent.text
                                    font.pixelSize: 14
                                    color: darkGray
                                    horizontalAlignment: Text.AlignHCenter
                                }
                                
                                onClicked: currentStep = 0
                            }
                        }
                    }
                    
                    // ==================== PASO 2: PROGRESO ====================
                    Item {
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 30
                            width: parent.width * 0.6
                            
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Configurando Sistema..."
                                font.pixelSize: 28
                                font.bold: true
                                color: primaryColor
                            }
                            
                            // Indicador de progreso animado
                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: 120
                                Layout.preferredHeight: 120
                                radius: 60
                                color: "transparent"
                                border.color: accentColor
                                border.width: 8
                                
                                RotationAnimation on rotation {
                                    from: 0
                                    to: 360
                                    duration: 2000
                                    loops: Animation.Infinite
                                    running: setupInProgress
                                }
                                
                                Rectangle {
                                    width: 50
                                    height: 8
                                    radius: 4
                                    color: accentColor
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.top: parent.top
                                    anchors.topMargin: 10
                                }
                            }
                            
                            Text {
                                id: progressMessage
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: parent.width
                                text: "Iniciando configuración..."
                                font.pixelSize: 16
                                color: darkGray
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                            }
                            
                            // Lista de pasos
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 15
                                
                                ProgressStep {
                                    id: step1
                                    stepText: "Verificando SQL Server"
                                    completed: false
                                }
                                
                                ProgressStep {
                                    id: step2
                                    stepText: "Creando base de datos"
                                    completed: false
                                }
                                
                                ProgressStep {
                                    id: step3
                                    stepText: "Ejecutando scripts SQL"
                                    completed: false
                                }
                                
                                ProgressStep {
                                    id: step4
                                    stepText: "Creando usuario administrador"
                                    completed: false
                                }
                                
                                ProgressStep {
                                    id: step5
                                    stepText: "Guardando configuración"
                                    completed: false
                                }
                            }
                        }
                    }
                    
                    // ==================== PASO 3: COMPLETADO ====================
                    Item {
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 25
                            width: parent.width * 0.7
                            
                            // Icono de éxito
                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: 120
                                Layout.preferredHeight: 120
                                radius: 60
                                color: "#e8f5e9"
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "✅"
                                    font.pixelSize: 60
                                }
                                
                                SequentialAnimation on scale {
                                    running: currentStep === 3
                                    NumberAnimation { from: 0.8; to: 1.1; duration: 300 }
                                    NumberAnimation { from: 1.1; to: 1.0; duration: 200 }
                                }
                            }
                            
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "¡Configuración Completada!"
                                font.pixelSize: 32
                                font.bold: true
                                color: successColor
                            }
                            
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "El sistema está listo para usar"
                                font.pixelSize: 16
                                color: darkGray
                            }
                            
                            // Recuadro de credenciales
                            Rectangle {
                                Layout.preferredWidth: parent.width
                                Layout.preferredHeight: credencialesLayout.implicitHeight + 40
                                radius: 10
                                color: whiteColor
                                border.color: accentColor
                                border.width: 2
                                
                                ColumnLayout {
                                    id: credencialesLayout
                                    anchors.fill: parent
                                    anchors.margins: 20
                                    spacing: 15
                                    
                                    Text {
                                        Layout.fillWidth: true
                                        text: "⚠️ IMPORTANTE: Guarda estas credenciales"
                                        font.pixelSize: 16
                                        font.bold: true
                                        color: warningColor
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 1
                                        color: lightGray
                                    }
                                    
                                    RowLayout {
                                        Layout.fillWidth: true
                                        
                                        Text {
                                            text: "👤 Usuario:"
                                            font.pixelSize: 16
                                            font.bold: true
                                            color: primaryColor
                                            Layout.preferredWidth: 100
                                        }
                                        
                                        Text {
                                            id: usernameText
                                            text: credenciales.username || "admin"
                                            font.pixelSize: 18
                                            font.bold: true
                                            color: accentColor
                                            Layout.fillWidth: true
                                        }
                                    }
                                    
                                    RowLayout {
                                        Layout.fillWidth: true
                                        
                                        Text {
                                            text: "🔑 Contraseña:"
                                            font.pixelSize: 16
                                            font.bold: true
                                            color: primaryColor
                                            Layout.preferredWidth: 100
                                        }
                                        
                                        Text {
                                            id: passwordText
                                            text: credenciales.password || "admin123"
                                            font.pixelSize: 18
                                            font.bold: true
                                            color: accentColor
                                            Layout.fillWidth: true
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 1
                                        color: lightGray
                                    }
                                    
                                    Text {
                                        Layout.fillWidth: true
                                        text: "⚠️ Después de iniciar sesión, CAMBIA tu contraseña\nen el módulo de Configuración"
                                        font.pixelSize: 13
                                        color: warningColor
                                        horizontalAlignment: Text.AlignHCenter
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }
                            
                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 20
                                
                                Button {
                                    text: "📋 COPIAR CREDENCIALES"
                                    font.pixelSize: 14
                                    
                                    background: Rectangle {
                                        color: parent.pressed ? Qt.darker(darkGray, 1.2) : 
                                               parent.hovered ? Qt.lighter(darkGray, 1.1) : darkGray
                                        radius: 5
                                    }
                                    
                                    contentItem: Text {
                                        text: parent.text
                                        font: parent.font
                                        color: whiteColor
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    
                                    onClicked: {
                                        var texto = "Usuario: " + usernameText.text + "\nContraseña: " + passwordText.text
                                        // TODO: Copiar al portapapeles
                                        console.log("📋 Credenciales copiadas")
                                    }
                                }
                                
                                Button {
                                    text: "➡️ IR AL LOGIN"
                                    font.pixelSize: 16
                                    font.bold: true
                                    
                                    background: Rectangle {
                                        color: parent.pressed ? Qt.darker(successColor, 1.2) : 
                                               parent.hovered ? Qt.lighter(successColor, 1.1) : successColor
                                        radius: 5
                                    }
                                    
                                    contentItem: Text {
                                        text: parent.text
                                        font: parent.font
                                        color: whiteColor
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    
                                    onClicked: {
                                        console.log("✅ Setup completado - Abriendo login")
                                        wizardWindow.close()
                                        // Señal para abrir login
                                        if (typeof authController !== "undefined") {
                                            authController.showLogin()
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
    
    // ==================== FUNCIONES ====================
    
    function iniciarSetupAutomatico() {
        setupInProgress = true
        
        console.log("🚀 Iniciando setup automático...")
        progressMessage.text = "Iniciando configuración automática..."
        
        // Simular progreso de pasos
        step1.completed = false
        step2.completed = false
        step3.completed = false
        step4.completed = false
        step5.completed = false
        
        // Llamar al handler de Python
        if (typeof setupHandler !== "undefined") {
            setupHandler.ejecutar_setup_automatico()
        } else {
            console.log("❌ setupHandler no disponible")
            progressMessage.text = "Error: Handler no disponible"
        }
    }
    
    // Conexiones con Python
    Connections {
        target: typeof setupHandler !== "undefined" ? setupHandler : null
        
        function onSetupProgress(mensaje) {
            console.log("📊 Progreso:", mensaje)
            progressMessage.text = mensaje
            
            // Actualizar pasos visualmente
            if (mensaje.includes("Verificando SQL Server") || mensaje.includes("Validando")) {
                step1.completed = false
                step1.inProgress = true
            } else if (mensaje.includes("SQL Server")) {
                step1.completed = true
                step1.inProgress = false
            }
            
            if (mensaje.includes("Creando base de datos")) {
                step2.inProgress = true
            } else if (mensaje.includes("base de datos") && mensaje.includes("✅")) {
                step2.completed = true
                step2.inProgress = false
            }
            
            if (mensaje.includes("Ejecutando scripts") || mensaje.includes("estructura")) {
                step3.inProgress = true
            } else if (mensaje.includes("estructura") && mensaje.includes("✅")) {
                step3.completed = true
                step3.inProgress = false
            }
            
            if (mensaje.includes("usuario administrador") || mensaje.includes("Creando usuario")) {
                step4.inProgress = true
            } else if (mensaje.includes("usuario") && mensaje.includes("✅")) {
                step4.completed = true
                step4.inProgress = false
            }
            
            if (mensaje.includes("Guardando configuración")) {
                step5.inProgress = true
            } else if (mensaje.includes("configuración") && mensaje.includes("✅")) {
                step5.completed = true
                step5.inProgress = false
            }
        }
        
        function onSetupCompleted(exito, mensaje, creds) {
            setupInProgress = false
            
            console.log("🎯 Setup completado:", exito, mensaje)
            console.log("🔑 Credenciales:", JSON.stringify(creds))
            
            if (exito) {
                // Completar todos los pasos
                step1.completed = true
                step2.completed = true
                step3.completed = true
                step4.completed = true
                step5.completed = true
                
                step1.inProgress = false
                step2.inProgress = false
                step3.inProgress = false
                step4.inProgress = false
                step5.inProgress = false
                
                // Guardar credenciales
                credenciales = creds
                
                // Pasar a pantalla de completado después de un delay
                completionTimer.start()
            } else {
                progressMessage.text = "❌ Error: " + mensaje
                
                // Mostrar diálogo de error
                errorDialog.text = mensaje
                errorDialog.visible = true
            }
        }
    }
    
    Timer {
        id: completionTimer
        interval: 1500
        onTriggered: currentStep = 3
    }
    
    // Diálogo de error
    Rectangle {
        id: errorDialog
        anchors.centerIn: parent
        width: 500
        height: 250
        radius: 10
        color: whiteColor
        border.color: accentColor
        border.width: 2
        visible: false
        z: 1000
        
        property alias text: errorText.text
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 30
            spacing: 20
            
            Text {
                text: "❌ Error en la Configuración"
                font.pixelSize: 20
                font.bold: true
                color: accentColor
            }
            
            Text {
                id: errorText
                Layout.fillWidth: true
                font.pixelSize: 14
                color: darkGray
                wrapMode: Text.WordWrap
            }
            
            Item { Layout.fillHeight: true }
            
            Button {
                Layout.alignment: Qt.AlignHCenter
                text: "CERRAR"
                
                onClicked: {
                    errorDialog.visible = false
                    currentStep = 1  // Volver a selección
                }
            }
        }
    }
    
    // Componente de paso de progreso
    Component {
        id: progressStepComponent
        
        RowLayout {
            Layout.fillWidth: true
            spacing: 15
            
            property alias stepText: stepLabel.text
            property bool completed: false
            property bool inProgress: false
            
            Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: 15
                color: parent.completed ? successColor : 
                       parent.inProgress ? accentColor : lightGray
                border.color: parent.completed || parent.inProgress ? "transparent" : darkGray
                border.width: 2
                
                Behavior on color { ColorAnimation { duration: 300 } }
                
                Text {
                    anchors.centerIn: parent
                    text: parent.parent.completed ? "✓" : 
                          parent.parent.inProgress ? "⏳" : ""
                    color: whiteColor
                    font.pixelSize: 16
                    font.bold: true
                }
                
                RotationAnimation on rotation {
                    from: 0
                    to: 360
                    duration: 2000
                    loops: Animation.Infinite
                    running: parent.parent.inProgress
                }
            }
            
            Text {
                id: stepLabel
                Layout.fillWidth: true
                font.pixelSize: 15
                color: parent.completed ? successColor :
                       parent.inProgress ? primaryColor : darkGray
                font.bold: parent.inProgress || parent.completed
                
                Behavior on color { ColorAnimation { duration: 300 } }
            }
        }
    }


    // Componente de paso reutilizable
    // ==================== COMPONENTE DE PASO DE PROGRESO ====================
    component ProgressStep: RowLayout {
        id: progressStepRoot
        Layout.fillWidth: true
        spacing: 15
        
        // ✅ NO usar alias, usar propiedades directas
        property string stepText: ""
        property bool completed: false
        property bool inProgress: false
        
        Rectangle {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            radius: 15
            color: progressStepRoot.completed ? "#27ae60" : 
                   progressStepRoot.inProgress ? "#e30909" : "#ecf0f1"
            border.color: progressStepRoot.completed || progressStepRoot.inProgress ? "transparent" : "#7f8c8d"
            border.width: 2
            
            Behavior on color { ColorAnimation { duration: 300 } }
            
            Text {
                anchors.centerIn: parent
                text: progressStepRoot.completed ? "✓" : 
                      progressStepRoot.inProgress ? "⏳" : ""
                color: "#ffffff"
                font.pixelSize: 16
                font.bold: true
            }
            
            RotationAnimation on rotation {
                from: 0
                to: 360
                duration: 2000
                loops: Animation.Infinite
                running: progressStepRoot.inProgress
            }
        }
        
        Text {
            Layout.fillWidth: true
            text: progressStepRoot.stepText
            font.pixelSize: 15
            color: progressStepRoot.completed ? "#27ae60" :
                   progressStepRoot.inProgress ? "#273746" : "#7f8c8d"
            font.bold: progressStepRoot.inProgress || progressStepRoot.completed
            
            Behavior on color { ColorAnimation { duration: 300 } }
        }
    }
}
