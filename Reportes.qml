import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import QtQuick.Pdf 5.15
import Qt.labs.platform 1.1
Item {
    id: reportesRoot
    objectName: "reportesRoot"
    
    // Colores del tema PROFESIONAL (monocromático)
    readonly property color primaryColor: "#2C3E50"      // Azul oscuro profesional
    readonly property color successColor: "#27AE60"      // Verde para valores positivos
    readonly property color dangerColor: "#E74C3C"       // Rojo para valores negativos
    readonly property color warningColor: "#F39C12"      // Naranja para advertencias
    readonly property color lightGrayColor: "#ECF0F1"    // Gris claro
    readonly property color textColor: "#2C3E50"         // Texto principal
    readonly property color whiteColor: "#FFFFFF"        // Blanco
    readonly property color darkGrayColor: "#7F8C8D"     // Gris oscuro
    readonly property color infoColor: "#34495E"         // Azul información
    readonly property color violetColor: "#8E44AD"       // Violeta profesional
    readonly property color blackColor: "#000000"        // Negro puro
    readonly property color zebraColor: "#F8F9FA"        // Color zebra striping
    
    // Estados del módulo
    property int vistaActual: 0  // 0: Configuración, 1: Resultados
    property int tipoReporteSeleccionado: 0
    property string fechaDesde: ""
    property string fechaHasta: ""
    property bool reporteGenerado: false
    property bool mostrandoVistaPrevia: false
    property var datosReporte: []
    property var resumenReporte: ({})
    
    // Tipos de reportes disponibles
    property var tiposReportes: [
        {
            id: 0,
            nombre: "Seleccionar tipo de reporte...",
            modulo: "",
            icono: "📊",
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
                    
                    // Sombra profesional
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
                            
                            Label {
                                anchors.centerIn: parent
                                text: "📊"
                                color: whiteColor
                                font.pixelSize: 28
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
                
                // Sección de configuración del reporte PROFESIONAL
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
                        
                        // Título de sección PROFESIONAL
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
                        
                        // Formulario de configuración MEJORADO
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
                        
                        // Descripción del reporte seleccionado PROFESIONAL
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
                        
                        // Botón de acción principal PROFESIONAL
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            
                            Item { Layout.fillWidth: true }
                            
                            Button {
                                id: generarReporteBtn
                                text: "📊 Generar Reporte Profesional"
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
                                    
                                    // Efecto de gradiente sutil
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
        
        // VISTA 1: RESULTADOS DEL REPORTE PROFESIONAL
        Item {
            id: vistaResultados
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                
                // Header de navegación PROFESIONAL
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    color: primaryColor
                    
                    // Gradiente sutil
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
                            spacing: 8
                            
                            Button {
                                text: mostrandoVistaPrevia ? "📊 Ver Datos" : "👁️ Vista Previa"
                                Layout.preferredHeight: 40
                                Layout.preferredWidth: 120
                                
                                background: Rectangle {
                                    color: parent.pressed ? Qt.darker(infoColor, 1.2) : infoColor
                                    radius: 4
                                }
                                
                                contentItem: Label {
                                    text: parent.text
                                    color: whiteColor
                                    font.bold: true
                                    font.pixelSize: 10
                                    font.family: "Segoe UI"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                
                                onClicked: {
                                    mostrandoVistaPrevia = !mostrandoVistaPrevia
                                }
                            }
                            
                            Button {
                                text: "📄 Descargar PDF"
                                Layout.preferredHeight: 40
                                Layout.preferredWidth: 130
                                
                                background: Rectangle {
                                    color: parent.pressed ? Qt.darker(successColor, 1.2) : successColor
                                    radius: 4
                                }
                                
                                contentItem: Label {
                                    text: parent.text
                                    color: whiteColor
                                    font.bold: true
                                    font.pixelSize: 10
                                    font.family: "Segoe UI"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
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

                
                // Contenido principal PROFESIONAL (tabla o vista previa)
                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: mostrandoVistaPrevia ? 1 : 0
                    
                    // Vista de tabla de datos PROFESIONAL
                    Rectangle {
                        color: whiteColor
                        
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 20
                            
                            // Información del período PROFESIONAL
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
                            
                            // Tabla de datos PROFESIONAL con zebra striping
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
                                    
                                    // Encabezados de la tabla PROFESIONAL
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
                                    
                                    // Área de datos con scroll y ZEBRA STRIPING
                                    ScrollView {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        clip: true
                                        
                                        ColumnLayout {
                                            width: parent.width
                                            spacing: 0
                                            
                                            // Filas de datos con zebra striping
                                            Repeater {
                                                model: datosReporte.length
                                                
                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: 40
                                                    // ZEBRA STRIPING PROFESIONAL
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
                                                                font.family: "Segoe UI"
                                                                color: textColor
                                                                horizontalAlignment: modelData.align || Text.AlignLeft
                                                                verticalAlignment: Text.AlignVCenter
                                                                elide: Text.ElideRight
                                                                font.bold: modelData.campo === "valor"
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    
                                    // Fila de total PROFESIONAL
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 50
                                        color: lightGrayColor
                                        border.color: textColor
                                        border.width: 1
                                        
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 5
                                            
                                            Item {
                                                Layout.fillWidth: true
                                                
                                                Label {
                                                    anchors.right: parent.right
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: "TOTAL GENERAL:"
                                                    font.bold: true
                                                    font.pixelSize: 13
                                                    font.family: "Segoe UI"
                                                    color: textColor
                                                }
                                            }
                                            
                                            Label {
                                                Layout.preferredWidth: 120
                                                text: "Bs " + (resumenReporte.totalValor || 0).toFixed(2)
                                                font.bold: true
                                                font.pixelSize: 13
                                                font.family: "Segoe UI"
                                                color: resumenReporte.totalValor >= 0 ? successColor : dangerColor
                                                horizontalAlignment: Text.AlignRight
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // Resumen inferior PROFESIONAL
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 70
                                color: "#F8F9FA"
                                radius: 4
                                border.color: "#E9ECEF"
                                border.width: 1
                                
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 15
                                    spacing: 40
                                    
                                    ColumnLayout {
                                        spacing: 6
                                        
                                        Label {
                                            text: "Total de Registros: " + datosReporte.length
                                            font.pixelSize: 12
                                            font.bold: true
                                            font.family: "Segoe UI"
                                            color: textColor
                                        }
                                        
                                        Label {
                                            text: "Valor Total: Bs " + (resumenReporte.totalValor || 0).toFixed(2)
                                            font.pixelSize: 12
                                            font.bold: true
                                            font.family: "Segoe UI"
                                            color: resumenReporte.totalValor >= 0 ? successColor : dangerColor
                                        }
                                    }
                                    
                                    Item { Layout.fillWidth: true }
                                    
                                    Label {
                                        text: "Sistema de Gestión Médica - Clínica María Inmaculada"
                                        font.pixelSize: 10
                                        font.family: "Segoe UI"
                                        color: darkGrayColor
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }
                            }
                        }
                    }
                    
                    // Vista previa del PDF PROFESIONAL
                    Rectangle {
                        color: "#F5F6FA"
                        
                        ScrollView {
                            anchors.fill: parent
                            clip: true
                            
                            // Contenedor centrado que simula una hoja carta PROFESIONAL
                            Item {
                                width: Math.max(parent.width, 900)
                                height: Math.max(parent.height, 700)
                                
                                // Simulación de hoja carta PROFESIONAL
                                Rectangle {
                                    id: cartaPageProfesional
                                    width: 650
                                    height: 850
                                    anchors.centerIn: parent
                                    color: whiteColor
                                    radius: 4
                                    border.color: "#BDC3C7"
                                    border.width: 1
                                    
                                    // Sombra profesional
                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.topMargin: 4
                                        anchors.leftMargin: 4
                                        color: "#15000000"
                                        radius: 4
                                        z: -1
                                    }
                                    
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 30
                                        spacing: 15
                                        
                                        // Encabezado PROFESIONAL simulado
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 10
                                            
                                            // Simulación de logo
                                            RowLayout {
                                                Layout.fillWidth: true
                                                
                                                Rectangle {
                                                    width: 80
                                                    height: 40
                                                    color: primaryColor
                                                    radius: 4
                                                    
                                                    Label {
                                                        anchors.centerIn: parent
                                                        text: "CMI\nLOGO"
                                                        color: whiteColor
                                                        font.bold: true
                                                        font.pixelSize: 10
                                                        font.family: "Segoe UI"
                                                        horizontalAlignment: Text.AlignHCenter
                                                    }
                                                }
                                                
                                                Item { Layout.fillWidth: true }
                                                
                                                ColumnLayout {
                                                    spacing: 2
                                                    
                                                    Label {
                                                        text: "CLÍNICA MARÍA INMACULADA"
                                                        font.pixelSize: 10
                                                        font.bold: true
                                                        font.family: "Segoe UI"
                                                        color: darkGrayColor
                                                        horizontalAlignment: Text.AlignRight
                                                    }
                                                    
                                                    Label {
                                                        text: "Villa Yapacaní, Santa Cruz - Bolivia"
                                                        font.pixelSize: 8
                                                        font.family: "Segoe UI"
                                                        color: darkGrayColor
                                                        horizontalAlignment: Text.AlignRight
                                                    }
                                                }
                                            }
                                            
                                            // Título principal
                                            Label {
                                                text: obtenerTituloReporte()
                                                font.pixelSize: 16
                                                font.bold: true
                                                font.family: "Segoe UI"
                                                color: textColor
                                                Layout.fillWidth: true
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                            
                                            // Línea separadora
                                            Rectangle {
                                                Layout.fillWidth: true
                                                height: 2
                                                color: blackColor
                                            }
                                            
                                            // Información del período
                                            Label {
                                                text: "PERÍODO: " + fechaDesde + " al " + fechaHasta
                                                font.pixelSize: 10
                                                font.family: "Segoe UI"
                                                color: textColor
                                                Layout.fillWidth: true
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                            
                                            Rectangle {
                                                Layout.fillWidth: true
                                                height: 1
                                                color: blackColor
                                            }
                                        }
                                        
                                        // Tabla principal PROFESIONAL
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 0
                                            
                                            // Encabezados de tabla
                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 32
                                                color: blackColor
                                                
                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.margins: 6
                                                    spacing: 0
                                                    
                                                    Repeater {
                                                        model: obtenerColumnasReporteCarta()
                                                        
                                                        Label {
                                                            Layout.preferredWidth: modelData.width
                                                            text: modelData.titulo
                                                            font.bold: true
                                                            font.pixelSize: 8
                                                            font.family: "Segoe UI"
                                                            color: whiteColor
                                                            horizontalAlignment: modelData.align || Text.AlignLeft
                                                            verticalAlignment: Text.AlignVCenter
                                                        }
                                                    }
                                                }
                                            }
                                            
                                            // Filas de datos con ZEBRA STRIPING
                                            Repeater {
                                                model: Math.min(datosReporte.length, 25)
                                                
                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: 25
                                                    // ZEBRA STRIPING PROFESIONAL
                                                    color: index % 2 === 0 ? whiteColor : zebraColor
                                                    border.color: "transparent"
                                                    
                                                    property int rowIndex: index
                                                    
                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.margins: 6
                                                        spacing: 0
                                                        
                                                        Repeater {
                                                            model: obtenerColumnasReporteCarta()
                                                            
                                                            Label {
                                                                Layout.preferredWidth: modelData.width
                                                                text: obtenerValorColumnaCarta(parent.parent.parent.rowIndex, modelData.campo)
                                                                font.pixelSize: 7
                                                                font.family: "Segoe UI"
                                                                color: textColor
                                                                horizontalAlignment: modelData.align || Text.AlignLeft
                                                                elide: Text.ElideRight
                                                                font.bold: modelData.campo === "valor"
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                            
                                            // Fila de total
                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 32
                                                color: lightGrayColor
                                                border.color: blackColor
                                                border.width: 1
                                                
                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.margins: 8
                                                    spacing: 0
                                                    
                                                    Item {
                                                        Layout.fillWidth: true
                                                        
                                                        Label {
                                                            anchors.right: parent.right
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            text: "TOTAL GENERAL:"
                                                            font.bold: true
                                                            font.pixelSize: 9
                                                            font.family: "Segoe UI"
                                                            color: textColor
                                                        }
                                                    }
                                                    
                                                    Label {
                                                        Layout.preferredWidth: 80
                                                        text: "Bs " + (resumenReporte.totalValor || 0).toFixed(2)
                                                        font.bold: true
                                                        font.pixelSize: 9
                                                        font.family: "Segoe UI"
                                                        color: resumenReporte.totalValor >= 0 ? successColor : dangerColor
                                                        horizontalAlignment: Text.AlignRight
                                                        verticalAlignment: Text.AlignVCenter
                                                    }
                                                }
                                            }
                                        }
                                        
                                        // Pie de página PROFESIONAL simulado
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 8
                                            Layout.topMargin: 15
                                            
                                            Rectangle {
                                                Layout.fillWidth: true
                                                height: 1
                                                color: blackColor
                                            }
                                            
                                            RowLayout {
                                                Layout.fillWidth: true
                                                
                                                Label {
                                                    text: "Página 1 de 1"
                                                    font.pixelSize: 8
                                                    font.family: "Segoe UI"
                                                    color: textColor
                                                }
                                                
                                                Item { Layout.fillWidth: true }
                                                
                                                Label {
                                                    text: "Generado el " + Qt.formatDateTime(new Date(), "dd/MM/yyyy hh:mm")
                                                    font.pixelSize: 8
                                                    font.family: "Segoe UI"
                                                    color: textColor
                                                }
                                            }
                                            
                                            Label {
                                                text: "Sistema de Gestión Médica - Documento generado automáticamente"
                                                font.pixelSize: 7
                                                font.family: "Segoe UI"
                                                color: darkGrayColor
                                                Layout.fillWidth: true
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                        }
                                        
                                        Item { Layout.fillHeight: true }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // ===== FUNCIONES DE LÓGICA DE NEGOCIO (SIN CAMBIOS) =====
    
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
        console.log("📊 Generando reporte profesional tipo:", tipoReporteSeleccionado)
        console.log("📅 Período:", fechaDesde, "al", fechaHasta)
        
        datosReporte = []
        
        switch(tipoReporteSeleccionado) {
            case 1: generarReporteVentas(); break
            case 2: generarReporteInventario(); break
            case 3: generarReporteCompras(); break
            case 4: generarReporteConsultas(); break
            case 5: generarReporteLaboratorio(); break
            case 6: generarReporteEnfermeria(); break
            case 7: generarReporteGastos(); break
            case 8: generarReporteConsolidado(); break
            default:
                console.log("❌ Tipo de reporte no reconocido")
                return
        }
        
        reporteGenerado = true
        vistaActual = 1
        
        console.log("✅ Reporte profesional generado con", datosReporte.length, "registros")
    }
    
    // ===== FUNCIONES DE GENERACIÓN DE DATOS (SIN CAMBIOS) =====
    
    function generarReporteVentas() {
        var ventasEjemplo = [
            {fecha: "15/06/2025", descripcion: "Paracetamol 500mg x2, Ibuprofeno 400mg x4", cantidad: 6, valor: 92.00, numeroVenta: "V001", cliente: "Ana María López"},
            {fecha: "16/06/2025", descripcion: "Loratadina 10mg x1, Amoxicilina 500mg x1", cantidad: 2, valor: 42.00, numeroVenta: "V002", cliente: "Carlos Eduardo Martínez"},
            {fecha: "17/06/2025", descripcion: "Omeprazol 20mg x3, Aspirina 100mg x2", cantidad: 5, valor: 65.50, numeroVenta: "V003", cliente: "Elena Isabel Vargas"},
            {fecha: "18/06/2025", descripcion: "Diclofenaco gel x1, Vitamina C x1", cantidad: 2, valor: 38.75, numeroVenta: "V004", cliente: "Roberto Silva"},
            {fecha: "19/06/2025", descripcion: "Acetaminofén 500mg x4, Jarabe tos x1", cantidad: 5, valor: 78.90, numeroVenta: "V005", cliente: "Patricia Morales"},
            {fecha: "20/06/2025", descripcion: "Captopril 25mg x2, Losartán 50mg x1", cantidad: 3, valor: 55.25, numeroVenta: "V006", cliente: "Miguel Ángel Torres"},
            {fecha: "21/06/2025", descripcion: "Metformina 850mg x3, Insulina NPH x1", cantidad: 4, valor: 125.80, numeroVenta: "V007", cliente: "Carmen Rosa Mendoza"}
        ]
        
        datosReporte = ventasEjemplo
        
        var totalValor = 0
        for (var i = 0; i < datosReporte.length; i++) {
            totalValor += datosReporte[i].valor
        }
        
        resumenReporte = {
            totalValor: totalValor,
            totalRegistros: datosReporte.length,
            promedioPorVenta: totalValor / datosReporte.length
        }
    }
    
    function generarReporteInventario() {
        var inventarioEjemplo = [
            {fecha: "09/07/2025", descripcion: "Paracetamol 500mg", cantidad: 150, valor: 2325.00, codigo: "MED001", unidad: "TAB", precioUnitario: 15.50},
            {fecha: "09/07/2025", descripcion: "Amoxicilina 500mg", cantidad: 75, valor: 1732.50, codigo: "MED002", unidad: "CAP", precioUnitario: 23.10},
            {fecha: "09/07/2025", descripcion: "Ibuprofeno 400mg", cantidad: 120, valor: 1830.00, codigo: "MED003", unidad: "TAB", precioUnitario: 15.25},
            {fecha: "09/07/2025", descripcion: "Loratadina 10mg", cantidad: 60, valor: 1134.00, codigo: "MED004", unidad: "TAB", precioUnitario: 18.90},
            {fecha: "09/07/2025", descripcion: "Omeprazol 20mg", cantidad: 90, valor: 1147.50, codigo: "MED005", unidad: "CAP", precioUnitario: 12.75},
            {fecha: "09/07/2025", descripcion: "Captopril 25mg", cantidad: 200, valor: 2450.00, codigo: "MED006", unidad: "TAB", precioUnitario: 12.25},
            {fecha: "09/07/2025", descripcion: "Metformina 850mg", cantidad: 180, valor: 2890.50, codigo: "MED007", unidad: "TAB", precioUnitario: 16.06}
        ]
        
        datosReporte = inventarioEjemplo
        
        var totalValor = 0
        for (var i = 0; i < datosReporte.length; i++) {
            totalValor += datosReporte[i].valor
        }
        
        resumenReporte = {
            totalValor: totalValor,
            totalRegistros: datosReporte.length
        }
    }
    
    function generarReporteCompras() {
        var comprasEjemplo = [
            {fecha: "05/07/2025", descripcion: "Farmacéutica Nacional S.A.", cantidad: 500, valor: 6250.00, numeroCompra: "C001", proveedor: "Farmacéutica Nacional S.A."},
            {fecha: "06/07/2025", descripcion: "Distribuidora Médica Global", cantidad: 300, valor: 5400.00, numeroCompra: "C002", proveedor: "Distribuidora Médica Global"},
            {fecha: "07/07/2025", descripcion: "Laboratorios Unidos", cantidad: 200, valor: 3600.00, numeroCompra: "C003", proveedor: "Laboratorios Unidos"},
            {fecha: "08/07/2025", descripcion: "Pharma Solutions Ltda.", cantidad: 150, valor: 2890.75, numeroCompra: "C004", proveedor: "Pharma Solutions Ltda."}
        ]
        
        datosReporte = comprasEjemplo
        
        var totalValor = 0
        for (var i = 0; i < datosReporte.length; i++) {
            totalValor += datosReporte[i].valor
        }
        
        resumenReporte = {
            totalValor: totalValor,
            totalRegistros: datosReporte.length
        }
    }
    
    function generarReporteConsultas() {
        var consultasEjemplo = [
            {fecha: "05/07/2025", descripcion: "Dr. Juan Carlos García", cantidad: 1, valor: 45.00, especialidad: "Cardiología", medico: "Dr. Juan Carlos García", paciente: "Ana María López"},
            {fecha: "06/07/2025", descripcion: "Dra. María Elena Rodríguez", cantidad: 1, valor: 85.00, especialidad: "Neurología", medico: "Dra. María Elena Rodríguez", paciente: "Carlos Eduardo Martínez"},
            {fecha: "07/07/2025", descripcion: "Dr. Pedro Antonio Martínez", cantidad: 1, valor: 40.00, especialidad: "Pediatría", medico: "Dr. Pedro Antonio Martínez", paciente: "Elena Isabel Vargas"},
            {fecha: "08/07/2025", descripcion: "Dr. Juan Carlos García", cantidad: 1, valor: 45.00, especialidad: "Cardiología", medico: "Dr. Juan Carlos García", paciente: "Roberto Silva"},
            {fecha: "09/07/2025", descripcion: "Dra. Ana Isabel Torres", cantidad: 1, valor: 50.00, especialidad: "Ginecología", medico: "Dra. Ana Isabel Torres", paciente: "Patricia Morales"}
        ]
        
        datosReporte = consultasEjemplo
        
        var totalValor = 0
        for (var i = 0; i < datosReporte.length; i++) {
            totalValor += datosReporte[i].valor
        }
        
        resumenReporte = {
            totalValor: totalValor,
            totalRegistros: datosReporte.length
        }
    }
    
    function generarReporteLaboratorio() {
        var laboratorioEjemplo = [
            {fecha: "05/07/2025", descripcion: "Hemograma Completo", cantidad: 1, valor: 25.00, paciente: "Ana María López", estado: "Procesado"},
            {fecha: "06/07/2025", descripcion: "Glucosa en Sangre", cantidad: 1, valor: 15.00, paciente: "Carlos Eduardo Martínez", estado: "Entregado"},
            {fecha: "07/07/2025", descripcion: "Perfil Lipídico", cantidad: 1, valor: 35.00, paciente: "Elena Isabel Vargas", estado: "Procesado"},
            {fecha: "08/07/2025", descripcion: "Examen General de Orina", cantidad: 1, valor: 18.00, paciente: "Roberto Silva", estado: "Pendiente"},
            {fecha: "09/07/2025", descripcion: "Creatinina", cantidad: 1, valor: 20.00, paciente: "Patricia Morales", estado: "Entregado"}
        ]
        
        datosReporte = laboratorioEjemplo
        
        var totalValor = 0
        for (var i = 0; i < datosReporte.length; i++) {
            totalValor += datosReporte[i].valor
        }
        
        resumenReporte = {
            totalValor: totalValor,
            totalRegistros: datosReporte.length
        }
    }
    
    function generarReporteEnfermeria() {
        var enfermeriaEjemplo = [
            {fecha: "05/07/2025", descripcion: "Curación Simple", cantidad: 1, valor: 25.00, paciente: "Ana María López"},
            {fecha: "06/07/2025", descripcion: "Inyección Intramuscular", cantidad: 3, valor: 45.00, paciente: "Carlos Eduardo Martínez"},
            {fecha: "07/07/2025", descripcion: "Control de Signos Vitales", cantidad: 2, valor: 30.00, paciente: "Elena Isabel Vargas"},
            {fecha: "08/07/2025", descripcion: "Nebulización", cantidad: 2, valor: 36.00, paciente: "Roberto Silva"},
            {fecha: "09/07/2025", descripcion: "Curación Avanzada", cantidad: 1, valor: 60.00, paciente: "Patricia Morales"}
        ]
        
        datosReporte = enfermeriaEjemplo
        
        var totalValor = 0
        for (var i = 0; i < datosReporte.length; i++) {
            totalValor += datosReporte[i].valor
        }
        
        resumenReporte = {
            totalValor: totalValor,
            totalRegistros: datosReporte.length
        }
    }
    
    function generarReporteGastos() {
        var gastosEjemplo = [
            {fecha: "01/07/2025", descripcion: "Servicios Públicos - Energía eléctrica", cantidad: 1, valor: -450.00, categoria: "Servicios"},
            {fecha: "02/07/2025", descripcion: "Personal - Pago quincenal administrativo", cantidad: 1, valor: -12500.00, categoria: "Personal"},
            {fecha: "03/07/2025", descripcion: "Alimentación - Refrigerios personal", cantidad: 1, valor: -280.50, categoria: "Suministros"},
            {fecha: "04/07/2025", descripcion: "Mantenimiento - Equipos médicos", cantidad: 1, valor: -850.00, categoria: "Mantenimiento"},
            {fecha: "05/07/2025", descripcion: "Suministros Médicos - Insumos julio", cantidad: 1, valor: -750.75, categoria: "Suministros"}
        ]
        
        datosReporte = gastosEjemplo
        
        var totalValor = 0
        for (var i = 0; i < datosReporte.length; i++) {
            totalValor += datosReporte[i].valor
        }
        
        resumenReporte = {
            totalValor: totalValor,
            totalRegistros: datosReporte.length
        }
    }
    
    function generarReporteConsolidado() {
        var consolidadoEjemplo = [
            {fecha: "09/07/2025", descripcion: "Ventas de Farmacia", cantidad: 7, valor: 498.20, tipo: "INGRESO"},
            {fecha: "09/07/2025", descripcion: "Consultas Médicas", cantidad: 5, valor: 265.00, tipo: "INGRESO"},
            {fecha: "09/07/2025", descripcion: "Análisis de Laboratorio", cantidad: 5, valor: 113.00, tipo: "INGRESO"},
            {fecha: "09/07/2025", descripcion: "Procedimientos de Enfermería", cantidad: 9, valor: 196.00, tipo: "INGRESO"},
            {fecha: "09/07/2025", descripcion: "Compras de Farmacia", cantidad: 4, valor: -18140.75, tipo: "EGRESO"},
            {fecha: "09/07/2025", descripcion: "Gastos Operativos", cantidad: 5, valor: -14831.25, tipo: "EGRESO"}
        ]
        
        datosReporte = consolidadoEjemplo
        
        var totalIngresos = 0
        var totalEgresos = 0
        
        for (var i = 0; i < datosReporte.length; i++) {
            if (datosReporte[i].valor > 0) {
                totalIngresos += datosReporte[i].valor
            } else {
                totalEgresos += Math.abs(datosReporte[i].valor)
            }
        }
        
        resumenReporte = {
            totalValor: totalIngresos - totalEgresos,
            totalIngresos: totalIngresos,
            totalEgresos: totalEgresos,
            totalRegistros: datosReporte.length
        }
    }
    
    // ===== FUNCIONES AUXILIARES PARA REPORTES (SIN CAMBIOS FUNCIONALES) =====
    
    function obtenerTituloReporte() {
        if (tipoReporteSeleccionado <= 0) return "REPORTE GENERAL"
        
        switch(tipoReporteSeleccionado) {
            case 1: return "REPORTE DE VENTAS DE FARMACIA"
            case 2: return "REPORTE DE INVENTARIO VALORIZADO"
            case 3: return "REPORTE DE COMPRAS DE FARMACIA"
            case 4: return "REPORTE DE CONSULTAS MÉDICAS"
            case 5: return "REPORTE DE ANÁLISIS DE LABORATORIO"
            case 6: return "REPORTE DE PROCEDIMIENTOS DE ENFERMERÍA"
            case 7: return "REPORTE DE GASTOS OPERATIVOS"
            case 8: return "REPORTE FINANCIERO CONSOLIDADO"
            default: return "REPORTE GENERAL"
        }
    }
    
    function obtenerColumnasReporte() {
        if (tipoReporteSeleccionado <= 0) {
            return [
                {titulo: "FECHA", campo: "fecha", width: 80},
                {titulo: "DESCRIPCIÓN", campo: "descripcion", width: 300},
                {titulo: "CANT.", campo: "cantidad", width: 60, align: Text.AlignRight},
                {titulo: "VALOR (Bs)", campo: "valor", width: 120, align: Text.AlignRight}
            ]
        }
        
        switch(tipoReporteSeleccionado) {
            case 1: // Ventas
                return [
                    {titulo: "FECHA", campo: "fecha", width: 80},
                    {titulo: "N° VENTA", campo: "numeroVenta", width: 80},
                    {titulo: "CLIENTE/DESCRIPCIÓN", campo: "descripcion", width: 250},
                    {titulo: "CANT.", campo: "cantidad", width: 60, align: Text.AlignRight},
                    {titulo: "TOTAL (Bs)", campo: "valor", width: 100, align: Text.AlignRight}
                ]
                
            case 2: // Inventario
                return [
                    {titulo: "CÓDIGO", campo: "codigo", width: 80},
                    {titulo: "PRODUCTO", campo: "descripcion", width: 250},
                    {titulo: "UM", campo: "unidad", width: 50},
                    {titulo: "STOCK", campo: "cantidad", width: 70, align: Text.AlignRight},
                    {titulo: "P.U.", campo: "precioUnitario", width: 80, align: Text.AlignRight},
                    {titulo: "STOCK VAL.", campo: "valor", width: 100, align: Text.AlignRight}
                ]
                
            case 3: // Compras
                return [
                    {titulo: "FECHA", campo: "fecha", width: 80},
                    {titulo: "N° COMPRA", campo: "numeroCompra", width: 90},
                    {titulo: "PROVEEDOR", campo: "descripcion", width: 200},
                    {titulo: "CANT.", campo: "cantidad", width: 70, align: Text.AlignRight},
                    {titulo: "TOTAL (Bs)", campo: "valor", width: 100, align: Text.AlignRight}
                ]
                
            case 4: // Consultas
                return [
                    {titulo: "FECHA", campo: "fecha", width: 80},
                    {titulo: "ESPECIALIDAD", campo: "especialidad", width: 120},
                    {titulo: "MÉDICO", campo: "descripcion", width: 180},
                    {titulo: "PACIENTE", campo: "paciente", width: 150},
                    {titulo: "VALOR (Bs)", campo: "valor", width: 100, align: Text.AlignRight}
                ]
                
            case 5: // Laboratorio
                return [
                    {titulo: "FECHA", campo: "fecha", width: 80},
                    {titulo: "EXAMEN", campo: "descripcion", width: 220},
                    {titulo: "PACIENTE", campo: "paciente", width: 150},
                    {titulo: "ESTADO", campo: "estado", width: 80},
                    {titulo: "VALOR (Bs)", campo: "valor", width: 100, align: Text.AlignRight}
                ]
                
            case 6: // Enfermería
                return [
                    {titulo: "FECHA", campo: "fecha", width: 80},
                    {titulo: "PROCEDIMIENTO", campo: "descripcion", width: 200},
                    {titulo: "PACIENTE", campo: "paciente", width: 150},
                    {titulo: "CANT.", campo: "cantidad", width: 60, align: Text.AlignRight},
                    {titulo: "TOTAL (Bs)", campo: "valor", width: 100, align: Text.AlignRight}
                ]
                
            case 7: // Gastos
                return [
                    {titulo: "FECHA", campo: "fecha", width: 80},
                    {titulo: "CATEGORÍA", campo: "categoria", width: 120},
                    {titulo: "DESCRIPCIÓN", campo: "descripcion", width: 220},
                    {titulo: "MONTO (Bs)", campo: "valor", width: 100, align: Text.AlignRight}
                ]
                
            case 8: // Consolidado
                return [
                    {titulo: "FECHA", campo: "fecha", width: 80},
                    {titulo: "TIPO", campo: "tipo", width: 100},
                    {titulo: "DESCRIPCIÓN", campo: "descripcion", width: 200},
                    {titulo: "REGISTROS", campo: "cantidad", width: 80, align: Text.AlignRight},
                    {titulo: "VALOR (Bs)", campo: "valor", width: 120, align: Text.AlignRight}
                ]
                
            default:
                return [
                    {titulo: "FECHA", campo: "fecha", width: 80},
                    {titulo: "DESCRIPCIÓN", campo: "descripcion", width: 300},
                    {titulo: "CANT.", campo: "cantidad", width: 60, align: Text.AlignRight},
                    {titulo: "VALOR (Bs)", campo: "valor", width: 120, align: Text.AlignRight}
                ]
        }
    }
    
    function obtenerValorColumna(index, campo) {
        if (!datosReporte[index]) return "---"
        
        var registro = datosReporte[index]
        
        switch(campo) {
            case "fecha":
                return registro.fecha || "---"
            case "descripcion":
                return registro.descripcion || "---"
            case "cantidad":
                return (registro.cantidad || 0).toString()
            case "valor":
                return (registro.valor || 0).toFixed(2)
            case "numeroVenta":
                return registro.numeroVenta || ("V" + String(index + 1).padStart(3, '0'))
            case "numeroCompra":
                return registro.numeroCompra || ("C" + String(index + 1).padStart(3, '0'))
            case "codigo":
                return registro.codigo || ("COD" + String(index + 1).padStart(3, '0'))
            case "unidad":
                return registro.unidad || ["UND", "CAJ", "FRA", "TAB", "AMP"][index % 5]
            case "precioUnitario":
                return registro.precioUnitario ? registro.precioUnitario.toFixed(2) :
                       (registro.valor && registro.cantidad ? 
                       (registro.valor / registro.cantidad).toFixed(2) : "0.00")
            case "especialidad":
                return registro.especialidad || 
                       ["Cardiología", "Neurología", "Pediatría", "Ginecología", "Medicina General"][index % 5]
            case "medico":
                return registro.medico || registro.descripcion || "---"
            case "paciente":
                return registro.paciente || 
                       ["Ana María López", "Carlos Eduardo Martínez", "Elena Isabel Vargas", "Roberto Silva", "Patricia Morales"][index % 5]
            case "estado":
                return registro.estado || ["Procesado", "Pendiente", "Entregado"][index % 3]
            case "categoria":
                return registro.categoria || ["Servicios", "Personal", "Suministros", "Mantenimiento"][index % 4]
            case "tipo":
                return registro.tipo || (registro.valor >= 0 ? "INGRESO" : "EGRESO")
            case "cliente":
                return registro.cliente || registro.paciente || "---"
            case "proveedor":
                return registro.proveedor || registro.descripcion || "---"
            default:
                return registro[campo] || "---"
        }
    }
    
    Component.onCompleted: {
        console.log("📊 Módulo de Reportes Profesional inicializado completamente")
        console.log("📋 Tipos de reportes disponibles:", tiposReportes.length)
        
        // Establecer fechas por defecto
        var hoy = new Date()
        var primerDiaMes = new Date(hoy.getFullYear(), hoy.getMonth(), 1)
        
        fechaDesdeField.text = Qt.formatDate(primerDiaMes, "dd/MM/yyyy")
        fechaHastaField.text = Qt.formatDate(hoy, "dd/MM/yyyy")
        
        fechaDesde = fechaDesdeField.text
        fechaHasta = fechaHastaField.text
    }

    function obtenerColumnasReporteCarta() {
        // Anchos optimizados para vista previa carta (650px de ancho disponible)
        if (tipoReporteSeleccionado <= 0) {
            return [
                {titulo: "FECHA", campo: "fecha", width: 65, align: Text.AlignLeft},
                {titulo: "DESCRIPCIÓN", campo: "descripcion", width: 350, align: Text.AlignLeft},
                {titulo: "CANT.", campo: "cantidad", width: 50, align: Text.AlignRight},
                {titulo: "VALOR (Bs)", campo: "valor", width: 85, align: Text.AlignRight}
            ]
        }
        
        switch(tipoReporteSeleccionado) {
            case 1: // Ventas - Total: 600px
                return [
                    {titulo: "FECHA", campo: "fecha", width: 65, align: Text.AlignLeft},
                    {titulo: "N° VENTA", campo: "numeroVenta", width: 65, align: Text.AlignLeft},
                    {titulo: "CLIENTE/DESCRIPCIÓN", campo: "descripcion", width: 280, align: Text.AlignLeft},
                    {titulo: "CANT.", campo: "cantidad", width: 45, align: Text.AlignRight},
                    {titulo: "TOTAL (Bs)", campo: "valor", width: 85, align: Text.AlignRight}
                ]
                
            case 2: // Inventario - Total: 600px
                return [
                    {titulo: "CÓDIGO", campo: "codigo", width: 55, align: Text.AlignLeft},
                    {titulo: "PRODUCTO", campo: "descripcion", width: 260, align: Text.AlignLeft},
                    {titulo: "UM", campo: "unidad", width: 35, align: Text.AlignCenter},
                    {titulo: "STOCK", campo: "cantidad", width: 50, align: Text.AlignRight},
                    {titulo: "P.U.", campo: "precioUnitario", width: 55, align: Text.AlignRight},
                    {titulo: "STOCK VAL.", campo: "valor", width: 85, align: Text.AlignRight}
                ]
                
            case 3: // Compras - Total: 600px
                return [
                    {titulo: "FECHA", campo: "fecha", width: 65, align: Text.AlignLeft},
                    {titulo: "N° COMPRA", campo: "numeroCompra", width: 70, align: Text.AlignLeft},
                    {titulo: "PROVEEDOR", campo: "descripcion", width: 280, align: Text.AlignLeft},
                    {titulo: "CANT.", campo: "cantidad", width: 50, align: Text.AlignRight},
                    {titulo: "TOTAL (Bs)", campo: "valor", width: 85, align: Text.AlignRight}
                ]
                
            case 4: // Consultas - Total: 600px
                return [
                    {titulo: "FECHA", campo: "fecha", width: 65, align: Text.AlignLeft},
                    {titulo: "ESPECIALIDAD", campo: "especialidad", width: 100, align: Text.AlignLeft},
                    {titulo: "MÉDICO", campo: "descripcion", width: 180, align: Text.AlignLeft},
                    {titulo: "PACIENTE", campo: "paciente", width: 130, align: Text.AlignLeft},
                    {titulo: "VALOR (Bs)", campo: "valor", width: 75, align: Text.AlignRight}
                ]
                
            case 5: // Laboratorio - Total: 600px
                return [
                    {titulo: "FECHA", campo: "fecha", width: 65, align: Text.AlignLeft},
                    {titulo: "EXAMEN", campo: "descripcion", width: 220, align: Text.AlignLeft},
                    {titulo: "PACIENTE", campo: "paciente", width: 130, align: Text.AlignLeft},
                    {titulo: "ESTADO", campo: "estado", width: 70, align: Text.AlignCenter},
                    {titulo: "VALOR (Bs)", campo: "valor", width: 75, align: Text.AlignRight}
                ]
                
            case 6: // Enfermería - Total: 600px
                return [
                    {titulo: "FECHA", campo: "fecha", width: 65, align: Text.AlignLeft},
                    {titulo: "PROCEDIMIENTO", campo: "descripcion", width: 240, align: Text.AlignLeft},
                    {titulo: "PACIENTE", campo: "paciente", width: 130, align: Text.AlignLeft},
                    {titulo: "CANT.", campo: "cantidad", width: 50, align: Text.AlignRight},
                    {titulo: "TOTAL (Bs)", campo: "valor", width: 75, align: Text.AlignRight}
                ]
                
            case 7: // Gastos - Total: 600px
                return [
                    {titulo: "FECHA", campo: "fecha", width: 65, align: Text.AlignLeft},
                    {titulo: "CATEGORÍA", campo: "categoria", width: 90, align: Text.AlignLeft},
                    {titulo: "DESCRIPCIÓN", campo: "descripcion", width: 300, align: Text.AlignLeft},
                    {titulo: "MONTO (Bs)", campo: "valor", width: 85, align: Text.AlignRight}
                ]
                
            case 8: // Consolidado - Total: 600px
                return [
                    {titulo: "FECHA", campo: "fecha", width: 65, align: Text.AlignLeft},
                    {titulo: "TIPO", campo: "tipo", width: 80, align: Text.AlignCenter},
                    {titulo: "DESCRIPCIÓN", campo: "descripcion", width: 260, align: Text.AlignLeft},
                    {titulo: "REGISTROS", campo: "cantidad", width: 70, align: Text.AlignRight},
                    {titulo: "VALOR (Bs)", campo: "valor", width: 85, align: Text.AlignRight}
                ]
                
            default:
                return [
                    {titulo: "FECHA", campo: "fecha", width: 65, align: Text.AlignLeft},
                    {titulo: "DESCRIPCIÓN", campo: "descripcion", width: 350, align: Text.AlignLeft},
                    {titulo: "CANT.", campo: "cantidad", width: 50, align: Text.AlignRight},
                    {titulo: "VALOR (Bs)", campo: "valor", width: 85, align: Text.AlignRight}
                ]
        }
    }

    function obtenerValorColumnaCarta(index, campo) {
        if (!datosReporte[index]) return "---"
        
        var registro = datosReporte[index]
        var valor = obtenerValorColumna(index, campo)
        
        // Truncar texto largo para ajustarse mejor a carta
        if (campo === "descripcion" && valor.length > 35) {
            return valor.substring(0, 32) + "..."
        }
        
        if (campo === "paciente" && valor.length > 20) {
            return valor.substring(0, 17) + "..."
        }
        
        if (campo === "especialidad" && valor.length > 15) {
            return valor.substring(0, 12) + "..."
        }
        
        if (campo === "categoria" && valor.length > 12) {
            return valor.substring(0, 9) + "..."
        }
        
        return valor
    }

    // Función para validar que el reporte se ajuste a carta
    function validarFormatoCarta() {
        if (datosReporte.length > 30) {
            console.log("⚠️ Advertencia: El reporte tiene más de 30 registros. En el PDF se mostrarán todos, pero la vista previa se limitará.")
        }
        
        return true
    }

   // ===== FUNCIÓN DESCARGAR PDF PROFESIONAL =====
    function descargarPDF() {
        console.log("📄 Iniciando generación de PDF profesional via Python...")
        
        try {
            // Validar que hay datos para generar
            if (!datosReporte || datosReporte.length === 0) {
                console.log("❌ No hay datos para generar el reporte")
                mostrarNotificacionError("No hay datos para generar el reporte")
                return
            }
            
            // Convertir datos a JSON string
            var datosJson = JSON.stringify(datosReporte)
            
            console.log("📊 Enviando", datosReporte.length, "registros al backend Python...")
            console.log("📅 Período:", fechaDesde, "al", fechaHasta)
            console.log("📋 Tipo de reporte:", tipoReporteSeleccionado)
            
            // Llamar al backend Python
            var rutaArchivo = appController.generarReportePDF(
                datosJson, 
                tipoReporteSeleccionado.toString(),
                fechaDesde, 
                fechaHasta
            )
            
            // Verificar resultado
            if (rutaArchivo && rutaArchivo.length > 0) {
                console.log("✅ PDF profesional generado exitosamente:", rutaArchivo)
                
                // Extraer solo el nombre del archivo para mostrar
                var nombreArchivo = rutaArchivo.split("/").pop().split("\\").pop()
                
                mostrarNotificacionDescarga(nombreArchivo, rutaArchivo)
                
                // Opcional: abrir el archivo automáticamente
                Qt.openUrlExternally("file:///" + rutaArchivo)
                
            } else {
                console.log("❌ Error: Backend Python no pudo generar el PDF")
                mostrarNotificacionError("Error al generar el PDF. Verifique los datos.")
            }
            
        } catch (error) {
            console.log("❌ Error en descargarPDF():", error)
            mostrarNotificacionError("Error inesperado al generar el PDF")
        }
    }

    // ===== FUNCIÓN NOTIFICACIÓN DESCARGA PROFESIONAL =====
    function mostrarNotificacionDescarga(nombreArchivo, rutaCompleta) {
        // Crear notificación temporal mejorada PROFESIONAL
        var notificacion = Qt.createQmlObject(`
            import QtQuick 2.15
            import QtQuick.Controls 2.15
            import QtQuick.Layouts 1.15
            
            Rectangle {
                id: notification
                width: 480
                height: 110
                color: "${successColor}"
                radius: 8
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 20
                z: 1000
                
                // Sombra profesional
                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 3
                    anchors.leftMargin: 3
                    color: "#20000000"
                    radius: parent.radius
                    z: -1
                }
                
                // Animación de entrada
                opacity: 0
                Component.onCompleted: {
                    opacity = 1
                    timer.start()
                }
                
                Behavior on opacity {
                    NumberAnimation { duration: 400 }
                }
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 15
                    
                    Rectangle {
                        width: 55
                        height: 55
                        color: "${whiteColor}"
                        radius: 8
                        
                        Label {
                            anchors.centerIn: parent
                            text: "📄"
                            font.pixelSize: 28
                        }
                    }
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        
                        Label {
                            text: "PDF Profesional Generado Exitosamente"
                            font.bold: true
                            font.pixelSize: 15
                            font.family: "Segoe UI"
                            color: "${whiteColor}"
                        }
                        
                        Label {
                            text: "Archivo: " + nombreArchivo
                            font.pixelSize: 12
                            font.family: "Segoe UI"
                            color: "${whiteColor}"
                            opacity: 0.9
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                        
                        Label {
                            text: "📁 Guardado en: Documents/Reportes_CMI/"
                            font.pixelSize: 10
                            font.family: "Segoe UI"
                            color: "${whiteColor}"
                            opacity: 0.8
                        }
                    }
                    
                    Button {
                        text: "×"
                        Layout.preferredWidth: 35
                        Layout.preferredHeight: 35
                        
                        background: Rectangle {
                            color: parent.pressed ? "${whiteColor}" : "transparent"
                            radius: 17
                            opacity: parent.pressed ? 0.3 : 0.1
                        }
                        
                        contentItem: Label {
                            text: parent.text
                            color: "${whiteColor}"
                            font.bold: true
                            font.pixelSize: 16
                            font.family: "Segoe UI"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: notification.destroy()
                    }
                }
                
                Timer {
                    id: timer
                    interval: 10000  // 10 segundos
                    onTriggered: {
                        notification.opacity = 0
                        Qt.callLater(function() { notification.destroy() })
                    }
                }
            }
        `, reportesRoot)
    }

    // ===== FUNCIÓN NOTIFICACIÓN ERROR PROFESIONAL =====
    function mostrarNotificacionError(mensaje) {
        var notificacion = Qt.createQmlObject(`
            import QtQuick 2.15
            import QtQuick.Controls 2.15
            import QtQuick.Layouts 1.15
            
            Rectangle {
                id: errorNotification
                width: 420
                height: 100
                color: "${dangerColor}"
                radius: 8
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 20
                z: 1000
                
                // Sombra profesional
                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 3
                    anchors.leftMargin: 3
                    color: "#20000000"
                    radius: parent.radius
                    z: -1
                }
                
                opacity: 0
                Component.onCompleted: {
                    opacity = 1
                    timer.start()
                }
                
                Behavior on opacity {
                    NumberAnimation { duration: 400 }
                }
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 12
                    
                    Label {
                        text: "❌"
                        font.pixelSize: 28
                        color: "${whiteColor}"
                    }
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        
                        Label {
                            text: "Error al Generar PDF Profesional"
                            font.bold: true
                            font.pixelSize: 15
                            font.family: "Segoe UI"
                            color: "${whiteColor}"
                        }
                        
                        Label {
                            text: mensaje || "Intente nuevamente o contacte al administrador"
                            font.pixelSize: 12
                            font.family: "Segoe UI"
                            color: "${whiteColor}"
                            opacity: 0.9
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                    
                    Button {
                        text: "×"
                        Layout.preferredWidth: 35
                        Layout.preferredHeight: 35
                        
                        background: Rectangle {
                            color: parent.pressed ? "${whiteColor}" : "transparent"
                            radius: 17
                            opacity: parent.pressed ? 0.3 : 0.1
                        }
                        
                        contentItem: Label {
                            text: parent.text
                            color: "${whiteColor}"
                            font.bold: true
                            font.pixelSize: 16
                            font.family: "Segoe UI"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: errorNotification.destroy()
                    }
                }
                
                Timer {
                    id: timer
                    interval: 7000
                    onTriggered: {
                        errorNotification.opacity = 0
                        Qt.callLater(function() { errorNotification.destroy() })
                    }
                }
            }
        `, reportesRoot)
    }
}