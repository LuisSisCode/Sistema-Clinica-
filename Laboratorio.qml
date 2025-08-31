import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import Clinica.Models 1.0
import "./components/laboratory"


Item {
    id: laboratorioRoot
    objectName: "laboratorioRoot"

    // ACCESO AL MODELO DE BACKEND
    property var laboratorioModel: null
    
    // SISTEMA DE ESTILOS ADAPTABLES INTEGRADO
    readonly property real baseUnit: parent.baseUnit || Math.max(8, Screen.height / 100)
    readonly property real fontBaseSize: parent.fontBaseSize || Math.max(12, Screen.height / 70)
    readonly property real scaleFactor: parent.scaleFactor || Math.min(width / 1400, height / 900)
    
    // PROPIEDADES DE TAMAÑO MEJORADAS
    readonly property real iconSize: Math.max(baseUnit * 3, 24)
    readonly property real buttonIconSize: Math.max(baseUnit * 2, 18)

    // PROPIEDADES DE COLOR MEJORADAS
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

    // Usuario actual del sistema
    readonly property string currentUser: "Dr. Luis González"
    readonly property string currentUserRole: "Médico Laboratorista"
    
    // Propiedades para los diálogos del análisis
    property bool isEditMode: false
    property int editingIndex: -1
    property int selectedRowIndex: -1
    property bool showNewAnalysisDialog: false

    // PROPIEDADES DE PAGINACIÓN
    property int itemsPerPageLaboratorio: calcularElementosPorPagina()
    property int currentPageLaboratorio: 0
    property int totalPagesLaboratorio: 0

    // NUEVA PROPIEDAD PARA DATOS ORIGINALES
    property var analisisOriginales: []

    // DATOS DESDE EL BACKEND
    property var trabajadoresDisponibles: laboratorioModel ? laboratorioModel.trabajadoresJson : "[]"
    property var tiposAnalisis: laboratorioModel ? laboratorioModel.tiposAnalisisJson : "[]"

    // DATOS LIMPIOS
    property var analisisModelData: []
    
    // PROPIEDADES PARA FILTROS
    property var filtrosActivos: ({
        "busqueda": "",
        "tipo_analisis": "",
        "tipo": "",
        "fecha_desde": "",
        "fecha_hasta": ""
    })

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
    
    // CONEXIONES CON EL MODELO
    Connections {
        target: laboratorioModel
        enabled: laboratorioModel !== null
        
        function onExamenCreado(datos) {
            console.log("Análisis creado:", datos)
            showNewAnalysisDialog = false
            cargarDatosDesdeModelo()
        }
        
        function onErrorOcurrido(mensaje, codigo) {
            console.log("Error en operación:", mensaje)
        }
        
        function onExamenActualizado(datos) {
            console.log("Análisis actualizado:", datos)
            showNewAnalysisDialog = false
            selectedRowIndex = -1
            cargarDatosDesdeModelo()
        }

        function onExamenEliminado(examenId) {
            console.log("Análisis eliminado:", examenId)
            cargarDatosDesdeModelo()
        }

        function onExamenesActualizados() {
            cargarDatosDesdeModelo()
        }
    }

    // MODELOS SEPARADOS PARA PAGINACIÓN
    ListModel {
        id: analisisListModel // Modelo filtrado
    }
    
    ListModel {
        id: analisisPaginadosModel // Modelo para la página actual
    }

    // FUNCIÓN PARA CALCULAR ELEMENTOS POR PÁGINA
    function calcularElementosPorPagina() {
        var alturaDisponible = height - baseUnit * 25
        var alturaFila = baseUnit * 7
        var elementosCalculados = Math.floor(alturaDisponible / alturaFila)
        
        return Math.max(6, Math.min(elementosCalculados, 15))
    }

    // RECALCULAR PAGINACIÓN CUANDO CAMBIE EL TAMAÑO
    onHeightChanged: {
        var nuevosElementos = calcularElementosPorPagina()
        if (nuevosElementos !== itemsPerPageLaboratorio) {
            itemsPerPageLaboratorio = nuevosElementos
            updatePaginatedModel()
        }
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
                                            if (nombre) modelData.push(nombre)
                                        }
                                    } catch (e) {
                                        console.log("Error parseando tipos análisis:", e)
                                    }
                                    return modelData
                                }
                                currentIndex: 0
                                onCurrentIndexChanged: aplicarFiltros()
                                
                                contentItem: Label {
                                    text: filtroAnalisis.displayText
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
                                        
                                        // ANÁLISIS COLUMN
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
                            
                            onClicked: {
                                if (currentPageLaboratorio > 0) {
                                    currentPageLaboratorio--
                                    updatePaginatedModel()
                                }
                            }
                        }
                        
                        Label {
                            text: "Página " + (currentPageLaboratorio + 1) + " de " + Math.max(1, totalPagesLaboratorio)
                            color: textColor
                            font.pixelSize: fontBaseSize * 0.9
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
                            
                            onClicked: {
                                if (currentPageLaboratorio < totalPagesLaboratorio - 1) {
                                    currentPageLaboratorio++
                                    updatePaginatedModel()
                                }
                            }
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
                var analisis = analisisListModel.get(editingIndex)
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
                                
                                background: Rectangle {
                                    color: cedulaPaciente.pacienteAutocompletado ? "#F0F8FF" : whiteColor
                                    border.color: cedulaPaciente.activeFocus ? primaryColor : borderColor
                                    border.width: cedulaPaciente.activeFocus ? 2 : 1
                                    radius: baseUnit * 0.6
                                    
                                    Text {
                                        anchors.right: parent.right
                                        anchors.rightMargin: baseUnit
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: cedulaPaciente.text.length >= 5 ? "🔍" : "🔒"
                                        font.pixelSize: fontBaseSize * 1.2
                                        visible: cedulaPaciente.text.length > 0
                                    }
                                }
                                
                                onTextChanged: {
                                    if (text.length >= 5 && !cedulaPaciente.pacienteAutocompletado) {
                                        buscarTimer.restart()
                                    } else if (text.length === 0) {
                                        limpiarDatosPaciente()
                                    }
                                }
                                
                                onActiveFocusChanged: {
                                    if (!activeFocus) {
                                        // Timer para cerrar panel si existe
                                    }
                                }
                                
                                Keys.onReturnPressed: {
                                    if (cedulaPaciente.text.length >= 5) {
                                        buscarPacientePorCedula(cedulaPaciente.text)
                                    }
                                }
                                
                            }
                            
                            Button {
                                text: "Limpiar"
                                visible: cedulaPaciente.pacienteAutocompletado || nombrePaciente.text.length > 0
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
                            }
                        }
                        
                        // AGREGAR TIMER PARA EVITAR CONSULTAS EXCESIVAS
                        Timer {
                            id: buscarTimer
                            interval: 500 // 500ms de delay
                            running: false
                            repeat: false
                            onTriggered: buscarPacientePorCedula(cedulaPaciente.text.trim())
                        }
                        
                        // Campos de datos del paciente (solo lectura una vez encontrado)
                        TextField {
                            id: nombrePaciente
                            Layout.fillWidth: true
                            Layout.preferredHeight: baseUnit * 4
                            placeholderText: "Nombre del paciente"
                            readOnly: true
                            font.pixelSize: fontBaseSize * 0.9
                            font.family: "Segoe UI, Arial, sans-serif"
                            
                            background: Rectangle {
                                color: "#F8F9FA"
                                border.color: borderColor
                                border.width: 1
                                radius: baseUnit * 0.6
                            }
                        }
                        
                        RowLayout {
                            Layout.fillWidth: true
                            
                            TextField {
                                id: apellidoPaterno
                                Layout.fillWidth: true
                                Layout.preferredHeight: baseUnit * 4
                                placeholderText: "Apellido paterno"
                                readOnly: true
                                font.pixelSize: fontBaseSize * 0.9
                                font.family: "Segoe UI, Arial, sans-serif"
                                
                                property bool pacienteAutocompletado: false
                                
                                background: Rectangle {
                                    color: "#F8F9FA"
                                    border.color: borderColor
                                    border.width: 1
                                    radius: baseUnit * 0.6
                                }
                            }
                            
                            TextField {
                                id: apellidoMaterno
                                Layout.fillWidth: true
                                Layout.preferredHeight: baseUnit * 4
                                placeholderText: "Apellido materno"
                                readOnly: true
                                font.pixelSize: fontBaseSize * 0.9
                                font.family: "Segoe UI, Arial, sans-serif"
                                
                                property bool pacienteAutocompletado: false
                                
                                background: Rectangle {
                                    color: "#F8F9FA"
                                    border.color: borderColor
                                    border.width: 1
                                    radius: baseUnit * 0.6
                                }
                            }
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
                        model: {
                            var list = ["Seleccionar tipo de análisis..."]
                            try {
                                var tiposData = JSON.parse(tiposAnalisis)
                                for (var i = 0; i < tiposData.length; i++) {
                                    list.push(tiposData[i].nombre || tiposData[i].Nombre)
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
                        enabled: analysisForm.selectedAnalysisIndex >= 0 && 
                            nombrePaciente.text.length >= 2 && 
                            apellidoPaterno.text.length >= 1 &&
                            cedulaPaciente.text.length >= 5
                        Layout.preferredHeight: baseUnit * 4
                        
                        background: Rectangle {
                            color: {
                                if (!parent.enabled) return "#bdc3c7"
                                return primaryColor
                            }
                            radius: baseUnit
                        }
                        
                        contentItem: Label {
                            text: parent.text
                            color: whiteColor
                            font.bold: true
                            font.pixelSize: fontBaseSize * 0.9
                            font.family: "Segoe UI, Arial, sans-serif"
                            horizontalAlignment: Text.AlignHCenter
                        }
                        
                        onClicked: {
                            guardarAnalisis()
                        }
                    }
                }
            }
        }
    }

    // ===== FUNCIONES JAVASCRIPT =====
    
    function aplicarFiltros() {
        console.log("🔍 Aplicando filtros en laboratorio...")
        
        analisisListModel.clear()
        
        var hoy = new Date()
        var textoBusqueda = campoBusqueda.text ? campoBusqueda.text.toLowerCase() : ""
        
        for (var i = 0; i < analisisOriginales.length; i++) {
            var analisis = analisisOriginales[i]
            var mostrar = true
            
            // Filtro por fecha
            if (filtroFecha.currentIndex > 0) {
                var fechaAnalisis = new Date(analisis.fecha)
                var diferenciaDias = Math.floor((hoy - fechaAnalisis) / (1000 * 60 * 60 * 24))
                
                switch(filtroFecha.currentIndex) {
                    case 1: // Hoy
                        if (diferenciaDias !== 0) mostrar = false
                        break
                    case 2: // Esta Semana
                        if (diferenciaDias > 7) mostrar = false
                        break
                    case 3: // Este Mes
                        if (diferenciaDias > 30) mostrar = false
                        break
                }
            }
            
            // Filtro por tipo de análisis
            if (filtroAnalisis.currentIndex > 0 && mostrar) {
                var tipoSeleccionado = filtroAnalisis.currentText
                if (analisis.tipoAnalisis !== tipoSeleccionado) {
                    mostrar = false
                }
            }
            
            // Filtro por tipo
            if (filtroTipo.currentIndex > 0 && mostrar) {
                var tipoSeleccionado = filtroTipo.currentIndex === 1 ? "Normal" : "Emergencia"
                if (analisis.tipo !== tipoSeleccionado) {
                    mostrar = false
                }
            }
            
            // Filtro por texto de búsqueda
            if (textoBusqueda.length > 0 && mostrar) {
                var pacienteNombre = analisis.paciente.toLowerCase()
                var pacienteCedula = (analisis.pacienteCedula || "").toLowerCase()
                if (!pacienteNombre.includes(textoBusqueda) && !pacienteCedula.includes(textoBusqueda)) {
                    mostrar = false
                }
            }
            
            if (mostrar) {
                analisisListModel.append(analisis)
            }
        }
        
        currentPageLaboratorio = 0
        updatePaginatedModel()
        
        console.log("✅ Filtros aplicados. Análisis mostrados:", analisisListModel.count)
    }

    function updatePaginatedModel() {
        console.log("🔄 Laboratorio: Actualizando paginación - Página:", currentPageLaboratorio + 1)
        
        analisisPaginadosModel.clear()
        
        var totalItems = analisisListModel.count
        totalPagesLaboratorio = Math.ceil(totalItems / itemsPerPageLaboratorio)
        
        if (totalPagesLaboratorio === 0) {
            totalPagesLaboratorio = 1
        }
        
        if (currentPageLaboratorio >= totalPagesLaboratorio && totalPagesLaboratorio > 0) {
            currentPageLaboratorio = totalPagesLaboratorio - 1
        }
        if (currentPageLaboratorio < 0) {
            currentPageLaboratorio = 0
        }
        
        var startIndex = currentPageLaboratorio * itemsPerPageLaboratorio
        var endIndex = Math.min(startIndex + itemsPerPageLaboratorio, totalItems)
        
        for (var i = startIndex; i < endIndex; i++) {
            var analisis = analisisListModel.get(i)
            analisisPaginadosModel.append(analisis)
        }
        
        console.log("🔄 Laboratorio: Página", currentPageLaboratorio + 1, "de", totalPagesLaboratorio,
                    "- Mostrando", analisisPaginadosModel.count, "de", totalItems,
                    "- Elementos por página:", itemsPerPageLaboratorio)
    }

    function editarAnalisis(realIndex, analisisId) {
        // Buscar por ID numérico
        var idToFind = parseInt(analisisId)
        var realIndex = -1
        
        for (var i = 0; i < analisisListModel.count; i++) {
            if (parseInt(analisisListModel.get(i).analisisId) === idToFind) {
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

    function guardarAnalisis() {
        // Validaciones
        if (analysisForm.selectedAnalysisIndex < 0) {
            console.log("Debe seleccionar un tipo de análisis")
            return
        }
        if (!cedulaPaciente.text || cedulaPaciente.text.length < 5) {
            console.log("Debe ingresar una cédula válida")
            return
        }
        if (!nombrePaciente.text || nombrePaciente.text.length < 2) {
            console.log("Paciente no encontrado. Verifique la cédula.")
            return
        }

        try {
            if (isEditMode && editingIndex >= 0) {
                // Actualizar análisis existente
                var analisisExistente = analisisListModel.get(editingIndex)
                var tiposData = JSON.parse(tiposAnalisis)
                var tipoAnalisisId = tiposData[analysisForm.selectedAnalysisIndex].id
                
                var trabajadorId = 0
                if (trabajadorCombo.currentIndex > 0) {
                    var trabajadoresData = JSON.parse(trabajadoresDisponibles)
                    if (trabajadorCombo.currentIndex - 1 < trabajadoresData.length) {
                        trabajadorId = trabajadoresData[trabajadorCombo.currentIndex - 1].id
                    }
                }
                
                var resultado = laboratorioModel.actualizarExamen(
                    parseInt(analisisExistente.analisisId),
                    tipoAnalisisId,
                    analysisForm.analysisType,
                    trabajadorId,
                    detallesAnalisis.text
                )
                
                console.log("Resultado actualización:", resultado)
            } else {
                // Crear nuevo análisis - buscar o crear paciente por cédula
                var pacienteId = buscarOCrearPacientePorCedula()
                
                if (pacienteId <= 0) {
                    console.log("Error gestionando datos del paciente")
                    return
                }
                
                var tiposData = JSON.parse(tiposAnalisis)
                var tipoAnalisisId = tiposData[analysisForm.selectedAnalysisIndex].id
                
                var trabajadorId = 0
                if (trabajadorCombo.currentIndex > 0) {
                    var trabajadoresData = JSON.parse(trabajadoresDisponibles)
                    if (trabajadorCombo.currentIndex - 1 < trabajadoresData.length) {
                        trabajadorId = trabajadoresData[trabajadorCombo.currentIndex - 1].id
                    }
                }
                
                var resultado = laboratorioModel.crearExamen(
                    pacienteId,
                    tipoAnalisisId,
                    analysisForm.analysisType,
                    trabajadorId,
                    detallesAnalisis.text
                )
                
                console.log("Resultado creación:", resultado)
            }
        } catch (error) {
            console.log("Error inesperado:", error)
        }
    }

    function buscarOCrearPacientePorCedula() {
        if (!laboratorioModel) {
            console.error("❌ LaboratorioModel no disponible")
            return -1
        }
        
        var pacienteId = laboratorioModel.buscar_o_crear_paciente_inteligente(
            nombrePaciente.text || "Nombre",
            apellidoPaterno.text || "Apellido",
            apellidoMaterno.text || "",
            cedulaPaciente.text
        )
        
        return pacienteId
    }

    function buscarPacientePorCedula(cedula) {
        if (!laboratorioModel || cedula.length < 5) return
        
        console.log("Buscando paciente con cédula:", cedula)
        
        var pacienteData = laboratorioModel.buscar_paciente_por_cedula(cedula.trim())
        
        if (pacienteData && pacienteData.id) {
            autocompletarDatosPaciente(pacienteData)
        } else {
            console.log("No se encontró paciente con cédula:", cedula)
        }
    }

    function autocompletarDatosPaciente(paciente) {
        nombrePaciente.text = paciente.Nombre || paciente.nombre || ""
        apellidoPaterno.text = paciente.Apellido_Paterno || paciente.apellido_paterno || ""
        apellidoMaterno.text = paciente.Apellido_Materno || paciente.apellido_materno || ""
        
        // Marcar como autocompletado
        cedulaPaciente.pacienteAutocompletado = true
        apellidoPaterno.pacienteAutocompletado = true
        apellidoMaterno.pacienteAutocompletado = true
        
        console.log("✅ Paciente encontrado y autocompletado:", paciente.nombre_completo || "")
    }

    function limpiarDatosPaciente() {
        cedulaPaciente.text = ""
        nombrePaciente.text = ""
        apellidoPaterno.text = ""
        apellidoMaterno.text = ""
        
        cedulaPaciente.pacienteAutocompletado = false
        apellidoPaterno.pacienteAutocompletado = false
        apellidoMaterno.pacienteAutocompletado = false
        
        cedulaPaciente.forceActiveFocus()
    }
    
    function limpiarYCerrarDialogo() {
        showNewAnalysisDialog = false
        selectedRowIndex = -1
        isEditMode = false
        editingIndex = -1
    }
    
    function clearAllFields() {
        limpiarDatosPaciente()
        detallesAnalisis.text = ""
        analisisCombo.currentIndex = 0
        trabajadorCombo.currentIndex = 0
        normalRadio.checked = true
        
        analysisForm.selectedAnalysisIndex = -1
        analysisForm.calculatedPrice = 0.0
        
        cedulaPaciente.forceActiveFocus()
    }
    
    function initializarModelo() {
        console.log("✅ LaboratorioModel disponible, inicializando datos...")
        
        if (laboratorioModel) {
            // Cargar datos iniciales del backend
            laboratorioModel.cargarExamenes()
            laboratorioModel.cargarTiposAnalisis()
            laboratorioModel.cargarTrabajadores()
            
            // Cargar datos en la interfaz
            cargarDatosDesdeModelo()
        }
    }
    
    function cargarDatosDesdeModelo() {
        try {
            console.log("🔄 Cargando datos desde modelo de laboratorio...")
            
            // Obtener JSON directamente del modelo
            var examenesJson = laboratorioModel.examenesJson
            console.log("📋 ExamenesJSON longitud:", examenesJson.length)
            
            if (!examenesJson || examenesJson.length < 10) {
                console.log("⚠️ No hay datos en examenesJson, usando array vacío")
                analisisOriginales = []
                analisisListModel.clear()
                updatePaginatedModel()
                return
            }
            
            var examenes = JSON.parse(examenesJson)
            console.log("✅ JSON parseado, examenes encontrados:", examenes.length)
            
            analisisOriginales = []
            analisisListModel.clear()
            
            for (var i = 0; i < examenes.length; i++) {
                var examen = examenes[i]
                
                // Construir item de análisis con datos seguros
                var analisisItem = {
                    // IDs y básicos
                    analisisId: (examen.analisisId || examen.id || (i + 1)).toString(),
                    
                    // Información del paciente (SIN EDAD)
                    paciente: examen.paciente || examen.paciente_completo || "Paciente Desconocido",
                    pacienteCedula: examen.pacienteCedula || examen.paciente_cedula || "",
                    pacienteNombre: examen.pacienteNombre || examen.paciente_nombre || "",
                    pacienteApellidoP: examen.pacienteApellidoP || examen.paciente_apellido_p || "",
                    pacienteApellidoM: examen.pacienteApellidoM || examen.paciente_apellido_m || "",
                    
                    // Información del análisis
                    tipoAnalisis: examen.tipoAnalisis || examen.tipo_analisis || "Análisis General",
                    detalles: examen.detalles || "Sin detalles",
                    detallesExamen: examen.detallesExamen || examen.detalles_examen || "",
                    tipo: examen.tipo || "Normal",
                    
                    // Precio
                    precio: (examen.precio || "0.00").toString(),
                    
                    // Trabajador
                    trabajadorAsignado: examen.trabajadorAsignado || examen.trabajador_completo || "Sin asignar",
                    
                    // Fecha y usuario
                    fecha: examen.fecha || new Date().toISOString().split('T')[0],
                    registradoPor: examen.registradoPor || examen.registrado_por || "Sistema"
                }
                
                analisisOriginales.push(analisisItem)
                analisisListModel.append(analisisItem)
            }
            
            updatePaginatedModel()
            console.log("✅ Datos cargados correctamente:", analisisOriginales.length, "análisis")
            
        } catch (error) {
            console.error("❌ Error cargando datos:", error)
            // Datos de prueba si hay error
            analisisOriginales = []
            analisisListModel.clear()
            updatePaginatedModel()
        }
    }
    
    Component.onCompleted: {
        console.log("🔬 Módulo Laboratorio iniciado")
        
        if (laboratorioModel) {
            initializarModelo()
        }
        
        console.log("📱 Elementos por página calculados:", itemsPerPageLaboratorio)
    }
}