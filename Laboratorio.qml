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
    readonly property real colId: 0.05
    readonly property real colPaciente: 0.18
    readonly property real colAnalisis: 0.18
    readonly property real colTipo: 0.09
    readonly property real colPrecio: 0.10
    readonly property real colTrabajador: 0.15
    readonly property real colRegistradoPor: 0.15
    readonly property real colFecha: 0.10
    // Propiedades para los diálogos del análisis
    property bool isEditMode: false
    property int editingIndex: -1
    property int selectedRowIndex: -1
    property bool showNewAnalysisDialog: false
    // DATOS DESDE EL BACKEND
    property var trabajadoresDisponibles: laboratorioModel ? laboratorioModel.trabajadoresJson : "[]"
    property var tiposAnalisis: laboratorioModel ? laboratorioModel.tiposAnalisisJson : "[]"

    // PROPIEDADES DE FILTRO
    property var analisisModelData: []
    property var analysisMap: []
    
    readonly property int currentPageLaboratorio: laboratorioModel ? laboratorioModel._currentPage || 0 : 0
    readonly property int totalPagesLaboratorio: laboratorioModel ? laboratorioModel._totalPages || 0 : 0
    readonly property int itemsPerPageLaboratorio: laboratorioModel ? laboratorioModel._itemsPerPage || 20 : 20
    readonly property int totalItemsLaboratorio: laboratorioModel ? laboratorioModel._totalRecords || 0 : 0

    ListModel {
        id: analisisPaginadosModel // Modelo para la página actual
    }
    // CONEXIÓN CON EL MODELO
    Connections {
        target: appController
        function onModelsReady() {
            console.log("🔬 Modelos listos, conectando LaboratorioModel...")
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
                // ✅ CORREGIDO: Usar el método correcto del modelo
                laboratorioModel.aplicar_filtros_y_recargar("", "", "", "", "")
                console.log("✅ Inicialización retrasada exitosa")
            }
        }
    }
    // CONEXIONES CON EL MODELO
    Connections {
        target: laboratorioModel
        enabled: laboratorioModel !== null
        
        function onExamenesActualizados() {
            console.log("🔬 Signal: Exámenes actualizados")
            updateTimer.start()
        }
        
        function onTiposAnalisisActualizados() {
            console.log("📋 Signal: Tipos de análisis actualizados")
            Qt.callLater(updateAnalisisCombo)
        }
        
        function onTrabajadoresActualizados() {
            console.log("👥 Signal: Trabajadores actualizados") 
        }
        
        function onEstadoCambiado(nuevoEstado) {
            console.log("⏳ Estado:", nuevoEstado)
        }
        
        // NUEVO: Manejar éxito de operaciones
        function onOperacionExitosa(mensaje) {
            console.log("✅ Signal: Operación exitosa -", mensaje)
            mostrarNotificacion("Éxito", mensaje)
            updatePaginatedModel()
            
            // Solo cerrar si es una operación de análisis
            if (showNewAnalysisDialog && (mensaje.includes("creado") || mensaje.includes("actualizado") || mensaje.includes("Examen"))) {
                Qt.callLater(function() {
                    limpiarYCerrarDialogo()
                })
            }
        }
        // NUEVO: Manejar actualización exitosa
        function onExamenActualizado(datos) {
            console.log("📝 Signal: Examen actualizado exitosamente")
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
    

    // FUNCIÓN MEJORADA PARA MOSTRAR NOTIFICACIONES
    function mostrarNotificacion(titulo, mensaje) {
        console.log("📢 " + titulo + ": " + mensaje)
        // Aquí puedes agregar tu lógica de notificaciones visual
        // Por ejemplo, mostrar un toast o popup
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
                            
                            // Contenedor del icono con tamaño fijo
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
                            
                            // Título
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
                        
                        // ESPACIADOR FLEXIBLE
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
                                
                                // ✅ CORREGIDO: Garantizar que "Todos" esté siempre en índice 0
                                model: {
                                    var modelData = ["Todos"] // SIEMPRE empieza con "Todos"
                                    try {
                                        var tiposData = JSON.parse(tiposAnalisis)
                                        for (var i = 0; i < tiposData.length; i++) {
                                            var nombre = tiposData[i].nombre || tiposData[i].Nombre || ""
                                            if (nombre && nombre !== "Todos") { // Evitar duplicados
                                                modelData.push(nombre)
                                            }
                                        }
                                    } catch (e) {
                                        console.log("Error parseando tipos análisis:", e)
                                    }
                                    return modelData
                                }
                                currentIndex: 0 // Siempre empezar en "Todos"
                                
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
                        // En el GridLayout de filtros, agrega este botón:
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
                                
                                // TRABAJADOR COLUMN
                                Item {
                                    Layout.preferredWidth: parent.width * colTrabajador
                                    Layout.fillHeight: true
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "TRABAJADOR"
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
                                
                                // REGISTRADO POR COLUMN
                                Item {
                                    Layout.preferredWidth: parent.width * colRegistradoPor
                                    Layout.fillHeight: true
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "REGISTRADO POR"
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
                                        
                                        // ID COLUMN
                                        Item {
                                            Layout.preferredWidth: parent.width * colId
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
                                        
                                        // 🎯 ANÁLISIS COLUMN MODIFICADA - AHORA CON DETALLES
                                        Item {
                                            Layout.preferredWidth: parent.width * colAnalisis
                                            Layout.fillHeight: true
                                            
                                            Column {
                                                anchors.fill: parent
                                                anchors.margins: baseUnit * 0.5
                                                
                                                Label {
                                                    width: parent.width - baseUnit
                                                    text: model.tipoAnalisis || "Análisis General"
                                                    color: primaryColor
                                                    font.bold: false
                                                    font.pixelSize: fontBaseSize * 0.85
                                                    font.family: "Segoe UI, Arial, sans-serif"
                                                    elide: Text.ElideRight
                                                }
                                                
                                                Label {
                                                    width: parent.width - baseUnit
                                                    text: {
                                                        var detalles = model.detallesExamen || ""
                                                        if (detalles && detalles.trim() !== "") {
                                                            return "Detalles: " + detalles
                                                        } else {
                                                            return "Sin detalles específicos"
                                                        }
                                                    }
                                                    color: textColorLight
                                                    font.pixelSize: fontBaseSize * 0.75
                                                    font.family: "Segoe UI, Arial, sans-serif"
                                                    elide: Text.ElideRight
                                                    wrapMode: Text.WordWrap
                                                    maximumLineCount: 1
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
                                        
                                        // TRABAJADOR COLUMN
                                        Item {
                                            Layout.preferredWidth: parent.width * colTrabajador
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                anchors.rightMargin: baseUnit
                                                text: model.trabajadorAsignado || "Sin asignar"
                                                color: textColor
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
                                        
                                        // REGISTRADO POR COLUMN
                                        Item {
                                            Layout.preferredWidth: parent.width * colRegistradoPor
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                anchors.rightMargin: baseUnit
                                                text: model.registradoPor || "Sistema"
                                                color: textColorLight
                                                font.pixelSize: fontBaseSize * 0.75
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
                                    
                                    // LÍNEAS VERTICALES CONTINUAS
                                    Repeater {
                                        model: 7 // Número de líneas verticales
                                        Rectangle {
                                            property real xPos: {
                                                var w = parent.width - baseUnit * 3
                                                switch(index) {
                                                    case 0: return baseUnit * 1.5 + w * colId
                                                    case 1: return baseUnit * 1.5 + w * (colId + colPaciente)
                                                    case 2: return baseUnit * 1.5 + w * (colId + colPaciente + colAnalisis)
                                                    case 3: return baseUnit * 1.5 + w * (colId + colPaciente + colAnalisis + colTipo)
                                                    case 4: return baseUnit * 1.5 + w * (colId + colPaciente + colAnalisis + colTipo + colPrecio)
                                                    case 5: return baseUnit * 1.5 + w * (colId + colPaciente + colAnalisis + colTipo + colPrecio + colTrabajador)
                                                    case 6: return baseUnit * 1.5 + w * (colId + colPaciente + colAnalisis + colTipo + colPrecio + colTrabajador + colRegistradoPor)
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
                                            }
                                            
                                            onClicked: {
                                                var analisisId = parseInt(model.analisisId)
                                                editarAnalisis(index, analisisId)
                                            }
                                            
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
                                                source: "Resources/iconos/eliminar.svg"
                                                fillMode: Image.PreserveAspectFit
                                            }
                                            
                                            onClicked: {
                                                var analisisId = parseInt(model.analisisId)
                                                if (laboratorioModel) {
                                                    laboratorioModel.eliminarExamen(analisisId)
                                                }
                                                selectedRowIndex = -1
                                            }
                                            
                                            onHoveredChanged: {
                                                deleteIcon.opacity = hovered ? 0.7 : 1.0
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
                            text: {
                                var inicio = currentPageLaboratorio * itemsPerPageLaboratorio + 1
                                var fin = Math.min((currentPageLaboratorio + 1) * itemsPerPageLaboratorio, totalItemsLaboratorio)
                                return totalItemsLaboratorio + 
                                    " Página " + (currentPageLaboratorio + 1) + " de " + Math.max(1, totalPagesLaboratorio) + " "
                            }
                            color: textColor
                            font.pixelSize: fontBaseSize * 0.8
                            font.family: "Segoe UI, Arial, sans-serif"
                            font.weight: Font.Medium
                        }
                        
                        Button {
                            Layout.preferredWidth: baseUnit * 11
                            Layout.preferredHeight: baseUnit * 4
                            text: "Siguiente →"
                            enabled: currentPageLaboratorio < totalPagesLaboratorio - 1
                            
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

    // ===== DIÁLOGO PRINCIPAL =====
    
    // Fondo del diálogo
    Rectangle {
        id: dialogBackground
        anchors.fill: parent
        color: "black"
        opacity: showNewAnalysisDialog ? 0.5 : 0
        visible: opacity > 0
        z: 1000
        
        MouseArea {
            anchors.fill: parent
            onClicked: {
                limpiarYCerrarDialogo()
            }
        }
        
        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }
    }
    
    // Diálogo de análisis adaptativo
    Rectangle {
        id: analysisForm
        anchors.centerIn: parent
        width: Math.min(550, parent.width * 0.9)
        height: Math.min(800, parent.height * 0.9)
        color: whiteColor
        radius: baseUnit * 2
        border.color: lightGrayColor
        border.width: 2
        visible: showNewAnalysisDialog
        z: 1001
        
        property int selectedAnalysisIndex: -1
        property string analysisType: "Normal"
        property real calculatedPrice: 0.0
        
        function loadEditData() {
            if (isEditMode && editingIndex >= 0) {
                var analisis = analisisPaginadosModel.get(editingIndex)
                console.log("🔄 Cargando datos para editar:", JSON.stringify(analisis))
                
                // Cargar datos del paciente
                cedulaPaciente.text = analisis.pacienteCedula || ""
                nombrePaciente.text = analisis.pacienteNombre || ""
                apellidoPaterno.text = analisis.pacienteApellidoP || ""
                apellidoMaterno.text = analisis.pacienteApellidoM || ""
                
                // Marcar como autocompletado
                cedulaPaciente.pacienteAutocompletado = true
                apellidoPaterno.pacienteAutocompletado = true
                apellidoMaterno.pacienteAutocompletado = true
                
                // Cargar detalles específicos del análisis
                detallesAnalisis.text = analisis.detallesExamen || ""
                
                // Cargar tipo de análisis
                var tipoAnalisisNombre = analisis.tipoAnalisis
                var tiposData = JSON.parse(tiposAnalisis)
                var encontrado = false
                for (var i = 0; i < tiposData.length; i++) {
                    if (tiposData[i].nombre === tipoAnalisisNombre || tiposData[i].Nombre === tipoAnalisisNombre) {
                        analisisCombo.currentIndex = i + 1
                        analysisForm.selectedAnalysisIndex = i
                        encontrado = true
                        break
                    }
                }
                
                if (!encontrado) {
                    analisisCombo.currentIndex = 0
                    analysisForm.selectedAnalysisIndex = -1
                }
                
                // Cargar tipo de servicio
                if (analisis.tipo === "Normal") {
                    normalRadio.checked = true
                    analysisForm.analysisType = "Normal"
                } else {
                    emergenciaRadio.checked = true
                    analysisForm.analysisType = "Emergencia"
                }
                
                // Calcular precio
                updatePrice()
                
                // Cargar trabajador asignado
                var trabajadorEncontrado = false
                var trabajadorNombre = analisis.trabajadorAsignado || ""
                
                if (trabajadorNombre && trabajadorNombre !== "Sin asignar") {
                    var trabajadoresData = JSON.parse(trabajadoresDisponibles)
                    for (var j = 0; j < trabajadoresData.length; j++) {
                        if (trabajadoresData[j].nombre_completo === trabajadorNombre) {
                            trabajadorCombo.currentIndex = j + 1
                            trabajadorEncontrado = true
                            break
                        }
                    }
                }
                
                if (!trabajadorEncontrado) {
                    trabajadorCombo.currentIndex = 0
                }
                
                console.log("✅ Datos de edición cargados correctamente")
            }
        }
        
        function updatePrice() {
            if (analysisForm.selectedAnalysisIndex >= 0) {
                var tiposData = JSON.parse(tiposAnalisis)
                var tipoAnalisis = tiposData[analysisForm.selectedAnalysisIndex]
                if (analysisForm.analysisType === "Normal") {
                    analysisForm.calculatedPrice = tipoAnalisis.precioNormal || tipoAnalisis.Precio_Normal || 0
                } else {
                    analysisForm.calculatedPrice = tipoAnalisis.precioEmergencia || tipoAnalisis.Precio_Emergencia || 0
                }
            } else {
                analysisForm.calculatedPrice = 0.0
            }
        }
        
        onVisibleChanged: {
            if (visible && isEditMode) {
                loadEditData()
            } else if (visible && !isEditMode) {
                clearAllFields()
            }
        }
        
        ScrollView {
            anchors.fill: parent
            anchors.margins: baseUnit * 3
            contentHeight: mainColumn.implicitHeight
            clip: true
            
            ColumnLayout {
                id: mainColumn
                width: analysisForm.width - baseUnit * 6
                spacing: baseUnit * 2
                
                Label {
                    Layout.fillWidth: true
                    text: isEditMode ? "Editar Análisis" : "Nuevo Análisis"
                    font.pixelSize: fontBaseSize * 1.6
                    font.bold: true
                    font.family: "Segoe UI, Arial, sans-serif"
                    color: textColor
                    horizontalAlignment: Text.AlignHCenter
                }
                
                GroupBox {
                    Layout.fillWidth: true
                    title: "Datos del Paciente"
                    
                    background: Rectangle {
                        color: lightGrayColor
                        border.color: borderColor
                        border.width: 1
                        radius: baseUnit
                    }
                    
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: baseUnit
                        
                        // Campo principal: BÚSQUEDA SOLO POR CÉDULA
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit
                            
                            TextField {
                                id: cedulaPaciente
                                Layout.fillWidth: true
                                Layout.preferredHeight: baseUnit * 4
                                placeholderText: "Ingrese número de cédula para buscar paciente..."
                                inputMethodHints: Qt.ImhDigitsOnly
                                validator: RegularExpressionValidator { 
                                    regularExpression: /^[0-9]{1,12}(\s*[A-Z]{0,3})?$/
                                }
                                maximumLength: 15
                                
                                property bool pacienteAutocompletado: false
                                property bool pacienteNoEncontrado: false
                                
                                background: Rectangle {
                                    color: {
                                        if (cedulaPaciente.pacienteAutocompletado) return "#F0F8FF"
                                        if (cedulaPaciente.pacienteNoEncontrado) return "#FEF3C7"
                                        return whiteColor
                                    }
                                    border.color: cedulaPaciente.activeFocus ? primaryColor : borderColor
                                    border.width: cedulaPaciente.activeFocus ? 2 : 1
                                    radius: baseUnit * 0.6
                                    
                                    Text {
                                        anchors.right: parent.right
                                        anchors.rightMargin: baseUnit
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: {
                                            if (cedulaPaciente.pacienteAutocompletado) return "✅"
                                            if (cedulaPaciente.pacienteNoEncontrado) return "⚠️"
                                            return cedulaPaciente.text.length >= 5 ? "🔍" : "🔒"
                                        }
                                        font.pixelSize: fontBaseSize * 1.2
                                        visible: cedulaPaciente.text.length > 0
                                    }
                                }
                                
                                onTextChanged: {
                                    if (text.length >= 5 && !pacienteAutocompletado) {
                                        pacienteNoEncontrado = false
                                        buscarTimer.restart()
                                    } else if (text.length === 0) {
                                        limpiarDatosPaciente()
                                    }
                                }
                                
                                Keys.onReturnPressed: {
                                    if (cedulaPaciente.text.length >= 5) {
                                        buscarPacientePorCedula(cedulaPaciente.text)
                                    }
                                }
                                
                            }
                            Button {
                                id: nuevoPacienteBtn
                                text: "Nuevo Paciente"
                                visible: cedulaPaciente.pacienteNoEncontrado && 
                                        cedulaPaciente.text.length >= 5 && 
                                        !cedulaPaciente.pacienteAutocompletado
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
                                
                                onClicked: habilitarNuevoPaciente()
                                
                                HoverHandler {
                                    cursorShape: Qt.PointingHandCursor
                                }
                                
                                ToolTip {
                                    visible: nuevoPacienteBtn.hovered
                                    text: "Crear nuevo paciente con cédula " + cedulaPaciente.text
                                    delay: 500
                                    timeout: 3000
                                }
                            }
                            
                            Button {
                                text: "Limpiar"
                                visible: cedulaPaciente.pacienteAutocompletado || 
                                        nombrePaciente.text.length > 0 ||
                                        (cedulaPaciente.text.length > 0 && !cedulaPaciente.pacienteNoEncontrado)
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
                                
                                onClicked: limpiarDatosPaciente()
                                
                                HoverHandler {
                                    cursorShape: Qt.PointingHandCursor
                                }
                            }
                        }
                        
                        Timer {
                            id: buscarTimer
                            interval: 800 // 800ms de delay
                            running: false
                            repeat: false
                            onTriggered: {
                                var cedula = cedulaPaciente.text.trim()
                                if (cedula.length >= 5) {
                                    buscarPacientePorCedula(cedula)
                                }
                            }
                        }
                        
                        // Campos de datos del paciente (solo lectura una vez encontrado)
                        TextField {
                            id: nombrePaciente
                            Layout.fillWidth: true
                            Layout.preferredHeight: baseUnit * 4
                            placeholderText: cedulaPaciente.pacienteAutocompletado ? 
                                            "Nombre del paciente" : "Ingrese nombre del nuevo paciente"
                            readOnly: cedulaPaciente.pacienteAutocompletado
                            font.pixelSize: fontBaseSize * 0.9
                            font.family: "Segoe UI, Arial, sans-serif"
                            
                            property bool esCampoNuevoPaciente: !cedulaPaciente.pacienteAutocompletado && 
                                                            cedulaPaciente.pacienteNoEncontrado
                            
                            background: Rectangle {
                                color: {
                                    if (cedulaPaciente.pacienteAutocompletado) return "#F8F9FA"
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
                            
                            // Validación en tiempo real para nuevos pacientes
                            onTextChanged: {
                                if (esCampoNuevoPaciente && text.length > 0) {
                                    color = text.length >= 2 ? textColor : "#E74C3C"
                                }
                            }
                        }
                        
                        RowLayout {
                            Layout.fillWidth: true
                            
                            TextField {
                                id: apellidoPaterno
                                Layout.fillWidth: true
                                Layout.preferredHeight: baseUnit * 4
                                placeholderText: cedulaPaciente.pacienteAutocompletado ? 
                                                "Apellido paterno" : "Ingrese apellido paterno"
                                readOnly: cedulaPaciente.pacienteAutocompletado
                                font.pixelSize: fontBaseSize * 0.9
                                font.family: "Segoe UI, Arial, sans-serif"
                                
                                property bool pacienteAutocompletado: cedulaPaciente.pacienteAutocompletado
                                property bool esCampoNuevoPaciente: !cedulaPaciente.pacienteAutocompletado && 
                                                                cedulaPaciente.pacienteNoEncontrado
                                
                                background: Rectangle {
                                    color: {
                                        if (apellidoPaterno.pacienteAutocompletado) return "#F8F9FA"
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
                                
                                onTextChanged: {
                                    if (esCampoNuevoPaciente && text.length > 0) {
                                        color = text.length >= 2 ? textColor : "#E74C3C"
                                    }
                                }
                            }
                            
                            TextField {
                                id: apellidoMaterno
                                Layout.fillWidth: true
                                Layout.preferredHeight: baseUnit * 4
                                placeholderText: cedulaPaciente.pacienteAutocompletado ? 
                                                "Apellido materno" : "Ingrese apellido materno (opcional)"
                                readOnly: cedulaPaciente.pacienteAutocompletado
                                font.pixelSize: fontBaseSize * 0.9
                                font.family: "Segoe UI, Arial, sans-serif"
                                
                                property bool pacienteAutocompletado: cedulaPaciente.pacienteAutocompletado
                                property bool esCampoNuevoPaciente: !cedulaPaciente.pacienteAutocompletado && 
                                                                cedulaPaciente.pacienteNoEncontrado
                                
                                background: Rectangle {
                                    color: {
                                        if (apellidoMaterno.pacienteAutocompletado) return "#F8F9FA"
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
                            }
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: baseUnit * 3
                    visible: cedulaPaciente.pacienteNoEncontrado && !cedulaPaciente.pacienteAutocompletado
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
                            text: "Modo: Crear nuevo paciente con cédula " + cedulaPaciente.text
                            color: "#047857"
                            font.pixelSize: fontBaseSize * 0.8
                            font.bold: true
                            font.family: "Segoe UI, Arial, sans-serif"
                        }
                    }
                }
                
                // Tipo de Análisis
                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        Layout.preferredWidth: baseUnit * 12
                        text: "Tipo de Análisis:"
                        font.bold: true
                        color: textColor
                        font.pixelSize: fontBaseSize * 0.9
                        font.family: "Segoe UI, Arial, sans-serif"
                    }
                    ComboBox {
                        id: analisisCombo
                        Layout.fillWidth: true
                        Layout.preferredHeight: baseUnit * 4
                        
                        // ✅ CORREGIDO: Mismo patrón que el filtro - "Seleccionar..." en índice 0
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
                                analysisForm.selectedAnalysisIndex = currentIndex - 1
                                analysisForm.updatePrice()
                            } else {
                                analysisForm.selectedAnalysisIndex = -1
                                analysisForm.calculatedPrice = 0.0
                            }
                        }
                        
                        contentItem: Label {
                            text: analisisCombo.displayText
                            font.pixelSize: fontBaseSize * 0.8
                            font.family: "Segoe UI, Arial, sans-serif"
                            color: textColor
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: baseUnit
                            elide: Text.ElideRight
                        }
                    }
                }
                
                // Tipo de Servicio
                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        Layout.preferredWidth: baseUnit * 12
                        text: "Tipo de Servicio:"
                        font.bold: true
                        color: textColor
                        font.pixelSize: fontBaseSize * 0.9
                        font.family: "Segoe UI, Arial, sans-serif"
                    }
                    
                    RadioButton {
                        id: normalRadio
                        text: "Normal"
                        checked: true
                        onCheckedChanged: {
                            if (checked) {
                                analysisForm.analysisType = "Normal"
                                analysisForm.updatePrice()
                            }
                        }
                        
                        contentItem: Label {
                            text: normalRadio.text
                            font.pixelSize: fontBaseSize * 0.9
                            font.family: "Segoe UI, Arial, sans-serif"
                            color: textColor
                            leftPadding: normalRadio.indicator.width + normalRadio.spacing
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                    
                    RadioButton {
                        id: emergenciaRadio
                        text: "Emergencia"
                        onCheckedChanged: {
                            if (checked) {
                                analysisForm.analysisType = "Emergencia"
                                analysisForm.updatePrice()
                            }
                        }
                        
                        contentItem: Label {
                            text: emergenciaRadio.text
                            font.pixelSize: fontBaseSize * 0.9
                            font.family: "Segoe UI, Arial, sans-serif"
                            color: textColor
                            leftPadding: emergenciaRadio.indicator.width + emergenciaRadio.spacing
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                    Item { Layout.fillWidth: true }
                }
                
                // Trabajador
                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        Layout.preferredWidth: baseUnit * 12
                        text: "Trabajador:"
                        font.bold: true
                        color: textColor
                        font.pixelSize: fontBaseSize * 0.9
                        font.family: "Segoe UI, Arial, sans-serif"
                    }
                    ComboBox {
                        id: trabajadorCombo
                        Layout.fillWidth: true
                        Layout.preferredHeight: baseUnit * 4

                        model: {
                            var list = ["Seleccionar trabajador..."]
                            try {
                                var trabajadoresData = JSON.parse(trabajadoresDisponibles)
                                for (var i = 0; i < trabajadoresData.length; i++) {
                                    var nombre = trabajadoresData[i].nombre_completo || trabajadoresData[i].nombre || "Sin nombre"
                                    list.push(nombre)
                                }
                            } catch (e) {
                                console.log("Error parseando trabajadores:", e)
                            }
                            list.push("Sin asignar")
                            return list
                        }
                        
                        contentItem: Label {
                            text: trabajadorCombo.displayText
                            font.pixelSize: fontBaseSize * 0.8
                            font.family: "Segoe UI, Arial, sans-serif"
                            color: textColor
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: baseUnit
                            elide: Text.ElideRight
                        }
                    }
                }
                
                // Precio
                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        Layout.preferredWidth: baseUnit * 12
                        text: "Precio:"
                        font.bold: true
                        color: textColor
                        font.pixelSize: fontBaseSize * 0.9
                        font.family: "Segoe UI, Arial, sans-serif"
                    }
                    Label {
                        text: analysisForm.selectedAnalysisIndex >= 0 ? 
                              "Bs " + analysisForm.calculatedPrice.toFixed(2) : "Seleccione tipo de análisis"
                        font.bold: true
                        font.pixelSize: fontBaseSize * 1.1
                        font.family: "Segoe UI, Arial, sans-serif"
                        color: analysisForm.analysisType === "Emergencia" ? "#92400E" : "#047857"
                    }
                    Item { Layout.fillWidth: true }
                }
                
                // Detalles
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    
                    Label {
                        text: "Detalles:"
                        font.bold: true
                        color: textColor
                        font.pixelSize: fontBaseSize * 0.9
                        font.family: "Segoe UI, Arial, sans-serif"
                    }
                    
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: baseUnit * 8
                        
                        TextArea {
                            id: detallesAnalisis
                            placeholderText: "Descripción adicional del análisis..."
                            wrapMode: TextArea.Wrap
                            font.pixelSize: fontBaseSize * 0.9
                            font.family: "Segoe UI, Arial, sans-serif"
                            background: Rectangle {
                                color: whiteColor
                                border.color: borderColor
                                border.width: 1
                                radius: baseUnit
                            }
                        }
                    }
                }
                
                // Botones de acción
                RowLayout {
                    Layout.fillWidth: true
                    Item { Layout.fillWidth: true }
                    
                    Button {
                        text: "Cancelar"
                        Layout.preferredHeight: baseUnit * 4
                        background: Rectangle {
                            color: lightGrayColor
                            radius: baseUnit
                        }
                        contentItem: Label {
                            text: parent.text
                            color: textColor
                            font.pixelSize: fontBaseSize * 0.9
                            font.family: "Segoe UI, Arial, sans-serif"
                            horizontalAlignment: Text.AlignHCenter
                        }
                        onClicked: {
                            limpiarYCerrarDialogo()
                        }
                    }
                    
                    Button {
                        text: isEditMode ? "Actualizar" : "Guardar"
                        enabled: {
                            // Validaciones básicas
                            var tieneAnalisis = analysisForm.selectedAnalysisIndex >= 0
                            var tieneCedula = cedulaPaciente.text.length >= 5
                            
                            if (cedulaPaciente.pacienteAutocompletado) {
                                // Paciente existente encontrado
                                return tieneAnalisis && tieneCedula && nombrePaciente.text.length >= 2
                            } else if (cedulaPaciente.pacienteNoEncontrado) {
                                // Nuevo paciente - validar campos obligatorios
                                var tieneNombre = nombrePaciente.text.length >= 2
                                var tieneApellido = apellidoPaterno.text.length >= 2
                                return tieneAnalisis && tieneCedula && tieneNombre && tieneApellido
                            }
                            
                            return false
                        }
                        property bool isLoading: !analysisForm.enabled
                        Layout.preferredHeight: baseUnit * 4
                        
                        background: Rectangle {
                            color: {
                                if (!parent.enabled) return "#bdc3c7"
                                if (parent.isLoading) return "#95a5a6"  // Gris mientras carga
                                return primaryColor
                            }
                            radius: baseUnit
                            
                            // Indicador de loading
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.isLoading ? 20 : 0
                                height: parent.isLoading ? 20 : 0
                                color: "transparent"
                                visible: parent.isLoading
                                
                                // Spinner simple
                                Rectangle {
                                    width: 4
                                    height: 4
                                    radius: 2
                                    color: whiteColor
                                    anchors.centerIn: parent
                                    
                                    SequentialAnimation on rotation {
                                        running: parent.parent.visible
                                        loops: Animation.Infinite
                                        NumberAnimation { to: 360; duration: 1000 }
                                    }
                                }
                            }
                        }
                        
                        contentItem: Label {
                            text: parent.isLoading ? "Guardando..." : parent.text
                            color: whiteColor
                            font.bold: true
                            font.pixelSize: fontBaseSize * 0.9
                            font.family: "Segoe UI, Arial, sans-serif"
                            horizontalAlignment: Text.AlignHCenter
                        }
                        
                        onClicked: {
                            if (!isLoading) {
                                guardarAnalisis()
                            }
                        }
                    }
                }
            }
        }
    }

    function aplicarFiltros() {
        console.log("🔍 Aplicando filtros...")
        
        if (!laboratorioModel) {
            console.log("❌ LaboratorioModel no disponible")
            return
        }
    
        var filtros = {}
        
        // Filtro por tipo de análisis - USAR EL MAPA
        if (filtroAnalisis && filtroAnalisis.currentIndex > 0) {
            var selectedText = filtroAnalisis.currentText
            var analysisMap = laboratorioRoot.analysisMap || []
            var selectedIndexInMap = filtroAnalisis.currentIndex - 1 // Restar 1 por "Todos"
            
            if (selectedIndexInMap >= 0 && selectedIndexInMap < analysisMap.length) {
                var selectedAnalysis = analysisMap[selectedIndexInMap]
                filtros.tipo_analisis = selectedAnalysis.nombre
                console.log("✅ Filtro análisis aplicado:", selectedAnalysis.nombre, "ID:", selectedAnalysis.id)
            } else {
                console.log("⚠️ Índice fuera de rango en el mapa de análisis:", selectedIndexInMap)
            }
        } else {
            console.log("🔍 Filtro análisis no aplicado (índice 0 - Todos)")
        }
        
        // Resto de los filtros (se mantienen igual)
        if (filtroTipo && filtroTipo.currentIndex > 0) {
            if (filtroTipo.currentIndex === 1) {
                filtros.tipo_servicio = "Normal"
            } else if (filtroTipo.currentIndex === 2) {
                filtros.tipo_servicio = "Emergencia"
            }
        }
        
        if (campoBusqueda && campoBusqueda.text.length >= 2) {
            filtros.search_term = campoBusqueda.text.trim()
        }
        
        if (filtroFecha && filtroFecha.currentIndex > 0) {
            var hoy = new Date();
            var fechaDesde, fechaHasta;
            
            switch(filtroFecha.currentText) {
                case "Hoy":
                    fechaDesde = new Date(hoy);
                    fechaHasta = new Date(hoy);
                    break;
                case "Esta Semana":
                    // Obtener el lunes de esta semana
                    fechaDesde = new Date(hoy);
                    var diaSemana = fechaDesde.getDay(); // 0=Domingo, 1=Lunes, etc.
                    var diffLunes = fechaDesde.getDate() - diaSemana + (diaSemana === 0 ? -6 : 1);
                    fechaDesde.setDate(diffLunes);
                    
                    // Obtener el domingo de esta semana
                    fechaHasta = new Date(fechaDesde);
                    fechaHasta.setDate(fechaDesde.getDate() + 6);
                    break;
                case "Este Mes":
                    // Primer día del mes
                    fechaDesde = new Date(hoy.getFullYear(), hoy.getMonth(), 1);
                    
                    // Último día del mes
                    fechaHasta = new Date(hoy.getFullYear(), hoy.getMonth() + 1, 0);
                    break;
            }
            
            // Formatear fechas a YYYY-MM-DD
            filtros.fecha_desde = fechaDesde.toISOString().split('T')[0];
            filtros.fecha_hasta = fechaHasta.toISOString().split('T')[0];
            
            console.log("📅 Filtro fecha aplicado:", filtroFecha.currentText, 
                    "Desde:", filtros.fecha_desde, "Hasta:", filtros.fecha_hasta);
    }
    
        console.log("🔍 Filtros construidos:", JSON.stringify(filtros))
        
        laboratorioModel.aplicar_filtros_y_recargar(
            filtros.search_term || "",
            filtros.tipo_analisis || "",
            filtros.tipo_servicio || "",
            filtros.fecha_desde || "",
            filtros.fecha_hasta || ""
        )
    }
    
    // 🎯 FUNCIÓN MEJORADA - AHORA INCLUYE DETALLES DEL EXAMEN
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
                        // ⭐ NUEVO: Agregar detalles del examen
                        detallesExamen: examen.detallesExamen || examen.detalles || ""
                    })
                }
                
                console.log("✅ Modelo actualizado con", analisisPaginadosModel.count, "elementos (incluyendo detalles)")
            } else {
                console.log("No hay exámenes disponibles")
            }
        } catch (error) {
            console.log("❌ Error actualizando modelo:", error)
        }
    }
    

    function editarAnalisis(viewIndex, analisisId) {
        // Buscar por ID en el modelo actual de la página
        var idToFind = parseInt(analisisId)
        var realIndex = -1
        
        // CAMBIAR: usar analisisPaginadosModel en lugar de analisisListModel
        for (var i = 0; i < analisisPaginadosModel.count; i++) {
            if (parseInt(analisisPaginadosModel.get(i).analisisId) === idToFind) {
                realIndex = i
                break
            }
        }
        
        if (realIndex >= 0) {
            isEditMode = true
            editingIndex = realIndex
            showNewAnalysisDialog = true
        } else {
            console.error("Análisis no encontrado:", idToFind)
        }
    }

    // 🎯 FUNCIÓN DE GUARDAR MEJORADA CON MEJOR MANEJO DE ERRORES
    function guardarAnalisis() {
        try {
            console.log("🎯 Iniciando guardado - Modo:", isEditMode ? "EDITAR" : "CREAR")
            
            if (isEditMode && editingIndex >= 0) {
                actualizarAnalisis()
            } else {
                crearNuevoAnalisis()
            }
            
        } catch (error) {
            console.log("❌ Error en coordinador de guardado:", error.message)
            analysisForm.enabled = true
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
            
            // Mostrar loading
            analysisForm.enabled = false
            
            // 1. Gestionar paciente (buscar o crear)
            var pacienteId = buscarOCrearPacientePorCedula()
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
            analysisForm.enabled = true
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
            
            // Validar que estamos en modo edición
            if (!isEditMode || editingIndex < 0) {
                throw new Error("No hay análisis seleccionado para editar")
            }
            
            // Mostrar loading
            analysisForm.enabled = true
            
            // 1. Obtener análisis existente
            var analisisExistente = analisisPaginadosModel.get(editingIndex)
            if (!analisisExistente) {
                throw new Error("Análisis a editar no encontrado")
            }
            
            var analisisId = parseInt(analisisExistente.analisisId)
            if (analisisId <= 0) {
                throw new Error("ID de análisis inválido: " + analisisId)
            }
            
            // 2. Obtener datos del formulario
            var datosAnalisis = obtenerDatosFormulario()
            
            console.log("📝 Actualizando análisis ID:", analisisId)
            console.log("   - Tipo análisis ID:", datosAnalisis.tipoAnalisisId)  
            console.log("   - Tipo servicio:", datosAnalisis.tipoServicio)
            console.log("   - Trabajador ID:", datosAnalisis.trabajadorId)
            console.log("   - Detalles:", datosAnalisis.detalles)
            
            // 3. Actualizar en el backend
            var resultado = laboratorioModel.actualizarExamen(
                analisisId,
                datosAnalisis.tipoAnalisisId,
                datosAnalisis.tipoServicio,
                datosAnalisis.trabajadorId,
                datosAnalisis.detalles
            )
            
            // 4. Procesar resultado
            procesarResultadoActualizacion(resultado)
            
        } catch (error) {
            console.log("❌ Error actualizando análisis:", error.message)
            analysisForm.enabled = true
            mostrarNotificacion("Error", error.message)
        }
    }
    function buscarOCrearPacientePorCedula() {
        if (!laboratorioModel) {
            throw new Error("LaboratorioModel no disponible")
        }
        
        var nombre = nombrePaciente.text.trim()
        var apellidoP = apellidoPaterno.text.trim()
        var apellidoM = apellidoMaterno.text.trim()
        var cedula = cedulaPaciente.text.trim()
        
        // Validaciones
        if (!cedula || cedula.length < 5) {
            throw new Error("Cédula inválida: " + cedula)
        }
        if (!nombre || nombre.length < 2) {
            throw new Error("Nombre inválido: " + nombre)
        }
        if (!apellidoP || apellidoP.length < 2) {
            throw new Error("Apellido paterno inválido: " + apellidoP)
        }
        
        console.log("📄 Gestionando paciente:", nombre, apellidoP, "- Cédula:", cedula)
        
        var pacienteId = laboratorioModel.buscar_o_crear_paciente_inteligente(
            nombre,
            apellidoP, 
            apellidoM,
            cedula
        )
        
        if (!pacienteId || pacienteId <= 0) {
            throw new Error("Error: ID de paciente inválido: " + pacienteId)
        }
        
        console.log("✅ Paciente gestionado correctamente - ID:", pacienteId)
        return pacienteId
    }

    function buscarPacientePorCedula(cedula) {
        if (!laboratorioModel || cedula.length < 5) return
        
        console.log("Buscando paciente con cédula:", cedula)
        
        // Limpiar estado anterior
        cedulaPaciente.pacienteNoEncontrado = false
        
        var pacienteData = laboratorioModel.buscar_paciente_por_cedula(cedula.trim())
        
        if (pacienteData && pacienteData.id) {
            autocompletarDatosPaciente(pacienteData)
        } else {
            console.log("No se encontró paciente con cédula:", cedula)
            marcarPacienteNoEncontrado(cedula)
        }
    }
    
    function marcarPacienteNoEncontrado(cedula) {
        cedulaPaciente.pacienteNoEncontrado = true
        cedulaPaciente.pacienteAutocompletado = false
        
        // Limpiar campos pero mantener la cédula
        nombrePaciente.text = ""
        apellidoPaterno.text = ""
        apellidoMaterno.text = ""
        
        console.log("⚠️ Paciente no encontrado. Habilitando modo crear nuevo paciente.")
    }
    
    function habilitarNuevoPaciente() {
        console.log("✅ Habilitando creación de nuevo paciente con cédula:", cedulaPaciente.text)
        
        // Mantener la cédula ingresada
        cedulaPaciente.pacienteNoEncontrado = true
        cedulaPaciente.pacienteAutocompletado = false
        
        // Limpiar campos de nombre para edición
        nombrePaciente.text = ""
        apellidoPaterno.text = ""
        apellidoMaterno.text = ""
        
        // Enfocar en el primer campo editable
        nombrePaciente.forceActiveFocus()
    }

    function autocompletarDatosPaciente(paciente) {
        nombrePaciente.text = paciente.Nombre || paciente.nombre || ""
        apellidoPaterno.text = paciente.Apellido_Paterno || paciente.apellido_paterno || ""
        apellidoMaterno.text = paciente.Apellido_Materno || paciente.apellido_materno || ""
        
        // Marcar como encontrado y autocompletado
        cedulaPaciente.pacienteAutocompletado = true
        cedulaPaciente.pacienteNoEncontrado = false
        apellidoPaterno.pacienteAutocompletado = true
        apellidoMaterno.pacienteAutocompletado = true
        
        console.log("✅ Paciente encontrado y autocompletado:", paciente.nombre_completo || "")
    }

    function limpiarDatosPacienteMejorado() {
        cedulaPaciente.text = ""
        nombrePaciente.text = ""
        apellidoPaterno.text = ""
        apellidoMaterno.text = ""
        
        // Resetear estados
        cedulaPaciente.pacienteAutocompletado = false
        cedulaPaciente.pacienteNoEncontrado = false
        cedulaPaciente.buscandoPaciente = false
        
        // Hacer campos editables
        nombrePaciente.readOnly = false
        apellidoPaterno.readOnly = false
        apellidoMaterno.readOnly = false
        
        console.log("🧹 Datos del paciente limpiados")
    }
    
    function limpiarYCerrarDialogo() {
        console.log("🚪 Cerrando diálogo de análisis...")
        
        try {
            // Reactivar formulario si estaba deshabilitado
            if (analysisForm) {
                analysisForm.enabled = true
            }
            
            // Cerrar diálogo
            showNewAnalysisDialog = false
            
            // Limpiar estados
            selectedRowIndex = -1
            isEditMode = false
            editingIndex = -1
            
            // Limpiar todos los campos
            clearAllFields()
            
            console.log("✅ Diálogo cerrado y limpiado correctamente")
            
        } catch (error) {
            console.log("⚠️ Error limpiando diálogo:", error)
            // Forzar cierre básico
            showNewAnalysisDialog = false
            if (analysisForm) analysisForm.enabled = true
        }
    }
    
    function clearAllFields() {
        console.log("🧹 Limpiando todos los campos del formulario...")
        
        // Limpiar datos del paciente
        limpiarDatosPaciente()
        
        // Limpiar formulario
        detallesAnalisis.text = ""
        
        // Resetear combos
        if (analisisCombo) analisisCombo.currentIndex = 0
        if (trabajadorCombo) trabajadorCombo.currentIndex = 0
        
        // Resetear radio buttons
        if (normalRadio) normalRadio.checked = true
        if (emergenciaRadio) emergenciaRadio.checked = false
        
        // Resetear propiedades del formulario
        analysisForm.selectedAnalysisIndex = -1
        analysisForm.calculatedPrice = 0.0
        analysisForm.analysisType = "Normal"
        
        // Enfocar en cédula
        if (cedulaPaciente) {
            cedulaPaciente.forceActiveFocus()
        }
        
        console.log("✅ Campos limpiados correctamente")
    }
    
    function initializarModelo() {
        console.log("✅ LaboratorioModel disponible, inicializando datos...")
        
        if (!laboratorioModel) {
            console.log("❌ Error: laboratorioModel es null")
            return
        }
        
        try {
            // Configurar elementos por página según tamaño de pantalla
            var elementosPorPagina = Math.max(6, Math.min(Math.floor(height / (baseUnit * 7)), 20))
            console.log("📊 Configurando elementos por página:", elementosPorPagina)
            
            // Establecer tamaño de página
            if (laboratorioModel.itemsPerPage !== elementosPorPagina) {
                laboratorioModel.itemsPerPage = elementosPorPagina
            }
            
            // Cargar datos iniciales del backend
            laboratorioModel.cargarTiposAnalisis()
            laboratorioModel.cargarTrabajadores()
            
            // ✅ FORZAR LIMPIEZA DE FILTROS AL INICIALIZAR
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
        if (laboratorioModel) {
            var currentPage = laboratorioModel._currentPage || 0
            if (currentPage > 0) {
                aplicarFiltros() // Esto recargará con los filtros actuales
            }
        }
    }

    function irAPaginaSiguiente() {
        if (laboratorioModel) {
            var currentPage = laboratorioModel._currentPage || 0
            var totalPages = laboratorioModel._totalPages || 1
            if (currentPage < totalPages - 1) {
                aplicarFiltros() // Esto recargará con los filtros actuales
            }
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

    Component.onCompleted: {
        console.log("🔬 Módulo Laboratorio iniciado con lógica mejorada")
        
        function conectarModelos() {
            if (typeof appController !== 'undefined') {
                laboratorioModel = appController.laboratorio_model_instance
                
                if (laboratorioModel) {
                    // Conectar señales críticas
                    laboratorioModel.examenesActualizados.connect(function() {
                        console.log("🔄 Exámenes actualizados - forzando refresh")
                        updatePaginatedModel()
                    })
                    
                    // Verificar métodos disponibles
                    console.log("🔍 Verificando métodos disponibles:")
                    console.log("   - actualizarExamen:", typeof laboratorioModel.actualizarExamen === 'function' ? "✅" : "❌")
                    console.log("   - editarExamen:", typeof laboratorioModel.editarExamen === 'function' ? "✅" : "❌")
                    console.log("   - crearExamen:", typeof laboratorioModel.crearExamen === 'function' ? "✅" : "❌")
                    console.log("   - refrescarDatos:", typeof laboratorioModel.refrescarDatos === 'function' ? "✅" : "❌")
                    
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
    function validarFormularioAnalisis() {
        console.log("✅ Validando formulario...")
        
        if (analysisForm.selectedAnalysisIndex < 0) {
            mostrarNotificacion("Error", "Debe seleccionar un tipo de análisis")
            return false
        }
        
        if (!cedulaPaciente.text || cedulaPaciente.text.length < 5) {
            mostrarNotificacion("Error", "Debe ingresar una cédula válida (mínimo 5 dígitos)")
            return false
        }
        
        if (!nombrePaciente.text || nombrePaciente.text.length < 2) {
            mostrarNotificacion("Error", "Nombre del paciente es obligatorio")
            return false
        }
        
        // Validación adicional para pacientes nuevos
        if (cedulaPaciente.pacienteNoEncontrado) {
            if (!apellidoPaterno.text || apellidoPaterno.text.length < 2) {
                mostrarNotificacion("Error", "Apellido paterno es obligatorio para pacientes nuevos")
                return false
            }
        }
        
        console.log("✅ Formulario válido")
        return true
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
            
            if (analysisForm.selectedAnalysisIndex >= tiposData.length) {
                throw new Error("Índice de análisis fuera de rango")
            }
            
            var tipoAnalisisSeleccionado = tiposData[analysisForm.selectedAnalysisIndex]
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
                tipoServicio: analysisForm.analysisType,
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
            console.log("🔄 Procesando resultado de creación:", resultado)
            
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
            
            analysisForm.enabled = true
            
        } catch (error) {
            console.log("❌ Error procesando resultado de creación:", error.message)
            analysisForm.enabled = true
            throw error
        }
    }

    function procesarResultadoActualizacion(resultado) {
        try {
            console.log("🔄 Procesando resultado de actualización:", resultado)
            
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
            
            analysisForm.enabled = true
            
        } catch (error) {
            console.log("❌ Error procesando resultado de actualización:", error.message)
            analysisForm.enabled = true
            throw error
        }
    }
}