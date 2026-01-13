// Interfaz de laboratorio
import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import Clinica.Models 1.0

Item {
    id: laboratorioRoot
    objectName: "laboratorioRoot"

    // ACCESO AL MODELO DE BACKEND
    property var laboratorioModel: null
    
    // SISTEMA DE ESTILOS ADAPTATIVAS DEL MAIN
    readonly property real baseUnit: parent.baseUnit || Math.max(8, Screen.height / 100)
    readonly property real fontBaseSize: parent.fontBaseSize || Math.max(12, Screen.height / 70)
    readonly property real scaleFactor: parent.scaleFactor || Math.min(width / 1400, height / 900)
    
    // PROPIEDADES DE TAMAÑO
    readonly property real iconSize: Math.max(baseUnit * 3, 24)
    readonly property real buttonIconSize: Math.max(baseUnit * 2, 18)

    // PROPIEDADES DE COLOR 
    readonly property color primaryColor: "#3498DB"  // Azul para laboratorio
    readonly property color primaryColorHover: "#2980B9"
    readonly property color primaryColorPressed: "#21618C"
    readonly property color successColor: "#27ae60"
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

    // Distribución de columnas responsive
    readonly property real colCodigo: 0.06        
    readonly property real colPaciente: 0.18      
    readonly property real colAnalisis: 0.20      
    readonly property real colDetalles: 0.16      
    readonly property real colEjecutadoPor: 0.14   
    readonly property real colTipo: 0.08          
    readonly property real colPrecio: 0.09        
    readonly property real colFecha: 0.09

    // ✅ PROPIEDADES CONSOLIDADAS - SIN DUPLICADOS
    property string analisisIdToDelete: ""
    property bool showConfirmDeleteDialog: false
    property bool showNewAnalysisDialog: false
    property bool isEditMode: false
    property int editingIndex: -1
    property int selectedRowIndex: -1
    property bool formEnabled: true

    // DATOS DESDE EL BACKEND
    property var trabajadoresDisponibles: laboratorioModel ? laboratorioModel.trabajadoresJson : "[]"
    property var tiposAnalisis: laboratorioModel ? laboratorioModel.tiposAnalisisJson : "[]"

    // PROPIEDADES DE FILTRO
    property var analisisModelData: []
    property var analysisMap: []

    // ✅ PROPIEDADES DE PAGINACIÓN CORREGIDAS
    readonly property int currentPageLaboratorio: laboratorioModel ? (laboratorioModel.currentPageProperty || 0) : 0
    readonly property int totalPagesLaboratorio: laboratorioModel ? (laboratorioModel.totalPagesProperty || 0) : 0
    readonly property int itemsPerPageLaboratorio: laboratorioModel ? (laboratorioModel.itemsPerPageProperty || 6) : 6
    readonly property int totalItemsLaboratorio: laboratorioModel ? (laboratorioModel.totalRecordsProperty || 0) : 0
    
    // Agregar al inicio del laboratorioRoot, después de las propiedades existentes
    readonly property string usuarioActualRol: {
        if (typeof authModel !== 'undefined' && authModel) {
            return authModel.userRole || ""
        }
        return ""
    }
    readonly property bool esAdministrador: usuarioActualRol === "Administrador"
    readonly property bool esMedico: usuarioActualRol === "Médico" || usuarioActualRol === "MÃ©dico"

    // Propiedades para búsqueda unificada de pacientes
    property bool mostrarResultadosBusqueda: false
    property bool pacienteSeleccionado: false
    property var pacienteActual: null
    property string tipoDetectado: ""

    // Agregar estas propiedades al inicio del archivo, después de las propiedades existentes
    property int pacienteSeleccionadoId: -1  // ✅ NUEVO: ID del paciente seleccionado
    property bool esPacienteExistente: false // ✅ NUEVO: Flag para paciente existente

    ListModel {
        id: analisisPaginadosModel // Modelo para la página actual
    }
    ListModel {
        id: resultadosBusquedaPacientesModel
    }

    // ✅ CONEXIÓN CON EL MODELO CORREGIDA
    Connections {
        target: appController
        function onModelsReady() {
            //console.log("🔬 Modelos listos, conectando LaboratorioModel...")
            laboratorioModel = appController.laboratorio_model_instance
            if (laboratorioModel) {
                initializarModelo()
            }
        }
    }

    Timer {
        id: initTimer
        interval: 100
        running: false
        repeat: false
        onTriggered: {
            console.log("⏰ Ejecutando inicialización retrasada...")
            if (laboratorioModel) {
                laboratorioModel.aplicar_filtros_y_recargar("", "", "", "", "")
            }
        }
    }

    // ✅ CONEXIONES CON EL MODELO CORREGIDAS
    Connections {
        target: laboratorioModel
        enabled: laboratorioModel !== null
        
        function onExamenesActualizados() {

            updateTimer.start()
        }
        
        function onTiposAnalisisActualizados() {
   
            Qt.callLater(updateAnalisisCombo)
        }
        
        function onTrabajadoresActualizados() {
            console.log("👥 Signal: Trabajadores actualizados") 
        }
        
        function onEstadoCambiado(nuevoEstado) {
            console.log("⏳ Estado:", nuevoEstado)
        }
        
        function onOperacionExitosa(mensaje) {

            mostrarNotificacion("Éxito", mensaje)
            updatePaginatedModel()
            
            if (showNewAnalysisDialog && (mensaje.includes("creado") || mensaje.includes("actualizado") || mensaje.includes("Examen"))) {
                Qt.callLater(function() {
                    limpiarYCerrarDialogo()
                })
            }
        }
        
        function onExamenActualizado(datos) {

            mostrarNotificacion("Éxito", "Análisis actualizado correctamente")
            
            Qt.callLater(function() {
                if (showNewAnalysisDialog) {
                    limpiarYCerrarDialogo()
                }
            })
        }
    }

    Timer {
        id: updateTimer
        interval: 100
        onTriggered: updatePaginatedModel()
    }

    // ✅ FUNCIÓN MEJORADA PARA MOSTRAR NOTIFICACIONES
    function mostrarNotificacion(titulo, mensaje) {
        console.log("📢 " + titulo + ": " + mensaje)
    }

    // LAYOUT PRINCIPAL RESPONSIVO
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
                
                // HEADER ADAPTATIVO
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: baseUnit * 12
                    color: lightGrayColor
                    border.color: borderColor
                    border.width: 1
                    radius: baseUnit * 2
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: baseUnit * 2
                        spacing: baseUnit * 2
                        
                        // SECCIÓN DEL LOGO Y TÍTULO
                        RowLayout {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: baseUnit * 1.5
                            
                            Rectangle {
                                Layout.preferredWidth: baseUnit * 10
                                Layout.preferredHeight: baseUnit * 10
                                color: "transparent"
                                
                                Image {
                                    id: laboratorioIcon
                                    anchors.centerIn: parent
                                    width: Math.min(baseUnit * 8, parent.width * 0.8)
                                    height: Math.min(baseUnit * 8, parent.height * 0.8)
                                    source: "Resources/iconos/Laboratorio.png"
                                    fillMode: Image.PreserveAspectFit
                                    antialiasing: true
                                    
                                    onStatusChanged: {
                                        if (status === Image.Error) {
                                            console.log("Error cargando PNG de laboratorio:", source)
                                        } else if (status === Image.Ready) {
                                            console.log("PNG de laboratorio cargado correctamente:", source)
                                        }
                                    }
                                }
                            }
                            
                            Label {
                                Layout.alignment: Qt.AlignVCenter
                                text: "Gestión de Análisis de Laboratorio"
                                font.pixelSize: fontBaseSize * 1.3
                                font.bold: true
                                font.family: "Segoe UI, Arial, sans-serif"
                                color: textColor
                                wrapMode: Text.WordWrap
                            }
                        }
                        
                        Item { 
                            Layout.fillWidth: true 
                            Layout.minimumWidth: baseUnit * 2
                        }
                        
                        // BOTÓN NUEVO ANÁLISIS
                        Button {
                            id: newAnalysisBtn
                            objectName: "newAnalysisButton"
                            Layout.preferredHeight: baseUnit * 5
                            Layout.preferredWidth: Math.max(baseUnit * 20, implicitWidth + baseUnit * 2)
                            Layout.alignment: Qt.AlignVCenter
                            enabled: true
                            visible: true

                            background: Rectangle {
                                color: newAnalysisBtn.pressed ? primaryColorPressed : 
                                    newAnalysisBtn.hovered ? primaryColorHover : primaryColor
                                radius: baseUnit * 1.2
                                border.width: 0
                                
                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                            
                            contentItem: RowLayout {
                                spacing: baseUnit
                                
                                Rectangle {
                                    Layout.preferredWidth: baseUnit * 3
                                    Layout.preferredHeight: baseUnit * 3
                                    color: "transparent"
                                    
                                    Image {
                                        id: addIcon
                                        anchors.centerIn: parent
                                        width: baseUnit * 2.5
                                        height: baseUnit * 2.5
                                        source: "Resources/iconos/Nueva_Consulta.png"
                                        fillMode: Image.PreserveAspectFit
                                        antialiasing: true
                                        
                                        onStatusChanged: {
                                            if (status === Image.Error) {
                                                console.log("Error cargando PNG del botón:", source)
                                                visible = false
                                                fallbackText.visible = true
                                            }
                                        }
                                    }
                                    
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
                                
                                Label {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: "Nuevo Análisis"
                                    color: whiteColor
                                    font.bold: true
                                    font.pixelSize: fontBaseSize
                                    font.family: "Segoe UI, Arial, sans-serif"
                                }
                            }
                            
                            onClicked: {
                                if (!laboratorioRoot.esAdministrador && !laboratorioRoot.esMedico) {
                                    mostrarNotificacion("Error", "No tiene permisos para crear análisis")
                                    return
                                }
                                
                                isEditMode = false
                                editingIndex = -1
                                showNewAnalysisDialog = true
                            }
                            
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
                        
                        columns: width < 1000 ? 2 : 5
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
                                text: "Análisis:"
                                font.bold: true
                                color: textColor
                                font.pixelSize: fontBaseSize * 0.9
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                            
                            ComboBox {
                                id: filtroAnalisis
                                Layout.fillWidth: true
                                Layout.preferredHeight: baseUnit * 4
                                
                                model: {
                                    var modelData = ["Todos"]
                                    try {
                                        var tiposData = JSON.parse(tiposAnalisis)
                                        for (var i = 0; i < tiposData.length; i++) {
                                            var nombre = tiposData[i].nombre || tiposData[i].Nombre || ""
                                            if (nombre && nombre !== "Todos") {
                                                modelData.push(nombre)
                                            }
                                        }
                                    } catch (e) {
                                        console.log("Error parseando tipos análisis:", e)
                                    }
                                    return modelData
                                }
                                currentIndex: 0
                                
                                contentItem: Label {
                                    text: filtroAnalisis.displayText
                                    font.pixelSize: fontBaseSize * 0.8
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    color: textColor
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: baseUnit
                                    elide: Text.ElideRight
                                }
                                onCurrentIndexChanged: {
                                    console.log("🔍 Tipo análisis cambiado - Índice:", currentIndex, "Texto:", currentText)
                                    aplicarFiltros()
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
                                
                                contentItem: Label {
                                    text: filtroTipo.displayText
                                    font.pixelSize: fontBaseSize * 0.8
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    color: textColor
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: baseUnit
                                }
                                onCurrentIndexChanged: {
                                    console.log("🔍 Tipo servicio cambiado - Índice:", currentIndex, "Texto:", currentText)
                                    aplicarFiltros()
                                }
                            }
                        }
                        
                        TextField {
                            id: campoBusqueda
                            Layout.fillWidth: true
                            Layout.preferredHeight: baseUnit * 4
                            placeholderText: "Buscar por paciente o cédula..."
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

                        Button {
                            id: limpiarFiltrosBtn
                            text: "Limpiar Filtros"
                            Layout.preferredHeight: baseUnit * 4
                            Layout.fillWidth: true
                            
                            background: Rectangle {
                                color: limpiarFiltrosBtn.pressed ? "#E5E7EB" : 
                                    limpiarFiltrosBtn.hovered ? "#D1D5DB" : "#F3F4F6"
                                border.color: "#D1D5DB"
                                border.width: 1
                                radius: baseUnit * 0.8
                            }
                            
                            contentItem: Label {
                                text: limpiarFiltrosBtn.text
                                color: "#374151"
                                font.pixelSize: fontBaseSize * 0.9
                                font.family: "Segoe UI, Arial, sans-serif"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: {
                                limpiarFiltros()
                            }
                            
                            HoverHandler {
                                cursorShape: Qt.PointingHandCursor
                            }
                            
                            ToolTip {
                                visible: limpiarFiltrosBtn.hovered
                                text: "Restablecer todos los filtros"
                                delay: 500
                                timeout: 3000
                            }
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
                        
                        // HEADER CON LÍNEAS VERTICALES - ESTRUCTURA NUEVA
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
                                
                                // CÓDIGO COLUMN
                                Item {
                                    Layout.preferredWidth: parent.width * colCodigo
                                    Layout.fillHeight: true
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "CÓDIGO"
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
                                
                                // ANÁLISIS COLUMN
                                Item {
                                    Layout.preferredWidth: parent.width * colAnalisis
                                    Layout.fillHeight: true
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "ANÁLISIS"
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
                                
                                // DETALLES COLUMN (NUEVA)
                                Item {
                                    Layout.preferredWidth: parent.width * colDetalles
                                    Layout.fillHeight: true
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "DETALLES"
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
                                
                                // EJECUTADO POR COLUMN (CONSOLIDADO)
                                Item {
                                    Layout.preferredWidth: parent.width * colEjecutadoPor
                                    Layout.fillHeight: true
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "EJECUTADO POR"
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
                        
                        // CONTENIDO DE TABLA CON SCROLL Y LÍNEAS VERTICALES - NUEVA ESTRUCTURA
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            
                            ListView {
                                id: analisisListView
                                model: analisisPaginadosModel
                                section {
                                    property: "tipo"
                                    criteria: ViewSection.FullString
                                    labelPositioning: ViewSection.InlineLabels
                                }
                                delegate: Rectangle {
                                    width: ListView.view.width
                                    height: baseUnit * 5.5
                                    color: {
                                        if (selectedRowIndex === index) return "#F8F9FA"
                                        return index % 2 === 0 ? whiteColor : "#FAFAFA"
                                    }
                                    
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        height: 1
                                        color: borderColor
                                    }
                                    
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
                                        
                                        // CÓDIGO COLUMN
                                        Item {
                                            Layout.preferredWidth: parent.width * colCodigo
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                text: model.analisisId || "N/A"
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
                                            
                                            Column {
                                                anchors.fill: parent
                                                anchors.margins: baseUnit * 0.5
                                                
                                                Label {
                                                    width: parent.width - baseUnit
                                                    text: model.paciente || "Sin nombre"
                                                    color: textColor
                                                    font.bold: false
                                                    font.pixelSize: fontBaseSize * 0.85
                                                    font.family: "Segoe UI, Arial, sans-serif"
                                                    elide: Text.ElideRight
                                                }
                                                
                                                Label {
                                                    width: parent.width - baseUnit
                                                    text: "CI: " + (model.pacienteCedula || "Sin cédula")
                                                    color: textColorLight
                                                    font.pixelSize: fontBaseSize * 0.75
                                                    font.family: "Segoe UI, Arial, sans-serif"
                                                    elide: Text.ElideRight
                                                }
                                            }
                                            
                                            Rectangle {
                                                anchors.right: parent.right
                                                width: 1
                                                height: parent.height
                                                color: lineColor
                                            }
                                        }
                                        
                                        // ANÁLISIS COLUMN (SIMPLIFICADO)
                                        Item {
                                            Layout.preferredWidth: parent.width * colAnalisis
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                anchors.rightMargin: baseUnit
                                                text: model.tipoAnalisis || "Análisis General"
                                                color: primaryColor
                                                font.bold: false
                                                font.pixelSize: fontBaseSize * 0.85
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
                                        
                                        // DETALLES COLUMN (NUEVA - SEPARADA DE ANÁLISIS)
                                        Item {
                                            Layout.preferredWidth: parent.width * colDetalles
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                anchors.rightMargin: baseUnit
                                                text: {
                                                    var detalles = model.detallesExamen || ""
                                                    if (detalles && detalles.trim() !== "") {
                                                        return detalles
                                                    } else {
                                                        return "Sin detalles específicos"
                                                    }
                                                }
                                                color: textColorLight
                                                font.pixelSize: fontBaseSize * 0.85
                                                font.family: "Segoe UI, Arial, sans-serif"
                                                elide: Text.ElideRight
                                                wrapMode: Text.WordWrap
                                                maximumLineCount: 2
                                            }
                                            
                                            Rectangle {
                                                anchors.right: parent.right
                                                width: 1
                                                height: parent.height
                                                color: lineColor
                                            }
                                        }
                                        
                                        // EJECUTADO POR COLUMN (CONSOLIDADO)
                                        Item {
                                            Layout.preferredWidth: parent.width * colEjecutadoPor
                                            Layout.fillHeight: true
                                            
                                            Column {
                                                anchors.fill: parent
                                                anchors.margins: baseUnit * 0.5
                                                
                                                Label {
                                                    width: parent.width - baseUnit
                                                    text: model.trabajadorAsignado || "Sin asignar"
                                                    color: textColor
                                                    font.bold: false
                                                    font.pixelSize: fontBaseSize * 0.85
                                                    font.family: "Segoe UI, Arial, sans-serif"
                                                    elide: Text.ElideRight
                                                }
                                                
                                                Label {
                                                    width: parent.width - baseUnit
                                                    text: "Por: " + (model.registradoPor || "Sistema")
                                                    color: textColorLight
                                                    font.pixelSize: fontBaseSize * 0.75
                                                    font.family: "Segoe UI, Arial, sans-serif"
                                                    elide: Text.ElideRight
                                                }
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
                                                    text: model.tipo || "Normal"
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
                                                text: "Bs " + (model.precio || "0.00")
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
                                                text: model.fecha || "Sin fecha"
                                                color: textColor
                                                font.bold: false
                                                font.pixelSize: fontBaseSize * 0.85
                                                font.family: "Segoe UI, Arial, sans-serif"
                                            }
                                        }
                                    }
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            selectedRowIndex = selectedRowIndex === index ? -1 : index
                                            console.log("Seleccionado análisis ID:", model.analisisId)
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
                                            visible: laboratorioRoot.esAdministrador || laboratorioRoot.esMedico
                                            enabled: laboratorioRoot.esAdministrador || laboratorioRoot.esMedico
                                            
                                            background: Rectangle {
                                                color: "transparent"
                                            }
                                            
                                            Image {
                                                id: editIcon
                                                anchors.centerIn: parent
                                                width: baseUnit * 2.5
                                                height: baseUnit * 2.5
                                                source: "Resources/iconos/editar.svg"
                                                fillMode: Image.PreserveAspectFit
                                                opacity: parent.enabled ? (parent.hovered ? 0.7 : 1.0) : 0.3
                                            }
                                            
                                            onClicked: {
                                                var analisisId = parseInt(model.analisisId)
                                                editarAnalisis(index, analisisId)
                                            }
                                            
                                            ToolTip {
                                                visible: editButton.hovered
                                                text: {
                                                    if (laboratorioRoot.esAdministrador || laboratorioRoot.esMedico) return "Editar análisis"
                                                    return "Sin permisos"
                                                }
                                            }
                                        }

                                        Button {
                                            id: deleteButton
                                            width: baseUnit * 3.5
                                            height: baseUnit * 3.5
                                            visible: laboratorioRoot.esAdministrador || laboratorioRoot.esMedico
                                            enabled: laboratorioRoot.esAdministrador || laboratorioRoot.esMedico
                                            
                                            background: Rectangle {
                                                color: "transparent"
                                            }
                                            
                                            Image {
                                                id: deleteIcon
                                                anchors.centerIn: parent
                                                width: baseUnit * 2.5
                                                height: baseUnit * 2.5
                                                source: "Resources/iconos/eliminar.svg"
                                                fillMode: Image.PreserveAspectFit
                                                opacity: parent.hovered ? 0.7 : 1.0
                                            }
                                            
                                            onClicked: {
                                                var analisisId = model.analisisId
                                                if (analisisId && analisisId !== "N/A") {
                                                    analisisIdToDelete = analisisId
                                                    showConfirmDeleteDialog = true
                                                }
                                            }
                                            
                                            ToolTip {
                                                visible: deleteButton.hovered
                                                text: obtenerTooltipEliminacion(parseInt(model.analisisId))
                                                delay: 500
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // ESTADO VACÍO PARA TABLA SIN DATOS
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: analisisPaginadosModel.count === 0
                            spacing: baseUnit * 3
                            
                            Item { Layout.fillHeight: true }
                            
                            ColumnLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: baseUnit * 2
                                
                                Label {
                                    text: "🔬"
                                    font.pixelSize: fontBaseSize * 3
                                    color: "#E5E7EB"
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                
                                Label {
                                    text: "No hay análisis registrados"
                                    color: textColor
                                    font.bold: true
                                    font.pixelSize: fontBaseSize * 1.5
                                    Layout.alignment: Qt.AlignHCenter
                                    font.family: "Segoe UI, Arial, sans-serif"
                                }
                                
                                Label {
                                    text: "Registra el primer análisis haciendo clic en \"Nuevo Análisis\""
                                    color: textColorLight
                                    font.pixelSize: fontBaseSize
                                    Layout.alignment: Qt.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    horizontalAlignment: Text.AlignHCenter
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    Layout.maximumWidth: baseUnit * 40
                                }
                            }
                            
                            Item { Layout.fillHeight: true }
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
                            enabled: currentPageLaboratorio > 0
                            
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
                            
                            onClicked: irAPaginaAnterior()
                        }
                        
                        Label {
                            text: "Página " + (currentPageLaboratorio + 1) + " de " + (totalPagesLaboratorio > 0 ? totalPagesLaboratorio : 1)
                            color: textColor
                            font.pixelSize: fontBaseSize * 0.8
                            font.family: "Segoe UI, Arial, sans-serif"
                            font.weight: Font.Medium
                        }
                        
                        Button {
                            Layout.preferredWidth: baseUnit * 11
                            Layout.preferredHeight: baseUnit * 4
                            text: "Siguiente →"
                            enabled: currentPageLaboratorio < (totalPagesLaboratorio - 1) && totalPagesLaboratorio > 1
                            
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
                            
                            onClicked: irAPaginaSiguiente()
                        }
                    }
                }
            }
        }
    }
    
    // DIÁLOGO MODAL DE NUEVO/EDITAR ANÁLISIS - ACTUALIZADO CON BÚSQUEDA UNIFICADA
    Dialog {
        id: analysisFormDialog
        anchors.centerIn: laboratorioRoot
        width: Math.min(laboratorioRoot.width * 0.95, 700)
        height: Math.min(laboratorioRoot.height * 0.95, 850)
        modal: true
        closePolicy: Popup.NoAutoClose
        visible: showNewAnalysisDialog
        
        title: ""
        
        background: Rectangle {
            color: whiteColor
            radius: baseUnit * 1.5
            border.color: "#DDD"
            border.width: 1
            
            Rectangle {
                anchors.fill: parent
                anchors.margins: -baseUnit
                color: "transparent"
                radius: parent.radius + baseUnit
                border.color: "#20000000"
                border.width: baseUnit
                z: -1
            }
        }
        
        property var analisisParaEditar: null
        property int selectedAnalysisIndex: -1
        property string analysisType: "Normal"
        property real calculatedPrice: 0.0
        
        // Propiedades para búsqueda unificada de pacientes
        property bool mostrarResultadosBusqueda: false
        property bool pacienteSeleccionado: false
        property var pacienteActual: null
        property string tipoDetectado: ""
        
        function updatePrice() {
            if (analysisFormDialog.selectedAnalysisIndex >= 0) {
                try {
                    var tiposData = JSON.parse(tiposAnalisis)
                    if (tiposData && tiposData.length > analysisFormDialog.selectedAnalysisIndex) {
                        var tipoAnalisis = tiposData[analysisFormDialog.selectedAnalysisIndex]
                        
                        var precio = 0
                        if (analysisFormDialog.analysisType === "Emergencia") {
                            precio = tipoAnalisis.precioEmergencia || tipoAnalisis.Precio_Emergencia || 0
                        } else {
                            precio = tipoAnalisis.precioNormal || tipoAnalisis.Precio_Normal || 0
                        }
                        
                        analysisFormDialog.calculatedPrice = precio
                    }
                } catch (e) {
                    console.log("Error calculando precio:", e)
                    analysisFormDialog.calculatedPrice = 0.0
                }
            } else {
                analysisFormDialog.calculatedPrice = 0.0
            }
        }
            
        function loadEditData() {
            if (!isEditMode || !analysisFormDialog.analisisParaEditar) {
                console.log("No hay datos para cargar en edición")
                return
            }
            
            var analisis = analysisFormDialog.analisisParaEditar
            console.log("Cargando datos para edición")
            console.log("Análisis ID:", analisis.analisisId)
            
            // ✅ CRÍTICO: Guardar el ID del análisis PRIMERO
            var analisisIdNumerico = parseInt(analisis.analisisId) || -1
            if (analisisIdNumerico <= 0) {
                console.log("❌ Error: ID de análisis inválido:", analisis.analisisId)
                return
            }
            
            // Marcar como autocompletado inmediatamente ANTES de llenar campos
            campoBusquedaPaciente.pacienteAutocompletado = true
            campoBusquedaPaciente.pacienteNoEncontrado = false
            pacienteSeleccionado = true
            
            // ✅ NUEVO: Establecer paciente existente
            pacienteSeleccionadoId = analisis.pacienteId || -1
            esPacienteExistente = true
            
            try {
                // Cargar datos del paciente usando nuevo sistema
                console.log("Cargando datos del paciente...")
                
                // ✅ CORREGIR: Manejo correcto de cédula NULL
                var cedulaValue = analisis.pacienteCedula
                var tieneCedulaValida = false
                
                if (cedulaValue && 
                    cedulaValue !== "Sin cédula" && 
                    cedulaValue !== "NULL" && 
                    cedulaValue !== "None" &&
                    cedulaValue !== "null" &&
                    cedulaValue.toString().trim() !== "") {
                    
                    cedulaPaciente.text = cedulaValue.toString().trim()
                    campoBusquedaPaciente.text = cedulaValue.toString().trim()
                    tieneCedulaValida = true
                    console.log("📋 Cédula válida cargada:", cedulaValue)
                } else {
                    cedulaPaciente.text = ""
                    console.log("📋 Paciente sin cédula registrada (NULL/vacía)")
                    tieneCedulaValida = false
                }
                
                // Cargar nombres del paciente
                if (analisis.pacienteNombre) {
                    nombrePaciente.text = analisis.pacienteNombre || ""
                    apellidoPaterno.text = analisis.pacienteApellidoP || ""
                    apellidoMaterno.text = analisis.pacienteApellidoM || ""
                } else {
                    // Dividir nombre completo si no hay campos separados
                    var nombrePartes = (analisis.paciente || "").split(" ")
                    nombrePaciente.text = nombrePartes[0] || ""
                    apellidoPaterno.text = nombrePartes[1] || ""   
                    apellidoMaterno.text = nombrePartes.slice(2).join(" ") || ""
                }
                
                // ✅ CORREGIR: Establecer texto del campo de búsqueda
                if (!tieneCedulaValida) {
                    var nombreCompleto = (nombrePaciente.text + " " + 
                                        apellidoPaterno.text + " " + 
                                        apellidoMaterno.text).trim()
                    campoBusquedaPaciente.text = nombreCompleto
                }
                
                console.log("Datos del paciente cargados:", nombrePaciente.text, apellidoPaterno.text, apellidoMaterno.text, cedulaPaciente.text)
                
                // Cargar tipo de análisis
                if (analisis.tipoAnalisis) {
                    try {
                        var tiposData = JSON.parse(tiposAnalisis)
                        for (var i = 0; i < tiposData.length; i++) {
                            var nombre = tiposData[i].nombre || tiposData[i].Nombre || ""
                            if (nombre === analisis.tipoAnalisis) {
                                analisisCombo.currentIndex = i + 1
                                analysisFormDialog.selectedAnalysisIndex = i
                                break
                            }
                        }
                    } catch (e) {
                        console.log("Error cargando tipo análisis:", e)
                    }
                }
                
                // Cargar trabajador
                if (analisis.trabajadorAsignado && analisis.trabajadorAsignado !== "Sin asignar") {
                    try {
                        var trabajadoresData = JSON.parse(trabajadoresDisponibles)
                        for (var j = 0; j < trabajadoresData.length; j++) {
                            var trabajador = trabajadoresData[j]
                            var nombreTrabajador = trabajador.nombre_completo || trabajador.nombre || ""
                            if (nombreTrabajador === analisis.trabajadorAsignado) {
                                trabajadorCombo.currentIndex = j + 1
                                break
                            }
                        }
                    } catch (e) {
                        console.log("Error cargando trabajador:", e)
                    }
                }
                
                // Cargar tipo de servicio
                if (analisis.tipo === "Emergencia") {
                    emergenciaRadio.checked = true
                    normalRadio.checked = false
                    analysisFormDialog.analysisType = "Emergencia"
                } else {
                    normalRadio.checked = true
                    emergenciaRadio.checked = false
                    analysisFormDialog.analysisType = "Normal"
                }
                
                // Cargar detalles
                detallesAnalisis.text = analisis.detallesExamen || ""
                
                // Actualizar precio
                analysisFormDialog.updatePrice()
                
                console.log("✅ Datos de edición cargados correctamente")
            } catch (error) {
                console.log("❌ Error cargando datos para edicion:", error)
            }
        }
        
        onVisibleChanged: {
            if (visible) {
                if (isEditMode && analysisFormDialog.analisisParaEditar) {
                    loadEditData()
                } else if (!isEditMode) {
                    limpiarDatosPaciente()
                    analisisCombo.currentIndex = 0
                    trabajadorCombo.currentIndex = 0
                    normalRadio.checked = true
                    emergenciaRadio.checked = false
                    detallesAnalisis.text = ""
                    analysisFormDialog.selectedAnalysisIndex = -1
                    analysisFormDialog.calculatedPrice = 0.0
                    analysisFormDialog.analisisParaEditar = null
                    campoBusquedaPaciente.forceActiveFocus()
                }
            }
        }
        
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
                text: isEditMode ? "EDITAR ANÁLISIS" : "NUEVO ANÁLISIS"
                font.pixelSize: fontBaseSize * 1.2
                font.bold: true
                color: whiteColor
                font.family: "Segoe UI, Arial, sans-serif"
            }
            
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
                    limpiarYCerrarDialogo()
                }
            }
        }

        // MENSAJE INFORMATIVO EN EDICIÓN
        Rectangle {
            id: mensajeInformativo
            anchors.top: dialogHeader.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: baseUnit * 2
            height: isEditMode ? baseUnit * 4 : 0
            visible: isEditMode
            
            color: "#F9FAFB"
            border.color: "#E5E7EB"
            border.width: 1
            radius: baseUnit * 0.5
            
            Behavior on height {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
            
            Row {
                anchors.centerIn: parent
                spacing: baseUnit
                
                Text {
                    text: "i"
                    color: "#6B7280"
                    font.pixelSize: fontBaseSize
                    font.bold: true
                    font.family: "monospace"
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                Label {
                    text: "🔒 En modo edición solo se pueden modificar los datos del análisis, no del paciente"
                    color: "#4B5563"
                    font.pixelSize: fontBaseSize * 0.85
                    font.family: "Segoe UI, Arial, sans-serif"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        ScrollView {
            id: scrollView
            //anchors.top: dialogHeader.bottom 
            anchors.top: isEditMode ? mensajeInformativo.bottom : dialogHeader.bottom 
            anchors.topMargin: baseUnit * 2
            anchors.bottom: buttonRow.top
            anchors.bottomMargin: baseUnit * 2
            anchors.left: parent.left
            anchors.leftMargin: baseUnit * 3
            anchors.right: parent.right
            anchors.rightMargin: baseUnit * 3
            clip: true
            
            ColumnLayout {
                width: scrollView.width - (baseUnit * 1)
                spacing: baseUnit * 2
                
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
                    
                    ColumnLayout {
                        width: parent.width
                        spacing: baseUnit * 1.5
                        
                        // CAMPO DE BÚSQUEDA UNIFICADO - NUEVO SISTEMA
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit
                            
                            Label {
                                text: "Buscar Paciente:"
                                font.bold: true
                                color: textColor
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                            
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: baseUnit
                                
                                TextField {
                                    id: campoBusquedaPaciente
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: baseUnit * 4
                                    
                                    placeholderText: isEditMode ? "Paciente asignado a este análisis" : "Buscar por cédula o nombre del paciente..."
                                    readOnly: isEditMode
                                    enabled: !isEditMode
                                    
                                    property bool pacienteAutocompletado: false
                                    property bool pacienteNoEncontrado: false
                                    property string tipoDetectado: ""
                                    
                                    background: Rectangle {
                                        color: {
                                            if (isEditMode) return "#F8F9FA"
                                            if (campoBusquedaPaciente.pacienteAutocompletado) return "#F0F8FF"
                                            if (campoBusquedaPaciente.pacienteNoEncontrado) return "#FEF3C7"
                                            return whiteColor
                                        }
                                        border.color: {
                                            if (isEditMode) return "#D1D5DB"
                                            return campoBusquedaPaciente.activeFocus ? primaryColor : borderColor
                                        }
                                        border.width: campoBusquedaPaciente.activeFocus ? 2 : 1
                                        radius: baseUnit * 0.6
                                        
                                        // Indicador visual del tipo detectado
                                        Row {
                                            anchors.right: parent.right
                                            anchors.rightMargin: baseUnit
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: baseUnit * 0.5
                                            visible: !isEditMode
                                            
                                            Text {
                                                text: {
                                                    if (isEditMode) return "🔒"
                                                    if (campoBusquedaPaciente.pacienteAutocompletado) return "✅"
                                                    if (campoBusquedaPaciente.pacienteNoEncontrado) return "⚠️"
                                                    
                                                    if (campoBusquedaPaciente.tipoDetectado === "cedula") return "🆔"
                                                    if (campoBusquedaPaciente.tipoDetectado === "nombre") return "👤"
                                                    if (campoBusquedaPaciente.tipoDetectado === "mixto") return "🔍"
                                                    
                                                    return campoBusquedaPaciente.text.length > 0 ? "🔍" : ""
                                                }
                                                font.pixelSize: fontBaseSize * 1.1
                                                visible: campoBusquedaPaciente.text.length > 0 || isEditMode
                                            }
                                            
                                            Text {
                                                text: {
                                                    if (isEditMode) return "Solo lectura"
                                                    if (campoBusquedaPaciente.pacienteAutocompletado) return "Encontrado"
                                                    if (campoBusquedaPaciente.pacienteNoEncontrado) return "Nuevo"
                                                    if (campoBusquedaPaciente.tipoDetectado === "cedula") return "Cédula"
                                                    if (campoBusquedaPaciente.tipoDetectado === "nombre") return "Nombre"
                                                    if (campoBusquedaPaciente.tipoDetectado === "mixto") return "Mixto"
                                                    return ""
                                                }
                                                font.pixelSize: fontBaseSize * 0.7
                                                color: textColorLight
                                                visible: (campoBusquedaPaciente.text.length > 1 && text.length > 0) || isEditMode
                                            }
                                        }
                                    }
                                    
                                    onTextChanged: {
                                        // ✅ PROTECCIONES EN MODO EDICIÓN
                                        if (isEditMode) {
                                            console.log("Modo edición activo - no buscar")
                                            return
                                        }
                                        
                                        // ✅ PROTECCIÓN: No sobrescribir paciente ya seleccionado
                                        if (pacienteAutocompletado) {
                                            console.log("Campo autocompletado - no buscar")
                                            return
                                        }
                                        
                                        // ✅ NUEVO: Si hay un paciente existente seleccionado, NO buscar automáticamente
                                        if (esPacienteExistente && pacienteSeleccionadoId > 0) {
                                            console.log("Paciente existente seleccionado - no realizar búsqueda automática")
                                            return
                                        }
                                        
                                        // Limpiar estados de búsqueda (PERO NO RESETEAR PACIENTE SELECCIONADO)
                                        if (!pacienteAutocompletado) {
                                            pacienteNoEncontrado = false
                                            mostrarResultadosBusqueda = false
                                        }
                                        
                                        // Detectar tipo de búsqueda
                                        if (text.length >= 1) {
                                            tipoDetectado = laboratorioModel ? laboratorioModel.detectar_tipo_busqueda(text) : ""
                                        } else {
                                            tipoDetectado = ""
                                        }
                                        
                                        // Realizar búsqueda si hay suficientes caracteres
                                        if (text.length >= 2 && !pacienteAutocompletado) {
                                            buscarTimer.restart()
                                        } else if (text.length < 2) {
                                            limpiarResultadosBusqueda()
                                        }
                                        
                                        // ✅ MODIFICADO: Solo resetear si NO es un paciente existente Y se borra todo
                                        if (text.length === 0 && !isEditMode && !esPacienteExistente) {
                                            limpiarDatosPaciente()
                                        }
                                    }
                                    
                                    Keys.onReturnPressed: {
                                        if (!isEditMode && text.length >= 2) {
                                            buscarPacientesUnificado(text)
                                        }
                                    }
                                    
                                    Keys.onEscapePressed: {
                                        if (!isEditMode) {
                                            limpiarDatosPaciente()
                                        }
                                    }
                                    
                                    Keys.onDownPressed: {
                                        if (!isEditMode && mostrarResultadosBusqueda && resultadosBusquedaPacientesModel.count > 0) {
                                            listaResultadosPacientes.incrementCurrentIndex()
                                        }
                                    }
                                    
                                    Keys.onUpPressed: {
                                        if (!isEditMode && mostrarResultadosBusqueda && resultadosBusquedaPacientesModel.count > 0) {
                                            listaResultadosPacientes.decrementCurrentIndex()
                                        }
                                    }
                                }
                                
                                Button {
                                    text: "Limpiar"
                                    visible: !isEditMode && (campoBusquedaPaciente.pacienteAutocompletado || 
                                            esPacienteExistente ||
                                            nombrePaciente.text.length > 0 ||
                                            campoBusquedaPaciente.text.length > 0)

                                    Layout.preferredHeight: baseUnit * 3
                                    
                                    background: Rectangle {
                                        color: "#FEE2E2"
                                        border.color: "#F87171"
                                        border.width: 1
                                        radius: baseUnit * 0.5
                                    }
                                    
                                    contentItem: Label {
                                        text: parent.text
                                        color: "#B91C1C"
                                        font.pixelSize: fontBaseSize * 0.8
                                        font.family: "Segoe UI, Arial, sans-serif"
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    
                                    onClicked: forzarLimpiezaPaciente()
                                    
                                    HoverHandler {
                                        cursorShape: Qt.PointingHandCursor
                                    }
                                }
                                
                                Button {
                                    id: nuevoPacienteBtn
                                    text: "Nuevo Paciente"
                                    visible: !isEditMode && campoBusquedaPaciente.pacienteNoEncontrado && 
                                            campoBusquedaPaciente.text.length >= 2 &&
                                            !campoBusquedaPaciente.pacienteAutocompletado

                                    Layout.preferredHeight: baseUnit * 3
                                    
                                    background: Rectangle {
                                        color: nuevoPacienteBtn.pressed ? "#16A085" : 
                                            nuevoPacienteBtn.hovered ? "#1ABC9C" : "#2ECC71"
                                        border.color: "#27AE60"
                                        border.width: 1
                                        radius: baseUnit * 0.5
                                        
                                        Behavior on color {
                                            ColorAnimation { duration: 150 }
                                        }
                                    }
                                    
                                    contentItem: RowLayout {
                                        spacing: baseUnit * 0.5
                                        
                                        Text {
                                            text: "➕"
                                            color: whiteColor
                                            font.pixelSize: fontBaseSize * 0.8
                                        }
                                        
                                        Label {
                                            text: nuevoPacienteBtn.text
                                            color: whiteColor
                                            font.pixelSize: fontBaseSize * 0.8
                                            font.family: "Segoe UI, Arial, sans-serif"
                                            font.bold: true
                                        }
                                    }
                                    
                                    onClicked: {
                                        habilitarNuevoPaciente()
                                    }
                                    
                                    HoverHandler {
                                        cursorShape: Qt.PointingHandCursor
                                    }
                                    
                                    ToolTip {
                                        visible: nuevoPacienteBtn.hovered
                                        text: "Crear nuevo paciente: " + campoBusquedaPaciente.text
                                        delay: 500
                                        timeout: 3000
                                    }
                                }
                            }
                            
                            // Timer para búsqueda con delay
                            Timer {
                                id: buscarTimer
                                interval: 500
                                running: false
                                repeat: false
                                onTriggered: {
                                    var termino = campoBusquedaPaciente.text.trim()
                                    if (termino.length >= 2) {
                                        buscarPacientesUnificado(termino)
                                    }
                                }
                            }
                            
                            // PANEL DE RESULTADOS INTEGRADO
                            Rectangle {
                                id: panelResultadosPacientes
                                Layout.fillWidth: true
                                Layout.preferredHeight: mostrarResultadosBusqueda ? Math.min(230, resultadosBusquedaPacientesModel.count * 55 + 60) : 0
                                visible: mostrarResultadosBusqueda && !isEditMode
                                
                                color: whiteColor
                                border.color: primaryColor
                                border.width: 1
                                radius: baseUnit * 0.6
                                
                                Behavior on Layout.preferredHeight {
                                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                }
                                
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: baseUnit * 0.75
                                    spacing: baseUnit * 0.5
                                    
                                    // Header del panel
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: baseUnit
                                        
                                        Label {
                                            text: "👥"
                                            font.pixelSize: fontBaseSize * 0.9
                                        }
                                        
                                        Label {
                                            text: resultadosBusquedaPacientesModel.count + " pacientes encontrados"
                                            font.pixelSize: fontBaseSize * 0.85
                                            color: textColor
                                            font.bold: true
                                            Layout.fillWidth: true
                                        }
                                        
                                        Label {
                                            text: "Tipo: " + campoBusquedaPaciente.tipoDetectado
                                            font.pixelSize: fontBaseSize * 0.75
                                            color: primaryColor
                                            font.bold: true
                                        }
                                        
                                        Button {
                                            width: baseUnit * 2.5
                                            height: baseUnit * 2.5
                                            
                                            background: Rectangle {
                                                color: parent.hovered ? "#f0f0f0" : "transparent"
                                                radius: width / 2
                                            }
                                            
                                            contentItem: Text {
                                                text: "×"
                                                color: textColor
                                                font.pixelSize: fontBaseSize
                                                font.bold: true
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            
                                            onClicked: limpiarResultadosBusqueda()
                                        }
                                    }
                                    
                                    // Línea separadora
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 1
                                        color: borderColor
                                    }
                                    
                                    // Lista de resultados
                                    ScrollView {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        clip: true
                                        
                                        ListView {
                                            id: listaResultadosPacientes
                                            anchors.fill: parent
                                            model: resultadosBusquedaPacientesModel
                                            currentIndex: -1
                                            
                                            delegate: Rectangle {
                                                width: ListView.view ? ListView.view.width : 0
                                                height: 50
                                                color: {
                                                    if (mouseArea.containsMouse) return "#E3F2FD"
                                                    if (ListView.isCurrentItem) return "#BBDEFB"
                                                    return "transparent"
                                                }
                                                radius: baseUnit * 0.4
                                                
                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.margins: baseUnit * 0.75
                                                    spacing: baseUnit * 0.75
                                                    
                                                    // Indicador de tipo de coincidencia
                                                    Rectangle {
                                                        Layout.preferredWidth: baseUnit * 3.5
                                                        Layout.preferredHeight: baseUnit * 3.5
                                                        color: {
                                                            var tipo = model.tipo_coincidencia || ""
                                                            if (tipo.includes("cedula_exacta")) return successColor
                                                            if (tipo.includes("cedula")) return warningColor
                                                            if (tipo.includes("nombre")) return primaryColor
                                                            return lightGrayColor
                                                        }
                                                        radius: width / 2
                                                        
                                                        Label {
                                                            anchors.centerIn: parent
                                                            text: {
                                                                var tipo = model.tipo_coincidencia || ""
                                                                if (tipo.includes("cedula")) return "🆔"
                                                                if (tipo.includes("nombre")) return "👤"
                                                                return "?"
                                                            }
                                                            color: whiteColor
                                                            font.pixelSize: fontBaseSize * 0.7
                                                            font.bold: true
                                                        }
                                                    }
                                                    
                                                    // Información del paciente
                                                    ColumnLayout {
                                                        Layout.fillWidth: true
                                                        spacing: 1
                                                        
                                                        Label {
                                                            text: model.nombre_completo || "Sin nombre"
                                                            color: textColor
                                                            font.bold: true
                                                            font.pixelSize: fontBaseSize * 0.85
                                                            Layout.fillWidth: true
                                                            elide: Text.ElideRight
                                                        }
                                                        
                                                        Label {
                                                            text: "CI: " + (model.cedula || "Sin cédula")
                                                            color: textColorLight
                                                            font.pixelSize: fontBaseSize * 0.7
                                                        }
                                                    }
                                                    
                                                    // Botón seleccionar
                                                    Rectangle {
                                                        Layout.preferredWidth: baseUnit * 7
                                                        Layout.preferredHeight: baseUnit * 2.5
                                                        color: primaryColor
                                                        radius: baseUnit * 0.4
                                                        
                                                        Label {
                                                            anchors.centerIn: parent
                                                            text: "Seleccionar"
                                                            color: whiteColor
                                                            font.bold: true
                                                            font.pixelSize: fontBaseSize * 0.75
                                                        }
                                                        
                                                        MouseArea {
                                                            anchors.fill: parent
                                                            onClicked: {
                                                                seleccionarPacienteEncontrado(index)
                                                            }
                                                        }
                                                    }
                                                }
                                                
                                                MouseArea {
                                                    id: mouseArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    acceptedButtons: Qt.LeftButton
                                                    
                                                    onClicked: {
                                                        seleccionarPacienteEncontrado(index)
                                                    }
                                                    
                                                    onDoubleClicked: {
                                                        seleccionarPacienteEncontrado(index)
                                                    }
                                                }
                                            }
                                            
                                            // Estado vacío
                                            Label {
                                                anchors.centerIn: parent
                                                text: "No se encontraron pacientes"
                                                color: textColorLight
                                                font.pixelSize: fontBaseSize * 0.9
                                                visible: resultadosBusquedaPacientesModel.count === 0 && mostrarResultadosBusqueda
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Estado nuevo paciente
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: baseUnit * 3
                            visible: !isEditMode && campoBusquedaPaciente.pacienteNoEncontrado && 
                                    !campoBusquedaPaciente.pacienteAutocompletado
                            color: "#D1FAE5"
                            border.color: "#10B981"
                            border.width: 1
                            radius: baseUnit * 0.5
                            
                            RowLayout {
                                anchors.centerIn: parent
                                spacing: baseUnit
                                
                                Text {
                                    text: "✏️"
                                    font.pixelSize: fontBaseSize
                                }
                                
                                Label {
                                    text: "Modo: Crear nuevo paciente: " + campoBusquedaPaciente.text
                                    color: "#047857"
                                    font.pixelSize: fontBaseSize * 0.8
                                    font.bold: true
                                    font.family: "Segoe UI, Arial, sans-serif"
                                }
                            }
                        }
                        
                        // Campos de información del paciente
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: baseUnit * 2
                            rowSpacing: baseUnit * 1.5
                            
                            Label {
                                text: "Cédula:"
                                font.bold: true
                                color: textColor
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                            
                            TextField {
                                id: cedulaPaciente
                                Layout.fillWidth: true
                                placeholderText: "Cédula del paciente (puede estar vacía)"
                                readOnly: campoBusquedaPaciente.pacienteAutocompletado || isEditMode
                                font.pixelSize: fontBaseSize
                                font.family: "Segoe UI, Arial, sans-serif"
                                property bool esCampoNuevoPaciente: !campoBusquedaPaciente.pacienteAutocompletado && 
                                   campoBusquedaPaciente.pacienteNoEncontrado &&
                                   !isEditMode
                                background: Rectangle {
                                    color: campoBusquedaPaciente.pacienteAutocompletado ? "#F8F9FA" : whiteColor
                                    border.color: borderColor
                                    border.width: 1
                                    radius: baseUnit * 0.6
                                }
                                padding: baseUnit
                            }
                            
                            Label {
                                text: "Nombre:"
                                font.bold: true
                                color: textColor
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                            
                            TextField {
                                id: nombrePaciente
                                Layout.fillWidth: true
                                placeholderText: campoBusquedaPaciente.pacienteAutocompletado ? 
                                            "Nombre del paciente" : "Ingrese nombre del paciente"
                                readOnly: campoBusquedaPaciente.pacienteAutocompletado || isEditMode
                                font.pixelSize: fontBaseSize
                                font.family: "Segoe UI, Arial, sans-serif"
                                property bool esCampoNuevoPaciente: !campoBusquedaPaciente.pacienteAutocompletado && 
                                   campoBusquedaPaciente.pacienteNoEncontrado &&
                                   !isEditMode
                                background: Rectangle {
                                    color: {
                                        if (campoBusquedaPaciente.pacienteAutocompletado) return "#F8F9FA"
                                        if (nombrePaciente.esCampoNuevoPaciente) return "#E8F5E8"
                                        return whiteColor
                                    }
                                    border.color: {
                                        if (nombrePaciente.esCampoNuevoPaciente && nombrePaciente.activeFocus) return "#2ECC71"
                                        if (nombrePaciente.esCampoNuevoPaciente) return "#27AE60"
                                        return borderColor
                                    }
                                    border.width: nombrePaciente.esCampoNuevoPaciente ? 2 : 1
                                    radius: baseUnit * 0.6
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
                                placeholderText: campoBusquedaPaciente.pacienteAutocompletado ? 
                                                "Apellido paterno" : "Ingrese apellido paterno"
                                readOnly: campoBusquedaPaciente.pacienteAutocompletado || isEditMode
                                font.pixelSize: fontBaseSize
                                font.family: "Segoe UI, Arial, sans-serif"
                                
                                property bool esCampoNuevoPaciente: !campoBusquedaPaciente.pacienteAutocompletado && 
                                   campoBusquedaPaciente.pacienteNoEncontrado &&
                                   !isEditMode
                                
                                background: Rectangle {
                                    color: {
                                        if (campoBusquedaPaciente.pacienteAutocompletado) return "#F8F9FA"
                                        if (apellidoPaterno.esCampoNuevoPaciente) return "#E8F5E8"
                                        return whiteColor
                                    }
                                    border.color: {
                                        if (apellidoPaterno.esCampoNuevoPaciente && apellidoPaterno.activeFocus) return "#2ECC71"
                                        if (apellidoPaterno.esCampoNuevoPaciente) return "#27AE60"
                                        return borderColor
                                    }
                                    border.width: apellidoPaterno.esCampoNuevoPaciente ? 2 : 1
                                    radius: baseUnit * 0.6
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
                                placeholderText: campoBusquedaPaciente.pacienteAutocompletado ? 
                                                "Apellido materno" : "Ingrese apellido materno (opcional)"
                                readOnly: campoBusquedaPaciente.pacienteAutocompletado || isEditMode
                                font.pixelSize: fontBaseSize
                                font.family: "Segoe UI, Arial, sans-serif"
                                
                                property bool esCampoNuevoPaciente: !campoBusquedaPaciente.pacienteAutocompletado && 
                                    campoBusquedaPaciente.pacienteNoEncontrado &&
                                    !isEditMode
                                
                                background: Rectangle {
                                    color: {
                                        if (campoBusquedaPaciente.pacienteAutocompletado) return "#F8F9FA"
                                        if (apellidoMaterno.esCampoNuevoPaciente) return "#E8F5E8"
                                        return whiteColor
                                    }
                                    border.color: {
                                        if (apellidoMaterno.esCampoNuevoPaciente && apellidoMaterno.activeFocus) return "#2ECC71"
                                        if (apellidoMaterno.esCampoNuevoPaciente) return "#27AE60"
                                        return borderColor
                                    }
                                    border.width: apellidoMaterno.esCampoNuevoPaciente ? 2 : 1
                                    radius: baseUnit * 0.6
                                }
                                padding: baseUnit
                            }
                        }
                    }
                }
                
                // RESTO DE GROUPBOXES - SIN CAMBIOS
                GroupBox {
                    Layout.fillWidth: true
                    title: "INFORMACIÓN DEL ANÁLISIS"
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
                        
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit * 2
                            
                            Label {
                                text: "Tipo de Análisis:"
                                font.bold: true
                                Layout.preferredWidth: baseUnit * 15
                                color: textColor
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                            
                            ComboBox {
                                id: analisisCombo
                                Layout.fillWidth: true
                                font.pixelSize: fontBaseSize
                                font.family: "Segoe UI, Arial, sans-serif"
                                model: {
                                    var list = ["Seleccionar tipo de análisis..."]
                                    try {
                                        var tiposData = JSON.parse(tiposAnalisis)
                                        for (var i = 0; i < tiposData.length; i++) {
                                            var nombre = tiposData[i].nombre || tiposData[i].Nombre || ""
                                            if (nombre) {
                                                list.push(nombre)
                                            }
                                        }
                                    } catch (e) {
                                        console.log("Error parseando tipos análisis:", e)
                                    }
                                    return list
                                }
                                
                                onCurrentIndexChanged: {
                                    if (currentIndex > 0) {
                                        try {
                                            if (currentIndex - 1 < JSON.parse(tiposAnalisis).length) {
                                                analysisFormDialog.selectedAnalysisIndex = currentIndex - 1
                                            }
                                        } catch (e) {
                                            console.log("Error en cambio de análisis:", e)
                                        }
                                    } else {
                                        analysisFormDialog.selectedAnalysisIndex = -1
                                    }
                                    analysisFormDialog.updatePrice()
                                }
                                
                                contentItem: Label {
                                    text: analisisCombo.displayText
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
                            }
                        }
                        
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit * 2
                            
                            Label {
                                text: "Trabajador Asignado:"
                                font.bold: true
                                Layout.preferredWidth: baseUnit * 15
                                color: textColor
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                            
                            ComboBox {
                                id: trabajadorCombo
                                Layout.fillWidth: true
                                font.pixelSize: fontBaseSize
                                font.family: "Segoe UI, Arial, sans-serif"
                                model: {
                                    var modelData = ["Seleccionar trabajador..."]
                                    try {
                                        var trabajadoresData = JSON.parse(trabajadoresDisponibles)
                                        for (var i = 0; i < trabajadoresData.length; i++) {
                                            var trabajador = trabajadoresData[i]
                                            var nombre = trabajador.nombre_completo || trabajador.nombre || ""
                                            if (nombre) {
                                                modelData.push(nombre)
                                            }
                                        }
                                    } catch (e) {
                                        console.log("Error parseando trabajadores:", e)
                                    }
                                    modelData.push("Sin asignar")
                                    return modelData
                                }
                                
                                contentItem: Label {
                                    text: trabajadorCombo.displayText
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
                            }
                        }
                        
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit * 2
                            
                            Label {
                                text: "Tipo de Servicio:"
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
                                            analysisFormDialog.analysisType = "Normal"
                                            analysisFormDialog.updatePrice()
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
                                            analysisFormDialog.analysisType = "Emergencia"
                                            analysisFormDialog.updatePrice()
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
                            text: "Precio del Análisis:"
                            font.bold: true
                            color: textColor
                            font.family: "Segoe UI, Arial, sans-serif"
                        }
                        
                        Label {
                            text: analysisFormDialog.selectedAnalysisIndex >= 0 ? 
                                "Bs " + analysisFormDialog.calculatedPrice.toFixed(2) : "Seleccione tipo de análisis"
                            font.bold: true
                            font.pixelSize: fontBaseSize * 1.1
                            font.family: "Segoe UI, Arial, sans-serif"
                            color: analysisFormDialog.analysisType === "Emergencia" ? "#92400E" : "#047857"
                            padding: baseUnit
                            background: Rectangle {
                                color: analysisFormDialog.analysisType === "Emergencia" ? warningColorLight : successColorLight
                                radius: baseUnit * 0.8
                            }
                        }
                    }
                }
                
                GroupBox {
                    Layout.fillWidth: true
                    title: "DETALLES DEL ANÁLISIS"
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
                        id: detallesAnalisis
                        Layout.fillWidth: true
                        Layout.preferredHeight: baseUnit * 12
                        placeholderText: "Descripción adicional del análisis, instrucciones especiales..."
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
                    limpiarYCerrarDialogo()
                }
            }
            
            Button {
                text: isEditMode ? "Actualizar" : "Guardar"
                enabled: {
                    var tieneAnalisis = analysisFormDialog.selectedAnalysisIndex >= 0
                    var tieneNombre = nombrePaciente.text.length >= 2
                    var tieneTrabajador = trabajadorCombo.currentIndex > 0
                    
                    var validacionPaciente
                    var apellidoPValido = apellidoPaterno.text.length >= 2
                    validacionPaciente = tieneNombre && apellidoPValido
                    
                    return tieneAnalisis && tieneTrabajador && validacionPaciente && laboratorioRoot.formEnabled
                }
                Layout.preferredHeight: baseUnit * 4
                
                background: Rectangle {
                    color: {
                        if (!parent.enabled) return "#bdc3c7"
                        if (!laboratorioRoot.formEnabled) return "#95a5a6"
                        return primaryColor
                    }
                    radius: baseUnit
                }
                
                contentItem: Label {
                    text: !laboratorioRoot.formEnabled ? "Guardando..." : parent.text
                    color: whiteColor
                    font.bold: true
                    font.pixelSize: fontBaseSize * 0.9
                    font.family: "Segoe UI, Arial, sans-serif"
                    horizontalAlignment: Text.AlignHCenter
                }
                
                onClicked: {
                    if (laboratorioRoot.formEnabled) {
                        guardarAnalisis()
                    }
                }
            }
        }
    }

    // DIÁLOGO DE CONFIRMACIÓN DE ELIMINACIÓN
    Dialog {
        id: confirmDeleteDialogAnalisis
        anchors.centerIn: laboratorioRoot
        width: Math.min(laboratorioRoot.width * 0.9, 480)
        height: Math.min(laboratorioRoot.height * 0.55, 320)
        modal: true
        closePolicy: Popup.NoAutoClose
        visible: showConfirmDeleteDialog
        z: 1001
        
        title: ""
        
        background: Rectangle {
            color: whiteColor
            radius: baseUnit * 0.8
            border.color: "#e0e0e0"
            border.width: 1
            
            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                color: "transparent"
                radius: parent.radius + 3
                border.color: "#30000000"
                border.width: 3
                z: -1
            }
        }
        
        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 75
                color: "#fff5f5"
                radius: baseUnit * 0.8
                
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: baseUnit * 0.8
                    color: parent.color
                }
                
                RowLayout {
                    anchors.centerIn: parent
                    spacing: baseUnit * 2
                    
                    Rectangle {
                        Layout.preferredWidth: 45
                        Layout.preferredHeight: 45
                        color: "#fee2e2"
                        radius: 22
                        border.color: "#fecaca"
                        border.width: 2
                        
                        Label {
                            anchors.centerIn: parent
                            text: "⚠️"
                            font.pixelSize: fontBaseSize * 1.8
                        }
                    }
                    
                    ColumnLayout {
                        spacing: baseUnit * 0.25
                        
                        Label {
                            text: "Confirmar Eliminación"
                            font.pixelSize: fontBaseSize * 1.3
                            font.bold: true
                            color: "#dc2626"
                            Layout.alignment: Qt.AlignLeft
                        }
                        
                        Label {
                            text: "Acción irreversible"
                            font.pixelSize: fontBaseSize * 0.9
                            color: "#7f8c8d"
                            Layout.alignment: Qt.AlignLeft
                        }
                    }
                }
            }
            
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "transparent"
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: baseUnit * 2
                    spacing: baseUnit
                    
                    Item { Layout.preferredHeight: baseUnit * 0.5 }
                    
                    Label {
                        text: "¿Estás seguro de eliminar este análisis?"
                        font.pixelSize: fontBaseSize * 1.1
                        font.bold: true
                        color: textColor
                        Layout.alignment: Qt.AlignHCenter
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        font.family: "Segoe UI, Arial, sans-serif"
                    }
                    
                    Label {
                        text: "Esta acción no se puede deshacer y el registro del análisis se eliminará permanentemente."
                        font.pixelSize: fontBaseSize
                        color: "#6b7280"
                        Layout.alignment: Qt.AlignHCenter
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        Layout.maximumWidth: parent.width - baseUnit * 4
                        font.family: "Segoe UI, Arial, sans-serif"
                    }
                    
                    Item { Layout.fillHeight: true }
                    
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: baseUnit * 3
                        Layout.bottomMargin: baseUnit
                        Layout.topMargin: baseUnit
                        
                        Button {
                            Layout.preferredWidth: 130
                            Layout.preferredHeight: 45
                            
                            background: Rectangle {
                                color: parent.pressed ? "#e5e7eb" : 
                                    (parent.hovered ? "#f3f4f6" : "#f9fafb")
                                radius: baseUnit * 0.6
                                border.color: "#d1d5db"
                                border.width: 1
                                
                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                            
                            contentItem: RowLayout {
                                spacing: baseUnit * 0.5
                                
                                Label {
                                    text: "✕"
                                    color: "#6b7280"
                                    font.pixelSize: fontBaseSize * 0.9
                                    Layout.alignment: Qt.AlignVCenter
                                }
                                
                                Label {
                                    text: "Cancelar"
                                    color: "#374151"
                                    font.bold: true
                                    font.pixelSize: fontBaseSize
                                    Layout.alignment: Qt.AlignVCenter
                                    font.family: "Segoe UI, Arial, sans-serif"
                                }
                            }
                            
                            onClicked: {
                                showConfirmDeleteDialog = false
                                analisisIdToDelete = ""
                            }
                            
                            HoverHandler {
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                        
                        Button {
                            Layout.preferredWidth: 130
                            Layout.preferredHeight: 45
                            
                            background: Rectangle {
                                color: parent.pressed ? "#dc2626" : 
                                    (parent.hovered ? "#ef4444" : "#f87171")
                                radius: baseUnit * 0.6
                                border.width: 0
                                
                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                            
                            contentItem: RowLayout {
                                spacing: baseUnit * 0.5
                                
                                Label {
                                    text: "🗑️"
                                    color: whiteColor
                                    font.pixelSize: fontBaseSize * 0.9
                                    Layout.alignment: Qt.AlignVCenter
                                }
                                
                                Label {
                                    text: "Eliminar"
                                    color: whiteColor
                                    font.bold: true
                                    font.pixelSize: fontBaseSize
                                    Layout.alignment: Qt.AlignVCenter
                                    font.family: "Segoe UI, Arial, sans-serif"
                                }
                            }
                            
                            onClicked: {
                                console.log("🗑️ Confirmando eliminación de análisis...")
                                
                                var analisisId = parseInt(analisisIdToDelete)
                                
                                // Llamar directamente al modelo para eliminar
                                var exito = laboratorioModel.eliminarExamen(analisisId)
                                
                                if (exito) {
                                    selectedRowIndex = -1
                                    updatePaginatedModel()
                                    console.log("✅ Análisis eliminado correctamente ID:", analisisId)
                                    mostrarNotificacion("Éxito", "Análisis eliminado correctamente")
                                } else {
                                    console.log("❌ Error eliminando análisis ID:", analisisId)
                                    mostrarNotificacion("Error", "No se pudo eliminar el análisis")
                                }
                                
                                showConfirmDeleteDialog = false
                                analisisIdToDelete = ""
                            }
                            
                            HoverHandler {
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }
                }
            }
        }
    }


    // ✅ FUNCIONES JAVASCRIPT CORREGIDAS

    function aplicarFiltros() {
        //console.log("🔍 Aplicando filtros...")
        
        if (!laboratorioModel) {
            console.log("❌ LaboratorioModel no disponible")
            return
        }

        var filtros = construirFiltrosActuales()
        console.log("🔍 Filtros construidos:", JSON.stringify(filtros))
        
        if (laboratorioModel.itemsPerPageProperty !== 6) {
            laboratorioModel.itemsPerPageProperty = 6
        }

        laboratorioModel.aplicar_filtros_y_recargar(
            filtros.search_term || "",
            filtros.tipo_analisis || "",
            filtros.tipo_servicio || "",
            filtros.fecha_desde || "",
            filtros.fecha_hasta || ""
        )
    }
    
    function updatePaginatedModel() {
        if (!laboratorioModel) {
            console.log("LaboratorioModel no disponible")
            return
        }
        
        // Limpiar modelo actual
        analisisPaginadosModel.clear()
        
        // Obtener datos actuales del modelo
        try {
            var examenes = laboratorioModel.examenes_paginados
            
            if (examenes && examenes.length > 0) {
                for (var i = 0; i < examenes.length; i++) {
                    var examen = examenes[i]
                    analisisPaginadosModel.append({
                        analisisId: examen.analisisId || "N/A",
                        paciente: examen.paciente || "Sin nombre",
                        pacienteCedula: examen.pacienteCedula || "Sin cédula",
                        tipoAnalisis: examen.tipoAnalisis || "Análisis General",
                        tipo: examen.tipo || "Normal",
                        precio: examen.precio || "0.00",
                        trabajadorAsignado: examen.trabajadorAsignado || "Sin asignar",
                        registradoPor: examen.registradoPor || "Sistema",
                        fecha: examen.fecha || "Sin fecha",
                        // Agregar detalles del examen
                        detallesExamen: examen.detallesExamen || examen.detalles || "",
                        // ✅ AGREGAR CAMPOS PARA EDICIÓN
                        pacienteNombre: examen.pacienteNombre || "",
                        pacienteApellidoP: examen.pacienteApellidoP || "",
                        pacienteApellidoM: examen.pacienteApellidoM || ""
                    })
                }
            } else {
                console.log("No hay exámenes disponibles")
            }
        } catch (error) {
            console.log("❌ Error actualizando modelo:", error)
        }
        
    }

    function editarAnalisis(viewIndex, analisisId) {
        try {
            console.log("📝 Iniciando edición de análisis ID:", analisisId, "Índice:", viewIndex)
            
            // ✅ VERIFICAR PERMISOS
            if (!laboratorioRoot.esAdministrador && !laboratorioRoot.esMedico) {
                mostrarNotificacion("Error", "No tiene permisos para editar análisis")
                return
            }
            
            // Buscar análisis en el modelo actual
            var analisisData = null
            for (var i = 0; i < analisisPaginadosModel.count; i++) {
                var modelItem = analisisPaginadosModel.get(i)
                if (parseInt(modelItem.analisisId) === parseInt(analisisId)) {
                    analisisData = modelItem
                    break
                }
            }
            
            if (!analisisData) {
                console.error("❌ Análisis no encontrado:", analisisId)
                mostrarNotificacion("Error", "Análisis no encontrado")
                return
            }
            
            // Configurar modo edición
            isEditMode = true
            editingIndex = viewIndex
            
            // ✅ CARGAR DATOS AL DIÁLOGO CORRECTAMENTE
            analysisFormDialog.analisisParaEditar = {
                analisisId: analisisData.analisisId,              // ✅ CRÍTICO: Incluir ID
                pacienteId: analisisData.pacienteId || -1,        // ✅ NUEVO: Incluir paciente ID
                pacienteCedula: analisisData.pacienteCedula,
                pacienteNombre: analisisData.pacienteNombre,
                pacienteApellidoP: analisisData.pacienteApellidoP, 
                pacienteApellidoM: analisisData.pacienteApellidoM,
                paciente: analisisData.paciente,                  // Nombre completo como respaldo
                tipoAnalisis: analisisData.tipoAnalisis,
                tipo: analisisData.tipo,
                trabajadorAsignado: analisisData.trabajadorAsignado,
                detallesExamen: analisisData.detallesExamen,
                fecha: analisisData.fecha
            }
            
            // Mostrar diálogo
            showNewAnalysisDialog = true
            
            console.log("✅ Modo edición configurado correctamente")
            
        } catch (error) {
            console.error("❌ Error editando análisis:", error.message)
            mostrarNotificacion("Error", "Error cargando datos para edición")
        }
    }

    // ✅ FUNCIÓN DE GUARDAR MEJORADA CON MEJOR MANEJO DE ERRORES
    function guardarAnalisis() {
        try {
            console.log("🎯 Iniciando guardado - Modo:", isEditMode ? "EDITAR" : "CREAR")
            
            // Desactivar formulario mientras se procesa
            laboratorioRoot.formEnabled = false
            
            if (isEditMode && editingIndex >= 0) {
                actualizarAnalisis()
            } else {
                crearNuevoAnalisis()
            }
            
        } catch (error) {
            console.log("❌ Error en coordinador de guardado:", error.message)
            laboratorioRoot.formEnabled = true
            mostrarNotificacion("Error", "Error procesando solicitud: " + error.message)
        }
    }

    function crearNuevoAnalisis() {
        try {
            console.log("🧪 === INICIANDO CREACIÓN DE NUEVO ANÁLISIS ===")
            
            // Validar formulario
            if (!validarFormularioAnalisis()) {
                return
            }
            
            // 1. Gestionar paciente (buscar o crear)
            var pacienteId = buscarOCrearPaciente()
            if (pacienteId <= 0) {
                throw new Error("Error gestionando datos del paciente")
            }
            
            // 2. Obtener datos del formulario
            var datosAnalisis = obtenerDatosFormulario()
            
            // 3. Crear examen en el backend
            console.log("🔬 Creando examen con parámetros:")
            console.log("   - Paciente ID:", pacienteId)
            console.log("   - Tipo análisis ID:", datosAnalisis.tipoAnalisisId)  
            console.log("   - Tipo servicio:", datosAnalisis.tipoServicio)
            console.log("   - Trabajador ID:", datosAnalisis.trabajadorId)
            console.log("   - Detalles:", datosAnalisis.detalles)
            
            var resultado = laboratorioModel.crearExamen(
                pacienteId,
                datosAnalisis.tipoAnalisisId,
                datosAnalisis.tipoServicio,
                datosAnalisis.trabajadorId,
                datosAnalisis.detalles
            )
            
            // 4. Procesar resultado
            procesarResultadoCreacion(resultado)
            
        } catch (error) {
            console.log("❌ Error creando análisis:", error.message)
            laboratorioRoot.formEnabled = true
            mostrarNotificacion("Error", error.message)
        }
    }

    function actualizarAnalisis() {
        try {
            console.log("📝 === INICIANDO ACTUALIZACIÓN DE ANÁLISIS ===")
            
            // Validar formulario
            if (!validarFormularioAnalisis()) {
                return
            }
            
            // ✅ CRÍTICO: Obtener el ID correcto del análisis
            var analisisId = null
            
            if (analysisFormDialog.analisisParaEditar && analysisFormDialog.analisisParaEditar.analisisId) {
                analisisId = parseInt(analysisFormDialog.analisisParaEditar.analisisId)
            }
            
            if (!analisisId || analisisId <= 0) {
                throw new Error("No se pudo obtener el ID del análisis para actualizar")
            }
            
            console.log("📝 Actualizando análisis ID:", analisisId)
            
            // Obtener datos del formulario
            var datosAnalisis = obtenerDatosFormulario()
            
            console.log("📝 Datos a actualizar:")
            console.log("   - Tipo análisis ID:", datosAnalisis.tipoAnalisisId)  
            console.log("   - Tipo servicio:", datosAnalisis.tipoServicio)
            console.log("   - Trabajador ID:", datosAnalisis.trabajadorId)
            console.log("   - Detalles:", datosAnalisis.detalles)
            
            // ✅ CORREGIR: Llamar al backend con parámetros correctos
            var resultado = laboratorioModel.actualizarExamen(
                analisisId,                    // ID del examen
                datosAnalisis.tipoAnalisisId,  // Tipo de análisis
                datosAnalisis.tipoServicio,    // Tipo de servicio
                datosAnalisis.trabajadorId,    // ID del trabajador
                datosAnalisis.detalles         // Detalles
            )
            
            console.log("📝 Resultado del backend:", typeof resultado === "string" ? resultado : JSON.stringify(resultado))
            
            // Procesar resultado
            procesarResultadoActualizacion(resultado)
            
        } catch (error) {
            console.log("❌ Error actualizando análisis:", error.message)
            laboratorioRoot.formEnabled = true
            mostrarNotificacion("Error", error.message)
        }
    }
    
    function limpiarYCerrarDialogo() {
        console.log("🚪 Cerrando diálogo de análisis...")

        showNewAnalysisDialog = false
        
        // Limpiar datos del paciente usando nueva función
        limpiarDatosPaciente()
        
        // Limpiar campos de análisis
        detallesAnalisis.text = ""
        if (analisisCombo) analisisCombo.currentIndex = 0
        
        // Resetear radio buttons
        if (normalRadio) normalRadio.checked = true
        if (emergenciaRadio) emergenciaRadio.checked = false
        if (trabajadorCombo) trabajadorCombo.currentIndex = 0
        
        // Resetear propiedades del formulario
        analysisFormDialog.selectedAnalysisIndex = -1
        analysisFormDialog.calculatedPrice = 0.0
        analysisFormDialog.analysisType = "Normal"
        analysisFormDialog.analisisParaEditar = null         
        
        // Resetear estados de la interfaz
        selectedRowIndex = -1
        isEditMode = false
        editingIndex = -1

        // ✅ RESETEAR NUEVOS CAMPOS
        pacienteSeleccionadoId = -1
        esPacienteExistente = false
        
        console.log("✅ Diálogo cerrado y formulario reseteado")
    }
    
    function initializarModelo() {
        
        if (!laboratorioModel) {
            console.log("❌ Error: laboratorioModel es null")
            return
        }
        
        try {
            // Configurar elementos por página según tamaño de pantalla
            // Aqui paginado
            var elementosPorPagina = 8
            //console.log("📊 Configurando elementos por página:", elementosPorPagina)
            
            // Establecer tamaño de página
            if (laboratorioModel.itemsPerPageProperty !== elementosPorPagina) {
                laboratorioModel.itemsPerPageProperty = elementosPorPagina
            }
            
            // Cargar datos iniciales del backend
            laboratorioModel.cargarTiposAnalisis()
            laboratorioModel.cargarTrabajadores()
            
            // Limpiar filtros al inicializar
            if (filtroFecha) filtroFecha.currentIndex = 0
            if (filtroAnalisis) filtroAnalisis.currentIndex = 0  
            if (filtroTipo) filtroTipo.currentIndex = 0
            if (campoBusqueda) campoBusqueda.text = ""
            
            // Pequeño delay para asegurar que los datos estén cargados
            initTimer.start()
            
        } catch (error) {
            console.log("❌ Error inicializando modelo:", error)
        }
    }

    function irAPaginaAnterior() {
        if (laboratorioModel && currentPageLaboratorio > 0) {
            console.log("⬅️ Navegando a página anterior:", currentPageLaboratorio - 1)
            
            // ✅ USAR LA MISMA LÓGICA DE FILTROS
            var filtros = construirFiltrosActuales()
            
            laboratorioModel.obtener_examenes_paginados(currentPageLaboratorio - 1, 8, filtros)
        }
    }

    function irAPaginaSiguiente() {
        if (laboratorioModel && currentPageLaboratorio < (totalPagesLaboratorio - 1)) {
            console.log("➡️ Navegando a página siguiente:", currentPageLaboratorio + 1)
            
            // ✅ USAR LA MISMA LÓGICA DE FILTROS
            var filtros = construirFiltrosActuales()
            
            laboratorioModel.obtener_examenes_paginados(currentPageLaboratorio + 1, 8, filtros)
        }
    }
    
    function updateAnalisisCombo() {
        if (filtroAnalisis && laboratorioModel) {
            try {
                var tiposData = laboratorioModel.tipos_analisis
                var newModelData = ["Todos"] // Siempre empezar con "Todos"
                
                // Mapear nombres y IDs para mantener consistencia
                var analysisMap = []
                for (var i = 0; i < tiposData.length; i++) {
                    var nombre = tiposData[i].nombre || tiposData[i].Nombre || ""
                    var id = tiposData[i].id || tiposData[i].ID || i
                    if (nombre && nombre !== "Todos") {
                        newModelData.push(nombre)
                        analysisMap.push({id: id, nombre: nombre})
                    }
                }
                
                // Almacenar el mapa para referencia futura
                laboratorioRoot.analysisMap = analysisMap
                
                // Solo actualizar si el modelo ha cambiado
                var currentModel = filtroAnalisis.model || []
                var shouldUpdate = currentModel.length !== newModelData.length
                
                if (!shouldUpdate) {
                    for (var j = 0; j < currentModel.length; j++) {
                        if (currentModel[j] !== newModelData[j]) {
                            shouldUpdate = true
                            break
                        }
                    }
                }
                
                if (shouldUpdate) {
                    var currentIndex = filtroAnalisis.currentIndex
                    var currentText = filtroAnalisis.currentText
                    
                    filtroAnalisis.model = newModelData
                    
                    // Restaurar la selección si es posible
                    var newIndex = newModelData.indexOf(currentText)
                    if (newIndex >= 0) {
                        filtroAnalisis.currentIndex = newIndex
                    } else {
                        filtroAnalisis.currentIndex = 0
                    }
                    
                    console.log("🔍 Combo análisis actualizado. Elementos:", newModelData.length, 
                            "Selección:", filtroAnalisis.currentIndex, filtroAnalisis.currentText)
                }
            } catch (e) {
                console.log("❌ Error actualizando combo análisis:", e)
            }
        }
    }

    function limpiarFiltros() {
        console.log("🧹 Limpiando todos los filtros")
        
        // Reiniciar filtro de fecha
        if (filtroFecha) {
            filtroFecha.currentIndex = 0
        }
        
        // Reiniciar filtro de análisis
        if (filtroAnalisis) {
            filtroAnalisis.currentIndex = 0
        }
        
        // Reiniciar filtro de tipo
        if (filtroTipo) {
            filtroTipo.currentIndex = 0
        }
        
        // Limpiar campo de búsqueda
        if (campoBusqueda) {
            campoBusqueda.text = ""
        }
        
        // Aplicar filtros vacíos
        aplicarFiltros()
    }

    // ✅ FUNCIONES DE VALIDACIÓN Y DATOS CORREGIDAS
    
    function validarFormularioAnalisis() {
        console.log("✅ Validando formulario...")
        
        if (analysisFormDialog.selectedAnalysisIndex < 0) {
            mostrarNotificacion("Error", "Debe seleccionar un tipo de análisis")
            return false
        }
        
        if (nombrePaciente.text.length < 2) {
            mostrarNotificacion("Error", "Nombre del paciente es obligatorio")
            return false
        }

        if (apellidoPaterno.text.length < 2) {
            mostrarNotificacion("Error", "Apellido paterno es obligatorio")
            return false
        }

        if (detallesAnalisis.text.length > 500) {
            mostrarNotificacion("Error", "Detalles del análisis no puede exceder 500 caracteres")
            return false
        }

        // Validación específica para nuevos pacientes
        if (campoBusquedaPaciente.pacienteNoEncontrado) {
            var cedula = cedulaPaciente.text.trim()
            var tipoDetectado = campoBusquedaPaciente.tipoDetectado
            
            // Si el tipo detectado era cédula, debe tener cédula válida
            if (tipoDetectado === "cedula" && (!cedula || cedula.length < 6)) {
                mostrarNotificacion("Error", "Debe ingresar una cédula válida")
                return false
            }
        }
        
        console.log("✅ Formulario válido")
        return true
    }
   
    function verificarYCorregirDatos() {
        if (!isEditMode) return
        
        console.log("🔍 Verificando datos cargados...")
        
        // Verificar paciente
        if (!campoBusquedaPaciente.pacienteAutocompletado) {
            console.log("⚠️ Paciente no autocompletado, reintentando...")
            loadEditData()
        }
        
        // Verificar especialidad
        if (consultationFormDialog.selectedEspecialidadIndex < 0) {
            console.log("⚠️ Especialidad no seleccionada, reintentando...")
            reintentarCargaEspecialidad()
        }
        
        console.log("✅ Verificación completada")
    }
    function verificarPermisosAnalisis(analisisId) {
        try {
            if (!laboratorioModel || !analisisId) {
                return {
                    puede_editar: false,
                    puede_eliminar: false,
                    razon_editar: "Datos insuficientes"
                }
            }
            
            var permisos = laboratorioModel.verificar_permisos_analisis(parseInt(analisisId))
            
            
            return permisos
            
        } catch (error) {
            console.log("❌ Error verificando permisos:", error.message)
            return {
                puede_editar: false,
                puede_eliminar: false,
                razon_editar: "Error verificando permisos"
            }
        }
    }
    

    function obtenerMensajePermiso(analisisId) {
        var permisos = verificarPermisosAnalisis(analisisId)
        
        if (permisos.es_administrador) {
            return "Administrador: Acceso completo"
        }
        
        if (permisos.es_medico) {
            if (permisos.dias_antiguedad > 30) {
                return `Solo puede eliminar consultas de máximo 30 días (esta tiene ${permisos.dias_antiguedad} días)`
            }
            return "Médico: Puede editar siempre, eliminar si es reciente"
        }
        
        return "Sin permisos para esta operación"
    }

    function obtenerDatosFormulario() {
        try {
            // Validar tipos de análisis
            if (!tiposAnalisis || tiposAnalisis === "[]") {
                throw new Error("No hay tipos de análisis disponibles")
            }
            
            var tiposData = JSON.parse(tiposAnalisis)
            if (!tiposData || tiposData.length === 0) {
                throw new Error("Lista de tipos de análisis está vacía")
            }
            
            if (analysisFormDialog.selectedAnalysisIndex >= tiposData.length) {
                throw new Error("Índice de análisis fuera de rango")
            }
            
            var tipoAnalisisSeleccionado = tiposData[analysisFormDialog.selectedAnalysisIndex]
            var tipoAnalisisId = tipoAnalisisSeleccionado.id || tipoAnalisisSeleccionado.ID
            
            if (!tipoAnalisisId || tipoAnalisisId <= 0) {
                throw new Error("ID de tipo de análisis inválido")
            }
            
            // Obtener trabajador ID
            var trabajadorId = 0
            if (trabajadorCombo.currentIndex > 0 && trabajadoresDisponibles !== "[]") {
                try {
                    var trabajadoresData = JSON.parse(trabajadoresDisponibles)
                    if (trabajadorCombo.currentIndex - 1 < trabajadoresData.length) {
                        var trabajadorSeleccionado = trabajadoresData[trabajadorCombo.currentIndex - 1]
                        trabajadorId = trabajadorSeleccionado.id || trabajadorSeleccionado.ID || 0
                    }
                } catch (e) {
                    console.log("⚠️ Error parseando trabajadores, continuando sin asignar:", e)
                }
            }

            return {
                tipoAnalisisId: tipoAnalisisId,
                tipoServicio: analysisFormDialog.analysisType,
                trabajadorId: trabajadorId,
                detalles: detallesAnalisis.text || ""
            }
            
        } catch (error) {
            console.log("❌ Error obteniendo datos del formulario:", error.message)
            throw error
        }
    }

    function procesarResultadoCreacion(resultado) {
        try {
            console.log("📄 Procesando resultado de creación:", resultado)
            
            // Verificar si fue exitoso
            var resultadoObj = typeof resultado === 'string' ? JSON.parse(resultado) : resultado
            if (resultadoObj && resultadoObj.exito === false) {
                throw new Error(resultadoObj.error || "Error desconocido en la creación")
            }
            
            console.log("✅ Análisis creado exitosamente")
            
            // Actualizar interfaz
            if (laboratorioModel && typeof laboratorioModel.refrescarDatos === 'function') {
                laboratorioModel.refrescarDatos()
            }
            
            // Limpiar y cerrar formulario
            Qt.callLater(function() {
                if (showNewAnalysisDialog) {
                    limpiarYCerrarDialogo()
                }
            })
            
            laboratorioRoot.formEnabled = true
            
        } catch (error) {
            console.log("❌ Error procesando resultado de creación:", error.message)
            laboratorioRoot.formEnabled = true
            throw error
        }
    }

    function procesarResultadoActualizacion(resultado) {
        try {
            console.log("📄 Procesando resultado de actualización:", resultado)
            
            // Verificar si fue exitoso
            var resultadoObj = typeof resultado === 'string' ? JSON.parse(resultado) : resultado
            if (resultadoObj && resultadoObj.exito === false) {
                throw new Error(resultadoObj.error || "Error desconocido en la actualización")
            }
            
            console.log("✅ Análisis actualizado exitosamente")
            
            // Actualizar interfaz
            if (laboratorioModel && typeof laboratorioModel.refrescarDatos === 'function') {
                laboratorioModel.refrescarDatos()
            }
            
            // Limpiar y cerrar formulario
            Qt.callLater(function() {
                if (showNewAnalysisDialog) {
                    limpiarYCerrarDialogo()
                }
            })
            
            laboratorioRoot.formEnabled = true
            
        } catch (error) {
            console.log("❌ Error procesando resultado de actualización:", error.message)
            laboratorioRoot.formEnabled = true
            throw error
        }
    }

    // ✅ COMPONENT.ONCOMPLETED CORREGIDO
    Component.onCompleted: {
        console.log("🔬 Módulo Laboratorio iniciado con lógica mejorada")
        
        function conectarModelos() {
            if (typeof appController !== 'undefined') {
                laboratorioModel = appController.laboratorio_model_instance
                
                if (laboratorioModel) {
                    // Conectar señales críticas
                    laboratorioModel.examenesActualizados.connect(function() {
                        console.log("📄 Exámenes actualizados - forzando refresh")
                        updatePaginatedModel()
                    })
                    
                    // Inicializar datos
                    if (typeof laboratorioModel.refrescarDatos === 'function') {
                        laboratorioModel.refrescarDatos()
                    }
                    
                    return true
                }
            }
            return false
        }
        
        var attempts = 0
        var timer = Qt.createQmlObject("import QtQuick 2.15; Timer { interval: 300; repeat: true }", laboratorioRoot)
        
        timer.triggered.connect(function() {
            if (conectarModelos() || ++attempts >= 5) {
                timer.destroy()
                if (attempts >= 5) {
                    console.log("⚠️ No se pudo conectar con LaboratorioModel después de 5 intentos")
                }
            }
        })
        timer.start()
    }

    function construirFiltrosActuales() {
        var filtros = {}
        
        // Filtro por tipo de análisis - USAR EL MAPA CORRECTO
        if (filtroAnalisis && filtroAnalisis.currentIndex > 0) {
            var selectedText = filtroAnalisis.currentText
            var analysisMap = laboratorioRoot.analysisMap || []
            var selectedIndexInMap = filtroAnalisis.currentIndex - 1 // Restar 1 por "Todos"
            
            if (selectedIndexInMap >= 0 && selectedIndexInMap < analysisMap.length) {
                var selectedAnalysis = analysisMap[selectedIndexInMap]
                filtros.tipo_analisis = selectedAnalysis.nombre
            }
        }
        
        // Filtro por tipo de servicio
        if (filtroTipo && filtroTipo.currentIndex > 0) {
            if (filtroTipo.currentIndex === 1) {
                filtros.tipo_servicio = "Normal"
            } else if (filtroTipo.currentIndex === 2) {
                filtros.tipo_servicio = "Emergencia"
            }
        }
        
        // Filtro por búsqueda
        if (campoBusqueda && campoBusqueda.text.length >= 2) {
            filtros.search_term = campoBusqueda.text.trim()
        }
        
        // ✅ CORRECCIÓN: Usar currentIndex en lugar de currentText
        if (filtroFecha && filtroFecha.currentIndex > 0) {
            var hoy = new Date();
            var fechaDesde, fechaHasta;
            
            // ✅ USAR ÍNDICE EN LUGAR DE TEXTO
            switch(filtroFecha.currentIndex) {
                case 1: // "Hoy"
                    fechaDesde = new Date(hoy);
                    fechaHasta = new Date(hoy);
                    console.log("✅ Aplicando filtro: Hoy")
                    break;
                case 2: // "Esta Semana"
                    fechaDesde = new Date(hoy);
                    var diaSemana = fechaDesde.getDay();
                    var diffLunes = fechaDesde.getDate() - diaSemana + (diaSemana === 0 ? -6 : 1);
                    fechaDesde.setDate(diffLunes);
                    
                    fechaHasta = new Date(fechaDesde);
                    fechaHasta.setDate(fechaDesde.getDate() + 6);
                    console.log("✅ Aplicando filtro: Esta Semana")
                    break;
                case 3: // "Este Mes"
                    fechaDesde = new Date(hoy.getFullYear(), hoy.getMonth(), 1);
                    fechaHasta = new Date(hoy.getFullYear(), hoy.getMonth() + 1, 0);
                    console.log("✅ Aplicando filtro: Este Mes")
                    break;
                default:
                    console.log("⚠️ Índice de fecha no reconocido:", filtroFecha.currentIndex)
                    return filtros; // ✅ RETORNAR SIN FECHAS SI HAY ERROR
            }
            
            // ✅ VALIDAR QUE LAS FECHAS EXISTAN ANTES DE CONVERTIR
            if (fechaDesde && fechaHasta) {
                try {
                    // ✅ CORREGIDO: Usar fecha local sin conversión UTC
                    var año_desde = fechaDesde.getFullYear();
                    var mes_desde = String(fechaDesde.getMonth() + 1).padStart(2, '0');
                    var dia_desde = String(fechaDesde.getDate()).padStart(2, '0');
                    filtros.fecha_desde = año_desde + '-' + mes_desde + '-' + dia_desde;
                    
                    var año_hasta = fechaHasta.getFullYear();
                    var mes_hasta = String(fechaHasta.getMonth() + 1).padStart(2, '0');
                    var dia_hasta = String(fechaHasta.getDate()).padStart(2, '0');
                    filtros.fecha_hasta = año_hasta + '-' + mes_hasta + '-' + dia_hasta;
                    
                    console.log("📅 Fechas aplicadas:", filtros.fecha_desde, "al", filtros.fecha_hasta)
                } catch (error) {
                    console.log("❌ Error convirtiendo fechas:", error)
                    // No agregar fechas si hay error
                }
            }
        }
        
        return filtros
    }

    function obtenerTooltipEliminacion(analisisId) {
        if (!analisisId) return "Análisis no válido"
        
        var permisos = laboratorioModel.verificar_permisos_analisis(parseInt(analisisId))
        
        if (permisos.es_administrador) {
            return "Eliminar análisis (Administrador - Sin restricciones)"
        }
        
        if (permisos.es_medico) {
            if (permisos.puede_eliminar) {
                var diasRestantes = Math.max(0, 30 - permisos.dias_antiguedad)
                return `Eliminar (${permisos.dias_antiguedad} días - ${diasRestantes} días restantes)`
            } else {
                return `Bloqueado: ${permisos.dias_antiguedad} días (Límite: 30 días)`
            }
        }
        
        return "Eliminar análisis"
    }

    // ===============================
    // FUNCIONES DE BÚSQUEDA UNIFICADA - AGREGAR DESPUÉS DE obtenerTooltipEliminacion()
    // ===============================

    function buscarPacientesUnificado(termino) {
        if (!laboratorioModel || !termino || termino.length < 2) {
            limpiarResultadosBusqueda()
            return
        }
        
        console.log("Buscando pacientes (unificado):", termino)
        
        try {
            var resultados = laboratorioModel.buscar_paciente_unificado(termino.trim(), 8)
            
            resultadosBusquedaPacientesModel.clear()
            
            if (resultados && resultados.length > 0) {
                for (var i = 0; i < resultados.length; i++) {
                    var paciente = resultados[i]
                    
                    resultadosBusquedaPacientesModel.append({
                        id: paciente.id,
                        nombre: paciente.nombre,
                        apellido_paterno: paciente.apellido_paterno,
                        apellido_materno: paciente.apellido_materno,
                        cedula: paciente.cedula,
                        nombre_completo: paciente.nombre_completo,
                        relevancia: paciente.relevancia,
                        tipo_coincidencia: paciente.tipo_coincidencia,
                        texto_busqueda: paciente.texto_busqueda
                    })
                }
                
                mostrarResultadosBusqueda = true
                campoBusquedaPaciente.pacienteNoEncontrado = false
                
                console.log("Encontrados", resultados.length, "pacientes")
            } else {
                console.log("No se encontraron pacientes para:", termino)
                mostrarResultadosBusqueda = false
                marcarComoNuevoPaciente(termino)
            }
            
        } catch (error) {
            console.log("Error en búsqueda unificada:", error.message)
            limpiarResultadosBusqueda()
        }
    }

    function seleccionarPacienteEncontrado(index) {
        if (index < 0 || index >= resultadosBusquedaPacientesModel.count) {
            console.log("Índice inválido:", index)
            return
        }
        
        var paciente = resultadosBusquedaPacientesModel.get(index)
        
        console.log("Paciente seleccionado:", paciente.nombre_completo)
        
        // ✅ GUARDAR ID DEL PACIENTE EXISTENTE
        pacienteSeleccionadoId = paciente.id || -1
        esPacienteExistente = (pacienteSeleccionadoId > 0)
        
        console.log("🆔 Paciente existente guardado - ID:", pacienteSeleccionadoId)
        
        // Autocompletar campos
        nombrePaciente.text = paciente.nombre || ""
        apellidoPaterno.text = paciente.apellido_paterno || ""
        apellidoMaterno.text = paciente.apellido_materno || ""
        
        // ✅ MANEJAR CÉDULA NULL/VACÍA CORRECTAMENTE
        var cedulaValue = paciente.cedula
        if (cedulaValue === null || cedulaValue === undefined || cedulaValue === "NULL" || cedulaValue === "") {
            cedulaPaciente.text = ""
            console.log("📋 Paciente sin cédula registrada")
        } else {
            cedulaPaciente.text = cedulaValue.toString()
            console.log("📋 Cédula cargada:", cedulaValue)
        }
        
        // ✅ IMPORTANTE: Actualizar campo de búsqueda SIN disparar nueva búsqueda
        campoBusquedaPaciente.pacienteAutocompletado = true  // MARCAR ANTES de cambiar texto
        campoBusquedaPaciente.text = paciente.nombre_completo
        campoBusquedaPaciente.pacienteNoEncontrado = false
        
        pacienteSeleccionado = true
        pacienteActual = paciente
        
        // Limpiar resultados
        limpiarResultadosBusqueda()
        
        console.log("✅ Paciente autocompletado correctamente (ID:", pacienteSeleccionadoId, ")")
    }

    function marcarComoNuevoPaciente(termino) {
        // ✅ PROTECCIÓN: No marcar como nuevo si ya hay un paciente existente seleccionado
        if (esPacienteExistente && pacienteSeleccionadoId > 0) {
            console.log("🛡️ Paciente existente protegido - no marcar como nuevo")
            return
        }
        
        campoBusquedaPaciente.pacienteNoEncontrado = true
        campoBusquedaPaciente.pacienteAutocompletado = false
        pacienteSeleccionado = false
        pacienteActual = null
        
        // Analizar automáticamente el término para pre-llenar campos
        if (laboratorioModel && termino.length >= 3) {
            var tipoDetectado = laboratorioModel.detectar_tipo_busqueda(termino)
            
            if (tipoDetectado === "nombre") {
                // Analizar nombre y pre-llenar campos
                var componentes = laboratorioModel.analizar_nombre_completo(termino)
                
                if (componentes && componentes.valido) {
                    nombrePaciente.text = componentes.nombre || ""
                    apellidoPaterno.text = componentes.apellido_paterno || ""
                    apellidoMaterno.text = componentes.apellido_materno || ""
                    cedulaPaciente.text = ""
                    
                    console.log("Campos pre-llenados desde análisis:", componentes)
                }
            } else if (tipoDetectado === "cedula") {
                // Pre-llenar cédula y limpiar nombres
                cedulaPaciente.text = termino.replace(/\D/g, '')
                nombrePaciente.text = ""
                apellidoPaterno.text = ""
                apellidoMaterno.text = ""
            }
        }
        
        console.log("Marcado como nuevo paciente:", termino)
    }

    function limpiarResultadosBusqueda() {
        mostrarResultadosBusqueda = false
        resultadosBusquedaPacientesModel.clear()
    }

    function habilitarNuevoPaciente() {
        console.log("Habilitando creación de nuevo paciente:", campoBusquedaPaciente.text)
        
        var termino = campoBusquedaPaciente.text.trim()
        marcarComoNuevoPaciente(termino)
        
        // Enfocar el primer campo vacío
        if (!nombrePaciente.text) {
            nombrePaciente.forceActiveFocus()
        } else if (!apellidoPaterno.text) {
            apellidoPaterno.forceActiveFocus()
        } else {
            detallesAnalisis.forceActiveFocus()
        }
    }

    // ===============================
    // FUNCIÓN LIMPIAR ACTUALIZADA
    // ===============================

    function limpiarDatosPaciente() {
        // No limpiar si estamos en modo edición
        if (isEditMode) {
            console.log("Modo edición activo - NO limpiar datos")
            return
        }
        
        campoBusquedaPaciente.text = ""
        cedulaPaciente.text = ""
        nombrePaciente.text = ""
        apellidoPaterno.text = ""
        apellidoMaterno.text = ""
        
        // ✅ RESETEAR NUEVOS CAMPOS
        pacienteSeleccionadoId = -1
        esPacienteExistente = false
        
        // Resetear estados
        campoBusquedaPaciente.pacienteAutocompletado = false
        campoBusquedaPaciente.pacienteNoEncontrado = false
        campoBusquedaPaciente.tipoDetectado = ""
        pacienteSeleccionado = false
        pacienteActual = null
        
        limpiarResultadosBusqueda()
        
        console.log("Datos del paciente limpiados completamente")
    }

    // ===============================
    // FUNCIÓN BUSCAR O CREAR ACTUALIZADA
    // ===============================

    function buscarOCrearPaciente() {
        if (!laboratorioModel) {
            throw new Error("laboratorioModel no disponible")
        }
        
        // ✅ NUEVA LÓGICA: Si es paciente existente seleccionado, usar su ID directamente
        if (esPacienteExistente && pacienteSeleccionadoId > 0) {
            console.log("🎯 Usando paciente existente seleccionado - ID:", pacienteSeleccionadoId)
            return pacienteSeleccionadoId
        }
        
        // ✅ LÓGICA ORIGINAL: Buscar o crear paciente nuevo
        var nombre = nombrePaciente.text.trim()
        var apellidoP = apellidoPaterno.text.trim()
        var apellidoM = apellidoMaterno.text.trim()
        var cedula = cedulaPaciente.text.trim()
        
        // Validaciones básicas
        if (!nombre || nombre.length < 2) {
            throw new Error("Nombre inválido: " + nombre)
        }
        if (!apellidoP || apellidoP.length < 2) {
            throw new Error("Apellido paterno inválido: " + apellidoP)
        }
        
        console.log("🔍 Buscando/creando paciente nuevo:", nombre, apellidoP, "- Cedula:", cedula || "vacía")
        
        // Usar el método mejorado del modelo
        var pacienteId = laboratorioModel.buscar_o_crear_paciente_inteligente(
            nombre, apellidoP, apellidoM, cedula
        )
        
        if (!pacienteId || pacienteId <= 0) {
            throw new Error("Error: ID de paciente inválido: " + pacienteId)
        }
        
        console.log("✅ Paciente gestionado correctamente - ID:", pacienteId)
        return pacienteId
    }

    // ===============================
    // FUNCIONES DE AUTOCOMPLETADO LEGACY SIMPLIFICADAS (REEMPLAZAR LAS EXISTENTES)
    // ===============================

    function autocompletarDatosPaciente(paciente) {
        // Redirigir al nuevo sistema
        console.log("LEGACY: Redirigiendo autocompletado al nuevo sistema")
        
        nombrePaciente.text = paciente.Nombre || ""
        apellidoPaterno.text = paciente.Apellido_Paterno || ""
        apellidoMaterno.text = paciente.Apellido_Materno || ""
        cedulaPaciente.text = paciente.Cedula || ""
        
        campoBusquedaPaciente.text = paciente.nombre_completo || 
            (paciente.Nombre + " " + paciente.Apellido_Paterno + " " + (paciente.Apellido_Materno || "")).trim()
        
        campoBusquedaPaciente.pacienteAutocompletado = true
        campoBusquedaPaciente.pacienteNoEncontrado = false
        pacienteSeleccionado = true
        
        console.log("Paciente autocompletado (legacy):", paciente.nombre_completo || "")
    }

    // Mantener para compatibilidad pero redirigir al nuevo sistema
    function buscarPacientes(termino_busqueda, limite) {
        console.log("LEGACY: Redirigiendo búsqueda al sistema unificado")
        return buscarPacientesUnificado(termino_busqueda)
    }

    // ===============================
    // FUNCIONES DE DEBUGGING Y UTILIDADES
    // ===============================

    function verificarEstadoPaciente() {
        console.log("=== ESTADO ACTUAL DEL PACIENTE ===")
        console.log("Campo búsqueda:", campoBusquedaPaciente.text)
        console.log("Autocompletado:", campoBusquedaPaciente.pacienteAutocompletado)
        console.log("No encontrado:", campoBusquedaPaciente.pacienteNoEncontrado)
        console.log("Tipo detectado:", campoBusquedaPaciente.tipoDetectado)
        console.log("Paciente seleccionado:", pacienteSeleccionado)
        console.log("Nombre:", nombrePaciente.text)
        console.log("Apellido P:", apellidoPaterno.text)
        console.log("Apellido M:", apellidoMaterno.text)
        console.log("Cédula:", cedulaPaciente.text)
        console.log("Resultados visibles:", mostrarResultadosBusqueda)
        console.log("Cantidad resultados:", resultadosBusquedaPacientesModel.count)
        console.log("=================================")
    }

    function reiniciarBusquedaPaciente() {
        console.log("Reiniciando búsqueda de paciente...")
        limpiarDatosPaciente()
        campoBusquedaPaciente.forceActiveFocus()
    }

    function forzarLimpiezaPaciente() {
        console.log("🧹 Forzando limpieza completa del paciente")
        
        // Forzar limpieza incluso si hay paciente existente
        pacienteSeleccionadoId = -1
        esPacienteExistente = false
        
        campoBusquedaPaciente.text = ""
        cedulaPaciente.text = ""
        nombrePaciente.text = ""
        apellidoPaterno.text = ""
        apellidoMaterno.text = ""
        
        // Resetear estados
        campoBusquedaPaciente.pacienteAutocompletado = false
        campoBusquedaPaciente.pacienteNoEncontrado = false
        campoBusquedaPaciente.tipoDetectado = ""
        pacienteSeleccionado = false
        pacienteActual = null
        
        limpiarResultadosBusqueda()
        
        console.log("✅ Limpieza forzada completada")
    }
}