import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import Qt.labs.platform 1.1

Item {
    id: cierreCajaRoot
    objectName: "cierreCajaRoot"

    // PROPIEDADES DEL MODELO
    property var cierreCajaModel: null
    
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
    property bool cierreGenerado: false
    property var datosIngresos: []
    property var datosEgresos: []
    property var resumenFinanciero: ({})
    
    // PROPIEDADES DINÁMICAS DESDE EL MODEL CORREGIDAS
// PROPIEDADES DINÁMICAS SIMPLIFICADAS
    property string fechaActual: cierreCajaModel ? cierreCajaModel.fechaActual : Qt.formatDate(new Date(), "dd/MM/yyyy")

    property string horaInicio: cierreCajaModel ? cierreCajaModel.horaInicio : "08:00"

    property string horaFin: cierreCajaModel ? cierreCajaModel.horaFin : Qt.formatTime(new Date(), "HH:mm")

    property real efectivoReal: cierreCajaModel ? cierreCajaModel.efectivoReal : 0.0

    property real totalIngresos: cierreCajaModel ? cierreCajaModel.totalIngresos : 0.0

    property real totalEgresos: cierreCajaModel ? cierreCajaModel.totalEgresos : 0.0

    property real saldoTeorico: cierreCajaModel ? cierreCajaModel.saldoTeorico : 0.0

    property real diferencia: cierreCajaModel ? cierreCajaModel.diferencia : 0.0

    property int totalTransacciones: cierreCajaModel ? cierreCajaModel.totalTransacciones : 0

    // Propiedades calculadas para el arqueo
    readonly property string tipoDiferencia: {
        if (Math.abs(diferencia) < 1.0) return "NEUTRO"
        else if (diferencia > 0) return "SOBRANTE"
        else return "FALTANTE"
    }

    readonly property bool dentroDeLimite: Math.abs(diferencia) <= 50.0
    readonly property bool requiereAutorizacion: Math.abs(diferencia) > 50.0
    // Propiedades calculadas para el arqueo
    
    onCierreCajaModelChanged: {
        if (cierreCajaModel) {
            // Sincronizar valores iniciales
            if (cierreCajaModel.horaFin) horaFin = cierreCajaModel.horaFin
            if (cierreCajaModel.horaInicio) horaInicio = cierreCajaModel.horaInicio
            if (cierreCajaModel.fechaActual) fechaActual = cierreCajaModel.fechaActual
        }
    }    
    onVisibleChanged: {
        if (visible) {
            console.log("💰 Módulo visible")
            // Cargar datos con delay para evitar crashes
            Qt.callLater(function() {
                if (cierreCajaModel && typeof cierreCajaModel.cargarCierresSemana === 'function') {
                    try {
                        cierreCajaModel.cargarCierresSemana()
                    } catch (error) {
                        console.log("❌ Error cargando datos:", error)
                    }
                }
            })
        }
    }

    Connections {
        target: cierreCajaModel
        function onEfectivoRealChanged() {
            if (cierreCajaModel) {
                efectivoReal = cierreCajaModel.efectivoReal
            }
        }
        function onValidacionChanged() {
            // Forzar actualización de propiedades calculadas
            cierreCajaRoot.diferencia = cierreCajaModel ? cierreCajaModel.diferencia : 0.0
        }
    }
   
    Timer {
        id: modelHealthTimer
        interval: 15000  // Reducir frecuencia
        running: false   // NO iniciar automáticamente
        repeat: true
        
        onTriggered: {
            // Solo verificar, NO reconectar automáticamente
            if (!cierreCajaModel) {
                console.log("⚠️ CierreCajaModel no disponible")
                running = false  // Detener el timer
            }
        }
    }
    Timer {
        id: initializationTimer
        interval: 1000
        running: false
        repeat: false
        
        onTriggered: {
            try {
                if (appController && appController.cierre_caja_model_instance) {
                    cierreCajaModel = appController.cierre_caja_model_instance
                    
                    if (cierreCajaModel && cierreCajaModel.usuario_actual_id > 0) {
                        // Solo cargar datos si hay usuario autenticado
                        Qt.callLater(function() {
                            if (typeof cierreCajaModel.cargarCierresSemana === 'function') {
                                cierreCajaModel.cargarCierresSemana()
                            }
                        })
                    }
                    console.log("✅ Modelo inicializado correctamente")
                } else {
                    console.log("❌ Modelo no disponible en AppController")
                }
            } catch (error) {
                console.log("❌ Error en inicialización:", error)
            }
        }
    }
    function verificarModelo() {
        if (!cierreCajaModel && appController) {
            try {
                cierreCajaModel = appController.cierre_caja_model_instance
                if (cierreCajaModel) {
                    console.log("🔄 Modelo reconectado")
                }
            } catch (error) {
                console.log("❌ Error verificando modelo:", error)
            }
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
                                enabled: cierreCajaModel && !cierreCajaModel.loading && efectivoReal > 0
                                
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
                                
                                onClicked: {
                                    if (cierreCajaModel && typeof cierreCajaModel.consultarDatos === 'function') {
                                        try {
                                            cierreCajaModel.consultarDatos()
                                        } catch (error) {
                                            console.log("❌ Error en consultarDatos:", error)
                                            if (toastNotification) {
                                                toastNotification.show("Error ejecutando operación")
                                            }
                                        }
                                    } else {
                                        console.log("❌ Modelo no disponible")
                                        if (toastNotification) {
                                            toastNotification.show("Módulo no disponible")
                                        }
                                    }
                                }
                            }
                            
                            Button {
                                text: "✅ Cerrar Caja"
                                Layout.preferredHeight: 40
                                Layout.preferredWidth: 130
                                enabled: {
                                    // Verificar que tenga modelo, no esté cargando, tenga efectivo y campos completos
                                    var habilitado = cierreCajaModel && 
                                                    !cierreCajaModel.loading && 
                                                    efectivoReal > 0 && 
                                                    fechaField.text.trim().length > 0 &&
                                                    horaInicioField.text.trim().length > 0 &&
                                                    horaFinField.text.trim().length > 0
                                    
                                    // Debug simplificado
                                    if (!habilitado) {
                                        console.log("🔍 Botón deshabilitado - Efectivo:", efectivoReal, "Campos completos:", 
                                                fechaField.text.length > 0 && horaInicioField.text.length > 0 && horaFinField.text.length > 0)
                                    }
                                    
                                    return habilitado
                                }
                                
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
                                
                                onClicked: {
                                    console.log("🖱️ Botón Cerrar Caja presionado")
                                    cerrarCaja()
                                }
                            }
                        }
                    }
                }
                
                // CONTENIDO PRINCIPAL CON SCROLL MEJORADO
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    wheelEnabled: true
                    contentWidth: availableWidth
                    contentHeight: mainContent.height + 40
                    
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    
                    Rectangle {
                        width: parent.width
                        height: mainContent.height + 40
                        color: lightGrayColor
                        
                        ColumnLayout {
                            id: mainContent
                            width: parent.width
                            spacing: 20
                            anchors.top: parent.top
                            anchors.topMargin: 20
                            
                            // SELECTOR DE FECHA Y RANGO
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
                                        spacing: 8
                                        Label {
                                            text: "📅 FECHA DEL CIERRE"
                                            font.pixelSize: 12
                                            font.bold: true
                                            color: textColor
                                        }
                                        TextField {
                                            id: fechaField
                                            Layout.preferredWidth: 120
                                            Layout.preferredHeight: 35
                                            text: fechaActual
                                            placeholderText: "DD/MM/YYYY"
                                            selectByMouse: true
                                            
                                            background: Rectangle {
                                                color: whiteColor
                                                border.color: {
                                                    if (parent.activeFocus) return primaryColor
                                                    if (parent.text.trim().length === 0) return darkGrayColor
                                                    return validarFormatoFecha(parent.text) ? successColor : dangerColor
                                                }
                                                border.width: 1
                                                radius: 4
                                            }
                                            
                                            onTextChanged: {
                                                // Solo actualizar si hay modelo y el texto tiene contenido
                                                if (cierreCajaModel && text.trim().length > 0) {
                                                    try {
                                                        cierreCajaModel.cambiarFecha(text)
                                                    } catch (error) {
                                                        console.log("Error actualizando fecha:", error)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    
                                    ColumnLayout {
                                        spacing: 8
                                        Label {
                                            text: "🕐 HORA INICIO"
                                            font.pixelSize: 12
                                            font.bold: true
                                            color: textColor
                                        }
                                        TextField {
                                            id: horaInicioField
                                            Layout.preferredWidth: 80
                                            Layout.preferredHeight: 35
                                            text: horaInicio
                                            placeholderText: "08:00"
                                            selectByMouse: true
                                            
                                            background: Rectangle {
                                                color: whiteColor
                                                border.color: {
                                                    if (parent.activeFocus) return primaryColor
                                                    if (parent.text.trim().length === 0) return darkGrayColor
                                                    return validarFormatoHora(parent.text) ? successColor : dangerColor
                                                }
                                                border.width: 1
                                                radius: 4
                                            }
                                            
                                            onTextChanged: {
                                                if (cierreCajaModel && text.trim().length > 0) {
                                                    try {
                                                        cierreCajaModel.establecerHoraInicio(text)
                                                    } catch (error) {
                                                        console.log("Error actualizando hora inicio:", error)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    
                                    ColumnLayout {
                                        spacing: 8
                                        Label {
                                            text: "🕐 HORA FIN"
                                            font.pixelSize: 12
                                            font.bold: true
                                            color: textColor
                                        }
                                        TextField {
                                            id: horaFinField
                                            Layout.preferredWidth: 80
                                            Layout.preferredHeight: 35
                                            text: horaFin
                                            placeholderText: "18:00"
                                            selectByMouse: true
                                            
                                            background: Rectangle {
                                                color: whiteColor
                                                border.color: {
                                                    if (parent.activeFocus) return primaryColor
                                                    if (parent.text.trim().length === 0) return darkGrayColor
                                                    return validarFormatoHora(parent.text) ? successColor : dangerColor
                                                }
                                                border.width: 1
                                                radius: 4
                                            }
                                            
                                            onTextChanged: {
                                                if (cierreCajaModel && text.trim().length > 0) {
                                                    try {
                                                        cierreCajaModel.establecerHoraFin(text)
                                                    } catch (error) {
                                                        console.log("Error actualizando hora fin:", error)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    
                                    Button {
                                        text: "🔄 Consultar"
                                        Layout.preferredHeight: 35
                                        Layout.preferredWidth: 120
                                        enabled: {return cierreCajaModel && 
                                                    !cierreCajaModel.loading && 
                                                    fechaField.text.trim().length > 0 && 
                                                    horaInicioField.text.trim().length > 0 && 
                                                    horaFinField.text.trim().length > 0
                                            }
                                        
                                        background: Rectangle {
                                            color: parent.pressed ? Qt.darker(primaryColor, 1.2) : (parent.enabled ? primaryColor : darkGrayColor)
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
                                        
                                        onClicked: {
                                            if (cierreCajaModel && typeof cierreCajaModel.consultarDatos === 'function') {
                                                try {
                                                    cierreCajaModel.consultarDatos()
                                                } catch (error) {
                                                    console.log("❌ Error en consultarDatos:", error)
                                                    if (toastNotification) {
                                                        toastNotification.show("Error ejecutando operación")
                                                    }
                                                }
                                            } else {
                                                console.log("❌ Modelo no disponible")
                                                if (toastNotification) {
                                                    toastNotification.show("Módulo no disponible")
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            
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
                                            text: (cierreCajaModel && cierreCajaModel.resumenRango ? cierreCajaModel.resumenRango.transacciones_ingresos : 0) + " transacciones"
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
                                            text: (cierreCajaModel && cierreCajaModel.resumenRango ? cierreCajaModel.resumenRango.transacciones_egresos : 0) + " transacciones"
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
                                    Layout.preferredHeight: 300
                                    color: whiteColor
                                    radius: 8
                                    border.color: "#E0E6ED"
                                    border.width: 1
                                    
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 20
                                        spacing: 15
                                        
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
                                        
                                        ScrollView {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            clip: true
                                            wheelEnabled: false
                                            
                                            ColumnLayout {
                                                width: parent.width
                                                spacing: 0
                                                
                                                Repeater {
                                                    model: cierreCajaModel && cierreCajaModel.resumenRango ? cierreCajaModel.resumenRango.ingresos_por_categoria : []
                                                    
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
                                            }
                                        }
                                    }
                                }
                                
                                // TABLA DE EGRESOS DETALLADOS
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 300
                                    color: whiteColor
                                    radius: 8
                                    border.color: "#E0E6ED"
                                    border.width: 1
                                    
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 20
                                        spacing: 15
                                        
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
                                        
                                        ScrollView {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            clip: true
                                            wheelEnabled: false
                                            
                                            ColumnLayout {
                                                width: parent.width
                                                spacing: 8
                                                
                                                Repeater {
                                                    model: cierreCajaModel && cierreCajaModel.resumenRango ? cierreCajaModel.resumenRango.egresos_por_categoria : []
                                                    
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
                            
                            // ARQUEO MANUAL - RECTANGLE RESPONSIVE
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 120
                                Layout.leftMargin: 20
                                Layout.rightMargin: 20
                                color: whiteColor
                                radius: 8
                                border.color: "#E0E6ED"
                                border.width: 1
                                
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 15
                                    spacing: 10
                                    
                                    Label {
                                        text: "📊 ARQUEO MANUAL DE EFECTIVO"
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: textColor
                                    }
                                    
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 15
                                        
                                        // EFECTIVO REAL CONTADO
                                        ColumnLayout {
                                            Layout.preferredWidth: 140
                                            Layout.minimumWidth: 120
                                            spacing: 4
                                            
                                            Label {
                                                text: "💵 Efectivo Real:"
                                                font.pixelSize: 12
                                                font.bold: true
                                                color: textColor
                                            }
                                            
                                            TextField {
                                                id: efectivoRealField
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 35
                                                placeholderText: "0.00"
                                                font.pixelSize: 14
                                                font.bold: true
                                                text: ""
                                                selectByMouse: true
                                                
                                                property bool actualizandoTexto: false
                                                
                                                background: Rectangle {
                                                    color: whiteColor
                                                    border.color: parent.activeFocus ? primaryColor : darkGrayColor
                                                    border.width: 1
                                                    radius: 4
                                                }
                                                
                                                onTextChanged: {
                                                    if (!actualizandoTexto && text.trim().length > 0) {
                                                        var monto = parseFloat(text) || 0
                                                        if (cierreCajaModel) {
                                                            cierreCajaModel.establecerEfectivoReal(monto)
                                                        }
                                                    }
                                                }
                                                
                                                onPressed: {
                                                    selectAll()
                                                }
                                                
                                                Connections {
                                                    target: cierreCajaModel
                                                    function onEfectivoRealChanged() {
                                                        if (cierreCajaModel && !efectivoRealField.activeFocus) {
                                                            efectivoRealField.text = cierreCajaModel.efectivoReal.toFixed(2)
                                                        }
                                                    }
                                                }
                                                
                                                validator: DoubleValidator {
                                                    bottom: 0
                                                    decimals: 2
                                                    notation: DoubleValidator.StandardNotation
                                                }
                                            }
                                        }
                                        
                                        // SEPARADOR VISUAL
                                        Rectangle {
                                            width: 1
                                            Layout.fillHeight: true
                                            Layout.topMargin: 5
                                            Layout.bottomMargin: 5
                                            color: lightGrayColor
                                        }
                                        
                                        // SALDO TEÓRICO
                                        ColumnLayout {
                                            Layout.preferredWidth: 140
                                            Layout.minimumWidth: 120
                                            spacing: 4
                                            
                                            Label {
                                                text: "📊 Saldo Teórico:"
                                                font.pixelSize: 12
                                                font.bold: true
                                                color: textColor
                                            }
                                            
                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 35
                                                color: zebraColor
                                                radius: 4
                                                border.color: lightGrayColor
                                                border.width: 1
                                                
                                                Label {
                                                    anchors.centerIn: parent
                                                    text: "Bs " + saldoTeorico.toFixed(2)
                                                    font.pixelSize: 14
                                                    font.bold: true
                                                    color: saldoTeorico >= 0 ? successColor : dangerColor
                                                }
                                            }
                                        }
                                        
                                        // SEPARADOR VISUAL
                                        Rectangle {
                                            width: 1
                                            Layout.fillHeight: true
                                            Layout.topMargin: 5
                                            Layout.bottomMargin: 5
                                            color: lightGrayColor
                                        }
                                        
                                        // ESTADO DE LA DIFERENCIA
                                        Rectangle {
                                            Layout.preferredWidth: 160
                                            Layout.minimumWidth: 140
                                            Layout.preferredHeight: 50
                                            color: dentroDeLimite ? "#d1fae5" : "#fee2e2"
                                            radius: 6
                                            border.color: dentroDeLimite ? successColor : dangerColor
                                            border.width: 2
                                            
                                            ColumnLayout {
                                                anchors.centerIn: parent
                                                spacing: 2
                                                
                                                Label {
                                                    text: tipoDiferencia === "SOBRANTE" ? "✅ SOBRANTE" : 
                                                        tipoDiferencia === "FALTANTE" ? "❌ FALTANTE" : "⚖️ NEUTRO"
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                    color: dentroDeLimite ? "#065f46" : "#dc2626"
                                                    Layout.alignment: Qt.AlignHCenter
                                                }
                                                
                                                Label {
                                                    text: "Bs " + Math.abs(diferencia).toFixed(2)
                                                    font.pixelSize: 14
                                                    font.bold: true
                                                    color: dentroDeLimite ? "#065f46" : "#dc2626"
                                                    Layout.alignment: Qt.AlignHCenter
                                                }
                                                
                                                Label {
                                                    text: requiereAutorizacion ? "Requiere autorización" : 
                                                        tipoDiferencia === "NEUTRO" ? "Balanceado" : "Dentro del límite"
                                                    font.pixelSize: 8
                                                    color: darkGrayColor
                                                    Layout.alignment: Qt.AlignHCenter
                                                }
                                            }
                                        }
                                        
                                        // SEPARADOR VISUAL
                                        Rectangle {
                                            width: 1
                                            Layout.fillHeight: true
                                            Layout.topMargin: 5
                                            Layout.bottomMargin: 5
                                            color: lightGrayColor
                                        }
                                        
                                        // OBSERVACIONES EDITABLES (SE EXPANDE PARA USAR ESPACIO RESTANTE)
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 200
                                            spacing: 4
                                            
                                            Label {
                                                text: "📝 Observaciones:"
                                                font.pixelSize: 12
                                                font.bold: true
                                                color: textColor
                                            }
                                            
                                            TextField {
                                                id: observacionesField
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 35
                                                placeholderText: "Ingrese observaciones del arqueo..."
                                                text: "Arqueo realizado correctamente. " + 
                                                    (tipoDiferencia === "SOBRANTE" ? "Se registra sobrante." : 
                                                    tipoDiferencia === "FALTANTE" ? "Se registra faltante." : "Sin diferencias.") + 
                                                    (requiereAutorizacion ? " Requiere autorización de supervisor." : " Dentro de límites permitidos.")
                                                selectByMouse: true
                                                font.pixelSize: 11
                                                
                                                background: Rectangle {
                                                    color: "#F8F9FA"
                                                    border.color: parent.activeFocus ? primaryColor : lightGrayColor
                                                    border.width: 1
                                                    radius: 4
                                                }
                                                
                                                onTextChanged: {
                                                    // Guardar observaciones en tiempo real si es necesario
                                                    if (cierreCajaModel && typeof cierreCajaModel.establecerObservaciones === 'function') {
                                                        cierreCajaModel.establecerObservaciones(text)
                                                    }
                                                }
                                                
                                                onPressed: {
                                                    if (text.includes("Arqueo realizado correctamente")) {
                                                        selectAll()
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            } 
                            
                            // LISTA DE CIERRES DE LA SEMANA (CON FECHA)
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 450
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
                                    
                                    // ENCABEZADO DE LA SECCIÓN
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
                                            text: "📋 CIERRES DE LA SEMANA ACTUAL"
                                            font.pixelSize: 16
                                            font.bold: true
                                            color: textColor
                                        }
                                        
                                        Item { Layout.fillWidth: true }
                                        
                                        Label {
                                            text: (cierreCajaModel ? cierreCajaModel.cierresDelDia.length : 0) + " cierres registrados"
                                            font.pixelSize: 12
                                            font.bold: true
                                            color: primaryColor
                                            background: Rectangle {
                                                color: "#E8F4FD"
                                                radius: 4
                                                anchors.fill: parent
                                                anchors.margins: -6
                                            }
                                        }
                                    }
                                    
                                    // ENCABEZADOS DE LA TABLA
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 45
                                        color: primaryColor
                                        radius: 6
                                        border.color: "#1a202c"
                                        border.width: 2
                                        
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 0
                                            
                                            Label {
                                                Layout.preferredWidth: 90
                                                text: "FECHA"
                                                font.bold: true
                                                font.pixelSize: 11
                                                color: whiteColor
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            
                                            Rectangle { width: 2; Layout.fillHeight: true; color: "#1a202c" }
                                            
                                            Label {
                                                Layout.preferredWidth: 110
                                                text: "HORARIO"
                                                font.bold: true
                                                font.pixelSize: 11
                                                color: whiteColor
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            
                                            Rectangle { width: 2; Layout.fillHeight: true; color: "#1a202c" }
                                            
                                            Label {
                                                Layout.preferredWidth: 120
                                                text: "EFECTIVO REAL"
                                                font.bold: true
                                                font.pixelSize: 11
                                                color: whiteColor
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            
                                            Rectangle { width: 2; Layout.fillHeight: true; color: "#1a202c" }
                                            
                                            Label {
                                                Layout.preferredWidth: 120
                                                text: "SALDO TEÓRICO"
                                                font.bold: true
                                                font.pixelSize: 11
                                                color: whiteColor
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            
                                            Rectangle { width: 2; Layout.fillHeight: true; color: "#1a202c" }
                                            
                                            Label {
                                                Layout.preferredWidth: 100
                                                text: "DIFERENCIA"
                                                font.bold: true
                                                font.pixelSize: 11
                                                color: whiteColor
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            
                                            Rectangle { width: 2; Layout.fillHeight: true; color: "#1a202c" }
                                            
                                            Label {
                                                Layout.preferredWidth: 90
                                                text: "ESTADO"
                                                font.bold: true
                                                font.pixelSize: 11
                                                color: whiteColor
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            
                                            Rectangle { width: 2; Layout.fillHeight: true; color: "#1a202c" }
                                            
                                            Label {
                                                Layout.preferredWidth: 130
                                                text: "REGISTRADO POR"
                                                font.bold: true
                                                font.pixelSize: 11
                                                color: whiteColor
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            
                                            Rectangle { width: 2; Layout.fillHeight: true; color: "#1a202c" }
                                            
                                            Label {
                                                Layout.fillWidth: true
                                                text: "OBSERVACIONES"
                                                font.bold: true
                                                font.pixelSize: 11
                                                color: whiteColor
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                        }
                                    }
                                    
                                    // LISTA DE DATOS
                                    ScrollView {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        clip: true
                                        wheelEnabled: true
                                        
                                        ScrollBar.vertical.policy: ScrollBar.AsNeeded
                                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                                        
                                        ListView {
                                            model: cierreCajaModel ? cierreCajaModel.cierresDelDia : []
                                            spacing: 1
                                            
                                            delegate: Rectangle {
                                                width: ListView.view.width
                                                height: 60
                                                color: index % 2 === 0 ? whiteColor : zebraColor
                                                border.color: "#E0E6ED"
                                                border.width: 1
                                                
                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.margins: 8
                                                    spacing: 0
                                                    
                                                    // FECHA
                                                    Rectangle {
                                                        Layout.preferredWidth: 90
                                                        Layout.fillHeight: true
                                                        color: "transparent"
                                                        
                                                        Label {
                                                            anchors.left: parent.left
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            anchors.leftMargin: 8
                                                            text: formatearFecha(modelData.Fecha)
                                                            font.pixelSize: 10
                                                            font.bold: true
                                                            color: textColor
                                                            horizontalAlignment: Text.AlignLeft
                                                        }
                                                    }
                                                    
                                                    Rectangle { width: 2; Layout.fillHeight: true; color: "#E0E6ED"; opacity: 0.7 }
                                                    
                                                    // HORARIO
                                                    Rectangle {
                                                        Layout.preferredWidth: 110
                                                        Layout.fillHeight: true
                                                        color: "transparent"
                                                        
                                                        Label {
                                                            anchors.left: parent.left
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            anchors.leftMargin: 8
                                                            text: formatearHorario(modelData.HoraInicio, modelData.HoraFin)
                                                            font.pixelSize: 10
                                                            font.bold: true
                                                            color: textColor
                                                            horizontalAlignment: Text.AlignLeft
                                                        }
                                                    }
                                                    
                                                    Rectangle { width: 2; Layout.fillHeight: true; color: "#E0E6ED"; opacity: 0.7 }
                                                    
                                                    // EFECTIVO REAL
                                                    Rectangle {
                                                        Layout.preferredWidth: 120
                                                        Layout.fillHeight: true
                                                        color: "transparent"
                                                        
                                                        Label {
                                                            anchors.left: parent.left
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            anchors.leftMargin: 8
                                                            text: "Bs " + parseFloat(modelData.EfectivoReal || 0).toLocaleString(Qt.locale(), 'f', 2)
                                                            font.pixelSize: 10
                                                            font.bold: true
                                                            color: successColor
                                                            horizontalAlignment: Text.AlignLeft
                                                        }
                                                    }
                                                    
                                                    Rectangle { width: 2; Layout.fillHeight: true; color: "#E0E6ED"; opacity: 0.7 }
                                                    
                                                    // SALDO TEÓRICO
                                                    Rectangle {
                                                        Layout.preferredWidth: 120
                                                        Layout.fillHeight: true
                                                        color: "transparent"
                                                        
                                                        Label {
                                                            anchors.left: parent.left
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            anchors.leftMargin: 8
                                                            text: "Bs " + parseFloat(modelData.SaldoTeorico || 0).toLocaleString(Qt.locale(), 'f', 2)
                                                            font.pixelSize: 10
                                                            color: textColor
                                                            horizontalAlignment: Text.AlignLeft
                                                        }
                                                    }
                                                    
                                                    Rectangle { width: 2; Layout.fillHeight: true; color: "#E0E6ED"; opacity: 0.7 }
                                                    
                                                    // DIFERENCIA
                                                    Rectangle {
                                                        Layout.preferredWidth: 100
                                                        Layout.fillHeight: true
                                                        color: "transparent"
                                                        
                                                        RowLayout {
                                                            anchors.left: parent.left
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            anchors.leftMargin: 8
                                                            spacing: 4
                                                            
                                                            Rectangle {
                                                                width: 50
                                                                height: 25
                                                                radius: 4
                                                                color: {
                                                                    let diff = parseFloat(modelData.Diferencia || 0)
                                                                    if (Math.abs(diff) < 1.0) return "#d1fae5"
                                                                    else if (diff > 0) return "#fef3c7"
                                                                    else return "#fee2e2"
                                                                }
                                                                border.width: 1
                                                                border.color: {
                                                                    let diff = parseFloat(modelData.Diferencia || 0)
                                                                    if (Math.abs(diff) < 1.0) return successColor
                                                                    else if (diff > 0) return warningColor
                                                                    else return dangerColor
                                                                }
                                                                
                                                                Label {
                                                                    anchors.centerIn: parent
                                                                    text: (parseFloat(modelData.Diferencia || 0) >= 0 ? "+" : "") + 
                                                                        parseFloat(modelData.Diferencia || 0).toFixed(2)
                                                                    font.pixelSize: 9
                                                                    font.bold: true
                                                                    color: {
                                                                        let diff = parseFloat(modelData.Diferencia || 0)
                                                                        if (Math.abs(diff) < 1.0) return "#065f46"
                                                                        else if (diff > 0) return "#92400e"
                                                                        else return "#dc2626"
                                                                    }
                                                                }
                                                            }
                                                            
                                                            Label {
                                                                text: "Bs"
                                                                font.pixelSize: 8
                                                                color: darkGrayColor
                                                            }
                                                        }
                                                    }
                                                    
                                                    Rectangle { width: 2; Layout.fillHeight: true; color: "#E0E6ED"; opacity: 0.7 }
                                                    
                                                    // ESTADO
                                                    Rectangle {
                                                        Layout.preferredWidth: 90
                                                        Layout.fillHeight: true
                                                        color: "transparent"
                                                        
                                                        Rectangle {
                                                            anchors.left: parent.left
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            anchors.leftMargin: 8
                                                            width: 70
                                                            height: 22
                                                            radius: 11
                                                            color: {
                                                                let diff = parseFloat(modelData.Diferencia || 0)
                                                                if (Math.abs(diff) < 1.0) return successColor
                                                                else if (diff > 0) return warningColor
                                                                else return dangerColor
                                                            }
                                                            
                                                            Label {
                                                                anchors.centerIn: parent
                                                                text: {
                                                                    let diff = parseFloat(modelData.Diferencia || 0)
                                                                    if (Math.abs(diff) < 1.0) return "✓ OK"
                                                                    else if (diff > 0) return "+ SOBRA"
                                                                    else return "- FALTA"
                                                                }
                                                                font.pixelSize: 7
                                                                font.bold: true
                                                                color: whiteColor
                                                            }
                                                        }
                                                    }
                                                    
                                                    Rectangle { width: 2; Layout.fillHeight: true; color: "#E0E6ED"; opacity: 0.7 }
                                                    
                                                    // REGISTRADO POR
                                                    Rectangle {
                                                        Layout.preferredWidth: 130
                                                        Layout.fillHeight: true
                                                        color: "transparent"
                                                        
                                                        ColumnLayout {
                                                            anchors.left: parent.left
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            anchors.leftMargin: 8
                                                            spacing: 2
                                                            
                                                            Label {
                                                                text: modelData.NombreUsuario || "Usuario desconocido"
                                                                font.pixelSize: 9
                                                                font.bold: true
                                                                color: textColor
                                                                horizontalAlignment: Text.AlignLeft
                                                                elide: Text.ElideRight
                                                            }
                                                            
                                                            Label {
                                                                text: "Cierre: " + formatearHora(modelData.HoraCierre)
                                                                font.pixelSize: 8
                                                                color: darkGrayColor
                                                                horizontalAlignment: Text.AlignLeft
                                                            }
                                                        }
                                                    }
                                                    
                                                    Rectangle { width: 2; Layout.fillHeight: true; color: "#E0E6ED"; opacity: 0.7 }
                                                    
                                                    // OBSERVACIONES
                                                    Rectangle {
                                                        Layout.fillWidth: true
                                                        Layout.fillHeight: true
                                                        color: "transparent"
                                                        
                                                        ScrollView {
                                                            anchors.fill: parent
                                                            anchors.margins: 8
                                                            clip: true
                                                            wheelEnabled: false
                                                            
                                                            ScrollBar.vertical.policy: ScrollBar.AsNeeded
                                                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                                                            
                                                            Label {
                                                                text: modelData.Observaciones || "Sin observaciones registradas"
                                                                font.pixelSize: 9
                                                                color: modelData.Observaciones ? textColor : darkGrayColor
                                                                font.italic: !modelData.Observaciones
                                                                wrapMode: Text.WordWrap
                                                                width: parent.width
                                                                horizontalAlignment: Text.AlignLeft
                                                                verticalAlignment: Text.AlignTop
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                            
                                            // MENSAJE CUANDO NO HAY DATOS
                                            Rectangle {
                                                visible: parent.count === 0
                                                anchors.centerIn: parent
                                                width: parent.width * 0.6
                                                height: 120
                                                color: "#F8F9FA"
                                                radius: 8
                                                border.color: "#E0E6ED"
                                                border.width: 1
                                                
                                                ColumnLayout {
                                                    anchors.centerIn: parent
                                                    spacing: 8
                                                    
                                                    Label {
                                                        text: "📋"
                                                        font.pixelSize: 32
                                                        Layout.alignment: Qt.AlignHCenter
                                                    }
                                                    
                                                    Label {
                                                        text: "No hay cierres registrados para esta semana"
                                                        font.pixelSize: 14
                                                        font.bold: true
                                                        color: darkGrayColor
                                                        Layout.alignment: Qt.AlignHCenter
                                                    }
                                                    
                                                    Label {
                                                        text: "Realiza tu primer cierre usando el formulario superior"
                                                        font.pixelSize: 11
                                                        color: darkGrayColor
                                                        Layout.alignment: Qt.AlignHCenter
                                                    }
                                                }
                                            }
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
    
    // NOTIFICACIÓN TOAST CENTRADA
    Rectangle {
        id: toastNotification
        anchors.horizontalCenter: parent.horizontalCenter
        y: 100
        width: 400
        height: 70
        radius: 10
        color: "#27ae60"
        visible: false
        z: 9999
        opacity: 0
        
        Behavior on opacity {
            NumberAnimation { duration: 300 }
        }
        
        Rectangle {
            anchors.fill: parent
            radius: 10
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#27ae60" }
                GradientStop { position: 1.0; color: "#219a52" }
            }
            border.color: "#1e8449"
            border.width: 2
        }
        
        RowLayout {
            anchors.fill: parent
            anchors.margins: 15
            spacing: 15
            
            Label {
                text: "✅"
                font.pixelSize: 20
                Layout.alignment: Qt.AlignVCenter
            }
            
            Label {
                id: toastMessage
                text: ""
                color: "white"
                font.bold: true
                font.pixelSize: 14
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                wrapMode: Text.WordWrap
            }
        }
        
        Timer {
            id: toastTimer
            interval: 3500
            onTriggered: hide()
        }
        
        function show(message) {
            toastMessage.text = message
            visible = true
            opacity = 1
            toastTimer.restart()
        }
        
        function hide() {
            opacity = 0
            timerHide.start()
        }
        
        Timer {
            id: timerHide
            interval: 300
            onTriggered: toastNotification.visible = false
        }
    }

    // FUNCIONES JAVASCRIPT
    function abrirPDFEnNavegador(rutaArchivo) {
        try {
            console.log("🌐 Abriendo PDF en navegador: " + rutaArchivo)
            var urlArchivo = "file:///" + rutaArchivo.replace(/\\/g, "/")
            Qt.openUrlExternally(urlArchivo)
            var nombreArchivo = rutaArchivo.split("/").pop().split("\\").pop()
            mostrarNotificacion("PDF Generado", "Archivo abierto en navegador: " + nombreArchivo)
        } catch (error) {
            console.log("❌ Error abriendo PDF: " + error)
            mostrarNotificacion("Error", "No se pudo abrir el PDF en el navegador")
        }
    }
    
    function cerrarCaja() {
        console.log("✅ Iniciando cierre de caja...")
        
        // Validaciones previas
        if (!cierreCajaModel) {
            console.log("❌ Modelo no disponible")
            mostrarNotificacion("Error", "Modelo no disponible")
            return
        }
        
        if (efectivoReal <= 0) {
            console.log("❌ Efectivo real no válido:", efectivoReal)
            mostrarNotificacion("Error", "Debe ingresar el efectivo real contado")
            return
        }
        
        try {
            console.log("🔍 Validando cierre...")
            console.log("📊 Datos del cierre:")
            console.log("   - Efectivo Real:", efectivoReal)
            console.log("   - Saldo Teórico:", saldoTeorico)
            console.log("   - Diferencia:", diferencia)
            console.log("   - Requiere Autorización:", requiereAutorizacion)
            
            // Intentar validar el cierre
            var validacionExitosa = false
            
            if (typeof cierreCajaModel.validarCierre === 'function') {
                validacionExitosa = cierreCajaModel.validarCierre()
                console.log("✅ Resultado validación:", validacionExitosa)
            } else {
                // Si no existe el método, asumir que es válido
                console.log("⚠️ Método validarCierre no existe, continuando...")
                validacionExitosa = true
            }
            
            if (validacionExitosa) {
                var observaciones = "Cierre automático - diferencia dentro del límite"
                
                if (requiereAutorizacion) {
                    observaciones = "Diferencia de Bs " + Math.abs(diferencia).toFixed(2) + " - Requiere autorización"
                    console.log("⚠️ Requiere autorización por diferencia significativa")
                }
                
                // Ejecutar el cierre
                console.log("💾 Completando cierre con observaciones:", observaciones)
                
                if (typeof cierreCajaModel.completarCierre === 'function') {
                    var resultado = cierreCajaModel.completarCierre(observaciones)
                    console.log("🔒 Resultado completarCierre:", resultado)
                    
                    // Mostrar notificación de éxito
                    mostrarNotificacion("Éxito", "Caja cerrada correctamente")
                    
                    // Recargar datos para actualizar la interfaz
                    Qt.callLater(function() {
                        if (typeof cierreCajaModel.cargarCierresSemana === 'function') {
                            cierreCajaModel.cargarCierresSemana()
                        }
                    })
                    
                    if (cierreCajaModel && typeof cierreCajaModel.establecerEfectivoReal === 'function') {
                        cierreCajaModel.establecerEfectivoReal(0.0)
                    }
                    efectivoRealField.text = ""
                } else {
                    console.log("❌ Método completarCierre no existe")
                    mostrarNotificacion("Error", "Método de cierre no disponible")
                }
            } else {
                console.log("❌ Validación de cierre falló")
                mostrarNotificacion("Error", "No se puede cerrar la caja - validación falló")
            }
            
        } catch (error) {
            console.log("❌ Error en cerrarCaja:", error.toString())
            mostrarNotificacion("Error", "Error al cerrar caja: " + error.toString())
        }
    }
        
    function mostrarNotificacion(titulo, mensaje) {
        console.log("📢 " + titulo + ": " + mensaje)
        
        if (titulo.includes("✅") || titulo.includes("Éxito") || 
            titulo.includes("PDF") || titulo.includes("Cierre") ||
            titulo.includes("Consulta")) {
            toastNotification.show(mensaje)
        }
    }
    
    function mostrarConfirmacion(titulo, mensaje, callback) {
        console.log("❓ " + titulo + ": " + mensaje)
        callback()
    }

    function calculateDuration(inicio, fin) {
            if (!inicio || !fin) return "0.0"
            
            try {
                let inicioMinutos = parseInt(inicio.split(':')[0]) * 60 + parseInt(inicio.split(':')[1])
                let finMinutos = parseInt(fin.split(':')[0]) * 60 + parseInt(fin.split(':')[1])
                let duracion = (finMinutos - inicioMinutos) / 60
                return duracion.toFixed(1)
            } catch (e) {
                return "0.0"
            }
        }
        function formatearHorario(inicio, fin) {
        if (!inicio || !fin) return "--:-- - --:--"
        
        try {
            function extraerHoraMinuto(hora) {
                if (!hora) return "--:--"
                
                let horaStr = hora.toString().trim()
                let partes = horaStr.split(':')
                
                if (partes.length >= 2) {
                    let horas = parseInt(partes[0]) || 0
                    let minutos = parseInt(partes[1]) || 0
                    
                    return String(horas).padStart(2, '0') + ':' + String(minutos).padStart(2, '0')
                }
                
                return "--:--"
            }
            
            let inicioLimpio = extraerHoraMinuto(inicio)
            let finLimpio = extraerHoraMinuto(fin)
            
            return inicioLimpio + " - " + finLimpio
            
        } catch (e) {
            return "--:-- - --:--"
        }
    }
    // Agregar después de formatearHorario():

    function formatearFecha(fecha) {
        if (!fecha) return "--/--/----"
        
        try {
            // Si viene como string de fecha
            if (typeof fecha === 'string') {
                // Si ya está en formato DD/MM/YYYY, devolverla
                if (fecha.match(/^\d{1,2}\/\d{1,2}\/\d{4}$/)) {
                    return fecha
                }
                
                // Si viene en formato YYYY-MM-DD, convertir a DD/MM/YYYY
                if (fecha.match(/^\d{4}-\d{2}-\d{2}/)) {
                    let partes = fecha.split('-')
                    return partes[2] + '/' + partes[1] + '/' + partes[0]
                }
            }
            
            // Si viene como Date object
            if (fecha instanceof Date) {
                let dia = String(fecha.getDate()).padStart(2, '0')
                let mes = String(fecha.getMonth() + 1).padStart(2, '0')
                let anio = fecha.getFullYear()
                return dia + '/' + mes + '/' + anio
            }
            
            return "--/--/----"
        } catch (e) {
            return "--/--/----"
        }
    }

    function formatearHora(hora) {
        if (!hora) return "--:--"
        
        try {
            let horaStr = hora.toString().trim()
            let partes = horaStr.split(':')
            
            if (partes.length >= 2) {
                let horas = parseInt(partes[0]) || 0
                let minutos = parseInt(partes[1]) || 0
                
                return String(horas).padStart(2, '0') + ':' + String(minutos).padStart(2, '0')
            }
            
            return "--:--"
        } catch (e) {
            return "--:--"
        }
    }
    
    function validarFormatoFecha(fecha) {
        if (!fecha || fecha.trim().length === 0) return false
        
        // Permitir varios formatos: DD/MM/YYYY, DD-MM-YYYY, DD.MM.YYYY
        var regex = /^(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{4})$/
        var match = fecha.match(regex)
        
        if (!match) return false
        
        var dia = parseInt(match[1])
        var mes = parseInt(match[2])
        var anio = parseInt(match[3])
        
        return dia >= 1 && dia <= 31 && 
            mes >= 1 && mes <= 12 && 
            anio >= 2020 && anio <= 2030
    }

    function validarFormatoHora(hora) {
        if (!hora || hora.trim().length === 0) return false
        
        // Permitir formatos: HH:MM, H:MM, HH.MM, H.MM
        var regex = /^(\d{1,2})[\:\.](\d{2})$/
        var match = hora.match(regex)
        
        if (!match) return false
        
        var horas = parseInt(match[1])
        var minutos = parseInt(match[2])
        
        return horas >= 0 && horas <= 23 && 
            minutos >= 0 && minutos <= 59
    }
    
    // INICIALIZACIÓN
    Component.onCompleted: {
        console.log("💰 Inicializando módulo CierreCaja")
        
        // Verificar AppController primero
        if (!appController) {
            console.log("❌ AppController no disponible")
            return
        }
        
        // Inicializar modelo con delay
        initializationTimer.start()
    }
}