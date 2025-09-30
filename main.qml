import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15
import QtQml 2.15
import Qt5Compat.GraphicalEffects

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
    property bool serviciosExpanded: false
    property int serviciosSubsection: 0

    // ===== PROPIEDADES SEGURAS PARA EVITAR UNDEFINED =====
    property bool modelsReady: false
    property int totalProductos: 0
    property int totalProveedores: 0
    property int ventasHoyCount: 0

    
    Universal.theme: Universal.Light
    Universal.accent: primaryColor
    Universal.background: lightGrayColor
    Universal.foreground: textColor

    Component.onCompleted: {
        console.log("✅ main.qml cargado correctamente")
        
        // Verificar si authModel está disponible
        if (typeof authModel === "undefined") {
            console.log("⚠️ authModel no está disponible aún")
        } else {
            console.log("✅ authModel disponible:", authModel)
        }
    }
    
    // ===== CONEXIONES CON MODELOS SEGURAS =====
    Connections {
        target: appController
        function onModelsReady() {
            //console.log("🔗 Models listos desde AppController")
            modelsReady = true
            
            // Actualizar propiedades de forma segura
            updateModelProperties()
        }
    }
    
    // Función para actualizar propiedades de forma segura
    function updateModelProperties() {
        try {
            if (appController && appController.inventario_model_instance) {
                totalProductos = appController.inventario_model_instance.totalProductos || 0
                console.log("📦 Productos disponibles BD:", totalProductos)
            }
            
            if (appController && appController.proveedor_model_instance) {
                totalProveedores = appController.proveedor_model_instance.totalProveedores || 0
                console.log("📋 Proveedores BD:", totalProveedores)
            }
            
            if (appController && appController.venta_model_instance && appController.venta_model_instance.ventasHoy) {
                ventasHoyCount = appController.venta_model_instance.ventasHoy.length || 0
                console.log("💰 Ventas del día BD:", ventasHoyCount)
            }
        } catch (error) {
            console.log("⚠️ Error actualizando propiedades:", error)
        }
    }
    
    // Conexión con AuthModel si está disponible
    Connections {
        target: typeof authModel !== 'undefined' ? authModel : null
        function onCurrentUserChanged() {
            console.log("Usuario autenticado cambiado")
        }
        function onLogoutCompleted() {
            console.log("Logout completado")
        }
    }
    
    // HEADER ADAPTATIVO MEJORADO - SOLO PERFIL Y CERRAR SESIÓN
    header: ToolBar {
        id: mainToolBar
        objectName: "mainToolBar"
        height: Math.max(70, baseUnit * 9)
        
        background: Rectangle {
            gradient: Gradient {
                GradientStop { position: 0.0; color: primaryDarkColor }
                GradientStop { position: 1.0; color: primaryColor }
            }
            border.color: "#20000000"
            border.width: 1
        }
        
        RowLayout {
            id: headerLayout
            anchors.fill: parent
            anchors.leftMargin: baseUnit * 1.5
            anchors.rightMargin: baseUnit * 1.5
            anchors.topMargin: baseUnit * 1.2
            anchors.bottomMargin: baseUnit * 1.2
            spacing: baseUnit * 1.5
            
            // BOTÓN DE MENÚ ADAPTATIVO
            RoundButton {
                objectName: "menuToggleButton"
                Layout.preferredWidth: baseUnit * 6
                Layout.preferredHeight: baseUnit * 6
                Layout.alignment: Qt.AlignVCenter
                text: "☰"
                
                background: Rectangle {
                    color: whiteColor
                    radius: baseUnit * 1
                    border.color: "#10000000"
                    border.width: 1
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
            
            // BREADCRUMB ADAPTATIVO MEJORADO
            RowLayout {
                Layout.fillWidth: false
                Layout.preferredWidth: Math.min(300, mainWindow.width * 0.25)
                spacing: baseUnit * 0.6
                
                Label {
                    text: "🏥"
                    color: whiteColor
                    font.pixelSize: fontBaseSize * 1.0
                }
                
                Label {
                    text: "Clínica María Inmaculada"
                    color: whiteColor
                    font.pixelSize: fontBaseSize * 0.85
                    visible: mainWindow.width > 700
                    elide: Text.ElideRight
                    Layout.maximumWidth: 150
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
            
            // Espaciador flexible
            Item { 
                Layout.fillWidth: true 
                Layout.minimumWidth: baseUnit * 1
            }

            // PERFIL DE USUARIO COMPACTO
            Rectangle {
                id: userProfileContainer
                Layout.preferredWidth: {
                    if (mainWindow.width < 800) return Math.max(120, baseUnit * 14)
                    else if (mainWindow.width < 1100) return Math.max(150, baseUnit * 18)
                    else return Math.max(180, baseUnit * 22)
                }
                Layout.preferredHeight: baseUnit * 6
                Layout.alignment: Qt.AlignVCenter
                
                color: userProfileMouseArea.containsMouse || userMenu.visible ? Qt.lighter(whiteColor, 0.95) : whiteColor
                radius: baseUnit * 1.5
                border.color: userMenu.visible ? primaryColor : "#20000000"
                border.width: userMenu.visible ? 1.5 : 1
                
                // Efecto de sombra suave
                layer.enabled: true
                layer.effect: DropShadow {
                    horizontalOffset: 0
                    verticalOffset: 2
                    radius: 6
                    samples: 12
                    color: "#30000000"
                }
                
                // Usar Layout en lugar de anchors para el contenido interno
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: baseUnit * 1.2
                    spacing: baseUnit * 1.2
                    
                    // Avatar compacto
                    Rectangle {
                        Layout.preferredWidth: baseUnit * 4
                        Layout.preferredHeight: baseUnit * 4
                        Layout.alignment: Qt.AlignVCenter
                        color: primaryColor
                        radius: baseUnit * 2
                        
                        Label {
                            anchors.centerIn: parent
                            text: getCurrentUserInitials()
                            color: whiteColor
                            font.bold: true
                            font.pixelSize: fontBaseSize * 1.2
                        }
                    }
                    
                    // Información del usuario compacta
                    Column {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: baseUnit * 0.3
                        
                        Label {
                            text: getCurrentUserName()
                            color: textColor
                            font.bold: true
                            font.pixelSize: fontBaseSize * 0.9
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, parent.width)
                        }
                        
                        Label {
                            text: getCurrentUserRole()
                            color: darkGrayColor
                            font.pixelSize: fontBaseSize * 0.75
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, parent.width)
                        }
                    }
                    
                    // Icono dropdown
                    Label {
                        text: userMenu.visible ? "▲" : "▼"
                        color: primaryColor
                        font.pixelSize: fontBaseSize * 0.9
                        Layout.alignment: Qt.AlignVCenter
                        Layout.rightMargin: baseUnit * 0.3
                    }
                }
                
                MouseArea {
                    id: userProfileMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    
                    onClicked: {
                        userMenu.visible = !userMenu.visible
                    }
                }
            }
        }
        
        // MENÚ DESPLEGABLE SIMPLIFICADO - SOLO PERFIL Y CERRAR SESIÓN
        Rectangle {
            id: userMenu
            width: Math.max(180, baseUnit * 22)
            height: baseUnit * 8 // Altura reducida para solo 2 opciones
            
            // Posicionamiento absoluto respecto al perfil de usuario
            x: userProfileContainer.x + userProfileContainer.width - width
            y: userProfileContainer.y + userProfileContainer.height + baseUnit * 0.5
            
            color: whiteColor
            radius: baseUnit * 1.5
            border.color: "#40000000"
            border.width: 1
            
            // Sombra más pronunciada para mejor visibilidad
            layer.enabled: true
            layer.effect: DropShadow {
                horizontalOffset: 0
                verticalOffset: 4
                radius: 10
                samples: 16
                color: "#60000000"
            }
            
            visible: false
            z: 1000
            
            Column {
                anchors.fill: parent
                anchors.margins: baseUnit * 1.0
                spacing: baseUnit * 0.5
                
                // Opción: Ver Perfil
                Rectangle {
                    width: parent.width
                    height: baseUnit * 3
                    color: mouseArea1.containsMouse ? "#f0f0f0" : "transparent"
                    radius: baseUnit * 0.5
                    
                    Row {
                        anchors.centerIn: parent
                        spacing: baseUnit * 0.8
                        
                        Text {
                            text: "👤"
                            font.pixelSize: fontBaseSize
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        Text {
                            text: "Ver Perfil"
                            font.pixelSize: fontBaseSize * 0.85
                            color: textColor
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                    
                    MouseArea {
                        id: mouseArea1
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            userMenu.visible = false
                            showUserProfile()
                        }
                    }
                }
                
                // Separador
                Rectangle {
                    width: parent.width
                    height: 1
                    color: "#e0e0e0"
                }
                
                // Opción: Cerrar Sesión
                Rectangle {
                    width: parent.width
                    height: baseUnit * 3
                    color: mouseArea2.containsMouse ? "#fff0f0" : "transparent"
                    radius: baseUnit * 0.5
                    
                    Row {
                        anchors.centerIn: parent
                        spacing: baseUnit * 0.8
                        
                        Text {
                            text: "🚪"
                            font.pixelSize: fontBaseSize
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        Text {
                            text: "Cerrar Sesión"
                            font.pixelSize: fontBaseSize * 0.85
                            font.bold: true
                            color: dangerColor
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                    
                    MouseArea {
                        id: mouseArea2
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            userMenu.visible = false
                            confirmLogout()
                        }
                    }
                }
            }
        }
    }

    // Click fuera para cerrar menú - Colocado al final del archivo principal
    MouseArea {
        anchors.fill: parent
        z: 999
        visible: userMenu.visible
        onClicked: {
            userMenu.visible = false
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
                        
                        Image {
                            Layout.alignment: Qt.AlignHCenter
                            source: "Resources/iconos/logo_CMI.svg"
                            Layout.preferredWidth: Math.min(150, drawer.width * 0.8)
                            Layout.preferredHeight: Math.min(200, baseUnit * 20)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            
                            onStatusChanged: {
                                if (status === Image.Error) {
                                    console.log("❌ Error cargando logo:", source)
                                } else if (status === Image.Ready) {
                                    console.log("✅ Logo cargado correctamente:", source)
                                }
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
                                icon: "Resources/iconos/vistageneral.png"
                                active: currentIndex === 0
                                onClicked: switchToPage(0)
                            }
                            
                            NavItemWithSubmenu {
                                id: navItem1
                                text: "FARMACIA"
                                icon: "Resources/iconos/farmacia.png"
                                active: currentIndex === 1
                                expanded: farmaciaExpanded
                                
                                
                                onMainClicked: {
                                    farmaciaExpanded = !farmaciaExpanded
                                    if (!farmaciaExpanded) {
                                        switchToPage(1)
                                    }
                                }
                                
                                submenuItems: [
                                    { text: "Ventas", icon: "Resources/iconos/ventas.png", subsection: 0 },
                                    { text: "Productos", icon: "Resources/iconos/productos.png", subsection: 1 },
                                    { text: "Compras", icon: "Resources/iconos/compras.png", subsection: 2 },
                                    { text: "Proveedores", icon: "Resources/iconos/proveedor.png" , subsection: 3 }
                                ]
                                
                                onSubmenuClicked: function(subsection) {
                                    farmaciaSubsection = subsection
                                    switchToPage(1)
                                }
                            }
                            NavItem {
                                id: navItem2
                                text: "CIERRE DE CAJA"
                                icon: "Resources/iconos/camaraderia.png"  // Necesitarás este ícono
                                active: currentIndex === 2
                                onClicked: switchToPage(2)
                            }
                            
                            NavItem {
                                id: navItem3
                                text: "CONSULTAS"
                                icon: "Resources/iconos/Consulta.png"
                                active: currentIndex === 3
                                onClicked: switchToPage(3)
                            }
                            
                            NavItem {
                                id: navItem4
                                text: "LABORATORIO"
                                icon: "Resources/iconos/Laboratorio.png"
                                active: currentIndex === 4
                                onClicked: switchToPage(4)
                            }
                            
                            NavItem {
                                id: navItem5
                                text: "ENFERMERÍA"
                                icon: "Resources/iconos/Enfermeria.png"
                                active: currentIndex === 5
                                onClicked: switchToPage(5)
                            }
                        }
                        
                        NavSection {
                            title: "SERVICIOS"
                            
                            // Reemplazar el NavItem actual de SERVICIOS BÁSICOS con:
                            NavItemWithSubmenu {
                                id: navItem6
                                text: "SERVICIOS BÁSICOS"
                                icon: "Resources/iconos/ServiciosBasicos.png"
                                active: currentIndex === 6
                                expanded: serviciosExpanded
                                
                                onMainClicked: {
                                    serviciosExpanded = !serviciosExpanded
                                    if (!serviciosExpanded) {
                                        switchToPage(6)
                                    }
                                }
                                
                                submenuItems: [
                                    { text: "Gastos Operativos", icon: "Resources/iconos/gastos.png", subsection: 0 },
                                    { text: "Ingresos Extras", icon: "Resources/iconos/ingresos.png", subsection: 1 }
                                   
                                ]
                                
                                onSubmenuClicked: function(subsection) {
                                    serviciosSubsection = subsection
                                    switchToPage(6)
                                }
                            }
                                                        
                            NavItem {
                                id: navItem7
                                text: "USUARIOS"
                                icon: "Resources/iconos/usuario.png"
                                active: currentIndex === 7
                                onClicked: switchToPage(7)
                            }
                            
                            NavItem {
                                id: navItem8
                                text: "PERSONAL"
                                icon: "Resources/iconos/Trabajadores.png"
                                active: currentIndex === 8
                                onClicked: switchToPage(8)
                            }
                            
                            NavItem {
                                id: navItem9
                                text: "REPORTES"
                                icon: "Resources/iconos/reportes.png"
                                active: currentIndex === 9
                                onClicked: switchToPage(9)
                            }
                        }
                        
                        NavSection {
                            title: "SISTEMA"
                            
                            NavItem {
                                id: navItem10
                                text: "CONFIGURACIÓN"
                                icon: "Resources/iconos/configuraciones.png"
                                active: currentIndex === 10
                                onClicked: switchToPage(10)
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
                
                property int currentFarmaciaSubsection: farmaciaSubsection
                onCurrentFarmaciaSubsectionChanged: {
                    if (currentFarmaciaSubsection === 3) {
                        console.log("🟷 Navegando a subsección de Proveedores")
                    }
                }
            }

            CierreCaja {
                id: cierreCajaPage
                objectName: "cierreCajaPage"
                anchors.fill: parent
                visible: currentIndex === 2
                layer.enabled: true
            }
            
            // ===== CONSULTAS PAGE CON NUEVA CONEXIÓN DE SEÑAL =====
            Consultas {
                id: consultasPage
                objectName: "consultasPage"
                anchors.fill: parent
                visible: currentIndex === 3
                layer.enabled: true
            }
            
            // Laboratorio Page
            Laboratorio {
                id: laboratorioPage
                objectName: "laboratorioPage"
                anchors.fill: parent
                visible: currentIndex === 4
                layer.enabled: true
            }
            
            // Enfermería Page
            Enfermeria {
                id: enfermeriaPage
                objectName: "enfermeriaPage"
                anchors.fill: parent
                visible: currentIndex === 5
                layer.enabled: true
            }   
            
            // ===== SERVICIOS BÁSICOS PAGE CON NUEVA CONEXIÓN DE SEÑAL =====
            ServiciosBasicos {
                id: serviciosPage
                objectName: "serviciosPage"
                anchors.fill: parent
                visible: currentIndex === 6
                layer.enabled: true
                
                // AGREGAR ESTA PROPIEDAD:
                property int currentServiciosSubsection: serviciosSubsection
                onCurrentServiciosSubsectionChanged: {
                    if (currentServiciosSubsection === 1) {
                        console.log("🟢 Navegando a subsección de Ingresos Extras")
                    }
                }
                
                // Mantener la señal existente
                onIrAConfigServiciosBasicos: {
                    console.log("🚀 Señal irAConfigServiciosBasicos recibida desde ServiciosBasicos")
                    
                    var tiposGastosData = []
                    
                    try {
                        if (serviciosPage.tiposGastosModel && serviciosPage.tiposGastosModel.count) {
                            for (var i = 0; i < serviciosPage.tiposGastosModel.count; i++) {
                                var item = serviciosPage.tiposGastosModel.get(i)
                                tiposGastosData.push({
                                    nombre: item.nombre || "",
                                    descripcion: item.descripcion || "",
                                    ejemplos: item.ejemplos || "",
                                    color: item.color || ""
                                })
                            }
                        }
                    } catch (error) {
                        console.log("⚠️ Error obteniendo tipos de gastos:", error)
                    }
                    
                    console.log("📊 Datos de tipos de gastos obtenidos:", JSON.stringify(tiposGastosData))
                    
                    if (configuracionPage.item) {
                        configuracionPage.item.tiposGastosModel = tiposGastosData
                    }
                    console.log("📤 Datos transferidos a configuracionPage.tiposGastosModel")
                    
                    configuracionPage.changeView("servicios")
                    console.log("🔄 Vista de configuración cambiada a: servicios")
                    
                    switchToPage(10)
                    console.log("🎯 Navegación completada hacia módulo Configuración")
                }
            }
            
            // Usuario Page
            Usuario {
                id: usuarioPage
                objectName: "usuarioPage"
                anchors.fill: parent
                visible: currentIndex === 7
                layer.enabled: true
            }

            // ===== TRABAJADORES PAGE CON NUEVA CONEXIÓN DE SEÑAL =====
            Trabajadores {
                id: trabajadoresPage
                objectName: "trabajadoresPage"
                anchors.fill: parent
                visible: currentIndex === 8
                layer.enabled: true
                
                onIrAConfigPersonal: {
                    console.log("🚀 Señal irAConfigPersonal recibida desde Trabajadores")
                    
                    var tiposTrabajadoresData = []
                    
                    try {
                        if (trabajadoresPage.tiposTrabajadoresModel && trabajadoresPage.tiposTrabajadoresModel.count) {
                            for (var i = 0; i < trabajadoresPage.tiposTrabajadoresModel.count; i++) {
                                var item = trabajadoresPage.tiposTrabajadoresModel.get(i)
                                tiposTrabajadoresData.push({
                                    nombre: item.nombre || "",
                                    descripcion: item.descripcion || "",
                                    requiereMatricula: item.requiereMatricula || false,
                                    especialidades: item.especialidades || ""
                                })
                            }
                        }
                    } catch (error) {
                        console.log("⚠️ Error obteniendo tipos de trabajadores:", error)
                    }
                    
                    console.log("📊 Datos de tipos de trabajadores obtenidos:", JSON.stringify(tiposTrabajadoresData))
                    
                    configuracionPage.tiposTrabajadoresModel = tiposTrabajadoresData
                    console.log("📤 Datos transferidos a configuracionPage.tiposTrabajadoresModel")
                    
                    configuracionPage.changeView("personal")
                    console.log("🔄 Vista de configuración cambiada a: personal")
                    
                    switchToPage(10)
                    console.log("🎯 Navegación completada hacia módulo Configuración - Personal")
                }
            }
            
            // Reportes Page
            Reportes {
                id: reportesPage
                objectName: "reportesPage"
                anchors.fill: parent
                visible: currentIndex === 9
                layer.enabled: true
            }
            
            // ===== CONFIGURACIÓN PAGE CON ACCESO A PROPIEDADES DE MODELOS =====
            Loader {
                id: configuracionPage
                objectName: "configuracionPage" 
                anchors.fill: parent
                visible: currentIndex === 10
                layer.enabled: true
                source: "Configuracion.qml"
                
                readonly property var tiposGastosModel: item && item.tiposGastosModel ? item.tiposGastosModel : []
                readonly property var especialidadesModel: item && item.especialidadesModel ? item.especialidadesModel : []
                
                function changeView(view) {
                    if (item && item.changeView) {
                        item.changeView(view)
                    }
                }
            }
        }
    }
    
    property var navItems: [navItem0, navItem1, navItem2, navItem3, navItem4, navItem5, navItem6, navItem7, navItem8, navItem9, navItem10]
    
    function switchToPage(index) {
        if (currentIndex !== index) {
            for (var i = 0; i < navItems.length; i++) {
                if (navItems[i]) {
                    navItems[i].resetHoverState()
                }
            }
            
            currentIndex = index
            Qt.callLater(function() {
                if (appController && appController.navigateToModule) {
                    appController.navigateToModule(getCurrentPageName())
                }
            })
        }
    }
        
    function getCurrentPageName() {
        if (currentIndex === 1) {
            const farmaciaSubsections = ["Ventas", "Productos", "Compras", "Proveedores"]
            return "Farmacia - " + farmaciaSubsections[farmaciaSubsection]
        }
        
        // AGREGAR ESTA SECCIÓN:
        if (currentIndex === 6) {
            const serviciosSubsections = ["Gastos Operativos", "Ingresos Extras"]
            return "Servicios Básicos - " + serviciosSubsections[serviciosSubsection]
        }
        
        const pageNames = [
            "Dashboard",        // 0
            "Farmacia",         // 1  
            "Cierre de Caja",   // 2
            "Consultas",        // 3
            "Laboratorio",      // 4
            "Enfermería",       // 5
            "Servicios Básicos", // 6
            "Usuarios",         // 7
            "Trabajadores",     // 8
            "Reportes",         // 9
            "Configuración"     // 10
        ]
        return pageNames[currentIndex] || "Dashboard"
    }

    // ===== FUNCIONES PARA OBTENER DATOS DEL USUARIO DESDE BD =====
    function getCurrentUserInitials() {
        try {
            if (typeof authModel !== "undefined" && authModel && authModel.isAuthenticated) {
                const name = authModel.userName
                const parts = name.split(" ")
                if (parts.length >= 2) {
                    return (parts[0].charAt(0) + parts[1].charAt(0)).toUpperCase()
                } else if (parts.length === 1) {
                    return parts[0].substring(0, 2).toUpperCase()
                }
            }
        } catch (error) {
            console.log("⚠️ Error obteniendo iniciales:", error)
        }
        return "US"
    }
    
    function getCurrentUserName() {
        try {
            if (typeof authModel !== "undefined" && authModel && authModel.isAuthenticated) {
                const userName = authModel.userName
                const userRole = authModel.userRole
                if (userRole && userRole.toLowerCase().includes("medico")) {
                    return "Dr. " + userName.split(" ")[0]
                }
                return userName.split(" ")[0] || "Usuario"
            }
        } catch (error) {
            console.log("⚠️ Error obteniendo nombre:", error)
        }
        return "Usuario"
    }
    
    function getCurrentUserFullName() {
        try {
            if (typeof authModel !== "undefined" && authModel && authModel.isAuthenticated) {
                return authModel.userName
            }
        } catch (error) {
            console.log("⚠️ Error obteniendo nombre completo:", error)
        }
        return "Usuario"
    }
    
    function getCurrentUserRole() {
        try {
            if (typeof authModel !== "undefined" && authModel && authModel.isAuthenticated) {
                return authModel.userRole
            }
        } catch (error) {
            console.log("⚠️ Error obteniendo rol:", error)
        }
        return "Sin sesión"
    }
    
    function getCurrentUserEmail() {
        try {
            if (typeof authModel !== "undefined" && authModel && authModel.isAuthenticated) {
                return authModel.userEmail
            }
        } catch (error) {
            console.log("⚠️ Error obteniendo email:", error)
        }
        return ""
    }
    
    function canAccessModule(moduleName) {
        try {
            if (typeof authModel !== "undefined" && authModel && authModel.isAuthenticated) {
                switch(moduleName) {
                    case "farmacia":
                        return authModel.canAccessFarmacia()
                    case "usuarios":
                        return authModel.canAccessUsuarios()
                    case "reportes":
                        return authModel.canAccessReportes()
                    default:
                        return true
                }
            }
        } catch (error) {
            console.log("⚠️ Error verificando acceso:", error)
        }
        return true
    }

    // FUNCIONES PARA MANEJAR PERFIL Y LOGOUT
    function showUserProfile() {
        console.log("Navegando a perfil de usuario")
        switchToPage(10) // Ir a configuración donde está la info del usuario
    }

    function confirmLogout() {
        console.log("Iniciando logout...")
        try {
            if (appController && appController.showNotification) {
                appController.showNotification("Cerrando Sesión", "Hasta pronto!")
            }
            Qt.callLater(function() {
                if (typeof authModel !== "undefined" && authModel && authModel.logout) {
                    authModel.logout()
                }
            })
        } catch (error) {
            console.log("⚠️ Error en logout:", error)
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
            Layout.preferredHeight: expanded ? implicitHeight : 0
            
            Behavior on opacity { NumberAnimation { duration: 200 } }
            Behavior on Layout.preferredHeight { NumberAnimation { duration: 200 } }
            
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
                            Layout.preferredWidth: fontBaseSize * 2.0
                            Layout.preferredHeight: fontBaseSize * 2.0
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

    // Componente MenuItem personalizado
    component MenuItem: Rectangle {
        property string icon: ""
        property string text: ""
        property bool bold: false
        signal clicked()
        
        Layout.fillWidth: true
        Layout.preferredHeight: baseUnit * 4.5
        color: menuItemMouseArea.containsMouse ? "#f8f9fa" : "transparent"
        radius: baseUnit * 1.0
        
        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: baseUnit * 1.5
            spacing: baseUnit * 1.2
            
            Label {
                text: parent.parent.icon
                font.pixelSize: fontBaseSize * 1.1
                anchors.verticalCenter: parent.verticalCenter
            }
            
            Label {
                text: parent.parent.text
                color: textColor
                font.pixelSize: fontBaseSize * 0.9
                font.bold: parent.parent.bold
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        
        MouseArea {
            id: menuItemMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
        
        Behavior on color {
            ColorAnimation { duration: 100 }
        }
    }
    
    // Click fuera para cerrar menú
    MouseArea {
        anchors.fill: parent
        z: 999
        visible: userProfileContainer.state === "menuOpen"
        onClicked: {
            userProfileContainer.state = ""
        }
    }
}