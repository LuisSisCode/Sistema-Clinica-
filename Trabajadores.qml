import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

Item {
    id: trabajadoresRoot
    objectName: "trabajadoresRoot"
    
    // ===== SISTEMA DE MEDIDAS RESPONSIVAS =====
    readonly property real baseUnit: Math.min(width, height) / 100
    readonly property real smallMargin: baseUnit * 1
    readonly property real mediumMargin: baseUnit * 2
    readonly property real largeMargin: baseUnit * 3
    readonly property real extraLargeMargin: baseUnit * 4
    
    readonly property real smallFont: baseUnit * 1.5
    readonly property real mediumFont: baseUnit * 2.0
    readonly property real largeFont: baseUnit * 3.0
    readonly property real titleFont: baseUnit * 4.0
    
    readonly property real smallRadius: baseUnit * 0.8
    readonly property real mediumRadius: baseUnit * 1.2
    readonly property real largeRadius: baseUnit * 2
    
    readonly property real rowHeight: baseUnit * 6 // Altura responsiva para filas
    readonly property real headerHeight: baseUnit * 6
    readonly property real buttonHeight: baseUnit * 4
    
    // ===== COLORES =====
    readonly property color primaryColor: "#3498DB"
    readonly property color successColor: "#27ae60"
    readonly property color dangerColor: "#E74C3C"
    readonly property color warningColor: "#f39c12"
    readonly property color lightGrayColor: "#ECF0F1"
    readonly property color textColor: "#2c3e50"
    readonly property color whiteColor: "#FFFFFF"
    readonly property color infoColor: "#17a2b8"
    readonly property color violetColor: "#9b59b6"
    
    // ===== PROPIEDADES PARA DIÁLOGOS =====
    property bool showNewWorkerDialog: false
    property bool showConfigTiposDialog: false
    property bool isEditMode: false
    property int editingIndex: -1
    property int selectedRowIndex: -1
    
    // ===== MODELO DE TIPOS DE TRABAJADORES =====
    ListModel {
        id: tiposTrabajadoresModel
        
        Component.onCompleted: {
            append({
                nombre: "Médico General", 
                descripcion: "Profesional médico con título universitario en medicina",
                requiereMatricula: true,
                especialidades: ["Medicina General", "Medicina Familiar"]
            })
            append({
                nombre: "Médico Especialista", 
                descripcion: "Médico con especialización en área específica",
                requiereMatricula: true,
                especialidades: ["Cardiología", "Pediatría", "Ginecología", "Traumatología", "Neurología"]
            })
            append({
                nombre: "Enfermero(a)", 
                descripcion: "Profesional de enfermería licenciado",
                requiereMatricula: true,
                especialidades: ["Enfermería General", "Enfermería Quirúrgica", "Enfermería Pediátrica"]
            })
            append({
                nombre: "Laboratorista", 
                descripcion: "Técnico especializado en análisis de laboratorio",
                requiereMatricula: true,
                especialidades: ["Laboratorio Clínico", "Microbiología", "Hematología"]
            })
            append({
                nombre: "Administrativo", 
                descripcion: "Personal de administración y gestión",
                requiereMatricula: false,
                especialidades: ["Recursos Humanos", "Contabilidad", "Recepción", "Archivo"]
            })
        }
    }

    // ===== FUNCIONES HELPER =====
    function getTiposTrabajadoresNombres() {
        var nombres = ["Todos los tipos"]
        for (var i = 0; i < tiposTrabajadoresModel.count; i++) {
            nombres.push(tiposTrabajadoresModel.get(i).nombre)
        }
        return nombres
    }

    function getTiposTrabajadoresParaCombo() {
        var nombres = ["Seleccionar tipo..."]
        for (var i = 0; i < tiposTrabajadoresModel.count; i++) {
            nombres.push(tiposTrabajadoresModel.get(i).nombre)
        }
        return nombres
    }

    // ===== MODELO PARA TRABAJADORES EXISTENTES =====
    property var trabajadoresModel: [
        {
            trabajadorId: "1",
            nombreCompleto: "Dr. Juan Carlos Mendoza",
            tipoTrabajador: "Médico Especialista",
            especialidad: "Cardiología",
            matricula: "MED-001-2020",
            fechaRegistro: "2025-01-15"
        },
        {
            trabajadorId: "2",
            nombreCompleto: "Lic. María Elena Vargas",
            tipoTrabajador: "Enfermero(a)",
            especialidad: "Enfermería General",
            matricula: "ENF-045-2021",
            fechaRegistro: "2025-02-10"
        },
        {
            trabajadorId: "3",
            nombreCompleto: "Dra. Ana Patricia Silva",
            tipoTrabajador: "Médico General",
            especialidad: "Medicina General",
            matricula: "MED-032-2019",
            fechaRegistro: "2025-01-08"
        },
        {
            trabajadorId: "4",
            nombreCompleto: "Sr. Roberto García",
            tipoTrabajador: "Administrativo",
            especialidad: "Recepción",
            matricula: "",
            fechaRegistro: "2025-03-01"
        }
    ]

    // ===== LAYOUT PRINCIPAL RESPONSIVO =====
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: largeMargin
        spacing: mediumMargin
        
        // ===== CONTENIDO PRINCIPAL =====
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: whiteColor
            radius: largeRadius
            border.color: "#e0e0e0"
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                
                // ===== HEADER RESPONSIVO =====
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: headerHeight
                    color: "#f8f9fa"
                    border.color: "#e0e0e0"
                    border.width: 1
                    radius: largeRadius
                    
                    Rectangle {
                        anchors.fill: parent
                        anchors.bottomMargin: mediumMargin
                        color: parent.color
                        radius: parent.radius
                    }
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: mediumMargin
                        spacing: mediumMargin
                        
                        // Título y icono
                        RowLayout {
                            spacing: smallMargin
                            
                            Label {
                                text: "👥"
                                font.pixelSize: titleFont
                                color: primaryColor
                            }
                            
                            Label {
                                text: "Gestión de Trabajadores"
                                font.pixelSize: largeFont
                                font.bold: true
                                color: textColor
                            }
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        // Botón Nuevo Trabajador
                        Button {
                            objectName: "newWorkerButton"
                            text: "➕ Nuevo Trabajador"
                            Layout.preferredHeight: buttonHeight
                            
                            background: Rectangle {
                                color: primaryColor
                                radius: mediumRadius
                            }
                            
                            contentItem: Label {
                                text: parent.text
                                color: whiteColor
                                font.bold: true
                                font.pixelSize: mediumFont
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: {
                                isEditMode = false
                                editingIndex = -1
                                showNewWorkerDialog = true
                            }
                        }
                        
                        // Botón de configuración
                        Button {
                            id: configButton
                            text: "⚙️"
                            Layout.preferredWidth: buttonHeight
                            Layout.preferredHeight: buttonHeight
                            font.pixelSize: mediumFont
                            
                            background: Rectangle {
                                color: "#6c757d"
                                radius: mediumRadius
                            }
                            
                            contentItem: Label {
                                text: parent.text
                                color: whiteColor
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: configMenu.open()
                            
                            Menu {
                                id: configMenu
                                y: parent.height
                                
                                MenuItem {
                                    text: "👥 Configuración de Tipos de Trabajadores"
                                    onTriggered: showConfigTiposDialog = true
                                }
                            }
                        }
                    }
                }
                
                // ===== FILTROS RESPONSIVOS =====
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: headerHeight * 0.8
                    color: "transparent"
                    z: 10
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: mediumMargin
                        spacing: mediumMargin
                        
                        Label {
                            text: "Filtrar por:"
                            font.bold: true
                            font.pixelSize: mediumFont
                            color: textColor
                        }
                        
                        ComboBox {
                            id: filtroTipo
                            Layout.preferredWidth: width > 0 ? Math.max(120, parent.width * 0.2) : 120
                            Layout.preferredHeight: buttonHeight
                            model: getTiposTrabajadoresNombres()
                            currentIndex: 0
                            font.pixelSize: smallFont*1.3
                            onCurrentIndexChanged: aplicarFiltros()
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        TextField {
                            id: campoBusqueda
                            Layout.preferredWidth: Math.max(150, parent.width * 0.25)
                            Layout.preferredHeight: buttonHeight
                            placeholderText: "Buscar trabajador..."
                            font.pixelSize: smallFont*1.3
                            onTextChanged: aplicarFiltros()
                            
                            background: Rectangle {
                                color: whiteColor
                                border.color: "#e0e0e0"
                                border.width: 1
                                radius: smallRadius
                            }
                        }
                    }
                }
               
                // ===== TABLA RESPONSIVA =====
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.margins: mediumMargin
                    
                    ScrollView {
                        anchors.fill: parent
                        clip: true
                        
                        ListView {
                            id: trabajadoresListView
                            model: ListModel {
                                id: trabajadoresListModel
                                Component.onCompleted: {
                                    for (var i = 0; i < trabajadoresModel.length; i++) {
                                        append(trabajadoresModel[i])
                                    }
                                }
                            }
                            
                            // ===== HEADER DE LA TABLA =====
                            header: Rectangle {
                                width: parent.width
                                height: rowHeight * 0.8
                                color: "#f5f5f5"
                                border.color: "#d0d0d0"
                                border.width: 1
                                z: 5
                                
                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 0
                                    
                                    Rectangle {
                                        Layout.preferredWidth: Math.max(40, parent.width * 0.08)
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#d0d0d0"
                                        border.width: 1
                                        
                                        Label { 
                                            anchors.centerIn: parent
                                            text: "ID"
                                            font.bold: true
                                            font.pixelSize: smallFont*1.3
                                            color: textColor
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: Math.max(120, parent.width * 0.25)
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#d0d0d0"
                                        border.width: 1
                                        
                                        Label { 
                                            anchors.centerIn: parent
                                            text: "NOMBRE COMPLETO"
                                            font.bold: true
                                            font.pixelSize: smallFont*1.3
                                            color: textColor
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: Math.max(100, parent.width * 0.22)
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#d0d0d0"
                                        border.width: 1
                                        
                                        Label { 
                                            anchors.centerIn: parent
                                            text: "TIPO TRABAJADOR"
                                            font.bold: true
                                            font.pixelSize: smallFont*1.3
                                            color: textColor
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: Math.max(80, parent.width * 0.20)
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#d0d0d0"
                                        border.width: 1
                                        
                                        Label { 
                                            anchors.centerIn: parent
                                            text: "ESPECIALIDAD"
                                            font.bold: true
                                            font.pixelSize: smallFont*1.3
                                            color: textColor
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: Math.max(80, parent.width * 0.15)
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#d0d0d0"
                                        border.width: 1
                                        
                                        Label { 
                                            anchors.centerIn: parent
                                            text: "MATRÍCULA"
                                            font.bold: true
                                            font.pixelSize: smallFont*1.3
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
                                            font.pixelSize: smallFont*1.3
                                            color: textColor
                                        }
                                    }                                   
                                }
                            }
                            
                            // ===== FILAS DE LA TABLA (ALTURA REDUCIDA) =====
                            delegate: Rectangle {
                                width: ListView.view.width
                                height: rowHeight  // Altura responsiva reducida
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
                                        Layout.preferredWidth: Math.max(40, parent.width * 0.08)
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#d0d0d0"
                                        border.width: 1
                                        
                                        Label { 
                                            anchors.centerIn: parent
                                            text: model.trabajadorId
                                            color: textColor
                                            font.bold: true
                                            font.pixelSize: smallFont*1.3
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: Math.max(120, parent.width * 0.25)
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#d0d0d0"
                                        border.width: 1
                                        
                                        Label { 
                                            anchors.fill: parent
                                            anchors.margins: smallMargin
                                            text: model.nombreCompleto
                                            color: primaryColor
                                            font.bold: true
                                            font.pixelSize: smallFont*1.3
                                            elide: Text.ElideRight
                                            wrapMode: Text.WordWrap
                                            maximumLineCount: 2
                                            verticalAlignment: Text.AlignVCenter
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: Math.max(100, parent.width * 0.22)
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#d0d0d0"
                                        border.width: 1
                                        
                                        Label { 
                                            anchors.fill: parent
                                            anchors.margins: smallMargin
                                            text: model.tipoTrabajador
                                            color: textColor
                                            font.bold: true
                                            font.pixelSize: smallFont*1.3
                                            elide: Text.ElideRight
                                            wrapMode: Text.WordWrap
                                            maximumLineCount: 2
                                            verticalAlignment: Text.AlignVCenter
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: Math.max(80, parent.width * 0.20)
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#d0d0d0"
                                        border.width: 1
                                        
                                        Label { 
                                            anchors.fill: parent
                                            anchors.margins: smallMargin
                                            text: model.especialidad
                                            color: "#7f8c8d"
                                            font.pixelSize: smallFont
                                            elide: Text.ElideRight
                                            wrapMode: Text.WordWrap
                                            maximumLineCount: 2
                                            verticalAlignment: Text.AlignVCenter
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: Math.max(80, parent.width * 0.15)
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#d0d0d0"
                                        border.width: 1
                                        
                                        Label { 
                                            anchors.fill: parent
                                            anchors.margins: smallMargin
                                            text: model.matricula || "Sin matrícula"
                                            color: model.matricula ? textColor : "#95a5a6"
                                            font.pixelSize: smallFont * 0.9
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
                                        
                                        TextField {
                                            anchors.fill: parent
                                            anchors.margins: smallMargin
                                            placeholderText: "DD/MM/YYYY"
                                            text: ""
                                            font.pixelSize: smallFont * 0.9
                                            background: Rectangle {
                                                color: "transparent"
                                                border.color: "transparent"
                                            }
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }                                    
                                }
                                
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        selectedRowIndex = index
                                        console.log("Seleccionado trabajador ID:", model.trabajadorId)
                                    }
                                }
                                
                                // ===== BOTONES DE ACCIÓN RESPONSIVOS =====
                                RowLayout {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: smallMargin
                                    spacing: smallMargin / 2
                                    visible: selectedRowIndex === index
                                    z: 10
                                    
                                    Button {
                                        id: editButton
                                        width: buttonHeight * 0.8
                                        height: buttonHeight * 0.8
                                        text: "✏️"
                                        
                                        background: Rectangle {
                                            color: warningColor
                                            radius: smallRadius
                                            border.color: "#f1c40f"
                                            border.width: 1
                                        }
                                        
                                        contentItem: Label {
                                            text: parent.text
                                            color: whiteColor
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            font.pixelSize: smallFont
                                        }
                                        
                                        onClicked: {
                                            isEditMode = true
                                            editingIndex = index
                                            var trabajador = trabajadoresListModel.get(index)
                                            console.log("Editando trabajador:", JSON.stringify(trabajador))
                                            showNewWorkerDialog = true
                                        }
                                    }
                                    
                                    Button {
                                        id: deleteButton
                                        width: buttonHeight * 0.8
                                        height: buttonHeight * 0.8
                                        text: "🗑️"
                                        
                                        background: Rectangle {
                                            color: dangerColor
                                            radius: smallRadius
                                            border.color: "#c0392b"
                                            border.width: 1
                                        }
                                        
                                        contentItem: Label {
                                            text: parent.text
                                            color: whiteColor
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            font.pixelSize: smallFont
                                        }
                                        
                                        onClicked: {
                                            trabajadoresListModel.remove(index)
                                            selectedRowIndex = -1
                                            console.log("Trabajador eliminado en índice:", index)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ===== FUNCIÓN PARA APLICAR FILTROS =====
    function aplicarFiltros() {
        trabajadoresListModel.clear()
        
        var textoBusqueda = campoBusqueda.text.toLowerCase()
        
        for (var i = 0; i < trabajadoresModel.length; i++) {
            var trabajador = trabajadoresModel[i]
            var mostrar = true
            
            // Filtro por tipo
            if (filtroTipo.currentIndex > 0 && mostrar) {
                var tipoSeleccionado = filtroTipo.model[filtroTipo.currentIndex]
                if (trabajador.tipoTrabajador !== tipoSeleccionado) {
                    mostrar = false
                }
            }
            
            // Búsqueda por texto en nombre
            if (textoBusqueda.length > 0 && mostrar) {
                if (!trabajador.nombreCompleto.toLowerCase().includes(textoBusqueda)) {
                    mostrar = false
                }
            }
            
            if (mostrar) {
                trabajadoresListModel.append(trabajador)
            }
        }
    }

    // ===== DIÁLOGOS (MANTENGO LA FUNCIONALIDAD ORIGINAL PERO CON MEDIDAS RESPONSIVAS) =====
    
    // Fondo del diálogo
    Rectangle {
        id: newWorkerDialog
        anchors.fill: parent
        color: "black"
        opacity: showNewWorkerDialog ? 0.5 : 0
        visible: opacity > 0
        
        MouseArea {
            anchors.fill: parent
            onClicked: {
                showNewWorkerDialog = false
                selectedRowIndex = -1
            }
        }
        
        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }
    }
    
    // Diálogo del formulario (continúa igual pero con medidas responsivas)
    Rectangle {
        id: workerForm
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.8, 600)
        height: Math.min(parent.height * 0.8, 550)
        color: whiteColor
        radius: largeRadius
        border.color: lightGrayColor
        border.width: 2
        visible: showNewWorkerDialog
        
        property int selectedTipoTrabajadorIndex: -1
                
        // Función para cargar datos en modo edición
        function loadEditData() {
            if (isEditMode && editingIndex >= 0) {
                var trabajador = trabajadoresListModel.get(editingIndex)
                
                // Extraer nombres del trabajador completo
                var nombreCompleto = trabajador.nombreCompleto.split(" ")
                nombreTrabajador.text = nombreCompleto[0] || ""
                apellidoPaterno.text = nombreCompleto[1] || ""
                apellidoMaterno.text = nombreCompleto.slice(2).join(" ") || ""
                
                // Buscar el tipo de trabajador correspondiente
                var tipoTrabajadorNombre = trabajador.tipoTrabajador
                for (var i = 0; i < tiposTrabajadoresModel.count; i++) {
                    if (tiposTrabajadoresModel.get(i).nombre === tipoTrabajadorNombre) {
                        tipoTrabajadorCombo.currentIndex = i + 1
                        workerForm.selectedTipoTrabajadorIndex = i
                        break
                    }
                }
                
                // Cargar especialidad
                especialidadCombo.editText = trabajador.especialidad
                
                // Cargar matrícula
                matriculaField.text = trabajador.matricula || ""
            }
        }
        
        onVisibleChanged: {
            if (visible && isEditMode) {
                loadEditData()
            } else if (visible && !isEditMode) {
                // Limpiar formulario para nuevo trabajador
                nombreTrabajador.text = ""
                apellidoPaterno.text = ""
                apellidoMaterno.text = ""
                tipoTrabajadorCombo.currentIndex = 0
                tipoTrabajadorCombo.model = getTiposTrabajadoresParaCombo()
                especialidadCombo.currentIndex = 0
                matriculaField.text = ""
                workerForm.selectedTipoTrabajadorIndex = -1
            }
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 30
            spacing: 20
            
            // Título
            Label {
                Layout.fillWidth: true
                text: isEditMode ? "Editar Trabajador" : "Nuevo Trabajador"
                font.pixelSize: 24
                font.bold: true
                color: textColor
                horizontalAlignment: Text.AlignHCenter
            }
            
            // Datos del Trabajador
            GroupBox {
                Layout.fillWidth: true
                title: "Datos Personales"
                
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
                        id: nombreTrabajador
                        Layout.fillWidth: true
                        placeholderText: "Nombre del trabajador"
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
                }
            }
            
            // Información Profesional
            GroupBox {
                Layout.fillWidth: true
                title: "Información Profesional"
                
                background: Rectangle {
                    color: "#f8f9fa"
                    border.color: lightGrayColor
                    border.width: 1
                    radius: 8
                }
                
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 12
                    
                    // Tipo de Trabajador
                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            Layout.preferredWidth: 120
                            text: "Tipo:"
                            font.bold: true
                            color: textColor
                        }
                        ComboBox {
                            id: tipoTrabajadorCombo
                            Layout.fillWidth: true
                            model: getTiposTrabajadoresParaCombo()
                            onCurrentIndexChanged: {
                                if (currentIndex > 0) {
                                    workerForm.selectedTipoTrabajadorIndex = currentIndex - 1
                                    var tipoTrabajador = tiposTrabajadoresModel.get(workerForm.selectedTipoTrabajadorIndex)
                                    
                                    // Actualizar especialidades disponibles
                                    especialidadCombo.model = tipoTrabajador.especialidades
                                    especialidadCombo.currentIndex = 0
                                    
                                    // Mostrar/ocultar campo matrícula
                                    matriculaRow.visible = tipoTrabajador.requiereMatricula
                                } else {
                                    workerForm.selectedTipoTrabajadorIndex = -1
                                    especialidadCombo.model = []
                                    matriculaRow.visible = false
                                }
                            }
                        }
                    }
                    
                    // Especialidad
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
                            editable: true
                            model: []
                        }
                    }
                    
                    // Matrícula
                    RowLayout {
                        id: matriculaRow
                        Layout.fillWidth: true
                        visible: false
                        Label {
                            Layout.preferredWidth: 120
                            text: "Matrícula:"
                            font.bold: true
                            color: textColor
                        }
                        TextField {
                            id: matriculaField
                            Layout.fillWidth: true
                            placeholderText: "Número de matrícula profesional"
                            background: Rectangle {
                                color: whiteColor
                                border.color: lightGrayColor
                                border.width: 1
                                radius: 6
                            }
                        }
                    }
                }
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
                        // Limpiar y cerrar
                        showNewWorkerDialog = false
                        selectedRowIndex = -1
                        isEditMode = false
                        editingIndex = -1
                    }
                }
                
                Button {
                    text: isEditMode ? "Actualizar" : "Guardar"
                    enabled: workerForm.selectedTipoTrabajadorIndex >= 0 && 
                             nombreTrabajador.text.length > 0
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
                        // Crear datos de trabajador
                        var nombreCompleto = nombreTrabajador.text + " " + 
                                           apellidoPaterno.text + " " + 
                                           apellidoMaterno.text
                        
                        var tipoTrabajador = tiposTrabajadoresModel.get(workerForm.selectedTipoTrabajadorIndex)
                        
                        var trabajadorData = {
                            nombreCompleto: nombreCompleto.trim(),
                            tipoTrabajador: tipoTrabajador.nombre,
                            especialidad: especialidadCombo.editText || especialidadCombo.currentText,
                            matricula: tipoTrabajador.requiereMatricula ? matriculaField.text : "",
                            fechaRegistro: new Date().toISOString().split('T')[0]
                        }
                        
                        if (isEditMode && editingIndex >= 0) {
                            // Actualizar trabajador existente - mantener el ID original
                            var trabajadorExistente = trabajadoresListModel.get(editingIndex)
                            trabajadorData.trabajadorId = trabajadorExistente.trabajadorId
                            
                            trabajadoresListModel.set(editingIndex, trabajadorData)
                            console.log("Trabajador actualizado:", JSON.stringify(trabajadorData))
                        } else {
                            // Crear nuevo trabajador con nuevo ID
                            trabajadorData.trabajadorId = (trabajadoresListModel.count + 1).toString()
                            trabajadoresListModel.append(trabajadorData)
                            console.log("Nuevo trabajador guardado:", JSON.stringify(trabajadorData))
                        }
                        
                        // Actualizar filtros después de agregar/editar
                        filtroTipo.model = getTiposTrabajadoresNombres()
                        
                        // Limpiar y cerrar
                        showNewWorkerDialog = false
                        selectedRowIndex = -1
                        isEditMode = false
                        editingIndex = -1
                    }
                }
            }
        }
    }

    // Diálogo Configuración de Tipos de Trabajadores (Editable)
    Rectangle {
        id: configTiposBackground
        anchors.fill: parent
        color: "black"
        opacity: showConfigTiposDialog ? 0.5 : 0
        visible: opacity > 0
        
        MouseArea {
            anchors.fill: parent
            onClicked: showConfigTiposDialog = false
        }
        
        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }
    }
    
    Rectangle {
        id: configTiposDialog
        anchors.centerIn: parent
        width: 800
        height: 700
        color: whiteColor
        radius: 20
        border.color: lightGrayColor
        border.width: 2
        visible: showConfigTiposDialog
        
        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            
            // Header fijo para título y formulario
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 450
                color: whiteColor
                radius: 20
                z: 10
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 30
                    spacing: 20
                    
                    Label {
                        Layout.fillWidth: true
                        text: "👥 Configuración de Tipos de Trabajadores"
                        font.pixelSize: 24
                        font.bold: true
                        color: textColor
                        horizontalAlignment: Text.AlignHCenter
                    }
                    
                    // Formulario para agregar nuevo tipo de trabajador
                    GroupBox {
                        Layout.fillWidth: true
                        title: "Agregar Nuevo Tipo de Trabajador"
                        
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
                                id: nuevoTipoNombre
                                Layout.fillWidth: true
                                placeholderText: "Ej: Médico General"
                                background: Rectangle {
                                    color: whiteColor
                                    border.color: lightGrayColor
                                    border.width: 1
                                    radius: 6
                                }
                            }
                            
                            Label {
                                text: "Descripción:"
                                font.bold: true
                                color: textColor
                            }
                            ScrollView {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 60
                                
                                TextArea {
                                    id: nuevoTipoDescripcion
                                    placeholderText: "Descripción del tipo de trabajador..."
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
                                text: "Especialidades:"
                                font.bold: true
                                color: textColor
                            }
                            TextField {
                                id: nuevoTipoEspecialidades
                                Layout.fillWidth: true
                                placeholderText: "Ej: Medicina General, Medicina Familiar (separadas por comas)"
                                background: Rectangle {
                                    color: whiteColor
                                    border.color: lightGrayColor
                                    border.width: 1
                                    radius: 6
                                }
                            }
                            
                            Label {
                                text: "Requiere Matrícula:"
                                font.bold: true
                                color: textColor
                            }
                            
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                
                                CheckBox {
                                    id: requiereMatriculaCheck
                                    text: "Sí, requiere matrícula profesional"
                                    checked: true
                                }
                                
                                Item { Layout.fillWidth: true }
                            }
                            
                            Item { }
                            Button {
                                Layout.alignment: Qt.AlignRight
                                text: "➕ Agregar Tipo de Trabajador"
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
                                    if (nuevoTipoNombre.text && nuevoTipoDescripcion.text && nuevoTipoEspecialidades.text) {
                                        
                                        var especialidadesTexto = nuevoTipoEspecialidades.text
                                        var especialidadesArray = especialidadesTexto.split(',')
                                        
                                        // Limpiar espacios de cada especialidad
                                        for (var i = 0; i < especialidadesArray.length; i++) {
                                            especialidadesArray[i] = especialidadesArray[i].trim()
                                        }
                                        
                                        // USAR APPEND DEL LISTMODEL
                                        tiposTrabajadoresModel.append({
                                            nombre: nuevoTipoNombre.text,
                                            descripcion: nuevoTipoDescripcion.text,
                                            requiereMatricula: requiereMatriculaCheck.checked,
                                            especialidades: especialidadesArray
                                        })
                                        
                                        // Actualizar los ComboBox que dependen de tiposTrabajadoresModel
                                        filtroTipo.model = getTiposTrabajadoresNombres()
                                        if (workerForm.visible) {
                                            tipoTrabajadorCombo.model = getTiposTrabajadoresParaCombo()
                                        }
                                        
                                        // Limpiar campos
                                        nuevoTipoNombre.text = ""
                                        nuevoTipoDescripcion.text = ""
                                        nuevoTipoEspecialidades.text = ""
                                        requiereMatriculaCheck.checked = true
                                        
                                        console.log("Nuevo tipo de trabajador agregado. Total tipos:", tiposTrabajadoresModel.count)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // Lista de tipos de trabajadores existentes con scroll
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 20
                Layout.topMargin: 0
                color: "transparent"
                
                ScrollView {
                    anchors.fill: parent
                    clip: true
                    
                    ListView {
                        model: tiposTrabajadoresModel
                        spacing: 2
                        
                        delegate: Rectangle {
                            width: ListView.view.width
                            height: 100
                            color: index % 2 === 0 ? "transparent" : "#fafafa"
                            border.color: "#e8e8e8"
                            border.width: 1
                            radius: 6
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 12
                                
                                // Contenido principal
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    
                                    RowLayout {
                                        Layout.fillWidth: true
                                        
                                        Label {
                                            text: model.nombre
                                            font.bold: true
                                            color: primaryColor
                                            font.pixelSize: 14
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 80
                                            Layout.preferredHeight: 20
                                            color: model.requiereMatricula ? infoColor : "#95a5a6"
                                            radius: 10
                                            
                                            Label {
                                                anchors.centerIn: parent
                                                text: model.requiereMatricula ? "Matrícula" : "Sin Matrícula"
                                                color: whiteColor
                                                font.pixelSize: 9
                                                font.bold: true
                                            }
                                        }
                                        
                                        Item { Layout.fillWidth: true }
                                    }
                                    
                                    Label {
                                        Layout.fillWidth: true
                                        text: model.descripcion
                                        color: textColor
                                        font.pixelSize: 11
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                    }
                                    
                                    Label {
                                        Layout.fillWidth: true
                                        text: "Especialidades: " + (model.especialidades ? model.especialidades.join(", ") : "")
                                        color: "#7f8c8d"
                                        font.pixelSize: 10
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
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
                                        font.pixelSize: 12
                                    }
                                    onClicked: {
                                        // USAR REMOVE DEL LISTMODEL
                                        tiposTrabajadoresModel.remove(index)
                                        
                                        // Actualizar los ComboBox que dependen de tiposTrabajadoresModel
                                        filtroTipo.model = getTiposTrabajadoresNombres()
                                        if (workerForm.visible) {
                                            tipoTrabajadorCombo.model = getTiposTrabajadoresParaCombo()
                                        }
                                        
                                        console.log("Tipo de trabajador eliminado en índice:", index)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}