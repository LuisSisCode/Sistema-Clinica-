import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import Clinica.Models 1.0

Item {
    id: laboratorioRoot
    objectName: "laboratorioRoot"
    
    // ACCESO A PROPIEDADES ADAPTATIVAS DEL MAIN
    readonly property real baseUnit: parent.baseUnit || Math.max(8, Screen.height / 100)
    readonly property real fontBaseSize: parent.fontBaseSize || Math.max(12, Screen.height / 70)
    readonly property real scaleFactor: parent.scaleFactor || Math.min(width / 1400, height / 900)
    
    // Colores modernos (igual que Consultas)
    readonly property color primaryColor: "#3498DB"
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
    readonly property color borderColor: "#e0e0e0"
    readonly property color accentColor: "#10B981"
    readonly property color lineColor: "#D1D5DB"
    
    // Propiedades para los diálogos
    property bool showNewLabTestDialog: false
    property bool isEditMode: false
    property int editingIndex: -1
    property int selectedRowIndex: -1

    // PAGINACIÓN ADAPTATIVA
    property int itemsPerPageLaboratorio: calcularElementosPorPagina()
    property int currentPageLaboratorio: 0
    property int totalPagesLaboratorio: 0

    // Datos originales
    property var analisisOriginales: []

    // Distribución de columnas responsive (como en Consultas)
    readonly property real colId: 0.04
    readonly property real colPaciente: 0.15
    readonly property real colAnalisis: 0.25
    readonly property real colTipo: 0.10
    readonly property real colPrecio: 0.10
    readonly property real colTrabajador: 0.15
    readonly property real colRegistradoPor: 0.15
    readonly property real colFecha: 0.06

    property var tiposAnalisisDB: []
    property var trabajadoresDB: []

    // MODELO DE LABORATORIO PYTHON
    LaboratorioModel {
        id: laboratorioModel
        
        // Conectar señales del modelo
        onExamenesActualizados: {
            console.log("📊 Exámenes actualizados desde base de datos")
            cargarDatosDesdeModelo()
        }
        
        onOperacionExitosa: function(mensaje) {
            console.log("✅", mensaje)
            showSuccessMessage(mensaje)
        }
        
        onErrorOcurrido: function(mensaje, codigo) {
            console.error("❌", mensaje, codigo)
            showErrorMessage(mensaje)
        }
        
        onExamenCreado: function(datos) {
            console.log("🆕 Examen creado:", datos)
            cargarDatosDesdeModelo()
        }
        
        onExamenActualizado: function(datos) {
            console.log("🔄 Examen actualizado:", datos)
            cargarDatosDesdeModelo()
        }
        
        onExamenEliminado: function(examenId) {
            console.log("🗑️ Examen eliminado:", examenId)
            cargarDatosDesdeModelo()
        }
    }

    // Modelos
    ListModel {
        id: analisisListModel
    }
    
    ListModel {
        id: analisisPaginadosModel
    }

    // FUNCIÓN PARA CALCULAR ELEMENTOS POR PÁGINA ADAPTATIVAMENTE
    function calcularElementosPorPagina() {
        var alturaDisponible = height - baseUnit * 25
        var alturaFila = baseUnit * 6
        var elementosCalculados = Math.floor(alturaDisponible / alturaFila)
        
        return Math.max(8, Math.min(elementosCalculados, 20))
    }

    // RECALCULAR PAGINACIÓN CUANDO CAMBIE EL TAMAÑO
    onHeightChanged: {
        var nuevosElementos = calcularElementosPorPagina()
        if (nuevosElementos !== itemsPerPageLaboratorio) {
            itemsPerPageLaboratorio = nuevosElementos
            updatePaginatedModel()
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
                
                // HEADER ADAPTATIVO
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: baseUnit * 8
                    color: lightGrayColor
                    border.color: borderColor
                    border.width: 1
                    
                    Rectangle {
                        anchors.fill: parent
                        anchors.bottomMargin: baseUnit * 2
                        color: parent.color
                        radius: parent.radius
                    }
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: baseUnit * 1.5
                        
                        RowLayout {
                            spacing: baseUnit
                            
                            Label {
                                text: "🧪"
                                font.pixelSize: fontBaseSize * 1.8
                                color: primaryColor
                            }
                            
                            Label {
                                text: "Gestión de Análisis de Laboratorio"
                                font.pixelSize: fontBaseSize * 1.4
                                font.bold: true
                                font.family: "Segoe UI, Arial, sans-serif"
                                color: textColor
                            }
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        Button {
                            objectName: "newLabTestButton"
                            text: "➕ Nuevo Análisis"
                            Layout.preferredHeight: baseUnit * 4.5
                            
                            background: Rectangle {
                                color: primaryColor
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
                                isEditMode = false
                                editingIndex = -1
                                showNewLabTestDialog = true
                            }
                        }
                    }
                }
                
                // FILTROS ADAPTATIVOS
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: width < 800 ? baseUnit * 12 : baseUnit * 8
                    color: "transparent"
                    z: 10
                    
                    // Layout adaptativo: una fila en pantallas grandes, dos en pequeñas
                    GridLayout {
                        anchors.fill: parent
                        anchors.margins: baseUnit * 3
                        anchors.bottomMargin: baseUnit * 1.5
                        
                        columns: width < 800 ? 2 : 3
                        rowSpacing: baseUnit
                        columnSpacing: baseUnit * 2
                        
                        // Primera fila/grupo de filtros
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
                                text: "Tipo:"
                                font.bold: true
                                color: textColor
                                font.pixelSize: fontBaseSize * 0.9
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                            
                            ComboBox {
                                id: filtroTipo
                                Layout.fillWidth: true
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
                        
                        // Campo de búsqueda
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
                
                // TABLA MODERNA CON LÍNEAS VERTICALES (como en Consultas)
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
                            Layout.preferredHeight: baseUnit * 5
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
                                    height: baseUnit * 5
                                    color: {
                                        if (selectedRowIndex === index) return "#F8F9FA"
                                        return index % 2 === 0 ? whiteColor : "#FAFAFA"
                                    }
                                    
                                    // Borde horizontal inferior
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        height: 1
                                        color: borderColor
                                    }
                                    
                                    // Borde vertical de selección (izquierdo)
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: baseUnit * 0.4
                                        color: selectedRowIndex === index ? accentColor : "transparent"
                                        radius: baseUnit * 0.2
                                        visible: selectedRowIndex === index
                                        z: 3
                                    }
                                    
                                    // CONTENEDOR PRINCIPAL DE COLUMNAS
                                    RowLayout {
                                        id: columnsContainer
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
                                                text: model.analisisId
                                                color: textColor
                                                font.bold: false
                                                font.pixelSize: fontBaseSize * 0.9
                                                font.family: "Segoe UI, Arial, sans-serif"
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
                                        }
                                        
                                        // ANÁLISIS COLUMN
                                        Item {
                                            Layout.preferredWidth: parent.width * colAnalisis
                                            Layout.fillHeight: true
                                            
                                            ColumnLayout {
                                                anchors.fill: parent
                                                anchors.margins: baseUnit * 0.6
                                                spacing: baseUnit * 0.1
                                                
                                                Label { 
                                                    Layout.fillWidth: true
                                                    text: model.tipoAnalisis
                                                    color: primaryColor
                                                    font.bold: true
                                                    font.pixelSize: fontBaseSize * 0.75
                                                    elide: Text.ElideRight
                                                    maximumLineCount: 1
                                                    verticalAlignment: Text.AlignVCenter
                                                    font.family: "Segoe UI, Arial, sans-serif"
                                                }
                                                Label { 
                                                    Layout.fillWidth: true
                                                    text: model.detalles
                                                    color: textColorLight
                                                    font.pixelSize: fontBaseSize * 0.65
                                                    wrapMode: Text.WordWrap
                                                    elide: Text.ElideRight
                                                    maximumLineCount: 2
                                                    font.family: "Segoe UI, Arial, sans-serif"
                                                }
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
                                                color: model.trabajadorAsignado ? textColor : textColorLight
                                                font.pixelSize: fontBaseSize * 0.9
                                                font.family: "Segoe UI, Arial, sans-serif"
                                                elide: Text.ElideRight
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
                                                text: model.registradoPor || "Luis López"
                                                color: textColorLight
                                                font.pixelSize: fontBaseSize * 0.9
                                                font.family: "Segoe UI, Arial, sans-serif"
                                                elide: Text.ElideRight
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
                                                text: {
                                                    var fecha = new Date(model.fecha)
                                                    return fecha.toLocaleDateString("es-ES", {
                                                        day: "2-digit",
                                                        month: "2-digit", 
                                                        year: "numeric"
                                                    })
                                                }
                                                color: textColor
                                                font.bold: false
                                                font.pixelSize: fontBaseSize * 0.85
                                                font.family: "Segoe UI, Arial, sans-serif"
                                            }
                                        }
                                    }
                                    
                                    // LÍNEAS VERTICALES PERFECTAMENTE ALINEADAS
                                    Repeater {
                                        model: 7 // 7 líneas entre 8 columnas
                                        delegate: Rectangle {
                                            property real columnPosition: {
                                                switch(index) {
                                                    case 0: return colId;
                                                    case 1: return colId + colPaciente;
                                                    case 2: return colId + colPaciente + colAnalisis;
                                                    case 3: return colId + colPaciente + colAnalisis + colTipo;
                                                    case 4: return colId + colPaciente + colAnalisis + colTipo + colPrecio;
                                                    case 5: return colId + colPaciente + colAnalisis + colTipo + colPrecio + colTrabajador;
                                                    case 6: return colId + colPaciente + colAnalisis + colTipo + colPrecio + colTrabajador + colRegistradoPor;
                                                }
                                            }
                                            
                                            x: columnsContainer.x + columnsContainer.width * columnPosition
                                            width: 1
                                            height: parent.height
                                            color: lineColor
                                            z: 2
                                        }
                                    }
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            selectedRowIndex = selectedRowIndex === index ? -1 : index
                                            console.log("Seleccionado análisis ID:", model.analisisId)
                                        }
                                    }
                                    
                                    // BOTONES DE ACCIÓN
                                    RowLayout {
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: baseUnit * 0.8
                                        spacing: baseUnit * 0.5
                                        visible: selectedRowIndex === index
                                        z: 4
                                        
                                        Button {
                                            id: editButton
                                            width: baseUnit * 3.5
                                            height: baseUnit * 3.5
                                            text: "✏️"
                                            
                                            background: Rectangle {
                                                color: warningColor
                                                radius: baseUnit * 0.8
                                                border.color: "#e67e22"
                                                border.width: 1
                                            }
                                            
                                            contentItem: Label {
                                                text: parent.text
                                                color: whiteColor
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                                font.pixelSize: fontBaseSize * 0.85
                                            }
                                            
                                            onClicked: {
                                                var analisisId = model.analisisId
                                                var realIndex = -1
                                                
                                                for (var i = 0; i < analisisListModel.count; i++) {
                                                    if (analisisListModel.get(i).analisisId === analisisId) {
                                                        realIndex = i
                                                        break
                                                    }
                                                }
                                                
                                                isEditMode = true
                                                editingIndex = realIndex
                                                
                                                console.log("Editando análisis ID:", analisisId, "índice real:", realIndex)
                                                showNewLabTestDialog = true
                                            }
                                        }
                                        
                                        Button {
                                            id: deleteButton
                                            width: baseUnit * 3.5
                                            height: baseUnit * 3.5
                                            text: "🗑️"
                                            
                                            background: Rectangle {
                                                color: dangerColor
                                                radius: baseUnit * 0.8
                                                border.color: "#c0392b"
                                                border.width: 1
                                            }
                                            
                                            contentItem: Label {
                                                text: parent.text
                                                color: whiteColor
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                                font.pixelSize: fontBaseSize * 0.85
                                            }
                                            
                                            onClicked: {
                                                var analisisId = parseInt(model.analisisId)
                                                var exito = laboratorioModel.eliminarExamen(analisisId)
                                                
                                                if (exito) {
                                                    selectedRowIndex = -1
                                                    console.log("✅ Análisis eliminado exitosamente:", analisisId)
                                                } else {
                                                    console.error("❌ Error eliminando análisis:", analisisId)
                                                }
}
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                // PAGINACIÓN MODERNA (como en Consultas)
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

    // ===== DIÁLOGOS ADAPTATIVOS =====
    
    // Fondo del diálogo
    Rectangle {
        id: newLabTestDialog
        anchors.fill: parent
        color: "black"
        opacity: showNewLabTestDialog ? 0.5 : 0
        visible: opacity > 0
        
        MouseArea {
            anchors.fill: parent
            onClicked: {
                showNewLabTestDialog = false
                selectedRowIndex = -1
            }
        }
        
        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }
    }
    
    // Diálogo de análisis adaptativo
    Rectangle {
        id: labTestForm
        anchors.centerIn: parent
        width: Math.min(500, parent.width * 0.9)
        height: Math.min(700, parent.height * 0.9)
        color: whiteColor
        radius: baseUnit * 2
        border.color: lightGrayColor
        border.width: 2
        visible: showNewLabTestDialog
        
        property int selectedTipoAnalisisIndex: -1
        property string analisisType: "Normal"
        property real calculatedPrice: 0.0
        
        function loadEditData() {
            if (isEditMode && editingIndex >= 0) {
                var analisis = analisisListModel.get(editingIndex)
                
                var nombreCompleto = analisis.paciente.split(" ")
                nombrePaciente.text = nombreCompleto[0] || ""
                apellidoPaterno.text = nombreCompleto[1] || ""
                apellidoMaterno.text = nombreCompleto.slice(2).join(" ") || ""
                
                var tipoAnalisisNombre = analisis.tipoAnalisis
                for (var i = 0; i < tiposAnalisisDB.length; i++) {  // CAMBIAR AQUÍ
                    if (tiposAnalisisDB[i].nombre === tipoAnalisisNombre) {  // CAMBIAR AQUÍ
                        tipoAnalisisCombo.currentIndex = i + 1
                        labTestForm.selectedTipoAnalisisIndex = i
                        break
                    }
                }
                
                if (analisis.tipo === "Normal") {
                    normalRadio.checked = true
                    labTestForm.analisisType = "Normal"
                } else {
                    emergenciaRadio.checked = true
                    labTestForm.analisisType = "Emergencia"
                }
                
                labTestForm.calculatedPrice = parseFloat(analisis.precio)
                
                for (var j = 0; j < trabajadoresDB.length; j++) {  // CAMBIAR AQUÍ
                    if (trabajadoresDB[j] === analisis.trabajadorAsignado) {  // CAMBIAR AQUÍ
                        trabajadorCombo.currentIndex = j + 1
                        break
                    }
                }
            }
        }
        
        onVisibleChanged: {
            if (visible && isEditMode) {
                loadEditData()
            } else if (visible && !isEditMode) {
                nombrePaciente.text = ""
                apellidoPaterno.text = ""
                apellidoMaterno.text = ""
                edadPaciente.text = ""
                tipoAnalisisCombo.currentIndex = 0
                trabajadorCombo.currentIndex = 0
                normalRadio.checked = true
                labTestForm.selectedTipoAnalisisIndex = -1
                labTestForm.calculatedPrice = 0.0
            }
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: baseUnit * 3
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
                    
                    TextField {
                        id: nombrePaciente
                        Layout.fillWidth: true
                        Layout.preferredHeight: baseUnit * 4
                        placeholderText: "Nombre del paciente"
                        font.pixelSize: fontBaseSize * 0.9
                        font.family: "Segoe UI, Arial, sans-serif"
                        background: Rectangle {
                            color: whiteColor
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
                            font.pixelSize: fontBaseSize * 0.9
                            font.family: "Segoe UI, Arial, sans-serif"
                            background: Rectangle {
                                color: whiteColor
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
                            font.pixelSize: fontBaseSize * 0.9
                            font.family: "Segoe UI, Arial, sans-serif"
                            background: Rectangle {
                                color: whiteColor
                                border.color: borderColor
                                border.width: 1
                                radius: baseUnit * 0.6
                            }
                        }
                    }
                    
                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            Layout.preferredWidth: baseUnit * 12
                            text: "Edad:"
                            font.bold: true
                            color: textColor
                            font.pixelSize: fontBaseSize * 0.9
                            font.family: "Segoe UI, Arial, sans-serif"
                        }
                        TextField {
                            id: edadPaciente
                            Layout.preferredWidth: baseUnit * 10
                            Layout.preferredHeight: baseUnit * 4
                            placeholderText: "0"
                            validator: IntValidator { bottom: 0; top: 120 }
                            font.pixelSize: fontBaseSize * 0.9
                            font.family: "Segoe UI, Arial, sans-serif"
                            background: Rectangle {
                                color: whiteColor
                                border.color: borderColor
                                border.width: 1
                                radius: baseUnit * 0.6
                            }
                        }
                        Label {
                            text: "años"
                            color: textColor
                            font.pixelSize: fontBaseSize * 0.9
                            font.family: "Segoe UI, Arial, sans-serif"
                        }
                        Item { Layout.fillWidth: true }
                    }
                }
            }
            
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
                    id: tipoAnalisisCombo
                    Layout.fillWidth: true
                    Layout.preferredHeight: baseUnit * 4
                    model: {
                        var list = ["Seleccionar tipo de análisis..."]
                        for (var i = 0; i < tiposAnalisisDB.length; i++) {
                            list.push(tiposAnalisisDB[i].nombre)
                        }
                        return list
                    }
                    onCurrentIndexChanged: {
                        if (currentIndex > 0) {
                            labTestForm.selectedTipoAnalisisIndex = currentIndex - 1
                            var tipoAnalisis = tiposAnalisisDB[labTestForm.selectedTipoAnalisisIndex]  // CAMBIAR AQUÍ
                            if (labTestForm.analisisType === "Normal") {
                                labTestForm.calculatedPrice = tipoAnalisis.precioNormal
                            } else {
                                labTestForm.calculatedPrice = tipoAnalisis.precioEmergencia
                            }
                        } else {
                            labTestForm.selectedTipoAnalisisIndex = -1
                            labTestForm.calculatedPrice = 0.0
                        }
        }
                    
                    contentItem: Label {
                        text: tipoAnalisisCombo.displayText
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
                            labTestForm.analisisType = "Normal"
                            if (labTestForm.selectedTipoAnalisisIndex >= 0) {
                                var tipoAnalisis = tiposAnalisisDB[labTestForm.selectedTipoAnalisisIndex]  // CAMBIAR AQUÍ
                                labTestForm.calculatedPrice = tipoAnalisis.precioNormal
                            }
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
                            labTestForm.analisisType = "Emergencia"
                            if (labTestForm.selectedTipoAnalisisIndex >= 0) {
                                var tipoAnalisis = tiposAnalisisDB[labTestForm.selectedTipoAnalisisIndex]  // CAMBIAR AQUÍ
                                labTestForm.calculatedPrice = tipoAnalisis.precioEmergencia
                            }
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
                        for (var i = 0; i < trabajadoresDB.length; i++) {
                            list.push(trabajadoresDB[i])
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
                    text: labTestForm.selectedTipoAnalisisIndex >= 0 ? 
                          "Bs " + labTestForm.calculatedPrice.toFixed(2) : "Seleccione tipo de análisis"
                    font.bold: true
                    font.pixelSize: fontBaseSize * 1.1
                    font.family: "Segoe UI, Arial, sans-serif"
                    color: labTestForm.analisisType === "Emergencia" ? "#92400E" : "#047857"
                }
                Item { Layout.fillWidth: true }
            }
            
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
                        id: detallesConsulta
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
                        nombrePaciente.text = ""
                        apellidoPaterno.text = ""
                        apellidoMaterno.text = ""
                        edadPaciente.text = ""
                        tipoAnalisisCombo.currentIndex = 0
                        trabajadorCombo.currentIndex = 0
                        normalRadio.checked = true
                        showNewLabTestDialog = false
                        selectedRowIndex = -1
                        isEditMode = false
                        editingIndex = -1
                    }
                }
                
                Button {
                    text: isEditMode ? "Actualizar" : "Guardar"
                    enabled: labTestForm.selectedTipoAnalisisIndex >= 0 && 
                             nombrePaciente.text.length > 0
                    Layout.preferredHeight: baseUnit * 4
                    background: Rectangle {
                        color: parent.enabled ? primaryColor : "#bdc3c7"
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
                        // Validaciones previas
                        if (labTestForm.selectedTipoAnalisisIndex < 0) {
                            console.error("Tipo de análisis no seleccionado")
                            return
                        }
                        
                        try {
                            if (isEditMode && editingIndex >= 0) {
                                // Actualizar examen existente
                                var analisisExistente = analisisListModel.get(editingIndex)
                                var tipoAnalisisId = tiposAnalisisDB[labTestForm.selectedTipoAnalisisIndex].id
                                var trabajadorId = (trabajadorCombo.currentIndex > 0 && 
                                                trabajadorCombo.currentIndex <= trabajadoresDB.length) ? 
                                                trabajadorCombo.currentIndex : 0
                                
                                var resultado = laboratorioModel.actualizarExamen(
                                    parseInt(analisisExistente.analisisId),
                                    tipoAnalisisId,
                                    labTestForm.analisisType,
                                    detallesConsulta.text,
                                    trabajadorId
                                )
                                
                                var data = JSON.parse(resultado)
                                if (data.exito) {
                                    console.log("Examen actualizado exitosamente")
                                    limpiarYCerrarDialogo()
                                } else {
                                    console.error("Error actualizando:", data.error)
                                }
                            } else {
                                // Crear nuevo examen - Gestionar paciente inteligentemente
                                var pacienteId = pacienteModel.buscarOCrearPaciente(
                                    nombrePaciente.text,
                                    apellidoPaterno.text,
                                    apellidoMaterno.text,
                                    parseInt(edadPaciente.text) || 0
                                )
                                
                                if (pacienteId <= 0) {
                                    console.error("Error gestionando paciente")
                                    return
                                }
                                
                                var tipoAnalisisId = tiposAnalisisDB[labTestForm.selectedTipoAnalisisIndex].id
                                var trabajadorId = (trabajadorCombo.currentIndex > 0 && 
                                                trabajadorCombo.currentIndex <= trabajadoresDB.length) ? 
                                                trabajadorCombo.currentIndex : 0
                                
                                var resultado = laboratorioModel.crearExamen(
                                    pacienteId,  // Usa el ID correcto
                                    tipoAnalisisId,
                                    labTestForm.analisisType,
                                    trabajadorId
                                )
                                
                                var data = JSON.parse(resultado)
                                if (data.exito) {
                                    console.log("Examen creado exitosamente:", data.examen_id)
                                    limpiarYCerrarDialogo()
                                } else {
                                    console.error("Error creando:", data.error)
                                }
                            }
                            
                        } catch (error) {
                            console.error("Error procesando examen:", error)
                        }
                    }

                    // Función auxiliar para limpiar (agregar fuera del onClicked)
                    function limpiarYCerrarDialogo() {
                        showNewLabTestDialog = false
                        selectedRowIndex = -1
                        isEditMode = false
                        editingIndex = -1
                        
                        // Limpiar campos
                        nombrePaciente.text = ""
                        apellidoPaterno.text = ""
                        apellidoMaterno.text = ""
                        edadPaciente.text = ""
                        detallesConsulta.text = ""
                        tipoAnalisisCombo.currentIndex = 0
                        trabajadorCombo.currentIndex = 0
                        normalRadio.checked = true
                        
                        labTestForm.selectedTipoAnalisisIndex = -1
                        labTestForm.calculatedPrice = 0.0
                    }
                }
            }
        }
    }

    // ===== FUNCIONES =====
    
    function aplicarFiltros() {
        console.log("🔍 Aplicando filtros en laboratorio...")
        
        analisisListModel.clear()
        
        var hoy = new Date()
        var textoBusqueda = campoBusqueda.text.toLowerCase()
        
        for (var i = 0; i < analisisOriginales.length; i++) {
            var analisis = analisisOriginales[i]
            var mostrar = true
            
            if (filtroFecha.currentIndex > 0) {
                var fechaAnalisis = new Date(analisis.fecha)
                var diferenciaDias = Math.floor((hoy - fechaAnalisis) / (1000 * 60 * 60 * 24))
                
                switch(filtroFecha.currentIndex) {
                    case 1:
                        if (diferenciaDias !== 0) mostrar = false
                        break
                    case 2:
                        if (diferenciaDias > 7) mostrar = false
                        break
                    case 3:
                        if (diferenciaDias > 30) mostrar = false
                        break
                }
            }
            
            if (filtroTipo.currentIndex > 0 && mostrar) {
                var tipoSeleccionado = filtroTipo.model[filtroTipo.currentIndex]
                if (analisis.tipo !== tipoSeleccionado) {
                    mostrar = false
                }
            }
            
            if (textoBusqueda.length > 0 && mostrar) {
                if (!analisis.paciente.toLowerCase().includes(textoBusqueda)) {
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
        console.log("📄 Laboratorio: Actualizando paginación - Página:", currentPageLaboratorio + 1)
        
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
        
        console.log("📄 Laboratorio: Página", currentPageLaboratorio + 1, "de", totalPagesLaboratorio,
                    "- Mostrando", analisisPaginadosModel.count, "de", totalItems,
                    "- Elementos por página:", itemsPerPageLaboratorio)
    }
    
    function getTotalLaboratorioCount() {
        return analisisOriginales.length
    }
    
    Component.onCompleted: {
        console.log("🧪 Módulo Laboratorio iniciado")
        
        // Cargar datos desde el modelo Python
        laboratorioModel.cargarExamenes()
        laboratorioModel.cargarTiposAnalisis()
        laboratorioModel.cargarTrabajadores()
        
        // Cargar datos iniciales
        cargarTiposAnalisisDB()
        cargarTrabajadoresDB()
        cargarDatosDesdeModelo()
        
        console.log("📱 Elementos por página calculados:", itemsPerPageLaboratorio)
    }

    function cargarDatosDesdeModelo() {
        try {
            var examenesJson = laboratorioModel.examenesJson
            var examenes = JSON.parse(examenesJson)
            
            analisisOriginales = []
            analisisListModel.clear()
            
            for (var i = 0; i < examenes.length; i++) {
                var examen = examenes[i]
                
                // Determinar precio según tipo
                var precio = 0
                if (examen.Tipo === "Emergencia") {
                    precio = examen.Precio_Emergencia || 0
                } else {
                    precio = examen.Precio_Normal || 0
                }
                
                var analisisItem = {
                    analisisId: (examen.id || i + 1).toString(),
                    paciente: examen.paciente_completo || "Paciente Desconocido",
                    tipoAnalisis: examen.tipo_analisis || "Análisis General",
                    detalles: examen.detalles || "Sin detalles",
                    tipo: examen.Tipo || "Normal",
                    precio: precio.toFixed(2),
                    trabajadorAsignado: (examen.trabajador_completo && examen.trabajador_completo !== "Sin asignar") ? 
                                    examen.trabajador_completo : "",
                    fecha: new Date(examen.Fecha).toISOString().split('T')[0],
                    registradoPor: examen.registrado_por || "Usuario Sistema",
                    tipoAnalisisId: examen.Id_Tipo_Analisis,
                    pacienteId: examen.Id_Paciente
                }
                
                analisisOriginales.push(analisisItem)
                analisisListModel.append(analisisItem)
            }
            
            updatePaginatedModel()
            console.log("📊 Datos cargados desde BD:", analisisOriginales.length, "exámenes")
            
        } catch (error) {
            console.error("❌ Error cargando datos:", error)
        }
    }

    function cargarTiposAnalisisDB() {
        try {
            var resultado = laboratorioModel.obtenerTiposAnalisisDisponibles()
            console.log("🔍 Resultado tipos análisis:", resultado)
            
            var data = JSON.parse(resultado)
            
            if (data.exito && data.tipos) {
                tiposAnalisisDB = data.tipos.map(function(tipo) {
                    return {
                        id: tipo.id,
                        nombre: tipo.Nombre,
                        detalles: tipo.Descripcion || "Análisis de laboratorio",
                        precioNormal: tipo.Precio_Normal,
                        precioEmergencia: tipo.Precio_Emergencia
                    }
                })
                console.log("✅ Tipos análisis cargados:", tiposAnalisisDB.length)
            } else {
                console.log("⚠️ No se pudieron cargar tipos, usando fallback")
                tiposAnalisisDB = []
            }
        } catch (error) {
            console.error("❌ Error cargando tipos análisis:", error)
            tiposAnalisisDB = []
        }
}

    function cargarTrabajadoresDB() {
        try {
            var trabajadoresJson = laboratorioModel.trabajadoresJson
            console.log("🔍 JSON trabajadores:", trabajadoresJson)
            
            var trabajadores = JSON.parse(trabajadoresJson)
            
            trabajadoresDB = trabajadores.map(function(t) {
                return t.nombre_completo || t.trabajador_completo || "Trabajador Desconocido"
            })
            
            console.log("✅ Trabajadores cargados:", trabajadoresDB.length)
        } catch (error) {
            console.error("❌ Error cargando trabajadores:", error)
            trabajadoresDB = ["Lic. Carmen Ruiz", "Lic. Roberto Silva"]
        }
    }

    function showSuccessMessage(mensaje) {
        console.log("✅ Éxito:", mensaje)
        // Mostrar notificación visual de éxito
        Qt.createQmlObject('import QtQuick 2.15; import QtQuick.Controls 2.15; Rectangle { width: 300; height: 50; color: "#10B981"; radius: 8; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 40; z: 999; Label { anchors.centerIn: parent; text: "' + mensaje + '"; color: "white"; font.bold: true; font.pixelSize: 18; } Timer { interval: 2000; running: true; repeat: false; onTriggered: parent.destroy(); } }', laboratorioRoot, "successToast")
    }

    function showErrorMessage(mensaje) {
        console.log("❌ Error:", mensaje)
        // Mostrar notificación visual de error
        Qt.createQmlObject('import QtQuick 2.15; import QtQuick.Controls 2.15; Rectangle { width: 300; height: 50; color: "#E74C3C"; radius: 8; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 40; z: 999; Label { anchors.centerIn: parent; text: "' + mensaje + '"; color: "white"; font.bold: true; font.pixelSize: 18; } Timer { interval: 2500; running: true; repeat: false; onTriggered: parent.destroy(); } }', laboratorioRoot, "errorToast")
    }
}