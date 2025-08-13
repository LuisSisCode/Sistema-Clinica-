import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

Item {
    id: laboratorioRoot
    objectName: "laboratorioRoot"
    
    // ACCESO A PROPIEDADES ADAPTATIVAS DEL MAIN
    readonly property real baseUnit: parent.baseUnit || Math.max(8, Screen.height / 100)
    readonly property real fontBaseSize: parent.fontBaseSize || Math.max(12, Screen.height / 70)
    readonly property real scaleFactor: parent.scaleFactor || Math.min(width / 1400, height / 900)
    
    // Colores (mantener)
    readonly property color primaryColor: "#3498DB"
    readonly property color successColor: "#27ae60"
    readonly property color dangerColor: "#E74C3C"
    readonly property color warningColor: "#f39c12"
    readonly property color lightGrayColor: "#ECF0F1"
    readonly property color textColor: "#2c3e50"
    readonly property color whiteColor: "#FFFFFF"
    readonly property color emergencyColor: "#e67e22"
    
    // Propiedades para los diálogos (mantener)
    property bool showNewLabTestDialog: false
    property bool showConfigTiposAnalisisDialog: false
    property bool isEditMode: false
    property int editingIndex: -1
    property int selectedRowIndex: -1

    // PAGINACIÓN ADAPTATIVA
    property int itemsPerPageLaboratorio: calcularElementosPorPagina()
    property int currentPageLaboratorio: 0
    property int totalPagesLaboratorio: 0

    // Datos originales (mantener)
    property var analisisOriginales: []

    // Modelo de tipos de análisis (mantener)
    property var tiposAnalisis: [
        { 
            nombre: "Hemograma Completo", 
            detalles: "Análisis completo de células sanguíneas, incluye recuento de glóbulos rojos, blancos y plaquetas",
            precioNormal: 25.0,
            precioEmergencia: 45.0
        },
        { 
            nombre: "Glucosa en Sangre", 
            detalles: "Medición de niveles de glucosa en sangre en ayunas",
            precioNormal: 15.0,
            precioEmergencia: 25.0
        },
        { 
            nombre: "Perfil Lipídico", 
            detalles: "Evaluación de colesterol total, HDL, LDL y triglicéridos",
            precioNormal: 35.0,
            precioEmergencia: 55.0
        },
        { 
            nombre: "Examen General de Orina", 
            detalles: "Análisis físico, químico y microscópico de orina",
            precioNormal: 18.0,
            precioEmergencia: 28.0
        },
        { 
            nombre: "Proteína C Reactiva", 
            detalles: "Marcador de inflamación e infección",
            precioNormal: 22.0,
            precioEmergencia: 35.0
        },
        { 
            nombre: "Creatinina", 
            detalles: "Evaluación de función renal",
            precioNormal: 20.0,
            precioEmergencia: 32.0
        },
        { 
            nombre: "Ácido Úrico", 
            detalles: "Medición de niveles de ácido úrico en sangre",
            precioNormal: 18.0,
            precioEmergencia: 28.0
        }
    ]

    // Modelo de trabajadores de laboratorio (mantener)
    property var trabajadoresLab: [
        "Lic. Carmen Ruiz",
        "Lic. Roberto Silva", 
        "Lic. Ana Martínez",
        "Lic. Pedro González"
    ]

    // Datos de ejemplo ampliados (mantener)
    property var analisisModelData: [
        {
            analisisId: "1",
            paciente: "Ana María López",
            tipoAnalisis: "Hemograma Completo",
            detalles: "Análisis completo de células sanguíneas, incluye recuento de glóbulos rojos, blancos y plaquetas",
            tipo: "Normal",
            precio: "25.00",
            trabajadorAsignado: "Lic. Carmen Ruiz",
            fecha: "2025-06-15",
            registradoPor: "Luis López"
        },
        {
            analisisId: "2",
            paciente: "Carlos Eduardo Martínez",
            tipoAnalisis: "Glucosa en Sangre",
            detalles: "Medición de niveles de glucosa en sangre en ayunas",
            tipo: "Emergencia",
            precio: "25.00",
            trabajadorAsignado: "Lic. Roberto Silva",
            fecha: "2025-06-16",
            registradoPor: "Luis López"
        },
        {
            analisisId: "3",
            paciente: "Elena Isabel Vargas",
            tipoAnalisis: "Perfil Lipídico",
            detalles: "Evaluación de colesterol total, HDL, LDL y triglicéridos",
            tipo: "Normal",
            precio: "35.00",
            trabajadorAsignado: "Lic. Carmen Ruiz",
            fecha: "2025-06-17",
            registradoPor: "Luis López"
        },
        {
            analisisId: "4",
            paciente: "Roberto Silva",
            tipoAnalisis: "Examen General de Orina",
            detalles: "Análisis físico, químico y microscópico de orina",
            tipo: "Normal",
            precio: "18.00",
            trabajadorAsignado: "Lic. Ana Martínez",
            fecha: "2025-06-17",
            registradoPor: "Luis López"
        },
        {
            analisisId: "5",
            paciente: "Patricia González",
            tipoAnalisis: "Proteína C Reactiva",
            detalles: "Marcador de inflamación e infección",
            tipo: "Emergencia",
            precio: "35.00",
            trabajadorAsignado: "Lic. Pedro González",
            fecha: "2025-06-18",
            registradoPor: "Luis López"
        },
        {
            analisisId: "6",
            paciente: "José Antonio Morales",
            tipoAnalisis: "Creatinina",
            detalles: "Evaluación de función renal",
            tipo: "Normal",
            precio: "20.00",
            trabajadorAsignado: "Lic. Roberto Silva",
            fecha: "2025-06-19",
            registradoPor: "Luis López"
        },
        {
            analisisId: "7",
            paciente: "Carmen Rosa Delgado",
            tipoAnalisis: "Ácido Úrico",
            detalles: "Medición de niveles de ácido úrico en sangre",
            tipo: "Normal",
            precio: "18.00",
            trabajadorAsignado: "Lic. Ana Martínez",
            fecha: "2025-06-20",
            registradoPor: "Luis López"
        },
        {
            analisisId: "8",
            paciente: "Ricardo Herrera",
            tipoAnalisis: "Hemograma Completo",
            detalles: "Análisis completo de células sanguíneas, incluye recuento de glóbulos rojos, blancos y plaquetas",
            tipo: "Emergencia",
            precio: "45.00",
            trabajadorAsignado: "Lic. Carmen Ruiz",
            fecha: "2025-06-21",
            registradoPor: "Luis López"
        },
        {
            analisisId: "9",
            paciente: "Patricia Sánchez",
            tipoAnalisis: "Glucosa en Sangre",
            detalles: "Medición de niveles de glucosa en sangre en ayunas",
            tipo: "Normal",
            precio: "15.00",
            trabajadorAsignado: "Lic. Pedro González",
            fecha: "2025-06-22",
            registradoPor: "Luis López"
        },
        {
            analisisId: "10",
            paciente: "Fernando Gómez",
            tipoAnalisis: "Perfil Lipídico",
            detalles: "Evaluación de colesterol total, HDL, LDL y triglicéridos",
            tipo: "Normal",
            precio: "35.00",
            trabajadorAsignado: "Lic. Ana Martínez",
            fecha: "2025-06-23",
            registradoPor: "Luis López"
        },
        {
            analisisId: "11",
            paciente: "Isabella Ramírez",
            tipoAnalisis: "Examen General de Orina",
            detalles: "Análisis físico, químico y microscópico de orina",
            tipo: "Emergencia",
            precio: "28.00",
            trabajadorAsignado: "Lic. Roberto Silva",
            fecha: "2025-06-24",
            registradoPor: "Luis López"
        },
        {
            analisisId: "12",
            paciente: "Miguel Ángel Torres",
            tipoAnalisis: "Proteína C Reactiva",
            detalles: "Marcador de inflamación e infección",
            tipo: "Normal",
            precio: "22.00",
            trabajadorAsignado: "Lic. Carmen Ruiz",
            fecha: "2025-06-25",
            registradoPor: "Luis López"
        }
    ]

    // Modelos (mantener)
    ListModel {
        id: analisisListModel
    }
    
    ListModel {
        id: analisisPaginadosModel
    }

    // FUNCIÓN PARA CALCULAR ELEMENTOS POR PÁGINA ADAPTATIVAMENTE
    function calcularElementosPorPagina() {
        var alturaDisponible = height - baseUnit * 25 // Headers, filtros, paginación
        var alturaFila = baseUnit * 6
        var elementosCalculados = Math.floor(alturaDisponible / alturaFila)
        
        // Límites inteligentes: mínimo 8, máximo 20
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
            border.color: "#e0e0e0"
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                
                // HEADER ADAPTATIVO
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: baseUnit * 8
                    color: "#f8f9fa"
                    border.color: "#e0e0e0"
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
                                horizontalAlignment: Text.AlignHCenter
                            }
                            
                            onClicked: {
                                isEditMode = false
                                editingIndex = -1
                                showNewLabTestDialog = true
                            }
                        }
                        
                        Button {
                            id: configButton
                            text: "⚙️"
                            Layout.preferredWidth: baseUnit * 4.5
                            Layout.preferredHeight: baseUnit * 4.5
                            
                            background: Rectangle {
                                color: "#6c757d"
                                radius: baseUnit
                            }
                            
                            contentItem: Label {
                                text: parent.text
                                color: whiteColor
                                font.pixelSize: fontBaseSize * 1.1
                                horizontalAlignment: Text.AlignHCenter
                            }
                            
                            onClicked: configMenu.open()
                            
                            Menu {
                                id: configMenu
                                y: parent.height
                                
                                MenuItem {
                                    text: "🧪 Configuración de Tipos de Análisis"
                                    onTriggered: showConfigTiposAnalisisDialog = true
                                }
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
                                border.color: "#e0e0e0"
                                border.width: 1
                                radius: baseUnit * 0.8
                            }
                            
                            leftPadding: baseUnit * 1.5
                            rightPadding: baseUnit * 1.5
                            font.pixelSize: fontBaseSize * 0.9
                        }
                    }
                }
                
                // TABLA ADAPTATIVA CON COLUMNAS PORCENTUALES
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.margins: baseUnit * 3
                    Layout.topMargin: 0
                    color: "#FFFFFF"
                    border.color: "#D5DBDB"
                    border.width: 1
                    radius: baseUnit
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 0
                        spacing: 0
                        
                        // HEADER DE TABLA CON PORCENTAJES
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: baseUnit * 5
                            color: "#f5f5f5"
                            border.color: "#d0d0d0"
                            border.width: 1
                            z: 5
                            
                            RowLayout {
                                anchors.fill: parent
                                spacing: 0
                                
                                Rectangle {
                                    Layout.preferredWidth: parent.width * 0.04 // 4% para ID
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#d0d0d0"
                                    border.width: 1
                                    
                                    Label { 
                                        anchors.centerIn: parent
                                        text: "ID"
                                        font.bold: true
                                        font.pixelSize: fontBaseSize * 0.8
                                        color: textColor
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: parent.width * 0.12 // 12% para PACIENTE
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#d0d0d0"
                                    border.width: 1
                                    
                                    Label { 
                                        anchors.centerIn: parent
                                        text: "PACIENTE"
                                        font.bold: true
                                        font.pixelSize: fontBaseSize * 0.8
                                        color: textColor
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: parent.width * 0.30 // 30% para ANÁLISIS
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#d0d0d0"
                                    border.width: 1
                                    
                                    Label { 
                                        anchors.centerIn: parent
                                        text: "ANÁLISIS"
                                        font.bold: true
                                        font.pixelSize: fontBaseSize * 0.8
                                        color: textColor
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: parent.width * 0.07 // 7% para TIPO
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#d0d0d0"
                                    border.width: 1
                                    
                                    Label { 
                                        anchors.centerIn: parent
                                        text: "TIPO"
                                        font.bold: true
                                        font.pixelSize: fontBaseSize * 0.8
                                        color: textColor
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: parent.width * 0.07 // 7% para PRECIO
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#d0d0d0"
                                    border.width: 1
                                    
                                    Label { 
                                        anchors.centerIn: parent
                                        text: "PRECIO"
                                        font.bold: true
                                        font.pixelSize: fontBaseSize * 0.8
                                        color: textColor
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: parent.width * 0.15 // 15% para TRABAJADOR
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#d0d0d0"
                                    border.width: 1
                                    
                                    Label { 
                                        anchors.centerIn: parent
                                        text: "TRABAJADOR"
                                        font.bold: true
                                        font.pixelSize: fontBaseSize * 0.8
                                        color: textColor
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: parent.width * 0.16 // 16% para REGISTRADO POR
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#d0d0d0"
                                    border.width: 1
                                    
                                    Label { 
                                        anchors.centerIn: parent
                                        text: "REGISTRADO POR"
                                        font.bold: true
                                        font.pixelSize: fontBaseSize * 0.8
                                        color: textColor
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: parent.width * 0.09// 9% para FECHA (resto)
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#d0d0d0"
                                    border.width: 1
                                    
                                    Label { 
                                        anchors.centerIn: parent
                                        text: "FECHA"
                                        font.bold: true
                                        font.pixelSize: fontBaseSize * 0.8
                                        color: textColor
                                    }
                                }
                            }
                        }
                        
                        // CONTENIDO DE TABLA CON SCROLL
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            
                            ListView {
                                id: analisisListView
                                model: analisisPaginadosModel
                                
                                delegate: Rectangle {
                                    width: ListView.view.width
                                    height: baseUnit * 6
                                    color: {
                                        if (selectedRowIndex === index) return "#e3f2fd"
                                        return index % 2 === 0 ? "transparent" : "#fafafa"
                                    }
                                    border.color: selectedRowIndex === index ? primaryColor : "#e8e8e8"
                                    border.width: selectedRowIndex === index ? 2 : 1
                                    
                                    RowLayout {
                                        anchors.fill: parent
                                        spacing: 0
                                        
                                        Rectangle {
                                            Layout.preferredWidth: parent.width * 0.04
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Label { 
                                                anchors.centerIn: parent
                                                text: model.analisisId
                                                color: textColor
                                                font.bold: true
                                                font.pixelSize: fontBaseSize * 0.8
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: parent.width * 0.12
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Label { 
                                                anchors.fill: parent
                                                anchors.margins: baseUnit * 0.3
                                                text: model.paciente
                                                color: textColor
                                                font.bold: true
                                                font.pixelSize: fontBaseSize * 0.8
                                                elide: Text.ElideRight
                                                wrapMode: Text.WordWrap
                                                maximumLineCount: 2
                                                verticalAlignment: Text.AlignVCenter
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: parent.width * 0.30
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
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
                                                }
                                                Label { 
                                                    Layout.fillWidth: true
                                                    text: model.detalles
                                                    color: "#7f8c8d"
                                                    font.pixelSize: fontBaseSize * 0.65
                                                    wrapMode: Text.WordWrap
                                                    elide: Text.ElideRight
                                                    maximumLineCount: 2
                                                }
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: parent.width * 0.07
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: baseUnit * 4.5
                                                height: baseUnit * 1.6
                                                color: model.tipo === "Emergencia" ? emergencyColor : successColor
                                                radius: baseUnit * 0.8
                                                
                                                Label {
                                                    anchors.centerIn: parent
                                                    text: model.tipo
                                                    color: whiteColor
                                                    font.pixelSize: fontBaseSize * 0.65
                                                    font.bold: true
                                                }
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: parent.width * 0.07
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Label { 
                                                anchors.centerIn: parent
                                                text: "Bs " + model.precio
                                                color: model.tipo === "Emergencia" ? emergencyColor : successColor
                                                font.bold: true
                                                font.pixelSize: fontBaseSize * 0.8
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: parent.width * 0.15
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Label { 
                                                anchors.fill: parent
                                                anchors.margins: baseUnit * 0.3
                                                text: model.trabajadorAsignado || "Sin asignar"
                                                color: model.trabajadorAsignado ? textColor : "#95a5a6"
                                                font.pixelSize: fontBaseSize * 0.7
                                                verticalAlignment: Text.AlignVCenter
                                                horizontalAlignment: Text.AlignHCenter
                                                elide: Text.ElideRight
                                                wrapMode: Text.WordWrap
                                                maximumLineCount: 2
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: parent.width * 0.16
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Label { 
                                                anchors.fill: parent
                                                anchors.margins: baseUnit * 0.3
                                                text: model.registradoPor || "Luis López"
                                                color: "#7f8c8d"
                                                font.pixelSize: fontBaseSize * 0.7
                                                elide: Text.ElideRight
                                                wrapMode: Text.WordWrap
                                                maximumLineCount: 2
                                                verticalAlignment: Text.AlignVCenter
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: parent.width * 0.9
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Label { 
                                                anchors.centerIn: parent
                                                text: {
                                                    var fecha = new Date(model.fecha)
                                                    return fecha.toLocaleDateString("es-ES", {
                                                        day: "2-digit",
                                                        month: "2-digit", 
                                                        year: "numeric"
                                                    })
                                                }
                                                color: textColor
                                                font.pixelSize: fontBaseSize * 0.75
                                                font.bold: true
                                            }
                                        }
                                    }
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            selectedRowIndex = index
                                            console.log("Seleccionado análisis ID:", model.analisisId)
                                        }
                                    }
                                    
                                    // BOTONES DE ACCIÓN ADAPTATIVOS
                                    RowLayout {
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: baseUnit * 0.5
                                        spacing: baseUnit * 0.3
                                        visible: selectedRowIndex === index
                                        z: 10
                                        
                                        Button {
                                            id: editButton
                                            width: baseUnit * 2.8
                                            height: baseUnit * 2.8
                                            text: "✏️"
                                            
                                            background: Rectangle {
                                                color: warningColor
                                                radius: baseUnit * 0.5
                                                border.color: "#f1c40f"
                                                border.width: 1
                                            }
                                            
                                            contentItem: Label {
                                                text: parent.text
                                                color: whiteColor
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                                font.pixelSize: fontBaseSize * 0.7
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
                                            width: baseUnit * 2.8
                                            height: baseUnit * 2.8
                                            text: "🗑️"
                                            
                                            background: Rectangle {
                                                color: dangerColor
                                                radius: baseUnit * 0.5
                                                border.color: "#c0392b"
                                                border.width: 1
                                            }
                                            
                                            contentItem: Label {
                                                text: parent.text
                                                color: whiteColor
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                                font.pixelSize: fontBaseSize * 0.7
                                            }
                                            
                                            onClicked: {
                                                var analisisId = model.analisisId
                                                
                                                for (var i = 0; i < analisisListModel.count; i++) {
                                                    if (analisisListModel.get(i).analisisId === analisisId) {
                                                        analisisListModel.remove(i)
                                                        break
                                                    }
                                                }
                                                
                                                for (var j = 0; j < analisisOriginales.length; j++) {
                                                    if (analisisOriginales[j].analisisId === analisisId) {
                                                        analisisOriginales.splice(j, 1)
                                                        break
                                                    }
                                                }
                                                
                                                selectedRowIndex = -1
                                                updatePaginatedModel()
                                                console.log("Análisis eliminado ID:", analisisId)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                // PAGINACIÓN ADAPTATIVA
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: baseUnit * 6
                    Layout.margins: baseUnit * 3
                    Layout.topMargin: 0
                    color: "#F8F9FA"
                    border.color: "#D5DBDB"
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
                                    (parent.pressed ? Qt.darker("#10B981", 1.1) : "#10B981") : 
                                    "#E5E7EB"
                                radius: baseUnit * 2
                                
                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                            
                            contentItem: Label {
                                text: parent.text
                                color: parent.enabled ? "#FFFFFF" : "#9CA3AF"
                                font.bold: true
                                font.pixelSize: fontBaseSize * 0.9
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
                            color: "#374151"
                            font.pixelSize: fontBaseSize * 0.9
                            font.weight: Font.Medium
                        }
                        
                        Button {
                            Layout.preferredWidth: baseUnit * 11
                            Layout.preferredHeight: baseUnit * 4
                            text: "Siguiente →"
                            enabled: currentPageLaboratorio < totalPagesLaboratorio - 1
                            
                            background: Rectangle {
                                color: parent.enabled ? 
                                    (parent.pressed ? Qt.darker("#10B981", 1.1) : "#10B981") : 
                                    "#E5E7EB"
                                radius: baseUnit * 2
                                
                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                            
                            contentItem: Label {
                                text: parent.text
                                color: parent.enabled ? "#FFFFFF" : "#9CA3AF"
                                font.bold: true
                                font.pixelSize: fontBaseSize * 0.9
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
                for (var i = 0; i < tiposAnalisis.length; i++) {
                    if (tiposAnalisis[i].nombre === tipoAnalisisNombre) {
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
                
                for (var j = 0; j < trabajadoresLab.length; j++) {
                    if (trabajadoresLab[j] === analisis.trabajadorAsignado) {
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
                color: textColor
                horizontalAlignment: Text.AlignHCenter
            }
            
            GroupBox {
                Layout.fillWidth: true
                title: "Datos del Paciente"
                
                background: Rectangle {
                    color: "#f8f9fa"
                    border.color: lightGrayColor
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
                        background: Rectangle {
                            color: whiteColor
                            border.color: lightGrayColor
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
                            background: Rectangle {
                                color: whiteColor
                                border.color: lightGrayColor
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
                            background: Rectangle {
                                color: whiteColor
                                border.color: lightGrayColor
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
                        }
                        TextField {
                            id: edadPaciente
                            Layout.preferredWidth: baseUnit * 10
                            Layout.preferredHeight: baseUnit * 4
                            placeholderText: "0"
                            validator: IntValidator { bottom: 0; top: 120 }
                            font.pixelSize: fontBaseSize * 0.9
                            background: Rectangle {
                                color: whiteColor
                                border.color: lightGrayColor
                                border.width: 1
                                radius: baseUnit * 0.6
                            }
                        }
                        Label {
                            text: "años"
                            color: textColor
                            font.pixelSize: fontBaseSize * 0.9
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
                }
                ComboBox {
                    id: tipoAnalisisCombo
                    Layout.fillWidth: true
                    Layout.preferredHeight: baseUnit * 4
                    model: {
                        var list = ["Seleccionar tipo de análisis..."]
                        for (var i = 0; i < tiposAnalisis.length; i++) {
                            list.push(tiposAnalisis[i].nombre)
                        }
                        return list
                    }
                    onCurrentIndexChanged: {
                        if (currentIndex > 0) {
                            labTestForm.selectedTipoAnalisisIndex = currentIndex - 1
                            var tipoAnalisis = tiposAnalisis[labTestForm.selectedTipoAnalisisIndex]
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
                }
                
                RadioButton {
                    id: normalRadio
                    text: "Normal"
                    checked: true
                    onCheckedChanged: {
                        if (checked) {
                            labTestForm.analisisType = "Normal"
                            if (labTestForm.selectedTipoAnalisisIndex >= 0) {
                                var tipoAnalisis = tiposAnalisis[labTestForm.selectedTipoAnalisisIndex]
                                labTestForm.calculatedPrice = tipoAnalisis.precioNormal
                            }
                        }
                    }
                    
                    contentItem: Label {
                        text: normalRadio.text
                        font.pixelSize: fontBaseSize * 0.9
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
                                var tipoAnalisis = tiposAnalisis[labTestForm.selectedTipoAnalisisIndex]
                                labTestForm.calculatedPrice = tipoAnalisis.precioEmergencia
                            }
                        }
                    }
                    
                    contentItem: Label {
                        text: emergenciaRadio.text
                        font.pixelSize: fontBaseSize * 0.9
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
                }
                ComboBox {
                    id: trabajadorCombo
                    Layout.fillWidth: true
                    Layout.preferredHeight: baseUnit * 4
                    model: {
                        var list = ["Seleccionar trabajador..."]
                        for (var i = 0; i < trabajadoresLab.length; i++) {
                            list.push(trabajadoresLab[i])
                        }
                        list.push("Sin asignar")
                        return list
                    }
                    
                    contentItem: Label {
                        text: trabajadorCombo.displayText
                        font.pixelSize: fontBaseSize * 0.8
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
                }
                Label {
                    text: labTestForm.selectedTipoAnalisisIndex >= 0 ? 
                          "Bs " + labTestForm.calculatedPrice.toFixed(2) : "Seleccione tipo de análisis"
                    font.bold: true
                    font.pixelSize: fontBaseSize * 1.1
                    color: labTestForm.analisisType === "Emergencia" ? emergencyColor : successColor
                }
                Item { Layout.fillWidth: true }
            }
            
            Item { Layout.fillHeight: true }
            
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
                        horizontalAlignment: Text.AlignHCenter
                    }
                    onClicked: {
                        var nombreCompleto = nombrePaciente.text + " " + 
                                           apellidoPaterno.text + " " + 
                                           apellidoMaterno.text
                        
                        var tipoAnalisis = tiposAnalisis[labTestForm.selectedTipoAnalisisIndex]
                        var trabajadorSeleccionado = trabajadorCombo.currentIndex > 0 && trabajadorCombo.currentIndex <= trabajadoresLab.length ?
                                                   trabajadoresLab[trabajadorCombo.currentIndex - 1] : ""
                        
                        var analisisData = {
                            paciente: nombreCompleto.trim(),
                            tipoAnalisis: tipoAnalisis.nombre,
                            detalles: tipoAnalisis.detalles,
                            tipo: labTestForm.analisisType,
                            precio: labTestForm.calculatedPrice.toFixed(2),
                            trabajadorAsignado: trabajadorSeleccionado,
                            fecha: new Date().toISOString().split('T')[0],
                            registradoPor: "Luis López"
                        }
                        
                        if (isEditMode && editingIndex >= 0) {
                            var analisisExistente = analisisListModel.get(editingIndex)
                            analisisData.analisisId = analisisExistente.analisisId
                            
                            analisisListModel.set(editingIndex, analisisData)
                            
                            for (var i = 0; i < analisisOriginales.length; i++) {
                                if (analisisOriginales[i].analisisId === analisisData.analisisId) {
                                    analisisOriginales[i] = analisisData
                                    break
                                }
                            }
                            
                            console.log("Análisis actualizado:", JSON.stringify(analisisData))
                        } else {
                            analisisData.analisisId = (getTotalLaboratorioCount() + 1).toString()
                            
                            analisisListModel.append(analisisData)
                            analisisOriginales.push(analisisData)
                            
                            console.log("Nuevo análisis guardado:", JSON.stringify(analisisData))
                        }
                        
                        updatePaginatedModel()
                        
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
            }
        }
    }

    // === DIÁLOGO DE CONFIGURACIÓN (adaptativo) ===
    Rectangle {
        id: configTiposAnalisisBackground
        anchors.fill: parent
        color: "black"
        opacity: showConfigTiposAnalisisDialog ? 0.5 : 0
        visible: opacity > 0
        
        MouseArea {
            anchors.fill: parent
            onClicked: showConfigTiposAnalisisDialog = false
        }
        
        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }
    }
    
    Rectangle {
        id: configTiposAnalisisDialog
        anchors.centerIn: parent
        width: Math.min(700, parent.width * 0.95)
        height: Math.min(600, parent.height * 0.9)
        color: whiteColor
        radius: baseUnit * 2
        border.color: lightGrayColor
        border.width: 2
        visible: showConfigTiposAnalisisDialog
        
        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: baseUnit * 40
                color: whiteColor
                radius: baseUnit * 2
                z: 10
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: baseUnit * 3
                    spacing: baseUnit * 2
                    
                    Label {
                        Layout.fillWidth: true
                        text: "🧪 Configuración de Tipos de Análisis"
                        font.pixelSize: fontBaseSize * 1.6
                        font.bold: true
                        color: textColor
                        horizontalAlignment: Text.AlignHCenter
                    }
                    
                    GroupBox {
                        Layout.fillWidth: true
                        title: "Agregar Nuevo Tipo de Análisis"
                        
                        background: Rectangle {
                            color: "#f8f9fa"
                            border.color: lightGrayColor
                            border.width: 1
                            radius: baseUnit
                        }
                        
                        GridLayout {
                            anchors.fill: parent
                            columns: 2
                            rowSpacing: baseUnit
                            columnSpacing: baseUnit
                            
                            Label {
                                text: "Nombre:"
                                font.bold: true
                                color: textColor
                                font.pixelSize: fontBaseSize * 0.9
                            }
                            TextField {
                                id: nuevoTipoAnalisisNombre
                                Layout.fillWidth: true
                                Layout.preferredHeight: baseUnit * 4
                                placeholderText: "Ej: Hemograma Completo"
                                font.pixelSize: fontBaseSize * 0.9
                                background: Rectangle {
                                    color: whiteColor
                                    border.color: lightGrayColor
                                    border.width: 1
                                    radius: baseUnit * 0.6
                                }
                            }
                            
                            Label {
                                text: "Detalles:"
                                font.bold: true
                                color: textColor
                                font.pixelSize: fontBaseSize * 0.9
                            }
                            ScrollView {
                                Layout.fillWidth: true
                                Layout.preferredHeight: baseUnit * 6
                                
                                TextArea {
                                    id: nuevoTipoAnalisisDetalles
                                    placeholderText: "Descripción del análisis..."
                                    wrapMode: TextArea.Wrap
                                    font.pixelSize: fontBaseSize * 0.9
                                    background: Rectangle {
                                        color: whiteColor
                                        border.color: lightGrayColor
                                        border.width: 1
                                        radius: baseUnit * 0.6
                                    }
                                }
                            }
                            
                            Label {
                                text: "Precio Normal:"
                                font.bold: true
                                color: textColor
                                font.pixelSize: fontBaseSize * 0.9
                            }
                            TextField {
                                id: nuevoTipoAnalisisPrecioNormal
                                Layout.fillWidth: true
                                Layout.preferredHeight: baseUnit * 4
                                placeholderText: "0.00"
                                validator: DoubleValidator { bottom: 0.0; decimals: 2 }
                                font.pixelSize: fontBaseSize * 0.9
                                background: Rectangle {
                                    color: whiteColor
                                    border.color: lightGrayColor
                                    border.width: 1
                                    radius: baseUnit * 0.6
                                }
                            }
                            
                            Label {
                                text: "Precio Emergencia:"
                                font.bold: true
                                color: textColor
                                font.pixelSize: fontBaseSize * 0.9
                            }
                            TextField {
                                id: nuevoTipoAnalisisPrecioEmergencia
                                Layout.fillWidth: true
                                Layout.preferredHeight: baseUnit * 4
                                placeholderText: "0.00"
                                validator: DoubleValidator { bottom: 0.0; decimals: 2 }
                                font.pixelSize: fontBaseSize * 0.9
                                background: Rectangle {
                                    color: whiteColor
                                    border.color: lightGrayColor
                                    border.width: 1
                                    radius: baseUnit * 0.6
                                }
                            }
                            
                            Item { }
                            Button {
                                Layout.alignment: Qt.AlignRight
                                Layout.preferredHeight: baseUnit * 4
                                text: "➕ Agregar Tipo de Análisis"
                                background: Rectangle {
                                    color: successColor
                                    radius: baseUnit
                                }
                                contentItem: Label {
                                    text: parent.text
                                    color: whiteColor
                                    font.bold: true
                                    font.pixelSize: fontBaseSize * 0.9
                                    horizontalAlignment: Text.AlignHCenter
                                }
                                onClicked: {
                                    if (nuevoTipoAnalisisNombre.text && nuevoTipoAnalisisDetalles.text && 
                                        nuevoTipoAnalisisPrecioNormal.text && nuevoTipoAnalisisPrecioEmergencia.text) {
                                        
                                        var nuevoTipoAnalisis = {
                                            nombre: nuevoTipoAnalisisNombre.text,
                                            detalles: nuevoTipoAnalisisDetalles.text,
                                            precioNormal: parseFloat(nuevoTipoAnalisisPrecioNormal.text),
                                            precioEmergencia: parseFloat(nuevoTipoAnalisisPrecioEmergencia.text)
                                        }
                                        
                                        tiposAnalisis.push(nuevoTipoAnalisis)
                                        laboratorioRoot.tiposAnalisis = tiposAnalisis
                                        
                                        nuevoTipoAnalisisNombre.text = ""
                                        nuevoTipoAnalisisDetalles.text = ""
                                        nuevoTipoAnalisisPrecioNormal.text = ""
                                        nuevoTipoAnalisisPrecioEmergencia.text = ""
                                        
                                        console.log("Nuevo tipo de análisis agregado:", JSON.stringify(nuevoTipoAnalisis))
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: baseUnit * 3
                Layout.topMargin: 0
                color: "transparent"
                
                ScrollView {
                    anchors.fill: parent
                    clip: true
                    
                    ListView {
                        model: tiposAnalisis
                        delegate: Rectangle {
                            width: ListView.view.width
                            height: baseUnit * 8
                            color: index % 2 === 0 ? "transparent" : "#fafafa"
                            border.color: "#e8e8e8"
                            border.width: 1
                            radius: baseUnit
                            
                            GridLayout {
                                anchors.fill: parent
                                anchors.margins: baseUnit
                                columns: 4
                                rowSpacing: baseUnit * 0.6
                                columnSpacing: baseUnit
                                
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: baseUnit * 0.4
                                    
                                    Label {
                                        text: modelData.nombre
                                        font.bold: true
                                        color: primaryColor
                                        font.pixelSize: fontBaseSize * 0.95
                                    }
                                    Label {
                                        text: modelData.detalles
                                        color: textColor
                                        font.pixelSize: fontBaseSize * 0.75
                                        wrapMode: Text.WordWrap
                                        elide: Text.ElideRight
                                        maximumLineCount: 2
                                    }
                                }
                                
                                ColumnLayout {
                                    Layout.preferredWidth: baseUnit * 10
                                    spacing: baseUnit * 0.4
                                    
                                    Label {
                                        text: "Normal"
                                        font.bold: true
                                        color: successColor
                                        font.pixelSize: fontBaseSize * 0.8
                                    }
                                    Label {
                                        text: "Bs " + modelData.precioNormal.toFixed(2)
                                        color: successColor
                                        font.bold: true
                                        font.pixelSize: fontBaseSize * 0.95
                                    }
                                }
                                
                                ColumnLayout {
                                    Layout.preferredWidth: baseUnit * 10
                                    spacing: baseUnit * 0.4
                                    
                                    Label {
                                        text: "Emergencia"
                                        font.bold: true
                                        color: emergencyColor
                                        font.pixelSize: fontBaseSize * 0.8
                                    }
                                    Label {
                                        text: "Bs " + modelData.precioEmergencia.toFixed(2)
                                        color: emergencyColor
                                        font.bold: true
                                        font.pixelSize: fontBaseSize * 0.95
                                    }
                                }
                                
                                Button {
                                    Layout.preferredWidth: baseUnit * 3.5
                                    Layout.preferredHeight: baseUnit * 3.5
                                    text: "🗑️"
                                    background: Rectangle {
                                        color: dangerColor
                                        radius: baseUnit * 0.6
                                    }
                                    contentItem: Label {
                                        text: parent.text
                                        color: whiteColor
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        font.pixelSize: fontBaseSize * 0.8
                                    }
                                    onClicked: {
                                        tiposAnalisis.splice(index, 1)
                                        laboratorioRoot.tiposAnalisis = tiposAnalisis
                                        console.log("Tipo de análisis eliminado en índice:", index)
                                    }
                                }
                            }
                        }
                    }
                }
            }      
        }
    }

    // ===== FUNCIONES (mantener todas con adaptaciones) =====
    
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
        
        for (var i = 0; i < analisisModelData.length; i++) {
            analisisOriginales.push(analisisModelData[i])
            analisisListModel.append(analisisModelData[i])
        }
        
        updatePaginatedModel()
        
        console.log("✅ Análisis cargados:", analisisOriginales.length)
        console.log("📱 Elementos por página calculados:", itemsPerPageLaboratorio)
    }
}