import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import QtQuick.Pdf 5.15
import Qt.labs.platform 1.1

Item {
    id: reportesRoot
    objectName: "reportesRoot"

    // PROPIEDAD PARA EL MODELO DE REPORTES
    property var reportesModel: appController ? appController.reportes_model_instance : null
    
    // Colores del tema PROFESIONAL
    readonly property color primaryColor: "#2C3E50"
    readonly property color successColor: "#27AE60"
    readonly property color dangerColor: "#E74C3C"
    readonly property color warningColor: "#F39C12"
    readonly property color lightGrayColor: "#ECF0F1"
    readonly property color textColor: "#2C3E50"
    readonly property color whiteColor: "#FFFFFF"
    readonly property color darkGrayColor: "#7F8C8D"
    readonly property color infoColor: "#34495E"
    readonly property color violetColor: "#8E44AD"
    readonly property color blackColor: "#000000"
    readonly property color zebraColor: "#F8F9FA"
    
    // Estados del módulo
    property int vistaActual: 0
    property int tipoReporteSeleccionado: 0
    property string fechaDesde: ""
    property string fechaHasta: ""
    property bool reporteGenerado: false
    property var datosReporte: []
    property var resumenReporte: ({})

    // Tipos de reportes disponibles
    property var tiposReportes: [
        {
            id: 0,
            nombre: "Seleccionar tipo de reporte...",
            modulo: "",
            icono: "Resources/iconos/reportes.png",
            descripcion: "Seleccione el tipo de reporte que desea generar",
            color: lightGrayColor
        },
        {
            id: 1,
            nombre: "Ventas de Farmacia",
            modulo: "farmacia",
            icono: "💰",
            descripcion: "Reporte detallado de todas las ventas realizadas en farmacia",
            color: primaryColor
        },
        {
            id: 2,
            nombre: "Inventario de Productos",
            modulo: "farmacia",
            icono: "📦",
            descripcion: "Estado actual del inventario con stock y valores",
            color: infoColor
        },
        {
            id: 3,
            nombre: "Compras de Farmacia",
            modulo: "farmacia",
            icono: "🚚",
            descripcion: "Historial de compras realizadas a proveedores",
            color: violetColor
        },
        {
            id: 4,
            nombre: "Consultas Médicas",
            modulo: "consultas",
            icono: "🩺",
            descripcion: "Registro de consultas médicas por especialidad y doctor",
            color: primaryColor
        },
        {
            id: 5,
            nombre: "Análisis de Laboratorio",
            modulo: "laboratorio",
            icono: "🧪",
            descripcion: "Historial de análisis realizados en laboratorio",
            color: "#7F8C8D"
        },
        {
            id: 6,
            nombre: "Procedimientos de Enfermería",
            modulo: "enfermeria",
            icono: "💉",
            descripcion: "Registro de procedimientos realizados por enfermería",
            color: "#95A5A6"
        },
        {
            id: 7,
            nombre: "Gastos Operativos",
            modulo: "servicios",
            icono: "💳",
            descripcion: "Detalle de gastos en servicios básicos y operaciones",
            color: dangerColor
        },
        {
            id: 8,
            nombre: "Reporte Financiero Consolidado",
            modulo: "consolidado",
            icono: "📈",
            descripcion: "Resumen financiero de todos los módulos",
            color: blackColor
        }
    ]

    // CONEXIONES AL MODELO DE REPORTES
    Connections {
        target: reportesModel
        function onReporteGenerado(success, message, totalRegistros) {
            if (success) {
                console.log("✅ Reporte generado:", message, "Registros:", totalRegistros)
                if (totalRegistros > 0) {
                    datosReporte = reportesModel.datosReporte
                    resumenReporte = reportesModel.resumenReporte
                    reporteGenerado = true
                    vistaActual = 1
                    mostrarNotificacionGeneracion(message, totalRegistros)
                } else {
                    mostrarNotificacionSinDatos()
                }
            } else {
                console.log("❌ Error generando reporte:", message)
                mostrarNotificacionError(message)
            }
        }
        
        function onReporteError(title, message) {
            console.log("❌ Error en reporte:", title, "-", message)
            mostrarNotificacionError(message)
        }
        
        function onLoadingChanged() {
            console.log("Loading changed:", reportesModel ? reportesModel.loading : false)
        }
    }
    
    StackLayout {
        anchors.fill: parent
        currentIndex: vistaActual
        
        // VISTA 0: CONFIGURACIÓN INICIAL
        Item {
            id: vistaConfiguracion
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 40
                spacing: 32
                
                // Header del módulo PROFESIONAL
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 120
                    color: whiteColor
                    radius: 8
                    border.color: "#E0E6ED"
                    border.width: 1
                    
                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: 2
                        anchors.leftMargin: 2
                        color: "#08000000"
                        radius: parent.radius
                        z: -1
                    }
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 30
                        spacing: 24
                        
                        Rectangle {
                            Layout.preferredWidth: 70
                            Layout.preferredHeight: 70
                            color: primaryColor
                            radius: 8
                            
                            Image {
                                anchors.centerIn: parent
                                source: "Resources/iconos/reportes.png"
                                width: 32
                                height: 32
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }
                        }
                        
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            
                            Label {
                                text: "Centro de Reportes Profesional"
                                font.pixelSize: 26
                                font.bold: true
                                color: textColor
                                font.family: "Segoe UI"
                            }
                            
                            Label {
                                text: "Generación de reportes ejecutivos y análisis estadísticos del sistema"
                                font.pixelSize: 14
                                color: darkGrayColor
                                font.family: "Segoe UI"
                            }
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        Rectangle {
                            Layout.preferredWidth: 220
                            Layout.preferredHeight: 70
                            color: "#F8F9FA"
                            radius: 8
                            border.color: "#E9ECEF"
                            border.width: 1
                            
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 4
                                
                                Label {
                                    text: "ESTADO DEL SISTEMA"
                                    font.pixelSize: 10
                                    color: darkGrayColor
                                    font.bold: true
                                    font.family: "Segoe UI"
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                
                                Label {
                                    text: "🟢 Todos los módulos operativos"
                                    font.pixelSize: 12
                                    color: successColor
                                    font.bold: true
                                    font.family: "Segoe UI"
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }
                    }
                }
                
                // Sección de configuración del reporte
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 320
                    color: whiteColor
                    radius: 8
                    border.color: "#E0E6ED"
                    border.width: 1
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 24
                        spacing: 20
                        
                        // Título de sección
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            
                            Rectangle {
                                width: 4
                                height: 24
                                color: primaryColor
                                radius: 2
                            }
                            
                            Label {
                                text: "Configuración del Reporte"
                                font.pixelSize: 18
                                font.bold: true
                                color: textColor
                                font.family: "Segoe UI"
                            }
                            
                            Item { Layout.fillWidth: true }
                            
                            Button {
                                text: "🧹 Limpiar"
                                Layout.preferredHeight: 32
                                visible: tipoReporteSeleccionado > 0
                                
                                background: Rectangle {
                                    color: parent.pressed ? Qt.darker(lightGrayColor, 1.1) : lightGrayColor
                                    radius: 4
                                    border.color: "#BDC3C7"
                                    border.width: 1
                                }
                                
                                contentItem: Label {
                                    text: parent.text
                                    color: textColor
                                    font.bold: true
                                    font.pixelSize: 12
                                    font.family: "Segoe UI"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                
                                onClicked: limpiarFormulario()
                            }
                        }
                        
                        // Formulario de configuración
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 3
                            columnSpacing: 20
                            rowSpacing: 16
                            
                            // Tipo de Reporte
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                
                                Label {
                                    text: "Tipo de Reporte:"
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: textColor
                                    font.family: "Segoe UI"
                                }
                                
                                ComboBox {
                                    id: tipoReporteCombo
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 45
                                    
                                    model: ListModel {
                                        id: tiposReportesModel
                                        Component.onCompleted: {
                                            for (var i = 0; i < tiposReportes.length; i++) {
                                                append(tiposReportes[i])
                                            }
                                        }
                                    }
                                    
                                    textRole: "nombre"
                                    
                                    background: Rectangle {
                                        color: whiteColor
                                        border.color: parent.activeFocus ? primaryColor : "#E0E6ED"
                                        border.width: parent.activeFocus ? 2 : 1
                                        radius: 4
                                    }
                                    
                                    contentItem: RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 8
                                        
                                        Label {
                                            text: tipoReporteCombo.currentIndex >= 0 ? 
                                                  tiposReportesModel.get(tipoReporteCombo.currentIndex).icono : "📊"
                                            font.pixelSize: 16
                                        }
                                        
                                        Label {
                                            Layout.fillWidth: true
                                            text: tipoReporteCombo.displayText
                                            font.pixelSize: 13
                                            color: textColor
                                            font.family: "Segoe UI"
                                            elide: Text.ElideRight
                                        }
                                    }
                                    
                                    onCurrentIndexChanged: {
                                        if (currentIndex >= 0) {
                                            tipoReporteSeleccionado = currentIndex
                                        }
                                    }
                                }
                            }
                            
                            // Fecha Desde
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                
                                Label {
                                    text: "Fecha Desde:"
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: textColor
                                    font.family: "Segoe UI"
                                }
                                
                                TextField {
                                    id: fechaDesdeField
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 45
                                    placeholderText: "DD/MM/YYYY"
                                    font.pixelSize: 13
                                    font.family: "Segoe UI"
                                    
                                    background: Rectangle {
                                        color: whiteColor
                                        border.color: parent.activeFocus ? primaryColor : "#E0E6ED"
                                        border.width: parent.activeFocus ? 2 : 1
                                        radius: 4
                                    }
                                    
                                    onTextChanged: {
                                        fechaDesde = text
                                    }
                                }
                            }
                            
                            // Fecha Hasta
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                
                                Label {
                                    text: "Fecha Hasta:"
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: textColor
                                    font.family: "Segoe UI"
                                }
                                
                                TextField {
                                    id: fechaHastaField
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 45
                                    placeholderText: "DD/MM/YYYY"
                                    font.pixelSize: 13
                                    font.family: "Segoe UI"
                                    
                                    background: Rectangle {
                                        color: whiteColor
                                        border.color: parent.activeFocus ? primaryColor : "#E0E6ED"
                                        border.width: parent.activeFocus ? 2 : 1
                                        radius: 4
                                    }
                                    
                                    onTextChanged: {
                                        fechaHasta = text
                                    }
                                }
                            }
                        }
                        
                        // Descripción del reporte seleccionado
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 70
                            color: tipoReporteSeleccionado > 0 ? "#F8F9FA" : "#FAFAFA"
                            radius: 6
                            border.color: "#E9ECEF"
                            border.width: 1
                            visible: tipoReporteSeleccionado > 0
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 12
                                
                                Rectangle {
                                    width: 32
                                    height: 32
                                    color: tipoReporteSeleccionado > 0 ? 
                                           tiposReportes[tipoReporteSeleccionado].color : lightGrayColor
                                    radius: 4
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: tipoReporteSeleccionado > 0 ? 
                                              tiposReportes[tipoReporteSeleccionado].icono : "📊"
                                        font.pixelSize: 16
                                        color: whiteColor
                                    }
                                }
                                
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    
                                    Label {
                                        text: tipoReporteSeleccionado > 0 ? 
                                              tiposReportes[tipoReporteSeleccionado].nombre : "Sin selección"
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: textColor
                                        font.family: "Segoe UI"
                                    }
                                    
                                    Label {
                                        text: tipoReporteSeleccionado > 0 ? 
                                              tiposReportes[tipoReporteSeleccionado].descripcion : ""
                                        font.pixelSize: 12
                                        color: darkGrayColor
                                        font.family: "Segoe UI"
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                        }
                        
                        // Botón de acción principal
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            
                            Item { Layout.fillWidth: true }
                            
                            Button {
                                id: generarReporteBtn
                                text: "📊 Generar Reporte "
                                Layout.preferredHeight: 50
                                Layout.preferredWidth: 220
                                enabled: tipoReporteSeleccionado > 0 && fechaDesde && fechaHasta
                                
                                background: Rectangle {
                                    color: parent.enabled ? 
                                           (parent.pressed ? Qt.darker(primaryColor, 1.2) : primaryColor) : 
                                           lightGrayColor
                                    radius: 6
                                    border.color: parent.enabled ? primaryColor : "#BDC3C7"
                                    border.width: 1
                                    
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: "transparent" }
                                            GradientStop { position: 1.0; color: "#10000000" }
                                        }
                                    }
                                }
                                
                                contentItem: Label {
                                    text: parent.text
                                    color: parent.enabled ? whiteColor : darkGrayColor
                                    font.bold: true
                                    font.pixelSize: 14
                                    font.family: "Segoe UI"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                
                                onClicked: generarReporte()
                            }
                        }
                    }
                }
                
                Item { Layout.fillHeight: true }
            }
        }
        
        // VISTA 1: RESULTADOS DEL REPORTE
        Item {
            id: vistaResultados
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                
                // Header de navegación
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    color: primaryColor
                    
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 1.0; color: "#10000000" }
                        }
                    }
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 15
                        spacing: 15
                        
                        Button {
                            text: "← Volver"
                            Layout.preferredHeight: 40
                            Layout.preferredWidth: 100
                            
                            background: Rectangle {
                                color: parent.pressed ? "#40FFFFFF" : "transparent"
                                radius: 4
                                border.color: whiteColor
                                border.width: 1
                            }
                            
                            contentItem: Label {
                                text: parent.text
                                color: whiteColor
                                font.bold: true
                                font.pixelSize: 12
                                font.family: "Segoe UI"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: {
                                vistaActual = 0
                                mostrandoVistaPrevia = false
                            }
                        }
                        
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            
                            Label {
                                text: "REPORTE: " + obtenerTituloReporte().replace("REPORTE DE ", "").replace("REPORTE ", "")
                                color: whiteColor
                                font.bold: true
                                font.pixelSize: 16
                                font.family: "Segoe UI"
                            }
                            
                            Label {
                                text: "Período: " + fechaDesde + " al " + fechaHasta + " • " + datosReporte.length + " registros"
                                color: "#E8F4FD"
                                font.pixelSize: 11
                                font.family: "Segoe UI"
                            }
                        }
                        
                        RowLayout {
                            spacing: 12
                                                        
                            Button {
                                text: "Descargar PDF"
                                Layout.preferredHeight: 50
                                Layout.preferredWidth: 180
                                
                                background: Rectangle {
                                    color: parent.pressed ? Qt.darker(successColor, 1.2) : successColor
                                    radius: 6
                                    
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: "transparent" }
                                            GradientStop { position: 1.0; color: "#10000000" }
                                        }
                                    }
                                }
                                
                                contentItem: RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 10  // Aumenté el espaciado entre icono y texto
                                    
                                    Image {
                                        source: "file:///D:/Sistema-Clinica-/Resources/iconos/descargarpdf.png"
                                        Layout.preferredWidth: 28  // Aumentado de 20 a 28
                                        Layout.preferredHeight: 28 // Aumentado de 20 a 28
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        
                                        // Fallback si no encuentra la imagen
                                        onStatusChanged: {
                                            if (status === Image.Error) {
                                                source = "Resources/iconos/descargarpdf.png"
                                            }
                                        }
                                    }
                                    
                                    Label {
                                        Layout.fillWidth: true
                                        text: parent.parent.text
                                        color: whiteColor
                                        font.bold: true
                                        font.pixelSize: 13  // Aumenté ligeramente el tamaño de fuente
                                        font.family: "Segoe UI"
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                                
                                onClicked: descargarPDF()
                            }
                        }
                        
                        Button {
                            text: "×"
                            Layout.preferredHeight: 40
                            Layout.preferredWidth: 40
                            
                            background: Rectangle {
                                color: parent.pressed ? "#40FFFFFF" : "transparent"
                                radius: 20
                            }
                            
                            contentItem: Label {
                                text: parent.text
                                color: whiteColor
                                font.bold: true
                                font.pixelSize: 16
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: {
                                vistaActual = 0
                                mostrandoVistaPrevia = false
                                reporteGenerado = false
                            }
                        }
                    }
                }
                
                // Contenido principal (solo tabla de datos)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: whiteColor
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 20
                        
                        // Información del período
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 50
                            color: "#F8F9FA"
                            radius: 4
                            border.color: "#E9ECEF"
                            border.width: 1
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 15
                                spacing: 15
                                
                                Label {
                                    text: "PERÍODO: " + fechaDesde + " al " + fechaHasta
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: textColor
                                    font.family: "Segoe UI"
                                }
                                
                                Item { Layout.fillWidth: true }
                                
                                Label {
                                    text: "Fecha: " + Qt.formatDateTime(new Date(), "dd/MM/yyyy")
                                    font.pixelSize: 12
                                    color: darkGrayColor
                                    font.family: "Segoe UI"
                                }
                            }
                        }
                                                
                        // ========================================
                        // REEMPLAZAR LA TABLA COMPLETA EN REPORTES.QML
                        // ========================================

                        // Tabla de datos con zebra striping Y TOTALES
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: whiteColor
                            radius: 4
                            border.color: "#E0E6ED"
                            border.width: 1
                            
                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 0
                                
                                // Encabezados de la tabla
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 45
                                    color: blackColor
                                    radius: 4
                                    
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 0
                                        
                                        Repeater {
                                            model: obtenerColumnasReporte()
                                            
                                            Label {
                                                Layout.preferredWidth: modelData.width
                                                text: modelData.titulo
                                                font.bold: true
                                                font.pixelSize: 11
                                                font.family: "Segoe UI"
                                                color: whiteColor
                                                horizontalAlignment: modelData.align || Text.AlignLeft
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                        }
                                    }
                                }
                                
                                // Área de datos con scroll y zebra striping
                                ScrollView {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true
                                    
                                    ColumnLayout {
                                        width: parent.width
                                        spacing: 0
                                        
                                        Repeater {
                                            model: datosReporte.length
                                            
                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 40
                                                color: index % 2 === 0 ? whiteColor : zebraColor
                                                border.color: "transparent"
                                                border.width: 0
                                                
                                                property int rowIndex: index
                                                
                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.margins: 12
                                                    spacing: 0
                                                    
                                                    Repeater {
                                                        model: obtenerColumnasReporte()
                                                        
                                                        Label {
                                                            Layout.preferredWidth: modelData.width
                                                            text: obtenerValorColumna(parent.parent.rowIndex, modelData.campo)
                                                            font.pixelSize: 10
                                                            font.family: "Segoe UI, Arial, sans-serif"
                                                            color: textColor
                                                            horizontalAlignment: modelData.align || Text.AlignLeft
                                                            verticalAlignment: Text.AlignVCenter
                                                            wrapMode: modelData.campo === "descripcion" ? Text.WordWrap : Text.NoWrap
                                                            elide: modelData.campo === "descripcion" ? Text.ElideNone : Text.ElideRight
                                                            font.bold: modelData.campo === "valor"
                                                            maximumLineCount: modelData.campo === "descripcion" ? 3 : 1
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                // ==========================================
                                // FILA DE TOTAL UNIVERSAL - FUNCIONA PARA TODOS LOS REPORTES
                                // ==========================================
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 50
                                    color: "#2C3E50"  // Color destacado para totales
                                    border.color: "#34495E"
                                    border.width: 2
                                    
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 0
                                        
                                        // Obtener columnas actuales
                                        property var columnasActuales: obtenerColumnasReporte()
                                        
                                        Repeater {
                                            model: parent.columnasActuales.length
                                            
                                            Rectangle {
                                                Layout.preferredWidth: parent.columnasActuales[index].width
                                                Layout.fillHeight: true
                                                color: "transparent"
                                                
                                                Label {
                                                    anchors.centerIn: parent
                                                    text: {
                                                        var columna = parent.parent.columnasActuales[index]
                                                        var nombreColumna = columna.titulo
                                                        var campoColumna = columna.campo
                                                        
                                                        console.log("Procesando columna:", index, nombreColumna, campoColumna, "Tipo reporte:", tipoReporteSeleccionado)
                                                        
                                                        // MOSTRAR TOTAL en columna de valor monetario
                                                        if (campoColumna === "valor") {
                                                            var total = calcularTotalReporte()
                                                            console.log("Mostrando total:", total)
                                                            return "Bs " + total.toFixed(2)
                                                        }
                                                        
                                                        // PARA GASTOS: mostrar "TOTAL GENERAL:" en DESCRIPCIÓN
                                                        if (tipoReporteSeleccionado === 7 && campoColumna === "descripcion") {
                                                            console.log("Mostrando TOTAL GENERAL en descripción para gastos")
                                                            return "TOTAL GENERAL:"
                                                        }
                                                        
                                                        // PARA OTROS REPORTES: mostrar "TOTAL GENERAL:" en penúltima columna
                                                        if (tipoReporteSeleccionado !== 7 && 
                                                            index === parent.parent.columnasActuales.length - 2 && 
                                                            campoColumna !== "valor") {
                                                            console.log("Mostrando TOTAL GENERAL en penúltima columna")
                                                            return "TOTAL GENERAL:"
                                                        }
                                                        
                                                        // Todas las demás columnas vacías
                                                        return ""
                                                    }
                                                    
                                                    font.bold: true
                                                    font.pixelSize: 13
                                                    font.family: "Segoe UI"
                                                    color: whiteColor
                                                    horizontalAlignment: {
                                                        var columna = parent.parent.parent.columnasActuales[index]
                                                        var campoColumna = columna.campo
                                                        
                                                        if (campoColumna === "valor") {
                                                            return Text.AlignRight
                                                        } else if (tipoReporteSeleccionado === 7 && campoColumna === "descripcion") {
                                                            return Text.AlignRight
                                                        } else if (tipoReporteSeleccionado !== 7 && index === parent.parent.parent.columnasActuales.length - 2) {
                                                            return Text.AlignRight
                                                        } else {
                                                            return Text.AlignCenter
                                                        }
                                                    }
                                                    verticalAlignment: Text.AlignVCenter
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ==========================================
                        // RESUMEN INFERIOR UNIVERSAL CON ESTADÍSTICAS
                        // ==========================================
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 90
                            color: "#F8F9FA"
                            radius: 4
                            border.color: "#E9ECEF"
                            border.width: 1
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 15
                                spacing: 30
                                
                                // ESTADÍSTICAS PRINCIPALES
                                ColumnLayout {
                                    spacing: 6
                                    
                                    Label {
                                        text: "📊 RESUMEN EJECUTIVO"
                                        font.pixelSize: 12
                                        font.bold: true
                                        font.family: "Segoe UI"
                                        color: primaryColor
                                    }
                                    
                                    Row {
                                        spacing: 25
                                        
                                        Label {
                                            text: "Total Registros: " + datosReporte.length
                                            font.pixelSize: 11
                                            font.bold: true
                                            font.family: "Segoe UI"
                                            color: textColor
                                        }
                                        
                                        Label {
                                            text: "Valor Total: Bs " + calcularTotalReporte().toFixed(2)
                                            font.pixelSize: 11
                                            font.bold: true
                                            font.family: "Segoe UI"
                                            color: calcularTotalReporte() >= 0 ? successColor : dangerColor
                                        }
                                        
                                        Label {
                                            text: "Promedio: Bs " + (datosReporte.length > 0 ? (calcularTotalReporte() / datosReporte.length).toFixed(2) : "0.00")
                                            font.pixelSize: 11
                                            font.bold: true
                                            font.family: "Segoe UI"
                                            color: infoColor
                                        }
                                    }
                                    
                                    // SEGUNDA FILA DE ESTADÍSTICAS
                                    Row {
                                        spacing: 25
                                        
                                        Label {
                                            text: "Tipo de Reporte: " + obtenerTituloReporte()
                                            font.pixelSize: 10
                                            font.family: "Segoe UI"
                                            color: darkGrayColor
                                        }
                                        
                                        Label {
                                            text: "Período: " + fechaDesde + " al " + fechaHasta
                                            font.pixelSize: 10
                                            font.family: "Segoe UI"
                                            color: darkGrayColor
                                        }
                                    }
                                }
                                
                                Item { Layout.fillWidth: true }
                                
                                // INFORMACIÓN DEL SISTEMA
                                ColumnLayout {
                                    spacing: 4
                                    Layout.alignment: Qt.AlignTop
                                    
                                    Label {
                                        text: "📅 Generado: " + Qt.formatDateTime(new Date(), "dd/MM/yyyy hh:mm")
                                        font.pixelSize: 10
                                        font.family: "Segoe UI"
                                        color: darkGrayColor
                                        horizontalAlignment: Text.AlignRight
                                    }
                                    
                                    Label {
                                        text: "👤 Usuario: " + (typeof authModel !== 'undefined' && authModel ? authModel.userName : "Sistema")
                                        font.pixelSize: 10
                                        font.family: "Segoe UI"
                                        color: darkGrayColor
                                        horizontalAlignment: Text.AlignRight
                                    }
                                    
                                    Label {
                                        text: "🏥 Sistema de Gestión Médica - CMI"
                                        font.pixelSize: 9
                                        font.family: "Segoe UI"
                                        color: darkGrayColor
                                        horizontalAlignment: Text.AlignRight
                                    }
                                    
                                    Label {
                                        text: "📍 Villa Yapacaní, Santa Cruz - Bolivia"
                                        font.pixelSize: 9
                                        font.family: "Segoe UI"
                                        color: darkGrayColor
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // ===== FUNCIONES =====
    
    function limpiarFormulario() {
        tipoReporteCombo.currentIndex = 0
        fechaDesdeField.text = ""
        fechaHastaField.text = ""
        tipoReporteSeleccionado = 0
        fechaDesde = ""
        fechaHasta = ""
        reporteGenerado = false
        mostrandoVistaPrevia = false
        datosReporte = []
        resumenReporte = {}
    }
    
    function generarReporte() {
        console.log("📊 Generando reporte real desde base de datos")
        console.log("🔍 Tipo:", tipoReporteSeleccionado, "Período:", fechaDesde, "al", fechaHasta)
        
        // Validaciones básicas
        if (tipoReporteSeleccionado === 0) {
            mostrarNotificacionError("Por favor seleccione un tipo de reporte")
            return
        }
        
        if (!fechaDesde || !fechaHasta) {
            mostrarNotificacionError("Por favor ingrese las fechas del período")
            return
        }
        
        // Validar que el modelo esté disponible
        if (!reportesModel) {
            console.log("❌ ReportesModel no disponible")
            mostrarNotificacionError("Sistema de reportes no disponible")
            return
        }
        
        // Validar formato de fechas
        if (!reportesModel.validarFecha(fechaDesde) || !reportesModel.validarFecha(fechaHasta)) {
            mostrarNotificacionError("Formato de fecha inválido. Use DD/MM/YYYY")
            return
        }
        
        // Validar rango de fechas
        if (!reportesModel.validarRangoFechas(fechaDesde, fechaHasta)) {
            mostrarNotificacionError("La fecha desde debe ser menor o igual a la fecha hasta")
            return
        }
        
        // Generar reporte real
        console.log("🚀 Llamando al modelo para generar reporte...")
        var success = reportesModel.generarReporte(tipoReporteSeleccionado, fechaDesde, fechaHasta)
        
        if (!success) {
            console.log("❌ El modelo reportó error inmediato")
            mostrarNotificacionError("Error iniciando generación del reporte")
        }
    }
    
    function descargarPDF() {
        console.log("📄 Iniciando descarga de PDF con datos reales...")
        
        try {
            if (!reporteGenerado || !datosReporte || datosReporte.length === 0) {
                console.log("❌ No hay reporte generado para descargar")
                mostrarNotificacionError("Primero debe generar un reporte")
                return
            }
            
            if (!reportesModel) {
                console.log("❌ ReportesModel no disponible para PDF")
                mostrarNotificacionError("Sistema de reportes no disponible")
                return
            }
            
            console.log("📊 Exportando", datosReporte.length, "registros a PDF...")
            
            var rutaArchivo = reportesModel.exportarPDF()
            
            if (rutaArchivo && rutaArchivo.length > 0) {
                console.log("✅ PDF exportado exitosamente:", rutaArchivo)
                var nombreArchivo = rutaArchivo.split("/").pop().split("\\").pop()
                mostrarNotificacionDescarga(nombreArchivo, rutaArchivo)
                Qt.openUrlExternally("file:///" + rutaArchivo)
            } else {
                console.log("❌ Error: No se pudo generar el PDF")
                mostrarNotificacionError("Error generando el archivo PDF")
            }
            
        } catch (error) {
            console.log("❌ Error en descargarPDF():", error)
            mostrarNotificacionError("Error inesperado al generar PDF")
        }
    }
        
    function obtenerColumnasReporte() {
        switch(tipoReporteSeleccionado) {
            case 1: // Ventas de Farmacia
                return [
                    {titulo: "FECHA", campo: "fecha", width: 80},
                    {titulo: "Nº VENTA", campo: "numeroVenta", width: 80},
                    {titulo: "DESCRIPCIÓN", campo: "descripcion", width: 200},
                    {titulo: "CANTIDAD", campo: "cantidad", width: 80, align: Text.AlignRight},
                    {titulo: "TOTAL (Bs)", campo: "valor", width: 120, align: Text.AlignRight}
                ]
                
            case 2: // Inventario de Productos
                return [
                    {titulo: "CÓDIGO", campo: "codigo", width: 80},
                    {titulo: "PRODUCTO", campo: "descripcion", width: 180},
                    {titulo: "UNIDAD", campo: "unidad", width: 60},
                    {titulo: "STOCK", campo: "cantidad", width: 80, align: Text.AlignRight},
                    {titulo: "PRECIO UNIT.", campo: "precioUnitario", width: 100, align: Text.AlignRight},
                    {titulo: "VALOR TOTAL (Bs)", campo: "valor", width: 120, align: Text.AlignRight}
                ]
                
            case 3: // Compras de Farmacia
                return [
                    {titulo: "FECHA", campo: "fecha", width: 80},
                    {titulo: "Nº COMPRA", campo: "numeroCompra", width: 90},
                    {titulo: "PROVEEDOR", campo: "descripcion", width: 180},
                    {titulo: "CANTIDAD", campo: "cantidad", width: 80, align: Text.AlignRight},
                    {titulo: "TOTAL (Bs)", campo: "valor", width: 120, align: Text.AlignRight}
                ]
                
            case 4: // Consultas Médicas
                return [
                    {titulo: "FECHA", campo: "fecha", width: 100},
                    {titulo: "ESPECIALIDAD", campo: "especialidad", width: 140},
                    {titulo: "DESCRIPCIÓN", campo: "descripcion", width: 180},
                    {titulo: "PACIENTE", campo: "paciente", width: 150},
                    {titulo: "MÉDICO", campo: "doctor_nombre", width: 150},
                    {titulo: "PRECIO (Bs)", campo: "valor", width: 120, align: Text.AlignRight}
                ]
                
            case 5: // Laboratorio
                return [
                    {titulo: "FECHA", campo: "fecha", width: 90},
                    {titulo: "TIPO ANÁLISIS", campo: "tipoAnalisis", width: 140},
                    {titulo: "DESCRIPCIÓN", campo: "descripcion", width: 180},
                    {titulo: "PACIENTE", campo: "paciente", width: 150},
                    {titulo: "TÉCNICO", campo: "tecnico", width: 140},
                    {titulo: "PRECIO (Bs)", campo: "valor", width: 120, align: Text.AlignRight}
                ]
                
            case 6: // Enfermería
                return [
                    {titulo: "FECHA", campo: "fecha", width: 90},
                    {titulo: "TIPO PROCEDIMIENTO", campo: "tipoProcedimiento", width: 140},
                    {titulo: "DESCRIPCIÓN", campo: "descripcion", width: 180},
                    {titulo: "PACIENTE", campo: "paciente", width: 150},
                    {titulo: "ENFERMERO/A", campo: "enfermero", width: 140},
                    {titulo: "PRECIO (Bs)", campo: "valor", width: 120, align: Text.AlignRight}
                ]
                
            case 7: // Gastos Operativos - SEGÚN REQUERIMIENTO EXACTO
                return [
                    {titulo: "FECHA", campo: "fecha", width: 90},
                    {titulo: "TIPO DE GASTO", campo: "categoria", width: 140},
                    {titulo: "DESCRIPCIÓN", campo: "descripcion", width: 180},
                    {titulo: "MONTO (Bs)", campo: "valor", width: 120, align: Text.AlignRight},
                    {titulo: "PROVEEDOR", campo: "proveedor", width: 150}
                ]
                
            case 8: // Consolidado
                return [
                    {titulo: "FECHA", campo: "fecha", width: 80},
                    {titulo: "TIPO", campo: "tipo", width: 100, align: Text.AlignCenter},
                    {titulo: "DESCRIPCIÓN", campo: "descripcion", width: 180},
                    {titulo: "CANTIDAD", campo: "cantidad", width: 80, align: Text.AlignRight},
                    {titulo: "VALOR (Bs)", campo: "valor", width: 120, align: Text.AlignRight}
                ]
                
            default:
                return [
                    {titulo: "FECHA", campo: "fecha", width: 90},
                    {titulo: "DESCRIPCIÓN", campo: "descripcion", width: 250},
                    {titulo: "CANTIDAD", campo: "cantidad", width: 80, align: Text.AlignRight},
                    {titulo: "VALOR (Bs)", campo: "valor", width: 120, align: Text.AlignRight}
                ]
        }
    }

    function calcularTotalReporte() {
        var total = 0.0
        
        if (!datosReporte || datosReporte.length === 0) {
            return 0.0
        }
        
        for (var i = 0; i < datosReporte.length; i++) {
            var registro = datosReporte[i]
            var valor = 0.0
            
            // Buscar valor en diferentes campos posibles
            if (registro.valor !== undefined && registro.valor !== null) {
                valor = parseFloat(registro.valor) || 0.0
            } else if (registro.Monto !== undefined && registro.Monto !== null) {
                valor = parseFloat(registro.Monto) || 0.0
            } else if (registro.Total !== undefined && registro.Total !== null) {
                valor = parseFloat(registro.Total) || 0.0
            }
            
            total += valor
        }
        
        console.log("Total calculado para", datosReporte.length, "registros:", total.toFixed(2))
        return total
    }    
    

    function obtenerValorColumna(index, campo) {
        if (!datosReporte[index]) return "---"
        
        var registro = datosReporte[index]
        
        switch(campo) {
            // CAMPOS BÁSICOS
            case "fecha":
                return registro.fecha || "---"
            case "descripcion":
                return registro.descripcion || "Sin detalles"
            case "cantidad":
                return (registro.cantidad || 0).toString()
            case "valor":
                return (registro.valor || 0).toFixed(2)
                
            // VENTAS
            case "numeroVenta":
                return registro.numeroVenta || ("V" + String(index + 1).padStart(3, '0'))
                
            // INVENTARIO
            case "codigo":
                return registro.codigo || ("COD" + String(index + 1).padStart(3, '0'))
            case "unidad":
                return registro.unidad || "UND"
            case "precioUnitario":
                return registro.precioUnitario ? registro.precioUnitario.toFixed(2) : "0.00"
                
            // COMPRAS
            case "numeroCompra":
                return registro.numeroCompra || ("C" + String(index + 1).padStart(3, '0'))
                
            // CONSULTAS
            case "especialidad":
                return registro.especialidad || "Sin especialidad"
            case "paciente":
                return registro.paciente || "Paciente"
            case "doctor_nombre":
                return registro.doctor_nombre || "Sin médico"
                
            // LABORATORIO
            case "tipoAnalisis":
                return registro.tipoAnalisis || registro.tipo || "Análisis General"
            case "tecnico":
                return registro.tecnico || "Sin asignar"
                
            // ENFERMERÍA
            case "tipoProcedimiento":
                return registro.tipoProcedimiento || registro.tipo || "Procedimiento General"
            case "enfermero":
                return registro.enfermero || "Sin asignar"
                
            // GASTOS - SEGÚN REQUERIMIENTO EXACTO
            case "categoria":
                return registro.categoria || registro.tipo_nombre || "General"
            case "proveedor":
                return registro.proveedor || "Sin proveedor"
                
            // CONSOLIDADO
            case "tipo":
                return registro.tipo || "Normal"
                
            default:
                return registro[campo] || "---"
        }
    }
    
    // ===== FUNCIONES DE NOTIFICACIÓN =====
    
    function mostrarNotificacionError(mensaje) {
        console.log("Mostrando notificación de error:", mensaje)
        // Implementación simplificada - puedes expandir según necesites
    }
    
    function mostrarNotificacionDescarga(nombreArchivo, rutaCompleta) {
        console.log("Mostrando notificación de descarga:", nombreArchivo)
        // Implementación simplificada - puedes expandir según necesites
    }
    
    function mostrarNotificacionGeneracion(mensaje, totalRegistros) {
        console.log("Mostrando notificación de generación:", mensaje, totalRegistros)
        // Implementación simplificada - puedes expandir según necesites
    }
    
    function mostrarNotificacionSinDatos() {
        console.log("Mostrando notificación sin datos")
        // Implementación simplificada - puedes expandir según necesites
    }
    
    // ===== INICIALIZACIÓN =====
    
    Component.onCompleted: {
        console.log("📊 Módulo de Reportes con datos reales inicializado")
        
        if (reportesModel) {
            console.log("✅ ReportesModel conectado correctamente")
        } else {
            console.log("⚠️ ReportesModel no disponible aún")
            Qt.callLater(function() {
                if (appController && appController.reportes_model_instance) {
                    reportesModel = appController.reportes_model_instance
                    console.log("✅ ReportesModel conectado con delay")
                }
            })
        }
        
        // Establecer fechas por defecto
        var hoy = new Date()
        var primerDiaMes = new Date(hoy.getFullYear(), hoy.getMonth(), 1)
        
        fechaDesdeField.text = Qt.formatDate(primerDiaMes, "dd/MM/yyyy")
        fechaHastaField.text = Qt.formatDate(hoy, "dd/MM/yyyy")
        
        fechaDesde = fechaDesdeField.text
        fechaHasta = fechaHastaField.text
        
        console.log("📅 Fechas por defecto establecidas:", fechaDesde, "al", fechaHasta)
    }
}