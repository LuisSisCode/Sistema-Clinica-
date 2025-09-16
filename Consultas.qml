import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

import QtQml 2.15

Item {
    id: consultasRoot
    objectName: "consultasRoot"

    property var consultaModel: appController ? appController.consulta_model_instance : null
    
    // ACCESO A PROPIEDADES ADAPTATIVAS DEL MAIN
    readonly property real baseUnit: parent.baseUnit || Math.max(8, Screen.height / 100)
    readonly property real fontBaseSize: parent.fontBaseSize || Math.max(12, Screen.height / 70)
    readonly property real scaleFactor: parent.scaleFactor || Math.min(width / 1400, height / 900)
    
    // PROPIEDADES DE TAMAÑO
    readonly property real iconSize: Math.max(baseUnit * 3, 24)
    readonly property real buttonIconSize: Math.max(baseUnit * 2, 18)

    // PROPIEDADES DE COLOR 
    readonly property color primaryColor: "#901fd2"
    readonly property color primaryColorHover: "#2980B9"
    readonly property color primaryColorPressed: "#21618C"
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
    readonly property color borderColor: "#E5E7EB"
    readonly property color accentColor: "#10B981"
    readonly property color lineColor: "#D1D5DB"
    // Distribución de columnas responsive
    readonly property real colId: 0.05
    readonly property real colPaciente: 0.16
    readonly property real colDetalle: 0.20
    readonly property real colEspecialidad: 0.22
    readonly property real colTipo: 0.09
    readonly property real colPrecio: 0.10
    readonly property real colFecha: 0.10
    // Propiedades para los diálogos de especialidades
    property bool showNewConsultationDialog: false
    property bool isEditMode: false
    property int editingIndex: -1
    property int selectedRowIndex: -1

    // PROPIEDADES PARA DIÁLOGO DE CONFIRMACIÓN DE ELIMINACIÓN
    property string consultaIdToDelete: ""
    property bool showConfirmDeleteDialog: false

    // PAGINACIÓN ADAPTATIVA
    property int itemsPerPageConsultas: 8 // Valor inicial, se ajustará dinámicamente
    property int currentPageConsultas: 0
    property int totalPagesConsultas: 0
    // MODELO DE PACIENTES PARA BÚSQUEDA
    property var pacienteModel: appController ? appController.paciente_model_instance : null
    
    // PROPIEDADES DE FILTRO
    property bool hayFiltrosActivos: {
        return (filtroFecha && filtroFecha.currentIndex > 0) ||
            (filtroEspecialidad && filtroEspecialidad.currentIndex > 0) ||
            (filtroTipo && filtroTipo.currentIndex > 0) ||
            (campoBusqueda && campoBusqueda.text.length > 0)
    }
    property var especialidadMap: []

    property var consultasOriginales: []

    ListModel {
        id: consultasPaginadasModel
    }

    ListModel {
        id: consultasListModel
    }

    // CONEXIONES CORREGIDAS
    Connections {
        target: consultaModel
        
        function onConsultasRecientesChanged() {
            console.log("📋 Signal: Consultas recientes cambiadas")
            updateTimer.start()
        }
        
        function onEspecialidadesChanged() {
            console.log("🏥 Signal: Especialidades cambiadas")
            updateEspecialidadesCombo()
        }
        
        function onEstadoCambiado(nuevoEstado) {
            console.log("⏳ Estado:", nuevoEstado)
        }
        
        // ✅ CORREGIDO: Signal name correcto
        function onOperacionError(mensaje) {
            console.log("⚠️ Error:", mensaje)
            showNotification("Error", mensaje)
        }
        
        function onOperacionExitosa(mensaje) {
            console.log("✅ Éxito:", mensaje)
            showNotification("Éxito", mensaje)
            
            if (mensaje.includes("creada") || mensaje.includes("actualizada")) {
                limpiarYCerrarDialogoConsulta()
            }
            updatePaginatedModel()
        }
    }

    Timer {
        id: updateTimer
        interval: 100
        onTriggered: updatePaginatedModel()
    }
    function formatearFechaSegura(fechaInput) {
        try {
            // ✅ SOLUCIÓN: Confiar en el formateo de Python
            if (typeof fechaInput === 'string') {
                // Si ya viene formateado desde Python, usar directamente
                if (fechaInput.includes('/')) {
                    return fechaInput;
                }
                if (fechaInput === "Sin fecha") {
                    return fechaInput;
                }
            }
            
            // Solo procesar si es absolutamente necesario
            if (fechaInput instanceof Date) {
                return fechaInput.toLocaleDateString("es-ES");
            }
            
            return "Sin fecha";
            
        } catch (error) {
            console.log("Error formateando fecha:", error);
            return "Sin fecha";
        }
    }

    function formatearFecha(fechaISO) {
        return formatearFechaSegura(fechaISO)
    }

    function showNotification(tipo, mensaje) {
        if (typeof appController !== 'undefined') {
            console.log("Exito para consulta")
            //appController.showNotification(tipo, mensaje)
        } else {
            console.log(`${tipo}: ${mensaje}`)
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
                
                // HEADER ADAPTATIVO CORREGIDO
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
                                    id: consultaIcon
                                    anchors.centerIn: parent
                                    width: Math.min(baseUnit * 8, parent.width * 10)
                                    height: Math.min(baseUnit * 8, parent.height * 10)
                                    source: "Resources/iconos/Consulta.png"
                                    fillMode: Image.PreserveAspectFit
                                    antialiasing: true
                                    
                                    onStatusChanged: {
                                        if (status === Image.Error) {
                                            console.log("Error cargando PNG:", source)
                                        } else if (status === Image.Ready) {
                                            console.log("PNG cargado correctamente:", source)
                                        }
                                    }
                                }
                            }
                            
                            Label {
                                Layout.alignment: Qt.AlignVCenter
                                text: "Registro de Consultas Médicas"
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
                        
                        // BOTÓN NUEVA CONSULTA
                        Button {
                            id: newConsultationBtn
                            objectName: "newConsultationButton"
                            Layout.preferredHeight: baseUnit * 5
                            Layout.preferredWidth: Math.max(baseUnit * 20, implicitWidth + baseUnit * 2)
                            Layout.alignment: Qt.AlignVCenter
                            
                            background: Rectangle {
                                color: newConsultationBtn.pressed ? Qt.darker(primaryColor, 1.1) : 
                                    newConsultationBtn.hovered ? Qt.lighter(primaryColor, 1.1) : primaryColor
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
                                            } else if (status === Image.Ready) {
                                                console.log("PNG del botón cargado correctamente:", source)
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
                                    text: "Nueva Consulta"
                                    color: whiteColor
                                    font.bold: true
                                    font.pixelSize: fontBaseSize
                                    font.family: "Segoe UI, Arial, sans-serif"
                                }
                            }
                            
                            onClicked: {
                                isEditMode = false
                                editingIndex = -1
                                showNewConsultationDialog = true
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
                                text: "Especialidad:"
                                font.bold: true
                                color: textColor
                                font.pixelSize: fontBaseSize * 0.9
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                            
                            ComboBox {
                                id: filtroEspecialidad
                                Layout.fillWidth: true
                                Layout.preferredHeight: baseUnit * 4
                                model: {
                                    var especialidades = ["Todas"]
                                    if (consultaModel && consultaModel.especialidades) {
                                        for (var i = 0; i < consultaModel.especialidades.length; i++) {
                                            var esp = consultaModel.especialidades[i]
                                            if (esp && esp.text) {
                                                // CORREGIDO: Solo nombre de especialidad, sin doctor
                                                especialidades.push(esp.text)
                                            }
                                        }
                                    }
                                    return especialidades
                                }
                                currentIndex: 0
                                onCurrentIndexChanged: aplicarFiltros()
                                
                                contentItem: Label {
                                    text: filtroEspecialidad.displayText
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
                
                // TABLA MODERNA CON LÍNEAS VERTICALES - ACTUALIZADA CON CÉDULA
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
                        
                        // HEADER CON LÍNEAS VERTICALES - ACTUALIZADO
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
                                
                                // DETALLE COLUMN
                                Item {
                                    Layout.preferredWidth: parent.width * colDetalle
                                    Layout.fillHeight: true
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "DETALLE"
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
                                        text: "ESPECIALIDAD - DOCTOR"
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
                                
                                // FECHA COLUMN (sin línea derecha)
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
                                id: consultasListView
                                model: consultasPaginadasModel
                                
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
                                        
                                        // ID COLUMN - CORREGIDO
                                        Item {
                                            Layout.preferredWidth: parent.width * colId
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                text: model.id || "N/A"  // CORREGIDO: usar model.id
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
                                        
                                        // PACIENTE COLUMN - CORREGIDO
                                        Item {
                                            Layout.preferredWidth: parent.width * colPaciente
                                            Layout.fillHeight: true
                                            Column {
                                                anchors.fill: parent
                                                anchors.margins: baseUnit * 0.5
                                                Label {
                                                    width: parent.width - baseUnit
                                                    text: model.paciente_completo || "Sin nombre"
                                                    color: textColor
                                                    font.pixelSize: fontBaseSize * 0.85
                                                    font.family: "Segoe UI, Arial, sans-serif"
                                                    elide: Text.ElideRight
                                                }
                                            
                                                Label {
                                                    width: parent.width - baseUnit
                                                    text: model.paciente_cedula ? "C.I: " + model.paciente_cedula : "Sin cédula"
                                                    color: textColorLight
                                                    font.pixelSize: fontBaseSize * 0.75
                                                    font.family: "Segoe UI, Arial, sans-serif"
                                                    elide: Text.ElideRight
                                                    visible: model.paciente_cedula !== ""
                                                }
                                            }
                                            
                                            Rectangle {
                                                anchors.right: parent.right
                                                width: 1
                                                height: parent.height
                                                color: lineColor
                                            }
                                        }
                                        
                                        // CÉDULA COLUMN - CORREGIDO
                                  
                                        
                                        // DETALLE COLUMN - CORREGIDO
                                        Item {
                                            Layout.preferredWidth: parent.width * colDetalle
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                anchors.rightMargin: baseUnit
                                                text: model.Detalles || "Sin detalles"  // CORREGIDO: Detalles con D mayúscula
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
                                        
                                        // ESPECIALIDAD COLUMN - CORREGIDO
                                        Item {
                                            Layout.preferredWidth: parent.width * colEspecialidad
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                anchors.rightMargin: baseUnit
                                                text: model.especialidad_doctor || "Sin especialidad/doctor"  // CORREGIDO
                                                color: primaryColor
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
                                        
                                        // TIPO COLUMN - CORREGIDO
                                        Item {
                                            Layout.preferredWidth: parent.width * colTipo
                                            Layout.fillHeight: true
                                            
                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: baseUnit * 7
                                                height: baseUnit * 2.5
                                                color: (model.tipo_consulta === "Emergencia") ? warningColorLight : successColorLight  // CORREGIDO
                                                radius: height / 2
                                                
                                                Label {
                                                    anchors.centerIn: parent
                                                    text: model.tipo_consulta || "Normal"  // CORREGIDO
                                                    color: (model.tipo_consulta === "Emergencia") ? "#92400E" : "#047857"
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
                                        
                                        // PRECIO COLUMN - CORREGIDO
                                        Item {
                                            Layout.preferredWidth: parent.width * colPrecio
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                text: "Bs " + (model.precio ? model.precio.toFixed(2) : "0.00")  // CORREGIDO
                                                color: (model.tipo_consulta === "Emergencia") ? "#92400E" : "#047857"
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
                                        
                                        // FECHA COLUMN - CORREGIDO
                                        Item {
                                            Layout.preferredWidth: parent.width * colFecha
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                text: model.fecha || "Sin fecha"  // CORREGIDO
                                                color: textColor
                                                font.bold: false
                                                font.pixelSize: fontBaseSize * 0.85
                                                font.family: "Segoe UI, Arial, sans-serif"
                                            }
                                        }
                                    }
                                    
                                    // LÍNEAS VERTICALES CONTINUAS
                                    Repeater {
                                        model: 6  // 6 líneas para 7 columnas
                                        Rectangle {
                                            property real xPos: {
                                                var totalWidth = parent.width - (baseUnit * 3) // Ajustar por márgenes
                                                var cumulativeWidth = 0
                                                
                                                switch(index) {
                                                    case 0: cumulativeWidth = colId; break
                                                    case 1: cumulativeWidth = colId + colPaciente; break
                                                    case 2: cumulativeWidth = colId + colPaciente + colDetalle; break
                                                    case 3: cumulativeWidth = colId + colPaciente + colDetalle + colEspecialidad; break
                                                    case 4: cumulativeWidth = colId + colPaciente + colDetalle + colEspecialidad + colTipo; break
                                                    case 5: cumulativeWidth = colId + colPaciente + colDetalle + colEspecialidad + colTipo + colPrecio; break
                                                }
                                                
                                                return baseUnit * 1.5 + (totalWidth * cumulativeWidth)
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
                                            console.log("Seleccionada consulta ID:", model.id)
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
                                                consultationFormDialog.consultaParaEditar = {
                                                    consultaId: model.id,
                                                    paciente: model.paciente_completo,
                                                    pacienteCedula: model.paciente_cedula,
                                                    especialidadDoctor: model.especialidad_doctor,
                                                    tipo: model.tipo_consulta,
                                                    precio: model.precio,
                                                    detalles: model.Detalles,
                                                    fecha: model.fecha
                                                }
                                                
                                                isEditMode = true
                                                editingIndex = -1
                                                showNewConsultationDialog = true
                                                
                                                console.log("Editando consulta ID:", model.id)
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
                                                var consultaId = model.id
                                                if (consultaId && consultaId !== "N/A") {
                                                    consultaIdToDelete = consultaId
                                                    showConfirmDeleteDialog = true
                                                }
                                            }
                                            
                                            onHoveredChanged: {
                                                deleteIcon.opacity = hovered ? 0.7 : 1.0
                                            }
                                        }
                                    }
                                }
                            }
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
                            enabled: currentPageConsultas > 0
                            
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
                                if (currentPageConsultas > 0) {
                                    currentPageConsultas--
                                    updatePaginatedModel()
                                }
                            }
                        }
                        
                        Label {
                            text: "Página " + (currentPageConsultas + 1) + " de " + Math.max(1, totalPagesConsultas)
                            color: textColor
                            font.pixelSize: fontBaseSize * 0.9
                            font.family: "Segoe UI, Arial, sans-serif"
                            font.weight: Font.Medium
                        }
                        
                        Button {
                            Layout.preferredWidth: baseUnit * 11
                            Layout.preferredHeight: baseUnit * 4
                            text: "Siguiente →"
                            enabled: currentPageConsultas < totalPagesConsultas - 1
                            
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

    // DIÁLOGO MODAL DE NUEVA/EDITAR CONSULTA (IGUAL QUE ENFERMERÍA)
    Dialog {
        id: consultationFormDialog
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.95, 700)
        height: Math.min(parent.height * 0.95, 800)
        modal: true
        closePolicy: Popup.NoAutoClose
        visible: showNewConsultationDialog
        
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
        
        property var consultaParaEditar: null
        property int selectedEspecialidadIndex: -1
        property string consultationType: "Normal"
        property real calculatedPrice: 0.0
        
        function updatePrices() {
            if (consultationFormDialog.selectedEspecialidadIndex >= 0 && consultaModel && consultaModel.especialidades) {
                var especialidad = consultaModel.especialidades[consultationFormDialog.selectedEspecialidadIndex]
                if (consultationFormDialog.consultationType === "Normal") {
                    consultationFormDialog.calculatedPrice = especialidad.precio_normal
                } else {
                    consultationFormDialog.calculatedPrice = especialidad.precio_emergencia
                }
            } else {
                consultationFormDialog.calculatedPrice = 0.0
            }
        }
            
        function loadEditData() {
            if (!isEditMode || !consultationFormDialog.consultaParaEditar) {
                console.log("No hay datos para cargar en edición")
                return
            }
            
            var consulta = consultationFormDialog.consultaParaEditar
            console.log("Cargando datos para edición:", JSON.stringify(consulta))
            
            // Cargar datos del paciente
            cedulaPaciente.text = consulta.pacienteCedula || ""
            nombrePaciente.text = consulta.paciente || ""
            
            if (cedulaPaciente.text.length >= 5) {
                buscarPacientePorCedula(cedulaPaciente.text)
            }
            
            // ✅ CORREGIR: Buscar especialidad por coincidencia flexible
            if (consultaModel && consultaModel.especialidades && consulta.especialidadDoctor) {
                var especialidadBuscada = consulta.especialidadDoctor.trim()
                console.log("🔍 Buscando especialidad:", especialidadBuscada)
                
                var encontrada = false
                for (var i = 0; i < consultaModel.especialidades.length; i++) {
                    var esp = consultaModel.especialidades[i]
                    
                    // ✅ MÉTODO 1: Comparación exacta con formato ComboBox
                    var espTextoCombo = esp.text + " - " + esp.doctor_nombre
                    
                    // ✅ MÉTODO 2: Comparación solo por especialidad si no coincide exacto
                    var soloEspecialidad = especialidadBuscada.split(" - ")[0]
                    
                    console.log(`Comparando [${i}]: "${espTextoCombo}" vs "${especialidadBuscada}"`)
                    
                    if (espTextoCombo === especialidadBuscada || 
                        esp.text === soloEspecialidad ||
                        especialidadBuscada.includes(esp.text)) {
                        
                        especialidadCombo.currentIndex = i + 1
                        consultationFormDialog.selectedEspecialidadIndex = i
                        encontrada = true
                        
                        console.log("✅ Especialidad encontrada en índice:", i + 1)
                        break
                    }
                }
                
                if (!encontrada) {
                    console.log("⚠️ Especialidad no encontrada:", especialidadBuscada)
                    console.log("📋 Especialidades disponibles:", consultaModel.especialidades.map(function(e) { 
                        return e.text + " - " + e.doctor_nombre 
                    }))
                }
            }
            
            // Configurar tipo de consulta
            if (consulta.tipo === "Normal") {
                normalRadio.checked = true
                consultationFormDialog.consultationType = "Normal"
            } else {
                emergenciaRadio.checked = true
                consultationFormDialog.consultationType = "Emergencia"
            }
            
            // Cargar demás campos
            consultationFormDialog.calculatedPrice = consulta.precio || 0
            detallesConsulta.text = consulta.detalles || ""
            
            // ✅ FORZAR ACTUALIZACIÓN DE PRECIOS
            consultationFormDialog.updatePrices()
            
            console.log("Datos de edición cargados correctamente")
        }
        
        onVisibleChanged: {
            if (visible) {
                if (isEditMode && consultationFormDialog.consultaParaEditar) {
                    loadEditData()
                } else if (!isEditMode) {
                    limpiarDatosPaciente()
                    especialidadCombo.currentIndex = 0
                    normalRadio.checked = true
                    emergenciaRadio.checked = false
                    detallesConsulta.text = ""
                    consultationFormDialog.selectedEspecialidadIndex = -1
                    consultationFormDialog.calculatedPrice = 0.0
                    consultationFormDialog.consultaParaEditar = null
                    cedulaPaciente.forceActiveFocus()
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
                text: isEditMode ? "EDITAR CONSULTA" : "NUEVA CONSULTA"
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
                    limpiarYCerrarDialogoConsulta()
                }
            }
        }
        
        ScrollView {
            id: scrollView
            anchors.top: dialogHeader.bottom
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
                            interval: 800
                            running: false
                            repeat: false
                            onTriggered: {
                                var cedula = cedulaPaciente.text.trim()
                                if (cedula.length >= 5) {
                                    buscarPacientePorCedula(cedula)
                                }
                            }
                        }
                        
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: baseUnit * 2
                            rowSpacing: baseUnit * 1.5
                            
                            Label {
                                text: "Nombre:"
                                font.bold: true
                                color: textColor
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                            
                            TextField {
                                id: nombrePaciente
                                Layout.fillWidth: true
                                placeholderText: cedulaPaciente.pacienteAutocompletado ? 
                                            "Nombre del paciente" : "Ingrese nombre del nuevo paciente"
                                readOnly: cedulaPaciente.pacienteAutocompletado
                                font.pixelSize: fontBaseSize
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
                                onTextChanged: {
                                    if (esCampoNuevoPaciente && text.length > 0) {
                                        color = text.length >= 2 ? textColor : "#E74C3C"
                                    }
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
                                placeholderText: cedulaPaciente.pacienteAutocompletado ? 
                                                "Apellido paterno" : "Ingrese apellido paterno"
                                readOnly: cedulaPaciente.pacienteAutocompletado
                                font.pixelSize: fontBaseSize
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
                                placeholderText: cedulaPaciente.pacienteAutocompletado ? 
                                                "Apellido materno" : "Ingrese apellido materno (opcional)"
                                readOnly: cedulaPaciente.pacienteAutocompletado
                                font.pixelSize: fontBaseSize
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
                                padding: baseUnit
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
                
                GroupBox {
                    Layout.fillWidth: true
                    title: "INFORMACIÓN DE LA CONSULTA"
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
                                text: "Especialidad:"
                                font.bold: true
                                Layout.preferredWidth: baseUnit * 15
                                color: textColor
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                            
                            ComboBox {
                                id: especialidadCombo
                                Layout.fillWidth: true
                                font.pixelSize: fontBaseSize
                                font.family: "Segoe UI, Arial, sans-serif"
                                model: {
                                    var list = ["Seleccionar especialidad..."]
                                    if (consultaModel && consultaModel.especialidades) {
                                        for (var i = 0; i < consultaModel.especialidades.length; i++) {
                                            var esp = consultaModel.especialidades[i]
                                            list.push(esp.text + " - " + esp.doctor_nombre)
                                        }
                                    }
                                    return list
                                }
                                onCurrentIndexChanged: {
                                    if (currentIndex > 0 && consultaModel && consultaModel.especialidades) {
                                        consultationFormDialog.selectedEspecialidadIndex = currentIndex - 1
                                        consultationFormDialog.updatePrices()
                                    } else {
                                        consultationFormDialog.selectedEspecialidadIndex = -1
                                        consultationFormDialog.calculatedPrice = 0.0
                                    }
                                }
                                
                                contentItem: Label {
                                    text: especialidadCombo.displayText
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
                                text: "Tipo:"
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
                                            consultationFormDialog.consultationType = "Normal"
                                            consultationFormDialog.updatePrices()
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
                                            consultationFormDialog.consultationType = "Emergencia"
                                            consultationFormDialog.updatePrices()
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
                            text: "Precio Consulta:"
                            font.bold: true
                            color: textColor
                            font.family: "Segoe UI, Arial, sans-serif"
                        }
                        
                        Label {
                            text: consultationFormDialog.selectedEspecialidadIndex >= 0 ? 
                                "Bs " + consultationFormDialog.calculatedPrice.toFixed(2) : "Seleccione especialidad"
                            font.bold: true
                            font.pixelSize: fontBaseSize * 1.1
                            font.family: "Segoe UI, Arial, sans-serif"
                            color: consultationFormDialog.consultationType === "Emergencia" ? warningColor : successColor
                            padding: baseUnit
                            background: Rectangle {
                                color: consultationFormDialog.consultationType === "Emergencia" ? warningColorLight : successColorLight
                                radius: baseUnit * 0.8
                            }
                        }
                    }
                }
                
                GroupBox {
                    Layout.fillWidth: true
                    title: "DETALLES DE LA CONSULTA"
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
                        id: detallesConsulta
                        Layout.fillWidth: true
                        Layout.preferredHeight: baseUnit * 12
                        placeholderText: "Descripción de la consulta, síntomas, observaciones..."
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
                    limpiarYCerrarDialogoConsulta()
                }
            }
            
            Button {
                text: isEditMode ? "Actualizar" : "Guardar"
                enabled: {
                    var especialidadSeleccionada = consultationFormDialog.selectedEspecialidadIndex >= 0
                    var cedulaValida = cedulaPaciente.text.length >= 5
                    var nombreValido = nombrePaciente.text.length >= 2
                    var detallesValidos = detallesConsulta.text.length >= 10
                    
                    if (cedulaPaciente.pacienteNoEncontrado) {
                        var apellidoValido = apellidoPaterno.text.length >= 2
                        return especialidadSeleccionada && cedulaValida && nombreValido && apellidoValido && detallesValidos
                    } else {
                        return especialidadSeleccionada && cedulaValida && nombreValido && detallesValidos
                    }
                }
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
                    guardarConsulta()
                }
            }
        }
    }

    // DIÁLOGO DE CONFIRMACIÓN DE ELIMINACIÓN
    Dialog {
        id: confirmDeleteDialog
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.9, 480)
        height: Math.min(parent.height * 0.55, 320)
        modal: true
        closePolicy: Popup.NoAutoClose
        visible: showConfirmDeleteDialog
        z: 102
        
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
            
            // Header personalizado con ícono
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
            
            // Contenido principal
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
                        text: "¿Estás seguro de eliminar esta consulta?"
                        font.pixelSize: fontBaseSize * 1.1
                        font.bold: true
                        color: textColor
                        Layout.alignment: Qt.AlignHCenter
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        font.family: "Segoe UI, Arial, sans-serif"
                    }
                    
                    Label {
                        text: "Esta acción no se puede deshacer y el registro de la consulta se eliminará permanentemente."
                        font.pixelSize: fontBaseSize
                        color: "#6b7280"
                        Layout.alignment: Qt.AlignHCenter
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        Layout.maximumWidth: parent.width - baseUnit * 4
                        font.family: "Segoe UI, Arial, sans-serif"
                    }
                    
                    Item { Layout.fillHeight: true }
                    
                    // Botones
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
                                consultaIdToDelete = ""
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
                                console.log("🗑️ Confirmando eliminación de consulta...")
                                
                                var consultaId = parseInt(consultaIdToDelete)
                                if (consultaModel.eliminar_consulta(consultaId)) {
                                    selectedRowIndex = -1
                                    updatePaginatedModel()
                                    console.log("✅ Consulta eliminada de BD ID:", consultaId)
                                    showNotification("Éxito", "Consulta eliminada correctamente")
                                } else {
                                    console.log("❌ Error eliminando consulta ID:", consultaId)
                                    showNotification("Error", "No se pudo eliminar la consulta")
                                }
                                
                                showConfirmDeleteDialog = false
                                consultaIdToDelete = ""
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

    function getTotalConsultasCount() {
        return consultasOriginales.length
    }
    
    Component.onCompleted: {
        console.log("🩺 Módulo Consultas iniciado")
        console.log("🔧 Sistema de edición de consultas inicializado")
        
        function conectarModelos() {
            if (typeof appController !== 'undefined') {
                consultaModel = appController.consulta_model_instance
                pacienteModel = appController.paciente_model_instance
                
                if (consultaModel) {
                    consultaModel.consultasRecientesChanged.connect(function() {
                        console.log("🔄 Consultas actualizadas - forzando refresh")
                        updatePaginatedModel()
                    })
                    
                    consultaModel.refresh_consultas()
                    consultaModel.refresh_especialidades()
                    return true
                }
            }
            return false
        }
        
        var attempts = 0
        var timer = Qt.createQmlObject("import QtQuick 2.15; Timer { interval: 300; repeat: true }", consultasRoot)
        
        timer.triggered.connect(function() {
            if (conectarModelos() || ++attempts >= 3) {
                timer.destroy()
            }
        })
        timer.start()
    }

    function obtenerEspecialidades() {
        var especialidades = ["Todas"]
        
        if (consultaModel && consultaModel.especialidades) {
            for (var i = 0; i < consultaModel.especialidades.length; i++) {
                var esp = consultaModel.especialidades[i]
                if (esp.text) {
                    especialidades.push(esp.text)
                }
            }
        }
        
        return especialidades
    }
    Timer {
        id: initialLoadTimer
        interval: 100
        running: true
        onTriggered: {
            aplicarFiltros()
        }
    }
    function construirFiltrosActuales() {
        var filtros = {}
        
        // Filtro por tipo de consulta
        if (filtroTipo && filtroTipo.currentIndex > 0) {
            if (filtroTipo.currentIndex === 1) {
                filtros.tipo_consulta = "Normal"
            } else if (filtroTipo.currentIndex === 2) {
                filtros.tipo_consulta = "Emergencia"
            }
        }
        
        // Filtro por especialidad
        if (filtroEspecialidad && filtroEspecialidad.currentIndex > 0) {
            var selectedIndexInMap = filtroEspecialidad.currentIndex - 1
            
            if (selectedIndexInMap >= 0 && selectedIndexInMap < especialidadMap.length) {
                var selectedEspecialidad = especialidadMap[selectedIndexInMap]
                filtros.especialidad = selectedEspecialidad.nombre
                console.log("✅ Filtro especialidad aplicado:", selectedEspecialidad.nombre, "ID:", selectedEspecialidad.id)
            }
        }
        
        // Filtro por búsqueda
        if (campoBusqueda && campoBusqueda.text.length >= 2) {
            filtros.busqueda = campoBusqueda.text.trim()
        }
        
        // ✅ FILTROS DE FECHA CORREGIDOS
        if (filtroFecha && filtroFecha.currentIndex > 0) {
            var hoy = new Date();
            var fechaDesde, fechaHasta;
            
            switch(filtroFecha.currentIndex) {
                case 1: // "Hoy"
                    fechaDesde = new Date(hoy.getFullYear(), hoy.getMonth(), hoy.getDate());
                    fechaHasta = new Date(hoy.getFullYear(), hoy.getMonth(), hoy.getDate(), 23, 59, 59);
                    break;
                case 2: // "Esta Semana"
                    var diaSemana = hoy.getDay();
                    var diffLunes = hoy.getDate() - diaSemana + (diaSemana === 0 ? -6 : 1);
                    fechaDesde = new Date(hoy);
                    fechaDesde.setDate(diffLunes);
                    fechaDesde.setHours(0, 0, 0, 0);
                    
                    fechaHasta = new Date(fechaDesde);
                    fechaHasta.setDate(fechaDesde.getDate() + 6);
                    fechaHasta.setHours(23, 59, 59, 999);
                    break;
                case 3: // "Este Mes"
                    fechaDesde = new Date(hoy.getFullYear(), hoy.getMonth(), 1);
                    fechaHasta = new Date(hoy.getFullYear(), hoy.getMonth() + 1, 0);
                    fechaHasta.setHours(23, 59, 59, 999);
                    break;
                default:
                    return filtros;
            }
            
            filtros.fecha_desde = fechaDesde.toISOString();
            filtros.fecha_hasta = fechaHasta.toISOString();
        }
        
        return filtros;
    }

    // FUNCIÓN PRINCIPAL CORREGIDA - MAPEO DIRECTO DE DATOS
    function updatePaginatedModel() {
        if (!consultaModel) return;
        
        var filtros = construirFiltrosActuales();
        
        // Limpiar cache antes de consultar
        if (consultaModel.limpiar_cache_consultas) {
            consultaModel.limpiar_cache_consultas();
        }
        
        var resultado = consultaModel.obtener_consultas_paginadas(
            currentPageConsultas, 6, filtros
        );
        
        consultasPaginadasModel.clear();
        
        if (resultado && resultado.consultas) {
            for (var i = 0; i < resultado.consultas.length; i++) {
                var consulta = resultado.consultas[i];
                
                consultasPaginadasModel.append({
                    id: consulta.id || "N/A",
                    paciente_completo: consulta.paciente_completo || "Sin nombre",
                    paciente_cedula: consulta.paciente_cedula || "Sin cédula", 
                    Detalles: consulta.Detalles || "Sin detalles",
                    especialidad_doctor: consulta.especialidad_doctor || "Sin especialidad/doctor",
                    tipo_consulta: consulta.tipo_consulta || "Normal",
                    precio: consulta.precio || 0,
                    // ✅ USAR FECHA TAL COMO VIENE DE PYTHON
                    fecha: consulta.fecha || "Sin fecha"
                });
            }
            
            totalPagesConsultas = resultado.total_pages || 1;
        }
    }
    // Guardar una nueva consulta
    function guardarConsulta() {
        try {
            console.log("🩺 Iniciando guardado consulta - Modo:", isEditMode ? "EDITAR" : "CREAR")
            
            if (isEditMode && consultationFormDialog.consultaParaEditar) {
                actualizarConsulta()
            } else {
                crearNuevaConsulta()
            }
            
        } catch (error) {
            console.log("❌ Error en coordinador de guardado:", error.message)
            consultationFormDialog.enabled = true
            showNotification("Error", "Error procesando solicitud: " + error.message)
        }
    }
    function crearNuevaConsulta() {
        /**
        * RESPONSABILIDAD ÚNICA: Crear una nueva consulta médica
        */
        try {
            console.log("🩺 === INICIANDO CREACIÓN DE NUEVA CONSULTA ===")
            
            // Validar formulario
            if (!validarFormularioConsulta()) {
                return
            }
            
            // Mostrar loading
            consultationFormDialog.enabled = false
            
            // 1. Gestionar paciente (buscar o crear)
            var pacienteId = buscarOCrearPacientePorCedula()
            if (pacienteId <= 0) {
                throw new Error("Error gestionando datos del paciente")
            }
            
            // 2. Obtener datos del formulario
            var datosConsulta = obtenerDatosFormularioConsulta()
            
            // 3. Crear consulta en el backend
            console.log("🩺 Creando consulta con parámetros:")
            console.log("   - Paciente ID:", pacienteId)
            console.log("   - Especialidad ID:", datosConsulta.especialidadId)
            console.log("   - Tipo consulta:", datosConsulta.tipoConsulta)
            console.log("   - Detalles:", datosConsulta.detalles)
            
            var consultaData = {
                "paciente_id": pacienteId,
                "especialidad_id": datosConsulta.especialidadId,
                "detalles": datosConsulta.detalles,
                "tipo_consulta": datosConsulta.tipoConsulta
            }
            
            var resultado = consultaModel.crear_consulta(consultaData)
            
            // 4. Procesar resultado
            procesarResultadoCreacionConsulta(resultado)
            
        } catch (error) {
            console.log("❌ Error creando consulta:", error.message)
            consultationFormDialog.enabled = true
            showNotification("Error", error.message)
        }
    }

    function actualizarConsulta() {
        /**
        * RESPONSABILIDAD ÚNICA: Actualizar una consulta existente
        */
        try {
            console.log("📝 === INICIANDO ACTUALIZACIÓN DE CONSULTA ===")
            
            // Validar formulario
            if (!validarFormularioConsulta()) {
                return
            }
            
            // Validar que estamos en modo edición
            if (!isEditMode || !consultationFormDialog.consultaParaEditar) {
                throw new Error("No hay consulta seleccionada para editar")
            }
            
            // Mostrar loading
            consultationFormDialog.enabled = false
            
            // 1. Obtener consulta existente
            var consultaId = consultationFormDialog.consultaParaEditar.consultaId
            if (!consultaId || consultaId <= 0) {
                throw new Error("ID de consulta inválido: " + consultaId)
            }
            
            // 2. Obtener datos del formulario
            var datosConsulta = obtenerDatosFormularioConsulta()
            
            console.log("📝 Actualizando consulta ID:", consultaId)
            console.log("   - Tipo consulta:", datosConsulta.tipoConsulta)
            console.log("   - Detalles:", datosConsulta.detalles)
            
            // 3. Actualizar en el backend
            var datosActualizados = {
                "detalles": datosConsulta.detalles,
                "tipo_consulta": datosConsulta.tipoConsulta
            }
            
            var resultado = consultaModel.actualizar_consulta(parseInt(consultaId), datosActualizados)
            
            // 4. Procesar resultado
            procesarResultadoActualizacionConsulta(resultado)
            
        } catch (error) {
            console.log("❌ Error actualizando consulta:", error.message)
            consultationFormDialog.enabled = true
            showNotification("Error", error.message)
        }
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

    function limpiarDatosPaciente() {
        cedulaPaciente.text = ""
        nombrePaciente.text = ""
        apellidoPaterno.text = ""
        apellidoMaterno.text = ""
        
        cedulaPaciente.pacienteAutocompletado = false
        apellidoPaterno.pacienteAutocompletado = false
        apellidoMaterno.pacienteAutocompletado = false
        console.log("🧹 Datos del paciente limpiados")
    }

    function buscarOCrearPacientePorCedula() {
        if (!consultaModel) {
            throw new Error("ConsultaModel no disponible")
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
        
        var pacienteId = consultaModel.buscar_o_crear_paciente_inteligente(
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
        if (!consultaModel || cedula.length < 5) return
        
        console.log("🔍 Buscando paciente con cédula:", cedula)
        
        // Limpiar estado anterior
        cedulaPaciente.pacienteNoEncontrado = false
        
        var pacienteData = consultaModel.buscar_paciente_por_cedula(cedula.trim())
        
        if (pacienteData && pacienteData.id) {
            autocompletarDatosPaciente(pacienteData)
        } else {
            console.log("❌ No se encontró paciente con cédula:", cedula)
            marcarPacienteNoEncontrado(cedula)
        }
    }

    function limpiarYCerrarDialogoConsulta() {
        showNewConsultationDialog = false
        limpiarDatosPaciente()
        detallesConsulta.text = ""
        especialidadCombo.currentIndex = 0
        normalRadio.checked = true
        selectedRowIndex = -1
        isEditMode = false
        editingIndex = -1
        consultationFormDialog.consultaParaEditar = null
        console.log("🧹 Formulario de consulta limpiado y diálogo cerrado")
    }

    function aplicarFiltros() {
        console.log("🔍 Aplicando filtros...")
        
        // Resetear a primera página
        currentPageConsultas = 0
        
        // Usar la función actualizada
        updatePaginatedModel()
    }
    function updateEspecialidadesCombo() {
        if (filtroEspecialidad && consultaModel) {
            // ✅ USAR DIRECTAMENTE LAS ESPECIALIDADES DISPONIBLES:
            if (consultaModel.especialidades) {
                var especialidades = ["Todas"]
                especialidadMap = []
                
                for (var i = 0; i < consultaModel.especialidades.length; i++) {
                    var esp = consultaModel.especialidades[i]
                    if (esp && esp.text) {
                        var nombreEspecialidad = esp.text
                        especialidades.push(nombreEspecialidad)
                        especialidadMap.push({
                            id: esp.id,
                            nombre: nombreEspecialidad,
                            data: esp
                        })
                    }
                }
                
                // Actualizar modelo solo si cambió
                var shouldUpdate = !filtroEspecialidad.model || 
                                filtroEspecialidad.model.length !== especialidades.length
                
                if (shouldUpdate) {
                    filtroEspecialidad.model = especialidades
                    console.log("🔁 Combo especialidad actualizado. Elementos:", especialidades.length)
                }
            }
        }
    }
    function limpiarFiltros() {
        console.log("🧹 Limpiando todos los filtros...")
        
        // Resetear ComboBox de fecha
        if (filtroFecha) {
            filtroFecha.currentIndex = 0  // "Todas"
        }
        
        // Resetear ComboBox de especialidad
        if (filtroEspecialidad) {
            filtroEspecialidad.currentIndex = 0  // "Todas"
        }
        
        // Resetear ComboBox de tipo
        if (filtroTipo) {
            filtroTipo.currentIndex = 0  // "Todos"
        }
        
        // Limpiar campo de búsqueda
        if (campoBusqueda) {
            campoBusqueda.text = ""
        }
        
        // Resetear a primera página
        currentPageConsultas = 0
        
        // Aplicar filtros (que ahora estarán vacíos/por defecto)
        aplicarFiltros()
        
        console.log("✅ Filtros limpiados - mostrando todas las consultas")
        
        // Mostrar notificación opcional
        showNotification("Info", "Filtros restablecidos")
    }
    function debugFiltros(filtros) {
        console.log("🔍 DEBUG Filtros Consultas:")
        console.log("   - tipo_consulta:", "'" + (filtros.tipo_consulta || "VACÍO") + "'")
        console.log("   - especialidad:", "'" + (filtros.especialidad || "VACÍO") + "'")
        console.log("   - busqueda:", "'" + (filtros.busqueda || "VACÍO") + "'")
    }
    // Nuevas Funciones
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
    function marcarPacienteNoEncontrado(cedula) {
        cedulaPaciente.pacienteNoEncontrado = true
        cedulaPaciente.pacienteAutocompletado = false
        
        // Limpiar campos pero mantener la cédula
        nombrePaciente.text = ""
        apellidoPaterno.text = ""
        apellidoMaterno.text = ""
        
        console.log("⚠️ Paciente no encontrado. Habilitando modo crear nuevo paciente.")
    }
    function validarFormularioConsulta() {
        console.log("✅ Validando formulario de consulta...")
        
        // ✅ DECLARAR VARIABLES ANTES DE USARLAS
        var tieneEspecialidad = consultationFormDialog.selectedEspecialidadIndex >= 0
        var tieneCedula = cedulaPaciente.text.length >= 5
        var tieneNombre = nombrePaciente.text.length >= 2
        var tieneDetalles = detallesConsulta.text.length >= 10
        
        if (!tieneEspecialidad) {
            showNotification("Error", "Debe seleccionar una especialidad")
            return false
        }
        
        if (!tieneCedula) {
            showNotification("Error", "Debe ingresar una cédula válida (mínimo 5 dígitos)")
            return false
        }
        
        if (!tieneNombre) {
            showNotification("Error", "Nombre del paciente es obligatorio")
            return false
        }
        
        if (!tieneDetalles) {
            showNotification("Error", "Los detalles de la consulta son obligatorios (mínimo 10 caracteres)")
            return false
        }
        
        // Validación adicional para pacientes nuevos
        if (cedulaPaciente.pacienteNoEncontrado) {
            if (!apellidoPaterno.text || apellidoPaterno.text.length < 2) {
                showNotification("Error", "Apellido paterno es obligatorio para pacientes nuevos")
                return false
            }
        }
        
        console.log("✅ Formulario de consulta válido")
        return true
    }

    function obtenerDatosFormularioConsulta() {
        try {
            // Validar especialidades
            if (!consultaModel || !consultaModel.especialidades) {
                throw new Error("No hay especialidades disponibles")
            }

            // CORREGIDO: Cambiar consultationForm por consultationFormDialog
            if (consultationFormDialog.selectedEspecialidadIndex >= consultaModel.especialidades.length) {
                throw new Error("Índice de especialidad fuera de rango")
            }

            var especialidadSeleccionada = consultaModel.especialidades[consultationFormDialog.selectedEspecialidadIndex]
            var especialidadId = especialidadSeleccionada.id
            
            if (!especialidadId || especialidadId <= 0) {
                throw new Error("ID de especialidad inválido")
            }
            
            // Obtener tipo de consulta
            var tipoConsulta = consultationFormDialog.consultationType.toLowerCase()
            
            return {
                especialidadId: especialidadId,
                tipoConsulta: tipoConsulta,
                detalles: detallesConsulta.text.trim()
            }
            
        } catch (error) {
            console.log("❌ Error obteniendo datos del formulario de consulta:", error.message)
            throw error
        }
    }

    function procesarResultadoCreacionConsulta(resultado) {
        try {
            console.log("🔄 Procesando resultado de creación consulta:", resultado)
            
            // Verificar si fue exitoso
            var resultadoObj = typeof resultado === 'string' ? JSON.parse(resultado) : resultado
            if (resultadoObj && resultadoObj.exito === false) {
                throw new Error(resultadoObj.error || "Error desconocido en la creación")
            }
            
            console.log("✅ Consulta creada exitosamente")
            
            // Actualizar interfaz
            if (consultaModel && typeof consultaModel.refrescarDatos === 'function') {
                consultaModel.refrescarDatos()
            }
            
            // Actualizar lista de consultas
            updatePaginatedModel()
            
            // Limpiar y cerrar formulario
            Qt.callLater(function() {
                if (showNewConsultationDialog) {
                    limpiarYCerrarDialogoConsulta()
                }
            })
            
            consultationFormDialog.enabled = true
            
        } catch (error) {
            console.log("❌ Error procesando resultado de creación consulta:", error.message)
            consultationFormDialog.enabled = true
            throw error
        }
    }

    function procesarResultadoActualizacionConsulta(resultado) {
        try {
            console.log("🔄 Procesando resultado de actualización consulta:", resultado)
            
            // Verificar si fue exitoso
            var resultadoObj = typeof resultado === 'string' ? JSON.parse(resultado) : resultado
            if (resultadoObj && resultadoObj.exito === false) {
                throw new Error(resultadoObj.error || "Error desconocido en la actualización")
            }
            
            console.log("✅ Consulta actualizada exitosamente")
            
            // Actualizar interfaz
            if (consultaModel && typeof consultaModel.refrescarDatos === 'function') {
                consultaModel.refrescarDatos()
            }
            
            // Actualizar lista de consultas
            updatePaginatedModel()
            
            // Limpiar y cerrar formulario
            Qt.callLater(function() {
                if (showNewConsultationDialog) {
                    limpiarYCerrarDialogoConsulta()
                }
            })
            
            consultationFormDialog.enabled = true
            
        } catch (error) {
            console.log("❌ Error procesando resultado de actualización consulta:", error.message)
            consultationFormDialog.enabled = true
            throw error
        }
    }
}