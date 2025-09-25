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
    
    // PROPIEDADES DINÁMICAS DESDE EL MODEL
    property real efectivoReal: cierreCajaModel ? cierreCajaModel.efectivoReal : 0.0
    property real totalIngresos: cierreCajaModel ? cierreCajaModel.totalIngresos : 0.0
    property real totalEgresos: cierreCajaModel ? cierreCajaModel.totalEgresos : 0.0
    property real saldoTeorico: cierreCajaModel ? cierreCajaModel.saldoTeorico : 0.0
    property real diferencia: cierreCajaModel ? cierreCajaModel.diferencia : 0.0
    property bool dentroDeLimite: cierreCajaModel ? cierreCajaModel.dentroDeLimite : true
    property bool requiereAutorizacion: cierreCajaModel ? cierreCajaModel.requiereAutorizacion : false
    property string tipoDiferencia: cierreCajaModel ? cierreCajaModel.tipoDiferencia : "NEUTRO"
    
    // CONEXIONES CON EL MODEL - CORREGIDO
    Connections {
        target: cierreCajaModel
        function onDatosChanged() {
            console.log("📊 Datos de cierre actualizados")
        }
        
        function onCierreCompletado(success, message) {
            if (success) {
                mostrarNotificacion("Cierre Completado", message)
                cierreGenerado = true
            } else {
                mostrarNotificacion("Error", message)
            }
        }
        
        function onPdfGenerado(rutaArchivo) {
            console.log("✅ Señal PDF recibida: " + rutaArchivo)
            // CAMBIO: Abrir PDF en navegador automáticamente
            abrirPDFEnNavegador(rutaArchivo)
        }
        
        function onErrorOccurred(title, message) {
            mostrarNotificacion(title, message)
        }
    }

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
                                text: "📄 Generar PDF"
                                Layout.preferredHeight: 40
                                Layout.preferredWidth: 150
                                enabled: !cierreCajaModel || (!cierreCajaModel.loading && efectivoReal > 0)
                                
                                background: Rectangle {
                                    color: parent.pressed ? Qt.darker(successColor, 1.2) : (parent.enabled ? successColor : darkGrayColor)
                                    radius: 6
                                }
                                
                                contentItem: Label {
                                    text: parent.text
                                    color: whiteColor
                                    font.bold: true
                                    font.pixelSize: 12
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    opacity: parent.enabled ? 1.0 : 0.6
                                }
                                
                                onClicked: descargarPDFArqueo()
                            }
                            
                            Button {
                                text: "✅ Cerrar Caja"
                                Layout.preferredHeight: 40
                                Layout.preferredWidth: 130
                                enabled: !cierreCajaModel || (!cierreCajaModel.loading && efectivoReal > 0 && !cierreCajaModel.cierreCompletadoHoy)
                                
                                background: Rectangle {
                                    color: parent.pressed ? Qt.darker(successColor, 1.2) : (parent.enabled ? successColor : darkGrayColor)
                                    radius: 6
                                }
                                
                                contentItem: Label {
                                    text: parent.text
                                    color: whiteColor
                                    font.bold: true
                                    font.pixelSize: 12
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    opacity: parent.enabled ? 1.0 : 0.6
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
                                            text: "Bs " + totalIngresos.toFixed(2)
                                            font.pixelSize: 28
                                            font.bold: true
                                            color: successColor
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                        
                                        Label {
                                            text: (cierreCajaModel ? cierreCajaModel.transaccionesIngresos : 0) + " transacciones"
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
                                            text: "Bs " + totalEgresos.toFixed(2)
                                            font.pixelSize: 28
                                            font.bold: true
                                            color: dangerColor
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                        
                                        Label {
                                            text: (cierreCajaModel ? cierreCajaModel.transaccionesEgresos : 0) + " transacciones"
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
                                            text: "Bs " + saldoTeorico.toFixed(2)
                                            font.pixelSize: 28
                                            font.bold: true
                                            color: saldoTeorico >= 0 ? successColor : dangerColor
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
                                                text: "Bs " + totalIngresos.toFixed(2)
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
                                                    model: cierreCajaModel ? cierreCajaModel.ingresosDetalle : []
                                                    
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
                                                                text: modelData.concepto || "Sin concepto"
                                                                font.pixelSize: 10
                                                                color: textColor
                                                                elide: Text.ElideRight
                                                            }
                                                            
                                                            Label {
                                                                Layout.preferredWidth: 80
                                                                text: (modelData.transacciones || 0).toString()
                                                                font.pixelSize: 10
                                                                color: textColor
                                                                horizontalAlignment: Text.AlignCenter
                                                            }
                                                            
                                                            Label {
                                                                Layout.fillWidth: true
                                                                text: (modelData.importe || 0).toFixed(2)
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
                                                            text: (cierreCajaModel ? cierreCajaModel.transaccionesIngresos : 0).toString()
                                                            font.bold: true
                                                            font.pixelSize: 12
                                                            color: whiteColor
                                                            horizontalAlignment: Text.AlignCenter
                                                        }
                                                        
                                                        Label {
                                                            Layout.fillWidth: true
                                                            text: totalIngresos.toFixed(2)
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
                                                text: "Bs " + totalEgresos.toFixed(2)
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
                                                    model: cierreCajaModel ? cierreCajaModel.egresosDetalle : []
                                                    
                                                    Rectangle {
                                                        Layout.fillWidth: true
                                                        Layout.preferredHeight: 60
                                                        color: index % 2 === 0 ? whiteColor : zebraColor
                                                        radius: 6
                                                        border.color: (modelData.importe || 0) > 0 ? dangerColor : lightGrayColor
                                                        border.width: (modelData.importe || 0) > 0 ? 2 : 1
                                                        
                                                        RowLayout {
                                                            anchors.fill: parent
                                                            anchors.margins: 12
                                                            spacing: 15
                                                            
                                                            ColumnLayout {
                                                                Layout.fillWidth: true
                                                                spacing: 4
                                                                
                                                                Label {
                                                                    text: modelData.concepto || "Sin concepto"
                                                                    font.pixelSize: 12
                                                                    font.bold: true
                                                                    color: textColor
                                                                }
                                                                
                                                                Label {
                                                                    text: modelData.detalle || "Sin detalles"
                                                                    font.pixelSize: 9
                                                                    color: darkGrayColor
                                                                }
                                                            }
                                                            
                                                            Label {
                                                                text: "Bs " + (modelData.importe || 0).toFixed(2)
                                                                font.pixelSize: 14
                                                                font.bold: true
                                                                color: (modelData.importe || 0) > 0 ? dangerColor : darkGrayColor
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
                                                
                                                background: Rectangle {
                                                    color: whiteColor
                                                    border.color: parent.activeFocus ? warningColor : darkGrayColor
                                                    border.width: 2
                                                    radius: 6
                                                }
                                                
                                                onTextChanged: {
                                                    var nuevoValor = parseFloat(text) || 0.0
                                                    if (cierreCajaModel && nuevoValor !== efectivoReal) {
                                                        cierreCajaModel.establecerEfectivoReal(nuevoValor)
                                                    }
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
                                                        color: saldoTeorico >= 0 ? successColor : dangerColor
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
                                            color: dentroDeLimite ? "#d1fae5" : "#fee2e2"
                                            radius: 8
                                            border.color: dentroDeLimite ? successColor : dangerColor
                                            border.width: 2
                                            
                                            ColumnLayout {
                                                anchors.centerIn: parent
                                                spacing: 4
                                                
                                                Label {
                                                    text: tipoDiferencia === "SOBRANTE" ? "✅ SOBRANTE" : 
                                                          tipoDiferencia === "FALTANTE" ? "❌ FALTANTE" : "⚖️ NEUTRO"
                                                    font.pixelSize: 14
                                                    font.bold: true
                                                    color: dentroDeLimite ? "#065f46" : "#dc2626"
                                                    Layout.alignment: Qt.AlignHCenter
                                                }
                                                
                                                Label {
                                                    text: "Bs " + Math.abs(diferencia).toFixed(2)
                                                    font.pixelSize: 18
                                                    font.bold: true
                                                    color: dentroDeLimite ? "#065f46" : "#dc2626"
                                                    Layout.alignment: Qt.AlignHCenter
                                                }
                                                
                                                Label {
                                                    text: requiereAutorizacion ? "Requiere autorización" : 
                                                          tipoDiferencia === "NEUTRO" ? "Balanceado" : "Dentro del límite"
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
                                                  (tipoDiferencia === "SOBRANTE" ? "Se registra sobrante." : 
                                                   tipoDiferencia === "FALTANTE" ? "Se registra faltante." : "Sin diferencias.") + 
                                                  (requiereAutorizacion ? " Requiere autorización de supervisor." : " Dentro de límites permitidos.")
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
    }
    
    // Timer para refresh manual
    Timer {
        id: manualRefreshTimer
        interval: 5000  // 5 segundos
        running: false
        repeat: false
        onTriggered: {
            if (cierreCajaModel) {
                cierreCajaModel.forzarActualizacion()
            }
        }
    }

    // ===== FUNCIONES CORREGIDAS =====
    
    function descargarPDFArqueo() {
        console.log("📄 Generando PDF de arqueo...")
        if (cierreCajaModel) {
            var rutaPDF = cierreCajaModel.generarPDFArqueoCorregido()
            if (rutaPDF) {
                console.log("✅ PDF generado: " + rutaPDF)
                // Se abrirá automáticamente por la señal onPdfGenerado
            } else {
                console.log("❌ Error generando PDF")
                mostrarNotificacion("Error", "No se pudo generar el PDF")
            }
        }
    }
    
    function abrirPDFEnNavegador(rutaArchivo) {
        try {
            console.log("🌐 Abriendo PDF en navegador: " + rutaArchivo)
            
            // Convertir la ruta a URL válida y abrir en navegador
            var urlArchivo = "file:///" + rutaArchivo.replace(/\\/g, "/")
            Qt.openUrlExternally(urlArchivo)
            
            // Mostrar notificación de éxito
            var nombreArchivo = rutaArchivo.split("/").pop().split("\\").pop()
            mostrarNotificacion("PDF Generado", "Archivo abierto en navegador: " + nombreArchivo)
            
        } catch (error) {
            console.log("❌ Error abriendo PDF: " + error)
            mostrarNotificacion("Error", "No se pudo abrir el PDF en el navegador")
        }
    }
    
    function cerrarCaja() {
        console.log("✅ Iniciando cierre de caja...")
        if (!cierreCajaModel) return
        
        if (cierreCajaModel.validarCierre()) {
            if (requiereAutorizacion) {
                mostrarConfirmacion(
                    "Diferencia Significativa",
                    "Se detectó una diferencia de Bs " + Math.abs(diferencia).toFixed(2) + 
                    ". ¿Confirma el cierre?",
                    function() {
                        cierreCajaModel.completarCierre("Diferencia autorizada por supervisor")
                        console.log("🔒 Caja cerrada - NO se genera PDF automáticamente")
                    }
                )
            } else {
                cierreCajaModel.completarCierre("Cierre automático - diferencia dentro del límite")
                console.log("🔒 Caja cerrada - NO se genera PDF automáticamente")
            }
        }
    }
    
    function actualizarDatos() {
        console.log("🔄 Actualizando datos del arqueo...")
        if (cierreCajaModel) {
            cierreCajaModel.actualizarDatos()
        }
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
    
    function activarRefreshManual() {
        console.log("🔄 Activando refresh manual en 5 segundos...")
        manualRefreshTimer.restart()
    }
    
    // ===== INICIALIZACIÓN =====
    Component.onCompleted: {
        console.log("💰 Cierre de Caja inicializado con backend")
        if (cierreCajaModel) {
            cierreCajaModel.cargarDatosDia()
            cierreCajaModel.iniciarAutoRefresh()
            console.log("📊 Datos cargados desde BD y auto-refresh activado")
        } else {
            console.log("⚠️ CierreCajaModel no disponible")
        }
    }
}