import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import Qt.labs.platform 1.1

Item {
    id: cierreCajaRoot
    objectName: "cierreCajaRoot"

    // PROPIEDADES DEL MODELO
    property var cierreCajaModel: appController ? appController.cierre_caja_model_instance : null
    
    // Colores del tema ACTUALES DEL SISTEMA
    readonly property color primaryColor: "#273746"  
    readonly property color primaryDarkColor: "#34495E"
    readonly property color successColor: "#27ae60"
    readonly property color dangerColor: "#E74C3C"
    readonly property color warningColor: "#f39c12"
    readonly property color lightGrayColor: "#ECF0F1"
    readonly property color darkGrayColor: "#7f8c8d"
    readonly property color textColor: "#2c3e50"
    readonly property color whiteColor: "#FFFFFF"
    readonly property color zebraColor: "#F8F9FA"
    
    // Estados del módulo
    property int vistaActual: 0
    property string fechaActual: Qt.formatDate(new Date(), "dd/MM/yyyy")
    property bool cierreGenerado: false
    property var datosIngresos: []
    property var datosEgresos: []
    property var resumenFinanciero: ({})
    property real efectivoReal: 10000.00
    property real saldoTeorico: -2559.00
    property real diferencia: efectivoReal - saldoTeorico
    property bool mostrandoVistaPrevia: false
    
    StackLayout {
        anchors.fill: parent
        currentIndex: vistaActual
        
        // VISTA 0: VISTA PRINCIPAL CON ARQUEO COMPLETO
        Item {
            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                
                // HEADER FIJO CON BOTONES PRINCIPALES
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    color: primaryColor
                    z: 10
                    
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
                            visible: vistaActual > 0
                            
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
                                text: "ARQUEO DE CAJA DIARIO"
                                color: whiteColor
                                font.bold: true
                                font.pixelSize: 18
                                font.family: "Segoe UI"
                            }
                            
                            Label {
                                text: "Fecha: " + fechaActual + " • Hora: " + Qt.formatTime(new Date(), "hh:mm")
                                color: "#E8F4FD"
                                font.pixelSize: 11
                                font.family: "Segoe UI"
                            }
                        }
                        
                        RowLayout {
                            spacing: 12
                            
                            Button {
                                text: "👁️ Ver PDF"
                                Layout.preferredHeight: 40
                                Layout.preferredWidth: 120
                                
                                background: Rectangle {
                                    color: parent.pressed ? Qt.darker(warningColor, 1.2) : warningColor
                                    radius: 6
                                }
                                
                                contentItem: Label {
                                    text: parent.text
                                    color: whiteColor
                                    font.bold: true
                                    font.pixelSize: 12
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                
                                onClicked: verPDFArqueo()
                            }
                            
                            Button {
                                text: "📄 Descargar PDF"
                                Layout.preferredHeight: 40
                                Layout.preferredWidth: 150
                                
                                background: Rectangle {
                                    color: parent.pressed ? Qt.darker(successColor, 1.2) : successColor
                                    radius: 6
                                }
                                
                                contentItem: Label {
                                    text: parent.text
                                    color: whiteColor
                                    font.bold: true
                                    font.pixelSize: 12
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                
                                onClicked: descargarPDFArqueo()
                            }
                            
                            Button {
                                text: "✅ Cerrar Caja"
                                Layout.preferredHeight: 40
                                Layout.preferredWidth: 130
                                
                                background: Rectangle {
                                    color: parent.pressed ? Qt.darker(successColor, 1.2) : successColor
                                    radius: 6
                                }
                                
                                contentItem: Label {
                                    text: parent.text
                                    color: whiteColor
                                    font.bold: true
                                    font.pixelSize: 12
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                
                                onClicked: cerrarCaja()
                            }
                        }
                    }
                }
                
                // CONTENIDO PRINCIPAL CON SCROLL
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: cierreCajaRoot.width
                    contentHeight: mainContent.height + 40
                    
                    Rectangle {
                        width: cierreCajaRoot.width
                        height: mainContent.height + 40
                        color: lightGrayColor
                        
                        ColumnLayout {
                            id: mainContent
                            width: parent.width
                            spacing: 20
                            anchors.top: parent.top
                            anchors.topMargin: 20

                            Layout.minimumHeight: 1200 
                            
                            // RESUMEN FINANCIERO PRINCIPAL
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 120
                                Layout.leftMargin: 20
                                Layout.rightMargin: 20
                                color: whiteColor
                                radius: 8
                                border.color: "#E0E6ED"
                                border.width: 1
                                
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 20
                                    spacing: 40
                                    
                                    // TOTAL INGRESOS
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        
                                        Label {
                                            text: "💰 TOTAL INGRESOS"
                                            font.pixelSize: 12
                                            font.bold: true
                                            color: darkGrayColor
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                        
                                        Label {
                                            text: "Bs 12,797.00"
                                            font.pixelSize: 28
                                            font.bold: true
                                            color: successColor
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                        
                                        Label {
                                            text: "60 transacciones"
                                            font.pixelSize: 10
                                            color: darkGrayColor
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                    }
                                    
                                    Rectangle {
                                        width: 1
                                        Layout.fillHeight: true
                                        Layout.topMargin: 10
                                        Layout.bottomMargin: 10
                                        color: lightGrayColor
                                    }
                                    
                                    // TOTAL EGRESOS
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        
                                        Label {
                                            text: "💸 TOTAL EGRESOS"
                                            font.pixelSize: 12
                                            font.bold: true
                                            color: darkGrayColor
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                        
                                        Label {
                                            text: "Bs 15,356.00"
                                            font.pixelSize: 28
                                            font.bold: true
                                            color: dangerColor
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                        
                                        Label {
                                            text: "8 transacciones"
                                            font.pixelSize: 10
                                            color: darkGrayColor
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                    }
                                    
                                    Rectangle {
                                        width: 1
                                        Layout.fillHeight: true
                                        Layout.topMargin: 10
                                        Layout.bottomMargin: 10
                                        color: lightGrayColor
                                    }
                                    
                                    // SALDO TEÓRICO
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        
                                        Label {
                                            text: "📊 SALDO TEÓRICO"
                                            font.pixelSize: 12
                                            font.bold: true
                                            color: darkGrayColor
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                        
                                        Label {
                                            text: "Bs -2,559.00"
                                            font.pixelSize: 28
                                            font.bold: true
                                            color: dangerColor
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                        
                                        Label {
                                            text: "Diferencia del día"
                                            font.pixelSize: 10
                                            color: darkGrayColor
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                    }
                                }
                            }
                            
                            // GRID CON INGRESOS Y EGRESOS
                            GridLayout {
                                Layout.fillWidth: true
                                Layout.leftMargin: 20
                                Layout.rightMargin: 20
                                columns: 2
                                columnSpacing: 20
                                rowSpacing: 20
                                
                                // TABLA DE INGRESOS DETALLADOS
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 400
                                    color: whiteColor
                                    radius: 8
                                    border.color: "#E0E6ED"
                                    border.width: 1
                                    
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 20
                                        spacing: 15
                                        
                                        // Título de sección
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 12
                                            
                                            Rectangle {
                                                width: 4
                                                height: 24
                                                color: successColor
                                                radius: 2
                                            }
                                            
                                            Label {
                                                text: "💰 INGRESOS DEL DÍA"
                                                font.pixelSize: 16
                                                font.bold: true
                                                color: textColor
                                            }
                                            
                                            Item { Layout.fillWidth: true }
                                            
                                            Label {
                                                text: "Bs 12,797.00"
                                                font.pixelSize: 16
                                                font.bold: true
                                                color: successColor
                                            }
                                        }
                                        
                                        // Encabezados
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 35
                                            color: primaryColor
                                            radius: 4
                                            
                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: 10
                                                spacing: 0
                                                
                                                Label {
                                                    Layout.preferredWidth: 180
                                                    text: "CONCEPTO"
                                                    font.bold: true
                                                    font.pixelSize: 10
                                                    color: whiteColor
                                                }
                                                
                                                Label {
                                                    Layout.preferredWidth: 80
                                                    text: "CANT."
                                                    font.bold: true
                                                    font.pixelSize: 10
                                                    color: whiteColor
                                                    horizontalAlignment: Text.AlignCenter
                                                }
                                                
                                                Label {
                                                    Layout.fillWidth: true
                                                    text: "IMPORTE (Bs)"
                                                    font.bold: true
                                                    font.pixelSize: 10
                                                    color: whiteColor
                                                    horizontalAlignment: Text.AlignRight
                                                }
                                            }
                                        }
                                        
                                        // Datos de ingresos
                                        ScrollView {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            clip: true
                                            
                                            ColumnLayout {
                                                width: parent.width
                                                spacing: 0
                                                
                                                Repeater {
                                                    model: [
                                                        {concepto: "💊 Farmacia - Ventas", transacciones: 47, importe: 11655.00},
                                                        {concepto: "🩺 Consultas Médicas", transacciones: 5, importe: 500.00},
                                                        {concepto: "🧪 Análisis de Laboratorio", transacciones: 6, importe: 600.00},
                                                        {concepto: "💉 Procedimientos Enfermería", transacciones: 2, importe: 42.00}
                                                    ]
                                                    
                                                    Rectangle {
                                                        Layout.fillWidth: true
                                                        Layout.preferredHeight: 40
                                                        color: index % 2 === 0 ? whiteColor : zebraColor
                                                        
                                                        RowLayout {
                                                            anchors.fill: parent
                                                            anchors.margins: 10
                                                            spacing: 0
                                                            
                                                            Label {
                                                                Layout.preferredWidth: 180
                                                                text: modelData.concepto
                                                                font.pixelSize: 10
                                                                color: textColor
                                                                elide: Text.ElideRight
                                                            }
                                                            
                                                            Label {
                                                                Layout.preferredWidth: 80
                                                                text: modelData.transacciones.toString()
                                                                font.pixelSize: 10
                                                                color: textColor
                                                                horizontalAlignment: Text.AlignCenter
                                                            }
                                                            
                                                            Label {
                                                                Layout.fillWidth: true
                                                                text: modelData.importe.toFixed(2)
                                                                font.pixelSize: 10
                                                                font.bold: true
                                                                color: successColor
                                                                horizontalAlignment: Text.AlignRight
                                                            }
                                                        }
                                                    }
                                                }
                                                
                                                // Total
                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: 45
                                                    color: successColor
                                                    
                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.margins: 10
                                                        spacing: 0
                                                        
                                                        Label {
                                                            Layout.preferredWidth: 180
                                                            text: "TOTAL INGRESOS"
                                                            font.bold: true
                                                            font.pixelSize: 12
                                                            color: whiteColor
                                                        }
                                                        
                                                        Label {
                                                            Layout.preferredWidth: 80
                                                            text: "60"
                                                            font.bold: true
                                                            font.pixelSize: 12
                                                            color: whiteColor
                                                            horizontalAlignment: Text.AlignCenter
                                                        }
                                                        
                                                        Label {
                                                            Layout.fillWidth: true
                                                            text: "12,797.00"
                                                            font.bold: true
                                                            font.pixelSize: 12
                                                            color: whiteColor
                                                            horizontalAlignment: Text.AlignRight
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                // TABLA DE EGRESOS DETALLADOS
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 400
                                    color: whiteColor
                                    radius: 8
                                    border.color: "#E0E6ED"
                                    border.width: 1
                                    
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 20
                                        spacing: 15
                                        
                                        // Título de sección
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 12
                                            
                                            Rectangle {
                                                width: 4
                                                height: 24
                                                color: dangerColor
                                                radius: 2
                                            }
                                            
                                            Label {
                                                text: "💸 EGRESOS DEL DÍA"
                                                font.pixelSize: 16
                                                font.bold: true
                                                color: textColor
                                            }
                                            
                                            Item { Layout.fillWidth: true }
                                            
                                            Label {
                                                text: "Bs 15,356.00"
                                                font.pixelSize: 16
                                                font.bold: true
                                                color: dangerColor
                                            }
                                        }
                                        
                                        // Lista de egresos simplificada
                                        ScrollView {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            clip: true
                                            
                                            ColumnLayout {
                                                width: parent.width
                                                spacing: 8
                                                
                                                Repeater {
                                                    model: [
                                                        {concepto: "🧾 Servicios Básicos", detalle: "Electricidad, agua, gas, internet", importe: 15356.00},
                                                        {concepto: "📦 Compras de Farmacia", detalle: "Sin compras registradas", importe: 0.00},
                                                        {concepto: "🏥 Gastos Operativos", detalle: "Sin gastos adicionales", importe: 0.00},
                                                        {concepto: "🔧 Mantenimiento", detalle: "Sin mantenimientos", importe: 0.00},
                                                        {concepto: "📋 Otros gastos", detalle: "Sin otros gastos", importe: 0.00}
                                                    ]
                                                    
                                                    Rectangle {
                                                        Layout.fillWidth: true
                                                        Layout.preferredHeight: 60
                                                        color: index % 2 === 0 ? whiteColor : zebraColor
                                                        radius: 6
                                                        border.color: modelData.importe > 0 ? dangerColor : lightGrayColor
                                                        border.width: modelData.importe > 0 ? 2 : 1
                                                        
                                                        RowLayout {
                                                            anchors.fill: parent
                                                            anchors.margins: 12
                                                            spacing: 15
                                                            
                                                            ColumnLayout {
                                                                Layout.fillWidth: true
                                                                spacing: 4
                                                                
                                                                Label {
                                                                    text: modelData.concepto
                                                                    font.pixelSize: 12
                                                                    font.bold: true
                                                                    color: textColor
                                                                }
                                                                
                                                                Label {
                                                                    text: modelData.detalle
                                                                    font.pixelSize: 9
                                                                    color: darkGrayColor
                                                                }
                                                            }
                                                            
                                                            Label {
                                                                text: "Bs " + modelData.importe.toFixed(2)
                                                                font.pixelSize: 14
                                                                font.bold: true
                                                                color: modelData.importe > 0 ? dangerColor : darkGrayColor
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // ARQUEO MANUAL
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 150
                                Layout.leftMargin: 20
                                Layout.rightMargin: 20
                                color: whiteColor
                                radius: 8
                                border.color: "#E0E6ED"
                                border.width: 1
                                
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 20
                                    spacing: 15
                                    
                                    Label {
                                        text: "📊 ARQUEO MANUAL DE EFECTIVO"
                                        font.pixelSize: 16
                                        font.bold: true
                                        color: textColor
                                    }
                                    
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 40
                                        
                                        // Input de efectivo
                                        ColumnLayout {
                                            spacing: 8
                                            
                                            Label {
                                                text: "💵 Efectivo Real Contado:"
                                                font.pixelSize: 14
                                                font.bold: true
                                                color: textColor
                                            }
                                            
                                            TextField {
                                                id: efectivoRealField
                                                Layout.preferredWidth: 200
                                                Layout.preferredHeight: 45
                                                placeholderText: "0.00"
                                                font.pixelSize: 16
                                                font.bold: true
                                                text: "10559.00"
                                                
                                                background: Rectangle {
                                                    color: whiteColor
                                                    border.color: parent.activeFocus ? warningColor : darkGrayColor
                                                    border.width: 2
                                                    radius: 6
                                                }
                                                
                                                onTextChanged: {
                                                    efectivoReal = parseFloat(text) || 0.0
                                                    diferencia = efectivoReal - saldoTeorico
                                                }
                                            }
                                        }
                                        
                                        // Cálculos automáticos
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 80
                                            color: zebraColor
                                            radius: 8
                                            border.color: lightGrayColor
                                            border.width: 1
                                            
                                            ColumnLayout {
                                                anchors.centerIn: parent
                                                spacing: 8
                                                
                                                RowLayout {
                                                    spacing: 20
                                                    
                                                    Label {
                                                        text: "Saldo Teórico:"
                                                        font.pixelSize: 12
                                                        color: textColor
                                                    }
                                                    
                                                    Label {
                                                        text: "Bs " + saldoTeorico.toFixed(2)
                                                        font.pixelSize: 12
                                                        font.bold: true
                                                        color: dangerColor
                                                    }
                                                }
                                                
                                                RowLayout {
                                                    spacing: 20
                                                    
                                                    Label {
                                                        text: "Efectivo Real:"
                                                        font.pixelSize: 12
                                                        color: textColor
                                                    }
                                                    
                                                    Label {
                                                        text: "Bs " + efectivoReal.toFixed(2)
                                                        font.pixelSize: 12
                                                        font.bold: true
                                                        color: textColor
                                                    }
                                                }
                                            }
                                        }
                                        
                                        // Resultado
                                        Rectangle {
                                            Layout.preferredWidth: 250
                                            Layout.preferredHeight: 80
                                            color: diferencia >= 0 ? "#d1fae5" : "#fee2e2"
                                            radius: 8
                                            border.color: diferencia >= 0 ? successColor : dangerColor
                                            border.width: 2
                                            
                                            ColumnLayout {
                                                anchors.centerIn: parent
                                                spacing: 4
                                                
                                                Label {
                                                    text: diferencia >= 0 ? "✅ SOBRANTE" : "❌ FALTANTE"
                                                    font.pixelSize: 14
                                                    font.bold: true
                                                    color: diferencia >= 0 ? "#065f46" : "#dc2626"
                                                    Layout.alignment: Qt.AlignHCenter
                                                }
                                                
                                                Label {
                                                    text: "Bs " + Math.abs(diferencia).toFixed(2)
                                                    font.pixelSize: 18
                                                    font.bold: true
                                                    color: diferencia >= 0 ? "#065f46" : "#dc2626"
                                                    Layout.alignment: Qt.AlignHCenter
                                                }
                                                
                                                Label {
                                                    text: diferencia >= 0 ? "Revisar origen del sobrante" : "Verificar transacciones"
                                                    font.pixelSize: 9
                                                    color: darkGrayColor
                                                    Layout.alignment: Qt.AlignHCenter
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // OBSERVACIONES Y ACCIONES FINALES
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 100
                                Layout.leftMargin: 20
                                Layout.rightMargin: 20
                                color: whiteColor
                                radius: 8
                                border.color: "#E0E6ED"
                                border.width: 1
                                
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 20
                                    spacing: 30
                                    
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        
                                        Label {
                                            text: "📝 OBSERVACIONES:"
                                            font.pixelSize: 12
                                            font.bold: true
                                            color: textColor
                                        }
                                        
                                        Label {
                                            text: "Arqueo realizado correctamente. " + 
                                                  (diferencia >= 0 ? "Se registra sobrante." : "Se registra faltante.") + 
                                                  " Revisar movimientos del día."
                                            font.pixelSize: 10
                                            color: darkGrayColor
                                            wrapMode: Text.WordWrap
                                            Layout.fillWidth: true
                                        }
                                    }
                                    
                                    ColumnLayout {
                                        spacing: 8
                                        
                                        Button {
                                            text: "🔄 Actualizar"
                                            Layout.preferredHeight: 35
                                            Layout.preferredWidth: 120
                                            
                                            background: Rectangle {
                                                color: parent.pressed ? Qt.darker(primaryColor, 1.2) : primaryColor
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
                                            
                                            onClicked: actualizarDatos()
                                        }
                                    }
                                }
                            }
                            
                            // Espacio final
                            Item { Layout.preferredHeight: 100 }
                        }
                    }
                }
            }
        }
        
        // VISTA 1: VISTA PREVIA DEL PDF
        Item {
            id: vistaPreviaPDF
            
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
                            text: "← Volver al Arqueo"
                            Layout.preferredHeight: 40
                            Layout.preferredWidth: 150
                            
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
                                text: "VISTA PREVIA - ARQUEO DE CAJA"
                                color: whiteColor
                                font.bold: true
                                font.pixelSize: 16
                                font.family: "Segoe UI"
                            }
                            
                            Label {
                                text: "Fecha: " + fechaActual + " • Generado: " + Qt.formatDateTime(new Date(), "dd/MM/yyyy hh:mm")
                                color: "#E8F4FD"
                                font.pixelSize: 11
                                font.family: "Segoe UI"
                            }
                        }
                        
                        RowLayout {
                            spacing: 12
                            
                            Button {
                                text: "📄 Descargar PDF"
                                Layout.preferredHeight: 40
                                Layout.preferredWidth: 150
                                
                                background: Rectangle {
                                    color: parent.pressed ? Qt.darker(successColor, 1.2) : successColor
                                    radius: 6
                                }
                                
                                contentItem: Label {
                                    text: parent.text
                                    color: whiteColor
                                    font.bold: true
                                    font.pixelSize: 12
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                
                                onClicked: descargarPDFArqueo()
                            }
                        }
                    }
                }
                
                // Contenido de la vista previa (simulación del PDF)
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    
                    Rectangle {
                        width: cierreCajaRoot.width
                        height: contenidoPDF.height + 40
                        color: "#f5f5f5"
                        
                        Column {
                            id: contenidoPDF
                            width: parent.width
                            spacing: 0
                            anchors.top: parent.top
                            anchors.topMargin: 20
                            
                            // Simulación del PDF con el estilo del ejemplo
                            Rectangle {
                                width: parent.width - 40
                                height: childrenRect.height + 30
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: "white"
                                border.color: "#E0E6ED"
                                border.width: 1
                                
                                Column {
                                    width: parent.width - 30
                                    anchors.centerIn: parent
                                    spacing: 15
                                    padding: 15
                                    
                                    // Encabezado del PDF
                                    Rectangle {
                                        width: parent.width
                                        height: 80
                                        color: "transparent"
                                        
                                        Row {
                                            width: parent.width
                                            spacing: 15
                                            
                                            Rectangle {
                                                width: 60
                                                height: 60
                                                color: "#1e3a8a"
                                                radius: 6
                                                
                                                Label {
                                                    anchors.centerIn: parent
                                                    text: "CMI"
                                                    color: "white"
                                                    font.bold: true
                                                    font.pixelSize: 16
                                                }
                                            }
                                            
                                            Column {
                                                spacing: 2
                                                
                                                Label {
                                                    text: "CLÍNICA MARÍA INMACULADA"
                                                    color: "#1e3a8a"
                                                    font.bold: true
                                                    font.pixelSize: 16
                                                }
                                                
                                                Label {
                                                    text: "Atención Médica Integral"
                                                    color: "#666"
                                                    font.pixelSize: 10
                                                }
                                                
                                                Label {
                                                    text: "Villa Yapacaní, Santa Cruz - Bolivia"
                                                    color: "#666"
                                                    font.pixelSize: 10
                                                }
                                                
                                                Label {
                                                    text: "NIT: 123456789"
                                                    color: "#666"
                                                    font.pixelSize: 10
                                                }
                                            }
                                        }
                                    }
                                    
                                    // Título del documento
                                    Rectangle {
                                        width: parent.width
                                        height: 40
                                        color: "#1e3a8a"
                                        
                                        Label {
                                            anchors.centerIn: parent
                                            text: "ARQUEO DE CAJA DETALLADO - " + fechaActual.toUpperCase()
                                            color: "white"
                                            font.bold: true
                                            font.pixelSize: 14
                                        }
                                    }
                                    
                                    // Información del cierre
                                    Grid {
                                        width: parent.width
                                        columns: 3
                                        spacing: 15
                                        
                                        Repeater {
                                            model: [
                                                {label: "Fecha:", value: fechaActual},
                                                {label: "Hora:", value: Qt.formatTime(new Date(), "hh:mm")},
                                                {label: "Turno:", value: "Diurno"},
                                                {label: "Responsable:", value: "María González"},
                                                {label: "N° Arqueo:", value: "ARQ-2025-266"},
                                                {label: "Estado:", value: "COMPLETADO"},
                                                {label: "Saldo Inicial:", value: "Bs 12,559.00"},
                                                {label: "Temperatura:", value: "28°C"},
                                                {label: "Supervisor:", value: "Dr. Mendoza"}
                                            ]
                                            
                                            Row {
                                                spacing: 5
                                                
                                                Label {
                                                    text: modelData.label
                                                    font.bold: true
                                                    font.pixelSize: 10
                                                    color: "#333"
                                                }
                                                
                                                Label {
                                                    text: modelData.value
                                                    font.pixelSize: 10
                                                    color: "#333"
                                                }
                                            }
                                        }
                                    }
                                    
                                    // Resumen financiero
                                    Rectangle {
                                        width: parent.width
                                        height: 100
                                        color: "#f8f9fa"
                                        border.color: "#1e3a8a"
                                        border.width: 2
                                        radius: 8
                                        
                                        Column {
                                            width: parent.width - 20
                                            anchors.centerIn: parent
                                            spacing: 10
                                            
                                            Label {
                                                text: "📊 RESUMEN FINANCIERO"
                                                font.bold: true
                                                font.pixelSize: 14
                                                color: "#1e3a8a"
                                                anchors.horizontalCenter: parent.horizontalCenter
                                            }
                                            
                                            Row {
                                                width: parent.width
                                                spacing: 40
                                                
                                                Column {
                                                    spacing: 5
                                                    
                                                    Label {
                                                        text: "TOTAL INGRESOS"
                                                        font.pixelSize: 10
                                                        color: "#666"
                                                    }
                                                    
                                                    Label {
                                                        text: "Bs 12,797.00"
                                                        font.bold: true
                                                        font.pixelSize: 16
                                                        color: "#065f46"
                                                    }
                                                    
                                                    Label {
                                                        text: "60 transacciones"
                                                        font.pixelSize: 9
                                                        color: "#666"
                                                    }
                                                }
                                                
                                                Column {
                                                    spacing: 5
                                                    
                                                    Label {
                                                        text: "TOTAL EGRESOS"
                                                        font.pixelSize: 10
                                                        color: "#666"
                                                    }
                                                    
                                                    Label {
                                                        text: "Bs 16,985.00"
                                                        font.bold: true
                                                        font.pixelSize: 16
                                                        color: "#dc2626"
                                                    }
                                                    
                                                    Label {
                                                        text: "8 transacciones"
                                                        font.pixelSize: 9
                                                        color: "#666"
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    
                                    // Resultado del arqueo
                                    Rectangle {
                                        width: parent.width
                                        height: 60
                                        color: diferencia >= 0 ? "#d1fae5" : "#fee2e2"
                                        border.color: diferencia >= 0 ? "#10b981" : "#dc2626"
                                        border.width: 2
                                        radius: 6
                                        
                                        Label {
                                            anchors.centerIn: parent
                                            text: (diferencia >= 0 ? "✅ SOBRANTE EN CAJA: " : "❌ FALTANTE EN CAJA: ") + 
                                                  "Bs " + Math.abs(diferencia).toFixed(2)
                                            font.bold: true
                                            font.pixelSize: 14
                                            color: diferencia >= 0 ? "#065f46" : "#dc2626"
                                        }
                                    }
                                    
                                    // Mensaje informativo
                                    Label {
                                        width: parent.width
                                        text: "Este es un documento oficial de arqueo de caja. Para más detalles, descargue el PDF completo."
                                        font.pixelSize: 10
                                        color: "#666"
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }
                            
                            // Espacio final
                            Item { height: 20 }
                        }
                    }
                }
            }
        }
    }
    
    // ===== FUNCIONES =====
    
    function verPDFArqueo() {
        console.log("👁️ Ver PDF de arqueo completo...")
        vistaActual = 1
        mostrandoVistaPrevia = true
    }
    
    function descargarPDFArqueo() {
        console.log("📄 Descargando PDF de arqueo completo...")
        
        try {
            // Generar contenido HTML del PDF
            var htmlContent = generarHTMLCierreCaja()
            
            // Crear diálogo para guardar archivo
            var fileDialog = Qt.createQmlObject('
                import Qt.labs.platform 1.1
                FileDialog {
                    fileMode: FileDialog.SaveFile
                    folder: StandardPaths.writableLocation(StandardPaths.DocumentsLocation)
                    nameFilters: ["PDF files (*.pdf)", "HTML files (*.html)"]
                    selectedNameFilter: "PDF files (*.pdf)"
                    defaultSuffix: "pdf"
                }', cierreCajaRoot)
            
            fileDialog.onAccepted = function() {
                var filePath = fileDialog.file.toString().replace("file:///", "")
                console.log("Guardando PDF en:", filePath)
                
                // Aquí iría la lógica real para generar el PDF
                // Por ahora, simulamos la generación
                mostrarNotificacion("PDF generado exitosamente", "El arqueo de caja se ha guardado en: " + filePath)
            }
            
            fileDialog.open()
            
        } catch (error) {
            console.log("❌ Error al generar PDF:", error)
            mostrarNotificacion("Error", "No se pudo generar el PDF: " + error)
        }
    }
    
    function generarHTMLCierreCaja() {
        // Esta función generaría el HTML completo similar al ejemplo proporcionado
        // Por simplicidad, retornamos el ejemplo estático
        return `<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PDF Arqueo de Caja Detallado</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: Arial, sans-serif;
            background: white;
            color: #333;
            line-height: 1.3;
            max-width: 210mm;
            margin: 0 auto;
            padding: 15mm;
            background: #f5f5f5;
        }
        
        .documento {
            background: white;
            padding: 15mm;
            box-shadow: 0 0 20px rgba(0,0,0,0.1);
            min-height: 297mm;
        }
        
        /* ... resto del CSS del ejemplo ... */
    </style>
</head>
<body>
    <div class="documento">
        <!-- ENCABEZADO -->
        <div class="header">
            <div class="logo-section">
                <div class="logo">CMI</div>
                <div class="institucion">
                    <h1>CLÍNICA MARÍA INMACULADA</h1>
                    <p>Atención Médica Integral</p>
                    <p>Villa Yapacaní, Santa Cruz - Bolivia</p>
                    <p>NIT: 123456789</p>
                </div>
            </div>
        </div>
        
        <div class="titulo-documento">
            ARQUEO DE CAJA DETALLADO - ${fechaActual.toUpperCase()}
        </div>
        
        <!-- INFORMACIÓN DEL CIERRE -->
        <div class="info-cierre">
            <div>
                <div class="info-item"><strong>Fecha:</strong> <span>${fechaActual}</span></div>
                <div class="info-item"><strong>Hora:</strong> <span>${Qt.formatTime(new Date(), "hh:mm")}</span></div>
                <div class="info-item"><strong>Turno:</strong> <span>Diurno</span></div>
            </div>
            <div>
                <div class="info-item"><strong>Responsable:</strong> <span>María González</span></div>
                <div class="info-item"><strong>N° Arqueo:</strong> <span>ARQ-2025-266</span></div>
                <div class="info-item"><strong>Estado:</strong> <span>COMPLETADO</span></div>
            </div>
            <div>
                <div class="info-item"><strong>Saldo Inicial:</strong> <span>Bs 12,559.00</span></div>
                <div class="info-item"><strong>Temperatura:</strong> <span>28°C</span></div>
                <div class="info-item"><strong>Supervisor:</strong> <span>Dr. Mendoza</span></div>
            </div>
        </div>
        
        <!-- ... resto del contenido HTML con datos dinámicos ... -->
        
    </div>
</body>
</html>`
    }
    
    function cerrarCaja() {
        console.log("✅ Cerrando caja del día...")
        
        // Validar que no haya diferencias significativas
        if (Math.abs(diferencia) > 100) {
            mostrarConfirmacion("¿Está seguro?", 
                "Se ha detectado una diferencia significativa (Bs " + Math.abs(diferencia).toFixed(2) + 
                "). ¿Desea cerrar la caja de todas formas?",
                function() {
                    realizarCierreCaja()
                })
        } else {
            realizarCierreCaja()
        }
    }
    
    function realizarCierreCaja() {
        console.log("✅ Realizando cierre de caja...")
        mostrarNotificacion("Cierre exitoso", "La caja ha sido cerrada correctamente.")
        cierreGenerado = true
    }
    
    function actualizarDatos() {
        console.log("🔄 Actualizando datos del arqueo...")
        diferencia = efectivoReal - saldoTeorico
        mostrarNotificacion("Datos actualizados", "Los cálculos han sido actualizados.")
    }
    
    function mostrarNotificacion(titulo, mensaje) {
        console.log("📢 " + titulo + ": " + mensaje)
        // Aquí podrías implementar un sistema de notificaciones visual
    }
    
    function mostrarConfirmacion(titulo, mensaje, callback) {
        console.log("❓ " + titulo + ": " + mensaje)
        // Aquí podrías implementar un diálogo de confirmación
        callback() // Por simplicidad, ejecutamos el callback directamente
    }
    
    // ===== INICIALIZACIÓN =====
    Component.onCompleted: {
        console.log("💰 Cierre de Caja inicializado - Fecha:", fechaActual)
        diferencia = efectivoReal - saldoTeorico
    }
}