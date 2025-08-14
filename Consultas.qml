import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

Item {
    id: consultasRoot
    objectName: "consultasRoot"
    
    // ===== NUEVA SEÑAL PARA IR A CONFIGURACIÓN =====
    signal irAConfiguracion()
    
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
    
    // Propiedades para los diálogos (mantener solo nuevo paciente)
    property bool showNewConsultationDialog: false
    // ===== ELIMINADO: property bool showConfigEspecialidadesDialog: false =====
    property bool isEditMode: false
    property int editingIndex: -1
    property int selectedRowIndex: -1
    
    // PAGINACIÓN ADAPTATIVA
    property int itemsPerPageConsultas: calcularElementosPorPagina()
    property int currentPageConsultas: 0
    property int totalPagesConsultas: 0
    
    // Datos originales (mantener)
    property var consultasOriginales: []
    
    // Modelo de especialidades (mantener)
    property var especialidades: [
        { 
            nombre: "Cardiología", 
            doctor: "Dr. Juan Carlos García", 
            precioNormal: 45.0,
            precioEmergencia: 80.0
        },
        { 
            nombre: "Neurología", 
            doctor: "Dra. María Elena Rodríguez", 
            precioNormal: 50.0,
            precioEmergencia: 85.0
        },
        { 
            nombre: "Pediatría", 
            doctor: "Dr. Pedro Antonio Martínez", 
            precioNormal: 40.0,
            precioEmergencia: 70.0
        },
        { 
            nombre: "Medicina General", 
            doctor: "Dr. Luis Fernández", 
            precioNormal: 35.0,
            precioEmergencia: 60.0
        }
    ]

    // Datos de ejemplo (mantener)
    property var consultasModelData: [
        {
            consultaId: "1",
            paciente: "Ana María López",
            especialidadDoctor: "Cardiología - Dr. Juan Carlos García",
            tipo: "Normal",
            precio: "45.00",
            fecha: "2025-06-15",
            detalles: "Control rutinario, presión arterial normal"
        },
        {
            consultaId: "2",
            paciente: "Carlos Eduardo Martínez",
            especialidadDoctor: "Neurología - Dra. María Elena Rodríguez",
            tipo: "Emergencia",
            precio: "85.00",
            fecha: "2025-06-16",
            detalles: "Seguimiento de migrañas recurrentes"
        },
        {
            consultaId: "3",
            paciente: "Elena Isabel Vargas",
            especialidadDoctor: "Pediatría - Dr. Pedro Antonio Martínez",
            tipo: "Normal",
            precio: "40.00",
            fecha: "2025-06-17",
            detalles: "Control de crecimiento y desarrollo"
        },
        {
            consultaId: "4",
            paciente: "Roberto Silva",
            especialidadDoctor: "Cardiología - Dr. Juan Carlos García",
            tipo: "Normal",
            precio: "45.00",
            fecha: "2025-06-17",
            detalles: "Evaluación post-operatoria"
        },
        {
            consultaId: "5",
            paciente: "María José Fernández",
            especialidadDoctor: "Medicina General - Dr. Luis Fernández",
            tipo: "Normal",
            precio: "35.00",
            fecha: "2025-06-18",
            detalles: "Consulta por síntomas gripales"
        },
        {
            consultaId: "6",
            paciente: "José Antonio Morales",
            especialidadDoctor: "Neurología - Dra. María Elena Rodríguez",
            tipo: "Emergencia",
            precio: "85.00",
            fecha: "2025-06-19",
            detalles: "Dolor de cabeza severo y persistente"
        },
        {
            consultaId: "7",
            paciente: "Carmen Rosa Delgado",
            especialidadDoctor: "Pediatría - Dr. Pedro Antonio Martínez",
            tipo: "Normal",
            precio: "40.00",
            fecha: "2025-06-20",
            detalles: "Vacunación infantil programada"
        },
        {
            consultaId: "8",
            paciente: "Ricardo Herrera",
            especialidadDoctor: "Cardiología - Dr. Juan Carlos García",
            tipo: "Emergencia",
            precio: "80.00",
            fecha: "2025-06-21",
            detalles: "Dolor en el pecho y dificultad respiratoria"
        },
        {
            consultaId: "9",
            paciente: "Patricia Sánchez",
            especialidadDoctor: "Medicina General - Dr. Luis Fernández",
            tipo: "Normal",
            precio: "35.00",
            fecha: "2025-06-22",
            detalles: "Control de presión arterial"
        },
        {
            consultaId: "10",
            paciente: "Fernando Gómez",
            especialidadDoctor: "Neurología - Dra. María Elena Rodríguez",
            tipo: "Normal",
            precio: "50.00",
            fecha: "2025-06-23",
            detalles: "Seguimiento de tratamiento neurológico"
        },
        {
            consultaId: "11",
            paciente: "Isabella Ramírez",
            especialidadDoctor: "Pediatría - Dr. Pedro Antonio Martínez",
            tipo: "Emergencia",
            precio: "70.00",
            fecha: "2025-06-24",
            detalles: "Fiebre alta en menor de edad"
        },
        {
            consultaId: "12",
            paciente: "Miguel Ángel Torres",
            especialidadDoctor: "Cardiología - Dr. Juan Carlos García",
            tipo: "Normal",
            precio: "45.00",
            fecha: "2025-06-25",
            detalles: "Revisión de medicación cardiológica"
        }
    ]

    // Modelos (mantener)
    ListModel {
        id: consultasListModel
    }
    
    ListModel {
        id: consultasPaginadasModel
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
        if (nuevosElementos !== itemsPerPageConsultas) {
            itemsPerPageConsultas = nuevosElementos
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
                                text: "🩺"
                                font.pixelSize: fontBaseSize * 1.8
                                color: primaryColor
                            }
                            
                            Label {
                                text: "Registro de Consultas Médicas"
                                font.pixelSize: fontBaseSize * 1.4
                                font.bold: true
                                color: textColor
                            }
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        Button {
                            objectName: "newConsultationButton"
                            text: "➕ Nueva Consulta"
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
                                showNewConsultationDialog = true
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
                    
                    // Layout adaptativo: una fila en pantallas grandes, dos en pequeñas
                    GridLayout {
                        anchors.fill: parent
                        anchors.margins: baseUnit * 3
                        anchors.bottomMargin: baseUnit * 1.5
                        
                        columns: width < 1000 ? 2 : 4
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
                                text: "Especialidad:"
                                font.bold: true
                                color: textColor
                                font.pixelSize: fontBaseSize * 0.9
                            }
                            
                            ComboBox {
                                id: filtroEspecialidad
                                Layout.fillWidth: true
                                Layout.preferredHeight: baseUnit * 4
                                model: {
                                    var list = ["Todas"]
                                    for (var i = 0; i < especialidades.length; i++) {
                                        list.push(especialidades[i].nombre)
                                    }
                                    return list
                                }
                                currentIndex: 0
                                onCurrentIndexChanged: aplicarFiltros()
                                
                                contentItem: Label {
                                    text: filtroEspecialidad.displayText
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
                            spacing: baseUnit
                            
                            Label {
                                text: "Tipo:"
                                font.bold: true
                                color: textColor
                                font.pixelSize: fontBaseSize * 0.9
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
                                    Layout.preferredWidth: parent.width * 0.06 // 6% para ID
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
                                    Layout.preferredWidth: parent.width * 0.18 // 18% para PACIENTE
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
                                    Layout.preferredWidth: parent.width * 0.22 // 22% para DETALLE
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#d0d0d0"
                                    border.width: 1
                                    
                                    Label { 
                                        anchors.centerIn: parent
                                        text: "DETALLE"
                                        font.bold: true
                                        font.pixelSize: fontBaseSize * 0.8
                                        color: textColor
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: parent.width * 0.25 // 25% para ESPECIALIDAD
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#d0d0d0"
                                    border.width: 1
                                    
                                    Label { 
                                        anchors.centerIn: parent
                                        text: "ESPECIALIDAD - DOCTOR"
                                        font.bold: true
                                        font.pixelSize: fontBaseSize * 0.8
                                        color: textColor
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: parent.width * 0.11 // 11% para TIPO
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
                                    Layout.preferredWidth: parent.width * 0.09 // 9% para PRECIO
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
                                    Layout.preferredWidth: parent.width * 0.09 // 9% para FECHA
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
                                id: consultasListView
                                model: consultasPaginadasModel
                                
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
                                            Layout.preferredWidth: parent.width * 0.06
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Label { 
                                                anchors.centerIn: parent
                                                text: model.consultaId
                                                color: textColor
                                                font.bold: true
                                                font.pixelSize: fontBaseSize * 0.8
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: parent.width * 0.18
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Label { 
                                                anchors.centerIn: parent
                                                text: model.paciente
                                                color: textColor
                                                font.bold: true
                                                font.pixelSize: fontBaseSize * 0.85
                                                elide: Text.ElideRight
                                                maximumLineCount: 1
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: parent.width * 0.22
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Label { 
                                                anchors.fill: parent
                                                anchors.margins: baseUnit * 0.5
                                                text: model.detalles
                                                color: "#7f8c8d"
                                                font.pixelSize: fontBaseSize * 0.75
                                                wrapMode: Text.WordWrap
                                                elide: Text.ElideRight
                                                maximumLineCount: 2
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: parent.width * 0.25
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Label { 
                                                anchors.fill: parent
                                                anchors.margins: baseUnit * 0.6
                                                text: model.especialidadDoctor
                                                color: primaryColor
                                                font.bold: true
                                                font.pixelSize: fontBaseSize * 0.75
                                                wrapMode: Text.WordWrap
                                                elide: Text.ElideRight
                                                maximumLineCount: 2
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: parent.width * 0.11
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: baseUnit * 5
                                                height: baseUnit * 2
                                                color: model.tipo === "Emergencia" ? "#e67e22" : successColor
                                                radius: baseUnit
                                                
                                                Label {
                                                    anchors.centerIn: parent
                                                    text: model.tipo
                                                    color: whiteColor
                                                    font.pixelSize: fontBaseSize * 0.7
                                                    font.bold: true
                                                }
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: parent.width * 0.09
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Label { 
                                                anchors.centerIn: parent
                                                text: "Bs" + model.precio
                                                color: model.tipo === "Emergencia" ? "#e67e22" : successColor
                                                font.bold: true
                                                font.pixelSize: fontBaseSize * 0.8
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: parent.width * 0.09
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Label { 
                                                anchors.centerIn: parent
                                                text: model.fecha
                                                color: textColor
                                                font.pixelSize: fontBaseSize * 0.75
                                            }
                                        }
                                    }
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            selectedRowIndex = index
                                            console.log("Seleccionada consulta ID:", model.consultaId)
                                        }
                                    }
                                    
                                    // BOTONES DE ACCIÓN ADAPTATIVOS
                                    RowLayout {
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: baseUnit * 0.6
                                        spacing: baseUnit * 0.3
                                        visible: selectedRowIndex === index
                                        z: 10
                                        
                                        Button {
                                            id: editButton
                                            width: baseUnit * 3
                                            height: baseUnit * 3
                                            text: "✏️"
                                            
                                            background: Rectangle {
                                                color: warningColor
                                                radius: baseUnit * 0.6
                                                border.color: "#f1c40f"
                                                border.width: 1
                                            }
                                            
                                            contentItem: Label {
                                                text: parent.text
                                                color: whiteColor
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                                font.pixelSize: fontBaseSize * 0.8
                                            }
                                            
                                            onClicked: {
                                                var consultaId = model.consultaId
                                                var realIndex = -1
                                                
                                                for (var i = 0; i < consultasListModel.count; i++) {
                                                    if (consultasListModel.get(i).consultaId === consultaId) {
                                                        realIndex = i
                                                        break
                                                    }
                                                }
                                                
                                                isEditMode = true
                                                editingIndex = realIndex
                                                
                                                console.log("Editando consulta ID:", consultaId, "índice real:", realIndex)
                                                showNewConsultationDialog = true
                                            }
                                        }
                                        
                                        Button {
                                            id: deleteButton
                                            width: baseUnit * 3
                                            height: baseUnit * 3
                                            text: "🗑️"
                                            
                                            background: Rectangle {
                                                color: dangerColor
                                                radius: baseUnit * 0.6
                                                border.color: "#c0392b"
                                                border.width: 1
                                            }
                                            
                                            contentItem: Label {
                                                text: parent.text
                                                color: whiteColor
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                                font.pixelSize: fontBaseSize * 0.8
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
                            enabled: currentPageConsultas > 0
                            
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
                                if (currentPageConsultas > 0) {
                                    currentPageConsultas--
                                    updatePaginatedModel()
                                }
                            }
                        }
                        
                        Label {
                            text: "Página " + (currentPageConsultas + 1) + " de " + Math.max(1, totalPagesConsultas)
                            color: "#374151"
                            font.pixelSize: fontBaseSize * 0.9
                            font.weight: Font.Medium
                        }
                        
                        Button {
                            Layout.preferredWidth: baseUnit * 11
                            Layout.preferredHeight: baseUnit * 4
                            text: "Siguiente →"
                            enabled: currentPageConsultas < totalPagesConsultas - 1
                            
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
    
    // Diálogo de consulta adaptativo
    Rectangle {
        id: consultationForm
        anchors.centerIn: parent
        width: Math.min(500, parent.width * 0.9)
        height: Math.min(650, parent.height * 0.9)
        color: whiteColor
        radius: baseUnit * 2
        border.color: lightGrayColor
        border.width: 2
        visible: showNewConsultationDialog
        
        property int selectedEspecialidadIndex: -1
        property string consultationType: "Normal"
        property real calculatedPrice: 0.0
        
        function loadEditData() {
            if (isEditMode && editingIndex >= 0) {
                var consulta = consultasListModel.get(editingIndex)
                
                var nombreCompleto = consulta.paciente.split(" ")
                nombrePaciente.text = nombreCompleto[0] || ""
                apellidoPaterno.text = nombreCompleto[1] || ""
                apellidoMaterno.text = nombreCompleto.slice(2).join(" ") || ""
                
                var especialidadDoctor = consulta.especialidadDoctor
                for (var i = 0; i < especialidades.length; i++) {
                    var espStr = especialidades[i].nombre + " - " + especialidades[i].doctor
                    if (espStr === especialidadDoctor) {
                        especialidadCombo.currentIndex = i + 1
                        consultationForm.selectedEspecialidadIndex = i
                        break
                    }
                }
                
                if (consulta.tipo === "Normal") {
                    normalRadio.checked = true
                    consultationForm.consultationType = "Normal"
                } else {
                    emergenciaRadio.checked = true
                    consultationForm.consultationType = "Emergencia"
                }
                
                consultationForm.calculatedPrice = parseFloat(consulta.precio)
                detallesConsulta.text = consulta.detalles
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
                especialidadCombo.currentIndex = 0
                normalRadio.checked = true
                detallesConsulta.text = ""
                consultationForm.selectedEspecialidadIndex = -1
                consultationForm.calculatedPrice = 0.0
            }
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: baseUnit * 3
            spacing: baseUnit * 2
            
            Label {
                Layout.fillWidth: true
                text: isEditMode ? "Editar Consulta" : "Nueva Consulta"
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
                    text: "Especialidad:"
                    font.bold: true
                    color: textColor
                    font.pixelSize: fontBaseSize * 0.9
                }
                ComboBox {
                    id: especialidadCombo
                    Layout.fillWidth: true
                    Layout.preferredHeight: baseUnit * 4
                    model: {
                        var list = ["Seleccionar especialidad..."]
                        for (var i = 0; i < especialidades.length; i++) {
                            list.push(especialidades[i].nombre + " - " + especialidades[i].doctor)
                        }
                        return list
                    }
                    onCurrentIndexChanged: {
                        if (currentIndex > 0) {
                            consultationForm.selectedEspecialidadIndex = currentIndex - 1
                            var especialidad = especialidades[consultationForm.selectedEspecialidadIndex]
                            if (consultationForm.consultationType === "Normal") {
                                consultationForm.calculatedPrice = especialidad.precioNormal
                            } else {
                                consultationForm.calculatedPrice = especialidad.precioEmergencia
                            }
                        } else {
                            consultationForm.selectedEspecialidadIndex = -1
                            consultationForm.calculatedPrice = 0.0
                        }
                    }
                    
                    contentItem: Label {
                        text: especialidadCombo.displayText
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
                    text: "Tipo de Consulta:"
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
                            consultationForm.consultationType = "Normal"
                            if (consultationForm.selectedEspecialidadIndex >= 0) {
                                var especialidad = especialidades[consultationForm.selectedEspecialidadIndex]
                                consultationForm.calculatedPrice = especialidad.precioNormal
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
                            consultationForm.consultationType = "Emergencia"
                            if (consultationForm.selectedEspecialidadIndex >= 0) {
                                var especialidad = especialidades[consultationForm.selectedEspecialidadIndex]
                                consultationForm.calculatedPrice = especialidad.precioEmergencia
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
                    text: "Precio:"
                    font.bold: true
                    color: textColor
                    font.pixelSize: fontBaseSize * 0.9
                }
                Label {
                    text: consultationForm.selectedEspecialidadIndex >= 0 ? 
                          "Bs" + consultationForm.calculatedPrice.toFixed(2) : "Seleccione especialidad"
                    font.bold: true
                    font.pixelSize: fontBaseSize * 1.1
                    color: consultationForm.consultationType === "Emergencia" ? "#e67e22" : successColor
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
                }
                
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: baseUnit * 8
                    
                    TextArea {
                        id: detallesConsulta
                        placeholderText: "Descripción de la consulta, síntomas, observaciones..."
                        wrapMode: TextArea.Wrap
                        font.pixelSize: fontBaseSize * 0.9
                        background: Rectangle {
                            color: whiteColor
                            border.color: lightGrayColor
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
                        horizontalAlignment: Text.AlignHCenter
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
                        isEditMode = false
                        editingIndex = -1
                    }
                }
                
                Button {
                    text: isEditMode ? "Actualizar" : "Guardar"
                    enabled: consultationForm.selectedEspecialidadIndex >= 0 && 
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
                        
                        var especialidad = especialidades[consultationForm.selectedEspecialidadIndex]
                        var especialidadDoctor = especialidad.nombre + " - " + especialidad.doctor
                        
                        var consultaData = {
                            paciente: nombreCompleto.trim(),
                            especialidadDoctor: especialidadDoctor,
                            tipo: consultationForm.consultationType,
                            precio: consultationForm.calculatedPrice.toFixed(2),
                            fecha: new Date().toISOString().split('T')[0],
                            detalles: detallesConsulta.text || "Sin detalles adicionales"
                        }
                        
                        if (isEditMode && editingIndex >= 0) {
                            var consultaExistente = consultasListModel.get(editingIndex)
                            consultaData.consultaId = consultaExistente.consultaId
                            
                            consultasListModel.set(editingIndex, consultaData)
                            
                            for (var i = 0; i < consultasOriginales.length; i++) {
                                if (consultasOriginales[i].consultaId === consultaData.consultaId) {
                                    consultasOriginales[i] = consultaData
                                    break
                                }
                            }
                            
                            console.log("Consulta actualizada:", JSON.stringify(consultaData))
                        } else {
                            consultaData.consultaId = (getTotalConsultasCount() + 1).toString()
                            
                            consultasListModel.append(consultaData)
                            consultasOriginales.push(consultaData)
                            
                            console.log("Nueva consulta guardada:", JSON.stringify(consultaData))
                        }
                        
                        updatePaginatedModel()
                        
                        nombrePaciente.text = ""
                        apellidoPaterno.text = ""
                        apellidoMaterno.text = ""
                        edadPaciente.text = ""
                        especialidadCombo.currentIndex = 0
                        normalRadio.checked = true
                        detallesConsulta.text = ""
                        showNewConsultationDialog = false
                        selectedRowIndex = -1
                        isEditMode = false
                        editingIndex = -1
                    }
                }
            }
        }
    }

    // ===== FUNCIONES (mantener todas) =====
    
    function aplicarFiltros() {
        console.log("🔍 Aplicando filtros...")
        
        consultasListModel.clear()
        
        var hoy = new Date()
        var textoBusqueda = campoBusqueda.text.toLowerCase()
        
        for (var i = 0; i < consultasOriginales.length; i++) {
            var consulta = consultasOriginales[i]
            var mostrar = true
            
            if (filtroFecha.currentIndex > 0) {
                var fechaConsulta = new Date(consulta.fecha)
                var diferenciaDias = Math.floor((hoy - fechaConsulta) / (1000 * 60 * 60 * 24))
                
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
            
            if (filtroEspecialidad.currentIndex > 0 && mostrar) {
                var especialidadSeleccionada = especialidades[filtroEspecialidad.currentIndex - 1].nombre
                if (!consulta.especialidadDoctor.includes(especialidadSeleccionada)) {
                    mostrar = false
                }
            }
            
            if (filtroTipo.currentIndex > 0 && mostrar) {
                var tipoSeleccionado = filtroTipo.model[filtroTipo.currentIndex]
                if (consulta.tipo !== tipoSeleccionado) {
                    mostrar = false
                }
            }
            
            if (textoBusqueda.length > 0 && mostrar) {
                if (!consulta.paciente.toLowerCase().includes(textoBusqueda)) {
                    mostrar = false
                }
            }
            
            if (mostrar) {
                consultasListModel.append(consulta)
            }
        }
        
        currentPageConsultas = 0
        updatePaginatedModel()
        
        console.log("✅ Filtros aplicados. Consultas mostradas:", consultasListModel.count)
    }

    function updatePaginatedModel() {
        console.log("📄 Consultas: Actualizando paginación - Página:", currentPageConsultas + 1)
        
        consultasPaginadasModel.clear()
        
        var totalItems = consultasListModel.count
        totalPagesConsultas = Math.ceil(totalItems / itemsPerPageConsultas)
        
        if (totalPagesConsultas === 0) {
            totalPagesConsultas = 1
        }
        
        if (currentPageConsultas >= totalPagesConsultas && totalPagesConsultas > 0) {
            currentPageConsultas = totalPagesConsultas - 1
        }
        if (currentPageConsultas < 0) {
            currentPageConsultas = 0
        }
        
        var startIndex = currentPageConsultas * itemsPerPageConsultas
        var endIndex = Math.min(startIndex + itemsPerPageConsultas, totalItems)
        
        for (var i = startIndex; i < endIndex; i++) {
            var consulta = consultasListModel.get(i)
            consultasPaginadasModel.append(consulta)
        }
        
        console.log("📄 Consultas: Página", currentPageConsultas + 1, "de", totalPagesConsultas,
                    "- Mostrando", consultasPaginadasModel.count, "de", totalItems, 
                    "- Elementos por página:", itemsPerPageConsultas)
    }
    
    function getTotalConsultasCount() {
        return consultasOriginales.length
    }
    
    Component.onCompleted: {
        console.log("🩺 Módulo Consultas iniciado")
        
        for (var i = 0; i < consultasModelData.length; i++) {
            consultasOriginales.push(consultasModelData[i])
            consultasListModel.append(consultasModelData[i])
        }
        
        updatePaginatedModel()
        
        console.log("✅ Consultas cargadas:", consultasOriginales.length)
        console.log("📱 Elementos por página calculados:", itemsPerPageConsultas)
    }
}