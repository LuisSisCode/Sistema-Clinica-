import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

Item {
    id: laboratorioRoot
    objectName: "laboratorioRoot"
    
    // Acceso a colores
    readonly property color primaryColor: "#3498DB"
    readonly property color successColor: "#27ae60"
    readonly property color dangerColor: "#E74C3C"
    readonly property color warningColor: "#f39c12"
    readonly property color lightGrayColor: "#ECF0F1"
    readonly property color textColor: "#2c3e50"
    readonly property color whiteColor: "#FFFFFF"
    readonly property color emergencyColor: "#e67e22"
    
    // Propiedades para los diálogos
    property bool showNewLabTestDialog: false
    property bool showConfigTiposAnalisisDialog: false
    property bool isEditMode: false
    property int editingIndex: -1
    property int selectedRowIndex: -1

    // ✅ PROPIEDADES DE PAGINACIÓN CORREGIDAS
    property int itemsPerPageLaboratorio: 10
    property int currentPageLaboratorio: 0
    property int totalPagesLaboratorio: 0

    // ✅ NUEVA PROPIEDAD PARA DATOS ORIGINALES
    property var analisisOriginales: []

    // Modelo de tipos de análisis
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

    // Modelo de trabajadores de laboratorio
    property var trabajadoresLab: [
        "Lic. Carmen Ruiz",
        "Lic. Roberto Silva", 
        "Lic. Ana Martínez",
        "Lic. Pedro González"
    ]

    // ✅ DATOS AMPLIADOS PARA PROBAR PAGINACIÓN (12 análisis)
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

    // ✅ MODELOS SEPARADOS PARA PAGINACIÓN
    ListModel {
        id: analisisListModel // Modelo filtrado (todos los resultados del filtro)
    }
    
    ListModel {
        id: analisisPaginadosModel // Modelo para la página actual
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 40
        spacing: 32
        
        // Contenido principal
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: whiteColor
            radius: 20
            border.color: "#e0e0e0"
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                
                // Header de Laboratorio - FIJO
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    color: "#f8f9fa"
                    border.color: "#e0e0e0"
                    border.width: 1
                    Rectangle {
                        anchors.fill: parent
                        anchors.bottomMargin: 20
                        color: parent.color
                        radius: parent.radius
                    }
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        
                        RowLayout {
                            spacing: 12
                            
                            Label {
                                text: "🧪"
                                font.pixelSize: 24
                                color: primaryColor
                            }
                            
                            Label {
                                text: "Gestión de Análisis de Laboratorio"
                                font.pixelSize: 20
                                font.bold: true
                                color: textColor
                            }
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        Button {
                            objectName: "newLabTestButton"
                            text: "➕ Nuevo Análisis"
                            
                            background: Rectangle {
                                color: primaryColor
                                radius: 12
                            }
                            
                            contentItem: Label {
                                text: parent.text
                                color: whiteColor
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                            }
                            
                            onClicked: {
                                isEditMode = false
                                editingIndex = -1
                                showNewLabTestDialog = true
                            }
                        }
                        
                        // Botón de configuración (engranaje)
                        Button {
                            id: configButton
                            text: "⚙️"
                            font.pixelSize: 18
                            
                            background: Rectangle {
                                color: "#6c757d"
                                radius: 12
                            }
                            
                            contentItem: Label {
                                text: parent.text
                                color: whiteColor
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
                
                // ✅ FILTROS CON MÁS ESPACIO
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80  // ✅ AUMENTADO de 60 a 80
                    color: "transparent"
                    z: 10
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 32
                        anchors.bottomMargin: 16  // ✅ AGREGAR separación
                        spacing: 16
                        
                        Label {
                            text: "Filtrar por:"
                            font.bold: true
                            color: textColor
                        }
                        
                        ComboBox {
                            id: filtroFecha
                            Layout.preferredWidth: 150
                            model: ["Todas", "Hoy", "Esta Semana", "Este Mes"]
                            currentIndex: 0
                            onCurrentIndexChanged: aplicarFiltros()
                        }
                        
                        Label {
                            text: "Tipo:"
                            font.bold: true
                            color: textColor
                        }
                        
                        ComboBox {
                            id: filtroTipo
                            Layout.preferredWidth: 120
                            model: ["Todos", "Normal", "Emergencia"]
                            currentIndex: 0
                            onCurrentIndexChanged: aplicarFiltros()
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        TextField {
                            id: campoBusqueda
                            Layout.preferredWidth: 200
                            placeholderText: "Buscar por paciente..."
                            onTextChanged: aplicarFiltros()
                            
                            background: Rectangle {
                                color: whiteColor
                                border.color: "#e0e0e0"
                                border.width: 1
                                radius: 8
                            }
                        }
                    }
                }
               
                // ✅ CONTENEDOR DE TABLA CORREGIDO
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 565  // ✅ ALTURA FIJA para que quepan 10 filas + header
                    Layout.fillHeight: false
                    Layout.margins: 32
                    Layout.topMargin: 0
                    color: "#FFFFFF"
                    border.color: "#D5DBDB"
                    border.width: 1
                    radius: 8
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 0
                        spacing: 0
                        
                        // Header de la tabla - FIJO
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 45
                            color: "#f5f5f5"
                            border.color: "#d0d0d0"
                            border.width: 1
                            z: 5
                            
                            RowLayout {
                                anchors.fill: parent
                                spacing: 0
                                
                                Rectangle {
                                    Layout.preferredWidth: 50
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#d0d0d0"
                                    border.width: 1
                                    
                                    Label { 
                                        anchors.centerIn: parent
                                        text: "ID"
                                        font.bold: true
                                        font.pixelSize: 10
                                        color: textColor
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 150
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#d0d0d0"
                                    border.width: 1
                                    
                                    Label { 
                                        anchors.centerIn: parent
                                        text: "PACIENTE"
                                        font.bold: true
                                        font.pixelSize: 12
                                        color: textColor
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 220
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#d0d0d0"
                                    border.width: 1
                                    
                                    Label { 
                                        anchors.centerIn: parent
                                        text: "ANÁLISIS"
                                        font.bold: true
                                        font.pixelSize: 12
                                        color: textColor
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 80
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#d0d0d0"
                                    border.width: 1
                                    
                                    Label { 
                                        anchors.centerIn: parent
                                        text: "TIPO"
                                        font.bold: true
                                        font.pixelSize: 12
                                        color: textColor
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 80
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#d0d0d0"
                                    border.width: 1
                                    
                                    Label { 
                                        anchors.centerIn: parent
                                        text: "PRECIO"
                                        font.bold: true
                                        font.pixelSize: 12
                                        color: textColor
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 130
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#d0d0d0"
                                    border.width: 1
                                    
                                    Label { 
                                        anchors.centerIn: parent
                                        text: "TRABAJADOR"
                                        font.bold: true
                                        font.pixelSize: 12
                                        color: textColor
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 130
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#d0d0d0"
                                    border.width: 1
                                    
                                    Label { 
                                        anchors.centerIn: parent
                                        text: "REGISTRADO POR"
                                        font.bold: true
                                        font.pixelSize: 12
                                        color: textColor
                                    }
                                }
                                
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#d0d0d0"
                                    border.width: 1
                                    
                                    Label { 
                                        anchors.centerIn: parent
                                        text: "FECHA"
                                        font.bold: true
                                        font.pixelSize: 12
                                        color: textColor
                                    }
                                }
                            }
                        }
                        
                        // Contenido de la tabla con scroll controlado
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 520  // ✅ ALTURA FIJA (565-45=520)
                            Layout.fillHeight: false
                            clip: true
                            
                            ListView {
                                id: analisisListView
                                model: analisisPaginadosModel  // ✅ USAR MODELO PAGINADO
                                
                                delegate: Rectangle {
                                    width: ListView.view.width
                                    height: 50  // ✅ REDUCIDO de 65 a 50
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
                                            Layout.preferredWidth: 50
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Label { 
                                                anchors.centerIn: parent
                                                text: model.analisisId
                                                color: textColor
                                                font.bold: true
                                                font.pixelSize: 11  // ✅ REDUCIDO de 12 a 11
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 150
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Label { 
                                                anchors.fill: parent
                                                anchors.margins: 3  // ✅ REDUCIDO de 4 a 3
                                                text: model.paciente
                                                color: textColor
                                                font.bold: true
                                                font.pixelSize: 11  // ✅ REDUCIDO de 12 a 11
                                                elide: Text.ElideRight
                                                wrapMode: Text.WordWrap
                                                maximumLineCount: 2
                                                verticalAlignment: Text.AlignVCenter
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 220
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            ColumnLayout {
                                                anchors.fill: parent
                                                anchors.margins: 6  // ✅ REDUCIDO de 8 a 6
                                                spacing: 1
                                                
                                                Label { 
                                                    Layout.fillWidth: true
                                                    text: model.tipoAnalisis
                                                    color: primaryColor
                                                    font.bold: true
                                                    font.pixelSize: 10  // ✅ REDUCIDO de 12 a 10
                                                    elide: Text.ElideRight
                                                    maximumLineCount: 1
                                                    verticalAlignment: Text.AlignVCenter
                                                }
                                                Label { 
                                                    Layout.fillWidth: true
                                                    text: model.detalles
                                                    color: "#7f8c8d"
                                                    font.pixelSize: 8  // ✅ REDUCIDO de 9 a 8
                                                    wrapMode: Text.WordWrap
                                                    elide: Text.ElideRight
                                                    maximumLineCount: 2
                                                }
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 80
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: 45  // ✅ REDUCIDO de 60 a 45
                                                height: 16  // ✅ REDUCIDO de 20 a 16
                                                color: model.tipo === "Emergencia" ? emergencyColor : successColor
                                                radius: 8
                                                
                                                Label {
                                                    anchors.centerIn: parent
                                                    text: model.tipo
                                                    color: whiteColor
                                                    font.pixelSize: 8  // ✅ REDUCIDO de 9 a 8
                                                    font.bold: true
                                                }
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 80
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Label { 
                                                anchors.centerIn: parent
                                                text: "Bs " + model.precio
                                                color: model.tipo === "Emergencia" ? emergencyColor : successColor
                                                font.bold: true
                                                font.pixelSize: 11  // ✅ REDUCIDO de 12 a 11
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 130
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Label { 
                                                anchors.fill: parent
                                                anchors.margins: 3  // ✅ REDUCIDO de 4 a 3
                                                text: model.trabajadorAsignado || "Sin asignar"
                                                color: model.trabajadorAsignado ? textColor : "#95a5a6"
                                                font.pixelSize: 10  // ✅ REDUCIDO de 12 a 10
                                                verticalAlignment: Text.AlignVCenter
                                                horizontalAlignment: Text.AlignHCenter
                                                elide: Text.ElideRight
                                                wrapMode: Text.WordWrap
                                                maximumLineCount: 2
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 130
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Label { 
                                                anchors.fill: parent
                                                anchors.margins: 3  // ✅ REDUCIDO de 4 a 3
                                                text: model.registradoPor || "Luis López"
                                                color: "#7f8c8d"
                                                font.pixelSize: 10  // ✅ REDUCIDO de 12 a 10
                                                elide: Text.ElideRight
                                                wrapMode: Text.WordWrap
                                                maximumLineCount: 2
                                                verticalAlignment: Text.AlignVCenter
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.fillWidth: true
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
                                                font.pixelSize: 10  // ✅ REDUCIDO de 12 a 10
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
                                    
                                    // ✅ BOTONES DE ACCIÓN CORREGIDOS
                                    RowLayout {
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 5  // ✅ REDUCIDO de 8 a 5
                                        spacing: 3
                                        visible: selectedRowIndex === index
                                        z: 10
                                        
                                        Button {
                                            id: editButton
                                            width: 24  // ✅ REDUCIDO de 32 a 24
                                            height: 24  // ✅ REDUCIDO de 32 a 24
                                            text: "✏️"
                                            
                                            background: Rectangle {
                                                color: warningColor
                                                radius: 5
                                                border.color: "#f1c40f"
                                                border.width: 1
                                            }
                                            
                                            contentItem: Label {
                                                text: parent.text
                                                color: whiteColor
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                                font.pixelSize: 9  // ✅ REDUCIDO de 12 a 9
                                            }
                                            
                                            onClicked: {
                                                // ✅ BUSCAR EL ÍNDICE REAL EN EL MODELO FILTRADO
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
                                            width: 24  // ✅ REDUCIDO de 32 a 24
                                            height: 24  // ✅ REDUCIDO de 32 a 24
                                            text: "🗑️"
                                            
                                            background: Rectangle {
                                                color: dangerColor
                                                radius: 5
                                                border.color: "#c0392b"
                                                border.width: 1
                                            }
                                            
                                            contentItem: Label {
                                                text: parent.text
                                                color: whiteColor
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                                font.pixelSize: 9  // ✅ REDUCIDO de 12 a 9
                                            }
                                            
                                            onClicked: {
                                                // ✅ ELIMINAR DEL MODELO FILTRADO Y ACTUALIZAR
                                                var analisisId = model.analisisId
                                                
                                                // Eliminar de analisisListModel
                                                for (var i = 0; i < analisisListModel.count; i++) {
                                                    if (analisisListModel.get(i).analisisId === analisisId) {
                                                        analisisListModel.remove(i)
                                                        break
                                                    }
                                                }
                                                
                                                // Eliminar de analisisOriginales
                                                for (var j = 0; j < analisisOriginales.length; j++) {
                                                    if (analisisOriginales[j].analisisId === analisisId) {
                                                        analisisOriginales.splice(j, 1)
                                                        break
                                                    }
                                                }
                                                
                                                selectedRowIndex = -1
                                                updatePaginatedModel() // ✅ ACTUALIZAR PAGINACIÓN
                                                console.log("Análisis eliminado ID:", analisisId)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                // ✅ CONTROL DE PAGINACIÓN CORREGIDO
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    Layout.margins: 32
                    Layout.topMargin: 0
                    color: "#F8F9FA"
                    border.color: "#D5DBDB"
                    border.width: 1
                    radius: 8
                    
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 20
                        
                        // Botón Anterior
                        Button {
                            Layout.preferredWidth: 100
                            Layout.preferredHeight: 36
                            text: "← Anterior"
                            enabled: currentPageLaboratorio > 0
                            
                            background: Rectangle {
                                color: parent.enabled ? 
                                    (parent.pressed ? Qt.darker("#10B981", 1.1) : "#10B981") : 
                                    "#E5E7EB"
                                radius: 18
                                
                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                            
                            contentItem: Label {
                                text: parent.text
                                color: parent.enabled ? "#FFFFFF" : "#9CA3AF"
                                font.bold: true
                                font.pixelSize: 14
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: {
                                if (currentPageLaboratorio > 0) {
                                    currentPageLaboratorio--
                                    updatePaginatedModel()  // ✅ CAMBIAR A FUNCIÓN CORRECTA
                                }
                            }
                        }
                        
                        // Indicador de página
                        Label {
                            text: "Página " + (currentPageLaboratorio + 1) + " de " + Math.max(1, totalPagesLaboratorio)
                            color: "#374151"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }
                        
                        // Botón Siguiente
                        Button {
                            Layout.preferredWidth: 110
                            Layout.preferredHeight: 36
                            text: "Siguiente →"
                            enabled: currentPageLaboratorio < totalPagesLaboratorio - 1  // ✅ CORREGIDO
                            
                            background: Rectangle {
                                color: parent.enabled ? 
                                    (parent.pressed ? Qt.darker("#10B981", 1.1) : "#10B981") : 
                                    "#E5E7EB"
                                radius: 18
                                
                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                            
                            contentItem: Label {
                                text: parent.text
                                color: parent.enabled ? "#FFFFFF" : "#9CA3AF"
                                font.bold: true
                                font.pixelSize: 14
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: {
                                if (currentPageLaboratorio < totalPagesLaboratorio - 1) {  // ✅ CORREGIDO
                                    currentPageLaboratorio++
                                    updatePaginatedModel()  // ✅ CAMBIAR A FUNCIÓN CORRECTA
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Diálogo Nuevo Análisis / Editar Análisis
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
    
    Rectangle {
        id: labTestForm
        anchors.centerIn: parent
        width: 500
        height: 700
        color: whiteColor
        radius: 20
        border.color: lightGrayColor
        border.width: 2
        visible: showNewLabTestDialog
        
        property int selectedTipoAnalisisIndex: -1
        property string analisisType: "Normal"
        property real calculatedPrice: 0.0
        
        // Función para cargar datos en modo edición
        function loadEditData() {
            if (isEditMode && editingIndex >= 0) {
                var analisis = analisisListModel.get(editingIndex)
                
                // Extraer nombres del paciente completo
                var nombreCompleto = analisis.paciente.split(" ")
                nombrePaciente.text = nombreCompleto[0] || ""
                apellidoPaterno.text = nombreCompleto[1] || ""
                apellidoMaterno.text = nombreCompleto.slice(2).join(" ") || ""
                
                // Buscar el tipo de análisis correspondiente
                var tipoAnalisisNombre = analisis.tipoAnalisis
                for (var i = 0; i < tiposAnalisis.length; i++) {
                    if (tiposAnalisis[i].nombre === tipoAnalisisNombre) {
                        tipoAnalisisCombo.currentIndex = i + 1
                        labTestForm.selectedTipoAnalisisIndex = i
                        break
                    }
                }
                
                // Configurar tipo de análisis
                if (analisis.tipo === "Normal") {
                    normalRadio.checked = true
                    labTestForm.analisisType = "Normal"
                } else {
                    emergenciaRadio.checked = true
                    labTestForm.analisisType = "Emergencia"
                }
                
                // Cargar precio
                labTestForm.calculatedPrice = parseFloat(analisis.precio)
                
                // Buscar trabajador
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
                // Limpiar formulario para nuevo análisis
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
            anchors.margins: 30
            spacing: 20
            
            // Título
            Label {
                Layout.fillWidth: true
                text: isEditMode ? "Editar Análisis" : "Nuevo Análisis"
                font.pixelSize: 24
                font.bold: true
                color: textColor
                horizontalAlignment: Text.AlignHCenter
            }
            
            // Datos del Paciente
            GroupBox {
                Layout.fillWidth: true
                title: "Datos del Paciente"
                
                background: Rectangle {
                    color: "#f8f9fa"
                    border.color: lightGrayColor
                    border.width: 1
                    radius: 8
                }
                
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 12
                    
                    // Nombre
                    TextField {
                        id: nombrePaciente
                        Layout.fillWidth: true
                        placeholderText: "Nombre del paciente"
                        background: Rectangle {
                            color: whiteColor
                            border.color: lightGrayColor
                            border.width: 1
                            radius: 6
                        }
                    }
                    
                    // Apellidos
                    RowLayout {
                        Layout.fillWidth: true                       
                        TextField {
                            id: apellidoPaterno
                            Layout.fillWidth: true
                            placeholderText: "Apellido paterno"
                            background: Rectangle {
                                color: whiteColor
                                border.color: lightGrayColor
                                border.width: 1
                                radius: 6
                            }
                        }
                        
                        TextField {
                            id: apellidoMaterno
                            Layout.fillWidth: true
                            placeholderText: "Apellido materno"
                            background: Rectangle {
                                color: whiteColor
                                border.color: lightGrayColor
                                border.width: 1
                                radius: 6
                            }
                        }
                    }
                    
                    // Edad
                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            Layout.preferredWidth: 120
                            text: "Edad:"
                            font.bold: true
                            color: textColor
                        }
                        TextField {
                            id: edadPaciente
                            Layout.preferredWidth: 100
                            placeholderText: "0"
                            validator: IntValidator { bottom: 0; top: 120 }
                            background: Rectangle {
                                color: whiteColor
                                border.color: lightGrayColor
                                border.width: 1
                                radius: 6
                            }
                        }
                        Label {
                            text: "años"
                            color: textColor
                        }
                        Item { Layout.fillWidth: true }
                    }
                }
            }
            
            // Tipo de Análisis
            RowLayout {
                Layout.fillWidth: true
                Label {
                    Layout.preferredWidth: 120
                    text: "Tipo de Análisis:"
                    font.bold: true
                    color: textColor
                }
                ComboBox {
                    id: tipoAnalisisCombo
                    Layout.fillWidth: true
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
                }
            }
            
            // Tipo de Servicio
            RowLayout {
                Layout.fillWidth: true
                Label {
                    Layout.preferredWidth: 120
                    text: "Tipo de Servicio:"
                    font.bold: true
                    color: textColor
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
                }
                Item { Layout.fillWidth: true }
            }
            
            // Trabajador
            RowLayout {
                Layout.fillWidth: true
                Label {
                    Layout.preferredWidth: 120
                    text: "Trabajador:"
                    font.bold: true
                    color: textColor
                }
                ComboBox {
                    id: trabajadorCombo
                    Layout.fillWidth: true
                    model: {
                        var list = ["Seleccionar trabajador..."]
                        for (var i = 0; i < trabajadoresLab.length; i++) {
                            list.push(trabajadoresLab[i])
                        }
                        list.push("Sin asignar")
                        return list
                    }
                }
            }
            
            // Precio calculado
            RowLayout {
                Layout.fillWidth: true
                Label {
                    Layout.preferredWidth: 120
                    text: "Precio:"
                    font.bold: true
                    color: textColor
                }
                Label {
                    text: labTestForm.selectedTipoAnalisisIndex >= 0 ? 
                          "Bs " + labTestForm.calculatedPrice.toFixed(2) : "Seleccione tipo de análisis"
                    font.bold: true
                    font.pixelSize: 16
                    color: labTestForm.analisisType === "Emergencia" ? emergencyColor : successColor
                }
                Item { Layout.fillWidth: true }
            }
            
            Item { Layout.fillHeight: true }
            
            // Botones
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                
                Button {
                    text: "Cancelar"
                    background: Rectangle {
                        color: lightGrayColor
                        radius: 8
                    }
                    contentItem: Label {
                        text: parent.text
                        color: textColor
                        horizontalAlignment: Text.AlignHCenter
                    }
                    onClicked: {
                        // Limpiar campos
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
                    background: Rectangle {
                        color: parent.enabled ? primaryColor : "#bdc3c7"
                        radius: 8
                    }
                    contentItem: Label {
                        text: parent.text
                        color: whiteColor
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                    onClicked: {
                        // Crear datos de análisis
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
                            registradoPor: "Luis López"  // Siempre Luis López
                        }
                        
                        if (isEditMode && editingIndex >= 0) {
                            // ✅ ACTUALIZAR ANÁLISIS EXISTENTE
                            var analisisExistente = analisisListModel.get(editingIndex)
                            analisisData.analisisId = analisisExistente.analisisId
                            
                            // Actualizar en modelo filtrado
                            analisisListModel.set(editingIndex, analisisData)
                            
                            // Actualizar en datos originales
                            for (var i = 0; i < analisisOriginales.length; i++) {
                                if (analisisOriginales[i].analisisId === analisisData.analisisId) {
                                    analisisOriginales[i] = analisisData
                                    break
                                }
                            }
                            
                            console.log("Análisis actualizado:", JSON.stringify(analisisData))
                        } else {
                            // ✅ CREAR NUEVO ANÁLISIS
                            analisisData.analisisId = (getTotalLaboratorioCount() + 1).toString()
                            
                            // Agregar a modelo filtrado
                            analisisListModel.append(analisisData)
                            
                            // Agregar a datos originales
                            analisisOriginales.push(analisisData)
                            
                            console.log("Nuevo análisis guardado:", JSON.stringify(analisisData))
                        }
                        
                        // ✅ ACTUALIZAR PAGINACIÓN
                        updatePaginatedModel()
                        
                        // Limpiar y cerrar
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

    // ✅ FUNCIÓN PARA APLICAR FILTROS - MEJORADA
    function aplicarFiltros() {
        console.log("🔍 Aplicando filtros en laboratorio...")
        
        // Limpiar el modelo filtrado
        analisisListModel.clear()
        
        var hoy = new Date()
        var textoBusqueda = campoBusqueda.text.toLowerCase()
        
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
            
            // Filtro por tipo
            if (filtroTipo.currentIndex > 0 && mostrar) {
                var tipoSeleccionado = filtroTipo.model[filtroTipo.currentIndex]
                if (analisis.tipo !== tipoSeleccionado) {
                    mostrar = false
                }
            }
            
            // Búsqueda por texto en paciente
            if (textoBusqueda.length > 0 && mostrar) {
                if (!analisis.paciente.toLowerCase().includes(textoBusqueda)) {
                    mostrar = false
                }
            }
            
            if (mostrar) {
                analisisListModel.append(analisis)
            }
        }
        
        // ✅ RESETEAR A PRIMERA PÁGINA Y ACTUALIZAR PAGINACIÓN
        currentPageLaboratorio = 0
        updatePaginatedModel()
        
        console.log("✅ Filtros aplicados. Análisis mostrados:", analisisListModel.count)
    }

    // ✅ NUEVA FUNCIÓN PARA ACTUALIZAR PAGINACIÓN
    function updatePaginatedModel() {
        console.log("📄 Laboratorio: Actualizando paginación - Página:", currentPageLaboratorio + 1)
        
        // Limpiar modelo paginado
        analisisPaginadosModel.clear()
        
        // Calcular total de páginas basado en análisis filtrados
        var totalItems = analisisListModel.count
        totalPagesLaboratorio = Math.ceil(totalItems / itemsPerPageLaboratorio)
        
        // Asegurar que siempre hay al menos 1 página
        if (totalPagesLaboratorio === 0) {
            totalPagesLaboratorio = 1
        }
        
        // Ajustar página actual si es necesario
        if (currentPageLaboratorio >= totalPagesLaboratorio && totalPagesLaboratorio > 0) {
            currentPageLaboratorio = totalPagesLaboratorio - 1
        }
        if (currentPageLaboratorio < 0) {
            currentPageLaboratorio = 0
        }
        
        // Calcular índices
        var startIndex = currentPageLaboratorio * itemsPerPageLaboratorio
        var endIndex = Math.min(startIndex + itemsPerPageLaboratorio, totalItems)
        
        // Agregar elementos de la página actual
        for (var i = startIndex; i < endIndex; i++) {
            var analisis = analisisListModel.get(i)
            analisisPaginadosModel.append(analisis)
        }
        
        console.log("📄 Laboratorio: Página", currentPageLaboratorio + 1, "de", totalPagesLaboratorio,
                    "- Mostrando", analisisPaginadosModel.count, "de", totalItems)
    }

    // Diálogo Configuración de Tipos de Análisis
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
        width: 700
        height: 600
        color: whiteColor
        radius: 20
        border.color: lightGrayColor
        border.width: 2
        visible: showConfigTiposAnalisisDialog
        
        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            
            // Header fijo para título y formulario
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 400
                color: whiteColor
                radius: 20
                z: 10
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 30
                    spacing: 20
                    
                    Label {
                        Layout.fillWidth: true
                        text: "🧪 Configuración de Tipos de Análisis"
                        font.pixelSize: 24
                        font.bold: true
                        color: textColor
                        horizontalAlignment: Text.AlignHCenter
                    }
                    
                    // Formulario para agregar nuevo tipo de análisis
                    GroupBox {
                        Layout.fillWidth: true
                        title: "Agregar Nuevo Tipo de Análisis"
                        
                        background: Rectangle {
                            color: "#f8f9fa"
                            border.color: lightGrayColor
                            border.width: 1
                            radius: 8
                        }
                        
                        GridLayout {
                            anchors.fill: parent
                            columns: 2
                            rowSpacing: 12
                            columnSpacing: 10
                            
                            Label {
                                text: "Nombre:"
                                font.bold: true
                                color: textColor
                            }
                            TextField {
                                id: nuevoTipoAnalisisNombre
                                Layout.fillWidth: true
                                placeholderText: "Ej: Hemograma Completo"
                                background: Rectangle {
                                    color: whiteColor
                                    border.color: lightGrayColor
                                    border.width: 1
                                    radius: 6
                                }
                            }
                            
                            Label {
                                text: "Detalles:"
                                font.bold: true
                                color: textColor
                            }
                            ScrollView {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 60
                                
                                TextArea {
                                    id: nuevoTipoAnalisisDetalles
                                    placeholderText: "Descripción del análisis..."
                                    wrapMode: TextArea.Wrap
                                    background: Rectangle {
                                        color: whiteColor
                                        border.color: lightGrayColor
                                        border.width: 1
                                        radius: 6
                                    }
                                }
                            }
                            
                            Label {
                                text: "Precio Normal:"
                                font.bold: true
                                color: textColor
                            }
                            TextField {
                                id: nuevoTipoAnalisisPrecioNormal
                                Layout.fillWidth: true
                                placeholderText: "0.00"
                                validator: DoubleValidator { bottom: 0.0; decimals: 2 }
                                background: Rectangle {
                                    color: whiteColor
                                    border.color: lightGrayColor
                                    border.width: 1
                                    radius: 6
                                }
                            }
                            
                            Label {
                                text: "Precio Emergencia:"
                                font.bold: true
                                color: textColor
                            }
                            TextField {
                                id: nuevoTipoAnalisisPrecioEmergencia
                                Layout.fillWidth: true
                                placeholderText: "0.00"
                                validator: DoubleValidator { bottom: 0.0; decimals: 2 }
                                background: Rectangle {
                                    color: whiteColor
                                    border.color: lightGrayColor
                                    border.width: 1
                                    radius: 6
                                }
                            }
                            
                            Item { }
                            Button {
                                Layout.alignment: Qt.AlignRight
                                text: "➕ Agregar Tipo de Análisis"
                                background: Rectangle {
                                    color: successColor
                                    radius: 8
                                }
                                contentItem: Label {
                                    text: parent.text
                                    color: whiteColor
                                    font.bold: true
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
                                        
                                        // Limpiar campos
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
            
            // Lista de tipos de análisis existentes con scroll limitado
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 30
                Layout.topMargin: 0
                color: "transparent"
                
                ScrollView {
                    anchors.fill: parent
                    clip: true
                    
                    ListView {
                        model: tiposAnalisis
                        delegate: Rectangle {
                            width: ListView.view.width
                            height: 90
                            color: index % 2 === 0 ? "transparent" : "#fafafa"
                            border.color: "#e8e8e8"
                            border.width: 1
                            radius: 8
                            
                            GridLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                columns: 4
                                rowSpacing: 6
                                columnSpacing: 12
                                
                                // Nombre y Detalles
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    
                                    Label {
                                        text: modelData.nombre
                                        font.bold: true
                                        color: primaryColor
                                        font.pixelSize: 14
                                    }
                                    Label {
                                        text: modelData.detalles
                                        color: textColor
                                        font.pixelSize: 11
                                        wrapMode: Text.WordWrap
                                        elide: Text.ElideRight
                                        maximumLineCount: 2
                                    }
                                }
                                
                                // Precio Normal
                                ColumnLayout {
                                    Layout.preferredWidth: 100
                                    spacing: 4
                                    
                                    Label {
                                        text: "Normal"
                                        font.bold: true
                                        color: successColor
                                        font.pixelSize: 12
                                    }
                                    Label {
                                        text: "Bs " + modelData.precioNormal.toFixed(2)
                                        color: successColor
                                        font.bold: true
                                        font.pixelSize: 14
                                    }
                                }
                                
                                // Precio Emergencia
                                ColumnLayout {
                                    Layout.preferredWidth: 100
                                    spacing: 4
                                    
                                    Label {
                                        text: "Emergencia"
                                        font.bold: true
                                        color: emergencyColor
                                        font.pixelSize: 12
                                    }
                                    Label {
                                        text: "Bs " + modelData.precioEmergencia.toFixed(2)
                                        color: emergencyColor
                                        font.bold: true
                                        font.pixelSize: 14
                                    }
                                }
                                
                                // Botón eliminar
                                Button {
                                    Layout.preferredWidth: 30
                                    Layout.preferredHeight: 30
                                    text: "🗑️"
                                    background: Rectangle {
                                        color: dangerColor
                                        radius: 6
                                    }
                                    contentItem: Label {
                                        text: parent.text
                                        color: whiteColor
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
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
    
    // ✅ FUNCIÓN PARA OBTENER TOTAL DE ANÁLISIS CORREGIDA
    function getTotalLaboratorioCount() {
        return analisisOriginales.length
    }
    
    // ✅ INICIALIZACIÓN AL CARGAR EL COMPONENTE
    Component.onCompleted: {
        console.log("🧪 Módulo Laboratorio iniciado")
        
        // Cargar datos originales
        for (var i = 0; i < analisisModelData.length; i++) {
            analisisOriginales.push(analisisModelData[i])
            analisisListModel.append(analisisModelData[i])
        }
        
        // Inicializar paginación
        updatePaginatedModel()
        
        console.log("✅ Análisis cargados:", analisisOriginales.length)
    }
}