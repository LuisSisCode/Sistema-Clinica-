import QtQuick 2.15
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

        
    // 1. AGREGAR PROPIEDADES PARA DATOS REALES 
    property var productosProximosVencer: []
    property var productosVencidos: []
    property bool datosVencimientosCargados: false

    // CONEXIÓN CON MODELO REAL DE BD
    property var dashboardModel: appController ? appController.dashboard_model_instance : null
    
    // Referencia al inventarioModel para obtener datos de vencimientos
    property var inventarioModel: appController ? appController.inventario_model_instance : null

    // Sistema de filtrado jerárquico: Año -> Mes
    property string currentPeriodType: "mes" // "hoy", "semana", "mes", "año"
    property int selectedMonth: new Date().getMonth() + 1  // Mes actual por defecto
    property int selectedYear: new Date().getFullYear()    // Año actual por defecto
    property date systemStartDate: new Date("2025-01-01") // Fecha de inicio del sistema
    
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

    // 3. FUNCIÓN PARA FORMATEAR FECHA (agregar en las funciones de utilidad)
    function formatearFechaVencimiento(fechaStr) {
        if (!fechaStr) return "Sin fecha"
        
        try {
            var fecha = new Date(fechaStr)
            var hoy = new Date()
            var diferencia = Math.ceil((fecha - hoy) / (1000 * 60 * 60 * 24))
            
            if (diferencia < 0) {
                return "Vencido (" + Math.abs(diferencia) + " días)"
            } else if (diferencia === 0) {
                return "Vence hoy"
            } else if (diferencia === 1) {
                return "Vence mañana"
            } else {
                return "Vence en " + diferencia + " días"
            }
        } catch (e) {
            return fechaStr
        }
    }
    
    // MODIFICADO: Función para generar meses del año seleccionado
    function getAvailableMonths() {
        var months = []
        var currentDate = getCurrentDate()
        var startYear = systemStartDate.getFullYear()
        var startMonth = systemStartDate.getMonth()
        
        // Solo mostrar meses del año seleccionado
        var yearStart = (selectedYear === startYear) ? startMonth : 0
        var yearEnd = (selectedYear === currentDate.getFullYear()) ? currentDate.getMonth() : 11
        
        for (var month = yearStart; month <= yearEnd; month++) {
            months.push({
                value: month + 1,
                label: getMonthName(month)  // Solo el nombre del mes
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
        return years.reverse() // Más recientes primero
    }
    
    // MODIFICADO: Función para encontrar índice del mes actual
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
    
    // NUEVO: Función para actualizar meses cuando cambia el año
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
    
    // Función de filtrado actualizada
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

    // Funciones que ahora usan datos reales del modelo
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
    
    // Calcular totales consolidados
    function calculateTotalIngresos() {
        return dashboardModel ? dashboardModel.totalIngresos : 0
    }
    
    function calculateTotalEgresos() {
        return dashboardModel ? dashboardModel.totalEgresos : 0
    }
    
    // Función para obtener el nombre del período actual
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

    // 2. FUNCIÓN PARA CARGAR PRODUCTOS POR VENCER (agregar en las funciones)
    function cargarProductosVencimientos() {
        if (!inventarioModel) {
            console.log("⚠️ InventarioModel no disponible para vencimientos")
            return
        }
        
        try {
            console.log("📅 Cargando productos próximos a vencer...")
            
            // Obtener lotes próximos a vencer (60 días)
            if (typeof inventarioModel.get_lotes_por_vencer === 'function') {
                var lotesProximos = inventarioModel.get_lotes_por_vencer(60) || []
                
                // Convertir lotes a productos únicos
                var productosUnicos = {}
                
                for (var i = 0; i < lotesProximos.length; i++) {
                    var lote = lotesProximos[i]
                    var stockLote = (lote.Cantidad_Caja || 0) * (lote.Cantidad_Unitario || 0)
                    
                    if (stockLote > 0) {  // Solo lotes con stock
                        var codigo = lote.Codigo
                        
                        if (!productosUnicos[codigo]) {
                            productosUnicos[codigo] = {
                                producto: lote.Producto_Nombre || lote.Nombre || codigo,
                                codigo: codigo,
                                cantidad: stockLote,
                                fecha: lote.Fecha_Vencimiento,
                                dias_para_vencer: lote.Dias_Para_Vencer || 0,
                                urgencia: (lote.Dias_Para_Vencer <= 7) ? "urgent" : "normal"
                            }
                        } else {
                            // Si ya existe, sumar stock y usar la fecha más próxima
                            productosUnicos[codigo].cantidad += stockLote
                            if (lote.Dias_Para_Vencer < productosUnicos[codigo].dias_para_vencer) {
                                productosUnicos[codigo].fecha = lote.Fecha_Vencimiento
                                productosUnicos[codigo].dias_para_vencer = lote.Dias_Para_Vencer
                                productosUnicos[codigo].urgencia = (lote.Dias_Para_Vencer <= 7) ? "urgent" : "normal"
                            }
                        }
                    }
                }
                
                // Convertir objeto a array
                productosProximosVencer = []
                for (var codigo in productosUnicos) {
                    productosProximosVencer.push(productosUnicos[codigo])
                }
                
                console.log("✅ Productos próximos a vencer cargados:", productosProximosVencer.length)
                
            } else {
                console.log("⚠️ Método get_lotes_por_vencer no disponible")
            }
            
            // Obtener productos vencidos
            if (typeof inventarioModel.get_lotes_vencidos === 'function') {
                var lotesVencidos = inventarioModel.get_lotes_vencidos() || []
                
                var vencidosUnicos = {}
                
                for (var j = 0; j < lotesVencidos.length; j++) {
                    var loteVencido = lotesVencidos[j]
                    var stockVencido = (loteVencido.Cantidad_Caja || 0) * (loteVencido.Cantidad_Unitario || 0)
                    
                    if (stockVencido > 0) {
                        var codigoVencido = loteVencido.Codigo
                        
                        if (!vencidosUnicos[codigoVencido]) {
                            vencidosUnicos[codigoVencido] = {
                                producto: loteVencido.Producto_Nombre || loteVencido.Nombre || codigoVencido,
                                codigo: codigoVencido,
                                cantidad: stockVencido,
                                fecha: loteVencido.Fecha_Vencimiento,
                                dias_vencido: loteVencido.Dias_Vencido || 0,
                                urgencia: "expired"
                            }
                        } else {
                            vencidosUnicos[codigoVencido].cantidad += stockVencido
                        }
                    }
                }
                
                productosVencidos = []
                for (var codigoV in vencidosUnicos) {
                    productosVencidos.push(vencidosUnicos[codigoV])
                }
                
                console.log("🚨 Productos vencidos cargados:", productosVencidos.length)
            }
            
            datosVencimientosCargados = true
            
        } catch (error) {
            console.log("❌ Error cargando vencimientos:", error)
            productosProximosVencer = []
            productosVencidos = []
            datosVencimientosCargados = false
        }
    }
    

    // Signal para notificar cambios en el período
    signal periodChanged(string newPeriodType)
    
    Component.onCompleted: {
        // Inicializar conexión con modelo
        if (dashboardModel) {
            console.log("📊 Dashboard conectado con modelo de BD")
            dashboardModel.cambiarPeriodo(currentPeriodType)
        } else {
            console.log("⚠️ Dashboard model no disponible")
        }
        
        // NUEVO: Cargar datos de vencimientos
        if (inventarioModel) {
            console.log("📅 Cargando datos de vencimientos al inicializar...")
            Qt.callLater(cargarProductosVencimientos)
        } else {
            console.log("⚠️ InventarioModel no disponible para vencimientos")
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
                    
                    // MODIFICADO: Filtro de período jerárquico
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
                            
                            Behavior on color { ColorAnimation { duration: 200 } }
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
                            
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                        
                        // MODIFICADO: ComboBox Año (Primero en el flujo jerárquico)
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
                        
                        // MODIFICADO: ComboBox Mes (Dependiente del año seleccionado)
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
                                console.log("🔄 Refrescando datos manualmente...")
                                dashboardModel.refrescarDatos()
                            }
                        }
                        
                        ToolTip.visible: hovered
                        ToolTip.text: "Refrescar datos"
                        
                        // Efecto hover
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: parent.scale = 1.1
                            onExited: parent.scale = 1.0
                            onClicked: parent.clicked()
                        }
                        
                        Behavior on scale {
                            NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                        }
                    }
                }
            }
            
            // KPI Cards Grid (5 cards) - ACTUALIZADAS CON DATOS REALES
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
                    value: "Bs " + calculateFarmaciaTotal().toFixed(0)
                    icon: "Resources/iconos/farmacia.png"  // Cambiar de "💊"
                    cardColor: farmaciaColor
                    borderColor: farmaciaColor
                }

                KPICard {
                    Layout.fillWidth: true
                    title: "Consultas"
                    value: "Bs " + calculateConsultasTotal().toFixed(0)
                    icon: "Resources/iconos/Consulta.png"  // Cambiar de "🩺"
                    cardColor: consultasColor
                    borderColor: consultasColor
                }

                KPICard {
                    Layout.fillWidth: true
                    title: "Laboratorio"
                    value: "Bs " + calculateLaboratorioTotal().toFixed(0)
                    icon: "Resources/iconos/Laboratorio.png"  // Cambiar de "🔬"
                    cardColor: laboratorioColor
                    borderColor: laboratorioColor
                }

                KPICard {
                    Layout.fillWidth: true
                    title: "Enfermería"
                    value: "Bs " + calculateEnfermeriaTotal().toFixed(0)
                    icon: "Resources/iconos/Enfermeria.png"  // Cambiar de "👩‍⚕️"
                    cardColor: enfermeriaColor
                    borderColor: enfermeriaColor
                }

                KPICard {
                    Layout.fillWidth: true
                    title: "Servicios Básicos"
                    value: "Bs " + calculateServiciosBasicosTotal().toFixed(0)
                    icon: "Resources/iconos/ServiciosBasicos.png"  // Cambiar de "⚡"
                    cardColor: serviciosColor
                    borderColor: serviciosColor
                }
            }
            
            // Main Content Grid (2 columns)
            GridLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 40
                Layout.rightMargin: 40
                columns: 3
                columnSpacing: 32
                rowSpacing: 32
                
                // Gráfico de líneas con áreas sombreadas - ACTUALIZADO
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
                                    text: "Ingresos: Bs " + calculateTotalIngresos().toFixed(0)
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
                                    text: "Egresos: Bs " + calculateTotalEgresos().toFixed(0)
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
                                
                                // Datos dinámicos basados en el período actual
                                property var ingresosData: generateIngresosData()
                                property var egresosData: generateEgresosData()
                                property var labels: generateLabels()
                                property int hoveredIndex: -1
                                
                                function generateIngresosData() {
                                    var data = []
                                    var totalIngresos = calculateTotalIngresos()
                                    
                                    // Generar datos basados en el período
                                    switch(currentPeriodType) {
                                        case "hoy":
                                            // Datos por horas del día actual
                                            for (var i = 0; i < 24; i++) {
                                                data.push(totalIngresos * (0.5 + Math.random() * 0.5) / 24)
                                            }
                                            break
                                        case "semana":
                                            // Datos por días de la semana
                                            for (var i = 0; i < 7; i++) {
                                                data.push(totalIngresos * (0.6 + Math.random() * 0.4) / 7)
                                            }
                                            break
                                        case "mes":
                                            // Datos por semanas del mes
                                            for (var i = 0; i < 4; i++) {
                                                data.push(totalIngresos * (0.7 + Math.random() * 0.3) / 4)
                                            }
                                            break
                                        case "año":
                                            // Datos por meses del año
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
                                        // Usar datos reales del modelo
                                        ingresosData = dashboardModel.datosGraficoIngresos || []
                                        egresosData = dashboardModel.datosGraficoEgresos || []
                                        labels = generateLabels()
                                    } else {
                                        // Fallback a datos simulados
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
                                    
                                    // Dibujar líneas de cuadrícula horizontales
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
                            
                            // Tooltip actualizado
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
                                        ingresosText = "Ingresos: Bs" + Math.round(chartCanvas.ingresosData[index])
                                        egresosText = "Egresos: Bs" + Math.round(chartCanvas.egresosData[index])
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
                
                // Alertas de Vencimiento - DATOS DINÁMICOS
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 400
                    color: whiteColor
                    radius: 16
                    border.color: lightGrayColor
                    border.width: 1
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 24
                        spacing: 16
                        
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            
                            Rectangle {
                                width: 24
                                height: 24
                                radius: 6
                                color: dangerColor
                                
                                Label {
                                    anchors.centerIn: parent
                                    text: "⚠️"
                                    color: whiteColor
                                    font.pixelSize: 12
                                }
                            }
                            
                            Label {
                                text: "Alerta: Productos por Vencer"
                                color: textColor
                                font.pixelSize: 18
                                font.bold: true
                            }
                            
                            Item { Layout.fillWidth: true }
                            
                            // Botón para actualizar vencimientos
                            Button {
                                Layout.preferredWidth: 40
                                Layout.preferredHeight: 40
                                text: "🔄"
                                
                                background: Rectangle {
                                    color: parent.pressed ? Qt.darker(blueColor, 1.2) : blueColor
                                    radius: 20
                                    
                                    Behavior on color {
                                        ColorAnimation { duration: 150 }
                                    }
                                }
                                
                                contentItem: Label {
                                    text: parent.text
                                    color: whiteColor
                                    font.bold: true
                                    font.pixelSize: 14
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                
                                onClicked: {
                                    console.log("🔄 Actualizando vencimientos manualmente...")
                                    cargarProductosVencimientos()
                                }
                                
                                ToolTip.visible: hovered
                                ToolTip.text: "Actualizar vencimientos"
                            }
                            
                            // Contador de alertas
                            Rectangle {
                                Layout.preferredWidth: 120
                                Layout.preferredHeight: 32
                                radius: 16
                                color: dangerColor
                                
                                Label {
                                    anchors.centerIn: parent
                                    text: "Total: " + (productosProximosVencer.length + productosVencidos.length)
                                    color: whiteColor
                                    font.bold: true
                                    font.pixelSize: 11
                                }
                            }
                        }
                        
                        // Header de la tabla
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            color: backgroundGradient
                            radius: 8
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 16
                                
                                Label {
                                    Layout.preferredWidth: 200
                                    text: "PRODUCTO"
                                    color: darkGrayColor
                                    font.bold: true
                                    font.pixelSize: 11
                                }
                                
                                Label {
                                    Layout.preferredWidth: 80
                                    text: "CANTIDAD"
                                    color: darkGrayColor
                                    font.bold: true
                                    font.pixelSize: 11
                                }
                                
                                Label {
                                    Layout.fillWidth: true
                                    text: "ESTADO VENCIMIENTO"
                                    color: darkGrayColor
                                    font.bold: true
                                    font.pixelSize: 11
                                }
                            }
                        }
                        
                        // Lista de alertas REAL desde BD
                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            
                            // Modelo combinado: productos vencidos + próximos a vencer
                            model: {
                                var alertasCombinadas = []
                                
                                // Agregar productos vencidos (prioridad alta)
                                for (var i = 0; i < productosVencidos.length; i++) {
                                    alertasCombinadas.push({
                                        producto: productosVencidos[i].producto,
                                        codigo: productosVencidos[i].codigo,
                                        cantidad: productosVencidos[i].cantidad + " unid.",
                                        fecha: productosVencidos[i].fecha,
                                        estado: "VENCIDO",
                                        urgencia: "expired",
                                        dias: productosVencidos[i].dias_vencido
                                    })
                                }
                                
                                // Agregar productos próximos a vencer
                                for (var j = 0; j < productosProximosVencer.length; j++) {
                                    alertasCombinadas.push({
                                        producto: productosProximosVencer[j].producto,
                                        codigo: productosProximosVencer[j].codigo,
                                        cantidad: productosProximosVencer[j].cantidad + " unid.",
                                        fecha: productosProximosVencer[j].fecha,
                                        estado: formatearFechaVencimiento(productosProximosVencer[j].fecha),
                                        urgencia: productosProximosVencer[j].urgencia,
                                        dias: productosProximosVencer[j].dias_para_vencer
                                    })
                                }
                                
                                return alertasCombinadas
                            }
                            
                            delegate: Rectangle {
                                width: ListView.view.width
                                height: 55
                                color: {
                                    switch(modelData.urgencia) {
                                        case "expired": return Qt.rgba(239/255, 68/255, 68/255, 0.15)
                                        case "urgent": return Qt.rgba(229/255, 115/255, 115/255, 0.1)
                                        default: return Qt.rgba(255/255, 193/255, 7/255, 0.1)
                                    }
                                }
                                radius: 8
                                
                                // Borde izquierdo coloreado según urgencia
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: 4
                                    color: {
                                        switch(modelData.urgencia) {
                                            case "expired": return "#ef4444"
                                            case "urgent": return "#E57373"
                                            default: return "#ffc107"
                                        }
                                    }
                                    radius: 2
                                }
                                
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 16
                                    
                                    ColumnLayout {
                                        Layout.preferredWidth: 200
                                        spacing: 4
                                        
                                        Label {
                                            Layout.fillWidth: true
                                            text: modelData.producto
                                            color: textColor
                                            font.bold: true
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                        }
                                        
                                        Label {
                                            Layout.fillWidth: true
                                            text: "Código: " + modelData.codigo
                                            color: darkGrayColor
                                            font.pixelSize: 9
                                            elide: Text.ElideRight
                                        }
                                    }
                                    
                                    Label {
                                        Layout.preferredWidth: 80
                                        text: modelData.cantidad
                                        color: textColor
                                        font.pixelSize: 12
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }
                                    
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 28
                                        radius: 14
                                        color: {
                                            switch(modelData.urgencia) {
                                                case "expired": return "#fee2e2"
                                                case "urgent": return "#fecaca"
                                                default: return "#fef3c7"
                                            }
                                        }
                                        
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 8
                                            
                                            Label {
                                                text: {
                                                    switch(modelData.urgencia) {
                                                        case "expired": return "💀"
                                                        case "urgent": return "🚨"
                                                        default: return "⚠️"
                                                    }
                                                }
                                                font.pixelSize: 12
                                            }
                                            
                                            Label {
                                                Layout.fillWidth: true
                                                text: modelData.estado
                                                color: {
                                                    switch(modelData.urgencia) {
                                                        case "expired": return "#dc2626"
                                                        case "urgent": return "#dc2626"
                                                        default: return "#d97706"
                                                    }
                                                }
                                                font.pixelSize: 10
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }
                                
                                // Efecto hover
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: parent.color = Qt.darker(parent.color, 1.1)
                                    onExited: parent.color = Qt.lighter(parent.color, 1.1)
                                }
                            }
                            
                            // Estado cuando no hay datos
                            Item {
                                anchors.centerIn: parent
                                visible: !datosVencimientosCargados || (productosProximosVencer.length === 0 && productosVencidos.length === 0)
                                width: 250
                                height: 120
                                
                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 12
                                    
                                    Label {
                                        text: datosVencimientosCargados ? "✅" : "⏳"
                                        font.pixelSize: 32
                                        color: lightGrayColor
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                    
                                    Label {
                                        text: datosVencimientosCargados ? "No hay productos próximos a vencer" : "Cargando vencimientos..."
                                        color: darkGrayColor
                                        font.pixelSize: 14
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                    
                                    // Botón de carga manual si no hay datos
                                    Button {
                                        visible: datosVencimientosCargados && productosProximosVencer.length === 0
                                        Layout.alignment: Qt.AlignHCenter
                                        text: "🔄 Verificar Nuevamente"
                                        
                                        background: Rectangle {
                                            color: parent.pressed ? Qt.darker(blueColor, 1.2) : blueColor
                                            radius: 6
                                        }
                                        
                                        contentItem: Label {
                                            text: parent.text
                                            color: whiteColor
                                            font.bold: true
                                            font.pixelSize: 11
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        
                                        onClicked: {
                                            cargarProductosVencimientos()
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
    
    // Conexiones para actualizar la gráfica cuando cambie el período
    Connections {
        target: dashboardRoot
        function onPeriodChanged(newPeriodType) {
            chartCanvas.updateChart()
        }
    }

    Connections {
        target: dashboardModel
        function onDashboardUpdated() {
            console.log("📊 Dashboard actualizado desde BD")
            // Forzar actualización de la UI
            if (chartCanvas) {
                chartCanvas.updateChart()
            }
        }
        function onErrorOccurred(mensaje) {
            console.log("❌ Error en dashboard:", mensaje)
        }
    }

    // 4. AGREGAR CONEXIONES (después de las conexiones existentes)
    Connections {
        target: inventarioModel
        function onProductosChanged() {
            console.log("📦 Productos actualizados - Recargando vencimientos")
            Qt.callLater(cargarProductosVencimientos)
        }
        function onLotesChanged() {
            console.log("📅 Lotes cambiaron - Actualizando vencimientos")
            Qt.callLater(cargarProductosVencimientos)
        }
    }
    
    // Componentes
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
    
    Component {
        id: alertDelegate
        
        Rectangle {
            width: ListView.view.width
            height: 48
            color: model.urgencia === "urgent" ? 
                   Qt.rgba(229/255, 115/255, 115/255, 0.1) : 
                   Qt.rgba(255/255, 193/255, 7/255, 0.1)
            radius: 8
            
            // Borde izquierdo coloreado
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 4
                color: model.urgencia === "urgent" ? "#E57373" : "#ffc107"
                radius: 2
            }
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 16
                
                Label {
                    Layout.preferredWidth: 120
                    text: model.producto
                    color: textColor
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
                
                Label {
                    Layout.preferredWidth: 80
                    text: model.cantidad
                    color: textColor
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
                
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 24
                    radius: 12
                    color: model.urgencia === "urgent" ? "#fee2e2" : "#fef3c7"
                    
                    Label {
                        anchors.centerIn: parent
                        text: model.fecha
                        color: model.urgencia === "urgent" ? "#dc2626" : "#d97706"
                        font.pixelSize: 10
                        font.bold: true
                    }
                }
            }
        }
    }
}