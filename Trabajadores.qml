import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

Item {
    id: trabajadoresRoot
    objectName: "trabajadoresRoot"
    
    // ACCESO A PROPIEDADES ADAPTATIVAS DEL MAIN
    readonly property real baseUnit: parent.baseUnit || Math.max(8, Screen.height / 100)
    readonly property real fontBaseSize: parent.fontBaseSize || Math.max(12, Screen.height / 70)
    readonly property real scaleFactor: parent.scaleFactor || Math.min(width / 1400, height / 900)
    
    // ===== COLORES MODERNOS =====
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
    readonly property color lineColor: "#D1D5DB" // Color para líneas verticales
    readonly property color violetColor: "#9b59b6"
    readonly property color infoColor: "#17a2b8"
    
    // ===== PROPIEDADES PARA DIÁLOGOS =====
    property bool showNewWorkerDialog: false
    // ===== PASO 3a: ELIMINADA PROPIEDAD showConfigTiposDialog =====
    // property bool showConfigTiposDialog: false  // REMOVIDO
    property bool isEditMode: false
    property int editingIndex: -1
    property int selectedRowIndex: -1
    
    // ===== PASO 3c: NUEVA SEÑAL PARA NAVEGAR A CONFIGURACIÓN PERSONAL =====
    signal irAConfigPersonal()
    
    // Distribución de columnas responsive
    readonly property real colId: 0.08
    readonly property real colNombre: 0.25
    readonly property real colTipo: 0.22
    readonly property real colEspecialidad: 0.20
    readonly property real colMatricula: 0.15
    readonly property real colFecha: 0.10
    
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

    // MODELOS
    ListModel {
        id: trabajadoresListModel
    }

    // ===== LAYOUT PRINCIPAL RESPONSIVO =====
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: baseUnit * 4
        spacing: baseUnit * 3
        
        // ===== CONTENIDO PRINCIPAL =====
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
                
                // ===== HEADER MODERNO =====
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
                                text: "👥"
                                font.pixelSize: fontBaseSize * 1.8
                                color: primaryColor
                            }
                            
                            Label {
                                text: "Gestión de Trabajadores"
                                font.pixelSize: fontBaseSize * 1.4
                                font.bold: true
                                font.family: "Segoe UI, Arial, sans-serif"
                                color: textColor
                            }
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        // Botón Nuevo Trabajador
                        Button {
                            objectName: "newWorkerButton"
                            text: "➕ Nuevo Trabajador"
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
                                showNewWorkerDialog = true
                            }
                        }
                    }
                }
                
                // ===== FILTROS ADAPTATIVOS =====
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: width < 1000 ? baseUnit * 16 : baseUnit * 8
                    color: "transparent"
                    z: 10
                    
                    GridLayout {
                        anchors.fill: parent
                        anchors.margins: baseUnit * 3
                        anchors.bottomMargin: baseUnit * 1.5
                        
                        columns: width < 1000 ? 2 : 3
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
                                id: filtroTipo
                                Layout.fillWidth: true
                                Layout.preferredHeight: baseUnit * 4
                                model: getTiposTrabajadoresNombres()
                                currentIndex: 0
                                onCurrentIndexChanged: aplicarFiltros()
                                
                                contentItem: Label {
                                    text: filtroTipo.displayText
                                    font.pixelSize: fontBaseSize * 0.8
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    color: textColor
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: baseUnit
                                    elide: Text.ElideRight
                                }
                            }
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        TextField {
                            id: campoBusqueda
                            Layout.fillWidth: true
                            Layout.preferredHeight: baseUnit * 4
                            placeholderText: "Buscar trabajador..."
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
               
                // ===== TABLA MODERNA CON LÍNEAS VERTICALES =====
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
                                
                                // NOMBRE COLUMN
                                Item {
                                    Layout.preferredWidth: parent.width * colNombre
                                    Layout.fillHeight: true
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "NOMBRE COMPLETO"
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
                                        text: "TIPO TRABAJADOR"
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
                                        text: "ESPECIALIDAD"
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
                                
                                // MATRÍCULA COLUMN
                                Item {
                                    Layout.preferredWidth: parent.width * colMatricula
                                    Layout.fillHeight: true
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "MATRÍCULA"
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
                                id: trabajadoresListView
                                model: trabajadoresListModel
                                
                                delegate: Rectangle {
                                    width: ListView.view.width
                                    height: baseUnit * 5
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
                                                text: model.trabajadorId
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
                                        
                                        // NOMBRE COLUMN
                                        Item {
                                            Layout.preferredWidth: parent.width * colNombre
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                anchors.rightMargin: baseUnit
                                                text: model.nombreCompleto
                                                color: primaryColor
                                                font.bold: true
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
                                        
                                        // TIPO COLUMN
                                        Item {
                                            Layout.preferredWidth: parent.width * colTipo
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                anchors.rightMargin: baseUnit
                                                text: model.tipoTrabajador
                                                color: textColor
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
                                                text: model.especialidad
                                                color: textColorLight
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
                                        
                                        // MATRÍCULA COLUMN
                                        Item {
                                            Layout.preferredWidth: parent.width * colMatricula
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                anchors.rightMargin: baseUnit
                                                text: model.matricula || "Sin matrícula"
                                                color: model.matricula ? textColor : "#95a5a6"
                                                font.bold: false
                                                font.pixelSize: fontBaseSize * 0.8
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
                                                text: model.fechaRegistro
                                                color: textColor
                                                font.bold: false
                                                font.pixelSize: fontBaseSize * 0.85
                                                font.family: "Segoe UI, Arial, sans-serif"
                                            }
                                        }
                                    }
                                    
                                    // LÍNEAS VERTICALES CONTINUAS
                                    Repeater {
                                        model: 5 // Número de líneas verticales (todas menos la última columna)
                                        Rectangle {
                                            property real xPos: {
                                                var w = parent.width - baseUnit * 3
                                                switch(index) {
                                                    case 0: return baseUnit * 1.5 + w * colId
                                                    case 1: return baseUnit * 1.5 + w * (colId + colNombre)
                                                    case 2: return baseUnit * 1.5 + w * (colId + colNombre + colTipo)
                                                    case 3: return baseUnit * 1.5 + w * (colId + colNombre + colTipo + colEspecialidad)
                                                    case 4: return baseUnit * 1.5 + w * (colId + colNombre + colTipo + colEspecialidad + colMatricula)
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
                                            console.log("Seleccionado trabajador ID:", model.trabajadorId)
                                        }
                                    }
                                    
                                    // ===== BOTONES DE ACCIÓN MODERNOS =====
                                    RowLayout {
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: baseUnit * 0.8
                                        spacing: baseUnit * 0.5
                                        visible: selectedRowIndex === index
                                        z: 10
                                        
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
                                                isEditMode = true
                                                editingIndex = index
                                                var trabajador = trabajadoresListModel.get(index)
                                                console.log("Editando trabajador:", JSON.stringify(trabajador))
                                                showNewWorkerDialog = true
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
        radius: baseUnit * 2
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
                font.pixelSize: fontBaseSize * 1.6
                font.bold: true
                font.family: "Segoe UI, Arial, sans-serif"
                color: textColor
                horizontalAlignment: Text.AlignHCenter
            }
            
            // Datos del Trabajador
            GroupBox {
                Layout.fillWidth: true
                title: "Datos Personales"
                
                background: Rectangle {
                    color: lightGrayColor
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
                    color: lightGrayColor
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

    // ===== PASO 3b: REMOVIDOS POR COMPLETO LOS RECTÁNGULOS DEL DIÁLOGO DE CONFIGURACIÓN =====
    // Los siguientes elementos han sido completamente eliminados:
    // - configTiposBackground
    // - configTiposDialog
    // Y toda su lógica asociada

    // ===== INICIALIZACIÓN =====
    Component.onCompleted: {
        console.log("👥 Módulo Trabajadores iniciado")
        
        for (var i = 0; i < trabajadoresModel.length; i++) {
            trabajadoresListModel.append(trabajadoresModel[i])
        }
        
        console.log("✅ Trabajadores cargados:", trabajadoresModel.length)
        console.log("🔗 Señal irAConfigPersonal configurada para navegación")
    }
}