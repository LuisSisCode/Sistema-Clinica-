import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15

Item {
    id: configuracionRoot
    objectName: "configuracionRoot"
    
    // ===== NUEVA PROPIEDAD PARA RECIBIR DATOS DE MAIN.QML =====
    property var especialidadesModel: []
    
    // ===== NUEVA PROPIEDAD PARA TIPOS DE GASTOS DESDE MAIN.QML =====
    property var tiposGastosModel: []
    
    // ===== NUEVA PROPIEDAD PARA TIPOS DE PROCEDIMIENTOS DESDE MAIN.QML =====
    property var tiposProcedimientosModel: []
  
    // ===== NUEVA PROPIEDAD PARA TIPOS DE ANÁLISIS DESDE MAIN.QML =====
    property var tiposAnalisisModel: []
    
    // ===== PASO 2b: NUEVA PROPIEDAD PARA TIPOS DE TRABAJADORES DESDE MAIN.QML =====
    property var tiposTrabajadoresModel: []
    
    // ===== SISTEMA DE ESCALADO RESPONSIVO =====
    readonly property real baseUnit: Math.min(width, height) / 100
    readonly property real fontTiny: baseUnit * 1.2
    readonly property real fontSmall: baseUnit * 1.5
    readonly property real fontBase: baseUnit * 2.0
    readonly property real fontMedium: baseUnit * 2.5
    readonly property real fontLarge: baseUnit * 3.0
    readonly property real fontTitle: baseUnit * 4.0
    
    readonly property real marginTiny: baseUnit * 0.5
    readonly property real marginSmall: baseUnit * 1
    readonly property real marginMedium: baseUnit * 2
    readonly property real marginLarge: baseUnit * 3
    readonly property real marginExtraLarge: baseUnit * 4
    
    readonly property real radiusSmall: baseUnit * 0.8
    readonly property real radiusMedium: baseUnit * 1.5
    readonly property real radiusLarge: baseUnit * 2
    
    // ===== PALETA DE COLORES MEJORADA =====
    readonly property string primaryColor: "#6366F1"
    readonly property string backgroundColor: "#FFFFFF"
    readonly property string surfaceColor: "#F8FAFC"
    readonly property string borderColor: "#E5E7EB"
    readonly property string textColor: "#111827"
    readonly property string textSecondaryColor: "#6B7280"
    readonly property string successColor: "#059669"
    readonly property string warningColor: "#D97706"
    readonly property string dangerColor: "#DC2626"
    readonly property string infoColor: "#2563EB"
    
    // ===== COLORES ESPECÍFICOS PARA MÓDULOS MEJORADOS =====
    readonly property string laboratorioColor: "#8B5CF6"
    readonly property string enfermeriaColor: "#EC4899"
    readonly property string consultasColor: "#06B6D4"
    readonly property string serviciosColor: "#65A30D"
    readonly property string usuariosColor: "#EA580C"
    readonly property string personalColor: "#7C3AED"
    
    // ===== ESTADOS DE LA APLICACIÓN =====
    property string currentView: "main"
    property bool showChangePasswordDialog: false
    
    // ===== DATOS DEL USUARIO =====
    property string currentUser: "Dr. María González"
    property string currentUserInitials: "MG"
    property string currentUserRole: "Médico General"
    property string currentUserEmail: "maria.gonzalez@mariainmaculada.com"
    property string currentUsername: "dr.maria"
    
    // ===== FUNCIONES =====
    function showNotification(title, message, type) {
        notificationBanner.show(title, message, type)
    }
    
    function changeView(newView) {
        currentView = newView
        console.log("🔄 Vista cambiada a:", newView)
    }
    
    function getModuleColor(moduleId) {
        switch(moduleId) {
            case "laboratorio": return laboratorioColor
            case "enfermeria": return enfermeriaColor
            case "consultas": return consultasColor
            case "servicios": return serviciosColor
            case "usuarios": return usuariosColor
            case "personal": return personalColor
            default: return primaryColor
        }
    }
    
    // ===== DATOS DE LOS MÓDULOS MEJORADOS =====
    readonly property var modulesData: [
        {
            id: "laboratorio",
            title: "Laboratorio",
            icon: "🧪",
            description: "Configura tipos de análisis, equipos y parámetros de laboratorio clínico"
        },
        {
            id: "enfermeria",
            title: "Enfermería",
            icon: "💉",
            description: "Gestiona protocolos de cuidados, procedimientos y planes de enfermería"
        },
        {
            id: "consultas",
            title: "Consultas",
            icon: "🩺",
            description: "Administra especialidades médicas,precios de consultas"
        },
        {
            id: "servicios",
            title: "Servicios Básicos",
            icon: "💰",
            description: "Controla gastos operativos, categorías financieras y configuraciones"
        },
        {
            id: "usuarios",
            title: "Usuarios",
            icon: "👤",
            description: "Define roles, permisos de acceso y políticas de seguridad del sistema"
        },
        {
            id: "personal",
            title: "Personal",
            icon: "👥",
            description: "Organiza departamentos, especialidades y estructura organizacional"
        }
    ]
    
    // ===== VISTA PRINCIPAL =====
    ScrollView {
        id: mainView
        anchors.fill: parent
        visible: currentView === "main"
        clip: true
        
        ColumnLayout {
            width: configuracionRoot.width
            spacing: marginMedium
            
            // Header Principal
            HeaderSection {
                Layout.fillWidth: true
                title: "Centro de Configuraciones"
                subtitle: "Administra las configuraciones del sistema y personaliza cada módulo según tus necesidades"
                icon: "⚙️"
                color: primaryColor
            }
            
            // Sección de Módulos
            ModulesSection {
                Layout.fillWidth: true
                Layout.margins: marginMedium
            }
            
            // Divisor elegante
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 2
                Layout.margins: marginMedium
                radius: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: borderColor }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
            
            // Configuraciones Generales - DIVIDIDO EN DOS COLUMNAS
            GeneralConfigSection {
                Layout.fillWidth: true
                Layout.margins: marginMedium
            }
            
            // Espacio final
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: marginMedium
            }
        }
    }
    
    // ===== VISTAS DE CONFIGURACIÓN ESPECÍFICAS =====
    Loader {
        id: configViewLoader
        anchors.fill: parent
        visible: currentView !== "main"
        
        sourceComponent: {
            switch(currentView) {
                case "laboratorio": return laboratorioConfigComponent
                case "enfermeria": return enfermeriaConfigComponent
                case "consultas": return consultasConfigComponent
                case "servicios": return serviciosConfigComponent
                case "usuarios": return usuariosConfigComponent
                case "personal": return personalConfigComponent
                default: return null
            }
        }
    }
    
    // ===== DIÁLOGO DE CAMBIO DE CONTRASEÑA =====
    PasswordChangeDialog {
        id: passwordDialog
        visible: showChangePasswordDialog
        onClosed: showChangePasswordDialog = false
        onPasswordChanged: {
            showChangePasswordDialog = false
            showNotification("Contraseña", "Contraseña actualizada exitosamente", "success")
        }
    }
    
    // ===== BANNER DE NOTIFICACIONES =====
    NotificationBanner {
        id: notificationBanner
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: marginLarge
        z: 2000
    }
    
    // ===== COMPONENTES REUTILIZABLES =====
    
    component HeaderSection: Rectangle {
        property string title: ""
        property string subtitle: ""
        property string icon: ""
        property string color: primaryColor
        
        Layout.preferredHeight: Math.max(120, baseUnit * 15)
        gradient: Gradient {
            GradientStop { position: 0.0; color: color }
            GradientStop { position: 1.0; color: Qt.darker(color, 1.1) }
        }
        radius: radiusLarge
        
        // Efecto de sombra sutil
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 4
            radius: parent.radius
            color: "black"
            opacity: 0.1
            z: -1
        }
        
        RowLayout {
            anchors.fill: parent
            anchors.margins: marginLarge
            spacing: marginMedium
            
            Rectangle {
                Layout.preferredWidth: baseUnit * 10
                Layout.preferredHeight: baseUnit * 10
                color: backgroundColor
                radius: baseUnit * 5
                
                // Sombra interna
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 2
                    radius: parent.radius - 2
                    color: "transparent"
                    border.color: Qt.lighter(color, 1.1)
                    border.width: 1
                }
                
                Label {
                    anchors.centerIn: parent
                    text: icon
                    font.pixelSize: fontTitle * 1.5
                }
            }
            
            ColumnLayout {
                Layout.fillWidth: true
                spacing: marginSmall
                
                Label {
                    text: title
                    color: backgroundColor
                    font.pixelSize: fontTitle
                    font.bold: true
                    font.family: "Segoe UI"
                }
                
                Label {
                    text: subtitle
                    color: backgroundColor
                    font.pixelSize: fontBase
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    opacity: 0.95
                    font.family: "Segoe UI"
                }
            }
        }
    }
    
    component ModulesSection: ColumnLayout {
        spacing: marginMedium
        
        SectionHeader {
            Layout.fillWidth: true
            title: "Configuraciones por Módulo"
            subtitle: "Accede y personaliza las configuraciones específicas de cada área del sistema médico"
            barColor: primaryColor
        }
        
        Grid {
            Layout.fillWidth: true
            columns: width < 600 ? 1 : (width < 900 ? 2 : (width < 1400 ? 3 : 4))
            spacing: marginMedium
            
            Repeater {
                model: modulesData
                
                ModuleCard {
                    moduleData: modelData
                    cardWidth: {
                        var cols = parent.columns
                        var availableWidth = configuracionRoot.width - marginLarge * 2
                        var spacingTotal = (cols - 1) * marginMedium
                        return (availableWidth - spacingTotal) / cols
                    }
                    onClicked: changeView(moduleData.id)
                }
            }
        }
    }
    
    component GeneralConfigSection: ColumnLayout {
        spacing: marginMedium
        
        SectionHeader {
            Layout.fillWidth: true
            title: "Configuraciones Generales"
            subtitle: "Información del sistema y configuración del perfil de usuario"
            barColor: infoColor
        }
        
        // DIVIDIDO EN DOS COLUMNAS
        RowLayout {
            Layout.fillWidth: true
            spacing: marginLarge
            
            // COLUMNA IZQUIERDA - INFORMACIÓN DEL SISTEMA
            SystemInfoCard {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(320, baseUnit * 40)
            }
            
            // COLUMNA DERECHA - CONFIGURACIÓN GENERAL (MI PERFIL)
            ProfileCard {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(320, baseUnit * 40)
            }
        }
    }
    
    component SectionHeader: RowLayout {
        property string title: ""
        property string subtitle: ""
        property string barColor: primaryColor
        
        spacing: marginSmall
        
        Rectangle {
            Layout.preferredWidth: baseUnit * 0.6
            Layout.preferredHeight: fontLarge * 1.2
            color: barColor
            radius: baseUnit * 0.3
        }
        
        ColumnLayout {
            Layout.fillWidth: true
            spacing: marginTiny
            
            Label {
                text: title
                font.pixelSize: fontLarge
                font.bold: true
                color: textColor
                font.family: "Segoe UI"
            }
            
            Label {
                text: subtitle
                color: textSecondaryColor
                font.pixelSize: fontBase
                font.family: "Segoe UI"
            }
        }
    }
    
    component ModuleCard: Rectangle {
        property var moduleData
        property real cardWidth: 300
        signal clicked()
        
        width: cardWidth
        height: Math.max(140, baseUnit * 18)
        radius: radiusMedium
        border.color: borderColor
        border.width: 1
        
        property string moduleColor: getModuleColor(moduleData.id)
        
        // Efecto de elevación
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: mouseArea.containsMouse ? 2 : 4
            radius: parent.radius
            color: "black"
            opacity: mouseArea.containsMouse ? 0.15 : 0.08
            z: -1
        }
        
        gradient: Gradient {
            GradientStop { position: 0.0; color: moduleColor }
            GradientStop { position: 1.0; color: Qt.darker(moduleColor, 1.08) }
        }
        
        scale: mouseArea.containsMouse ? 1.02 : 1.0
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        
        RowLayout {
            anchors.fill: parent
            anchors.margins: marginMedium
            spacing: marginMedium
            
            Rectangle {
                Layout.preferredWidth: baseUnit * 6
                Layout.preferredHeight: baseUnit * 6
                color: backgroundColor
                radius: baseUnit * 3
                
                // Borde sutil
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: parent.radius - 1
                    color: "transparent"
                    border.color: Qt.lighter(moduleColor, 1.2)
                    border.width: 1
                }
                
                Label {
                    anchors.centerIn: parent
                    text: moduleData.icon
                    font.pixelSize: fontLarge
                }
            }
            
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: marginTiny
                
                Label {
                    text: moduleData.title
                    color: backgroundColor
                    font.pixelSize: fontMedium
                    font.bold: true
                    font.family: "Segoe UI"
                }
                
                Label {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    text: moduleData.description
                    color: backgroundColor
                    font.pixelSize: fontSmall
                    wrapMode: Text.WordWrap
                    verticalAlignment: Text.AlignTop
                    opacity: 0.9
                    font.family: "Segoe UI"
                }
                
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: baseUnit * 3
                    color: backgroundColor
                    radius: radiusSmall
                    opacity: 0.9
                    
                    Label {
                        anchors.centerIn: parent
                        text: "Configurar"
                        color: moduleColor
                        font.pixelSize: fontSmall
                        font.bold: true
                        font.family: "Segoe UI"
                    }
                }
            }
        }
        
        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }
    
    // NUEVA TARJETA PARA INFORMACIÓN DEL SISTEMA
    component SystemInfoCard: Rectangle {
        color: backgroundColor
        radius: radiusMedium
        border.color: borderColor
        border.width: 1
        
        // Efecto de sombra
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 3
            radius: parent.radius
            color: "black"
            opacity: 0.05
            z: -1
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: marginMedium
            spacing: marginMedium
            
            // Header de la tarjeta
            RowLayout {
                Layout.fillWidth: true
                spacing: marginSmall
                
                Rectangle {
                    Layout.preferredWidth: baseUnit * 4.5
                    Layout.preferredHeight: baseUnit * 4.5
                    color: infoColor
                    radius: baseUnit * 2.25
                    
                    Label {
                        anchors.centerIn: parent
                        text: "💻"
                        font.pixelSize: fontMedium
                    }
                }
                
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    
                    Label {
                        text: "Información del Sistema"
                        color: textColor
                        font.pixelSize: fontMedium
                        font.bold: true
                        font.family: "Segoe UI"
                    }
                    
                    Label {
                        text: "Detalles técnicos y versión"
                        color: textSecondaryColor
                        font.pixelSize: fontSmall
                        font.family: "Segoe UI"
                    }
                }
            }
            
            // Contenido de información del sistema
            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 1
                rowSpacing: marginSmall
                
                SystemField { 
                    label: "Versión del Sistema"
                    value: "1.0.0"
                    icon: "🔢"
                }
                
                SystemField { 
                    label: "Desarrollado por"
                    value: "DeTNova"
                    icon: "👨‍💻"
                }
                
                SystemField { 
                    label: "Última Actualización"
                    value: "08 de Julio, 2025"
                    icon: "📅"
                }
                
                SystemField { 
                    label: "Institución"
                    value: "Clínica María Inmaculada"
                    icon: "🏥"
                }
            }
        }
    }
    
    // NUEVA TARJETA PARA PERFIL DE USUARIO
    component ProfileCard: Rectangle {
        color: backgroundColor
        radius: radiusMedium
        border.color: borderColor
        border.width: 1
        
        // Efecto de sombra
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 3
            radius: parent.radius
            color: "black"
            opacity: 0.05
            z: -1
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: marginMedium
            spacing: marginMedium
            
            // Header de la tarjeta
            RowLayout {
                Layout.fillWidth: true
                spacing: marginSmall
                
                Rectangle {
                    Layout.preferredWidth: baseUnit * 4.5
                    Layout.preferredHeight: baseUnit * 4.5
                    color: primaryColor
                    radius: baseUnit * 2.25
                    
                    Label {
                        anchors.centerIn: parent
                        text: "👤"
                        font.pixelSize: fontMedium
                    }
                }
                
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    
                    Label {
                        text: "Mi Perfil"
                        color: textColor
                        font.pixelSize: fontMedium
                        font.bold: true
                        font.family: "Segoe UI"
                    }
                    
                    Label {
                        text: "Información personal y configuración"
                        color: textSecondaryColor
                        font.pixelSize: fontSmall
                        font.family: "Segoe UI"
                    }
                }
            }
            
            // Avatar y datos básicos compactos
            RowLayout {
                Layout.fillWidth: true
                spacing: marginMedium
                
                Rectangle {
                    Layout.preferredWidth: baseUnit * 7
                    Layout.preferredHeight: baseUnit * 7
                    radius: baseUnit * 3.5
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: primaryColor }
                        GradientStop { position: 1.0; color: Qt.darker(primaryColor, 1.1) }
                    }
                    
                    Label {
                        anchors.centerIn: parent
                        text: currentUserInitials
                        font.pixelSize: fontLarge
                        font.bold: true
                        color: backgroundColor
                        font.family: "Segoe UI"
                    }
                }
                
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: marginTiny
                    
                    Label {
                        text: currentUser
                        color: textColor
                        font.pixelSize: fontMedium
                        font.bold: true
                        font.family: "Segoe UI"
                    }
                    
                    Label {
                        text: currentUserRole
                        color: textSecondaryColor
                        font.pixelSize: fontSmall
                        font.family: "Segoe UI"
                    }
                }
            }
            
            // Información detallada compacta
            GridLayout {
                Layout.fillWidth: true
                columns: 1
                rowSpacing: marginSmall
                
                ProfileField { 
                    label: "Usuario"
                    value: currentUsername
                    icon: "🔑"
                }
                
                ProfileField { 
                    label: "Email"
                    value: currentUserEmail
                    icon: "📧"
                }
            }
            
            // Botón de cambio de contraseña compacto
            Button {
                Layout.fillWidth: true
                Layout.preferredHeight: baseUnit * 4.5
                text: "Cambiar Contraseña"
                
                background: Rectangle {
                    color: parent.pressed ? Qt.darker(successColor, 1.2) : successColor
                    radius: radiusSmall
                    
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: parent.radius - 1
                        color: "transparent"
                        border.color: Qt.lighter(successColor, 1.2)
                        border.width: 1
                    }
                }
                
                contentItem: RowLayout {
                    spacing: marginTiny
                    
                    Label {
                        text: "🔒"
                        font.pixelSize: fontSmall
                        color: backgroundColor
                    }
                    
                    Label {
                        text: parent.parent.text
                        color: backgroundColor
                        font.pixelSize: fontSmall
                        font.bold: true
                        font.family: "Segoe UI"
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
                
                onClicked: showChangePasswordDialog = true
            }
        }
    }
    
    component ProfileField: RowLayout {
        property string label: ""
        property string value: ""
        property string icon: ""
        
        Layout.fillWidth: true
        spacing: marginSmall
        
        Label {
            text: icon
            font.pixelSize: fontSmall
            Layout.preferredWidth: baseUnit * 2.5
        }
        
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            
            Label {
                text: label
                color: textSecondaryColor
                font.pixelSize: fontTiny
                font.bold: true
                font.family: "Segoe UI"
            }
            
            Label {
                text: value
                color: textColor
                font.pixelSize: fontSmall
                wrapMode: Text.WordWrap
                font.family: "Segoe UI"
            }
        }
    }
    
    component SystemField: RowLayout {
        property string label: ""
        property string value: ""
        property string icon: ""
        
        Layout.fillWidth: true
        spacing: marginSmall
        
        Label {
            text: icon
            font.pixelSize: fontSmall
            Layout.preferredWidth: baseUnit * 2.5
        }
        
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            
            Label {
                text: label
                color: textSecondaryColor
                font.pixelSize: fontTiny
                font.bold: true
                font.family: "Segoe UI"
            }
            
            Label {
                text: value
                color: textColor
                font.pixelSize: fontSmall
                wrapMode: Text.WordWrap
                font.family: "Segoe UI"
            }
        }
    }
    
    component PasswordChangeDialog: Rectangle {
        signal closed()
        signal passwordChanged()
        
        anchors.fill: parent
        color: "transparent"
        z: 1000
        
        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: 0.5
            
            MouseArea {
                anchors.fill: parent
                onClicked: closed()
            }
        }
        
        Rectangle {
            anchors.centerIn: parent
            width: Math.min(500, configuracionRoot.width * 0.9)
            height: Math.min(600, configuracionRoot.height * 0.8)
            color: backgroundColor
            radius: radiusMedium
            border.color: borderColor
            border.width: 1
            
            // Sombra del diálogo
            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 8
                radius: parent.radius
                color: "black"
                opacity: 0.2
                z: -1
            }
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: marginLarge
                spacing: marginMedium
                
                Label {
                    Layout.fillWidth: true
                    text: "Cambiar Contraseña"
                    font.pixelSize: fontTitle
                    font.bold: true
                    color: textColor
                    horizontalAlignment: Text.AlignHCenter
                    font.family: "Segoe UI"
                }
                
                Label {
                    Layout.fillWidth: true
                    text: "Introduce tu contraseña actual y establece una nueva contraseña segura."
                    wrapMode: Text.WordWrap
                    color: textSecondaryColor
                    font.pixelSize: fontBase
                    font.family: "Segoe UI"
                }
                
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: marginMedium
                    
                    PasswordField { 
                        id: currentPasswordField
                        label: "Contraseña Actual"
                        placeholder: "Contraseña actual"
                    }
                    
                    PasswordField { 
                        id: newPasswordField
                        label: "Nueva Contraseña"
                        placeholder: "Mínimo 8 caracteres"
                    }
                    
                    PasswordField { 
                        id: confirmPasswordField
                        label: "Confirmar Nueva Contraseña"
                        placeholder: "Confirma la nueva contraseña"
                    }
                }
                
                Item { Layout.fillHeight: true }
                
                RowLayout {
                    Layout.fillWidth: true
                    spacing: marginMedium
                    
                    Item { Layout.fillWidth: true }
                    
                    Button {
                        text: "Cancelar"
                        Layout.preferredHeight: baseUnit * 5
                        
                        background: Rectangle {
                            color: parent.pressed ? Qt.darker(surfaceColor, 1.1) : surfaceColor
                            radius: radiusSmall
                            border.color: borderColor
                            border.width: 1
                        }
                        
                        contentItem: Label {
                            text: parent.text
                            color: textColor
                            font.pixelSize: fontBase
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.family: "Segoe UI"
                        }
                        
                        onClicked: {
                            currentPasswordField.clear()
                            newPasswordField.clear()
                            confirmPasswordField.clear()
                            closed()
                        }
                    }
                    
                    Button {
                        text: "Actualizar"
                        Layout.preferredHeight: baseUnit * 5
                        enabled: currentPasswordField.isValid && 
                                newPasswordField.isValid && 
                                confirmPasswordField.isValid &&
                                newPasswordField.text === confirmPasswordField.text
                        
                        background: Rectangle {
                            color: parent.enabled ? 
                                   (parent.pressed ? Qt.darker(successColor, 1.2) : successColor) :
                                   Qt.lighter(successColor, 1.5)
                            radius: radiusSmall
                        }
                        
                        contentItem: Label {
                            text: parent.text
                            color: backgroundColor
                            font.bold: true
                            font.pixelSize: fontBase
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.family: "Segoe UI"
                        }
                        
                        onClicked: {
                            currentPasswordField.clear()
                            newPasswordField.clear()
                            confirmPasswordField.clear()
                            passwordChanged()
                        }
                    }
                }
            }
        }
    }
    
    component PasswordField: ColumnLayout {
        property string label: ""
        property string placeholder: ""
        property alias text: textField.text
        property bool isValid: text.length >= (label.includes("Nueva") ? 8 : 1)
        
        function clear() { textField.text = "" }
        
        spacing: marginSmall
        Layout.fillWidth: true
        
        Label {
            text: label
            color: textColor
            font.pixelSize: fontBase
            font.bold: true
            font.family: "Segoe UI"
        }
        
        TextField {
            id: textField
            Layout.fillWidth: true
            Layout.preferredHeight: baseUnit * 5
            placeholderText: placeholder
            echoMode: TextInput.Password
            font.pixelSize: fontBase
            font.family: "Segoe UI"
            
            background: Rectangle {
                color: backgroundColor
                border.color: borderColor
                border.width: 1
                radius: radiusSmall
            }
        }
    }
    
    component NotificationBanner: Rectangle {
        id: banner
        height: 0
        color: backgroundColor
        radius: radiusMedium
        border.color: borderColor
        border.width: 1
        clip: true
        
        // Sombra del banner
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 2
            radius: parent.radius
            color: "black"
            opacity: 0.1
            z: -1
        }
        
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
            anchors.margins: marginMedium
            spacing: marginMedium
            
            Rectangle {
                Layout.preferredWidth: baseUnit * 4
                Layout.preferredHeight: baseUnit * 4
                radius: baseUnit * 2
                color: notificationType === "success" ? successColor : primaryColor
                
                Label {
                    anchors.centerIn: parent
                    text: notificationType === "success" ? "✓" : "i"
                    font.pixelSize: fontBase
                    font.bold: true
                    color: backgroundColor
                }
            }
            
            ColumnLayout {
                Layout.fillWidth: true
                spacing: marginTiny
                
                Label {
                    text: notificationTitle
                    font.bold: true
                    font.pixelSize: fontBase
                    color: textColor
                    font.family: "Segoe UI"
                }
                
                Label {
                    text: notificationMessage
                    font.pixelSize: fontSmall
                    color: textSecondaryColor
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    font.family: "Segoe UI"
                }
            }
            
            Button {
                Layout.preferredWidth: baseUnit * 3
                Layout.preferredHeight: baseUnit * 3
                
                background: Rectangle {
                    color: "transparent"
                    radius: baseUnit * 1.5
                }
                
                contentItem: Label {
                    text: "×"
                    font.pixelSize: fontBase
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
            to: baseUnit * 8
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
    
    // ===== COMPONENTES DE CONFIGURACIÓN ESPECÍFICA =====
    
    // ===== COMPONENTE DE LABORATORIO CON ConfiLaboratorio =====
    Component {
        id: laboratorioConfigComponent
        GenericConfigView {
            moduleId: "laboratorio"
            moduleTitle: "Laboratorio"
            moduleIcon: "🧪"
            moduleColor: laboratorioColor
            
            configContent: Item {
                anchors.fill: parent
                
                // ===== INSTANCIAR EL COMPONENTE ConfiLaboratorio =====
                ConfiLaboratorio {
                    id: configLaboratorioComponent
                    anchors.fill: parent
                    anchors.margins: marginMedium
                    
                    // ===== CONECTAR EL ALIAS A LA PROPIEDAD DEL ROOT =====
                    tiposAnalisis: configuracionRoot.tiposAnalisisModel
                    
                    // ===== PROPAGACIÓN DE CAMBIOS DE VUELTA AL MODELO PADRE =====
                    onTiposAnalisisChanged: {
                        if (tiposAnalisis && tiposAnalisis !== configuracionRoot.tiposAnalisisModel) {
                            configuracionRoot.tiposAnalisisModel = tiposAnalisis
                            console.log("🔄 Tipos de análisis actualizados hacia el modelo padre")
                        }
                    }
                }
            }
        }
    }
    
    Component {
        id: enfermeriaConfigComponent
        GenericConfigView {
            moduleId: "enfermeria"
            moduleTitle: "Enfermería"
            moduleIcon: "💉"
            moduleColor: enfermeriaColor
            
            configContent: Item {
                anchors.fill: parent
                
                // ===== INSTANCIAR EL COMPONENTE ConfiEnfermeria =====
                ConfiEnfermeria {
                    id: configEnfermeriaComponent
                    anchors.fill: parent
                    anchors.margins: marginMedium
                    
                    // ===== CONECTAR CON EL NOMBRE CORRECTO =====
                    tiposProcedimientosData: configuracionRoot.tiposProcedimientosModel
                    
                    // ===== CONECTAR AL EVENTO CORRECTO =====
                    onTiposProcedimientosChanged: {
                        if (tiposProcedimientos && tiposProcedimientos !== configuracionRoot.tiposProcedimientosModel) {
                            configuracionRoot.tiposProcedimientosModel = tiposProcedimientos
                            console.log("🔄 Tipos de procedimientos actualizados hacia el modelo padre")
                        }
                    }
                }
            }
        }
    }
    
    // ===== COMPONENTE DE CONSULTAS MODIFICADO =====
    Component {
        id: consultasConfigComponent
        GenericConfigView {
            moduleId: "consultas"
            moduleTitle: "Consultas"
            moduleIcon: "🩺"
            moduleColor: consultasColor
            
            configContent: Item {
                anchors.fill: parent
                
                // ===== INSTANCIAR EL NUEVO COMPONENTE ConfiConsultas =====
                ConfiConsultas {
                    id: configConsultasComponent
                    anchors.fill: parent
                    anchors.margins: marginMedium
                    
                    // ===== CONECTAR EL ALIAS A LA PROPIEDAD DEL ROOT =====
                    especialidades: configuracionRoot.especialidadesModel
                    
                    // ===== PROPAGACIÓN DE CAMBIOS DE VUELTA AL MODELO PADRE =====
                    onEspecialidadesChanged: {
                        if (especialidades && especialidades !== configuracionRoot.especialidadesModel) {
                            configuracionRoot.especialidadesModel = especialidades
                            console.log("🔄 Especialidades actualizadas hacia el modelo padre")
                        }
                    }
                }
            }
        }
    }
    
    // ===== NUEVO COMPONENTE DE SERVICIOS BÁSICOS =====
    Component {
        id: serviciosConfigComponent
        GenericConfigView {
            moduleId: "servicios"
            moduleTitle: "Servicios Básicos"
            moduleIcon: "💰"
            moduleColor: serviciosColor
            
            configContent: Item {
                anchors.fill: parent
                
                // ===== INSTANCIAR EL NUEVO COMPONENTE ConfiServiciosBasicos =====
                ConfiServiciosBasicos {
                    id: configServiciosBasicosComponent
                    anchors.fill: parent
                    anchors.margins: marginMedium
                    
                    // ===== CONECTAR EL ALIAS A LA PROPIEDAD DEL ROOT =====
                    tiposGastos: configuracionRoot.tiposGastosModel
                    
                    // ===== PROPAGACIÓN DE CAMBIOS DE VUELTA AL MODELO PADRE =====
                    onTiposGastosChanged: {
                        if (tiposGastos && tiposGastos !== configuracionRoot.tiposGastosModel) {
                            configuracionRoot.tiposGastosModel = tiposGastos
                            console.log("🔄 Tipos de gastos actualizados hacia el modelo padre")
                        }
                    }
                }
            }
        }
    }
    
    // ===== COMPONENTE DE USUARIOS MODIFICADO (SIN GenericConfigView) =====
    Component {
        id: usuariosConfigComponent
        ConfiUsuarios {
            anchors.fill: parent
            
            // Conectar la señal de volver a la función del parent
            onBackToMain: changeView("main")
        }
    }
    
    // ===== PASO 2c: COMPONENTE DE PERSONAL MODIFICADO CON ConfiTrabajadores =====
    Component {
        id: personalConfigComponent
        GenericConfigView {
            moduleId: "personal"
            moduleTitle: "Personal"
            moduleIcon: "👥"
            moduleColor: personalColor
            
            configContent: Item {
                anchors.fill: parent
                
                // ===== PASO 2c: INSTANCIAR EL NUEVO COMPONENTE ConfiTrabajadores =====
                ConfiTrabajadores {
                    id: configTrabajadoresComponent
                    anchors.fill: parent
                    anchors.margins: marginMedium
                    
                    // ===== PASO 2d: CONECTAR EL ALIAS A LA PROPIEDAD DEL ROOT =====
                    tiposTrabajadores: configuracionRoot.tiposTrabajadoresModel
                    
                    // ===== PASO 2e: PROPAGACIÓN DE CAMBIOS DE VUELTA AL MODELO PADRE =====
                    onTiposTrabajadoresChanged: {
                        if (tiposTrabajadores && tiposTrabajadores !== configuracionRoot.tiposTrabajadoresModel) {
                            configuracionRoot.tiposTrabajadoresModel = tiposTrabajadores
                            console.log("🔄 Tipos de trabajadores actualizados hacia el modelo padre")
                        }
                    }
                }
            }
        }
    }
    
    component GenericConfigView: Rectangle {
        property string moduleId: ""
        property string moduleTitle: ""
        property string moduleIcon: ""
        property string moduleColor: primaryColor
        property Component configContent
        
        color: surfaceColor
        
        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            
            // Header con navegación
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(80, baseUnit * 10)
                color: moduleColor
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: marginLarge
                    spacing: marginMedium
                    
                    Button {
                        Layout.preferredWidth: baseUnit * 5
                        Layout.preferredHeight: baseUnit * 5
                        text: "←"
                        
                        background: Rectangle {
                            color: backgroundColor
                            radius: radiusSmall
                        }
                        
                        contentItem: Label {
                            text: parent.text
                            color: moduleColor
                            font.pixelSize: fontMedium
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: changeView("main")
                    }
                    
                    Rectangle {
                        Layout.preferredWidth: baseUnit * 6
                        Layout.preferredHeight: baseUnit * 6
                        color: backgroundColor
                        radius: baseUnit * 3
                        
                        Label {
                            anchors.centerIn: parent
                            text: moduleIcon
                            font.pixelSize: fontLarge
                        }
                    }
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: marginTiny
                        
                        Label {
                            text: "Configuraciones de " + moduleTitle
                            color: backgroundColor
                            font.pixelSize: fontLarge
                            font.bold: true
                            font.family: "Segoe UI"
                        }
                        
                        Label {
                            text: "Gestiona las configuraciones específicas de este módulo"
                            color: backgroundColor
                            font.pixelSize: fontBase
                            opacity: 0.9
                            font.family: "Segoe UI"
                        }
                    }
                }
            }
            
            // Contenido específico del módulo
            Loader {
                Layout.fillWidth: true
                Layout.fillHeight: true
                sourceComponent: configContent
            }
        }
    }
    
    // ===== IMPORTAR LOS COMPONENTES DE CONFIGURACIÓN =====
    ConfiConsultas {
        id: hiddenConfiConsultas
        visible: false
        // Componente oculto solo para cargar el tipo en memoria
    }
    
    ConfiServiciosBasicos {
        id: hiddenConfiServiciosBasicos
        visible: false
        // Componente oculto solo para cargar el tipo en memoria
    }
    
    ConfiEnfermeria {
        id: hiddenConfiEnfermeria
        visible: false
        // Componente oculto solo para cargar el tipo en memoria
    }
    
    // ===== IMPORTAR EL COMPONENTE ConfiLaboratorio =====
    ConfiLaboratorio {
        id: hiddenConfiLaboratorio
        visible: false
        // Componente oculto solo para cargar el tipo en memoria
    }
    
    // ===== PASO 2a: IMPORTAR EL NUEVO COMPONENTE ConfiTrabajadores =====
    ConfiTrabajadores {
        id: hiddenConfiTrabajadores
        visible: false
        // Componente oculto solo para cargar el tipo en memoria
    }
    
    // ===== IMPORTAR EL NUEVO COMPONENTE ConfiUsuarios =====
    ConfiUsuarios {
        id: hiddenConfiUsuarios
        visible: false
        // Componente oculto solo para cargar el tipo en memoria
    }
}