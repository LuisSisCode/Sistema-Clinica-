import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

import QtQml 2.15

Item {
    id: consultasRoot
    objectName: "consultasRoot"

    property var consultaModel: appController ? appController.consulta_model_instance : null

    // ===== NUEVA SEÑAL PARA IR A CONFIGURACIÓN =====
    signal irAConfiguracion()
    
    // ACCESO A PROPIEDADES ADAPTATIVAS DEL MAIN
    readonly property real baseUnit: parent.baseUnit || Math.max(8, Screen.height / 100)
    readonly property real fontBaseSize: parent.fontBaseSize || Math.max(12, Screen.height / 70)
    readonly property real scaleFactor: parent.scaleFactor || Math.min(width / 1400, height / 900)
    
    // PROPIEDADES DE TAMAÑO MEJORADAS
    readonly property real iconSize: Math.max(baseUnit * 3, 24)
    readonly property real buttonIconSize: Math.max(baseUnit * 2, 18)

    // PROPIEDADES DE COLOR MEJORADAS (agregar después de scaleFactor)
    readonly property color primaryColor: "#3498DB"
    readonly property color primaryColorHover: "#2980B9"
    readonly property color primaryColorPressed: "#21618C"
    readonly property color successColor: "#10B981"
    readonly property color successColorLight: "#D1FAE5"
    readonly property color dangerColor: "#E74C3C"
    readonly property color dangerColorLight: "#FEE2E2"
    readonly property color warningColor: "#f39c12"
    readonly property color warningColorLight: "#FEF3C7"
    readonly property color lightGrayColor: "#F8F9FA"
    readonly property color textColor: "#2c3e50"
    readonly property color textColorLight: "#6B7280"
    readonly property color whiteColor: "#FFFFFF"
    readonly property color borderColor: "#E5E7EB"
    readonly property color accentColor: "#10B981"
    readonly property color lineColor: "#D1D5DB"
    
    // Propiedades para los diálogos
    property bool showNewConsultationDialog: false
    property bool isEditMode: false
    property int editingIndex: -1
    property int selectedRowIndex: -1
    
    // PAGINACIÓN ADAPTATIVA
    property int itemsPerPageConsultas: calcularElementosPorPagina()
    property int currentPageConsultas: 0
    property int totalPagesConsultas: 0

    property var pacienteModel: appController ? appController.paciente_model_instance : null
    
    
    // Distribución de columnas responsive
    readonly property real colId: 0.06
    readonly property real colPaciente: 0.18
    readonly property real colDetalle: 0.22
    readonly property real colEspecialidad: 0.24
    readonly property real colTipo: 0.10
    readonly property real colPrecio: 0.10
    readonly property real colFecha: 0.10

    ListModel {
        id: consultasPaginadasModel
    }

    ListModel {
        id: consultasListModel
    }

    property var consultasOriginales: []

    Connections {
        target: consultaModel
        
        function onConsultasRecientesChanged() {
            console.log("📋 Signal: Consultas recientes cambiadas")
            // Forzar actualización después de un breve delay
            updateTimer.start()
        }
        
        function onEspecialidadesChanged() {
            console.log("🏥 Signal: Especialidades cambiadas")
            updateEspecialidadesCombo()
        }
        
        function onLoadingChanged() {
            console.log("⏳ Loading:", consultaModel.loading)
        }
        
        function onOperacionError(mensaje) {
            console.log("❌ Error:", mensaje)
            showNotification("Error", mensaje)
        }
        
        function onOperacionExitosa(mensaje) {
            console.log("✅ Éxito:", mensaje)
            showNotification("Éxito", mensaje)
            // Forzar actualización inmediata
            updatePaginatedModel()
        }
    }
    // QUITARLO SI ESTORBA EN UN FUTURO
    Timer {
        id: updateTimer
        interval: 100
        onTriggered: updatePaginatedModel()
    }

    // FUNCIÓN PARA CALCULAR ELEMENTOS POR PÁGINA ADAPTATIVAMENTE
    function calcularElementosPorPagina() {
        var alturaDisponible = height - baseUnit * 25
        var alturaFila = baseUnit * 7
        var elementosCalculados = Math.floor(alturaDisponible / alturaFila)
        
        return Math.max(6, Math.min(elementosCalculados, 15))
    }

    // RECALCULAR PAGINACIÓN CUANDO CAMBIE EL TAMAÑO
    onHeightChanged: {
        var nuevosElementos = calcularElementosPorPagina()
        if (nuevosElementos !== itemsPerPageConsultas) {
            itemsPerPageConsultas = nuevosElementos
            updatePaginatedModel()
        }
    }

    function determinarTipoConsulta(precioNormal, precioEmergencia) {
        if (!precioNormal && !precioEmergencia) return "Normal"
        
        precioNormal = precioNormal || 0
        precioEmergencia = precioEmergencia || 0
        
        // Lógica para determinar tipo basado en precios
        return precioEmergencia > precioNormal ? "Emergencia" : "Normal"
    }

    function formatearFecha(fechaISO) {
        if (!fechaISO) return "Sin fecha"
        
        try {
            var fecha = new Date(fechaISO)
            return fecha.toLocaleDateString("es-ES")
        } catch (e) {
            return "Fecha inválida"
        }
    }

    function showNotification(tipo, mensaje) {
        // Conectar con sistema de notificaciones del main
        if (typeof appController !== 'undefined') {
            appController.showNotification(tipo, mensaje)
        } else {
            console.log(`${tipo}: ${mensaje}`)
        }
    }

    // LAYOUT PRINCIPAL ADAPTATIVO
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: baseUnit * 4
        spacing: baseUnit * 3
        
        // CONTENEDOR PRINCIPAL
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: whiteColor
            radius: baseUnit * 2
            border.color: borderColor
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                
                // HEADER ADAPTATIVO CORREGIDO
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: baseUnit * 12  // Aumentamos un poco la altura
                    color: lightGrayColor
                    border.color: borderColor
                    border.width: 1
                    radius: baseUnit * 2
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: baseUnit * 2  // Márgenes más generosos
                        spacing: baseUnit * 2
                        
                        // SECCIÓN DEL LOGO Y TÍTULO
                        RowLayout {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: baseUnit * 1.5
                            
                            // Contenedor del icono con tamaño fijo
                            Rectangle {
                                Layout.preferredWidth: baseUnit * 10
                                Layout.preferredHeight: baseUnit * 10
                                color: "transparent"
                                
                                Image {
                                    id: consultaIcon
                                    anchors.centerIn: parent
                                    width: Math.min(baseUnit * 8, parent.width * 10)
                                    height: Math.min(baseUnit * 8, parent.height * 10)
                                    source: "Resources/iconos/Consulta.png"    // ← CAMBIADO A PNG
                                    fillMode: Image.PreserveAspectFit
                                    antialiasing: true    // ← OPCIONAL: para mejor calidad del PNG
                                    
                                    onStatusChanged: {
                                        if (status === Image.Error) {
                                            console.log("Error cargando PNG:", source)
                                        } else if (status === Image.Ready) {
                                            console.log("PNG cargado correctamente:", source)
                                        }
                                    }
                                }
                            }
                            
                            // Título
                            Label {
                                Layout.alignment: Qt.AlignVCenter
                                text: "Registro de Consultas Médicas"
                                font.pixelSize: fontBaseSize * 1.3
                                font.bold: true
                                font.family: "Segoe UI, Arial, sans-serif"
                                color: textColor
                                wrapMode: Text.WordWrap
                            }
                        }
                        
                        // ESPACIADOR FLEXIBLE
                        Item { 
                            Layout.fillWidth: true 
                            Layout.minimumWidth: baseUnit * 2
                        }
                        
                        // BOTÓN NUEVA CONSULTA CORREGIDO
                        Button {
                            id: newConsultationBtn
                            objectName: "newConsultationButton"
                            Layout.preferredHeight: baseUnit * 5
                            Layout.preferredWidth: Math.max(baseUnit * 20, implicitWidth + baseUnit * 2)
                            Layout.alignment: Qt.AlignVCenter
                            
                            background: Rectangle {
                                color: newConsultationBtn.pressed ? Qt.darker(primaryColor, 1.1) : 
                                    newConsultationBtn.hovered ? Qt.lighter(primaryColor, 1.1) : primaryColor
                                radius: baseUnit * 1.2
                                border.width: 0
                                
                                // Animación suave del color
                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                            
                            contentItem: RowLayout {
                                spacing: baseUnit
                                
                                // Contenedor del icono del botón
                                Rectangle {
                                    Layout.preferredWidth: baseUnit * 3
                                    Layout.preferredHeight: baseUnit * 3
                                    color: "transparent"
                                    
                                    Image {
                                        id: addIcon
                                        anchors.centerIn: parent
                                        width: baseUnit * 2.5
                                        height: baseUnit * 2.5
                                        source: "Resources/iconos/Nueva_Consulta.png"    // ← CAMBIADO A PNG
                                        fillMode: Image.PreserveAspectFit
                                        antialiasing: true    // ← OPCIONAL: para mejor calidad
                                        
                                        onStatusChanged: {
                                            if (status === Image.Error) {
                                                console.log("Error cargando PNG del botón:", source)
                                                // Mostrar un "+" si no hay icono
                                                visible = false
                                                fallbackText.visible = true
                                            } else if (status === Image.Ready) {
                                                console.log("PNG del botón cargado correctamente:", source)
                                            }
                                        }
                                    }
                                    
                                    // Texto fallback si no hay icono
                                    Label {
                                        id: fallbackText
                                        anchors.centerIn: parent
                                        text: "+"
                                        color: whiteColor
                                        font.pixelSize: fontBaseSize * 1.5
                                        font.bold: true
                                        visible: false
                                    }
                                }
                                
                                // Texto del botón
                                Label {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: "Nueva Consulta"
                                    color: whiteColor
                                    font.bold: true
                                    font.pixelSize: fontBaseSize
                                    font.family: "Segoe UI, Arial, sans-serif"
                                }
                            }
                            
                            onClicked: {
                                isEditMode = false
                                editingIndex = -1
                                showNewConsultationDialog = true
                            }
                            
                            // Efecto hover mejorado
                            HoverHandler {
                                id: buttonHover
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }
                }
                
                // FILTROS ADAPTATIVOS
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: width < 1000 ? baseUnit * 16 : baseUnit * 8
                    color: "transparent"
                    z: 10
                    
                    GridLayout {
                        anchors.fill: parent
                        anchors.margins: baseUnit * 3
                        anchors.bottomMargin: baseUnit * 1.5
                        
                        columns: width < 1000 ? 2 : 4
                        rowSpacing: baseUnit
                        columnSpacing: baseUnit * 2
                        
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit
                            
                            Label {
                                text: "Filtrar por:"
                                font.bold: true
                                color: textColor
                                font.pixelSize: fontBaseSize * 0.9
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                            
                            ComboBox {
                                id: filtroFecha
                                Layout.preferredWidth: Math.max(120, width * 0.15)
                                Layout.preferredHeight: baseUnit * 4
                                model: ["Todas", "Hoy", "Esta Semana", "Este Mes"]
                                currentIndex: 0
                                onCurrentIndexChanged: aplicarFiltros()
                                
                                contentItem: Label {
                                    text: filtroFecha.displayText
                                    font.pixelSize: fontBaseSize * 0.8
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    color: textColor
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: baseUnit
                                }
                            }
                        }
                        
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit
                            
                            Label {
                                text: "Especialidad:"
                                font.bold: true
                                color: textColor
                                font.pixelSize: fontBaseSize * 0.9
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                            
                            ComboBox {
                                id: filtroEspecialidad
                                Layout.fillWidth: true
                                Layout.preferredHeight: baseUnit * 4
                                model: {
                                    var especialidades = ["Todas"]
                                    if (consultaModel && consultaModel.especialidades) {
                                        for (var i = 0; i < consultaModel.especialidades.length; i++) {
                                            var esp = consultaModel.especialidades[i]
                                            if (esp && esp.text) {
                                                especialidades.push(esp.text)
                                            }
                                        }
                                    }
                                    return especialidades
}
                                currentIndex: 0
                                onCurrentIndexChanged: aplicarFiltros()
                                
                                contentItem: Label {
                                    text: filtroEspecialidad.displayText
                                    font.pixelSize: fontBaseSize * 0.8
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    color: textColor
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: baseUnit
                                    elide: Text.ElideRight
                                }
                            }
                        }
                        
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit
                            
                            Label {
                                text: "Tipo:"
                                font.bold: true
                                color: textColor
                                font.pixelSize: fontBaseSize * 0.9
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                            
                            ComboBox {
                                id: filtroTipo
                                Layout.preferredWidth: Math.max(100, width * 0.12)
                                Layout.preferredHeight: baseUnit * 4
                                model: ["Todos", "Normal", "Emergencia"]
                                currentIndex: 0
                                onCurrentIndexChanged: aplicarFiltros()
                                
                                contentItem: Label {
                                    text: filtroTipo.displayText
                                    font.pixelSize: fontBaseSize * 0.8
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    color: textColor
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: baseUnit
                                }
                            }
                        }
                        
                        TextField {
                            id: campoBusqueda
                            Layout.fillWidth: true
                            Layout.preferredHeight: baseUnit * 4
                            placeholderText: "Buscar por paciente..."
                            onTextChanged: aplicarFiltros()
                            
                            background: Rectangle {
                                color: whiteColor
                                border.color: borderColor
                                border.width: 1
                                radius: baseUnit * 0.8
                            }
                            
                            leftPadding: baseUnit * 1.5
                            rightPadding: baseUnit * 1.5
                            font.pixelSize: fontBaseSize * 0.9
                            font.family: "Segoe UI, Arial, sans-serif"
                        }
                    }
                }
                
                // TABLA MODERNA CON LÍNEAS VERTICALES
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.margins: baseUnit * 3
                    Layout.topMargin: 0
                    color: whiteColor
                    border.color: borderColor
                    border.width: 1
                    radius: baseUnit
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 0
                        spacing: 0
                        
                        // HEADER CON LÍNEAS VERTICALES
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: baseUnit * 6
                            color: lightGrayColor
                            border.color: borderColor
                            border.width: 1
                            z: 5
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: baseUnit * 1.5
                                anchors.rightMargin: baseUnit * 1.5
                                spacing: 0
                                
                                // ID COLUMN
                                Item {
                                    Layout.preferredWidth: parent.width * colId
                                    Layout.fillHeight: true
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "ID"
                                        font.bold: true
                                        font.pixelSize: fontBaseSize * 0.85
                                        font.family: "Segoe UI, Arial, sans-serif"
                                        color: textColor
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    
                                    Rectangle {
                                        anchors.right: parent.right
                                        width: 1
                                        height: parent.height
                                        color: lineColor
                                    }
                                }
                                
                                // PACIENTE COLUMN
                                Item {
                                    Layout.preferredWidth: parent.width * colPaciente
                                    Layout.fillHeight: true
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "PACIENTE"
                                        font.bold: true
                                        font.pixelSize: fontBaseSize * 0.85
                                        font.family: "Segoe UI, Arial, sans-serif"
                                        color: textColor
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    
                                    Rectangle {
                                        anchors.right: parent.right
                                        width: 1
                                        height: parent.height
                                        color: lineColor
                                    }
                                }
                                
                                // DETALLE COLUMN
                                Item {
                                    Layout.preferredWidth: parent.width * colDetalle
                                    Layout.fillHeight: true
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "DETALLE"
                                        font.bold: true
                                        font.pixelSize: fontBaseSize * 0.85
                                        font.family: "Segoe UI, Arial, sans-serif"
                                        color: textColor
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    
                                    Rectangle {
                                        anchors.right: parent.right
                                        width: 1
                                        height: parent.height
                                        color: lineColor
                                    }
                                }
                                
                                // ESPECIALIDAD COLUMN
                                Item {
                                    Layout.preferredWidth: parent.width * colEspecialidad
                                    Layout.fillHeight: true
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "ESPECIALIDAD - DOCTOR"
                                        font.bold: true
                                        font.pixelSize: fontBaseSize * 0.85
                                        font.family: "Segoe UI, Arial, sans-serif"
                                        color: textColor
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    
                                    Rectangle {
                                        anchors.right: parent.right
                                        width: 1
                                        height: parent.height
                                        color: lineColor
                                    }
                                }
                                
                                // TIPO COLUMN
                                Item {
                                    Layout.preferredWidth: parent.width * colTipo
                                    Layout.fillHeight: true
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "TIPO"
                                        font.bold: true
                                        font.pixelSize: fontBaseSize * 0.85
                                        font.family: "Segoe UI, Arial, sans-serif"
                                        color: textColor
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    
                                    Rectangle {
                                        anchors.right: parent.right
                                        width: 1
                                        height: parent.height
                                        color: lineColor
                                    }
                                }
                                
                                // PRECIO COLUMN
                                Item {
                                    Layout.preferredWidth: parent.width * colPrecio
                                    Layout.fillHeight: true
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "PRECIO"
                                        font.bold: true
                                        font.pixelSize: fontBaseSize * 0.85
                                        font.family: "Segoe UI, Arial, sans-serif"
                                        color: textColor
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    
                                    Rectangle {
                                        anchors.right: parent.right
                                        width: 1
                                        height: parent.height
                                        color: lineColor
                                    }
                                }
                                
                                // FECHA COLUMN
                                Item {
                                    Layout.preferredWidth: parent.width * colFecha
                                    Layout.fillHeight: true
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "FECHA"
                                        font.bold: true
                                        font.pixelSize: fontBaseSize * 0.85
                                        font.family: "Segoe UI, Arial, sans-serif"
                                        color: textColor
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }
                            }
                        }
                        
                        // CONTENIDO DE TABLA CON SCROLL Y LÍNEAS VERTICALES
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            
                            ListView {
                                id: consultasListView
                                model: consultasPaginadasModel
                                
                                delegate: Rectangle {
                                    width: ListView.view.width
                                    height: baseUnit * 5.5
                                    color: {
                                        if (selectedRowIndex === index) return "#F8F9FA"
                                        return index % 2 === 0 ? whiteColor : "#FAFAFA"
                                    }
                                    
                                    // Borde horizontal sutil
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        height: 1
                                        color: borderColor
                                    }
                                    
                                    // Borde vertical de selección
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: baseUnit * 0.4
                                        color: selectedRowIndex === index ? accentColor : "transparent"
                                        radius: baseUnit * 0.2
                                        visible: selectedRowIndex === index
                                    }
                                    
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: baseUnit * 1.5
                                        anchors.rightMargin: baseUnit * 1.5
                                        spacing: 0
                                        
                                        // ID COLUMN
                                        Item {
                                            Layout.preferredWidth: parent.width * colId
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                text: model.consultaId
                                                color: textColor
                                                font.bold: false
                                                font.pixelSize: fontBaseSize * 0.9
                                                font.family: "Segoe UI, Arial, sans-serif"
                                            }
                                            
                                            Rectangle {
                                                anchors.right: parent.right
                                                width: 1
                                                height: parent.height
                                                color: lineColor
                                            }
                                        }
                                        
                                        // PACIENTE COLUMN
                                        Item {
                                            Layout.preferredWidth: parent.width * colPaciente
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                anchors.rightMargin: baseUnit
                                                text: model.paciente
                                                color: textColor
                                                font.bold: false
                                                font.pixelSize: fontBaseSize * 0.9
                                                font.family: "Segoe UI, Arial, sans-serif"
                                                elide: Text.ElideRight
                                            }
                                            
                                            Rectangle {
                                                anchors.right: parent.right
                                                width: 1
                                                height: parent.height
                                                color: lineColor
                                            }
                                        }
                                        
                                        // DETALLE COLUMN
                                        Item {
                                            Layout.preferredWidth: parent.width * colDetalle
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                anchors.rightMargin: baseUnit
                                                text: model.detalles
                                                color: textColor // Mismo color que paciente
                                                font.bold: false
                                                font.pixelSize: fontBaseSize * 0.85
                                                font.family: "Segoe UI, Arial, sans-serif"
                                                wrapMode: Text.WordWrap
                                                elide: Text.ElideRight
                                                maximumLineCount: 2
                                            }
                                            
                                            Rectangle {
                                                anchors.right: parent.right
                                                width: 1
                                                height: parent.height
                                                color: lineColor
                                            }
                                        }
                                        
                                        // ESPECIALIDAD COLUMN
                                        Item {
                                            Layout.preferredWidth: parent.width * colEspecialidad
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                anchors.rightMargin: baseUnit
                                                text: model.especialidadDoctor
                                                color: primaryColor
                                                font.bold: false
                                                font.pixelSize: fontBaseSize * 0.85
                                                font.family: "Segoe UI, Arial, sans-serif"
                                                wrapMode: Text.WordWrap
                                                elide: Text.ElideRight
                                                maximumLineCount: 2
                                            }
                                            
                                            Rectangle {
                                                anchors.right: parent.right
                                                width: 1
                                                height: parent.height
                                                color: lineColor
                                            }
                                        }
                                        
                                        // TIPO COLUMN
                                        Item {
                                            Layout.preferredWidth: parent.width * colTipo
                                            Layout.fillHeight: true
                                            
                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: baseUnit * 7
                                                height: baseUnit * 2.5
                                                color: model.tipo === "Emergencia" ? warningColorLight : successColorLight
                                                radius: height / 2
                                                
                                                Label {
                                                    anchors.centerIn: parent
                                                    text: model.tipo
                                                    color: model.tipo === "Emergencia" ? "#92400E" : "#047857"
                                                    font.pixelSize: fontBaseSize * 0.75
                                                    font.bold: false
                                                    font.family: "Segoe UI, Arial, sans-serif"
                                                }
                                            }
                                            
                                            Rectangle {
                                                anchors.right: parent.right
                                                width: 1
                                                height: parent.height
                                                color: lineColor
                                            }
                                        }
                                        
                                        // PRECIO COLUMN
                                        Item {
                                            Layout.preferredWidth: parent.width * colPrecio
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                text: "Bs "+ model.precio
                                                color: model.tipo === "Emergencia" ? "#92400E" : "#047857"
                                                font.bold: false
                                                font.pixelSize: fontBaseSize * 0.9
                                                font.family: "Segoe UI, Arial, sans-serif"
                                            }
                                            
                                            Rectangle {
                                                anchors.right: parent.right
                                                width: 1
                                                height: parent.height
                                                color: lineColor
                                            }
                                        }
                                        
                                        // FECHA COLUMN
                                        Item {
                                            Layout.preferredWidth: parent.width * colFecha
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                text: model.fecha
                                                color: textColor // Mismo color que paciente
                                                font.bold: false
                                                font.pixelSize: fontBaseSize * 0.85
                                                font.family: "Segoe UI, Arial, sans-serif"
                                            }
                                        }
                                    }
                                    
                                    // LÍNEAS VERTICALES CONTINUAS
                                    Repeater {
                                        model: 6 // Número de líneas verticales (todas menos la última columna)
                                        Rectangle {
                                            property real xPos: {
                                                var w = parent.width - baseUnit * 3
                                                switch(index) {
                                                    case 0: return baseUnit * 1.5 + w * colId
                                                    case 1: return baseUnit * 1.5 + w * (colId + colPaciente)
                                                    case 2: return baseUnit * 1.5 + w * (colId + colPaciente + colDetalle)
                                                    case 3: return baseUnit * 1.5 + w * (colId + colPaciente + colDetalle + colEspecialidad)
                                                    case 4: return baseUnit * 1.5 + w * (colId + colPaciente + colDetalle + colEspecialidad + colTipo)
                                                    case 5: return baseUnit * 1.5 + w * (colId + colPaciente + colDetalle + colEspecialidad + colTipo + colPrecio)
                                                }
                                            }
                                            x: xPos
                                            width: 1
                                            height: parent.height
                                            color: lineColor
                                            z: 1
                                        }
                                    }
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            selectedRowIndex = selectedRowIndex === index ? -1 : index
                                            console.log("Seleccionada consulta ID:", model.consultaId)
                                        }
                                    }
                                    
                                    // BOTONES DE ACCIÓN MODERNOS
                                    RowLayout {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.right: parent.right
                                        anchors.margins: baseUnit * 0.8
                                        spacing: baseUnit * 0.8
                                        visible: selectedRowIndex === index
                                        z: 10
                                        
                                        Button {
                                            id: editButton
                                            width: baseUnit * 3.5
                                            height: baseUnit * 3.5
                                            
                                            background: Rectangle {
                                                color: "transparent"
                                            }
                                            
                                            Image {
                                                id: editIcon
                                                anchors.centerIn: parent
                                                width: baseUnit * 2.5
                                                height: baseUnit * 2.5
                                                source: "Resources/iconos/editar.svg"  // Ruta a tu imagen SVG de editar
                                                fillMode: Image.PreserveAspectFit
                                                
                                            }
                                            
                                            onClicked: {
                                                // Almacenar datos completos de la consulta para edición
                                                consultationForm.consultaParaEditar = {
                                                    consultaId: model.consultaId,
                                                    paciente: model.paciente,
                                                    especialidadDoctor: model.especialidadDoctor,
                                                    tipo: model.tipo,
                                                    precio: model.precio,
                                                    detalles: model.detalles,
                                                    fecha: model.fecha
                                                }
                                                
                                                isEditMode = true
                                                editingIndex = -1 // Ya no lo necesitamos, pero mantenemos compatibilidad
                                                showNewConsultationDialog = true
                                                
                                                console.log("Editando consulta ID:", model.consultaId)
                                            }
                                            
                                            // Efecto hover
                                            onHoveredChanged: {
                                                editIcon.opacity = hovered ? 0.7 : 1.0
                                            }
                                        }

                                        Button {
                                            id: deleteButton
                                            width: baseUnit * 3.5
                                            height: baseUnit * 3.5
                                            
                                            background: Rectangle {
                                                color: "transparent"
                                            }
                                            
                                            Image {
                                                id: deleteIcon
                                                anchors.centerIn: parent
                                                width: baseUnit * 2.5
                                                height: baseUnit * 2.5
                                                source: "Resources/iconos/eliminar.svg"  // Ruta a tu imagen SVG de eliminar
                                                fillMode: Image.PreserveAspectFit

                                            }
                                            
                                            onClicked: {
                                                var consultaId = model.consultaId
                                                
                                                for (var i = 0; i < consultasListModel.count; i++) {
                                                    if (consultasListModel.get(i).consultaId === consultaId) {
                                                        consultasListModel.remove(i)
                                                        break
                                                    }
                                                }
                                                
                                                for (var j = 0; j < consultasOriginales.length; j++) {
                                                    if (consultasOriginales[j].consultaId === consultaId) {
                                                        consultasOriginales.splice(j, 1)
                                                        break
                                                    }
                                                }
                                                
                                                selectedRowIndex = -1
                                                updatePaginatedModel()
                                                console.log("Consulta eliminada ID:", consultaId)
                                            }
                                            
                                            // Efecto hover
                                            onHoveredChanged: {
                                                deleteIcon.opacity = hovered ? 0.7 : 1.0
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                // PAGINACIÓN MODERNA
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: baseUnit * 6
                    Layout.margins: baseUnit * 3
                    Layout.topMargin: 0
                    color: lightGrayColor
                    border.color: borderColor
                    border.width: 1
                    radius: baseUnit
                    
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: baseUnit * 2
                        
                        Button {
                            Layout.preferredWidth: baseUnit * 10
                            Layout.preferredHeight: baseUnit * 4
                            text: "← Anterior"
                            enabled: currentPageConsultas > 0
                            
                            background: Rectangle {
                                color: parent.enabled ? 
                                    (parent.pressed ? Qt.darker(successColor, 1.1) : successColor) : 
                                    "#E5E7EB"
                                radius: baseUnit * 2
                                
                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                            
                            contentItem: Label {
                                text: parent.text
                                color: parent.enabled ? whiteColor : "#9CA3AF"
                                font.bold: true
                                font.pixelSize: fontBaseSize * 0.9
                                font.family: "Segoe UI, Arial, sans-serif"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: {
                                if (currentPageConsultas > 0) {
                                    currentPageConsultas--
                                    updatePaginatedModel()
                                }
                            }
                        }
                        
                        Label {
                            text: "Página " + (currentPageConsultas + 1) + " de " + Math.max(1, totalPagesConsultas)
                            color: textColor
                            font.pixelSize: fontBaseSize * 0.9
                            font.family: "Segoe UI, Arial, sans-serif"
                            font.weight: Font.Medium
                        }
                        
                        Button {
                            Layout.preferredWidth: baseUnit * 11
                            Layout.preferredHeight: baseUnit * 4
                            text: "Siguiente →"
                            enabled: currentPageConsultas < totalPagesConsultas - 1
                            
                            background: Rectangle {
                                color: parent.enabled ? 
                                    (parent.pressed ? Qt.darker(successColor, 1.1) : successColor) : 
                                    "#E5E7EB"
                                radius: baseUnit * 2
                                
                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                            
                            contentItem: Label {
                                text: parent.text
                                color: parent.enabled ? whiteColor : "#9CA3AF"
                                font.bold: true
                                font.pixelSize: fontBaseSize * 0.9
                                font.family: "Segoe UI, Arial, sans-serif"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: {
                                if (currentPageConsultas < totalPagesConsultas - 1) {
                                    currentPageConsultas++
                                    updatePaginatedModel()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ===== DIÁLOGO DE NUEVA CONSULTA (MANTENER) =====
    
    // Fondo del diálogo
    Rectangle {
        id: newConsultationDialog
        anchors.fill: parent
        color: "black"
        opacity: showNewConsultationDialog ? 0.5 : 0
        visible: opacity > 0
        
        MouseArea {
            anchors.fill: parent
            onClicked: {
                showNewConsultationDialog = false
                selectedRowIndex = -1
            }
        }
        
        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }
    }
    
    // Diálogo de consulta adaptativo - Diseño IDÉNTICO a Enfermería
    Rectangle {
        id: consultationForm
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.95, 700)  // Más ancho para mejor uso del espacio
        height: Math.min(parent.height * 0.95, 800)  // Más alto pero con mejor distribución
        color: whiteColor
        radius: baseUnit * 1.5  // Bordes más redondeados
        border.color: "#DDD"
        border.width: 1
        visible: showNewConsultationDialog

        // Efecto de sombra simple
        Rectangle {
            anchors.fill: parent
            anchors.margins: -baseUnit
            color: "transparent"
            radius: parent.radius + baseUnit
            border.color: "#20000000"
            border.width: baseUnit
            z: -1
        }
        
        property int selectedEspecialidadIndex: -1
        property string consultationType: "Normal"
        property real calculatedPrice: 0.0
        property var consultaParaEditar: null
        
        function loadEditData() {
            if (!isEditMode || !consultationForm.consultaParaEditar) {
                console.log("No hay datos para cargar en edición")
                return
            }
            
            var consulta = consultationForm.consultaParaEditar
            console.log("Cargando datos para edición:", JSON.stringify(consulta))
            
            // Separar nombre completo del paciente
            var nombreCompleto = consulta.paciente || ""
            var partesNombre = nombreCompleto.split(" ")
            
            nombrePaciente.text = partesNombre[0] || ""
            apellidoPaterno.text = partesNombre[1] || ""
            apellidoMaterno.text = partesNombre.slice(2).join(" ") || ""
            
            // Buscar y establecer especialidad por nombre completo
            if (consulta.especialidadDoctor && consultaModel && consultaModel.especialidades) {
                console.log("Buscando especialidad:", consulta.especialidadDoctor)
                
                for (var i = 0; i < consultaModel.especialidades.length; i++) {
                    var esp = consultaModel.especialidades[i]
                    var espTextoCompleto = esp.text + " - " + esp.doctor_nombre
                    var nombreEspecialidad = esp.text
                    
                    // Comparar tanto el texto completo como solo el nombre de la especialidad
                    if (espTextoCompleto === consulta.especialidadDoctor || 
                        consulta.especialidadDoctor.indexOf(nombreEspecialidad) === 0) {
                        
                        especialidadCombo.currentIndex = i + 1
                        consultationForm.selectedEspecialidadIndex = i
                        
                        // Actualizar precio según el tipo
                        if (consultationForm.consultationType === "Normal") {
                            consultationForm.calculatedPrice = esp.precio_normal
                        } else {
                            consultationForm.calculatedPrice = esp.precio_emergencia
                        }
                        
                        console.log("Especialidad encontrada:", nombreEspecialidad)
                        break
                    }
                }
            }
            
            // Establecer tipo de consulta
            if (consulta.tipo === "Normal") {
                normalRadio.checked = true
                emergenciaRadio.checked = false
                consultationForm.consultationType = "Normal"
            } else {
                normalRadio.checked = false
                emergenciaRadio.checked = true
                consultationForm.consultationType = "Emergencia"
            }

            if (consulta.pacienteEdad !== null && consulta.pacienteEdad !== undefined) {
                edadPaciente.text = consulta.pacienteEdad.toString()
                console.log("Edad cargada:", consulta.pacienteEdad)
            } else {
                edadPaciente.text = ""
                console.log("Edad no disponible")
            }
            
            // Establecer precio calculado
            consultationForm.calculatedPrice = parseFloat(consulta.precio) || 0.0
            
            // Establecer detalles
            detallesConsulta.text = consulta.detalles || ""
            
            console.log("Datos de edición cargados correctamente")
        }
        
        function updatePrices() {
            if (consultationForm.selectedEspecialidadIndex >= 0 && consultaModel && consultaModel.especialidades) {
                var especialidad = consultaModel.especialidades[consultationForm.selectedEspecialidadIndex]
                if (consultationForm.consultationType === "Normal") {
                    consultationForm.calculatedPrice = especialidad.precio_normal
                } else {
                    consultationForm.calculatedPrice = especialidad.precio_emergencia
                }
            } else {
                consultationForm.calculatedPrice = 0.0
            }
        }
        
        onVisibleChanged: {
            if (visible) {
                if (isEditMode && consultationForm.consultaParaEditar) {
                    // Cargar datos para edición
                    loadEditData()
                } else if (!isEditMode) {
                    // Limpiar formulario para nueva consulta
                    nombrePaciente.text = ""
                    apellidoPaterno.text = ""
                    apellidoMaterno.text = ""
                    edadPaciente.text = ""
                    especialidadCombo.currentIndex = 0
                    normalRadio.checked = true
                    emergenciaRadio.checked = false
                    detallesConsulta.text = ""
                    consultationForm.selectedEspecialidadIndex = -1
                    consultationForm.calculatedPrice = 0.0
                    consultationForm.consultaParaEditar = null
                }
            }
        }
        
        // HEADER MEJORADO CON CIERRE - IDÉNTICO A ENFERMERÍA
        Rectangle {
            id: dialogHeader
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: baseUnit * 7
            color: primaryColor
            radius: baseUnit * 1.5
            
            Label {
                anchors.centerIn: parent
                text: isEditMode ? "EDITAR CONSULTA" : "NUEVA CONSULTA"
                font.pixelSize: fontBaseSize * 1.2
                font.bold: true
                color: whiteColor
                font.family: "Segoe UI, Arial, sans-serif"
            }
            
            // Botón de cerrar
            Button {
                anchors.right: parent.right
                anchors.rightMargin: baseUnit * 2
                anchors.verticalCenter: parent.verticalCenter
                width: baseUnit * 4
                height: baseUnit * 4
                background: Rectangle {
                    color: "transparent"
                    radius: width / 2
                    border.color: parent.hovered ? whiteColor : "transparent"
                    border.width: 1
                }
                
                contentItem: Text {
                    text: "×"
                    color: whiteColor
                    font.pixelSize: fontBaseSize * 1.8
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: {
                    showNewConsultationDialog = false
                    selectedRowIndex = -1
                    isEditMode = false
                    editingIndex = -1
                    consultationForm.consultaParaEditar = null
                }
            }
        }
        
        // SCROLLVIEW PRINCIPAL CON MÁRGENES ADECUADOS - IDÉNTICO A ENFERMERÍA
        ScrollView {
            id: scrollView
            anchors.top: dialogHeader.bottom
            anchors.topMargin: baseUnit * 2
            anchors.bottom: buttonRow.top
            anchors.bottomMargin: baseUnit * 2
            anchors.left: parent.left
            anchors.leftMargin: baseUnit * 3
            anchors.right: parent.right
            anchors.rightMargin: baseUnit * 3
            clip: true
            
            // CONTENEDOR PRINCIPAL DEL FORMULARIO - IDÉNTICO A ENFERMERÍA
            ColumnLayout {
                width: scrollView.width - (baseUnit * 1)
                spacing: baseUnit * 2
                
                // DATOS DEL PACIENTE - IDÉNTICO A ENFERMERÍA
                GroupBox {
                    Layout.fillWidth: true
                    title: "DATOS DEL PACIENTE"
                    font.bold: true
                    font.pixelSize: fontBaseSize
                    font.family: "Segoe UI, Arial, sans-serif"
                    padding: baseUnit * 1.5
                    
                    background: Rectangle {
                        color: "#f8f9fa"
                        border.color: "#e0e0e0"
                        radius: baseUnit * 0.8
                    }
                    
                    GridLayout {
                        width: parent.width
                        columns: 2
                        columnSpacing: baseUnit * 2
                        rowSpacing: baseUnit * 1.5
                        
                        Label {
                            text: "Nombre:"
                            font.bold: true
                            color: textColor
                            font.family: "Segoe UI, Arial, sans-serif"
                        }
                        
                        TextField {
                            id: nombrePaciente
                            Layout.fillWidth: true
                            placeholderText: "Nombre del paciente (opcional)"
                            font.pixelSize: fontBaseSize
                            font.family: "Segoe UI, Arial, sans-serif"
                            background: Rectangle {
                                color: whiteColor
                                border.color: "#ddd"
                                border.width: 1
                                radius: baseUnit * 0.5
                            }
                            padding: baseUnit
                        }
                        
                        Label {
                            text: "Apellido Paterno:"
                            font.bold: true
                            color: textColor
                            font.family: "Segoe UI, Arial, sans-serif"
                        }
                        
                        TextField {
                            id: apellidoPaterno
                            Layout.fillWidth: true
                            placeholderText: "Apellido paterno (opcional)"
                            font.pixelSize: fontBaseSize
                            font.family: "Segoe UI, Arial, sans-serif"
                            background: Rectangle {
                                color: whiteColor
                                border.color: "#ddd"
                                border.width: 1
                                radius: baseUnit * 0.5
                            }
                            padding: baseUnit
                        }
                        
                        Label {
                            text: "Apellido Materno:"
                            font.bold: true
                            color: textColor
                            font.family: "Segoe UI, Arial, sans-serif"
                        }
                        
                        TextField {
                            id: apellidoMaterno
                            Layout.fillWidth: true
                            placeholderText: "Apellido materno (opcional)"
                            font.pixelSize: fontBaseSize
                            font.family: "Segoe UI, Arial, sans-serif"
                            background: Rectangle {
                                color: whiteColor
                                border.color: "#ddd"
                                border.width: 1
                                radius: baseUnit * 0.5
                            }
                            padding: baseUnit
                        }
                        
                        Label {
                            text: "Edad:"
                            font.bold: true
                            color: textColor
                            font.family: "Segoe UI, Arial, sans-serif"
                        }
                        
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit
                            
                            TextField {
                                id: edadPaciente
                                Layout.preferredWidth: baseUnit * 10
                                placeholderText: "Edad (opcional)"
                                font.pixelSize: fontBaseSize
                                font.family: "Segoe UI, Arial, sans-serif"
                                validator: IntValidator { bottom: 0; top: 120 }
                                background: Rectangle {
                                    color: whiteColor
                                    border.color: "#ddd"
                                    border.width: 1
                                    radius: baseUnit * 0.5
                                }
                                padding: baseUnit
                            }
                            
                            Label {
                                text: "años"
                                color: textColorLight
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                            
                            Item { Layout.fillWidth: true }
                        }
                    }
                }
                
                // INFORMACIÓN DE LA CONSULTA - IDÉNTICO A ENFERMERÍA
                GroupBox {
                    Layout.fillWidth: true
                    title: "INFORMACIÓN DE LA CONSULTA"
                    font.bold: true
                    font.pixelSize: fontBaseSize
                    font.family: "Segoe UI, Arial, sans-serif"
                    padding: baseUnit * 1.5
                    
                    background: Rectangle {
                        color: "#f8f9fa"
                        border.color: "#e0e0e0"
                        radius: baseUnit * 0.8
                    }
                    
                    ColumnLayout {
                        width: parent.width
                        spacing: baseUnit * 2
                        
                        // Especialidad
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit * 2
                            
                            Label {
                                text: "Especialidad:"
                                font.bold: true
                                Layout.preferredWidth: baseUnit * 15
                                color: textColor
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                            
                            ComboBox {
                                id: especialidadCombo
                                Layout.fillWidth: true
                                font.pixelSize: fontBaseSize
                                font.family: "Segoe UI, Arial, sans-serif"
                                model: {
                                    var list = ["Seleccionar especialidad..."]
                                    if (consultaModel && consultaModel.especialidades) {
                                        for (var i = 0; i < consultaModel.especialidades.length; i++) {
                                            var esp = consultaModel.especialidades[i]
                                            list.push(esp.text + " - " + esp.doctor_nombre)
                                        }
                                    }
                                    return list
                                }
                                onCurrentIndexChanged: {
                                    if (currentIndex > 0 && consultaModel && consultaModel.especialidades) {
                                        consultationForm.selectedEspecialidadIndex = currentIndex - 1
                                        consultationForm.updatePrices()
                                    } else {
                                        consultationForm.selectedEspecialidadIndex = -1
                                        consultationForm.calculatedPrice = 0.0
                                    }
                                }
                                
                                contentItem: Label {
                                    text: especialidadCombo.displayText
                                    font.pixelSize: fontBaseSize
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    color: textColor
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: baseUnit
                                    elide: Text.ElideRight
                                }
                                
                                background: Rectangle {
                                    color: whiteColor
                                    border.color: "#ddd"
                                    border.width: 1
                                    radius: baseUnit * 0.5
                                }
                                
                                popup: Popup {
                                    width: especialidadCombo.width
                                    implicitHeight: contentItem.implicitHeight + baseUnit
                                    padding: 1
                                    
                                    contentItem: ListView {
                                        clip: true
                                        implicitHeight: contentHeight
                                        model: especialidadCombo.popup.visible ? especialidadCombo.delegateModel : null
                                        currentIndex: especialidadCombo.highlightedIndex
                                        
                                        ScrollIndicator.vertical: ScrollIndicator { }
                                    }
                                    
                                    background: Rectangle {
                                        color: whiteColor
                                        border.color: "#ddd"
                                        radius: baseUnit * 0.5
                                    }
                                }
                            }
                        }
                        
                        // Tipo de consulta
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit * 2
                            
                            Label {
                                text: "Tipo:"
                                font.bold: true
                                Layout.preferredWidth: baseUnit * 15
                                color: textColor
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                            
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: baseUnit * 3
                                
                                RadioButton {
                                    id: normalRadio
                                    text: "Normal"
                                    font.pixelSize: fontBaseSize
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    checked: true
                                    onCheckedChanged: {
                                        if (checked) {
                                            consultationForm.consultationType = "Normal"
                                            consultationForm.updatePrices()
                                        }
                                    }
                                    
                                    contentItem: Label {
                                        text: normalRadio.text
                                        font.pixelSize: fontBaseSize
                                        font.family: "Segoe UI, Arial, sans-serif"
                                        color: textColor
                                        leftPadding: normalRadio.indicator.width + normalRadio.spacing
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                                
                                RadioButton {
                                    id: emergenciaRadio
                                    text: "Emergencia"
                                    font.pixelSize: fontBaseSize
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    onCheckedChanged: {
                                        if (checked) {
                                            consultationForm.consultationType = "Emergencia"
                                            consultationForm.updatePrices()
                                        }
                                    }
                                    
                                    contentItem: Label {
                                        text: emergenciaRadio.text
                                        font.pixelSize: fontBaseSize
                                        font.family: "Segoe UI, Arial, sans-serif"
                                        color: textColor
                                        leftPadding: emergenciaRadio.indicator.width + emergenciaRadio.spacing
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                                
                                Item { Layout.fillWidth: true }
                            }
                        }
                    }
                }
                
                // INFORMACIÓN DE PRECIO - IDÉNTICO A ENFERMERÍA
                GroupBox {
                    Layout.fillWidth: true
                    title: "INFORMACIÓN DE PRECIO"
                    font.bold: true
                    font.pixelSize: fontBaseSize
                    font.family: "Segoe UI, Arial, sans-serif"
                    padding: baseUnit * 1.5
                    
                    background: Rectangle {
                        color: "#f8f9fa"
                        border.color: "#e0e0e0"
                        radius: baseUnit * 0.8
                    }
                    
                    GridLayout {
                        width: parent.width
                        columns: 2
                        columnSpacing: baseUnit * 2
                        rowSpacing: baseUnit * 1.5
                        
                        Label {
                            text: "Precio Consulta:"
                            font.bold: true
                            color: textColor
                            font.family: "Segoe UI, Arial, sans-serif"
                        }
                        
                        Label {
                            text: consultationForm.selectedEspecialidadIndex >= 0 ? 
                                "Bs " + consultationForm.calculatedPrice.toFixed(2) : "Seleccione especialidad"
                            font.bold: true
                            font.pixelSize: fontBaseSize * 1.1
                            font.family: "Segoe UI, Arial, sans-serif"
                            color: consultationForm.consultationType === "Emergencia" ? warningColor : successColor
                            padding: baseUnit
                            background: Rectangle {
                                color: consultationForm.consultationType === "Emergencia" ? warningColorLight : successColorLight
                                radius: baseUnit * 0.8
                            }
                        }
                    }
                }
                
                // DETALLES DE LA CONSULTA - IDÉNTICO A ENFERMERÍA
                GroupBox {
                    Layout.fillWidth: true
                    title: "DETALLES DE LA CONSULTA"
                    font.bold: true
                    font.pixelSize: fontBaseSize
                    font.family: "Segoe UI, Arial, sans-serif"
                    padding: baseUnit * 1.5
                    
                    background: Rectangle {
                        color: "#f8f9fa"
                        border.color: "#e0e0e0"
                        radius: baseUnit * 0.8
                    }
                    
                    TextArea {
                        id: detallesConsulta
                        Layout.fillWidth: true
                        Layout.preferredHeight: baseUnit * 12
                        placeholderText: "Descripción de la consulta, síntomas, observaciones..."
                        font.pixelSize: fontBaseSize
                        font.family: "Segoe UI, Arial, sans-serif"
                        wrapMode: TextArea.Wrap
                        background: Rectangle {
                            color: whiteColor
                            border.color: "#ddd"
                            border.width: 1
                            radius: baseUnit * 0.5
                        }
                        padding: baseUnit
                    }
                }
            }
        }
        
        // BOTONES INFERIORES - IDÉNTICO A ENFERMERÍA
        RowLayout {
            id: buttonRow
            anchors.bottom: parent.bottom
            anchors.bottomMargin: baseUnit * 2
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: baseUnit * 2
            height: baseUnit * 5
            
            Button {
                id: cancelButton
                text: "Cancelar"
                Layout.preferredWidth: baseUnit * 15
                Layout.preferredHeight: baseUnit * 4.5
                
                background: Rectangle {
                    color: cancelButton.pressed ? "#e0e0e0" : 
                        (cancelButton.hovered ? "#f0f0f0" : "#f8f9fa")
                    border.color: "#ddd"
                    border.width: 1
                    radius: baseUnit * 0.8
                }
                
                contentItem: Label {
                    text: parent.text
                    font.pixelSize: fontBaseSize
                    font.bold: true
                    font.family: "Segoe UI, Arial, sans-serif"
                    color: textColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: {
                    nombrePaciente.text = ""
                    apellidoPaterno.text = ""
                    apellidoMaterno.text = ""
                    edadPaciente.text = ""
                    especialidadCombo.currentIndex = 0
                    normalRadio.checked = true
                    detallesConsulta.text = ""
                    showNewConsultationDialog = false
                    selectedRowIndex = -1
                    consultationForm.consultaParaEditar = null
                    isEditMode = false
                    editingIndex = -1
                }
            }
            
            Button {
                id: saveButton
                text: isEditMode ? "Actualizar" : "Guardar"
                enabled: consultationForm.selectedEspecialidadIndex >= 0
                Layout.preferredWidth: baseUnit * 15
                Layout.preferredHeight: baseUnit * 4.5
                
                background: Rectangle {
                    color: !saveButton.enabled ? "#bdc3c7" : 
                        (saveButton.pressed ? Qt.darker(primaryColor, 1.1) : 
                        (saveButton.hovered ? Qt.lighter(primaryColor, 1.1) : primaryColor))
                    radius: baseUnit * 0.8
                }
                
                contentItem: Label {
                    text: parent.text
                    font.pixelSize: fontBaseSize
                    font.bold: true
                    font.family: "Segoe UI, Arial, sans-serif"
                    color: whiteColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: {
                    if (consultationForm.selectedEspecialidadIndex < 0) {
                        showNotification("Error", "Seleccione una especialidad")
                        return
                    }
                    
                    try {
                        if (isEditMode && consultationForm.consultaParaEditar) {
                            // Lógica de actualización - mantener la funcionalidad existente
                            console.log("Actualizando consulta existente")
                            // Aquí iría la lógica de actualización específica
                        } else {
                            // Crear nueva consulta - usar la función existente
                            crearConsulta()
                        }
                        
                    } catch (error) {
                        console.error("Error procesando consulta:", error)
                        showNotification("Error", "Error inesperado al procesar la consulta")
                    }
                }
            }
        }
    }

    function getTotalConsultasCount() {
        return consultasOriginales.length
    }
    
    Component.onCompleted: {
        console.log("🩺 Módulo Consultas inisciado")
        console.log("🔧 Sistema de edición de consultas inicializado")
        function conectarModelos() {
            if (typeof appController !== 'undefined') {
                consultaModel = appController.consulta_model_instance
                pacienteModel = appController.paciente_model_instance
                
                if (consultaModel) {
                    // Conectar señales para actualizaciones
                    consultaModel.consultasRecientesChanged.connect(function() {
                        console.log("🔄 Consultas actualizadas - forzando refresh")
                        updatePaginatedModel()
                    })
                    
                    consultaModel.refresh_consultas()
                    consultaModel.refresh_especialidades()
                    return true
                }
            }
            return false
        }
        
        // Timer simplificado - solo 3 intentos
        var attempts = 0
        var timer = Qt.createQmlObject("import QtQuick 2.15; Timer { interval: 300; repeat: true }", consultasRoot)
        
        timer.triggered.connect(function() {
            if (conectarModelos() || ++attempts >= 3) {
                timer.destroy()
            }
        })
        timer.start()
    }

    function obtenerEspecialidades() {
        var especialidades = ["Todas"]
        
        if (consultaModel && consultaModel.especialidades) {
            for (var i = 0; i < consultaModel.especialidades.length; i++) {
                var esp = consultaModel.especialidades[i]
                if (esp.text) {
                    especialidades.push(esp.text)
                }
            }
        }
        
        return especialidades
    }

    function updateEspecialidadesCombo() {
        if (filtroEspecialidad) {
            var especialidades = ["Todas"]
            
            if (consultaModel && consultaModel.especialidades) {
                for (var i = 0; i < consultaModel.especialidades.length; i++) {
                    var esp = consultaModel.especialidades[i]
                    if (esp && esp.text) {
                        especialidades.push(esp.text)
                    }
                }
            }
            filtroEspecialidad.model = especialidades
        }
    }

    function updatePaginatedModel() {
        console.log("🔄 Actualizando modelo paginado...")
        consultasPaginadasModel.clear()
        
        var consultas = []
        
        // Obtener consultas directamente del modelo
        if (consultaModel && consultaModel.consultas_recientes) {
            console.log("📋 Usando consultas del modelo")
            consultas = consultaModel.consultas_recientes
            // Actualizar consultas originales
            consultasOriginales = consultas
        } else if (consultasOriginales && consultasOriginales.length > 0) {
            console.log("📋 Usando consultas originales cacheadas")
            consultas = consultasOriginales
        } else {
            console.log("⚠️ No hay consultas disponibles - usando array vacío")
            consultas = []
        }
        
        console.log("📊 Consultas disponibles para paginación:", consultas.length)
        
        // Aplicar filtros
        consultas = aplicarFiltrosConsulta(consultas)
        
        var totalItems = consultas.length
        totalPagesConsultas = Math.ceil(totalItems / itemsPerPageConsultas) || 1
        
        // Restablecer a la primera página si es necesario
        if (currentPageConsultas >= totalPagesConsultas) {
            currentPageConsultas = Math.max(0, totalPagesConsultas - 1)
        }
        
        var startIndex = currentPageConsultas * itemsPerPageConsultas
        var endIndex = Math.min(startIndex + itemsPerPageConsultas, totalItems)
        
        console.log("📊 Paginación:", "página", currentPageConsultas + 1, "de", totalPagesConsultas, 
                    "índices", startIndex, "a", endIndex, "de", totalItems, "elementos")
        
        // Llenar el modelo paginado
        for (var i = startIndex; i < endIndex; i++) {
            var consulta = consultas[i]
            
            // Asegurar que la consulta tenga la estructura esperada
            var consultaId = consulta.id ? consulta.id.toString() : "N/A"
            var paciente = consulta.paciente_completo || consulta.paciente_nombre || "Sin nombre"
            var especialidadDoctor = (consulta.especialidad_nombre || "Sin especialidad") + " - " + 
                                    (consulta.doctor_completo || consulta.doctor_nombre || "Sin doctor")
            var tipo = consulta.Tipo_Consulta || "Normal"
            var precio = consulta.Precio_Normal ? consulta.Precio_Normal.toFixed(2) : "0.00"
            var fecha = formatearFecha(consulta.Fecha)
            var detalles = consulta.Detalles || "Sin detalles"
            
            consultasPaginadasModel.append({
                consultaId: consultaId,
                paciente: paciente,
                especialidadDoctor: especialidadDoctor,
                tipo: tipo,
                precio: precio,
                fecha: fecha,
                detalles: detalles
            })
        }
        
        console.log("✅ Modelo paginado actualizado:", consultasPaginadasModel.count, "elementos")
    }

    function crearConsulta() {
        if (consultationForm.selectedEspecialidadIndex < 0) {
            showNotification("Error", "Seleccione una especialidad")
            return
        }
        
        try {
            // Gestionar paciente inteligentemente
            var pacienteId = consultaModel.buscarOCrearPacienteInteligente(
                nombrePaciente.text,
                apellidoPaterno.text,
                apellidoMaterno.text,
                parseInt(edadPaciente.text) || 0
            )
            
            if (pacienteId <= 0) {
                showNotification("Error", "Error gestionando datos del paciente")
                return
            }
            
            var especialidad = consultaModel.especialidades[consultationForm.selectedEspecialidadIndex]
            
            var datosConsulta = {
                "paciente_id": pacienteId,  // Ahora usa el ID real
                "especialidad_id": especialidad.id,
                "detalles": detallesConsulta.text,
                "tipo_consulta": consultationForm.consultationType.toLowerCase()
            }
            
            console.log("📝 Enviando datos:", JSON.stringify(datosConsulta))
            
            var consultaId = consultaModel.crear_consulta(datosConsulta)
            if (consultaId > 0) {
                limpiarYCerrarDialogoConsulta()
            }
            
        } catch (error) {
            console.error("Error creando consulta:", error)
            showNotification("Error", "Error procesando consulta")
        }
    }
    function limpiarYCerrarDialogoConsulta() {
        showNewConsultationDialog = false
        nombrePaciente.text = ""
        apellidoPaterno.text = ""
        apellidoMaterno.text = ""
        edadPaciente.text = ""
        detallesConsulta.text = ""
        especialidadCombo.currentIndex = 0
        normalRadio.checked = true
    }

    // Crea una consulta usando el pacienteId proporcionado
    function crearConsultaConPaciente(pacienteId) {
        if (consultationForm.selectedEspecialidadIndex < 0) {
            showNotification("Error", "Seleccione una especialidad")
            return
        }
        var especialidad = consultaModel.especialidades[consultationForm.selectedEspecialidadIndex]
        var datosConsulta = {
            "paciente_id": pacienteId,
            "especialidad_id": especialidad.id,
            "detalles": detallesConsulta.text,
            "tipo_consulta": consultationForm.consultationType.toLowerCase()
        }
        console.log("📝 Enviando datos:", JSON.stringify(datosConsulta))
        var consultaId = consultaModel.crear_consulta(datosConsulta)
        if (consultaId > 0) {
            showNewConsultationDialog = false
            // Limpiar formulario
            nombrePaciente.text = ""
            apellidoPaterno.text = ""
            apellidoMaterno.text = ""
            edadPaciente.text = ""
            detallesConsulta.text = ""
            especialidadCombo.currentIndex = 0
            // Forzar actualización
            consultaModel.refresh_consultas()
        }
    }

    function buscarPaciente(nombre, apellidoPaterno, apellidoMaterno) {
        // Usar el modelo para buscar pacientes
        var resultados = consultaModel.buscar_pacientes(nombre + " " + apellidoPaterno)
        
        if (resultados && resultados.length > 0) {
            // Encontró pacientes, mostrar diálogo de selección
            mostrarDialogoSeleccionPaciente(resultados)
        } else {
            // No encontró pacientes, crear uno nuevo
            return -1 // Indicar que necesita crear nuevo paciente
        }
    }

    function mostrarDialogoSeleccionPaciente(resultados, callback) {
        var dialog = Qt.createQmlObject(`
            import QtQuick 2.15
            import QtQuick.Controls 2.15
            import QtQuick.Layouts 1.15
            
            Dialog {
                id: selectPatientDialog
                title: "Seleccionar Paciente"
                modal: true
                standardButtons: Dialog.Cancel
                width: 600
                height: 400
                
                property var pacientes: ${JSON.stringify(resultados)}
                property var callbackFunc: null
                
                ColumnLayout {
                    width: parent.width
                    
                    Label {
                        text: "Se encontraron múltiples pacientes. Seleccione uno:"
                        wrapMode: Text.Wrap
                    }
                    
                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: selectPatientDialog.pacientes
                        clip: true
                        
                        delegate: ItemDelegate {
                            width: ListView.view.width
                            text: modelData.nombre_completo || (modelData.Nombre + " " + modelData.Apellido_Paterno + " " + (modelData.Apellido_Materno || ""))
                            onClicked: {
                                if (selectPatientDialog.callbackFunc) {
                                    selectPatientDialog.callbackFunc(modelData.id)
                                }
                                selectPatientDialog.close()
                            }
                        }
                    }
                }
                
                function openWithCallback(callback) {
                    callbackFunc = callback
                    open()
                }
            }
        `, consultasRoot, "selectPatientDialog")
        
        dialog.openWithCallback(callback)
    }

    function aplicarFiltrosConsulta(consultas) {
        if (!consultas) return []
        
        var consultasFiltradas = consultas
        
        // Filtro por búsqueda
        var termino = campoBusqueda ? campoBusqueda.text.toLowerCase() : ""
        if (termino.length >= 2) {
            consultasFiltradas = consultasFiltradas.filter(function(c) {
                return (c.paciente_completo || "").toLowerCase().includes(termino)
            })
        }
        
        // Filtro por especialidad
        if (filtroEspecialidad && filtroEspecialidad.currentIndex > 0) {
            var especialidadSeleccionada = filtroEspecialidad.currentText
            consultasFiltradas = consultasFiltradas.filter(function(c) {
                return (c.especialidad_nombre || "").includes(especialidadSeleccionada)
            })
        }
        
        // FILTRO POR TIPO CORREGIDO
        if (filtroTipo && filtroTipo.currentIndex > 0) {
            var tipoSeleccionado = filtroTipo.currentIndex === 1 ? "Normal" : "Emergencia"
            console.log("🔍 Filtro tipo seleccionado (por índice):", tipoSeleccionado)
            
            consultasFiltradas = consultasFiltradas.filter(function(c) {
                var tipoConsulta = c.Tipo_Consulta || "Normal"
                console.log("🔍 Comparando:", tipoConsulta, "===", tipoSeleccionado)
                return tipoConsulta === tipoSeleccionado
            })
            
            console.log("🔍 Consultas filtradas por tipo:", consultasFiltradas.length)
        }
        
        return consultasFiltradas
    }

    function aplicarFiltros() {
        console.log("🔍 Aplicando filtros...")
        console.log("🔍 Filtro tipo actual:", filtroTipo.currentText, "índice:", filtroTipo.currentIndex)
        
        // RESETEAR PAGINACIÓN AL APLICAR FILTROS
        currentPageConsultas = 0
        
        // APLICAR FILTROS INMEDIATAMENTE
        updatePaginatedModel()
    }

    function buscarPacientePorNombre(nombreCompleto) {
        if (!pacienteModel) return null
        
        try {
            // Buscar usando el método de búsqueda del modelo
            var resultados = pacienteModel.search_patients(nombreCompleto)
            
            if (resultados && resultados.length > 0) {
                return resultados[0] // Retornar el primer resultado
            }
            
            return null
        } catch (e) {
            console.log("⚠️ Error buscando paciente:", e)
            return null
        }
    }

}