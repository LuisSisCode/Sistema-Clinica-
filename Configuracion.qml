import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15

Item {
    id: configuracionRoot
    objectName: "configuracionRoot"
    
    // Paleta de colores minimalista
    readonly property color primaryColor: "#4F46E5"
    readonly property color backgroundColor: "#FFFFFF"
    readonly property color surfaceColor: "#F8FAFC"
    readonly property color borderColor: "#E2E8F0"
    readonly property color textColor: "#1F2937"
    readonly property color textSecondaryColor: "#6B7280"
    readonly property color successColor: "#10B981"
    readonly property color warningColor: "#F59E0B"
    
    // Estados de la aplicación
    property bool isLoading: false
    property string currentUser: "Dr. María González"
    property string currentUserInitials: "MG"
    property string currentUserRole: "Médico General"
    property string currentUserEmail: "maria.gonzalez@mariainmaculada.com"
    property string currentUsername: "dr.maria"
    
    // Función para mostrar notificaciones
    function showNotification(title, message, type) {
        notificationBanner.show(title, message, type)
    }
    
    ScrollView {
        id: mainScrollView
        anchors.fill: parent
        anchors.margins: 24
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        
        ColumnLayout {
            width: configuracionRoot.width - 48
            spacing: 24
            
            // Header principal simplificado
            Label {
                text: "Configuración del Sistema"
                color: textColor
                font.pixelSize: 20
                font.bold: true
                Layout.topMargin: 8
            }
            
            Label {
                text: "Gestiona las preferencias del sistema"
                color: textSecondaryColor
                font.pixelSize: 14
                Layout.bottomMargin: 8
            }

            // Tarjeta única con toda la información
            Rectangle {
                id: mainCard
                Layout.fillWidth: true
                Layout.preferredHeight: 400
                color: backgroundColor
                radius: 8
                border.color: borderColor
                border.width: 1
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 32
                    
                    // Sección Mi Perfil
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 20
                        
                        Label {
                            text: "Mi Perfil"
                            color: textColor
                            font.pixelSize: 18
                            font.bold: true
                        }
                        
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 24
                            
                            // Avatar simple
                            Rectangle {
                                Layout.preferredWidth: 60
                                Layout.preferredHeight: 60
                                radius: 30
                                color: primaryColor
                                
                                Label {
                                    anchors.centerIn: parent
                                    text: currentUserInitials
                                    font.pixelSize: 20
                                    font.bold: true
                                    color: "white"
                                }
                            }
                            
                            // Información del usuario
                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2
                                columnSpacing: 32
                                rowSpacing: 12
                                
                                ProfileField {
                                    Layout.fillWidth: true
                                    label: "Nombre"
                                    value: currentUser
                                }
                                
                                ProfileField {
                                    Layout.fillWidth: true
                                    label: "Especialidad"
                                    value: currentUserRole
                                }
                                
                                ProfileField {
                                    Layout.fillWidth: true
                                    label: "Usuario"
                                    value: currentUsername
                                }
                                
                                ProfileField {
                                    Layout.fillWidth: true
                                    label: "Email"
                                    value: currentUserEmail
                                }
                            }
                            
                            // Botón de cambiar contraseña
                            Button {
                                text: "Cambiar Contraseña"
                                Layout.preferredHeight: 36
                                
                                background: Rectangle {
                                    color: parent.pressed ? Qt.darker(primaryColor, 1.2) : primaryColor
                                    radius: 6
                                }
                                
                                contentItem: Label {
                                    text: parent.text
                                    color: "white"
                                    font.pixelSize: 13
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                
                                onClicked: changePasswordDialog.open()
                            }
                        }
                    }
                    
                    // Sección Información del Sistema
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 20
                        
                        Label {
                            text: "Información del Sistema"
                            color: textColor
                            font.pixelSize: 18
                            font.bold: true
                        }
                        
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: 48
                            rowSpacing: 16
                            
                            SystemField {
                                Layout.fillWidth: true
                                label: "Versión"
                                value: "1.0"
                            }
                            
                            SystemField {
                                Layout.fillWidth: true
                                label: "Desarrollado por"
                                value: "DeTNova"
                            }
                            
                            SystemField {
                                Layout.fillWidth: true
                                label: "Última Actualización"
                                value: "08 de Julio, 2025"
                            }
                            
                            SystemField {
                                Layout.fillWidth: true
                                label: "Clínica"
                                value: "María Inmaculada"
                            }
                        }
                    }
                }
            }
        }
    }

    // Diálogo simplificado para cambiar contraseña
    Dialog {
        id: changePasswordDialog
        title: "Cambiar Contraseña"
        modal: true
        width: 400
        height: 420
        anchors.centerIn: parent
        standardButtons: Dialog.NoButton

        background: Rectangle {
            color: backgroundColor
            radius: 8
            border.color: borderColor
            border.width: 1
        }

        onClosed: {
            currentPasswordInput.text = ""
            newPasswordInput.text = ""
            confirmPasswordInput.text = ""
            clearErrors()
        }
        
        function clearErrors() {
            currentPasswordInput.hasError = false
            newPasswordInput.hasError = false
            confirmPasswordInput.hasError = false
            currentPasswordError.visible = false
            newPasswordError.visible = false
            confirmPasswordError.visible = false
        }
        
        contentItem: ColumnLayout {
            width: parent.width
            spacing: 20
            anchors.margins: 24

            Label {
                text: "Introduce tu contraseña actual y establece una nueva contraseña."
                wrapMode: Text.WordWrap
                color: textSecondaryColor
                font.pixelSize: 14
                Layout.fillWidth: true
            }

            // Contraseña Actual
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                
                Label {
                    text: "Contraseña Actual"
                    color: textColor
                    font.pixelSize: 13
                    font.bold: true
                }
                
                SecureTextField {
                    id: currentPasswordInput
                    Layout.fillWidth: true
                    placeholderText: "Contraseña actual"
                }
                
                Label {
                    id: currentPasswordError
                    text: "La contraseña actual es requerida"
                    color: warningColor
                    font.pixelSize: 11
                    visible: false
                }
            }

            // Nueva Contraseña
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                
                Label {
                    text: "Nueva Contraseña"
                    color: textColor
                    font.pixelSize: 13
                    font.bold: true
                }
                
                SecureTextField {
                    id: newPasswordInput
                    Layout.fillWidth: true
                    placeholderText: "Mínimo 8 caracteres"
                    
                    onTextChanged: {
                        if (confirmPasswordInput.text.length > 0) {
                            if (text === confirmPasswordInput.text) {
                                confirmPasswordInput.hasError = false
                                confirmPasswordError.visible = false
                            } else {
                                confirmPasswordInput.hasError = true
                                confirmPasswordError.visible = true
                            }
                        }
                    }
                }
                
                Label {
                    id: newPasswordError
                    text: "La contraseña debe tener al menos 8 caracteres"
                    color: warningColor
                    font.pixelSize: 11
                    visible: false
                }
            }

            // Confirmar Contraseña
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                
                Label {
                    text: "Confirmar Nueva Contraseña"
                    color: textColor
                    font.pixelSize: 13
                    font.bold: true
                }
                
                SecureTextField {
                    id: confirmPasswordInput
                    Layout.fillWidth: true
                    placeholderText: "Confirma la nueva contraseña"
                    
                    onTextChanged: {
                        if (text === newPasswordInput.text && text.length > 0) {
                            hasError = false
                            confirmPasswordError.visible = false
                        } else if (text.length > 0) {
                            hasError = true
                            confirmPasswordError.visible = true
                        }
                    }
                }
                
                Label {
                    id: confirmPasswordError
                    text: "Las contraseñas no coinciden"
                    color: warningColor
                    font.pixelSize: 11
                    visible: false
                }
            }
        }

        footer: RowLayout {
            width: parent.width
            spacing: 12

            Button {
                text: "Cancelar"
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                
                onClicked: changePasswordDialog.close()
                
                background: Rectangle { 
                    color: parent.pressed ? Qt.darker(borderColor, 1.2) : surfaceColor
                    radius: 6
                    border.color: borderColor
                    border.width: 1
                }
                
                contentItem: Label { 
                    text: parent.text
                    color: textColor
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Button {
                text: "Confirmar"
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                
                onClicked: validateAndChangePassword()
                
                background: Rectangle { 
                    color: parent.pressed ? Qt.darker(successColor, 1.2) : successColor
                    radius: 6
                }
                
                contentItem: Label { 
                    text: parent.text
                    color: "white"
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
        
        function validateAndChangePassword() {
            var hasErrors = false
            
            if (currentPasswordInput.text === "") {
                currentPasswordInput.hasError = true
                currentPasswordError.visible = true
                hasErrors = true
            }
            
            if (newPasswordInput.text === "") {
                newPasswordInput.hasError = true
                newPasswordError.text = "La nueva contraseña es requerida"
                newPasswordError.visible = true
                hasErrors = true
            } else if (newPasswordInput.text.length < 8) {
                newPasswordInput.hasError = true
                newPasswordError.text = "La contraseña debe tener al menos 8 caracteres"
                newPasswordError.visible = true
                hasErrors = true
            }
            
            if (confirmPasswordInput.text === "") {
                confirmPasswordInput.hasError = true
                confirmPasswordError.text = "Confirma la nueva contraseña"
                confirmPasswordError.visible = true
                hasErrors = true
            } else if (newPasswordInput.text !== confirmPasswordInput.text) {
                confirmPasswordInput.hasError = true
                confirmPasswordError.text = "Las contraseñas no coinciden"
                confirmPasswordError.visible = true
                hasErrors = true
            }
            
            if (!hasErrors) {
                isLoading = true
                passwordChangeTimer.start()
            }
        }
    }
    
    Timer {
        id: passwordChangeTimer
        interval: 1500
        onTriggered: {
            isLoading = false
            showNotification("Contraseña", "Contraseña actualizada exitosamente", "success")
            changePasswordDialog.close()
        }
    }

    // Banner de notificaciones simplificado
    NotificationBanner {
        id: notificationBanner
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 24
        z: 1000
    }

    // Overlay de carga
    Rectangle {
        anchors.fill: parent
        color: "#80000000"
        visible: isLoading
        z: 999
        
        Rectangle {
            anchors.centerIn: parent
            width: 120
            height: 80
            color: backgroundColor
            radius: 8
            
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 12
                
                BusyIndicator {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                }
                
                Label {
                    text: "Procesando..."
                    font.pixelSize: 12
                    color: textColor
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
    }

    // Componentes personalizados simplificados
    component ProfileField: ColumnLayout {
        property string label: ""
        property string value: ""
        
        spacing: 4
        
        Label {
            text: label
            color: textSecondaryColor
            font.pixelSize: 11
            font.bold: true
        }
        
        Label {
            text: value
            color: textColor
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }
    }

    component SystemField: ColumnLayout {
        property string label: ""
        property string value: ""
        
        spacing: 4
        
        Label {
            text: label
            color: textSecondaryColor
            font.pixelSize: 11
            font.bold: true
        }
        
        Label {
            text: value
            color: textColor
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }
    }

    component SecureTextField: TextField {
        property bool hasError: false
        
        Layout.preferredHeight: 40
        echoMode: TextInput.Password
        font.pixelSize: 13
        
        background: Rectangle {
            color: backgroundColor
            border.color: parent.hasError ? warningColor : (parent.activeFocus ? primaryColor : borderColor)
            border.width: 1
            radius: 6
        }
    }

    component NotificationBanner: Rectangle {
        id: banner
        height: 0
        color: backgroundColor
        radius: 6
        border.color: borderColor
        border.width: 1
        clip: true
        
        property string notificationTitle: ""
        property string notificationMessage: ""
        property string notificationType: "info"
        
        function show(title, message, type) {
            notificationTitle = title
            notificationMessage = message
            notificationType = type
            
            showAnimation.start()
            hideTimer.start()
        }
        
        RowLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12
            
            Rectangle {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                radius: 12
                color: notificationType === "success" ? successColor : primaryColor
                
                Label {
                    anchors.centerIn: parent
                    text: notificationType === "success" ? "✓" : "i"
                    font.pixelSize: 12
                    font.bold: true
                    color: "white"
                }
            }
            
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                
                Label {
                    text: notificationTitle
                    font.bold: true
                    font.pixelSize: 13
                    color: textColor
                }
                
                Label {
                    text: notificationMessage
                    font.pixelSize: 12
                    color: textSecondaryColor
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
            
            Button {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                
                background: Rectangle {
                    color: "transparent"
                    radius: 12
                }
                
                contentItem: Label {
                    text: "×"
                    font.pixelSize: 14
                    color: textSecondaryColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: hideAnimation.start()
            }
        }
        
        NumberAnimation {
            id: showAnimation
            target: banner
            property: "height"
            to: 60
            duration: 300
            easing.type: Easing.OutCubic
        }
        
        NumberAnimation {
            id: hideAnimation
            target: banner
            property: "height"
            to: 0
            duration: 300
            easing.type: Easing.InCubic
        }
        
        Timer {
            id: hideTimer
            interval: 3000
            onTriggered: hideAnimation.start()
        }
    }
}