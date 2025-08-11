import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15

ApplicationWindow {
    id: mainWindow
    objectName: "mainWindow"
    width: 1400
    height: 900
    visible: true
    title: "Sistema de Gestión Médica - Clínica Maria Inmaculada"
    
    readonly property color primaryColor:  "#273746"  
    readonly property color primaryDarkColor: "#34495E"
    readonly property color successColor: "#27ae60"
    readonly property color dangerColor: "#E74C3C"
    readonly property color warningColor: "#f39c12"
    readonly property color lightGrayColor: "#ECF0F1"
    readonly property color darkGrayColor: "#7f8c8d"
    readonly property color textColor: "#2c3e50"
    readonly property color whiteColor: "#FFFFFF"
    
    property bool drawerOpen: true
    property int currentIndex: 0
    property bool farmaciaExpanded: false
    property int farmaciaSubsection: 0
    
    // NUEVAS PROPIEDADES PARA NOTIFICACIONES
    property bool notificationPanelOpen: false
    property var notificaciones: []
    property int totalNotificaciones: 0
    property var fechaActual: new Date()
    
    Universal.theme: Universal.Light
    Universal.accent: primaryColor
    Universal.background: lightGrayColor
    Universal.foreground: textColor
    
    header: ToolBar {
        objectName: "mainToolBar"
        height: 80
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
            anchors.margins: 20
            spacing: 24
            
            RoundButton {
                objectName: "menuToggleButton"
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                text: "☰"
                background: Rectangle {
                    color: whiteColor
                    radius: 12
                }
                
                contentItem: Label {
                    text: parent.text
                    color: primaryColor
                    font.bold: true
                    font.pixelSize: 16
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: {
                    drawerOpen = !drawerOpen
                    drawer.visible = drawerOpen
                }
            }
            
            RowLayout {
                spacing: 8
                
                Label {
                    text: "🏠"
                    color: whiteColor
                }
                
                Label {
                    text: "Clínica María Inmaculada"
                    color: whiteColor
                    font.pixelSize: 14
                }
                
                Label {
                    text: ">"
                    color: whiteColor
                }
                
                Label {
                    objectName: "currentPageLabel"
                    text: getCurrentPageName()
                    color: whiteColor
                    font.bold: true
                    font.pixelSize: 14
                }
            }
            
            Item { Layout.fillWidth: true }
            
            // BOTÓN DE NOTIFICACIONES MEJORADO
            RoundButton {
                id: notificationButton
                objectName: "notificationButton"
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                text: "🔔"
                
                background: Rectangle {
                    color: notificationButton.pressed ? Qt.darker(whiteColor, 1.1) : whiteColor
                    radius: 12
                    border.color: totalNotificaciones > 0 ? dangerColor : "transparent"
                    border.width: totalNotificaciones > 0 ? 2 : 0
                    
                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                    
                    Behavior on border.color {
                        ColorAnimation { duration: 150 }
                    }
                }
                
                contentItem: Label {
                    text: parent.text
                    color: primaryColor
                    font.pixelSize: 16
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    
                    // Animación de pulseo cuando hay notificaciones críticas
                    SequentialAnimation on scale {
                        running: totalNotificaciones > 0
                        loops: Animation.Infinite
                        NumberAnimation { to: 1.1; duration: 800 }
                        NumberAnimation { to: 1.0; duration: 800 }
                    }
                }
                
                // Badge de contador de notificaciones
                Rectangle {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: -2
                    width: 20
                    height: 20
                    color: totalNotificaciones > 0 ? dangerColor : "transparent"
                    radius: 10
                    visible: totalNotificaciones > 0
                    
                    Label {
                        anchors.centerIn: parent
                        text: totalNotificaciones > 99 ? "99+" : totalNotificaciones.toString()
                        color: whiteColor
                        font.pixelSize: totalNotificaciones > 99 ? 8 : 11
                        font.bold: true
                    }
                    
                    // Animación de aparición
                    Behavior on opacity {
                        NumberAnimation { duration: 300 }
                    }
                }
                
                onClicked: {
                    actualizarNotificaciones()
                    notificationPanelOpen = !notificationPanelOpen
                }
            }
            
            Rectangle {
                Layout.preferredWidth: 200
                Layout.preferredHeight: 56
                color: whiteColor
                radius: 16
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 12
                    
                    Rectangle {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44
                        color: primaryColor
                        radius: 22
                        
                        Label {
                            anchors.centerIn: parent
                            text: "AM"
                            color: whiteColor
                            font.bold: true
                            font.pixelSize: 16
                        }
                    }
                    
                    Column {
                        Layout.fillWidth: true
                        spacing: 2
                        
                        Label {
                            text: "Dr. Admin"
                            color: textColor
                            font.bold: true
                            font.pixelSize: 14
                        }
                        
                        Label {
                            text: "Administrador"
                            color: darkGrayColor
                            font.pixelSize: 12
                        }
                    }
                    
                    Label {
                        text: "▼"
                        color: darkGrayColor
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
    
    // PANEL DE NOTIFICACIONES - OVERLAY
    Rectangle {
        id: notificationOverlay
        anchors.fill: parent
        color: "#80000000"
        visible: notificationPanelOpen
        opacity: notificationPanelOpen ? 1.0 : 0.0
        z: 1000
        
        Behavior on opacity {
            NumberAnimation { duration: 300 }
        }
        
        MouseArea {
            anchors.fill: parent
            onClicked: {
                notificationPanelOpen = false
            }
        }
        
        // Panel deslizable desde la derecha
        Rectangle {
            id: notificationPanel
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            width: Math.min(420, parent.width * 0.4)
            color: whiteColor
            
            // Animación de deslizamiento
            transform: Translate {
                x: notificationPanelOpen ? 0 : notificationPanel.width
                Behavior on x {
                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                }
            }
            
            // Sombra
            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: -10
                color: "transparent"
                border.color: "#20000000"
                border.width: 10
                radius: 10
                z: -1
            }
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                
                // Header del panel
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    color: primaryColor
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 16
                        
                        Rectangle {
                            width: 40
                            height: 40
                            color: whiteColor
                            radius: 20
                            
                            Label {
                                anchors.centerIn: parent
                                text: "🔔"
                                font.pixelSize: 20
                            }
                        }
                        
                        ColumnLayout {
                            spacing: 4
                            
                            Label {
                                text: "Centro de Notificaciones"
                                color: whiteColor
                                font.bold: true
                                font.pixelSize: 18
                            }
                            
                            Label {
                                text: totalNotificaciones + " alertas activas"
                                color: "#E8F4FD"
                                font.pixelSize: 13
                            }
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        Button {
                            width: 36
                            height: 36
                            
                            background: Rectangle {
                                color: parent.pressed ? "#40FFFFFF" : "transparent"
                                radius: 18
                            }
                            
                            contentItem: Label {
                                text: "×"
                                color: whiteColor
                                font.pixelSize: 20
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: {
                                notificationPanelOpen = false
                            }
                        }
                    }
                }
                
                // Filtros de notificaciones
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    color: "#F8F9FA"
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 8
                        
                        Button {
                            text: "🔄 Actualizar"
                            Layout.preferredHeight: 32
                            
                            background: Rectangle {
                                color: parent.pressed ? Qt.darker(primaryColor, 1.2) : primaryColor
                                radius: 6
                            }
                            
                            contentItem: Label {
                                text: parent.text
                                color: whiteColor
                                font.pixelSize: 12
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: {
                                actualizarNotificaciones()
                            }
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        Label {
                            text: Qt.formatDateTime(fechaActual, "dd/MM/yyyy hh:mm")
                            color: darkGrayColor
                            font.pixelSize: 11
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
                        model: ListModel {
                            id: notificacionesModel
                        }
                        spacing: 0
                        
                        delegate: Rectangle {
                            width: notificationsList.width
                            height: Math.max(80, contentColumn.implicitHeight + 20)
                            color: index % 2 === 0 ? "#FFFFFF" : "#F8F9FA"
                            border.color: "#E5E7EB"
                            border.width: 1
                            
                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: 4
                                color: getPrioridadColor(model.prioridad)
                            }
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                anchors.leftMargin: 20
                                spacing: 12
                                
                                Rectangle {
                                    width: 36
                                    height: 36
                                    color: getPrioridadColor(model.prioridad)
                                    radius: 18
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: model.icono
                                        color: whiteColor
                                        font.pixelSize: 16
                                        font.bold: true
                                    }
                                }
                                
                                ColumnLayout {
                                    id: contentColumn
                                    Layout.fillWidth: true
                                    spacing: 4
                                    
                                    Label {
                                        text: model.titulo
                                        color: textColor
                                        font.bold: true
                                        font.pixelSize: 14
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }
                                    
                                    Label {
                                        text: model.mensaje
                                        color: darkGrayColor
                                        font.pixelSize: 12
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }
                                    
                                    Label {
                                        text: model.tiempo
                                        color: "#9CA3AF"
                                        font.pixelSize: 10
                                    }
                                }
                                
                                // Botón de acción si está en farmacia
                                Button {
                                    visible: model.modulo === "farmacia" && currentIndex !== 1
                                    text: "Ver"
                                    Layout.preferredWidth: 50
                                    Layout.preferredHeight: 28
                                    
                                    background: Rectangle {
                                        color: parent.pressed ? Qt.darker(primaryColor, 1.2) : primaryColor
                                        radius: 4
                                    }
                                    
                                    contentItem: Label {
                                        text: parent.text
                                        color: whiteColor
                                        font.pixelSize: 10
                                        font.bold: true
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    
                                    onClicked: {
                                        notificationPanelOpen = false
                                        // Navegar a farmacia - productos
                                        farmaciaExpanded = true
                                        farmaciaSubsection = 1 // Productos
                                        switchToPage(1)
                                    }
                                }
                            }
                        }
                        
                        // Estado vacío
                        Item {
                            anchors.centerIn: parent
                            visible: notificacionesModel.count === 0
                            width: 200
                            height: 150
                            
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 16
                                
                                Label {
                                    text: "🎉"
                                    font.pixelSize: 48
                                    color: successColor
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                
                                Label {
                                    text: "¡Todo en orden!"
                                    color: textColor
                                    font.bold: true
                                    font.pixelSize: 16
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                
                                Label {
                                    text: "No hay alertas pendientes en este momento."
                                    color: darkGrayColor
                                    font.pixelSize: 12
                                    Layout.alignment: Qt.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    Layout.maximumWidth: 180
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }
                    }
                }
                
                // Footer con estadísticas
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50
                    color: "#F1F5F9"
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 16
                        
                        Label {
                            text: "📊 Resumen:"
                            color: darkGrayColor
                            font.pixelSize: 11
                            font.bold: true
                        }
                        
                        Label {
                            text: getConteoNotificaciones("critica") + " críticas"
                            color: dangerColor
                            font.pixelSize: 11
                            font.bold: true
                        }
                        
                        Label {
                            text: getConteoNotificaciones("alta") + " importantes"
                            color: warningColor
                            font.pixelSize: 11
                            font.bold: true
                        }
                        
                        Label {
                            text: getConteoNotificaciones("media") + " normales"
                            color: primaryColor
                            font.pixelSize: 11
                            font.bold: true
                        }
                        
                        Item { Layout.fillWidth: true }
                    }
                }
            }
        }
    }
    
    // ... Resto del código original (RowLayout, drawer, páginas, etc.) ...
    RowLayout {
        anchors.fill: parent
        spacing: 0
        
        Rectangle {
            id: drawer
            objectName: "navigationDrawer"
            Layout.preferredWidth: drawerOpen ? 320 : 0
            Layout.fillHeight: true
            visible: drawerOpen
            layer.enabled: true
            
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
                
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 120
                    color: "transparent"
                    border.color: "#20FFFFFF"
                    border.width: 1
                    
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 16
                        
                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter  
                            Image {
                                anchors.centerIn: parent
                                source: "iconos/logo_CMI.svg"
                                width: 150
                                height: 200
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }
                        }
                    }                    
                }
                
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
        }
        
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
            
            // Consultas Page
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
            
            // Servicios Básicos Page
            ServiciosBasicos {
                id: serviciosPage
                objectName: "serviciosPage"
                anchors.fill: parent
                visible: currentIndex === 5
                layer.enabled: true
            }
            
            // Usuario Page
            Usuario {
                id: usuarioPage
                objectName: "usuarioPage"
                anchors.fill: parent
                visible: currentIndex === 6
                layer.enabled: true
            }
            
            Trabajadores {
                id: trabajadoresPage
                objectName: "trabajadoresPage"
                anchors.fill: parent
                visible: currentIndex === 7
                layer.enabled: true
            }
            
            // Reportes Page
            Reportes {
                id: reportesPage
                objectName: "reportesPage"
                anchors.fill: parent
                visible: currentIndex === 8
                layer.enabled: true
            }
            
            // Configuración Page
            Configuracion {
                id: configuracionPage
                objectName: "configuracionPage"
                anchors.fill: parent
                visible: currentIndex === 9
                layer.enabled: true
            }
        }
    }
    
    // ===== FUNCIONES DE NOTIFICACIONES =====
    
    function actualizarNotificaciones() {
        console.log("🔔 Actualizando notificaciones...")
        fechaActual = new Date()
        
        // Limpiar notificaciones anteriores
        notificacionesModel.clear()
        notificaciones = []
        
        // Obtener productos de farmacia si está disponible
        if (farmaciaPage && farmaciaPage.farmaciaData) {
            var productos = farmaciaPage.farmaciaData.obtenerProductosParaInventario()
            verificarProductosVencidos(productos)
            verificarProductosProximosVencer(productos)
            verificarProductosBajoStock(productos)
        } else {
            // Si no hay datos, usar datos de ejemplo para testing
            console.log("⚠️ Datos de farmacia no disponibles, usando datos de ejemplo")
            verificarNotificacionesEjemplo()
        }
        
        // Agregar notificaciones del sistema
        verificarNotificacionesSistema()
        
        // Actualizar contador total
        totalNotificaciones = notificacionesModel.count
        
        console.log("✅ Notificaciones actualizadas. Total:", totalNotificaciones)
    }
    
    function verificarProductosVencidos(productos) {
        var productosVencidos = []
        
        for (var i = 0; i < productos.length; i++) {
            var producto = productos[i]
            
            // Simular verificación de lotes vencidos
            if (producto.stockUnitario > 0) {
                // En una implementación real, consultarías la tabla de lotes
                var fechaSimuladaVenc = new Date()
                fechaSimuladaVenc.setDate(fechaSimuladaVenc.getDate() - Math.random() * 10)
                
                if (fechaSimuladaVenc < fechaActual && Math.random() < 0.1) { // 10% de productos vencidos para demo
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
                // Simular productos próximos a vencer (próximos 30 días)
                if (Math.random() < 0.15) { // 15% de productos próximos a vencer para demo
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
        // Simular algunas notificaciones del sistema
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
        
        // Agregar aleatoriamente algunas notificaciones del sistema
        for (var i = 0; i < notificacionesSistema.length; i++) {
            if (Math.random() < 0.3) { // 30% de probabilidad
                agregarNotificacion(notificacionesSistema[i])
            }
        }
    }
    
    function verificarNotificacionesEjemplo() {
        // Datos de ejemplo cuando no hay farmacia disponible
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
            case "critica":
                return dangerColor
            case "alta":
                return warningColor
            case "media":
                return primaryColor
            case "baja":
                return successColor
            default:
                return darkGrayColor
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
    
    // Lista de referencias a todos los NavItem para resetear el hover
    property var navItems: [navItem0, navItem1, navItem2, navItem3, navItem4, navItem5, navItem6, navItem7, navItem8, navItem9]
    
    function switchToPage(index) {
        if (currentIndex !== index) {
            // Resetear el estado hover de todos los elementos
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
            "Dashboard",
            "Farmacia", 
            "Consultas",
            "Laboratorio",
            "Enfermería",
            "Servicios Básicos",
            "Usuarios",
            "Trabajadores",
            "Reportes",
            "Configuración"
        ]
        return pageNames[currentIndex] || "Dashboard"
    }

    // Components originales (NavSection, NavItem, NavItemWithSubmenu)
    component NavSection: ColumnLayout {
        property string title: ""
        spacing: 0
        Layout.fillWidth: true
        
        default property alias content: itemsColumn.children
        
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            color: "transparent"
            
            Label {
                anchors.left: parent.left
                anchors.leftMargin: 24
                anchors.verticalCenter: parent.verticalCenter
                text: title
                color: whiteColor
                font.pixelSize: 12
                font.bold: true
            }
        }
        
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            color: "#20FFFFFF"
        }
        
        ColumnLayout {
            id: itemsColumn
            Layout.fillWidth: true
            spacing: 4
        }
    }

    component NavItem: Rectangle {
        property string text: ""
        property string icon: ""
        property bool active: false
        property bool hovered: false
        signal clicked()
        
        Layout.fillWidth: true
        Layout.preferredHeight: 56
        Layout.leftMargin: 4
        Layout.rightMargin: 4
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
            width: 4
            color: active ? whiteColor : "transparent"
        }
        
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            spacing: 16
            
            Label {
                text: icon
                color: whiteColor
                font.pixelSize: 20
            }
            
            Label {
                Layout.fillWidth: true
                text: parent.parent.text
                color: whiteColor
                font.pixelSize: 15
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
        
        Behavior on color {
            ColorAnimation { duration: 100 }
        }
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
            Layout.preferredHeight: 56
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            color: active ? "#30FFFFFF" : (hovered && !active ? "#20FFFFFF" : "transparent")
            border.color: active ? whiteColor : "transparent"
            border.width: active ? 4 : 0
            radius: 0
            layer.enabled: active
            
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 4
                color: active ? whiteColor : "transparent"
            }
            
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                spacing: 16
                
                Label {
                    text: icon
                    color: whiteColor
                    font.pixelSize: 20
                }
                
                Label {
                    Layout.fillWidth: true
                    text: parent.parent.parent.text
                    color: whiteColor
                    font.pixelSize: 15
                    font.bold: true
                }
                
                Label {
                    text: expanded ? "▼" : "▶"
                    color: whiteColor
                    font.pixelSize: 12
                    
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
            
            Behavior on color {
                ColorAnimation { duration: 100 }
            }
        }
        
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            visible: expanded
            opacity: expanded ? 1.0 : 0.0
            height: expanded ? implicitHeight : 0
            
            Behavior on opacity {
                NumberAnimation { duration: 200 }
            }
            
            Behavior on height {
                NumberAnimation { duration: 200 }
            }
            
            Repeater {
                model: submenuItems
                
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    Layout.leftMargin: 12
                    Layout.rightMargin: 8
                    color: (currentIndex === 1 && farmaciaSubsection === modelData.subsection) ? "#40FFFFFF" : "transparent"
                    radius: 8
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 40
                        anchors.rightMargin: 24
                        spacing: 12
                        
                        Label {
                            text: modelData.icon
                            color: whiteColor
                            font.pixelSize: 16
                        }
                        
                        Label {
                            Layout.fillWidth: true
                            text: modelData.text
                            color: whiteColor
                            font.pixelSize: 14
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
                    
                    Behavior on color {
                        ColorAnimation { duration: 100 }
                    }
                }
            }
        }
    }
    
    // Timer para actualizar notificaciones periódicamente
    Timer {
        id: notificationTimer
        interval: 300000 // 5 minutos
        running: true
        repeat: true
        onTriggered: {
            actualizarNotificaciones()
        }
    }
    
    // Inicialización
    Component.onCompleted: {
        console.log("🔔 Sistema de notificaciones iniciado")
        // Pequeño delay para asegurar que farmacia esté cargada
        Qt.callLater(function() {
            actualizarNotificaciones()
        })
    }
}