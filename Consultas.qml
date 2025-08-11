import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

Item {
    id: consultasRoot
    objectName: "consultasRoot"
    
    // Acceso a colores
    readonly property color primaryColor: "#3498DB"
    readonly property color successColor: "#27ae60"
    readonly property color dangerColor: "#E74C3C"
    readonly property color warningColor: "#f39c12"
    readonly property color lightGrayColor: "#ECF0F1"
    readonly property color textColor: "#2c3e50"
    readonly property color whiteColor: "#FFFFFF"
    
    // Propiedades para los diálogos
    property bool showNewConsultationDialog: false
    property bool showConfigEspecialidadesDialog: false
    property bool isEditMode: false
    property int editingIndex: -1
    property int selectedRowIndex: -1
    
    // Propiedades de paginación para consultas
    property int itemsPerPageConsultas: 10
    property int currentPageConsultas: 0
    property int totalPagesConsultas: 0
    
    // ✅ NUEVAS PROPIEDADES PARA DATOS ORIGINALES
    property var consultasOriginales: []
    
    // Modelo de especialidades mejorado
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

    // Modelo para consultas existentes - DATOS ORIGINALES
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

    // ✅ MODELOS SEPARADOS PARA PAGINACIÓN
    ListModel {
        id: consultasListModel // Modelo filtrado (todos los resultados del filtro)
    }
    
    ListModel {
        id: consultasPaginadasModel // Modelo para la página actual
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
                
                // Header de Consultas - FIJO
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
                                text: "🩺"
                                font.pixelSize: 24
                                color: primaryColor
                            }
                            
                            Label {
                                text: "Registro de Consultas Médicas"
                                font.pixelSize: 20
                                font.bold: true
                                color: textColor
                            }
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        Button {
                            objectName: "newConsultationButton"
                            text: "➕ Nueva Consulta"
                            
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
                                showNewConsultationDialog = true
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
                                    text: "🏥 Configuración de Especialidades"
                                    onTriggered: showConfigEspecialidadesDialog = true
                                }
                            }
                        }           
                    }
                }
                
                //Filtros y búsqueda - FIJO
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    color: "transparent"
                    z: 10
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 32
                        anchors.bottomMargin: 16  
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
                            text: "Especialidad:"
                            font.bold: true
                            color: textColor
                        }
                        
                        ComboBox {
                            id: filtroEspecialidad
                            Layout.preferredWidth: 180
                            model: {
                                var list = ["Todas"]
                                for (var i = 0; i < especialidades.length; i++) {
                                    list.push(especialidades[i].nombre)
                                }
                                return list
                            }
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
               
                //Contenedor para tabla con scroll limitado
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 565
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
                                    Layout.preferredWidth: 80
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#d0d0d0"
                                    border.width: 1
                                    
                                    Label { 
                                        anchors.centerIn: parent
                                        text: "ID"
                                        font.bold: true
                                        font.pixelSize: 12
                                        color: textColor
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 200
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
                                    Layout.preferredWidth: 250
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#d0d0d0"
                                    border.width: 1
                                    
                                    Label { 
                                        anchors.centerIn: parent
                                        text: "DETALLE"
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
                                        text: "ESPECIALIDAD - DOCTOR"
                                        font.bold: true
                                        font.pixelSize: 12
                                        color: textColor
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 120
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
                                    Layout.preferredWidth: 100
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
                                    Layout.preferredWidth: 120
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
                            Layout.preferredHeight: 545  // ✅ CAMBIAR de fillHeight a preferredHeight: 500
                            Layout.fillHeight: false     // ✅ AGREGAR esta línea
                            clip: true
                            
                            ListView {
                                id: consultasListView
                                model: consultasPaginadasModel
                                
                                delegate: Rectangle {
                                    width: ListView.view.width
                                    height: 50
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
                                            Layout.preferredWidth: 80
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Label { 
                                                anchors.centerIn: parent
                                                text: model.consultaId
                                                color: textColor
                                                font.bold: true
                                                font.pixelSize: 11
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 200
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Label { 
                                                anchors.centerIn: parent
                                                text: model.paciente
                                                color: textColor
                                                font.bold: true
                                                font.pixelSize: 12
                                                elide: Text.ElideRight
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 250
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Label { 
                                                anchors.fill: parent
                                                anchors.margins: 4
                                                text: model.detalles
                                                color: "#7f8c8d"
                                                font.pixelSize: 10
                                                wrapMode: Text.WordWrap
                                                elide: Text.ElideRight
                                                maximumLineCount: 2
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Label { 
                                                anchors.fill: parent
                                                anchors.margins: 6
                                                text: model.especialidadDoctor
                                                color: primaryColor
                                                font.bold: true
                                                font.pixelSize: 10
                                                wrapMode: Text.WordWrap
                                                elide: Text.ElideRight
                                                maximumLineCount: 2
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 120
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: 45
                                                height: 18
                                                color: model.tipo === "Emergencia" ? "#e67e22" : successColor
                                                radius: 9
                                                
                                                Label {
                                                    anchors.centerIn: parent
                                                    text: model.tipo
                                                    color: whiteColor
                                                    font.pixelSize: 8
                                                    font.bold: true
                                                }
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 100
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Label { 
                                                anchors.centerIn: parent
                                                text: "Bs" + model.precio
                                                color: model.tipo === "Emergencia" ? "#e67e22" : successColor
                                                font.bold: true
                                                font.pixelSize: 11
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 120
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Label { 
                                                anchors.centerIn: parent
                                                text: model.fecha
                                                color: textColor
                                                font.pixelSize: 11
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
                                    
                                    // Botones de acción
                                    RowLayout {
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 6
                                        spacing: 3
                                        visible: selectedRowIndex === index
                                        z: 10
                                        
                                        Button {
                                            id: editButton
                                            width: 28
                                            height: 28
                                            text: "✏️"
                                            
                                            background: Rectangle {
                                                color: warningColor
                                                radius: 6
                                                border.color: "#f1c40f"
                                                border.width: 1
                                            }
                                            
                                            contentItem: Label {
                                                text: parent.text
                                                color: whiteColor
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                                font.pixelSize: 12
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
                                            width: 28
                                            height: 28
                                            text: "🗑️"
                                            
                                            background: Rectangle {
                                                color: dangerColor
                                                radius: 6
                                                border.color: "#c0392b"
                                                border.width: 1
                                            }
                                            
                                            contentItem: Label {
                                                text: parent.text
                                                color: whiteColor
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                                font.pixelSize: 12
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
                // Control de Paginación - Centrado con indicador
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
                            enabled: currentPageConsultas > 0
                            
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
                                if (currentPageConsultas > 0) {
                                    currentPageConsultas--
                                    updatePaginatedModel()
                                }
                            }
                        }
                        
                        // Indicador de página
                        Label {
                            text: "Página " + (currentPageConsultas + 1) + " de " + Math.max(1, totalPagesConsultas)
                            color: "#374151"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }
                        
                        // Botón Siguiente
                        Button {
                            Layout.preferredWidth: 110
                            Layout.preferredHeight: 36
                            text: "Siguiente →"
                            enabled: currentPageConsultas < totalPagesConsultas - 1
                            
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

    // Diálogo Nueva Consulta / Editar Consulta
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
    
    Rectangle {
        id: consultationForm
        anchors.centerIn: parent
        width: 500
        height: 650
        color: whiteColor
        radius: 20
        border.color: lightGrayColor
        border.width: 2
        visible: showNewConsultationDialog
        
        property int selectedEspecialidadIndex: -1
        property string consultationType: "Normal"
        property real calculatedPrice: 0.0
        
        // Función para cargar datos en modo edición
        function loadEditData() {
            if (isEditMode && editingIndex >= 0) {
                var consulta = consultasListModel.get(editingIndex)
                
                // Extraer nombres del paciente completo
                var nombreCompleto = consulta.paciente.split(" ")
                nombrePaciente.text = nombreCompleto[0] || ""
                apellidoPaterno.text = nombreCompleto[1] || ""
                apellidoMaterno.text = nombreCompleto.slice(2).join(" ") || ""
                
                // Buscar la especialidad correspondiente
                var especialidadDoctor = consulta.especialidadDoctor
                for (var i = 0; i < especialidades.length; i++) {
                    var espStr = especialidades[i].nombre + " - " + especialidades[i].doctor
                    if (espStr === especialidadDoctor) {
                        especialidadCombo.currentIndex = i + 1
                        consultationForm.selectedEspecialidadIndex = i
                        break
                    }
                }
                
                // Configurar tipo de consulta
                if (consulta.tipo === "Normal") {
                    normalRadio.checked = true
                    consultationForm.consultationType = "Normal"
                } else {
                    emergenciaRadio.checked = true
                    consultationForm.consultationType = "Emergencia"
                }
                
                // Cargar precio
                consultationForm.calculatedPrice = parseFloat(consulta.precio)
                
                // Cargar detalles
                detallesConsulta.text = consulta.detalles
            }
        }
        
        onVisibleChanged: {
            if (visible && isEditMode) {
                loadEditData()
            } else if (visible && !isEditMode) {
                // Limpiar formulario para nueva consulta
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
            anchors.margins: 30
            spacing: 20
            
            // Título
            Label {
                Layout.fillWidth: true
                text: isEditMode ? "Editar Consulta" : "Nueva Consulta"
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
            
            // Especialidad y Doctor
            RowLayout {
                Layout.fillWidth: true
                Label {
                    Layout.preferredWidth: 120
                    text: "Especialidad:"
                    font.bold: true
                    color: textColor
                }
                ComboBox {
                    id: especialidadCombo
                    Layout.fillWidth: true
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
                }
            }
            
            // Tipo de Consulta
            RowLayout {
                Layout.fillWidth: true
                Label {
                    Layout.preferredWidth: 120
                    text: "Tipo de Consulta:"
                    font.bold: true
                    color: textColor
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
                }
                Item { Layout.fillWidth: true }
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
                    text: consultationForm.selectedEspecialidadIndex >= 0 ? 
                          "Bs" + consultationForm.calculatedPrice.toFixed(2) : "Seleccione especialidad"
                    font.bold: true
                    font.pixelSize: 16
                    color: consultationForm.consultationType === "Emergencia" ? "#e67e22" : successColor
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
                }
                
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 80
                    
                    TextArea {
                        id: detallesConsulta
                        placeholderText: "Descripción de la consulta, síntomas, observaciones..."
                        wrapMode: TextArea.Wrap
                        background: Rectangle {
                            color: whiteColor
                            border.color: lightGrayColor
                            border.width: 1
                            radius: 8
                        }
                    }
                }
            }
            
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
                        // Crear datos de consulta
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
                            // ✅ ACTUALIZAR CONSULTA EXISTENTE
                            var consultaExistente = consultasListModel.get(editingIndex)
                            consultaData.consultaId = consultaExistente.consultaId
                            
                            // Actualizar en modelo filtrado
                            consultasListModel.set(editingIndex, consultaData)
                            
                            // Actualizar en datos originales
                            for (var i = 0; i < consultasOriginales.length; i++) {
                                if (consultasOriginales[i].consultaId === consultaData.consultaId) {
                                    consultasOriginales[i] = consultaData
                                    break
                                }
                            }
                            
                            console.log("Consulta actualizada:", JSON.stringify(consultaData))
                        } else {
                            // ✅ CREAR NUEVA CONSULTA
                            consultaData.consultaId = (getTotalConsultasCount() + 1).toString()
                            
                            // Agregar a modelo filtrado
                            consultasListModel.append(consultaData)
                            
                            // Agregar a datos originales
                            consultasOriginales.push(consultaData)
                            
                            console.log("Nueva consulta guardada:", JSON.stringify(consultaData))
                        }
                        
                        // ✅ ACTUALIZAR PAGINACIÓN
                        updatePaginatedModel()
                        
                        // Limpiar y cerrar
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
    
    // ✅ FUNCIÓN PARA APLICAR FILTROS - MEJORADA
    function aplicarFiltros() {
        console.log("🔍 Aplicando filtros...")
        
        // Limpiar el modelo filtrado
        consultasListModel.clear()
        
        var hoy = new Date()
        var textoBusqueda = campoBusqueda.text.toLowerCase()
        
        for (var i = 0; i < consultasOriginales.length; i++) {
            var consulta = consultasOriginales[i]
            var mostrar = true
            
            // Filtro por fecha
            if (filtroFecha.currentIndex > 0) {
                var fechaConsulta = new Date(consulta.fecha)
                var diferenciaDias = Math.floor((hoy - fechaConsulta) / (1000 * 60 * 60 * 24))
                
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
            
            // Filtro por especialidad
            if (filtroEspecialidad.currentIndex > 0 && mostrar) {
                var especialidadSeleccionada = especialidades[filtroEspecialidad.currentIndex - 1].nombre
                if (!consulta.especialidadDoctor.includes(especialidadSeleccionada)) {
                    mostrar = false
                }
            }
            
            // Filtro por tipo
            if (filtroTipo.currentIndex > 0 && mostrar) {
                var tipoSeleccionado = filtroTipo.model[filtroTipo.currentIndex]
                if (consulta.tipo !== tipoSeleccionado) {
                    mostrar = false
                }
            }
            
            // Búsqueda por texto en paciente
            if (textoBusqueda.length > 0 && mostrar) {
                if (!consulta.paciente.toLowerCase().includes(textoBusqueda)) {
                    mostrar = false
                }
            }
            
            if (mostrar) {
                consultasListModel.append(consulta)
            }
        }
        
        // ✅ RESETEAR A PRIMERA PÁGINA Y ACTUALIZAR PAGINACIÓN
        currentPageConsultas = 0
        updatePaginatedModel()
        
        console.log("✅ Filtros aplicados. Consultas mostradas:", consultasListModel.count)
    }

    // ✅ AGREGAR ESTA FUNCIÓN ANTES DE aplicarFiltros() SI NO EXISTE
    function updatePaginatedModel() {
        console.log("📄 Consultas: Actualizando paginación - Página:", currentPageConsultas + 1)
        
        // Limpiar modelo paginado
        consultasPaginadasModel.clear()
        
        // Calcular total de páginas basado en consultas filtradas
        var totalItems = consultasListModel.count
        totalPagesConsultas = Math.ceil(totalItems / itemsPerPageConsultas)
        
        // Asegurar que siempre hay al menos 1 página
        if (totalPagesConsultas === 0) {
            totalPagesConsultas = 1
        }
        
        // Ajustar página actual si es necesario
        if (currentPageConsultas >= totalPagesConsultas && totalPagesConsultas > 0) {
            currentPageConsultas = totalPagesConsultas - 1
        }
        if (currentPageConsultas < 0) {
            currentPageConsultas = 0
        }
        
        // Calcular índices
        var startIndex = currentPageConsultas * itemsPerPageConsultas
        var endIndex = Math.min(startIndex + itemsPerPageConsultas, totalItems)
        
        // Agregar elementos de la página actual
        for (var i = startIndex; i < endIndex; i++) {
            var consulta = consultasListModel.get(i)
            consultasPaginadasModel.append(consulta)
        }
        
        console.log("📄 Consultas: Página", currentPageConsultas + 1, "de", totalPagesConsultas,
                    "- Mostrando", consultasPaginadasModel.count, "de", totalItems)
    }

    // Diálogo Configuración de Especialidades
    Rectangle {
        id: configEspecialidadesBackground
        anchors.fill: parent
        color: "black"
        opacity: showConfigEspecialidadesDialog ? 0.5 : 0
        visible: opacity > 0
        
        MouseArea {
            anchors.fill: parent
            onClicked: showConfigEspecialidadesDialog = false
        }
        
        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }
    }
    
    Rectangle {
        id: configEspecialidadesDialog
        anchors.centerIn: parent
        width: 700
        height: 600
        color: whiteColor
        radius: 20
        border.color: lightGrayColor
        border.width: 2
        visible: showConfigEspecialidadesDialog
        
        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            
            // Header fijo para título y formulario
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 350
                color: whiteColor
                radius: 20
                z: 10
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 30
                    spacing: 20
                    
                    Label {
                        Layout.fillWidth: true
                        text: "🏥 Configuración de Especialidades"
                        font.pixelSize: 24
                        font.bold: true
                        color: textColor
                        horizontalAlignment: Text.AlignHCenter
                    }
                    
                    // Formulario para agregar nueva especialidad
                    GroupBox {
                        Layout.fillWidth: true
                        title: "Agregar Nueva Especialidad"
                        
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
                                text: "Especialidad:"
                                font.bold: true
                                color: textColor
                            }
                            TextField {
                                id: nuevaEspecialidadNombre
                                Layout.fillWidth: true
                                placeholderText: "Ej: Dermatología"
                                background: Rectangle {
                                    color: whiteColor
                                    border.color: lightGrayColor
                                    border.width: 1
                                    radius: 6
                                }
                            }
                            
                            Label {
                                text: "Doctor:"
                                font.bold: true
                                color: textColor
                            }
                            TextField {
                                id: nuevaEspecialidadDoctor
                                Layout.fillWidth: true
                                placeholderText: "Ej: Dr. Ana María García"
                                background: Rectangle {
                                    color: whiteColor
                                    border.color: lightGrayColor
                                    border.width: 1
                                    radius: 6
                                }
                            }
                            
                            Label {
                                text: "Precio Normal:"
                                font.bold: true
                                color: textColor
                            }
                            TextField {
                                id: nuevaEspecialidadPrecioNormal
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
                                id: nuevaEspecialidadPrecioEmergencia
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
                                text: "➕ Agregar Especialidad"
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
                                    if (nuevaEspecialidadNombre.text && nuevaEspecialidadDoctor.text && 
                                        nuevaEspecialidadPrecioNormal.text && nuevaEspecialidadPrecioEmergencia.text) {
                                        
                                        var nuevaEspecialidad = {
                                            nombre: nuevaEspecialidadNombre.text,
                                            doctor: nuevaEspecialidadDoctor.text,
                                            precioNormal: parseFloat(nuevaEspecialidadPrecioNormal.text),
                                            precioEmergencia: parseFloat(nuevaEspecialidadPrecioEmergencia.text)
                                        }
                                        
                                        especialidades.push(nuevaEspecialidad)
                                        consultasRoot.especialidades = especialidades
                                        
                                        // Limpiar campos
                                        nuevaEspecialidadNombre.text = ""
                                        nuevaEspecialidadDoctor.text = ""
                                        nuevaEspecialidadPrecioNormal.text = ""
                                        nuevaEspecialidadPrecioEmergencia.text = ""
                                        
                                        console.log("Nueva especialidad agregada:", JSON.stringify(nuevaEspecialidad))
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // Lista de especialidades existentes con scroll limitado
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
                        model: especialidades
                        delegate: Rectangle {
                            width: ListView.view.width
                            height: 70
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
                                
                                // Especialidad y Doctor
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
                                        text: modelData.doctor
                                        color: textColor
                                        font.pixelSize: 12
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
                                        text: "Bs" + modelData.precioNormal.toFixed(2)
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
                                        color: "#e67e22"
                                        font.pixelSize: 12
                                    }
                                    Label {
                                        text: "Bs" + modelData.precioEmergencia.toFixed(2)
                                        color: "#e67e22"
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
                                        especialidades.splice(index, 1)
                                        consultasRoot.especialidades = especialidades
                                        console.log("Especialidad eliminada en índice:", index)
                                    }
                                }
                            }
                        }
                    }
                }
            }      
        }
    } 
    
    // ✅ FUNCIÓN PARA OBTENER TOTAL DE CONSULTAS
    function getTotalConsultasCount() {
        return consultasOriginales.length
    }
    
    // ✅ INICIALIZACIÓN AL CARGAR EL COMPONENTE
    Component.onCompleted: {
        console.log("🩺 Módulo Consultas iniciado")
        
        // Cargar datos originales
        for (var i = 0; i < consultasModelData.length; i++) {
            consultasOriginales.push(consultasModelData[i])
            consultasListModel.append(consultasModelData[i])
        }
        
        // Inicializar paginación
        updatePaginatedModel()
        
        console.log("✅ Consultas cargadas:", consultasOriginales.length)
    }
}