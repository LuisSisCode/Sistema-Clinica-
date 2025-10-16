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
    
    property bool mostrandoVistaPrevia: false

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

    // ✅ NUEVA PROPIEDAD: Mensajes de estado del sistema
    property string mensajeEstado: "🟢 Todos los módulos operativos"
    property string colorEstado: successColor
    property string mensajeError: ""
    property bool mostrarMensajeError: false

    // Tipos de reportes disponibles
    property var tiposReportes: [
        {
            id: 0,
            nombre: "Seleccionar tipo de reporte...",
            modulo: "",
            icono: "📊", 
            descripcion: "Seleccione el tipo de reporte que desea generar",
            color: "#ECF0F1" 
        },
        {
            id: 1,
            nombre: "Ventas de Farmacia",
            modulo: "farmacia",
            icono: "💰",
            descripcion: "Reporte detallado de todas las ventas realizadas en farmacia",
            color: "#2C3E50"
        },
        {
            id: 2,
            nombre: "Inventario de Productos",
            modulo: "farmacia",
            icono: "📦",
            descripcion: "Estado actual del inventario con stock y valores",
            color: "#34495E" 
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
            color: "#2C3E50"
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
            nombre: "Reporte de Ingresos y Egresos",
            modulo: "financiero",
            icono: "📈",
            descripcion: "Análisis financiero completo de ingresos, egresos y saldo neto del período",
            color: blackColor
        }
    ]

    // ✅ CORREGIDO: Mensaje de error emergente SIN DropShadow
    Rectangle {
        id: mensajeEmergente
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width * 0.8
        height: 70
        color: dangerColor
        radius: 8
        border.color: Qt.darker(dangerColor, 1.2)
        border.width: 2
        visible: mostrarMensajeError
        z: 1000
        
        // ✅ ELIMINADO: DropShadow problemático
        // En su lugar, usamos un efecto de sombra simple con otro rectángulo
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 2
            anchors.leftMargin: 2
            color: "#40000000"
            radius: parent.radius
            z: -1
        }
        
        RowLayout {
            anchors.fill: parent
            anchors.margins: 15
            spacing: 15
            
            Rectangle {
                width: 40
                height: 40
                color: "white"
                radius: 20
                
                Label {
                    anchors.centerIn: parent
                    text: "⚠️"
                    font.pixelSize: 18
                }
            }
            
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                
                Label {
                    text: "ADVERTENCIA DEL SISTEMA"
                    font.pixelSize: 14
                    font.bold: true
                    color: whiteColor
                    font.family: "Segoe UI"
                }
                
                Label {
                    text: mensajeError
                    font.pixelSize: 12
                    color: whiteColor
                    font.family: "Segoe UI"
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
            
            Button {
                text: "✕"
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                
                background: Rectangle {
                    color: parent.pressed ? "#40FFFFFF" : "transparent"
                    radius: 15
                    border.color: whiteColor
                    border.width: 1
                }
                
                contentItem: Label {
                    text: parent.text
                    color: whiteColor
                    font.bold: true
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: {
                    mostrarMensajeError = false
                    mensajeError = ""
                }
            }
        }
        
        // Auto-ocultar después de 8 segundos
        Timer {
            id: timerOcultarMensaje
            interval: 8000
            onTriggered: {
                mostrarMensajeError = false
                mensajeError = ""
            }
        }
    }

    // CONEXIONES AL MODELO DE REPORTES - MEJORADAS
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
                    
                    // ✅ ACTUALIZAR ESTADO DEL SISTEMA
                    mensajeEstado = "🟢 Reporte generado exitosamente"
                    colorEstado = successColor
                } else {
                    mostrarNotificacionSinDatos()
                    // ✅ NO CAMBIAR A VISTA DE RESULTADOS SI NO HAY DATOS
                    vistaActual = 0
                    
                    // ✅ MOSTRAR MENSAJE EMERGENTE
                    mensajeError = "No se encontraron registros para el período seleccionado. Verifique las fechas e intente nuevamente."
                    mostrarMensajeError = true
                    timerOcultarMensaje.restart()
                    
                    // ✅ ACTUALIZAR ESTADO DEL SISTEMA
                    mensajeEstado = "🟡 Sin datos para el período"
                    colorEstado = warningColor
                }
            } else {
                console.log("❌ Error generando reporte:", message)
                mostrarNotificacionError(message)
                
                // ✅ MOSTRAR MENSAJE EMERGENTE
                mensajeError = "Error al generar el reporte: " + message
                mostrarMensajeError = true
                timerOcultarMensaje.restart()
                
                // ✅ ACTUALIZAR ESTADO DEL SISTEMA
                mensajeEstado = "🔴 Error en generación de reporte"
                colorEstado = dangerColor
            }
        }
        
        function onReporteError(title, message) {
            console.log("❌ Error en reporte:", title, "-", message)
            mostrarNotificacionError(message)
            
            // ✅ MOSTRAR MENSAJE EMERGENTE
            mensajeError = title + ": " + message
            mostrarMensajeError = true
            timerOcultarMensaje.restart()
            
            // ✅ ACTUALIZAR ESTADO DEL SISTEMA
            mensajeEstado = "🔴 Error del sistema"
            colorEstado = dangerColor
        }
        
        function onLoadingChanged() {
            console.log("Loading changed:", reportesModel ? reportesModel.loading : false)
            
            // ✅ ACTUALIZAR ESTADO DURANTE CARGA
            if (reportesModel && reportesModel.loading) {
                mensajeEstado = "🟡 Generando reporte..."
                colorEstado = warningColor
            }
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
                
                // Header del módulo PROFESIONAL - MEJORADO
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
                        
                        // ✅ MEJORADO: Estado del sistema dinámico
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
                                    text: mensajeEstado
                                    font.pixelSize: 12
                                    color: colorEstado
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
                                    color: parent.pressed ? Qt.darker("#ECF0F1", 1.1) : "#ECF0F1"
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
                                    currentIndex: 0
                                    
                                    model: ListModel {
                                        id: tiposReportesModel
                                        Component.onCompleted: {
                                            for (var i = 0; i < tiposReportes.length; i++) {
                                                var item = tiposReportes[i]
                                                append({
                                                    "id": item.id,
                                                    "nombre": item.nombre,
                                                    "modulo": item.modulo,
                                                    "icono": item.icono,
                                                    "descripcion": item.descripcion,
                                                    "color": item.color
                                                })
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
                                            text: {
                                                if (tipoReporteCombo.currentIndex >= 0 && 
                                                    tiposReportesModel.count > 0 && 
                                                    tipoReporteCombo.currentIndex < tiposReportesModel.count) {
                                                    var item = tiposReportesModel.get(tipoReporteCombo.currentIndex)
                                                    return item && item.icono ? item.icono : "📊"
                                                }
                                                return "📊"
                                            }
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
                        
                        // ✅ NUEVO: Panel de ayuda y validación
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 50
                            color: "#FFF9E6"
                            radius: 6
                            border.color: "#FFEAA7"
                            border.width: 1
                            visible: tipoReporteSeleccionado > 0 && (!fechaDesde || !fechaHasta)
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 10
                                
                                Label {
                                    text: "💡"
                                    font.pixelSize: 16
                                }
                                
                                Label {
                                    text: "Complete ambas fechas para generar el reporte"
                                    font.pixelSize: 12
                                    color: "#E67E22"
                                    font.family: "Segoe UI"
                                    Layout.fillWidth: true
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
                                           tiposReportes[tipoReporteSeleccionado].color : "#ECF0F1"
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
                                           "#ECF0F1"
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
                                    spacing: 10
                                    
                                    Image {
                                        source: "Resources/iconos/descargarpdf.png"
                                        Layout.preferredWidth: 28
                                        Layout.preferredHeight: 28
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        
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
                                        font.pixelSize: 13
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
                                
                                Rectangle {
                                    Layout.preferredWidth: 120
                                    Layout.preferredHeight: 25
                                    color: tipoReporteSeleccionado === 8 ? "#E8F5E8" : "transparent"
                                    radius: 12
                                    border.color: tipoReporteSeleccionado === 8 ? successColor : "transparent"
                                    border.width: 1
                                    visible: tipoReporteSeleccionado === 8
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "💰 ANÁLISIS FINANCIERO"
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: successColor
                                        font.family: "Segoe UI"
                                    }
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
                                    Layout.preferredHeight: 50
                                    color: blackColor
                                    radius: 4
                                    
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 0
                                        
                                        Repeater {
                                            model: obtenerColumnasReporte()
                                            
                                            Label {
                                                Layout.preferredWidth: modelData.width
                                                Layout.fillHeight: true
                                                text: modelData.titulo
                                                font.bold: true
                                                font.pixelSize: 10
                                                font.family: "Segoe UI"
                                                color: whiteColor
                                                horizontalAlignment: modelData.align || Text.AlignLeft
                                                verticalAlignment: Text.AlignVCenter
                                                wrapMode: Text.WordWrap
                                                maximumLineCount: 2
                                                elide: Text.ElideRight
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
                                
                                // FILA DE TOTAL UNIVERSAL
                                Rectangle {
                                    id: filaTotal
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 50
                                    color: "#2C3E50"  
                                    border.color: "#34495E"
                                    border.width: 2
                                    
                                    property var columnasLocal: obtenerColumnasReporte()
                                    
                                    RowLayout {
                                        id: rowTotal
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 0
                                        
                                        Repeater {
                                            id: repeaterTotal
                                            model: filaTotal.columnasLocal ? filaTotal.columnasLocal.length : 0
                                            
                                            Rectangle {
                                                id: celdaTotal
                                                Layout.preferredWidth: {
                                                    if (filaTotal.columnasLocal && 
                                                        index >= 0 && 
                                                        index < filaTotal.columnasLocal.length) {
                                                        return filaTotal.columnasLocal[index].width
                                                    }
                                                    return 80
                                                }
                                                Layout.fillHeight: true
                                                color: "transparent"
                                                
                                                Label {
                                                    anchors.centerIn: parent
                                                    text: {
                                                        if (!filaTotal.columnasLocal || 
                                                            index < 0 || 
                                                            index >= filaTotal.columnasLocal.length) {
                                                            return ""
                                                        }
                                                        
                                                        var columna = filaTotal.columnasLocal[index]
                                                        var campoColumna = columna.campo
                                                        
                                                        if (campoColumna === "valor") {
                                                            var total = calcularTotalReporte()
                                                            return "Bs " + total.toFixed(2)
                                                        }

                                                        if (tipoReporteSeleccionado === 1 && campoColumna === "usuario") {
                                                            return "TOTAL GENERAL:"
                                                        }

                                                        if (tipoReporteSeleccionado === 7 && campoColumna === "descripcion") {
                                                            return "TOTAL GENERAL:"
                                                        }

                                                        if (tipoReporteSeleccionado !== 7 && 
                                                            tipoReporteSeleccionado !== 1 && 
                                                            index === filaTotal.columnasLocal.length - 2 && 
                                                            campoColumna !== "valor") {
                                                            return "TOTAL GENERAL:"
                                                        }

                                                        return ""
                                                    }
                                                    
                                                    font.bold: true
                                                    font.pixelSize: 13
                                                    font.family: "Segoe UI"
                                                    color: whiteColor
                                                    horizontalAlignment: {
                                                        if (!filaTotal.columnasLocal || 
                                                            index < 0 || 
                                                            index >= filaTotal.columnasLocal.length) {
                                                            return Text.AlignCenter
                                                        }
                                                        
                                                        var columna = filaTotal.columnasLocal[index]
                                                        var campoColumna = columna.campo
                                                        
                                                        if (campoColumna === "valor") {
                                                            return Text.AlignRight
                                                        } else if (tipoReporteSeleccionado === 7 && campoColumna === "descripcion") {
                                                            return Text.AlignRight
                                                        } else if (tipoReporteSeleccionado === 1 && campoColumna === "usuario") {
                                                            return Text.AlignRight
                                                        } else if (tipoReporteSeleccionado !== 7 && 
                                                                tipoReporteSeleccionado !== 1 && 
                                                                index === filaTotal.columnasLocal.length - 2) {
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

                        // RESUMEN INFERIOR UNIVERSAL CON ESTADÍSTICAS
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: tipoReporteSeleccionado === 8 ? 110 : 90
                            color: "#F8F9FA"
                            radius: 4
                            border.color: "#E9ECEF"
                            border.width: 1
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 15
                                spacing: 30
                                
                                // ESTADÍSTICAS PRINCIPALES - MEJORADAS
                                ColumnLayout {
                                    spacing: 6
                                    
                                    Label {
                                        text: tipoReporteSeleccionado === 8 ? "💹 RESUMEN FINANCIERO" : "📊 RESUMEN EJECUTIVO"
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
                                            text: {
                                                var total = calcularTotalReporte()
                                                if (tipoReporteSeleccionado === 8) {
                                                    return total >= 0 ? "Saldo: +Bs " + total.toFixed(2) : "Saldo: -Bs " + Math.abs(total).toFixed(2)
                                                } else {
                                                    return "Valor Total: Bs " + total.toFixed(2)
                                                }
                                            }
                                            font.pixelSize: 11
                                            font.bold: true
                                            font.family: "Segoe UI"
                                            color: {
                                                if (tipoReporteSeleccionado === 8) {
                                                    return calcularTotalReporte() >= 0 ? successColor : dangerColor
                                                } else {
                                                    return calcularTotalReporte() >= 0 ? successColor : dangerColor
                                                }
                                            }
                                        }
                                        
                                        Label {
                                            text: "Promedio: Bs " + (datosReporte.length > 0 ? (calcularTotalReporte() / datosReporte.length).toFixed(2) : "0.00")
                                            font.pixelSize: 11
                                            font.bold: true
                                            font.family: "Segoe UI"
                                            color: "#34495E"
                                        }
                                    }
                                    
                                    // SEGUNDA FILA DE ESTADÍSTICAS - MEJORADA
                                    Row {
                                        spacing: 25
                                        
                                        Label {
                                            text: {
                                                if (tipoReporteSeleccionado === 8) {
                                                    return "Análisis: " + obtenerTituloReporte()
                                                } else {
                                                    return "Tipo: " + obtenerTituloReporte()
                                                }
                                            }
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
                                    
                                    // TERCERA FILA ESPECIAL PARA REPORTE FINANCIERO
                                    Row {
                                        spacing: 25
                                        visible: tipoReporteSeleccionado === 8
                                        
                                        Label {
                                            text: "Estado: " + (calcularTotalReporte() >= 0 ? "SUPERÁVIT FINANCIERO" : "DÉFICIT FINANCIERO")
                                            font.pixelSize: 10
                                            font.bold: true
                                            font.family: "Segoe UI"
                                            color: calcularTotalReporte() >= 0 ? successColor : dangerColor
                                        }
                                        
                                        Label {
                                            text: "Evaluación: " + (calcularTotalReporte() >= 0 ? "Gestión Saludable" : "Requiere Atención")
                                            font.pixelSize: 10
                                            font.family: "Segoe UI"
                                            color: darkGrayColor
                                        }
                                    }
                                }
                                
                                Item { Layout.fillWidth: true }
                                
                                // INFORMACIÓN DEL SISTEMA - MANTENIDA
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
        mostrarMensajeError = false
        mensajeError = ""
        
        // ✅ RESTABLECER ESTADO DEL SISTEMA
        mensajeEstado = "🟢 Todos los módulos operativos"
        colorEstado = successColor
    }
    
    function generarReporte() {
        console.log("📊 Generando reporte real desde base de datos")
        console.log("🔍 Tipo:", tipoReporteSeleccionado, "Período:", fechaDesde, "al", fechaHasta)
        
        // ✅ OCULTAR MENSAJES ANTERIORES
        mostrarMensajeError = false
        
        // Validaciones básicas
        if (tipoReporteSeleccionado === 0) {
            mostrarNotificacionError("Por favor seleccione un tipo de reporte")
            
            // ✅ MOSTRAR MENSAJE EMERGENTE
            mensajeError = "Debe seleccionar un tipo de reporte antes de continuar"
            mostrarMensajeError = true
            timerOcultarMensaje.restart()
            return
        }
        
        if (!fechaDesde || !fechaHasta) {
            mostrarNotificacionError("Por favor ingrese las fechas del período")
            
            // ✅ MOSTRAR MENSAJE EMERGENTE
            mensajeError = "Complete ambas fechas (Desde y Hasta) para generar el reporte"
            mostrarMensajeError = true
            timerOcultarMensaje.restart()
            return
        }
        
        // Validar que el modelo esté disponible
        if (!reportesModel) {
            console.log("❌ ReportesModel no disponible")
            mostrarNotificacionError("Sistema de reportes no disponible")
            
            // ✅ MOSTRAR MENSAJE EMERGENTE
            mensajeError = "El sistema de reportes no está disponible. Contacte al administrador."
            mostrarMensajeError = true
            timerOcultarMensaje.restart()
            
            // ✅ ACTUALIZAR ESTADO DEL SISTEMA
            mensajeEstado = "🔴 Sistema de reportes no disponible"
            colorEstado = dangerColor
            return
        }
        
        // Validar formato de fechas
        if (!reportesModel.validarFecha(fechaDesde) || !reportesModel.validarFecha(fechaHasta)) {
            mostrarNotificacionError("Formato de fecha inválido. Use DD/MM/YYYY")
            
            // ✅ MOSTRAR MENSAJE EMERGENTE
            mensajeError = "Formato de fecha incorrecto. Use el formato DD/MM/YYYY (ej: 15/10/2025)"
            mostrarMensajeError = true
            timerOcultarMensaje.restart()
            return
        }
        
        // Validar rango de fechas
        if (!reportesModel.validarRangoFechas(fechaDesde, fechaHasta)) {
            mostrarNotificacionError("La fecha desde debe ser menor o igual a la fecha hasta")
            
            // ✅ MOSTRAR MENSAJE EMERGENTE
            mensajeError = "La fecha 'Desde' debe ser anterior o igual a la fecha 'Hasta'"
            mostrarMensajeError = true
            timerOcultarMensaje.restart()
            return
        }
        
        // ✅ ACTUALIZAR ESTADO DURANTE GENERACIÓN
        mensajeEstado = "🟡 Generando reporte..."
        colorEstado = warningColor
        
        // Generar reporte real
        console.log("🚀 Llamando al modelo para generar reporte...")
        var success = reportesModel.generarReporte(tipoReporteSeleccionado, fechaDesde, fechaHasta)
        
        if (!success) {
            console.log("❌ El modelo reportó error inmediato")
            mostrarNotificacionError("Error iniciando generación del reporte")
            
            // ✅ ACTUALIZAR ESTADO DEL SISTEMA
            mensajeEstado = "🔴 Error iniciando reporte"
            colorEstado = dangerColor
        }
    }
    
    function descargarPDF() {
        console.log("📄 Iniciando descarga de PDF con datos reales...")
        
        try {
            if (!reporteGenerado || !datosReporte || datosReporte.length === 0) {
                console.log("❌ No hay reporte generado para descargar")
                mostrarNotificacionError("Primero debe generar un reporte")
                
                // ✅ MOSTRAR MENSAJE EMERGENTE
                mensajeError = "No hay datos disponibles para descargar. Genere un reporte primero."
                mostrarMensajeError = true
                timerOcultarMensaje.restart()
                return
            }
            
            if (!reportesModel) {
                console.log("❌ ReportesModel no disponible para PDF")
                mostrarNotificacionError("Sistema de reportes no disponible")
                
                // ✅ MOSTRAR MENSAJE EMERGENTE
                mensajeError = "El sistema de reportes no está disponible para generar PDF"
                mostrarMensajeError = true
                timerOcultarMensaje.restart()
                return
            }
            
            console.log("📊 Exportando", datosReporte.length, "registros a PDF...")
            
            // ✅ ACTUALIZAR ESTADO DURANTE GENERACIÓN DE PDF
            mensajeEstado = "🟡 Generando PDF..."
            colorEstado = warningColor
            
            var rutaArchivo = reportesModel.exportarPDF()
            
            if (rutaArchivo && rutaArchivo.length > 0) {
                console.log("✅ PDF exportado exitosamente:", rutaArchivo)
                var nombreArchivo = rutaArchivo.split("/").pop().split("\\").pop()
                mostrarNotificacionDescarga(nombreArchivo, rutaArchivo)
                Qt.openUrlExternally("file:///" + rutaArchivo)
                
                // ✅ ACTUALIZAR ESTADO DEL SISTEMA
                mensajeEstado = "🟢 PDF generado exitosamente"
                colorEstado = successColor
            } else {
                console.log("❌ Error: No se pudo generar el PDF")
                mostrarNotificacionError("Error generando el archivo PDF")
                
                // ✅ MOSTRAR MENSAJE EMERGENTE
                mensajeError = "Error al generar el archivo PDF. Verifique los permisos del sistema."
                mostrarMensajeError = true
                timerOcultarMensaje.restart()
                
                // ✅ ACTUALIZAR ESTADO DEL SISTEMA
                mensajeEstado = "🔴 Error generando PDF"
                colorEstado = dangerColor
            }
            
        } catch (error) {
            console.log("❌ Error en descargarPDF():", error)
            mostrarNotificacionError("Error inesperado al generar PDF")
            
            // ✅ MOSTRAR MENSAJE EMERGENTE
            mensajeError = "Error inesperado al generar PDF: " + error
            mostrarMensajeError = true
            timerOcultarMensaje.restart()
            
            // ✅ ACTUALIZAR ESTADO DEL SISTEMA
            mensajeEstado = "🔴 Error crítico en PDF"
            colorEstado = dangerColor
        }
    }

    function obtenerColumnasReporte() {
        switch(tipoReporteSeleccionado) {
            case 1: // Ventas de Farmacia
                return [
                    {titulo: "FECHA", campo: "fecha", width: 70},
                    {titulo: "Nº VENTA", campo: "numeroVenta", width: 70},
                    {titulo: "PRODUCTO", campo: "descripcion", width: 140},
                    {titulo: "CANT", campo: "cantidad", width: 50, align: Text.AlignRight},
                    {titulo: "P.UNIT.", campo: "precio_unitario", width: 80, align: Text.AlignRight},
                    {titulo: "VENDEDOR", campo: "usuario", width: 100},
                    {titulo: "TOTAL", campo: "valor", width: 80, align: Text.AlignRight}
                ]
                    
            case 2: // Inventario de Productos
                return [
                    {titulo: "FECHA", campo: "fecha", width: 70},
                    {titulo: "PRODUCTO", campo: "descripcion", width: 140},
                    {titulo: "MARCA", campo: "marca", width: 80},
                    {titulo: "STOCK", campo: "cantidad", width: 60, align: Text.AlignRight},
                    {titulo: "LOTES", campo: "lotes", width: 50, align: Text.AlignCenter},
                    {titulo: "P.UNIT.", campo: "precioUnitario", width: 80, align: Text.AlignRight},
                    {titulo: "F.VENC.", campo: "fecha_vencimiento", width: 80},
                    {titulo: "VALOR (Bs)", campo: "valor", width: 100, align: Text.AlignRight}
                ]

            case 3: // Compras de Farmacia
                return [
                    {titulo: "FECHA", campo: "fecha", width: 70},          
                    {titulo: "PRODUCTO", campo: "descripcion", width: 120},     
                    {titulo: "MARCA", campo: "marca", width: 80},          
                    {titulo: "UNID.", campo: "cantidad", width: 50, align: Text.AlignRight},         
                    {titulo: "PROVEEDOR", campo: "proveedor", width: 100},     
                    {titulo: "F.VENC.", campo: "fecha_vencimiento", width: 70},        
                    {titulo: "USUARIO", campo: "usuario", width: 80},        
                    {titulo: "TOTAL (Bs)", campo: "valor", width: 80, align: Text.AlignRight}     
                ]
                
            case 4: // Consultas Médicas
                return [
                    {titulo: "FECHA", campo: "fecha", width: 80},
                    {titulo: "ESPECIALIDAD", campo: "especialidad", width: 120},
                    {titulo: "DESCRIPCIÓN", campo: "descripcion", width: 160},
                    {titulo: "PACIENTE", campo: "paciente", width: 130},
                    {titulo: "MÉDICO", campo: "doctor_nombre", width: 130},
                    {titulo: "PRECIO (Bs)", campo: "valor", width: 100, align: Text.AlignRight}
                ]
                
            case 5: // Laboratorio
                return [
                    {titulo: "FECHA", campo: "fecha", width: 80},
                    {titulo: "ANÁLISIS", campo: "analisis", width: 140},
                    {titulo: "TIPO", campo: "tipo", width: 80, align: Text.AlignCenter},
                    {titulo: "PACIENTE", campo: "paciente", width: 130},
                    {titulo: "LABORATORISTA", campo: "laboratorista", width: 130},
                    {titulo: "PRECIO (Bs)", campo: "valor", width: 100, align: Text.AlignRight}
                ]
                
            case 6: // Enfermería
                return [
                    {titulo: "FECHA", campo: "fecha", width: 80},
                    {titulo: "PROCEDIMIENTO", campo: "procedimiento", width: 140},
                    {titulo: "TIPO", campo: "tipo", width: 80, align: Text.AlignCenter},
                    {titulo: "PACIENTE", campo: "paciente", width: 130},
                    {titulo: "ENFERMERO/A", campo: "enfermero", width: 130},
                    {titulo: "PRECIO (Bs)", campo: "valor", width: 100, align: Text.AlignRight}
                ]
                
            case 7: // Gastos Operativos
                return [
                    {titulo: "FECHA", campo: "fecha", width: 80},
                    {titulo: "TIPO GASTO", campo: "tipo_gasto", width: 120},
                    {titulo: "DESCRIPCIÓN", campo: "descripcion", width: 160},
                    {titulo: "PROVEEDOR", campo: "proveedor", width: 130},
                    {titulo: "MONTO (Bs)", campo: "valor", width: 100, align: Text.AlignRight}
                ]
                
            case 8: // Consolidado
                return [
                    {titulo: "FECHA", campo: "fecha", width: 80},
                    {titulo: "TIPO", campo: "tipo", width: 80, align: Text.AlignCenter},
                    {titulo: "DESCRIPCIÓN", campo: "descripcion", width: 180},
                    {titulo: "CANTIDAD", campo: "cantidad", width: 80, align: Text.AlignRight},
                    {titulo: "VALOR (Bs)", campo: "valor", width: 120, align: Text.AlignRight}
                ]
                
            default:
                return [
                    {titulo: "FECHA", campo: "fecha", width: 90},
                    {titulo: "DESCRIPCIÓN", campo: "descripcion", width: 200},
                    {titulo: "CANTIDAD", campo: "cantidad", width: 80, align: Text.AlignRight},
                    {titulo: "VALOR (Bs)", campo: "valor", width: 120, align: Text.AlignRight}
                ]
        }
    }

    function obtenerTituloReporte() {
        switch(tipoReporteSeleccionado) {
            case 1: return "REPORTE DE VENTAS DE FARMACIA"
            case 2: return "REPORTE DE INVENTARIO DE PRODUCTOS"
            case 3: return "REPORTE DE COMPRAS DE FARMACIA"
            case 4: return "REPORTE DE CONSULTAS MÉDICAS"
            case 5: return "REPORTE DE ANÁLISIS DE LABORATORIO"
            case 6: return "REPORTE DE PROCEDIMIENTOS DE ENFERMERÍA"
            case 7: return "REPORTE DE GASTOS OPERATIVOS"
            case 8: return "REPORTE DE INGRESOS Y EGRESOS"
            default: return "REPORTE GENERAL"
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
            case "fecha":
                return registro.fecha || Qt.formatDate(new Date(), "dd/MM/yyyy")
                
            case "descripcion":
                return registro.descripcion || registro.Nombre || registro.nombre || "Sin descripción"
                
            case "analisis":
                return registro.analisis || 
                    registro.tipoAnalisis || 
                    registro.tipo_analisis ||
                    "Análisis General"
            
            case "tipo":
                var tipoServicio = registro.tipo || "Normal"
                return tipoServicio === "Emergencia" ? "Emergencia" : "Normal"
            
            case "laboratorista":
                return registro.laboratorista || 
                    registro.tecnico ||
                    registro.trabajador_nombre ||
                    "Sin asignar"
            
            case "procedimiento":
                return registro.procedimiento ||
                    registro.tipoProcedimiento ||
                    registro.descripcion ||
                    "Procedimiento General"
            
            case "enfermero":
                return registro.enfermero ||
                    registro.trabajador_nombre ||
                    registro.usuario ||
                    "Sin asignar"
            
            case "tipo_gasto":
                return registro.tipo_gasto ||
                    registro.categoria ||
                    registro.tipo_nombre ||
                    "General"
            
            case "marca":
                return registro.marca || 
                    registro.Marca_Nombre || 
                    registro.marca_nombre || 
                    "Sin marca"
                
            case "cantidad":
                var stock = registro.cantidad || 
                        registro.Stock_Total || 
                        registro.stock_total ||
                        0
                return stock.toString()
                
            case "lotes":
                var numLotes = registro.lotes || 
                            registro.Lotes_Activos || 
                            0
                return numLotes.toString()

            case "precio_unitario":
            case "precioUnitario":
                try {
                    var precioUnit = parseFloat(registro.precio_unitario || registro.precioUnitario) || 0
                    return "Bs " + precioUnit.toFixed(2)
                } catch(e) {
                    return "Bs 0.00"
                }
                
            case "usuario":
                return registro.usuario || "Sin usuario"
                
            case "fecha_vencimiento":
                var fechaVenc = registro.fecha_vencimiento || 
                            registro.Proxima_Vencimiento || 
                            null
                
                if (!fechaVenc || fechaVenc === "" || fechaVenc === "None") {
                    return "Sin venc."
                }
                
                if (typeof fechaVenc === 'string' && fechaVenc.includes('-')) {
                    try {
                        var partes = fechaVenc.split('-')
                        return partes[2] + "/" + partes[1] + "/" + partes[0]
                    } catch(e) {
                        return fechaVenc
                    }
                }
                return fechaVenc
                
            case "valor":
                var valorTotal = registro.valor || 0
                return valorTotal.toFixed(2)
                
            case "numeroVenta":
                return registro.numeroVenta || ("V" + String(index + 1).padStart(3, '0'))

            case "especialidad":
                return registro.especialidad || "Sin especialidad"
                
            case "paciente":
                return registro.paciente || "Paciente"
                
            case "doctor_nombre":
                return registro.doctor_nombre || "Sin médico"
                
            case "proveedor":
                return registro.proveedor || "Sin proveedor"
                
            default:
                var valor = registro[campo]
                if (valor === undefined || valor === null || valor === "") {
                    return "---"
                }
                return valor.toString()
        }
    }

    function debugearDatosInventario() {
        if (tipoReporteSeleccionado === 2 && datosReporte.length > 0) {
            console.log("🔍 DEBUG - Primer registro de inventario:")
            var primer = datosReporte[0]
            console.log("Campos disponibles:", Object.keys(primer))
            console.log("Datos:", JSON.stringify(primer, null, 2))
        }
    }

    // ===== FUNCIONES DE NOTIFICACIÓN =====
    
    function mostrarNotificacionError(mensaje) {
        console.log("❌ ERROR:", mensaje)
        
        if (typeof notificationManager !== 'undefined' && notificationManager) {
            notificationManager.showNotification({
                tipo: "error",
                titulo: "Error en Reporte",
                mensaje: mensaje,
                duracion: 5000
            })
        }
    }
    
    function mostrarNotificacionDescarga(nombreArchivo, rutaCompleta) {
        console.log(`📄 PDF descargado: ${nombreArchivo}`)
        
        var mensajeDescarga = `PDF generado exitosamente:\n\n` +
                            `📁 Archivo: ${nombreArchivo}\n` +
                            `📂 Ubicación: ${rutaCompleta}\n\n` +
                            `El archivo se abrirá automáticamente.`
        
        if (typeof notificationManager !== 'undefined' && notificationManager) {
            notificationManager.showNotification({
                tipo: "success",
                titulo: "PDF Descargado",
                mensaje: mensajeDescarga,
                duracion: 6000
            })
        }
    }
    
    function mostrarNotificacionGeneracion(mensaje, totalRegistros) {
        console.log(`✅ ÉXITO: ${mensaje} (${totalRegistros} registros)`)
        
        var mensajeExito = `Reporte generado exitosamente:\n\n` +
                        `📊 Total de registros: ${totalRegistros}\n` +
                        `📅 Período: ${fechaDesde} al ${fechaHasta}\n` +
                        `📋 Tipo: ${tiposReportes[tipoReporteSeleccionado].nombre}`
        
        if (typeof notificationManager !== 'undefined' && notificationManager) {
            notificationManager.showNotification({
                tipo: "success",
                titulo: "Reporte Generado",
                mensaje: mensajeExito,
                duracion: 4000
            })
        }
    }
    
    function mostrarNotificacionSinDatos() {
        console.log("ℹ️ Sin datos para el período seleccionado")
        
        var mensajeDetallado = `No se encontraron registros para el período:\n` +
                            `${fechaDesde} al ${fechaHasta}\n\n` +
                            `Tipo de reporte: ${tiposReportes[tipoReporteSeleccionado].nombre}\n\n` +
                            `Sugerencias:\n` +
                            `• Verifique que las fechas sean correctas\n` +
                            `• Intente ampliar el rango de fechas\n` +
                            `• Confirme que existan registros en este período`
        
        if (typeof notificationManager !== 'undefined' && notificationManager) {
            notificationManager.showNotification({
                tipo: "info",
                titulo: "Sin Datos Disponibles",
                mensaje: mensajeDetallado,
                duracion: 7000
            })
        }
    }
    
    // ===== INICIALIZACIÓN =====
    
    Component.onCompleted: {
        console.log("📊 Módulo de Reportes con mensajes emergentes inicializado")
        
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
        
        // ✅ INICIALIZAR ESTADO DEL SISTEMA
        mensajeEstado = "🟢 Todos los módulos operativos"
        colorEstado = successColor
    }
}