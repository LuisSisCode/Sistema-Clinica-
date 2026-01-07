import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15
import ClinicaApp 1.0

ScrollView {
    id: dashboardRoot
    objectName: "dashboardRoot"
    
    readonly property color primaryColor: "#005A9C"
    readonly property color accentColor: "#4DBA87"
    readonly property color successColor: "#10b981"
    readonly property color dangerColor: "#E57373"
    readonly property color warningColor: "#f59e0b"
    readonly property color lightGrayColor: "#f1f5f9"
    readonly property color darkGrayColor: "#64748b"
    readonly property color textColor: "#334155"
    readonly property color whiteColor: "#FFFFFF"
    readonly property color backgroundGradient: "#f8f9fc"

    // Colores específicos para cada sección
    readonly property color farmaciaColor: "#ff6b35"
    readonly property color consultasColor: "#4a90e2"
    readonly property color laboratorioColor: "#4ecdc4"
    readonly property color enfermeriaColor: "#9b59b6"
    readonly property color serviciosColor: "#34495e"

    readonly property color blueColor: "#005A9C"

    // 🚀 PROPIEDADES PARA ALERTAS MEJORADAS
    property var alertasInventario: []
    property bool datosCargados: false
    property string filtroAlertaActual: "TODOS"  // "TODOS", "VENCIDOS", "PRÓXIMO_A_VENCER", "STOCK_BAJO"
    
    // CONEXIÓN CON MODELOS
    property var dashboardModel: appController ? appController.dashboard_model_instance : null
    property var inventarioModel: appController ? appController.inventario_model_instance : null

    // Sistema de filtrado jerárquico: Año -> Mes
    property string currentPeriodType: "mes" // "hoy", "semana", "mes", "año"
    property int selectedMonth: new Date().getMonth() + 1
    property int selectedYear: new Date().getFullYear()
    property date systemStartDate: new Date("2025-01-01")
    
    // Funciones de utilidad para fechas
    function getCurrentDate() {
        return new Date()
    }
    
    function getStartOfWeek(date) {
        var startOfWeek = new Date(date)
        var day = startOfWeek.getDay()
        var diff = startOfWeek.getDate() - day + (day === 0 ? -6 : 1)
        startOfWeek.setDate(diff)
        startOfWeek.setHours(0, 0, 0, 0)
        return startOfWeek
    }
    
    function getMonthName(monthIndex) {
        var months = ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
                      "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"]
        return months[monthIndex]
    }

    function formatearFechaVencimiento(fechaStr) {
        if (!fechaStr) return "Sin fecha"
        
        try {
            var fecha = new Date(fechaStr)
            var hoy = new Date()
            
            hoy.setHours(0, 0, 0, 0)
            fecha.setHours(0, 0, 0, 0)
            
            var diferencia = Math.ceil((fecha - hoy) / (1000 * 60 * 60 * 24))
            
            if (diferencia < 0) {
                return "VENCIDO (" + Math.abs(diferencia) + " días)"
            } else if (diferencia === 0) {
                return "VENCE HOY"
            } else if (diferencia === 1) {
                return "Vence mañana"
            } else if (diferencia <= 7) {
                return "Vence en " + diferencia + " días"
            } else {
                return "Vence en " + diferencia + " días"
            }
        } catch (e) {
            return fechaStr
        }
    }
    
    function getAvailableMonths() {
        var months = []
        var currentDate = getCurrentDate()
        var startYear = systemStartDate.getFullYear()
        var startMonth = systemStartDate.getMonth()
        
        var yearStart = (selectedYear === startYear) ? startMonth : 0
        var yearEnd = (selectedYear === currentDate.getFullYear()) ? currentDate.getMonth() : 11
        
        for (var month = yearStart; month <= yearEnd; month++) {
            months.push({
                value: month + 1,
                label: getMonthName(month)
            })
        }
        return months
    }
    
    function getAvailableYears() {
        var years = []
        var currentYear = getCurrentDate().getFullYear()
        var startYear = systemStartDate.getFullYear()
        
        for (var year = startYear; year <= currentYear; year++) {
            years.push({
                value: year,
                label: year.toString()
            })
        }
        return years.reverse()
    }
    
    function findCurrentMonthIndex() {
        var months = getAvailableMonths()
        for (var i = 0; i < months.length; i++) {
            if (months[i].value === selectedMonth) {
                return i
            }
        }
        return 0
    }
    
    function findCurrentYearIndex() {
        var years = getAvailableYears()
        for (var i = 0; i < years.length; i++) {
            if (years[i].value === selectedYear) {
                return i
            }
        }
        return 0
    }
    
    function updateMonthsForSelectedYear() {
        var availableMonths = getAvailableMonths()
        if (availableMonths.length > 0) {
            selectedMonth = availableMonths[0].value
            if (monthComboBox) {
                monthComboBox.model = availableMonths
                monthComboBox.currentIndex = 0
            }
        }
    }
    
    function isDateInSelectedPeriod(dateString) {
        var itemDate = new Date(dateString)
        var today = getCurrentDate()
        
        switch(currentPeriodType) {
            case "hoy":
                var todayStart = new Date(today)
                todayStart.setHours(0, 0, 0, 0)
                var todayEnd = new Date(today)
                todayEnd.setHours(23, 59, 59, 999)
                return itemDate >= todayStart && itemDate <= todayEnd
                
            case "semana":
                var weekStart = getStartOfWeek(today)
                var weekEnd = new Date(weekStart)
                weekEnd.setDate(weekStart.getDate() + 6)
                weekEnd.setHours(23, 59, 59, 999)
                return itemDate >= weekStart && itemDate <= weekEnd
                
            case "mes":
                return itemDate.getMonth() + 1 === selectedMonth && 
                       itemDate.getFullYear() === selectedYear
                       
            case "año":
                return itemDate.getFullYear() === selectedYear
                
            default:
                return true
        }
    }

    // Funciones que usan datos reales del modelo
    function calculateFarmaciaTotal() {
        return dashboardModel ? dashboardModel.farmaciaTotal : 0
    }
    
    function calculateConsultasTotal() {
        return dashboardModel ? dashboardModel.consultasTotal : 0
    }
    
    function calculateLaboratorioTotal() {
        return dashboardModel ? dashboardModel.laboratorioTotal : 0
    }
    
    function calculateEnfermeriaTotal() {
        return dashboardModel ? dashboardModel.enfermeriaTotal : 0
    }
    
    function calculateServiciosBasicosTotal() {
        return dashboardModel ? dashboardModel.serviciosBasicosTotal : 0
    }
    
    function calculateTotalIngresos() {
        return dashboardModel ? dashboardModel.totalIngresos : 0
    }
    
    function calculateTotalEgresos() {
        return dashboardModel ? dashboardModel.totalEgresos : 0
    }
    
    function getPeriodLabel() {
        if (!dashboardModel) return "CARGANDO..."
        
        switch(currentPeriodType) {
            case "hoy": 
                return "HOY"
            case "semana": 
                return "ESTA SEMANA"
            case "mes": 
                return getMonthName(selectedMonth - 1).toUpperCase() + " " + selectedYear
            case "año": 
                return "AÑO " + selectedYear
            default: 
                return "PERÍODO"
        }
    }

    // 🚀 FUNCIÓN SIMPLIFICADA PARA CARGAR ALERTAS
    function cargarAlertas() {
        if (!inventarioModel) {
            datosCargados = false
            return
        }
        
        try {
            var alertas = inventarioModel.obtener_alertas_inventario()
            if (alertas) {
                alertasInventario = alertas
            } else {
                alertasInventario = []
            }
            datosCargados = true
            
        } catch (error) {
            alertasInventario = []
            datosCargados = false
        }
    }
    
    function filtrarAlertas(tipoFiltro) {
        if (!alertasInventario || alertasInventario.length === 0) {
            return []
        }
        
        if (tipoFiltro === "TODOS") {
            return alertasInventario
        }
        
        var resultado = []
        for (var i = 0; i < alertasInventario.length; i++) {
            if (alertasInventario[i].Tipo_Alerta === tipoFiltro) {
                resultado.push(alertasInventario[i])
            }
        }
        return resultado
    }
    
    function contarAlertasPorTipo(tipo) {
        if (!alertasInventario || alertasInventario.length === 0) {
            return 0
        }
        
        var count = 0
        for (var i = 0; i < alertasInventario.length; i++) {
            if (alertasInventario[i].Tipo_Alerta === tipo) {
                count++
            }
        }
        return count
    }

    function obtenerDatosAgrupados(filtro) {
        if (!alertasInventario || alertasInventario.length === 0) return []
        
        var productos = {}
        
        for (var i = 0; i < alertasInventario.length; i++) {
            var alerta = alertasInventario[i]
            if (filtro !== "TODOS" && alerta.Tipo_Alerta !== filtro) continue
            
            var codigo = alerta.Codigo || "SIN_COD"
            var nombre = alerta.Producto || alerta.Nombre || "Producto sin nombre"
            
            if (!productos[codigo]) {
                productos[codigo] = {
                    codigo: codigo,
                    nombre: nombre,
                    alertas: []
                }
            }
            productos[codigo].alertas.push(alerta)
        }
        
        return Object.values(productos)
    }

    function obtenerColorAlerta(tipoAlerta) {
        switch(tipoAlerta) {
            case "PRODUCTO VENCIDO":
                return "#fef2f2"
            case "PRODUCTO PRÓXIMO A VENCER":
                return "#fffbeb"
            case "STOCK BAJO":
                return "#f0f9ff"
            default:
                return "#f3f4f6"
        }
    }
    
    function obtenerColorBorde(tipoAlerta) {
        switch(tipoAlerta) {
            case "PRODUCTO VENCIDO":
                return "#ef4444"
            case "PRODUCTO PRÓXIMO A VENCER":
                return "#f59e0b"
            case "STOCK BAJO":
                return "#0ea5e9"
            default:
                return "#9ca3af"
        }
    }
    
  
    
    function obtenerColor(tipo) {
        switch(tipo) {
            case "PRODUCTO VENCIDO": return "#ef4444"
            case "PRODUCTO PRÓXIMO A VENCER": return "#f59e0b"
            case "STOCK BAJO": return "#eab308"
            default: return "#6b7280"
        }
    }
    
    function obtenerBg(tipo) {
        switch(tipo) {
            case "PRODUCTO VENCIDO": return "#fef2f2"
            case "PRODUCTO PRÓXIMO A VENCER": return "#fffbeb"
            case "STOCK BAJO": return "#fef3c7"
            default: return "#f3f4f6"
        }
    }
    
    function obtenerIcono(tipo) {
        switch(tipo) {
            case "PRODUCTO VENCIDO": return "⚠️"
            case "PRODUCTO PRÓXIMO A VENCER": return "⏰"
            case "STOCK BAJO": return "📦"
            default: return "ℹ️"
        }
    }
    
    function formatearAlerta(alerta) {
        var tipo = alerta.Tipo_Alerta
        if (tipo === "STOCK BAJO") {
            return "Stock Bajo (Quedan " + (alerta.Stock_Actual || 0) + ")"
        }
        var detalle = alerta.Detalle || ""
        return detalle.length > 35 ? detalle.substring(0, 35) + "..." : detalle
    }
    
    function obtenerIconoAlerta(tipoAlerta) {
        switch(tipoAlerta) {
            case "PRODUCTO VENCIDO":
                return "🔴"
            case "PRODUCTO PRÓXIMO A VENCER":
                return "⚠️"
            case "STOCK BAJO":
                return "📦"
            default:
                return "ℹ️"
        }
    }
    
    function obtenerTextoEstado(tipoAlerta, detalle) {
        if (tipoAlerta === "STOCK BAJO") {
            return detalle || "Stock por debajo del mínimo"
        }
        return detalle || ""
    }

    function navegarAProducto(codigoProducto) {
        if (appController && typeof appController.navegarADetalleProducto === 'function') {
            appController.navegarADetalleProducto(codigoProducto)
        }
    }

    signal periodChanged(string newPeriodType)
    
    Component.onCompleted: {
        if (dashboardModel) {
            dashboardModel.cambiarPeriodo(currentPeriodType)
        }
        
        // Intentar cargar alertas inmediatamente
        if (inventarioModel) {
            console.log("📢 InventarioModel disponible - Cargando alertas")
            cargarAlertas()
        } else {
            console.log("⏳ InventarioModel no listo - Esperando signal productosChanged")
        }
    }
    
    // ✅ NUEVO: Listener para cuando inventarioModel esté listo
    // ✅ LISTENER PARA ALERTAS - CARGA DATOS REALES
    Connections {
        target: inventarioModel
        
        function onProductosChanged() {
            console.log("📦 Productos actualizados - Cargando alertas")
            cargarAlertas()
        }

        function onAertasChanged() {
            console.log("🔔 Signal alertasChanged del modelo - Actualizando vista")
            if (inventarioModel && inventarioModel.alertas) {
                alertasInventario = inventarioModel.alertas
                datosCargados = true
                console.log("✅ ALERTAS CARGADAS: " + alertasInventario.length + " alertas")
                for (var i = 0; i < alertasInventario.length; i++) {
                    console.log("   - " + alertasInventario[i].Tipo_Alerta + ": " + alertasInventario[i].Producto)
                }
                alertasRetryTimer.stop()
            }
        }
    }
    
    // ✅ TIMER: CARGAR ALERTAS SI NO SE CARGARON AUTOMÁTICAMENTE
    Timer {
        id: alertasRetryTimer
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        
        onTriggered: {
            if (inventarioModel && (!alertasInventario || alertasInventario.length === 0)) {
                console.log("⏱️ Cargando alertas del modelo...")
                inventarioModel.obtener_alertas_inventario()
            } else if (alertasInventario && alertasInventario.length > 0) {
                console.log("✅ Alertas cargadas - Timer detenido")
                stop()
            }
        }
    }

    Timer {
        id: autoRefreshAlertas
        interval: 5000
        running: true
        repeat: true
        
        onTriggered: {
            if (inventarioModel) {
                console.log("🔄 Auto-refreshing alertas...")
                var nuevasAlertas = inventarioModel.obtener_alertas_inventario()
                if (nuevasAlertas) {
                    alertasInventario = nuevasAlertas
                    console.log("✅ Alertas actualizadas: " + alertasInventario.length)
                }
            }
        }
    }
    
    Rectangle {
        width: dashboardRoot.width
        height: mainColumn.height + 80
        gradient: Gradient {
            GradientStop { position: 0.0; color: backgroundGradient }
            GradientStop { position: 1.0; color: lightGrayColor }
        }
        
        ColumnLayout {
            id: mainColumn
            width: parent.width
            spacing: 32
            anchors.top: parent.top
            anchors.topMargin: 40
            
            // Header Section
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 80
                Layout.leftMargin: 40
                Layout.rightMargin: 40
                color: whiteColor
                radius: 16
                border.color: lightGrayColor
                border.width: 1
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 20
                    
                    // Logo y título
                    RowLayout {
                        spacing: 16
                        
                        Label {
                            text: "VISTA GENERAL - " + getPeriodLabel()
                            color: primaryColor
                            font.pixelSize: 24
                            font.bold: true
                        }
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    // Filtro de período jerárquico
                    RowLayout {
                        spacing: 8
                        
                        // Botón Hoy
                        Rectangle {
                            width: 60
                            height: 40
                            radius: 10
                            color: currentPeriodType === "hoy" ? primaryColor : backgroundGradient
                            border.color: lightGrayColor
                            border.width: 1
                            
                            Label {
                                anchors.centerIn: parent
                                text: "Hoy"
                                color: currentPeriodType === "hoy" ? whiteColor : darkGrayColor
                                font.pixelSize: 11
                                font.bold: currentPeriodType === "hoy"
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    currentPeriodType = "hoy"
                                    if (dashboardModel) {
                                        dashboardModel.cambiarPeriodo(currentPeriodType)
                                    }
                                    periodChanged(currentPeriodType)
                                }
                            }
                        }
                        
                        // Botón Esta Semana
                        Rectangle {
                            width: 90
                            height: 40
                            radius: 10
                            color: currentPeriodType === "semana" ? primaryColor : backgroundGradient
                            border.color: lightGrayColor
                            border.width: 1
                            
                            Label {
                                anchors.centerIn: parent
                                text: "Esta Semana"
                                color: currentPeriodType === "semana" ? whiteColor : darkGrayColor
                                font.pixelSize: 11
                                font.bold: currentPeriodType === "semana"
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    currentPeriodType = "semana"
                                    if (dashboardModel) {
                                        dashboardModel.cambiarPeriodo(currentPeriodType)
                                    }
                                    periodChanged(currentPeriodType)
                                }
                            }
                        }
                        
                        // ComboBox Año
                        ComboBox {
                            id: yearComboBox
                            width: 80
                            height: 40
                            model: getAvailableYears()
                            textRole: "label"
                            currentIndex: findCurrentYearIndex()
                            
                            background: Rectangle {
                                radius: 10
                                color: currentPeriodType === "año" ? primaryColor : backgroundGradient
                                border.color: lightGrayColor
                                border.width: 1
                            }
                            
                            contentItem: Label {
                                text: yearComboBox.displayText
                                color: currentPeriodType === "año" ? whiteColor : darkGrayColor
                                font.pixelSize: 11
                                font.bold: currentPeriodType === "año"
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: 12
                            }
                            
                            onActivated: {
                                selectedYear = model[index].value
                                currentPeriodType = "año"
                                
                                if (dashboardModel) {
                                    dashboardModel.cambiarFechaEspecifica(selectedMonth, selectedYear)
                                }
                                
                                updateMonthsForSelectedYear()
                                periodChanged(currentPeriodType)
                            }
                        }
                        
                        // ComboBox Mes
                        ComboBox {
                            id: monthComboBox
                            width: 120
                            height: 40
                            model: getAvailableMonths()
                            textRole: "label"
                            currentIndex: findCurrentMonthIndex()
                            
                            background: Rectangle {
                                radius: 10
                                color: currentPeriodType === "mes" ? primaryColor : backgroundGradient
                                border.color: lightGrayColor
                                border.width: 1
                            }
                            
                            contentItem: Label {
                                text: monthComboBox.displayText
                                color: currentPeriodType === "mes" ? whiteColor : darkGrayColor
                                font.pixelSize: 11
                                font.bold: currentPeriodType === "mes"
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: 12
                            }
                            
                            onActivated: {
                                selectedMonth = model[index].value
                                currentPeriodType = "mes"
                                
                                if (dashboardModel) {
                                    dashboardModel.cambiarFechaEspecifica(selectedMonth, selectedYear)
                                }
                                
                                periodChanged(currentPeriodType)
                            }
                        }
                    } 

                    RoundButton {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        Layout.alignment: Qt.AlignVCenter
                        text: "🔄"
                        
                        background: Rectangle {
                            color: whiteColor
                            radius: 20
                            border.color: lightGrayColor
                            border.width: 1
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
                            if (dashboardModel) {
                                dashboardModel.refrescarDatos()
                            }
                            if (inventarioModel) {
                                cargarAlertas()
                            }
                        }
                        
                        ToolTip.visible: hovered
                        ToolTip.text: "Refrescar datos"
                        
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: parent.scale = 1.1
                            onExited: parent.scale = 1.0
                        }
                    }
                }
            }
            
            // KPI Cards Grid (5 cards) - INGRESOS
            GridLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 40
                Layout.rightMargin: 40
                columns: 5
                columnSpacing: 24
                rowSpacing: 24
                                
                KPICard {
                    Layout.fillWidth: true
                    title: "Farmacia"
                    value: "Bs " + calculateFarmaciaTotal().toFixed(2)
                    icon: "Resources/iconos/farmacia.png"
                    cardColor: farmaciaColor
                    borderColor: farmaciaColor
                }

                KPICard {
                    Layout.fillWidth: true
                    title: "Consultas"
                    value: "Bs " + calculateConsultasTotal().toFixed(2)
                    icon: "Resources/iconos/Consulta.png"
                    cardColor: consultasColor
                    borderColor: consultasColor
                }

                KPICard {
                    Layout.fillWidth: true
                    title: "Laboratorio"
                    value: "Bs " + calculateLaboratorioTotal().toFixed(2)
                    icon: "Resources/iconos/Laboratorio.png"
                    cardColor: laboratorioColor
                    borderColor: laboratorioColor
                }

                KPICard {
                    Layout.fillWidth: true
                    title: "Enfermería"
                    value: "Bs " + calculateEnfermeriaTotal().toFixed(2)
                    icon: "Resources/iconos/Enfermeria.png"
                    cardColor: enfermeriaColor
                    borderColor: enfermeriaColor
                }

                KPICard {
                    Layout.fillWidth: true
                    title: "Servicios Básicos"
                    value: "Bs " + calculateServiciosBasicosTotal().toFixed(2)
                    icon: "Resources/iconos/ServiciosBasicos.png"
                    cardColor: serviciosColor
                    borderColor: serviciosColor
                }
            }
            
            // Main Content Grid (3 columns)
            GridLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 40
                Layout.rightMargin: 40
                columns: 3
                columnSpacing: 32
                rowSpacing: 32
                
                // Gráfico de líneas con áreas sombreadas
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "white"
                    radius: 12
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 16
                        
                        // Título de la gráfica
                        Label {
                            text: "Ingresos vs Egresos - " + getPeriodLabel()
                            font.pixelSize: 18
                            font.bold: true
                            color: textColor
                            Layout.alignment: Qt.AlignHCenter
                        }
                        
                        // Leyenda
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 24
                            
                            RowLayout {
                                spacing: 8
                                Rectangle {
                                    width: 12
                                    height: 12
                                    radius: 6
                                    color: "#10b981"
                                }
                                Label {
                                    text: "Ingresos: Bs " + calculateTotalIngresos().toFixed(2)
                                    color: "#6b7280"
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                            }
                            
                            RowLayout {
                                spacing: 8
                                Rectangle {
                                    width: 12
                                    height: 12
                                    radius: 6
                                    color: "#ef4444"
                                }
                                Label {
                                    text: "Egresos: Bs " + calculateTotalEgresos().toFixed(2)
                                    color: "#6b7280"
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                            }
                        }
                        
                        // Área del gráfico
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: "transparent"
                            
                            Canvas {
                                id: chartCanvas
                                anchors.fill: parent
                                anchors.leftMargin: 50
                                anchors.rightMargin: 20
                                anchors.topMargin: 20
                                anchors.bottomMargin: 40
                                
                                property var ingresosData: generateIngresosData()
                                property var egresosData: generateEgresosData()
                                property var labels: generateLabels()
                                property int hoveredIndex: -1
                                
                                function generateIngresosData() {
                                    var data = []
                                    var totalIngresos = calculateTotalIngresos()
                                    
                                    switch(currentPeriodType) {
                                        case "hoy":
                                            for (var i = 0; i < 24; i++) {
                                                data.push(totalIngresos * (0.5 + Math.random() * 0.5) / 24)
                                            }
                                            break
                                        case "semana":
                                            for (var i = 0; i < 7; i++) {
                                                data.push(totalIngresos * (0.6 + Math.random() * 0.4) / 7)
                                            }
                                            break
                                        case "mes":
                                            for (var i = 0; i < 4; i++) {
                                                data.push(totalIngresos * (0.7 + Math.random() * 0.3) / 4)
                                            }
                                            break
                                        case "año":
                                            for (var i = 0; i < 12; i++) {
                                                data.push(totalIngresos * (0.6 + Math.random() * 0.4) / 12)
                                            }
                                            break
                                    }
                                    return data
                                }
                                
                                function generateEgresosData() {
                                    var data = []
                                    var totalEgresos = calculateTotalEgresos()
                                    
                                    switch(currentPeriodType) {
                                        case "hoy":
                                            for (var i = 0; i < 24; i++) {
                                                data.push(totalEgresos * (0.4 + Math.random() * 0.6) / 24)
                                            }
                                            break
                                        case "semana":
                                            for (var i = 0; i < 7; i++) {
                                                data.push(totalEgresos * (0.5 + Math.random() * 0.5) / 7)
                                            }
                                            break
                                        case "mes":
                                            for (var i = 0; i < 4; i++) {
                                                data.push(totalEgresos * (0.6 + Math.random() * 0.4) / 4)
                                            }
                                            break
                                        case "año":
                                            for (var i = 0; i < 12; i++) {
                                                data.push(totalEgresos * (0.5 + Math.random() * 0.5) / 12)
                                            }
                                            break
                                    }
                                    return data
                                }
                                
                                function generateLabels() {
                                    switch(currentPeriodType) {
                                        case "hoy":
                                            return ["00", "02", "04", "06", "08", "10", "12", "14", "16", "18", "20", "22"]
                                        case "semana":
                                            return ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"]
                                        case "mes":
                                            return ["Sem 1", "Sem 2", "Sem 3", "Sem 4"]
                                        case "año":
                                            return ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]
                                        default:
                                            return ["Período"]
                                    }
                                }
                                
                                function updateChart() {
                                    if (dashboardModel) {
                                        ingresosData = dashboardModel.datosGraficoIngresos || []
                                        egresosData = dashboardModel.datosGraficoEgresos || []
                                        labels = generateLabels()
                                    } else {
                                        ingresosData = generateIngresosData()
                                        egresosData = generateEgresosData()
                                        labels = generateLabels()
                                    }
                                    requestPaint()
                                }
        
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    
                                    var maxValue = Math.max(Math.max.apply(Math, ingresosData), Math.max.apply(Math, egresosData)) * 1.2
                                    var minValue = 0
                                    var stepX = width / Math.max(1, (ingresosData.length - 1))
                                    var chartHeight = height - 20
                                    var startY = 10
                                    
                                    function getY(value) {
                                        return startY + chartHeight - ((value - minValue) / (maxValue - minValue)) * chartHeight
                                    }
                                    
                                    // Dibujar líneas de cuadrícula
                                    ctx.strokeStyle = "#f3f4f6"
                                    ctx.lineWidth = 1
                                    for (var i = 0; i <= 6; i++) {
                                        var value = minValue + (maxValue - minValue) * i / 6
                                        var y = getY(value)
                                        ctx.beginPath()
                                        ctx.moveTo(0, y)
                                        ctx.lineTo(width, y)
                                        ctx.stroke()
                                    }
                                    
                                    // Área sombreada de ingresos
                                    ctx.fillStyle = "rgba(16, 185, 129, 0.1)"
                                    ctx.beginPath()
                                    ctx.moveTo(0, getY(0))
                                    for (var i = 0; i < ingresosData.length; i++) {
                                        var x = i * stepX
                                        var y = getY(ingresosData[i])
                                        ctx.lineTo(x, y)
                                    }
                                    ctx.lineTo((ingresosData.length - 1) * stepX, getY(0))
                                    ctx.closePath()
                                    ctx.fill()
                                    
                                    // Área sombreada de egresos
                                    ctx.fillStyle = "rgba(239, 68, 68, 0.1)"
                                    ctx.beginPath()
                                    ctx.moveTo(0, getY(0))
                                    for (var i = 0; i < egresosData.length; i++) {
                                        var x = i * stepX
                                        var y = getY(egresosData[i])
                                        ctx.lineTo(x, y)
                                    }
                                    ctx.lineTo((egresosData.length - 1) * stepX, getY(0))
                                    ctx.closePath()
                                    ctx.fill()
                                    
                                    // Línea de ingresos
                                    ctx.strokeStyle = "#10b981"
                                    ctx.lineWidth = 3
                                    ctx.beginPath()
                                    for (var i = 0; i < ingresosData.length; i++) {
                                        var x = i * stepX
                                        var y = getY(ingresosData[i])
                                        if (i === 0) {
                                            ctx.moveTo(x, y)
                                        } else {
                                            ctx.lineTo(x, y)
                                        }
                                    }
                                    ctx.stroke()
                                    
                                    // Puntos de ingresos
                                    ctx.fillStyle = "#10b981"
                                    for (var i = 0; i < ingresosData.length; i++) {
                                        var x = i * stepX
                                        var y = getY(ingresosData[i])
                                        ctx.beginPath()
                                        ctx.arc(x, y, 4, 0, Math.PI * 2)
                                        ctx.fill()
                                    }
                                    
                                    // Línea de egresos
                                    ctx.strokeStyle = "#ef4444"
                                    ctx.lineWidth = 3
                                    ctx.beginPath()
                                    for (var i = 0; i < egresosData.length; i++) {
                                        var x = i * stepX
                                        var y = getY(egresosData[i])
                                        if (i === 0) {
                                            ctx.moveTo(x, y)
                                        } else {
                                            ctx.lineTo(x, y)
                                        }
                                    }
                                    ctx.stroke()
                                    
                                    // Puntos de egresos
                                    ctx.fillStyle = "#ef4444"
                                    for (var i = 0; i < egresosData.length; i++) {
                                        var x = i * stepX
                                        var y = getY(egresosData[i])
                                        ctx.beginPath()
                                        ctx.arc(x, y, 4, 0, Math.PI * 2)
                                        ctx.fill()
                                    }
                                    
                                    // Tooltip en hover
                                    if (hoveredIndex >= 0) {
                                        var hx = hoveredIndex * stepX
                                        var hy1 = getY(ingresosData[hoveredIndex])
                                        var hy2 = getY(egresosData[hoveredIndex])
                                        
                                        // Línea vertical
                                        ctx.strokeStyle = "#6b7280"
                                        ctx.lineWidth = 1
                                        ctx.setLineDash([5, 5])
                                        ctx.beginPath()
                                        ctx.moveTo(hx, 0)
                                        ctx.lineTo(hx, height)
                                        ctx.stroke()
                                        ctx.setLineDash([])
                                        
                                        // Punto destacado ingresos
                                        ctx.fillStyle = "#059669"
                                        ctx.beginPath()
                                        ctx.arc(hx, hy1, 6, 0, Math.PI * 2)
                                        ctx.fill()
                                        
                                        // Punto destacado egresos
                                        ctx.fillStyle = "#dc2626"
                                        ctx.beginPath()
                                        ctx.arc(hx, hy2, 6, 0, Math.PI * 2)
                                        ctx.fill()
                                    }
                                }
                                
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    
                                    onPositionChanged: {
                                        var stepX = chartCanvas.width / Math.max(1, (chartCanvas.ingresosData.length - 1))
                                        var index = Math.round(mouseX / stepX)
                                        if (index >= 0 && index < chartCanvas.ingresosData.length) {
                                            chartCanvas.hoveredIndex = index
                                            tooltip.visible = true
                                            tooltip.x = mouseX - tooltip.width / 2
                                            tooltip.y = mouseY - tooltip.height - 10
                                            tooltip.updateData(index)
                                        }
                                        chartCanvas.requestPaint()
                                    }
                                    
                                    onExited: {
                                        chartCanvas.hoveredIndex = -1
                                        tooltip.visible = false
                                        chartCanvas.requestPaint()
                                    }
                                }
                            }
                            
                            // Etiquetas del eje Y
                            Column {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.topMargin: 20
                                height: parent.height - 60
                                spacing: height / 6
                                
                                Repeater {
                                    model: {
                                        var maxValue = Math.max(calculateTotalIngresos(), calculateTotalEgresos())
                                        var labels = []
                                        for (var i = 6; i >= 0; i--) {
                                            var value = (maxValue * 1.2) * i / 6
                                            labels.push("Bs " + Math.round(value))
                                        }
                                        return labels
                                    }
                                    Label {
                                        text: modelData
                                        font.pixelSize: 10
                                        color: "#6b7280"
                                    }
                                }
                            }
                            
                            // Etiquetas del eje X
                            Item {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 50
                                anchors.rightMargin: 20
                                height: 20
                                
                                Repeater {
                                    model: chartCanvas.labels
                                    Label {
                                        text: modelData
                                        font.pixelSize: 10
                                        color: "#6b7280"
                                        x: index * ((parent.width) / Math.max(1, (chartCanvas.labels.length - 1))) - width/2
                                        anchors.bottom: parent.bottom
                                    }
                                }
                            }                           
                            
                            // Tooltip
                            Rectangle {
                                id: tooltip
                                width: 140
                                height: 80
                                color: "#1f2937"
                                radius: 8
                                visible: false
                                z: 100
                                
                                property string periodText: ""
                                property string ingresosText: ""
                                property string egresosText: ""
                                
                                function updateData(index) {
                                    if (index >= 0 && index < chartCanvas.labels.length) {
                                        periodText = chartCanvas.labels[index]
                                        ingresosText = "Ingresos: Bs " + chartCanvas.ingresosData[index].toFixed(2)
                                        egresosText = "Egresos: Bs " + chartCanvas.egresosData[index].toFixed(2)
                                    }
                                }
                                
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    
                                    Label {
                                        text: tooltip.periodText
                                        color: "white"
                                        font.pixelSize: 11
                                        font.bold: true
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                    Label {
                                        text: tooltip.ingresosText
                                        color: "#10b981"
                                        font.pixelSize: 10
                                    }
                                    Label {
                                        text: tooltip.egresosText
                                        color: "#ef4444"
                                        font.pixelSize: 10
                                    }
                                }
                            }
                        }
                    }
                }                
                
                Rectangle {
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    Layout.preferredHeight: 520
                    color: whiteColor
                    radius: 16
                    border.color: lightGrayColor
                    border.width: 1

                    property string filtroAlertaActual: "TODOS"






                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 16

                        RowLayout {
                            Layout.fillWidth: true
                            Label {
                                text: "🔔 ALERTAS DE INVENTARIO"
                                color: textColor
                                font.pixelSize: 18
                                font.bold: true
                            }
                            Item { Layout.fillWidth: true }
                            
                            RoundButton {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                text: "🔄"
                                onClicked: {
                                    if (inventarioModel) inventarioModel.obtener_alertas_inventario()
                                }
                                background: Rectangle { 
                                    color: "#f1f5f9"
                                    radius: 16 
                                }
                                contentItem: Label { 
                                    text: parent.text
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter 
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            
                            Repeater {
                                model: [
                                    { tag: "PRODUCTO VENCIDO", label: "VENCIDOS", color: "#ef4444", bg: "#fef2f2" },
                                    { tag: "PRODUCTO PRÓXIMO A VENCER", label: "PRÓX. VENCER", color: "#f59e0b", bg: "#fffbeb" },
                                    { tag: "STOCK BAJO", label: "STOCK BAJO", color: "#eab308", bg: "#fef3c7" },
                                    { tag: "TODOS", label: "TODOS", color: primaryColor, bg: "#f8fafc" }
                                ]
                                
                                delegate: Rectangle {
                                    width: 120
                                    height: 40
                                    radius: 8
                                    color: filtroAlertaActual === modelData.tag ? modelData.bg : "#f1f5f9"
                                    border.color: filtroAlertaActual === modelData.tag ? modelData.color : "#e2e8f0"
                                    border.width: 1
                                    
                                    RowLayout {
                                        anchors.centerIn: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        spacing: 6
                                        
                                        Label {
                                            text: modelData.tag === "PRODUCTO VENCIDO" ? "⚠️" :
                                                modelData.tag === "PRODUCTO PRÓXIMO A VENCER" ? "⏰" :
                                                modelData.tag === "STOCK BAJO" ? "📦" : "👥"
                                            font.pixelSize: 12
                                        }
                                        
                                        Label {
                                            text: modelData.label
                                            color: filtroAlertaActual === modelData.tag ? modelData.color : darkGrayColor
                                            font.bold: true
                                            font.pixelSize: 10
                                        }
                                        
                                        Label {
                                            text: "(" + (modelData.tag === "TODOS" ? alertasInventario.length : contarAlertasPorTipo(modelData.tag)) + ")"
                                            color: "#94a3b8"
                                            font.pixelSize: 9
                                        }
                                    }
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: filtroAlertaActual = modelData.tag
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 36
                            color: "#f8fafc"
                            radius: 6
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                spacing: 12
                                
                                Label {
                                    text: "PRODUCTO"
                                    Layout.preferredWidth: 200
                                    font.bold: true
                                    color: "#94a3b8"
                                    font.pixelSize: 11
                                }
                                Label {
                                    text: "ALERTAS POR LOTE"
                                    Layout.fillWidth: true
                                    font.bold: true
                                    color: "#94a3b8"
                                    font.pixelSize: 11
                                }
                            }
                        }

                        ListView {
                            id: vistaAgrupada
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 8
                            
                            model: obtenerDatosAgrupados(filtroAlertaActual)

                            delegate: Rectangle {
                                width: vistaAgrupada.width
                                height: colInfo.height + 24
                                color: "white"
                                radius: 8
                                border.color: "#e2e8f0"
                                border.width: 1

                                property var producto: modelData

                                RowLayout {
                                    id: colInfo
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.margins: 12
                                    spacing: 15

                                    ColumnLayout {
                                        Layout.preferredWidth: 200
                                        Layout.alignment: Qt.AlignTop
                                        spacing: 4
                                        
                                        Label {
                                            text: producto.nombre
                                            font.bold: true
                                            color: textColor
                                            font.pixelSize: 13
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }
                                        Label {
                                            text: "ID: " + producto.codigo
                                            color: darkGrayColor
                                            font.pixelSize: 11
                                        }
                                    }

                                    Column {
                                        Layout.fillWidth: true
                                        spacing: 6
                                        
                                        Repeater {
                                            model: producto.alertas
                                            
                                            delegate: Rectangle {
                                                property var alerta: modelData
                                                width: parent.width
                                                height: 40
                                                radius: 6
                                                color: obtenerBg(alerta.Tipo_Alerta)
                                                border.color: obtenerColor(alerta.Tipo_Alerta)
                                                border.width: 1.5
                                                
                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 10
                                                    anchors.rightMargin: 10
                                                    spacing: 12
                                                    
                                                    Label {
                                                        text: obtenerIcono(alerta.Tipo_Alerta)
                                                        font.pixelSize: 13
                                                    }
                                                    
                                                    ColumnLayout {
                                                        Layout.fillWidth: true
                                                        spacing: 3
                                                        
                                                        Label {
                                                            text: {
                                                                var tipo = alerta.Tipo_Alerta
                                                                if (tipo === "STOCK BAJO") {
                                                                    return "<b>STOCK BAJO</b>"
                                                                } else {
                                                                    var numeroLote = alerta.Detalle.match(/#\d+/)?.[0]?.replace("#", "") || "N/A"
                                                                    return "<b>Lote #" + numeroLote + " : " + tipo + "</b>"
                                                                }
                                                            }
                                                            textFormat: Text.RichText
                                                            color: obtenerColor(alerta.Tipo_Alerta)
                                                            font.pixelSize: 11
                                                            font.bold: true
                                                        }
                                                        
                                                        Label {
                                                            text: {
                                                                var tipo = alerta.Tipo_Alerta
                                                                if (tipo === "STOCK BAJO") {
                                                                    return "Quedan: " + (alerta.Stock_Actual || 0) + " unidades | Mínimo: " + (alerta.Minimo || 0)
                                                                } else {
                                                                    var fecha = alerta.Detalle.match(/\d{2}\/\d{2}\/\d{4}/)?.[0] || ""
                                                                    return "Fecha: " + fecha
                                                                }
                                                            }
                                                            color: obtenerColor(alerta.Tipo_Alerta)
                                                            font.pixelSize: 9
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                visible: vistaAgrupada.count === 0
                                width: parent.width - 20
                                height: 80
                                radius: 8
                                color: "#f8fafc"
                                border.color: "#e2e8f0"
                                border.width: 1

                                Label {
                                    anchors.centerIn: parent
                                    text: "✅ No hay alertas de inventario"
                                    color: "#64748b"
                                    font.pixelSize: 14
                                    font.bold: true
                                }
                            }
                        }
                    }
                }

            }
        }
    }
    
    // Componentes reutilizables
    component KPICard: Rectangle {
        property string title: ""
        property string value: ""
        property string icon: ""
        property color cardColor: primaryColor
        property color borderColor: primaryColor
        
        Layout.preferredHeight: 140
        color: borderColor
        radius: 16
        border.color: lightGrayColor
        border.width: 1
            
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 8
            
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 60
                Layout.preferredHeight: 60
                radius: 15
                color: Qt.rgba(255, 255, 255, 0.2)

                Image {
                    anchors.centerIn: parent
                    source: icon
                    width: 48
                    height: 48
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }
            }
            
            Label {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                text: value
                color: whiteColor
                font.pixelSize: 24
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
            }
            
            Label {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                text: title
                color: whiteColor
                font.pixelSize: 12
                font.bold: true 
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }
        
        Behavior on scale {
            NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
        }
        
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: parent.scale = 1.02
            onExited: parent.scale = 1.0
        }
    }
}