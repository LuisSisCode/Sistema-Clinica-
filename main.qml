import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15
import QtQml 2.15

ApplicationWindow {
    id: mainWindow
    objectName: "mainWindow"
    
    // TAMAÑOS ADAPTATIVOS EN LUGAR DE FIJOS
    minimumWidth: Screen.width * 0.6   // Mínimo 60% del ancho de pantalla
    minimumHeight: Screen.height * 0.7 // Mínimo 70% del alto de pantalla
    width: Screen.width * 0.85         // Por defecto 85% del ancho
    height: Screen.height * 0.9        // Por defecto 90% del alto
    
    visible: true
    title: "Sistema de Gestión Médica - Clínica Maria Inmaculada"
    
    // SISTEMA DE ESCALADO RESPONSIVO
    readonly property real scaleFactor: Math.min(width / 1400, height / 900)
    readonly property real baseUnit: Math.max(8, Screen.height / 100) // Unidad base escalable
    readonly property real fontBaseSize: Math.max(12, Screen.height / 70) // Tamaño base de fuente
    
    // COLORES (mantener como están)
    readonly property color primaryColor: "#273746"  
    readonly property color primaryDarkColor: "#34495E"
    readonly property color successColor: "#27ae60"
    readonly property color dangerColor: "#E74C3C"
    readonly property color warningColor: "#f39c12"
    readonly property color lightGrayColor: "#ECF0F1"
    readonly property color darkGrayColor: "#7f8c8d"
    readonly property color textColor: "#2c3e50"
    readonly property color whiteColor: "#FFFFFF"
    
    // PROPIEDADES DE ESTADO (mantener)
    property bool drawerOpen: true
    property int currentIndex: 0
    property bool farmaciaExpanded: false
    property int farmaciaSubsection: 0
    
    // PROPIEDADES DE NOTIFICACIONES (mantener)
    property bool notificationPanelOpen: false
    property var notificaciones: []
    property int totalNotificaciones: 0
    property var fechaActual: new Date()
    
    Universal.theme: Universal.Light
    Universal.accent: primaryColor
    Universal.background: lightGrayColor
    Universal.foreground: textColor
    
    // HEADER ADAPTATIVO
    header: ToolBar {
        objectName: "mainToolBar"
        height: Math.max(60, baseUnit * 8) // Altura escalable con mínimo
        
        background: Rectangle {
            gradient: Gradient {
                GradientStop { position: 0.0; color: primaryDarkColor }
                GradientStop { position: 1.0; color: primaryColor }
            }
            border.color: "#20000000"
            border.width: 1
        }
        
        RowLayout {
            anchors.fill: parent
            anchors.margins: baseUnit * 2
            spacing: baseUnit * 2
            
            // BOTÓN DE MENÚ ADAPTATIVO
            RoundButton {
                objectName: "menuToggleButton"
                Layout.preferredWidth: baseUnit * 5
                Layout.preferredHeight: baseUnit * 5
                text: "☰"
                
                background: Rectangle {
                    color: whiteColor
                    radius: baseUnit
                }
                
                contentItem: Label {
                    text: parent.text
                    color: primaryColor
                    font.bold: true
                    font.pixelSize: fontBaseSize * 1.2
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: {
                    drawerOpen = !drawerOpen
                    drawer.visible = drawerOpen
                }
            }
            
            // BREADCRUMB ADAPTATIVO
            RowLayout {
                spacing: baseUnit
                
                Label {
                    text: "🏠"
                    color: whiteColor
                    font.pixelSize: fontBaseSize
                }
                
                Label {
                    text: "Clínica María Inmaculada"
                    color: whiteColor
                    font.pixelSize: fontBaseSize * 0.9
                    // En pantallas pequeñas, acortar el texto
                    visible: parent.parent.width > 600
                }
                
                Label {
                    text: ">"
                    color: whiteColor
                    font.pixelSize: fontBaseSize * 0.8
                    visible: parent.parent.width > 600
                }
                
                Label {
                    objectName: "currentPageLabel"
                    text: getCurrentPageName()
                    color: whiteColor
                    font.bold: true
                    font.pixelSize: fontBaseSize * 0.9
                }
            }
            
            Item { Layout.fillWidth: true }
            
            // BOTÓN DE NOTIFICACIONES ADAPTATIVO
            RoundButton {
                id: notificationButton
                objectName: "notificationButton"
                Layout.preferredWidth: baseUnit * 5
                Layout.preferredHeight: baseUnit * 5
                text: "🔔"
                
                background: Rectangle {
                    color: notificationButton.pressed ? Qt.darker(whiteColor, 1.1) : whiteColor
                    radius: baseUnit
                    border.color: totalNotificaciones > 0 ? dangerColor : "transparent"
                    border.width: totalNotificaciones > 0 ? 2 : 0
                    
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                }
                
                contentItem: Label {
                    text: parent.text
                    color: primaryColor
                    font.pixelSize: fontBaseSize * 1.1
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    
                    SequentialAnimation on scale {
                        running: totalNotificaciones > 0
                        loops: Animation.Infinite
                        NumberAnimation { to: 1.1; duration: 800 }
                        NumberAnimation { to: 1.0; duration: 800 }
                    }
                }
                
                // Badge adaptativo
                Rectangle {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: -baseUnit * 0.25
                    width: baseUnit * 2.5
                    height: baseUnit * 2.5
                    color: totalNotificaciones > 0 ? dangerColor : "transparent"
                    radius: baseUnit * 1.25
                    visible: totalNotificaciones > 0
                    
                    Label {
                        anchors.centerIn: parent
                        text: totalNotificaciones > 99 ? "99+" : totalNotificaciones.toString()
                        color: whiteColor
                        font.pixelSize: totalNotificaciones > 99 ? fontBaseSize * 0.6 : fontBaseSize * 0.8
                        font.bold: true
                    }
                    
                    Behavior on opacity { NumberAnimation { duration: 300 } }
                }
                
                onClicked: {
                    actualizarNotificaciones()
                    notificationPanelOpen = !notificationPanelOpen
                }
            }
            
            // PERFIL DE USUARIO ADAPTATIVO
            Rectangle {
                Layout.preferredWidth: Math.max(150, width * 0.15) // Adaptativo con mínimo
                Layout.preferredHeight: baseUnit * 6
                color: whiteColor
                radius: baseUnit * 1.5
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: baseUnit * 0.8
                    spacing: baseUnit
                    
                    Rectangle {
                        Layout.preferredWidth: baseUnit * 4.5
                        Layout.preferredHeight: baseUnit * 4.5
                        color: primaryColor
                        radius: baseUnit * 2.25
                        
                        Label {
                            anchors.centerIn: parent
                            text: "AM"
                            color: whiteColor
                            font.bold: true
                            font.pixelSize: fontBaseSize
                        }
                    }
                    
                    Column {
                        Layout.fillWidth: true
                        spacing: baseUnit * 0.25
                        visible: parent.parent.width > 120 // Ocultar texto en espacios muy pequeños
                        
                        Label {
                            text: "Dr. Admin"
                            color: textColor
                            font.bold: true
                            font.pixelSize: fontBaseSize * 0.9
                        }
                        
                        Label {
                            text: "Administrador"
                            color: darkGrayColor
                            font.pixelSize: fontBaseSize * 0.7
                        }
                    }
                    
                    Label {
                        text: "▼"
                        color: darkGrayColor
                        font.pixelSize: fontBaseSize * 0.8
                        visible: parent.parent.width > 120
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        Qt.callLater(function() {
                            appController.showNotification("Usuario", "Menú de usuario - Próximamente")
                        })
                    }
                }
            }
        }
    }
    
    // PANEL DE NOTIFICACIONES ADAPTATIVO
    Rectangle {
        id: notificationOverlay
        anchors.fill: parent
        color: "#80000000"
        visible: notificationPanelOpen
        opacity: notificationPanelOpen ? 1.0 : 0.0
        z: 1000
        
        Behavior on opacity { NumberAnimation { duration: 300 } }
        
        MouseArea {
            anchors.fill: parent
            onClicked: { notificationPanelOpen = false }
        }
        
        // Panel adaptativo
        Rectangle {
            id: notificationPanel
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            
            // ANCHO ADAPTATIVO: 400px en pantallas grandes, 80% en pequeñas, máximo 90%
            width: Math.min(
                Math.max(300, parent.width * 0.3),  // Mínimo 300px o 30%
                Math.min(420, parent.width * 0.9)   // Máximo 420px o 90%
            )
            
            color: whiteColor
            
            transform: Translate {
                x: notificationPanelOpen ? 0 : notificationPanel.width
                Behavior on x {
                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                }
            }
            
            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: -baseUnit
                color: "transparent"
                border.color: "#20000000"
                border.width: baseUnit
                radius: baseUnit
                z: -1
            }
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                
                // Header adaptativo
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(60, baseUnit * 8)
                    color: primaryColor
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: baseUnit * 2
                        spacing: baseUnit * 1.5
                        
                        Rectangle {
                            width: baseUnit * 4
                            height: baseUnit * 4
                            color: whiteColor
                            radius: baseUnit * 2
                            
                            Label {
                                anchors.centerIn: parent
                                text: "🔔"
                                font.pixelSize: fontBaseSize * 1.3
                            }
                        }
                        
                        ColumnLayout {
                            spacing: baseUnit * 0.5
                            
                            Label {
                                text: "Centro de Notificaciones"
                                color: whiteColor
                                font.bold: true
                                font.pixelSize: fontBaseSize * 1.2
                            }
                            
                            Label {
                                text: totalNotificaciones + " alertas activas"
                                color: "#E8F4FD"
                                font.pixelSize: fontBaseSize * 0.8
                            }
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        Button {
                            width: baseUnit * 3.5
                            height: baseUnit * 3.5
                            
                            background: Rectangle {
                                color: parent.pressed ? "#40FFFFFF" : "transparent"
                                radius: baseUnit * 1.75
                            }
                            
                            contentItem: Label {
                                text: "×"
                                color: whiteColor
                                font.pixelSize: fontBaseSize * 1.3
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: { notificationPanelOpen = false }
                        }
                    }
                }
                
                // Filtros adaptativos
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: baseUnit * 6
                    color: "#F8F9FA"
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: baseUnit * 1.5
                        spacing: baseUnit
                        
                        Button {
                            text: "🔄 Actualizar"
                            Layout.preferredHeight: baseUnit * 3.5
                            
                            background: Rectangle {
                                color: parent.pressed ? Qt.darker(primaryColor, 1.2) : primaryColor
                                radius: baseUnit * 0.6
                            }
                            
                            contentItem: Label {
                                text: parent.text
                                color: whiteColor
                                font.pixelSize: fontBaseSize * 0.8
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: { actualizarNotificaciones() }
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        Label {
                            text: Qt.formatDateTime(fechaActual, "dd/MM/yyyy hh:mm")
                            color: darkGrayColor
                            font.pixelSize: fontBaseSize * 0.7
                        }
                    }
                }
                
                // Lista de notificaciones
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    
                    ListView {
                        id: notificationsList
                        model: ListModel { id: notificacionesModel }
                        spacing: 0
                        
                        delegate: Rectangle {
                            width: notificationsList.width
                            height: Math.max(baseUnit * 8, contentColumn.implicitHeight + baseUnit * 2)
                            color: index % 2 === 0 ? "#FFFFFF" : "#F8F9FA"
                            border.color: "#E5E7EB"
                            border.width: 1
                            
                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: baseUnit * 0.5
                                color: getPrioridadColor(model.prioridad)
                            }
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: baseUnit * 1.5
                                anchors.leftMargin: baseUnit * 2
                                spacing: baseUnit
                                
                                Rectangle {
                                    width: baseUnit * 3.5
                                    height: baseUnit * 3.5
                                    color: getPrioridadColor(model.prioridad)
                                    radius: baseUnit * 1.75
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: model.icono
                                        color: whiteColor
                                        font.pixelSize: fontBaseSize
                                        font.bold: true
                                    }
                                }
                                
                                ColumnLayout {
                                    id: contentColumn
                                    Layout.fillWidth: true
                                    spacing: baseUnit * 0.5
                                    
                                    Label {
                                        text: model.titulo
                                        color: textColor
                                        font.bold: true
                                        font.pixelSize: fontBaseSize * 0.9
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }
                                    
                                    Label {
                                        text: model.mensaje
                                        color: darkGrayColor
                                        font.pixelSize: fontBaseSize * 0.8
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }
                                    
                                    Label {
                                        text: model.tiempo
                                        color: "#9CA3AF"
                                        font.pixelSize: fontBaseSize * 0.7
                                    }
                                }
                                
                                Button {
                                    visible: model.modulo === "farmacia" && currentIndex !== 1
                                    text: "Ver"
                                    Layout.preferredWidth: baseUnit * 5
                                    Layout.preferredHeight: baseUnit * 3
                                    
                                    background: Rectangle {
                                        color: parent.pressed ? Qt.darker(primaryColor, 1.2) : primaryColor
                                        radius: baseUnit * 0.5
                                    }
                                    
                                    contentItem: Label {
                                        text: parent.text
                                        color: whiteColor
                                        font.pixelSize: fontBaseSize * 0.7
                                        font.bold: true
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    
                                    onClicked: {
                                        notificationPanelOpen = false
                                        farmaciaExpanded = true
                                        farmaciaSubsection = 1
                                        switchToPage(1)
                                    }
                                }
                            }
                        }
                        
                        // Estado vacío
                        Item {
                            anchors.centerIn: parent
                            visible: notificacionesModel.count === 0
                            width: baseUnit * 20
                            height: baseUnit * 15
                            
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: baseUnit * 1.5
                                
                                Label {
                                    text: "🎉"
                                    font.pixelSize: fontBaseSize * 3
                                    color: successColor
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                
                                Label {
                                    text: "¡Todo en orden!"
                                    color: textColor
                                    font.bold: true
                                    font.pixelSize: fontBaseSize * 1.1
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                
                                Label {
                                    text: "No hay alertas pendientes en este momento."
                                    color: darkGrayColor
                                    font.pixelSize: fontBaseSize * 0.8
                                    Layout.alignment: Qt.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    Layout.maximumWidth: baseUnit * 18
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }
                    }
                }
                
                // Footer adaptativo
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: baseUnit * 5
                    color: "#F1F5F9"
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: baseUnit * 1.5
                        spacing: baseUnit * 1.5
                        
                        Label {
                            text: "📊 Resumen:"
                            color: darkGrayColor
                            font.pixelSize: fontBaseSize * 0.7
                            font.bold: true
                        }
                        
                        Label {
                            text: getConteoNotificaciones("critica") + " críticas"
                            color: dangerColor
                            font.pixelSize: fontBaseSize * 0.7
                            font.bold: true
                        }
                        
                        Label {
                            text: getConteoNotificaciones("alta") + " importantes"
                            color: warningColor
                            font.pixelSize: fontBaseSize * 0.7
                            font.bold: true
                        }
                        
                        Label {
                            text: getConteoNotificaciones("media") + " normales"
                            color: primaryColor
                            font.pixelSize: fontBaseSize * 0.7
                            font.bold: true
                        }
                        
                        Item { Layout.fillWidth: true }
                    }
                }
            }
        }
    }
    
    // ESTRUCTURA PRINCIPAL ADAPTATIVA
    RowLayout {
        anchors.fill: parent
        spacing: 0
        
        // DRAWER LATERAL ADAPTATIVO
        Rectangle {
            id: drawer
            objectName: "navigationDrawer"
            
            // ANCHO ADAPTATIVO DEL DRAWER
            Layout.preferredWidth: drawerOpen ? Math.max(280, width * 0.22) : 0
            Layout.fillHeight: true
            visible: drawerOpen
            layer.enabled: true
            
            // Comportamiento responsive: colapsar automáticamente en pantallas pequeñas
            readonly property bool autoCollapse: mainWindow.width < 1000
            
            Behavior on Layout.preferredWidth {
                NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
            }
            
            gradient: Gradient {
                GradientStop { position: 0.0; color: primaryDarkColor }
                GradientStop { position: 1.0; color: primaryColor }
            }
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                
                // Logo adaptativo
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: baseUnit * 12
                    color: "transparent"
                    border.color: "#20FFFFFF"
                    border.width: 1
                    
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: baseUnit * 1.5
                        
                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter  
                            Image {
                                anchors.centerIn: parent
                                source: "iconos/logo_CMI.svg"
                                width: Math.min(150, drawer.width * 0.8)
                                height: Math.min(200, baseUnit * 20)
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }
                        }
                    }                    
                }
                
                // Navegación adaptativa
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    
                    ColumnLayout {
                        width: drawer.width
                        spacing: 0
                        
                        NavSection {
                            title: "PRINCIPAL"
                            
                            NavItem {
                                id: navItem0
                                text: "VISTA GENERAL"
                                icon: "🏠"
                                active: currentIndex === 0
                                onClicked: switchToPage(0)
                            }
                            
                            NavItemWithSubmenu {
                                id: navItem1
                                text: "FARMACIA"
                                icon: "💊"
                                active: currentIndex === 1
                                expanded: farmaciaExpanded
                                
                                onMainClicked: {
                                    farmaciaExpanded = !farmaciaExpanded
                                    if (!farmaciaExpanded) {
                                        switchToPage(1)
                                    }
                                }
                                
                                submenuItems: [
                                    { text: "Ventas", icon: "💰", subsection: 0 },
                                    { text: "Productos", icon: "📦", subsection: 1 },
                                    { text: "Compras", icon: "🚚", subsection: 2 }
                                ]
                                
                                onSubmenuClicked: function(subsection) {
                                    farmaciaSubsection = subsection
                                    switchToPage(1)
                                }
                            }
                            
                            NavItem {
                                id: navItem2
                                text: "CONSULTAS"
                                icon: "🩺"
                                active: currentIndex === 2
                                onClicked: switchToPage(2)
                            }
                            
                            NavItem {
                                id: navItem3
                                text: "LABORATORIO"
                                icon: "🧪"
                                active: currentIndex === 3
                                onClicked: switchToPage(3)
                            }
                            
                            NavItem {
                                id: navItem4
                                text: "ENFERMERÍA"
                                icon: "💉"
                                active: currentIndex === 4
                                onClicked: switchToPage(4)
                            }
                        }
                        
                        NavSection {
                            title: "SERVICIOS"
                            
                            NavItem {
                                id: navItem5
                                text: "SERVICIOS BÁSICOS"
                                icon: "📊"
                                active: currentIndex === 5
                                onClicked: switchToPage(5)
                            }
                            
                            NavItem {
                                id: navItem6
                                text: "USUARIOS"
                                icon: "👤"
                                active: currentIndex === 6
                                onClicked: switchToPage(6)
                            }
                            
                            NavItem {
                                id: navItem7
                                text: "PERSONAL"
                                icon: "👥"
                                active: currentIndex === 7
                                onClicked: switchToPage(7)
                            }
                            
                            NavItem {
                                id: navItem8
                                text: "REPORTES"
                                icon: "📈"
                                active: currentIndex === 8
                                onClicked: switchToPage(8)
                            }
                        }
                        
                        NavSection {
                            title: "SISTEMA"
                            
                            NavItem {
                                id: navItem9
                                text: "CONFIGURACIÓN"
                                icon: "⚙️"
                                active: currentIndex === 9
                                onClicked: switchToPage(9)
                            }
                        }
                    }
                }
            }
            
            // Auto-colapsar en pantallas pequeñas
            onAutoCollapseChanged: {
                if (autoCollapse && drawerOpen) {
                    drawerOpen = false
                }
            }
        }
        
        // ===== ÁREA DE CONTENIDO PRINCIPAL CON NUEVAS CONEXIONES =====
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            
            // Dashboard Page
            Dashboard {
                id: dashboardPage
                objectName: "dashboardPage"
                anchors.fill: parent
                visible: currentIndex === 0
                layer.enabled: true
            }
            
            // Farmacia Page  
            Farmacia {
                id: farmaciaPage
                objectName: "farmaciaPage"
                anchors.fill: parent
                visible: currentIndex === 1
                layer.enabled: true
            }
            
            // ===== CONSULTAS PAGE CON NUEVA CONEXIÓN DE SEÑAL =====
            Consultas {
                id: consultasPage
                objectName: "consultasPage"
                anchors.fill: parent
                visible: currentIndex === 2
                layer.enabled: true
                
                // ===== NUEVA CONEXIÓN PARA ORQUESTAR NAVEGACIÓN =====
                onIrAConfiguracion: {
                    console.log("🚀 Señal irAConfiguracion recibida desde Consultas")
                    
                    // ===== PASO 4a: OBTENER MODELO DE DATOS DESDE CONSULTAS =====
                    var especialidadesData = consultasPage.especialidades
                    console.log("📊 Datos de especialidades obtenidos:", JSON.stringify(especialidadesData))
                    
                    // ===== PASO 4b: ASIGNAR DATOS AL MÓDULO CONFIGURACIÓN =====
                    configuracionPage.especialidadesModel = especialidadesData
                    console.log("📤 Datos transferidos a configuracionPage.especialidadesModel")
                    
                    // ===== PASO 4c: CAMBIAR VISTA INTERNA DE CONFIGURACIÓN =====
                    configuracionPage.changeView("consultas")
                    console.log("🔄 Vista de configuración cambiada a: consultas")
                    
                    // ===== PASO 4d: CAMBIAR VISTA PRINCIPAL A CONFIGURACIÓN =====
                    switchToPage(9)
                    console.log("🎯 Navegación completada hacia módulo Configuración")
                }
            }
            
            // Laboratorio Page
            Laboratorio {
                id: laboratorioPage
                objectName: "laboratorioPage"
                anchors.fill: parent
                visible: currentIndex === 3
                layer.enabled: true
            }
            
            // Enfermería Page
            Enfermeria {
                id: enfermeriaPage
                objectName: "enfermeriaPage"
                anchors.fill: parent
                visible: currentIndex === 4
                layer.enabled: true
                
                // ===== NUEVA CONEXIÓN PARA ORQUESTAR NAVEGACIÓN =====
                onIrAConfigEnfermeria: {
                    console.log("🚀 Señal irAConfigEnfermeria recibida desde Enfermería")
                    
                    // ===== PASO 4a: OBTENER MODELO DE DATOS DESDE ENFERMERÍA =====
                    var tiposProcedimientosData = enfermeriaPage.tiposProcedimientos
                    console.log("📊 Datos de tipos de procedimientos obtenidos:", JSON.stringify(tiposProcedimientosData))
                    
                    // ===== PASO 4b: ASIGNAR DATOS AL MÓDULO CONFIGURACIÓN =====
                    configuracionPage.tiposProcedimientosModel = tiposProcedimientosData
                    console.log("📤 Datos transferidos a configuracionPage.tiposProcedimientosModel")
                    
                    // ===== PASO 4c: CAMBIAR VISTA INTERNA DE CONFIGURACIÓN =====
                    configuracionPage.changeView("enfermeria")
                    console.log("🔄 Vista de configuración cambiada a: enfermeria")
                    
                    // ===== PASO 4d: CAMBIAR VISTA PRINCIPAL A CONFIGURACIÓN =====
                    switchToPage(9)
                    console.log("🎯 Navegación completada hacia módulo Configuración - Enfermería")
                }            
            }   
            
            // ===== SERVICIOS BÁSICOS PAGE CON NUEVA CONEXIÓN DE SEÑAL =====
            ServiciosBasicos {
                id: serviciosPage
                objectName: "serviciosPage"
                anchors.fill: parent
                visible: currentIndex === 5
                layer.enabled: true
                
                // ===== NUEVA CONEXIÓN PARA ORQUESTAR NAVEGACIÓN A CONFIGURACIÓN =====
                onIrAConfigServiciosBasicos: {
                    console.log("🚀 Señal irAConfigServiciosBasicos recibida desde ServiciosBasicos")
                    
                    // ===== PASO 4a: OBTENER MODELO DE DATOS DESDE SERVICIOS BÁSICOS =====
                    var tiposGastosData = []
                    
                    // Convertir ListModel a Array para transferencia
                    for (var i = 0; i < serviciosPage.tiposGastosModel.count; i++) {
                        var item = serviciosPage.tiposGastosModel.get(i)
                        tiposGastosData.push({
                            nombre: item.nombre,
                            descripcion: item.descripcion,
                            ejemplos: item.ejemplos,
                            color: item.color
                        })
                    }
                    
                    console.log("📊 Datos de tipos de gastos obtenidos:", JSON.stringify(tiposGastosData))
                    
                    // ===== PASO 4b: ASIGNAR DATOS AL MÓDULO CONFIGURACIÓN =====
                    configuracionPage.tiposGastosModel = tiposGastosData
                    console.log("📤 Datos transferidos a configuracionPage.tiposGastosModel")
                    
                    // ===== PASO 4c: CAMBIAR VISTA INTERNA DE CONFIGURACIÓN =====
                    configuracionPage.changeView("servicios")
                    console.log("🔄 Vista de configuración cambiada a: servicios")
                    
                    // ===== PASO 4d: CAMBIAR VISTA PRINCIPAL A CONFIGURACIÓN =====
                    switchToPage(9)
                    console.log("🎯 Navegación completada hacia módulo Configuración")
                }
            }
            
            // Usuario Page
            Usuario {
                id: usuarioPage
                objectName: "usuarioPage"
                anchors.fill: parent
                visible: currentIndex === 6
                layer.enabled: true
            }

            // ===== TRABAJADORES PAGE CON NUEVA CONEXIÓN DE SEÑAL =====
            Trabajadores {
                id: trabajadoresPage
                objectName: "trabajadoresPage"
                anchors.fill: parent
                visible: currentIndex === 7
                layer.enabled: true
                
                // ===== PASO 4: NUEVA CONEXIÓN PARA ORQUESTAR NAVEGACIÓN Y PASO DE DATOS =====
                onIrAConfigPersonal: {
                    console.log("🚀 Señal irAConfigPersonal recibida desde Trabajadores")
                    
                    // ===== PASO 4a: OBTENER Y CONVERTIR EL MODELO DE DATOS =====
                    var tiposTrabajadoresData = []
                    
                    // El ListModel no se puede pasar directamente, convertir a array de objetos JavaScript
                    for (var i = 0; i < trabajadoresPage.tiposTrabajadoresModel.count; i++) {
                        var item = trabajadoresPage.tiposTrabajadoresModel.get(i)
                        tiposTrabajadoresData.push({
                            nombre: item.nombre,
                            descripcion: item.descripcion,
                            requiereMatricula: item.requiereMatricula,
                            especialidades: item.especialidades
                        })
                    }
                    
                    console.log("📊 Datos de tipos de trabajadores obtenidos:", JSON.stringify(tiposTrabajadoresData))
                    
                    // ===== PASO 4b: ASIGNAR DATOS CONVERTIDOS AL MÓDULO CONFIGURACIÓN =====
                    configuracionPage.tiposTrabajadoresModel = tiposTrabajadoresData
                    console.log("📤 Datos transferidos a configuracionPage.tiposTrabajadoresModel")
                    
                    // ===== PASO 4c: CAMBIAR VISTA INTERNA DE CONFIGURACIÓN A "PERSONAL" =====
                    configuracionPage.changeView("personal")
                    console.log("🔄 Vista de configuración cambiada a: personal")
                    
                    // ===== PASO 4d: CAMBIAR VISTA PRINCIPAL A CONFIGURACIÓN (PÁGINA 9) =====
                    switchToPage(9)
                    console.log("🎯 Navegación completada hacia módulo Configuración - Personal")
                }
            }
            
            // Reportes Page
            Reportes {
                id: reportesPage
                objectName: "reportesPage"
                anchors.fill: parent
                visible: currentIndex === 8
                layer.enabled: true
            }
            
            // ===== CONFIGURACIÓN PAGE CON ACCESO A PROPIEDADES DE MODELOS =====
            Configuracion {
                id: configuracionPage
                objectName: "configuracionPage"
                anchors.fill: parent
                visible: currentIndex === 9
                layer.enabled: true
                
                // ===== LAS PROPIEDADES especialidadesModel Y tiposGastosModel YA ESTÁN DEFINIDAS EN Configuracion.qml =====
                // ===== SE CONECTARÁN AUTOMÁTICAMENTE CUANDO SE ASIGNEN DESDE LOS HANDLERS =====
            }
        }
    }
    
    // ===== FUNCIONES (mantener todas) =====
    function actualizarNotificaciones() {
        console.log("🔔 Actualizando notificaciones...")
        fechaActual = new Date()
        
        notificacionesModel.clear()
        notificaciones = []
        
        if (farmaciaPage && farmaciaPage.farmaciaData) {
            var productos = farmaciaPage.farmaciaData.obtenerProductosParaInventario()
            verificarProductosVencidos(productos)
            verificarProductosProximosVencer(productos)
            verificarProductosBajoStock(productos)
        } else {
            console.log("⚠️ Datos de farmacia no disponibles, usando datos de ejemplo")
            verificarNotificacionesEjemplo()
        }
        
        verificarNotificacionesSistema()
        totalNotificaciones = notificacionesModel.count
        console.log("✅ Notificaciones actualizadas. Total:", totalNotificaciones)
    }
    
    function verificarProductosVencidos(productos) {
        var productosVencidos = []
        
        for (var i = 0; i < productos.length; i++) {
            var producto = productos[i]
            
            if (producto.stockUnitario > 0) {
                var fechaSimuladaVenc = new Date()
                fechaSimuladaVenc.setDate(fechaSimuladaVenc.getDate() - Math.random() * 10)
                
                if (fechaSimuladaVenc < fechaActual && Math.random() < 0.1) {
                    productosVencidos.push(producto)
                }
            }
        }
        
        if (productosVencidos.length > 0) {
            agregarNotificacion({
                icono: "⚠️",
                titulo: "Productos Vencidos",
                mensaje: `${productosVencidos.length} producto(s) han vencido y deben ser retirados del inventario.`,
                prioridad: "critica",
                tiempo: "Ahora",
                modulo: "farmacia",
                tipo: "vencidos"
            })
        }
    }
    
    function verificarProductosProximosVencer(productos) {
        var productosProxVencer = []
        
        for (var i = 0; i < productos.length; i++) {
            var producto = productos[i]
            
            if (producto.stockUnitario > 0) {
                if (Math.random() < 0.15) {
                    productosProxVencer.push(producto)
                }
            }
        }
        
        if (productosProxVencer.length > 0) {
            agregarNotificacion({
                icono: "⏰",
                titulo: "Productos Próximos a Vencer",
                mensaje: `${productosProxVencer.length} producto(s) vencerán en los próximos 30 días.`,
                prioridad: "alta",
                tiempo: "Hace 5 min",
                modulo: "farmacia",
                tipo: "proximo_vencer"
            })
        }
    }
    
    function verificarProductosBajoStock(productos) {
        var productosBajoStock = []
        
        for (var i = 0; i < productos.length; i++) {
            var producto = productos[i]
            
            if (producto.stockUnitario > 0 && producto.stockUnitario <= 15) {
                productosBajoStock.push(producto)
            }
        }
        
        if (productosBajoStock.length > 0) {
            agregarNotificacion({
                icono: "📉",
                titulo: "Stock Bajo",
                mensaje: `${productosBajoStock.length} producto(s) tienen stock inferior a 15 unidades.`,
                prioridad: "media",
                tiempo: "Hace 10 min",
                modulo: "farmacia",
                tipo: "bajo_stock"
            })
        }
    }
    
    function verificarNotificacionesSistema() {
        var notificacionesSistema = [
            {
                icono: "🔄",
                titulo: "Backup Completado",
                mensaje: "Copia de seguridad diaria completada exitosamente.",
                prioridad: "baja",
                tiempo: "Hace 1 hora",
                modulo: "sistema",
                tipo: "backup"
            },
            {
                icono: "👥",
                titulo: "Nuevo Usuario Registrado",
                mensaje: "Se ha registrado un nuevo usuario en el sistema.",
                prioridad: "baja",
                tiempo: "Hace 2 horas",
                modulo: "usuarios",
                tipo: "registro"
            }
        ]
        
        for (var i = 0; i < notificacionesSistema.length; i++) {
            if (Math.random() < 0.3) {
                agregarNotificacion(notificacionesSistema[i])
            }
        }
    }
    
    function verificarNotificacionesEjemplo() {
        var notificacionesEjemplo = [
            {
                icono: "⚠️",
                titulo: "Productos Vencidos",
                mensaje: "3 productos han vencido y deben ser retirados del inventario.",
                prioridad: "critica",
                tiempo: "Ahora",
                modulo: "farmacia",
                tipo: "vencidos"
            },
            {
                icono: "⏰",
                titulo: "Productos Próximos a Vencer",
                mensaje: "8 productos vencerán en los próximos 30 días.",
                prioridad: "alta",
                tiempo: "Hace 5 min",
                modulo: "farmacia",
                tipo: "proximo_vencer"
            },
            {
                icono: "📉",
                titulo: "Stock Bajo",
                mensaje: "12 productos tienen stock inferior a 15 unidades.",
                prioridad: "media",
                tiempo: "Hace 10 min",
                modulo: "farmacia",
                tipo: "bajo_stock"
            }
        ]
        
        for (var i = 0; i < notificacionesEjemplo.length; i++) {
            agregarNotificacion(notificacionesEjemplo[i])
        }
    }
    
    function agregarNotificacion(notificacion) {
        notificaciones.push(notificacion)
        notificacionesModel.append(notificacion)
    }
    
    function getPrioridadColor(prioridad) {
        switch(prioridad) {
            case "critica": return dangerColor
            case "alta": return warningColor
            case "media": return primaryColor
            case "baja": return successColor
            default: return darkGrayColor
        }
    }
    
    function getConteoNotificaciones(prioridad) {
        var count = 0
        for (var i = 0; i < notificacionesModel.count; i++) {
            if (notificacionesModel.get(i).prioridad === prioridad) {
                count++
            }
        }
        return count
    }
    
    property var navItems: [navItem0, navItem1, navItem2, navItem3, navItem4, navItem5, navItem6, navItem7, navItem8, navItem9]
    
    function switchToPage(index) {
        if (currentIndex !== index) {
            for (var i = 0; i < navItems.length; i++) {
                if (navItems[i]) {
                    navItems[i].resetHoverState()
                }
            }
            
            currentIndex = index
            Qt.callLater(function() {
                appController.navigateToModule(getCurrentPageName())
            })
        }
    }
    
    function getCurrentPageName() {
        if (currentIndex === 1) {
            const farmaciaSubsections = ["Ventas", "Productos", "Compras"]
            return "Farmacia - " + farmaciaSubsections[farmaciaSubsection]
        }
        
        const pageNames = [
            "Dashboard", "Farmacia", "Consultas", "Laboratorio", "Enfermería",
            "Servicios Básicos", "Usuarios", "Trabajadores", "Reportes", "Configuración"
        ]
        return pageNames[currentIndex] || "Dashboard"
    }

    // ===== FUNCIONES AUXILIARES PARA DEBUG Y MONITOREO =====

    // ===== FUNCIÓN AUXILIAR PARA MONITOREAR EL FLUJO DE DATOS =====
    function logEspecialidadesSync() {
        if (consultasPage && configuracionPage) {
            console.log("📊 Estado de sincronización de especialidades:")
            console.log("   - Consultas tiene:", consultasPage.especialidades ? consultasPage.especialidades.length : 0, "especialidades")
            console.log("   - Configuración tiene:", configuracionPage.especialidadesModel ? configuracionPage.especialidadesModel.length : 0, "especialidades")
        }
    }
    
    // ===== FUNCIÓN AUXILIAR PARA MONITOREAR EL FLUJO DE DATOS DE TRABAJADORES =====
    function logTiposTrabajadoresSync() {
        if (trabajadoresPage && configuracionPage) {
            console.log("📊 Estado de sincronización de tipos de trabajadores:")
            console.log("   - Trabajadores tiene:", trabajadoresPage.tiposTrabajadoresModel ? trabajadoresPage.tiposTrabajadoresModel.count : 0, "tipos")
            console.log("   - Configuración tiene:", configuracionPage.tiposTrabajadoresModel ? configuracionPage.tiposTrabajadoresModel.length : 0, "tipos")
        }
    }
    
    // ===== FUNCIÓN AUXILIAR PARA SINCRONIZACIÓN BIDIRECCIONAL (OPCIONAL) =====
    function syncEspecialidadesFromConfig() {
        if (configuracionPage && consultasPage && configuracionPage.especialidadesModel) {
            // Sincronizar cambios desde configuración hacia consultas
            consultasPage.especialidades = configuracionPage.especialidadesModel
            console.log("🔄 Especialidades sincronizadas desde Configuración hacia Consultas")
        }
    }

    // ===== FUNCIÓN AUXILIAR PARA SINCRONIZACIÓN BIDIRECCIONAL DE TRABAJADORES (OPCIONAL) =====
    function syncTiposTrabajadoresFromConfig() {
        if (configuracionPage && trabajadoresPage && configuracionPage.tiposTrabajadoresModel) {
            // Esta función puede ser utilizada para sincronizar cambios desde configuración hacia trabajadores
            // en caso de que se requiera sincronización bidireccional en el futuro
            console.log("🔄 Tipos de trabajadores podrían sincronizarse desde Configuración hacia Trabajadores")
        }
    }

    // ===== COMPONENTES ADAPTATIVOS =====
    component NavSection: ColumnLayout {
        property string title: ""
        spacing: 0
        Layout.fillWidth: true
        
        default property alias content: itemsColumn.children
        
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: baseUnit * 5
            color: "transparent"
            
            Label {
                anchors.left: parent.left
                anchors.leftMargin: baseUnit * 2.5
                anchors.verticalCenter: parent.verticalCenter
                text: title
                color: whiteColor
                font.pixelSize: fontBaseSize * 0.8
                font.bold: true
            }
        }
        
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.leftMargin: baseUnit * 2.5
            Layout.rightMargin: baseUnit * 2.5
            color: "#20FFFFFF"
        }
        
        ColumnLayout {
            id: itemsColumn
            Layout.fillWidth: true
            spacing: baseUnit * 0.5
        }
    }

    component NavItem: Rectangle {
        property string text: ""
        property string icon: ""
        property bool active: false
        property bool hovered: false
        signal clicked()
        
        Layout.fillWidth: true
        Layout.preferredHeight: baseUnit * 6
        Layout.leftMargin: baseUnit * 0.5
        Layout.rightMargin: baseUnit * 0.5
        color: active ? "#30FFFFFF" : (hovered && !active ? "#20FFFFFF" : "transparent")
        border.color: active ? whiteColor : "transparent"
        border.width: active ? 4 : 0
        radius: 0
        layer.enabled: active
        
        function resetHoverState() {
            hovered = false
        }
        
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: baseUnit * 0.5
            color: active ? whiteColor : "transparent"
        }
        
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: baseUnit * 2.5
            anchors.rightMargin: baseUnit * 2.5
            spacing: baseUnit * 1.5
            
            Label {
                text: icon
                color: whiteColor
                font.pixelSize: fontBaseSize * 1.3
            }
            
            Label {
                Layout.fillWidth: true
                text: parent.parent.text
                color: whiteColor
                font.pixelSize: fontBaseSize * 0.9
                font.bold: true
            }
        }
        
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            
            onEntered: {
                if (!parent.active) {
                    parent.hovered = true
                }
            }
            
            onExited: {
                parent.hovered = false
            }
            
            onClicked: parent.clicked()
        }
        
        Behavior on color { ColorAnimation { duration: 100 } }
    }

    component NavItemWithSubmenu: ColumnLayout {
        property string text: ""
        property string icon: ""
        property bool active: false
        property bool expanded: false
        property var submenuItems: []
        property bool hovered: false
        
        signal mainClicked()
        signal submenuClicked(int subsection)
        
        function resetHoverState() {
            hovered = false
        }
        
        spacing: 0
        Layout.fillWidth: true
        
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: baseUnit * 6
            Layout.leftMargin: baseUnit * 0.5
            Layout.rightMargin: baseUnit * 0.5
            color: active ? "#30FFFFFF" : (hovered && !active ? "#20FFFFFF" : "transparent")
            border.color: active ? whiteColor : "transparent"
            border.width: active ? 4 : 0
            radius: 0
            layer.enabled: active
            
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: baseUnit * 0.5
                color: active ? whiteColor : "transparent"
            }
            
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: baseUnit * 2.5
                anchors.rightMargin: baseUnit * 2.5
                spacing: baseUnit * 1.5
                
                Label {
                    text: icon
                    color: whiteColor
                    font.pixelSize: fontBaseSize * 1.3
                }
                
                Label {
                    Layout.fillWidth: true
                    text: parent.parent.parent.text
                    color: whiteColor
                    font.pixelSize: fontBaseSize * 0.9
                    font.bold: true
                }
                
                Label {
                    text: expanded ? "▼" : "▶"
                    color: whiteColor
                    font.pixelSize: fontBaseSize * 0.8
                    
                    Behavior on rotation {
                        NumberAnimation { duration: 200 }
                    }
                }
            }
            
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                
                onEntered: {
                    if (!active) {
                        parent.parent.hovered = true
                    }
                }
                
                onExited: {
                    parent.parent.hovered = false
                }
                
                onClicked: {
                    mainClicked()
                }
            }
            
            Behavior on color { ColorAnimation { duration: 100 } }
        }
        
        ColumnLayout {
            Layout.fillWidth: true
            spacing: baseUnit * 0.25
            visible: expanded
            opacity: expanded ? 1.0 : 0.0
            height: expanded ? implicitHeight : 0
            
            Behavior on opacity { NumberAnimation { duration: 200 } }
            Behavior on height { NumberAnimation { duration: 200 } }
            
            Repeater {
                model: submenuItems
                
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: baseUnit * 5
                    Layout.leftMargin: baseUnit * 1.5
                    Layout.rightMargin: baseUnit
                    color: (currentIndex === 1 && farmaciaSubsection === modelData.subsection) ? "#40FFFFFF" : "transparent"
                    radius: baseUnit
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: baseUnit * 4
                        anchors.rightMargin: baseUnit * 2.5
                        spacing: baseUnit
                        
                        Label {
                            text: modelData.icon
                            color: whiteColor
                            font.pixelSize: fontBaseSize
                        }
                        
                        Label {
                            Layout.fillWidth: true
                            text: modelData.text
                            color: whiteColor
                            font.pixelSize: fontBaseSize * 0.85
                            font.bold: (currentIndex === 1 && farmaciaSubsection === modelData.subsection)
                        }
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        
                        onEntered: {
                            if (!(currentIndex === 1 && farmaciaSubsection === modelData.subsection)) {
                                parent.color = "#30FFFFFF"
                            }
                        }
                        
                        onExited: {
                            if (!(currentIndex === 1 && farmaciaSubsection === modelData.subsection)) {
                                parent.color = "transparent"
                            }
                        }
                        
                        onClicked: {
                            submenuClicked(modelData.subsection)
                        }
                    }
                    
                    Behavior on color { ColorAnimation { duration: 100 } }
                }
            }
        }
    }
    
    // ===== CONEXIONES ADICIONALES PARA MONITOREO (OPCIONAL) =====

    // Timer para monitoreo periódico de sincronización (solo en desarrollo)
    Timer {
        id: syncMonitorTimer
        interval: 10000 // 10 segundos
        running: false // Cambiar a true solo para debug
        repeat: true
        onTriggered: {
            logEspecialidadesSync()
            logTiposTrabajadoresSync()
        }
    }
    
    Timer {
        id: notificationTimer
        interval: 300000 // 5 minutos
        running: true
        repeat: true
        onTriggered: { actualizarNotificaciones() }
    }
    
    Component.onCompleted: {
        console.log("🔔 Sistema de notificaciones iniciado")
        console.log("🔗 Conexión de navegación Consultas -> Configuración establecida")
        console.log("🔗 Conexión de navegación Trabajadores -> Configuración establecida") // NUEVA LÍNEA
        Qt.callLater(function() {
            actualizarNotificaciones()
            
            // Verificar que las conexiones estén establecidas
            if (consultasPage.irAConfiguracion) {
                console.log("✅ Señal irAConfiguracion conectada correctamente")
            } else {
                console.log("❌ Error: Señal irAConfiguracion no encontrada")
            }
            
            // ===== NUEVA VERIFICACIÓN PARA TRABAJADORES =====
            if (trabajadoresPage.irAConfigPersonal) {
                console.log("✅ Señal irAConfigPersonal conectada correctamente")
            } else {
                console.log("❌ Error: Señal irAConfigPersonal no encontrada")
            }
        })
    }
}