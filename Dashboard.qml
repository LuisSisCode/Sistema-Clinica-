import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15

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
    
    // Sistema de filtrado jerárquico: Año -> Mes
    property string currentPeriodType: "mes" // "hoy", "semana", "mes", "año"
    property int selectedMonth: new Date().getMonth() + 1  // Mes actual por defecto
    property int selectedYear: new Date().getFullYear()    // Año actual por defecto
    property date systemStartDate: new Date("2025-01-01") // Fecha de inicio del sistema
    
    // Datos base de cada módulo - SIMULADOS
    property var farmaciaVentas: [
        {fecha: "2025-07-16", total: 850.00},
        {fecha: "2025-07-15", total: 420.50},
        {fecha: "2025-07-14", total: 320.75},
        {fecha: "2025-07-13", total: 180.25},
        {fecha: "2025-07-12", total: 650.00},
        {fecha: "2025-07-11", total: 290.50},
        {fecha: "2025-07-10", total: 475.80},
        {fecha: "2025-07-09", total: 385.60},
        {fecha: "2025-07-08", total: 220.40},
        {fecha: "2025-07-07", total: 540.30},
        {fecha: "2025-06-30", total: 680.75},
        {fecha: "2025-06-29", total: 395.20},
        {fecha: "2025-06-28", total: 450.90},
        {fecha: "2025-06-15", total: 275.65},
        {fecha: "2025-06-10", total: 380.45},
        {fecha: "2025-05-31", total: 520.80},
        {fecha: "2025-05-25", total: 340.25},
        {fecha: "2025-05-20", total: 410.60},
        {fecha: "2025-04-30", total: 285.40},
        {fecha: "2025-04-15", total: 625.50},
        {fecha: "2025-03-31", total: 390.75},
        {fecha: "2025-03-15", total: 475.30},
        {fecha: "2025-02-28", total: 320.85},
        {fecha: "2025-02-15", total: 580.20},
        {fecha: "2025-01-31", total: 445.90},
        {fecha: "2025-01-15", total: 680.50},
        {fecha: "2024-12-31", total: 425.75},
        {fecha: "2024-12-15", total: 590.30},
        {fecha: "2024-11-30", total: 355.40},
        {fecha: "2024-11-15", total: 720.60}
    ]
    
    property var consultasHistorial: [
        {fecha: "2025-07-16", precio: 45.00},
        {fecha: "2025-07-16", precio: 35.00},
        {fecha: "2025-07-15", precio: 50.00},
        {fecha: "2025-07-14", precio: 40.00},
        {fecha: "2025-07-13", precio: 45.00},
        {fecha: "2025-07-12", precio: 35.00},
        {fecha: "2025-07-11", precio: 85.00},
        {fecha: "2025-07-10", precio: 40.00},
        {fecha: "2025-06-30", precio: 50.00},
        {fecha: "2025-06-29", precio: 45.00},
        {fecha: "2025-06-15", precio: 35.00},
        {fecha: "2025-05-31", precio: 40.00},
        {fecha: "2025-05-15", precio: 45.00},
        {fecha: "2025-04-30", precio: 85.00},
        {fecha: "2025-04-15", precio: 35.00},
        {fecha: "2025-03-31", precio: 50.00},
        {fecha: "2025-03-15", precio: 40.00},
        {fecha: "2025-02-28", precio: 45.00},
        {fecha: "2025-02-15", precio: 85.00},
        {fecha: "2025-01-31", precio: 40.00},
        {fecha: "2025-01-15", precio: 50.00},
        {fecha: "2024-12-31", precio: 45.00},
        {fecha: "2024-12-15", precio: 35.00},
        {fecha: "2024-11-30", precio: 85.00},
        {fecha: "2024-11-15", precio: 40.00}
    ]
    
    property var laboratorioHistorial: [
        {fecha: "2025-07-16", precio: 25.00},
        {fecha: "2025-07-16", precio: 35.00},
        {fecha: "2025-07-15", precio: 18.00},
        {fecha: "2025-07-14", precio: 22.00},
        {fecha: "2025-07-13", precio: 25.00},
        {fecha: "2025-07-12", precio: 35.00},
        {fecha: "2025-07-11", precio: 18.00},
        {fecha: "2025-07-10", precio: 25.00},
        {fecha: "2025-06-30", precio: 22.00},
        {fecha: "2025-06-29", precio: 35.00},
        {fecha: "2025-06-15", precio: 25.00},
        {fecha: "2025-05-31", precio: 18.00},
        {fecha: "2025-05-15", precio: 22.00},
        {fecha: "2025-04-30", precio: 25.00},
        {fecha: "2025-04-15", precio: 35.00},
        {fecha: "2025-03-31", precio: 18.00},
        {fecha: "2025-03-15", precio: 25.00},
        {fecha: "2025-02-28", precio: 22.00},
        {fecha: "2025-02-15", precio: 35.00},
        {fecha: "2025-01-31", precio: 25.00},
        {fecha: "2025-01-15", precio: 35.00},
        {fecha: "2024-12-31", precio: 22.00},
        {fecha: "2024-12-15", precio: 25.00},
        {fecha: "2024-11-30", precio: 18.00},
        {fecha: "2024-11-15", precio: 35.00}
    ]
    
    property var enfermeriaHistorial: [
        {fecha: "2025-07-16", precioTotal: 25.00},
        {fecha: "2025-07-16", precioTotal: 45.00},
        {fecha: "2025-07-15", precioTotal: 15.00},
        {fecha: "2025-07-14", precioTotal: 20.00},
        {fecha: "2025-07-13", precioTotal: 35.00},
        {fecha: "2025-07-12", precioTotal: 18.00},
        {fecha: "2025-07-11", precioTotal: 25.00},
        {fecha: "2025-07-10", precioTotal: 36.00},
        {fecha: "2025-06-30", precioTotal: 18.00},
        {fecha: "2025-06-29", precioTotal: 70.00},
        {fecha: "2025-06-15", precioTotal: 25.00},
        {fecha: "2025-05-31", precioTotal: 15.00},
        {fecha: "2025-05-15", precioTotal: 20.00},
        {fecha: "2025-04-30", precioTotal: 35.00},
        {fecha: "2025-04-15", precioTotal: 25.00},
        {fecha: "2025-03-31", precioTotal: 45.00},
        {fecha: "2025-03-15", precioTotal: 18.00},
        {fecha: "2025-02-28", precioTotal: 36.00},
        {fecha: "2025-02-15", precioTotal: 25.00},
        {fecha: "2025-01-31", precioTotal: 35.00},
        {fecha: "2025-01-15", precioTotal: 20.00},
        {fecha: "2024-12-31", precioTotal: 45.00},
        {fecha: "2024-12-15", precioTotal: 18.00},
        {fecha: "2024-11-30", precioTotal: 25.00},
        {fecha: "2024-11-15", precioTotal: 35.00}
    ]
    
    property var serviciosBasicosGastos: [
        {fechaGasto: "2025-07-16", monto: 450.00},
        {fechaGasto: "2025-07-15", monto: 280.50},
        {fechaGasto: "2025-07-14", monto: 350.00},
        {fechaGasto: "2025-07-13", monto: 125.75},
        {fechaGasto: "2025-07-12", monto: 890.00},
        {fechaGasto: "2025-07-11", monto: 650.75},
        {fechaGasto: "2025-07-10", monto: 320.25},
        {fechaGasto: "2025-06-30", monto: 475.60},
        {fechaGasto: "2025-06-29", monto: 385.40},
        {fechaGasto: "2025-06-15", monto: 220.80},
        {fechaGasto: "2025-05-31", monto: 540.30},
        {fechaGasto: "2025-05-15", monto: 295.45},
        {fechaGasto: "2025-04-30", monto: 180.70},
        {fechaGasto: "2025-04-15", monto: 425.90},
        {fechaGasto: "2025-03-31", monto: 350.25},
        {fechaGasto: "2025-03-15", monto: 680.50},
        {fechaGasto: "2025-02-28", monto: 450.75},
        {fechaGasto: "2025-02-15", monto: 320.40},
        {fechaGasto: "2025-01-31", monto: 275.60},
        {fechaGasto: "2025-01-15", monto: 590.20},
        {fechaGasto: "2024-12-31", monto: 385.80},
        {fechaGasto: "2024-12-15", monto: 445.30},
        {fechaGasto: "2024-11-30", monto: 350.40},
        {fechaGasto: "2024-11-15", monto: 275.80}
    ]
    
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
    
    // Funciones para calcular totales por módulo
    function calculateFarmaciaTotal() {
        var total = 0
        for (var i = 0; i < farmaciaVentas.length; i++) {
            if (isDateInSelectedPeriod(farmaciaVentas[i].fecha)) {
                total += farmaciaVentas[i].total
            }
        }
        return total
    }
    
    function calculateConsultasTotal() {
        var total = 0
        for (var i = 0; i < consultasHistorial.length; i++) {
            if (isDateInSelectedPeriod(consultasHistorial[i].fecha)) {
                total += consultasHistorial[i].precio
            }
        }
        return total
    }
    
    function calculateLaboratorioTotal() {
        var total = 0
        for (var i = 0; i < laboratorioHistorial.length; i++) {
            if (isDateInSelectedPeriod(laboratorioHistorial[i].fecha)) {
                total += laboratorioHistorial[i].precio
            }
        }
        return total
    }
    
    function calculateEnfermeriaTotal() {
        var total = 0
        for (var i = 0; i < enfermeriaHistorial.length; i++) {
            if (isDateInSelectedPeriod(enfermeriaHistorial[i].fecha)) {
                total += enfermeriaHistorial[i].precioTotal
            }
        }
        return total
    }
    
    function calculateServiciosBasicosTotal() {
        var total = 0
        for (var i = 0; i < serviciosBasicosGastos.length; i++) {
            if (isDateInSelectedPeriod(serviciosBasicosGastos[i].fechaGasto)) {
                total += serviciosBasicosGastos[i].monto
            }
        }
        return total
    }
    
    // Calcular totales consolidados
    function calculateTotalIngresos() {
        return calculateFarmaciaTotal() + calculateConsultasTotal() + 
               calculateLaboratorioTotal() + calculateEnfermeriaTotal()
    }
    
    function calculateTotalEgresos() {
        return calculateServiciosBasicosTotal()
    }
    
    // Función para obtener el nombre del período actual
    function getPeriodLabel() {
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
    
    // Signal para notificar cambios en el período
    signal periodChanged(string newPeriodType)
    
    Component.onCompleted: {
        if (profiler) {
            profiler.startTiming("dashboard_load")
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
                                
                                // Actualizar opciones del mes para el nuevo año
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
                                periodChanged(currentPeriodType)
                            }
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
                    icon: "💊"
                    cardColor: farmaciaColor
                    borderColor: farmaciaColor
                }
                
                KPICard {
                    Layout.fillWidth: true
                    title: "Consultas"
                    value: "Bs " + calculateConsultasTotal().toFixed(0)
                    icon: "🩺"
                    cardColor: consultasColor
                    borderColor: consultasColor
                }
                
                KPICard {
                    Layout.fillWidth: true
                    title: "Laboratorio"
                    value: "Bs " + calculateLaboratorioTotal().toFixed(0)
                    icon: "🔬"
                    cardColor: laboratorioColor
                    borderColor: laboratorioColor
                }
                
                KPICard {
                    Layout.fillWidth: true
                    title: "Enfermería"
                    value: "Bs " + calculateEnfermeriaTotal().toFixed(0)
                    icon: "👩‍⚕️"
                    cardColor: enfermeriaColor
                    borderColor: enfermeriaColor
                }
                
                KPICard {
                    Layout.fillWidth: true
                    title: "Servicios Básicos"
                    value: "Bs " + calculateServiciosBasicosTotal().toFixed(0)
                    icon: "⚡"
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
                                    ingresosData = generateIngresosData()
                                    egresosData = generateEgresosData()
                                    labels = generateLabels()
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
                                    Layout.preferredWidth: 120
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
                                    text: "VENCIMIENTO"
                                    color: darkGrayColor
                                    font.bold: true
                                    font.pixelSize: 11
                                }
                            }
                        }
                        
                        // Lista de alertas
                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            model: ListModel {
                                ListElement {
                                    producto: "Amoxicilina 500mg"
                                    cantidad: "45 unid."
                                    fecha: "20/07/2025"
                                    urgencia: "urgent"
                                }
                                ListElement {
                                    producto: "Paracetamol 750mg"
                                    cantidad: "120 unid."
                                    fecha: "25/07/2025"
                                    urgencia: "warning"
                                }
                                ListElement {
                                    producto: "Ibuprofeno 400mg"
                                    cantidad: "78 unid."
                                    fecha: "28/07/2025"
                                    urgencia: "warning"
                                }
                                ListElement {
                                    producto: "Omeprazol 20mg"
                                    cantidad: "156 unid."
                                    fecha: "10/08/2025"
                                    urgencia: "warning"
                                }
                            }
                            delegate: alertDelegate
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
                Layout.preferredWidth: 50
                Layout.preferredHeight: 50
                radius: 12
                color: Qt.rgba(255, 255, 255, 0.2)
                
                Label {
                    anchors.centerIn: parent
                    text: icon
                    font.pixelSize: 24
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
            color: modelData.urgencia === "urgent" ? 
                   Qt.rgba(229/255, 115/255, 115/255, 0.1) : 
                   Qt.rgba(255/255, 193/255, 7/255, 0.1)
            radius: 8
            
            // Borde izquierdo coloreado
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 4
                color: modelData.urgencia === "urgent" ? "#E57373" : "#ffc107"
                radius: 2
            }
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 16
                
                Label {
                    Layout.preferredWidth: 120
                    text: modelData.producto
                    color: textColor
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
                
                Label {
                    Layout.preferredWidth: 80
                    text: modelData.cantidad
                    color: textColor
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
                
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 24
                    radius: 12
                    color: modelData.urgencia === "urgent" ? "#fee2e2" : "#fef3c7"
                    
                    Label {
                        anchors.centerIn: parent
                        text: modelData.fecha
                        color: modelData.urgencia === "urgent" ? "#dc2626" : "#d97706"
                        font.pixelSize: 10
                        font.bold: true
                    }
                }
            }
        }
    }
    
    Component.onDestruction: {
        if (profiler) {
            profiler.endTiming("dashboard_load")
        }
    }
}