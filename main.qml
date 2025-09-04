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
    
    
    Universal.theme: Universal.Light
    Universal.accent: primaryColor
    Universal.background: lightGrayColor
    Universal.foreground: textColor
    
    // HEADER ADAPTATIVO MEJORADO
    header: ToolBar {
        objectName: "mainToolBar"
        // PASO 1: Aumentar altura mínima del header
        height: Math.max(70, baseUnit * 9) // Incrementado de 60 a 70, y de 8 a 9
        
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
            // PASO 2: Reducir márgenes laterales para aprovechar mejor el espacio
            anchors.leftMargin: baseUnit * 1.5  // Reducido de baseUnit * 2
            anchors.rightMargin: baseUnit * 1.5 // Reducido de baseUnit * 2
            anchors.topMargin: baseUnit * 1.2
            anchors.bottomMargin: baseUnit * 1.2
            spacing: baseUnit * 1.5 // Reducido para optimizar espacio
            
            // BOTÓN DE MENÚ ADAPTATIVO
            RoundButton {
                objectName: "menuToggleButton"
                // PASO 3: Ajustar tamaño del botón menú
                Layout.preferredWidth: baseUnit * 6   // Incrementado de 5 a 6
                Layout.preferredHeight: baseUnit * 6  // Incrementado de 5 a 6
                Layout.alignment: Qt.AlignVCenter
                text: "☰"
                
                background: Rectangle {
                    color: whiteColor
                    radius: baseUnit * 1.2
                    // Añadir sombra sutil
                    border.color: "#10000000"
                    border.width: 1
                }
                
                contentItem: Label {
                    text: parent.text
                    color: primaryColor
                    font.bold: true
                    font.pixelSize: fontBaseSize * 1.4 // Ligeramente más grande
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: {
                    drawerOpen = !drawerOpen
                    drawer.visible = drawerOpen
                }
            }
            
            // BREADCRUMB ADAPTATIVO MEJORADO
            RowLayout {
                Layout.fillWidth: false // Cambiado para no expandirse demasiado
                Layout.preferredWidth: Math.min(400, mainWindow.width * 0.3) // Limitar ancho máximo
                spacing: baseUnit * 0.8
                
                Label {
                    text: "🏥"
                    color: whiteColor
                    font.pixelSize: fontBaseSize * 1.1
                }
                
                Label {
                    text: "Clínica María Inmaculada"
                    color: whiteColor
                    font.pixelSize: fontBaseSize * 0.95
                    // PASO 4: Mejorar responsividad del texto
                    visible: mainWindow.width > 800 // Cambiado de 600 a 800
                    elide: Text.ElideRight
                    Layout.maximumWidth: 200
                }
                
                Label {
                    text: ">"
                    color: whiteColor
                    font.pixelSize: fontBaseSize * 0.9
                    visible: mainWindow.width > 800
                }
                
                Label {
                    objectName: "currentPageLabel"
                    text: getCurrentPageName()
                    color: whiteColor
                    font.bold: true
                    font.pixelSize: fontBaseSize * 0.95
                    elide: Text.ElideRight
                    Layout.maximumWidth: 150
                }
            }
            
            // PASO 5: Espaciador flexible optimizado
            Item { 
                Layout.fillWidth: true 
                Layout.minimumWidth: baseUnit * 2 // Asegurar espacio mínimo
            }
            
            // PERFIL DE USUARIO ADAPTATIVO MEJORADO
            Rectangle {
                // PASO 6: Mejorar el ancho y responsividad del perfil
                Layout.preferredWidth: {
                    if (mainWindow.width < 900) return Math.max(120, baseUnit * 15)
                    else if (mainWindow.width < 1200) return Math.max(160, baseUnit * 20)
                    else return Math.max(200, baseUnit * 25) // Más ancho en pantallas grandes
                }
                Layout.preferredHeight: baseUnit * 7 // Incrementado de 6 a 7
                Layout.alignment: Qt.AlignVCenter
                
                color: whiteColor
                radius: baseUnit * 1.8 // Esquinas más redondeadas
                
                // PASO 7: Añadir sombra sutil
                border.color: "#15000000"
                border.width: 1
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: baseUnit * 1.2 // Incrementado de 0.8
                    spacing: baseUnit * 1.2
                    
                    // Avatar más grande
                    Rectangle {
                        Layout.preferredWidth: baseUnit * 5.5  // Incrementado de 4.5
                        Layout.preferredHeight: baseUnit * 5.5 // Incrementado de 4.5
                        Layout.alignment: Qt.AlignVCenter
                        color: primaryColor
                        radius: baseUnit * 2.75
                        
                        Label {
                            anchors.centerIn: parent
                            text: "AM"
                            color: whiteColor
                            font.bold: true
                            font.pixelSize: fontBaseSize * 1.1 // Ligeramente más grande
                        }
                    }
                    
                    // PASO 8: Información del usuario mejorada
                    Column {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: baseUnit * 0.3
                        // PASO 9: Mejorar responsividad del texto del perfil
                        visible: parent.parent.width > 140 // Incrementado de 120
                        
                        Label {
                            text: "Dr. Admin"
                            color: textColor
                            font.bold: true
                            font.pixelSize: fontBaseSize * 0.95 // Ligeramente más grande
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, parent.width)
                        }
                        
                        Label {
                            text: "Administrador"
                            color: darkGrayColor
                            font.pixelSize: fontBaseSize * 0.75
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, parent.width)
                        }
                    }
                    
                    // Icono dropdown
                    Label {
                        text: "▼"
                        color: darkGrayColor
                        font.pixelSize: fontBaseSize * 0.85
                        Layout.alignment: Qt.AlignVCenter
                        visible: parent.parent.width > 140
                    }
                }
                
                // PASO 10: Mejorar interacción visual
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    
                    onEntered: parent.color = Qt.lighter(whiteColor, 0.95)
                    onExited: parent.color = whiteColor
                    
                    onClicked: {
                        Qt.callLater(function() {
                            appController.showNotification("Usuario", "Menú de usuario - Próximamente")
                        })
                    }
                }
                
                // Animación suave para cambios de color
                Behavior on color { 
                    ColorAnimation { duration: 150 } 
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
                                icon: "file:///D:/Sistema-Clinica-/Resources/iconos/farmacia.png"
                                active: currentIndex === 1
                                expanded: farmaciaExpanded
                                
                                onMainClicked: {
                                    farmaciaExpanded = !farmaciaExpanded
                                    if (!farmaciaExpanded) {
                                        switchToPage(1)
                                    }
                                }
                                
                                submenuItems: [
                                    { text: "Ventas", icon: "file:///D:/Sistema-Clinica-/Resources/iconos/ventas.png", subsection: 0 },
                                    { text: "Productos", icon: "file:///D:/Sistema-Clinica-/Resources/iconos/productos.png", subsection: 1 },
                                    { text: "Compras", icon: "file:///D:/Sistema-Clinica-/Resources/iconos/compras.png", subsection: 2 }
                                ]
                                
                                onSubmenuClicked: function(subsection) {
                                    farmaciaSubsection = subsection
                                    switchToPage(1)
                                }
                            }
                            
                            NavItem {
                                id: navItem2
                                text: "CONSULTAS"
                                icon: "file:///D:/Sistema-Clinica-/Resources/iconos/Consulta.png"  // Cambia de "🩺"
                                active: currentIndex === 2
                                onClicked: switchToPage(2)
                            }
                            
                            NavItem {
                                id: navItem3
                                text: "LABORATORIO"
                                icon: "file:///D:/Sistema-Clinica-/Resources/iconos/Laboratorio.png"  // Cambia de "🧪"
                                active: currentIndex === 3
                                onClicked: switchToPage(3)
                            }
                            
                            NavItem {
                                id: navItem4
                                text: "ENFERMERÍA"
                                icon: "file:///D:/Sistema-Clinica-/Resources/iconos/Enfermeria.png"  // Cambia de "💉"
                                active: currentIndex === 4
                                onClicked: switchToPage(4)
                            }
                        }
                        
                        NavSection {
                            title: "SERVICIOS"
                            
                            NavItem {
                                id: navItem5
                                text: "SERVICIOS BÁSICOS"
                                icon: "file:///D:/Sistema-Clinica-/Resources/iconos/ServiciosBasicos.png"  // Cambia de "📊"
                                active: currentIndex === 5
                                onClicked: switchToPage(5)
                            }
                                                        
                            NavItem {
                                id: navItem6
                                text: "USUARIOS"
                                icon: "file:///D:/Sistema-Clinica-/Resources/iconos/usuario.png"  // Cambia de "👤"
                                active: currentIndex === 6
                                onClicked: switchToPage(6)
                            }
                            
                            NavItem {
                                id: navItem7
                                text: "PERSONAL"  // Corregir texto
                                icon: "file:///D:/Sistema-Clinica-/Resources/iconos/Trabajadores.png"  // Corregir icon
                                active: currentIndex === 7
                                onClicked: switchToPage(7)
                            }
                            
                            NavItem {
                                id: navItem8
                                text: "REPORTES"
                                icon: "file:///D:/Sistema-Clinica-/Resources/iconos/reportes.png"
                                active: currentIndex === 8
                                onClicked: switchToPage(8)
                            }
                        }
                        
                        NavSection {
                            title: "SISTEMA"
                            
                            NavItem {
                                id: navItem9
                                text: "CONFIGURACIÓN"
                                icon: "file:///D:/Sistema-Clinica-/Resources/iconos/configuraciones.png"
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
                    if (configuracionPage.item) {
                        configuracionPage.item.tiposGastosModel = tiposGastosData
                    }
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
            // ===== CONFIGURACIÓN PAGE CON ACCESO A PROPIEDADES DE MODELOS =====
            Loader {
                id: configuracionPage
                objectName: "configuracionPage" 
                anchors.fill: parent
                visible: currentIndex === 9
                layer.enabled: true
                source: "Configuracion.qml"
                
                // Acceso a las propiedades a través del item cargado
                readonly property var tiposGastosModel: item ? item.tiposGastosModel : []
                readonly property var especialidadesModel: item ? item.especialidadesModel : []
                
                function changeView(view) {
                    if (item && item.changeView) {
                        item.changeView(view)
                    }
                }
            }
        }
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
            
            Image {
                source: icon
                Layout.preferredWidth: fontBaseSize * 2.5
                Layout.preferredHeight: fontBaseSize * 2.5
                fillMode: Image.PreserveAspectFit
                smooth: true
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
                
                Image {
                    source: icon
                    Layout.preferredWidth: fontBaseSize * 2.5
                    Layout.preferredHeight: fontBaseSize * 2.5
                    fillMode: Image.PreserveAspectFit
                    smooth: true
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
                        
                        Image {
                            source: modelData.icon
                            Layout.preferredWidth: fontBaseSize * 2.0  // Aumentado de 1.0 a 1.5
                            Layout.preferredHeight: fontBaseSize * 2.0 // Aumentado de 1.0 a 1.5
                            fillMode: Image.PreserveAspectFit
                            smooth: true
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
}