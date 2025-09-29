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
    
    // PROPIEDADES DE TAMAÑO Y COLOR
    readonly property real iconSize: Math.max(baseUnit * 3, 24)
    readonly property real buttonIconSize: Math.max(baseUnit * 2, 18)
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
    readonly property real colCodigo: 0.06        
    readonly property real colPaciente: 0.18      
    readonly property real colEspecialidad: 0.22   
    readonly property real colDetalles: 0.20       
    readonly property real colTipo: 0.08          
    readonly property real colPrecio: 0.09        
    readonly property real colFecha: 0.09         
    readonly property real colAcciones: 0.08

    // Propiedades para los diálogos
    property bool showNewConsultationDialog: false
    property bool isEditMode: false
    property int editingIndex: -1
    property int selectedRowIndex: -1
    property string consultaIdToDelete: ""
    property bool showConfirmDeleteDialog: false
    property int itemsPerPageConsultas: 8
    property int currentPageConsultas: 0
    property int totalPagesConsultas: 0
    property var pacienteModel: appController ? appController.paciente_model_instance : null
    // AGREGAR después de: property var pacienteModel: appController ? appController.paciente_model_instance : null
    property bool hayFiltrosActivos: {
        return (filtroFecha && filtroFecha.currentIndex > 0) ||
            (filtroEspecialidad && filtroEspecialidad.currentIndex > 0) ||
            (filtroTipo && filtroTipo.currentIndex > 0) ||
            (campoBusqueda && campoBusqueda.text.length > 0)
    }
    property var especialidadMap: []

    readonly property string usuarioActualRol: {
        if (typeof authModel !== 'undefined' && authModel) {
            return authModel.userRole || ""
        }
        return ""
    }
    readonly property bool esAdministrador: usuarioActualRol === "Administrador"
    readonly property bool esMedico: usuarioActualRol === "Médico" || usuarioActualRol === "MÃ©dico"
    readonly property bool puedeCrearConsultas: esAdministrador || esMedico

    // Propiedades para búsqueda unificada de pacientes
    property bool mostrarResultadosBusqueda: false
    property bool pacienteSeleccionado: false
    property var pacienteActual: null
    property string tipoDetectado: ""

    // Agregar estas propiedades al inicio del archivo, después de las propiedades existentes
    property int pacienteSeleccionadoId: -1  // ✅ NUEVO: ID del paciente seleccionado
    property bool esPacienteExistente: false // ✅ NUEVO: Flag para paciente existente

    ListModel {
        id: consultasPaginadasModel
    }

    ListModel {
        id: consultasListModel
    }
    ListModel {
        id: resultadosBusquedaPacientesModel
    }

    // ✅ CONEXIONES SIMPLIFICADAS
    Connections {
        target: consultaModel
        
        function onConsultasRecientesChanged() {

            updateTimer.start()
        }
        
        function onEspecialidadesChanged() {
            console.log("🏥 Signal: Especialidades cambiadas")
            //updateEspecialidadesCombo()
        }
        
        function onEstadoCambiado(nuevoEstado) {
            console.log("⏳ Estado:", nuevoEstado)
        }
        
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
    Connections {
        target: appController
        function onUsuarioChanged() {
            console.log("🔄 USUARIO CAMBIÓ:")
            
            
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
                            
                            // ✅ USAR DIRECTAMENTE LAS PROPIEDADES DE PERMISOS
                            enabled: consultasRoot.esAdministrador || consultasRoot.esMedico
                            visible: consultasRoot.esAdministrador || consultasRoot.esMedico
                            
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
                                console.log("🎯 CLICK EN NUEVA CONSULTA:")
                                console.log("   - puedeCrearConsultas:", puedeCrearConsultas)
                                console.log("   - esAdministrador:", esAdministrador)
                                console.log("   - esMedico:", esMedico)
                                
                                if (!puedeCrearConsultas) {
                                    console.log("❌ Sin permisos para crear consultas")
                                    return
                                }
                                
                                console.log("✅ Abriendo diálogo de nueva consulta...")
                                isEditMode = false
                                editingIndex = -1
                                showNewConsultationDialog = true
                            }

                            ToolTip {
                                visible: parent.hovered
                                text: {
                                    if (esAdministrador) return "Crear nueva consulta (Administrador)"
                                    if (esMedico) return "Crear nueva consulta (Médico)"
                                    return "Crear nueva consulta"
                                }
                                delay: 500
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
                                                especialidades.push(esp.text)
                                            }
                                        }
                                    }
                                    return especialidades
                                }
                                currentIndex: 0
                                onCurrentIndexChanged: {                                    
                                    if (currentIndex > 0) {
                                        var selectedIndex = currentIndex - 1
                                        if (consultaModel && consultaModel.especialidades && 
                                            selectedIndex < consultaModel.especialidades.length) {
                                            var esp = consultaModel.especialidades[selectedIndex]
                                            console.log("   - Especialidad seleccionada:", esp.text)
                                            console.log("   - ID:", esp.id)
                                        }
                                    } else {
                                        console.log("   - Filtro limpiado (Todas)")
                                    }
                                    
                                    aplicarFiltros()
                                }
                                
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
                
                // TABLA MODERNA CON LÍNEAS VERTICALES - REDISEÑADA BASADA EN LABORATORIO
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
                        
                        // HEADER CON LÍNEAS VERTICALES - ESTRUCTURA NUEVA
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
                                
                                // CÓDIGO COLUMN
                                Item {
                                    Layout.preferredWidth: parent.width * colCodigo
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
                                
                                // DETALLES COLUMN
                                Item {
                                    Layout.preferredWidth: parent.width * colDetalles
                                    Layout.fillHeight: true
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "DETALLES"
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
                        
                        // CONTENIDO DE TABLA CON SCROLL Y LÍNEAS VERTICALES - NUEVA ESTRUCTURA
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
                                        
                                        // CÓDIGO COLUMN
                                        Item {
                                            Layout.preferredWidth: parent.width * colCodigo
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                text: model.id || "N/A"
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
                                                    text: model.paciente_completo || "Sin nombre"
                                                    color: textColor
                                                    font.bold: false
                                                    font.pixelSize: fontBaseSize * 0.85
                                                    font.family: "Segoe UI, Arial, sans-serif"
                                                    elide: Text.ElideRight
                                                }
                                                
                                                Label {
                                                    width: parent.width - baseUnit
                                                    text: "CI: " + (model.paciente_cedula || "Sin cédula")
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
                                                text: model.especialidad_doctor || "Sin especialidad/doctor"
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
                                        
                                        // DETALLES COLUMN
                                        Item {
                                            Layout.preferredWidth: parent.width * colDetalles
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                anchors.rightMargin: baseUnit
                                                text: model.Detalles || "Sin detalles"
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
                                        
                                        // TIPO COLUMN
                                        Item {
                                            Layout.preferredWidth: parent.width * colTipo
                                            Layout.fillHeight: true
                                            
                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: baseUnit * 7
                                                height: baseUnit * 2.5
                                                color: model.tipo_consulta === "Emergencia" ? warningColorLight : successColorLight
                                                radius: height / 2
                                                
                                                Label {
                                                    anchors.centerIn: parent
                                                    text: model.tipo_consulta || "Normal"
                                                    color: model.tipo_consulta === "Emergencia" ? "#92400E" : "#047857"
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
                                                color: model.tipo_consulta === "Emergencia" ? "#92400E" : "#047857"
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
                                            
                                            // Visibilidad y habilitación basada en permisos
                                            visible: consultasRoot.esAdministrador || consultasRoot.esMedico
                                            enabled: {
                                                if (!model.id) return false
                                                return consultasRoot.esAdministrador || consultasRoot.esMedico
                                            }
                                            
                                            background: Rectangle {
                                                color: parent.enabled ? "transparent" : "#F5F5F5"
                                                border.color: parent.enabled ? "transparent" : "#DDD"
                                                border.width: parent.enabled ? 0 : 1
                                                radius: baseUnit * 0.3
                                            }
                                            
                                            Image {
                                                id: editIcon
                                                anchors.centerIn: parent
                                                width: baseUnit * 2.5
                                                height: baseUnit * 2.5
                                                source: "Resources/iconos/editar.svg"
                                                fillMode: Image.PreserveAspectFit
                                                opacity: parent.enabled ? 1.0 : 0.3
                                            }
                                            
                                            onClicked: {
                                                editarConsulta(index) 
                                            }
                                            
                                            onHoveredChanged: {
                                                if (enabled) {
                                                    editIcon.opacity = hovered ? 0.7 : 1.0
                                                }
                                            }
                                        }

                                        Button {
                                            id: deleteButton
                                            width: baseUnit * 3.5
                                            height: baseUnit * 3.5
                                            
                                            // Solo administradores pueden ver y usar
                                            visible: consultasRoot.esAdministrador || consultasRoot.esMedico
                                            enabled: {
                                                if (!model.id) return false
                                                if (consultasRoot.esAdministrador) return true
                                                
                                                // Para médicos, verificar permisos dinámicamente
                                                if (consultasRoot.esMedico) {
                                                    var permisos = verificarPermisosConsulta(parseInt(model.id))
                                                    return permisos.puede_eliminar
                                                }
                                                
                                                return false
                                            }
                                            
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
                                                eliminarConsulta(index)
                                            }
                                            
                                            ToolTip {
                                                visible: deleteButton.hovered
                                                text: obtenerTooltipEliminacion(parseInt(model.id))
                                                delay: 500
                                                timeout: 5000
                                            }
                                            
                                            onHoveredChanged: {
                                                if (enabled) {
                                                    deleteIcon.opacity = hovered ? 0.7 : 1.0
                                                }
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
                            visible: consultasPaginadasModel.count === 0
                            spacing: baseUnit * 3
                            
                            Item { Layout.fillHeight: true }
                            
                            ColumnLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: baseUnit * 2
                                
                                Label {
                                    text: "🩺"
                                    font.pixelSize: fontBaseSize * 3
                                    color: "#E5E7EB"
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                
                                Label {
                                    text: "No hay consultas registradas"
                                    color: textColor
                                    font.bold: true
                                    font.pixelSize: fontBaseSize * 1.5
                                    Layout.alignment: Qt.AlignHCenter
                                    font.family: "Segoe UI, Arial, sans-serif"
                                }
                                
                                Label {
                                    text: "Registra la primera consulta haciendo clic en \"Nueva Consulta\""
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

    // DIÁLOGO MODAL DE NUEVA/EDITAR CONSULTA - ACTUALIZADO
    Dialog {
        id: consultationFormDialog
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.95, 700)
        height: Math.min(parent.height * 0.95, 850)
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
            console.log("Cargando datos para edición:", consulta.consultaId)
            
            try {
                // 1. CARGAR DATOS DEL PACIENTE - SIN DISPARAR BÚSQUEDAS
                console.log("Cargando datos del paciente...")
                
                // ✅ IMPORTANTE: Marcar como autocompletado ANTES de establecer el texto
                campoBusquedaPaciente.pacienteAutocompletado = true
                
                // Determinar si tiene cédula válida
                var tieneCedula = consulta.pacienteCedula && 
                                consulta.pacienteCedula !== "Sin cédula" && 
                                consulta.pacienteCedula !== "NULL" &&
                                consulta.pacienteCedula !== null
                
                // ✅ ESTABLECER TEXTO SIN DISPARAR BÚSQUEDA (ya está marcado como autocompletado)
                if (tieneCedula) {
                    campoBusquedaPaciente.text = consulta.pacienteCedula
                } else {
                    campoBusquedaPaciente.text = consulta.paciente
                }
                
                // Marcar estados
                campoBusquedaPaciente.pacienteNoEncontrado = false
                pacienteSeleccionado = true
                
                // ✅ ESTABLECER COMO PACIENTE EXISTENTE
                pacienteSeleccionadoId = consulta.pacienteId || -1
                esPacienteExistente = true
                
                // Cargar campos del paciente
                if (consulta.pacienteNombre) {
                    nombrePaciente.text = consulta.pacienteNombre
                    apellidoPaterno.text = consulta.pacienteApellidoP || ""
                    apellidoMaterno.text = consulta.pacienteApellidoM || ""
                } else {
                    // Dividir nombre completo si es necesario
                    var nombrePartes = consulta.paciente.split(' ')
                    nombrePaciente.text = nombrePartes[0] || ""
                    apellidoPaterno.text = nombrePartes[1] || ""
                    apellidoMaterno.text = nombrePartes.slice(2).join(' ')
                }
                
                cedulaPaciente.text = tieneCedula ? consulta.pacienteCedula : ""
                
                console.log("Paciente cargado:", nombrePaciente.text, apellidoPaterno.text)
                
                // 2. CARGAR ESPECIALIDAD
                if (consultaModel && consultaModel.especialidades && consulta.especialidadDoctor) {
                    var especialidadBuscada = consulta.especialidadDoctor.trim()
                    var encontrada = false
                    
                    for (var i = 0; i < consultaModel.especialidades.length; i++) {
                        var esp = consultaModel.especialidades[i]
                        var espTextoCombo = esp.text + " - " + esp.doctor_nombre
                        
                        if (espTextoCombo === especialidadBuscada || 
                            especialidadBuscada.includes(esp.text) ||
                            (consulta.especialidadId && esp.id === consulta.especialidadId)) {
                            
                            especialidadCombo.currentIndex = i + 1
                            consultationFormDialog.selectedEspecialidadIndex = i
                            encontrada = true
                            console.log("Especialidad encontrada:", espTextoCombo)
                            break
                        }
                    }
                    
                    if (!encontrada) {
                        console.log("Especialidad no encontrada:", especialidadBuscada)
                        especialidadCombo.currentIndex = 0
                        consultationFormDialog.selectedEspecialidadIndex = -1
                    }
                }
                
                // 3. CONFIGURAR TIPO DE CONSULTA
                if (consulta.tipo && consulta.tipo.toLowerCase() === "emergencia") {
                    normalRadio.checked = false
                    emergenciaRadio.checked = true
                    consultationFormDialog.consultationType = "Emergencia"
                } else {
                    normalRadio.checked = true
                    emergenciaRadio.checked = false
                    consultationFormDialog.consultationType = "Normal"
                }
                
                // 4. CARGAR DETALLES
                detallesConsulta.text = consulta.detalles || ""
                
                // 5. ACTUALIZAR PRECIOS
                consultationFormDialog.calculatedPrice = consulta.precio || 0
                consultationFormDialog.updatePrices()
                
                console.log("Datos de edición cargados completamente")
                
            } catch (error) {
                console.log("Error cargando datos de edición:", error.message)
                showNotification("Error", "Error cargando datos: " + error.message)
            }
        }
        
        onVisibleChanged: {
            if (visible) {
                console.log("Dialog abierto - Modo:", isEditMode ? "EDICIÓN" : "NUEVO")
                
                if (isEditMode && consultationFormDialog.consultaParaEditar) {
                    console.log("Iniciando carga para edición...")
                    loadEditData()
                } else if (!isEditMode) {
                    console.log("Iniciando modo nuevo registro...")
                    
                    // Limpiar formulario para nuevo registro
                    limpiarDatosPaciente()
                    especialidadCombo.currentIndex = 0
                    normalRadio.checked = true
                    emergenciaRadio.checked = false
                    detallesConsulta.text = ""
                    consultationFormDialog.selectedEspecialidadIndex = -1
                    consultationFormDialog.calculatedPrice = 0.0
                    consultationFormDialog.consultaParaEditar = null
                    
                    // Dar foco al campo de búsqueda
                    campoBusquedaPaciente.forceActiveFocus()
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

        Rectangle {
            id: mensajeInformativo
            anchors.top: dialogHeader.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: baseUnit * 2
            height: isEditMode ? baseUnit * 4 : 0
            visible: isEditMode
            
            color: "#F9FAFB"
            border.color: "#E5E7EB"
            border.width: 1
            radius: baseUnit * 0.5
            
            Behavior on height {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
            
            Row {
                anchors.centerIn: parent
                spacing: baseUnit
                
                Text {
                    text: "i"
                    color: "#6B7280"
                    font.pixelSize: fontBaseSize
                    font.bold: true
                    font.family: "monospace"
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                Label {
                    text: "En modo edición solo se pueden modificar los datos de la consulta, no del paciente"
                    color: "#4B5563"
                    font.pixelSize: fontBaseSize * 0.85
                    font.family: "Segoe UI, Arial, sans-serif"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
        
        ScrollView {
            id: scrollView
            anchors.top: isEditMode ? mensajeInformativo.bottom : dialogHeader.bottom 
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
                        
                        // CAMPO DE BÚSQUEDA UNIFICADO
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit
                            
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: baseUnit
                                
                                Label {
                                    text: isEditMode ? "Paciente de la consulta:" : "Buscar Paciente:"
                                    font.bold: true
                                    color: textColor
                                    font.family: "Segoe UI, Arial, sans-serif"
                                }
                                
                                TextField {
                                    id: campoBusquedaPaciente
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: baseUnit * 4
                                    
                                    // ✅ PROPIEDADES MODIFICADAS PARA MODO EDICIÓN
                                    placeholderText: isEditMode ? "Paciente asignado a esta consulta" : "Buscar por cédula o nombre del paciente..."
                                    readOnly: isEditMode  // ✅ SOLO LECTURA EN MODO EDICIÓN
                                    enabled: !isEditMode  // ✅ DESHABILITADO EN MODO EDICIÓN
                                    
                                    property bool pacienteAutocompletado: false
                                    property bool pacienteNoEncontrado: false
                                    property string tipoDetectado: ""
                                    
                                    // ✅ BACKGROUND MODIFICADO PARA MOSTRAR ESTADO
                                    background: Rectangle {
                                        color: {
                                            if (isEditMode) return "#F8F9FA"  // ✅ Gris claro en modo edición
                                            if (campoBusquedaPaciente.pacienteAutocompletado) return "#F0F8FF"
                                            if (campoBusquedaPaciente.pacienteNoEncontrado) return "#FEF3C7"
                                            return whiteColor
                                        }
                                        border.color: {
                                            if (isEditMode) return "#E5E7EB"  // ✅ Borde gris en modo edición
                                            return campoBusquedaPaciente.activeFocus ? primaryColor : borderColor
                                        }
                                        border.width: campoBusquedaPaciente.activeFocus && !isEditMode ? 2 : 1
                                        radius: baseUnit * 0.6
                                        
                                        // Indicador visual del tipo detectado
                                        Row {
                                            anchors.right: parent.right
                                            anchors.rightMargin: baseUnit
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: baseUnit * 0.5
                                            visible: !isEditMode  // ✅ OCULTAR INDICADORES EN MODO EDICIÓN
                                            
                                            Text {
                                                text: {
                                                    if (campoBusquedaPaciente.pacienteAutocompletado) return "✅"
                                                    if (campoBusquedaPaciente.pacienteNoEncontrado) return "⚠️"
                                                    
                                                    if (campoBusquedaPaciente.tipoDetectado === "cedula") return "🆔"
                                                    if (campoBusquedaPaciente.tipoDetectado === "nombre") return "👤"
                                                    if (campoBusquedaPaciente.tipoDetectado === "mixto") return "🔍"
                                                    
                                                    return campoBusquedaPaciente.text.length > 0 ? "🔍" : ""
                                                }
                                                font.pixelSize: fontBaseSize * 1.1
                                                visible: campoBusquedaPaciente.text.length > 0
                                            }
                                            
                                            Text {
                                                text: {
                                                    if (campoBusquedaPaciente.pacienteAutocompletado) return "Encontrado"
                                                    if (campoBusquedaPaciente.pacienteNoEncontrado) return "Nuevo"
                                                    if (campoBusquedaPaciente.tipoDetectado === "cedula") return "Cédula"
                                                    if (campoBusquedaPaciente.tipoDetectado === "nombre") return "Nombre"
                                                    if (campoBusquedaPaciente.tipoDetectado === "mixto") return "Mixto"
                                                    return ""
                                                }
                                                font.pixelSize: fontBaseSize * 0.7
                                                color: textColorLight
                                                visible: campoBusquedaPaciente.text.length > 1 && text.length > 0
                                            }
                                        }
                                        
                                        // ✅ NUEVO: Icono de "solo lectura" en modo edición
                                        Row {
                                            anchors.right: parent.right
                                            anchors.rightMargin: baseUnit
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: baseUnit * 0.5
                                            visible: isEditMode
                                            
                                            Text {
                                                text: "🔒"
                                                font.pixelSize: fontBaseSize * 1.1
                                            }
                                            
                                            Text {
                                                text: "Solo lectura"
                                                font.pixelSize: fontBaseSize * 0.7
                                                color: "#6B7280"
                                            }
                                        }
                                    }
                                    
                                    onTextChanged: {
                                        // ✅ PROTECCIÓN PRINCIPAL: No buscar en modo edición
                                        if (isEditMode) {
                                            console.log("Modo edición activo - búsqueda desactivada")
                                            return
                                        }
                                        
                                        // Proteger paciente autocompletado
                                        if (pacienteAutocompletado) {
                                            console.log("Campo autocompletado - no buscar")
                                            return
                                        }
                                        
                                        // Si hay paciente existente seleccionado, no buscar automáticamente
                                        if (esPacienteExistente && pacienteSeleccionadoId > 0) {
                                            console.log("Paciente existente seleccionado - no realizar búsqueda automática")
                                            return
                                        }
                                        
                                        // Limpiar estados de búsqueda (PERO NO RESETEAR PACIENTE SELECCIONADO)
                                        if (!pacienteAutocompletado) {
                                            pacienteNoEncontrado = false
                                            mostrarResultadosBusqueda = false
                                        }
                                        
                                        // Detectar tipo de búsqueda
                                        if (text.length >= 1) {
                                            tipoDetectado = consultaModel ? consultaModel.detectar_tipo_busqueda(text) : ""
                                        } else {
                                            tipoDetectado = ""
                                        }
                                        
                                        // Realizar búsqueda si hay suficientes caracteres
                                        if (text.length >= 2 && !pacienteAutocompletado) {
                                            buscarTimer.restart()
                                        } else if (text.length < 2) {
                                            limpiarResultadosBusqueda()
                                        }
                                        
                                        // Solo resetear si NO es un paciente existente Y se borra todo Y NO es modo edición
                                        if (text.length === 0 && !isEditMode && !esPacienteExistente) {
                                            limpiarDatosPaciente()
                                        }
                                    }
                                    
                                    // ✅ DESHABILITAR TECLAS EN MODO EDICIÓN
                                    Keys.onReturnPressed: {
                                        if (isEditMode) return
                                        if (text.length >= 2) {
                                            buscarPacientesUnificado(text)
                                        }
                                    }
                                    
                                    Keys.onEscapePressed: {
                                        if (isEditMode) return
                                        limpiarDatosPaciente()
                                    }
                                    
                                    Keys.onDownPressed: {
                                        if (isEditMode) return
                                        if (mostrarResultadosBusqueda && resultadosBusquedaPacientesModel.count > 0) {
                                            listaResultadosPacientes.incrementCurrentIndex()
                                        }
                                    }
                                    
                                    Keys.onUpPressed: {
                                        if (isEditMode) return
                                        if (mostrarResultadosBusqueda && resultadosBusquedaPacientesModel.count > 0) {
                                            listaResultadosPacientes.decrementCurrentIndex()
                                        }
                                    }
                                }
                                
                                // ✅ BOTONES MODIFICADOS - OCULTOS EN MODO EDICIÓN
                                Button {
                                    text: "Limpiar"
                                    visible: !isEditMode && (  // ✅ OCULTAR EN MODO EDICIÓN
                                        campoBusquedaPaciente.pacienteAutocompletado || 
                                        esPacienteExistente ||
                                        nombrePaciente.text.length > 0 ||
                                        campoBusquedaPaciente.text.length > 0
                                    )

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
                                    
                                    onClicked: forzarLimpiezaPaciente()
                                    
                                    HoverHandler {
                                        cursorShape: Qt.PointingHandCursor
                                    }
                                }
                                
                                Button {
                                    id: nuevoPacienteBtn
                                    text: "Nuevo Paciente"
                                    visible: !isEditMode && (  // ✅ OCULTAR EN MODO EDICIÓN
                                        campoBusquedaPaciente.pacienteNoEncontrado && 
                                        campoBusquedaPaciente.text.length >= 2 &&
                                        !campoBusquedaPaciente.pacienteAutocompletado
                                    )

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
                                    
                                    onClicked: {
                                        habilitarNuevoPaciente()
                                    }
                                    
                                    HoverHandler {
                                        cursorShape: Qt.PointingHandCursor
                                    }
                                    
                                    ToolTip {
                                        visible: nuevoPacienteBtn.hovered
                                        text: "Crear nuevo paciente: " + campoBusquedaPaciente.text
                                        delay: 500
                                        timeout: 3000
                                    }
                                }
                            }
                            
                            // Timer para búsqueda con delay
                            Timer {
                                id: buscarTimer
                                interval: 500
                                running: false
                                repeat: false
                                onTriggered: {
                                    var termino = campoBusquedaPaciente.text.trim()
                                    if (termino.length >= 2) {
                                        buscarPacientesUnificado(termino)
                                    }
                                }
                            }
                            
                            // PANEL DE RESULTADOS INTEGRADO
                            Rectangle {
                                id: panelResultadosPacientes
                                Layout.fillWidth: true
                                Layout.preferredHeight: mostrarResultadosBusqueda && !isEditMode ? Math.min(250, resultadosBusquedaPacientesModel.count * 55 + 60) : 0
                                visible: mostrarResultadosBusqueda && !isEditMode  // ✅ OCULTAR EN MODO EDICIÓN
                                
                                color: whiteColor
                                border.color: primaryColor
                                border.width: 1
                                radius: baseUnit * 0.6
                                
                                Behavior on Layout.preferredHeight {
                                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                }
                                
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: baseUnit * 0.75
                                    spacing: baseUnit * 0.5
                                    
                                    // Header del panel
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: baseUnit
                                        
                                        Label {
                                            text: "👥"
                                            font.pixelSize: fontBaseSize * 0.9
                                        }
                                        
                                        Label {
                                            text: resultadosBusquedaPacientesModel.count + " pacientes encontrados"
                                            font.pixelSize: fontBaseSize * 0.85
                                            color: textColor
                                            font.bold: true
                                            Layout.fillWidth: true
                                        }
                                        
                                        Label {
                                            text: "Tipo: " + campoBusquedaPaciente.tipoDetectado
                                            font.pixelSize: fontBaseSize * 0.75
                                            color: primaryColor
                                            font.bold: true
                                        }
                                        
                                        Button {
                                            width: baseUnit * 2.5
                                            height: baseUnit * 2.5
                                            
                                            background: Rectangle {
                                                color: parent.hovered ? "#f0f0f0" : "transparent"
                                                radius: width / 2
                                            }
                                            
                                            contentItem: Text {
                                                text: "×"
                                                color: textColor
                                                font.pixelSize: fontBaseSize
                                                font.bold: true
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            
                                            onClicked: limpiarResultadosBusqueda()
                                        }
                                    }
                                    
                                    // Línea separadora
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 1
                                        color: borderColor
                                    }
                                    
                                    // Lista de resultados
                                    ScrollView {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        clip: true
                                        
                                        ListView {
                                            id: listaResultadosPacientes
                                            anchors.fill: parent
                                            model: resultadosBusquedaPacientesModel
                                            currentIndex: -1
                                            
                                            delegate: Rectangle {
                                                width: ListView.view ? ListView.view.width : 0
                                                height: 50
                                                color: {
                                                    if (mouseArea.containsMouse) return "#E3F2FD"
                                                    if (ListView.isCurrentItem) return "#BBDEFB"
                                                    return "transparent"
                                                }
                                                radius: baseUnit * 0.4
                                                
                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.margins: baseUnit * 0.75
                                                    spacing: baseUnit * 0.75
                                                    
                                                    // Indicador de tipo de coincidencia
                                                    Rectangle {
                                                        Layout.preferredWidth: baseUnit * 3.5
                                                        Layout.preferredHeight: baseUnit * 3.5
                                                        color: {
                                                            var tipo = model.tipo_coincidencia || ""
                                                            if (tipo.includes("cedula_exacta")) return successColor
                                                            if (tipo.includes("cedula")) return warningColor
                                                            if (tipo.includes("nombre")) return primaryColor
                                                            return lightGrayColor
                                                        }
                                                        radius: width / 2
                                                        
                                                        Label {
                                                            anchors.centerIn: parent
                                                            text: {
                                                                var tipo = model.tipo_coincidencia || ""
                                                                if (tipo.includes("cedula")) return "🆔"
                                                                if (tipo.includes("nombre")) return "👤"
                                                                return "?"
                                                            }
                                                            color: whiteColor
                                                            font.pixelSize: fontBaseSize * 0.7
                                                            font.bold: true
                                                        }
                                                    }
                                                    
                                                    // Información del paciente
                                                    ColumnLayout {
                                                        Layout.fillWidth: true
                                                        spacing: 1
                                                        
                                                        Label {
                                                            text: model.nombre_completo || "Sin nombre"
                                                            color: textColor
                                                            font.bold: true
                                                            font.pixelSize: fontBaseSize * 0.85
                                                            Layout.fillWidth: true
                                                            elide: Text.ElideRight
                                                        }
                                                        
                                                        Label {
                                                            text: "CI: " + (model.cedula || "Sin cédula")
                                                            color: textColorLight
                                                            font.pixelSize: fontBaseSize * 0.7
                                                        }
                                                    }
                                                    
                                                    // Botón seleccionar
                                                    Rectangle {
                                                        Layout.preferredWidth: baseUnit * 7
                                                        Layout.preferredHeight: baseUnit * 2.5
                                                        color: primaryColor
                                                        radius: baseUnit * 0.4
                                                        
                                                        Label {
                                                            anchors.centerIn: parent
                                                            text: "Seleccionar"
                                                            color: whiteColor
                                                            font.bold: true
                                                            font.pixelSize: fontBaseSize * 0.75
                                                        }
                                                        
                                                        MouseArea {
                                                            anchors.fill: parent
                                                            onClicked: {
                                                                seleccionarPacienteEncontrado(index)
                                                            }
                                                        }
                                                    }
                                                }
                                                
                                                MouseArea {
                                                    id: mouseArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    acceptedButtons: Qt.LeftButton
                                                    
                                                    onClicked: {
                                                        seleccionarPacienteEncontrado(index)
                                                    }
                                                    
                                                    onDoubleClicked: {
                                                        seleccionarPacienteEncontrado(index)
                                                    }
                                                }
                                            }
                                            
                                            // Estado vacío
                                            Label {
                                                anchors.centerIn: parent
                                                text: "No se encontraron pacientes"
                                                color: textColorLight
                                                font.pixelSize: fontBaseSize * 0.9
                                                visible: resultadosBusquedaPacientesModel.count === 0 && mostrarResultadosBusqueda
                                            }
                                        }
                                    }
                                    
                                    // Footer con instrucciones
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: baseUnit * 3
                                        color: lightGrayColor
                                        radius: baseUnit * 0.4
                                        
                                        Label {
                                            anchors.centerIn: parent
                                            text: "💡 Use ↑↓ para navegar, Enter para seleccionar, Esc para cerrar"
                                            color: textColorLight
                                            font.pixelSize: fontBaseSize * 0.65
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Estado nuevo paciente
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: baseUnit * 3
                            visible: campoBusquedaPaciente.pacienteNoEncontrado && 
                                    !campoBusquedaPaciente.pacienteAutocompletado
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
                                    text: "Modo: Crear nuevo paciente: " + campoBusquedaPaciente.text
                                    color: "#047857"
                                    font.pixelSize: fontBaseSize * 0.8
                                    font.bold: true
                                    font.family: "Segoe UI, Arial, sans-serif"
                                }
                            }
                        }
                        
                        // Campos de información del paciente
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: baseUnit * 2
                            rowSpacing: baseUnit * 1.5
                            
                            Label {
                                text: "Cédula:"
                                font.bold: true
                                color: textColor
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                            
                            TextField {
                                id: cedulaPaciente
                                Layout.fillWidth: true
                                placeholderText: "Cédula del paciente (puede estar vacía)"
                                readOnly: campoBusquedaPaciente.pacienteAutocompletado
                                font.pixelSize: fontBaseSize
                                font.family: "Segoe UI, Arial, sans-serif"
                                
                                background: Rectangle {
                                    color: campoBusquedaPaciente.pacienteAutocompletado ? "#F8F9FA" : whiteColor
                                    border.color: borderColor
                                    border.width: 1
                                    radius: baseUnit * 0.6
                                }
                                padding: baseUnit
                            }
                            
                            Label {
                                text: "Nombre:"
                                font.bold: true
                                color: textColor
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                            
                            TextField {
                                id: nombrePaciente
                                Layout.fillWidth: true
                                placeholderText: campoBusquedaPaciente.pacienteAutocompletado ? 
                                            "Nombre del paciente" : "Ingrese nombre del paciente"
                                readOnly: campoBusquedaPaciente.pacienteAutocompletado
                                font.pixelSize: fontBaseSize
                                font.family: "Segoe UI, Arial, sans-serif"
                                
                                property bool esCampoNuevoPaciente: !campoBusquedaPaciente.pacienteAutocompletado && 
                                                            campoBusquedaPaciente.pacienteNoEncontrado
                                
                                background: Rectangle {
                                    color: {
                                        if (campoBusquedaPaciente.pacienteAutocompletado) return "#F8F9FA"
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
                                placeholderText: campoBusquedaPaciente.pacienteAutocompletado ? 
                                                "Apellido paterno" : "Ingrese apellido paterno"
                                readOnly: campoBusquedaPaciente.pacienteAutocompletado
                                font.pixelSize: fontBaseSize
                                font.family: "Segoe UI, Arial, sans-serif"
                                
                                property bool esCampoNuevoPaciente: !campoBusquedaPaciente.pacienteAutocompletado && 
                                                                campoBusquedaPaciente.pacienteNoEncontrado
                                
                                background: Rectangle {
                                    color: {
                                        if (campoBusquedaPaciente.pacienteAutocompletado) return "#F8F9FA"
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
                                placeholderText: campoBusquedaPaciente.pacienteAutocompletado ? 
                                                "Apellido materno" : "Ingrese apellido materno (opcional)"
                                readOnly: campoBusquedaPaciente.pacienteAutocompletado
                                font.pixelSize: fontBaseSize
                                font.family: "Segoe UI, Arial, sans-serif"
                                
                                property bool esCampoNuevoPaciente: !campoBusquedaPaciente.pacienteAutocompletado && 
                                                                campoBusquedaPaciente.pacienteNoEncontrado
                                
                                background: Rectangle {
                                    color: {
                                        if (campoBusquedaPaciente.pacienteAutocompletado) return "#F8F9FA"
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
                                        var newSelectedIndex = currentIndex - 1
                                        var selectedEsp = consultaModel.especialidades[newSelectedIndex]
                                        consultationFormDialog.selectedEspecialidadIndex = newSelectedIndex
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
                    var nombreValido = nombrePaciente.text.length >= 2
                    var apellidoValido = apellidoPaterno.text.length >= 2
                    var detallesValidos = detallesConsulta.text.length >= 10
                    
                    return especialidadSeleccionada && nombreValido && apellidoValido && detallesValidos
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
                        text: "¿Está seguro de eliminar esta consulta?"
                        font.pixelSize: fontBaseSize * 1.1
                        font.bold: true
                        color: textColor
                        Layout.alignment: Qt.AlignHCenter
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        font.family: "Segoe UI, Arial, sans-serif"
                    }

                    // ✅ NUEVO: Mostrar información de permisos
                    Label {
                        text: {
                            if (!consultaIdToDelete) return "Seleccione una consulta"
                            
                            var permisos = verificarPermisosConsulta(parseInt(consultaIdToDelete))
                            
                            if (permisos.es_administrador) {
                                return "Como administrador, puede eliminar cualquier consulta sin restricciones."
                            }
                            
                            if (permisos.es_medico) {
                                if (permisos.puede_eliminar) {
                                    var diasRestantes = Math.max(0, 30 - permisos.dias_antiguedad)
                                    return `Consulta de ${permisos.dias_antiguedad} días. Le quedan ${diasRestantes} días más para poder eliminar.`
                                } else {
                                    return `Esta consulta tiene ${permisos.dias_antiguedad} días (límite: 30 días).`
                                }
                            }
                            
                            return "Verificando permisos..."
                        }
                        font.pixelSize: fontBaseSize * 0.9
                        color: {
                            if (!consultaIdToDelete) return "#6b7280"
                            
                            var permisos = verificarPermisosConsulta(parseInt(consultaIdToDelete))
                            if (permisos.es_administrador) return "#059669"
                            if (permisos.puede_eliminar) return "#059669"
                            return "#dc2626"
                        }
                        Layout.alignment: Qt.AlignHCenter
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        Layout.maximumWidth: parent.width - baseUnit * 4
                        font.family: "Segoe UI, Arial, sans-serif"
                    }

                    Label {
                        text: "Esta acción no se puede deshacer y el registro se eliminará permanentemente."
                        font.pixelSize: fontBaseSize * 0.85
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
    
    Component.onCompleted: {
        console.log("Módulo Consultas iniciado con búsqueda unificada")
        
        function conectarModelos() {
            if (typeof appController !== 'undefined') {
                consultaModel = appController.consulta_model_instance
                
                if (consultaModel) {
                    consultaModel.consultasRecientesChanged.connect(function() {
                        console.log("Consultas recientes cambiadas")
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
            // Calcular el índice real en la lista de especialidades
            var selectedIndexInEspecialidades = filtroEspecialidad.currentIndex - 1
            
            // Obtener directamente desde consultaModel.especialidades
            if (consultaModel && consultaModel.especialidades && 
                selectedIndexInEspecialidades >= 0 && 
                selectedIndexInEspecialidades < consultaModel.especialidades.length) {
                
                var selectedEspecialidad = consultaModel.especialidades[selectedIndexInEspecialidades]
                
                // Usar el nombre de la especialidad para el filtro
                filtros.especialidad = selectedEspecialidad.text
                
                console.log("✅ Filtro especialidad aplicado:", selectedEspecialidad.text, "ID:", selectedEspecialidad.id)
            } else {
                console.log("❌ Índice de especialidad fuera de rango:", selectedIndexInEspecialidades)
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
        try {
            console.log("🩺 === INICIANDO CREACIÓN DE NUEVA CONSULTA ===")
            
            // Validar formulario
            if (!validarFormularioConsulta()) {
                return
            }
            
            // Mostrar loading
            consultationFormDialog.enabled = false
            
            // 1. Gestionar paciente
            var pacienteId = buscarOCrearPaciente()
            if (pacienteId <= 0) {
                throw new Error("Error gestionando datos del paciente")
            }
            
            // 2. Obtener datos del formulario
            var datosConsulta = obtenerDatosFormularioConsulta()
            
            // 3. LLAMADA CORREGIDA - 4 PARÁMETROS INDIVIDUALES
            console.log("🩺 Creando consulta con parámetros:")
            console.log("   - Paciente ID:", pacienteId)
            console.log("   - Especialidad ID:", datosConsulta.especialidadId)
            console.log("   - Tipo consulta:", datosConsulta.tipoConsulta)
            console.log("   - Detalles:", datosConsulta.detalles)
            
            var resultado = consultaModel.crear_consulta(
                pacienteId,                    // 1er parámetro: int
                datosConsulta.especialidadId,  // 2do parámetro: int
                datosConsulta.tipoConsulta,    // 3er parámetro: string
                datosConsulta.detalles         // 4to parámetro: string
            )
            
            // 4. Procesar resultado
            procesarResultadoCreacionConsulta(resultado)
            
        } catch (error) {
            console.log("❌ Error creando consulta:", error.message)
            consultationFormDialog.enabled = true
            showNotification("Error", error.message)
        }
    }

    function actualizarConsulta() {
        try {
            console.log("🔍 UPDATE DEBUG - Iniciando actualización...")
            
            if (!validarFormularioConsulta()) {
                return
            }
            
            if (!isEditMode || !consultationFormDialog.consultaParaEditar) {
                throw new Error("No hay consulta seleccionada para editar")
            }
            
            consultationFormDialog.enabled = false
            
            var consultaId = consultationFormDialog.consultaParaEditar.consultaId
            console.log("🔍 UPDATE DEBUG - Consulta ID:", consultaId)
            
            var datosConsulta = obtenerDatosFormularioConsulta()
            
            console.log("🔍 UPDATE DEBUG - Datos obtenidos del form:")
            console.log("   - especialidadId:", datosConsulta.especialidadId)
            console.log("   - especialidad_id:", datosConsulta.especialidad_id)
            console.log("   - tipoConsulta:", datosConsulta.tipoConsulta)
            
            var datosActualizados = {
                "detalles": datosConsulta.detalles,
                "tipo_consulta": datosConsulta.tipoConsulta,
                "especialidad_id": datosConsulta.especialidad_id
            }
            
            console.log("🔍 UPDATE DEBUG - Objeto final a enviar al backend:")
            console.log(JSON.stringify(datosActualizados))
            
            var resultado = consultaModel.actualizar_consulta(parseInt(consultaId), datosActualizados)
            
            console.log("🔍 UPDATE DEBUG - Resultado del backend:")
            console.log(typeof resultado === 'string' ? resultado : JSON.stringify(resultado))
            
            procesarResultadoActualizacionConsulta(resultado)
            
        } catch (error) {
            console.log("❌ UPDATE DEBUG - Error:", error.message)
            consultationFormDialog.enabled = true
            showNotification("Error", error.message)
        }
    }

    function aplicarFiltros() {
        //console.log("🔍 Aplicando filtros...")
        
        // Resetear a primera página
        currentPageConsultas = 0
        
        // Usar la función actualizada
        updatePaginatedModel()
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

    function verificarPermisosConsulta(consultaId) {
        try {
            if (!consultaModel || !consultaId) {
                return {
                    puede_editar: false,
                    puede_eliminar: false,
                    razon_editar: "Datos insuficientes"
                }
            }
            
            var permisos = consultaModel.verificar_permisos_consulta(parseInt(consultaId))
            
            
            return permisos
            
        } catch (error) {
            console.log("❌ Error verificando permisos:", error.message)
            return {
                puede_editar: false,
                puede_eliminar: false,
                razon_editar: "Error verificando permisos"
            }
        }
    }
    function verificarYCorregirDatos() {
        if (!isEditMode) return
        
        console.log("🔍 Verificando datos cargados...")
        
        // Verificar paciente
        if (!campoBusquedaPaciente.pacienteAutocompletado) {
            console.log("⚠️ Paciente no autocompletado, reintentando...")
            loadEditData()
        }
        
        // Verificar especialidad
        if (consultationFormDialog.selectedEspecialidadIndex < 0) {
            console.log("⚠️ Especialidad no seleccionada, reintentando...")
            reintentarCargaEspecialidad()
        }
        
        console.log("✅ Verificación completada")
    }
    

    function puedeEliminarConsulta(consultaId) {
        if (!consultaId) return false
        
        var permisos = verificarPermisosConsulta(consultaId)
        return permisos.puede_eliminar
    }

    function obtenerMensajePermiso(consultaId) {
        var permisos = verificarPermisosConsulta(consultaId)
        
        if (permisos.es_administrador) {
            return "Administrador: Acceso completo"
        }
        
        if (permisos.es_medico) {
            if (permisos.dias_antiguedad > 30) {
                return `Solo puede eliminar consultas de máximo 30 días (esta tiene ${permisos.dias_antiguedad} días)`
            }
            return "Médico: Puede editar siempre, eliminar si es reciente"
        }
        
        return "Sin permisos para esta operación"
    }
    function editarConsulta(consultaIndex) {
        try {
            if (consultaIndex < 0 || consultaIndex >= consultasPaginadasModel.count) {
                showNotification("Error", "Consulta no encontrada")
                return
            }
            
            var consulta = consultasPaginadasModel.get(consultaIndex)
            var consultaId = consulta.id
            
            console.log("📝 EDITANDO CONSULTA:", consultaId)
            
            // ✅ OBTENER DATOS COMPLETOS
            var resultadoCompleto = consultaModel.obtener_consulta_completa(parseInt(consultaId))
            var datosCompletos = null
            
            try {
                var resultadoObj = JSON.parse(resultadoCompleto)
                if (resultadoObj.exito && resultadoObj.consulta) {
                    datosCompletos = resultadoObj.consulta
                }
            } catch (e) {
                console.log("⚠️ Usando datos básicos")
            }
            
            // ✅ PREPARAR DATOS COMPLETOS
            var datosParaEdicion = datosCompletos || consulta
            
            consultationFormDialog.consultaParaEditar = {
                // IDs
                consultaId: parseInt(consultaId),
                pacienteId: datosParaEdicion.paciente_id || datosParaEdicion.Id_Paciente,
                especialidadId: datosParaEdicion.especialidad_id || datosParaEdicion.Id_Especialidad,
                
                // Datos del paciente
                paciente: datosParaEdicion.paciente_completo || consulta.paciente_completo,
                pacienteCedula: datosParaEdicion.paciente_cedula || consulta.paciente_cedula,
                pacienteNombre: datosParaEdicion.paciente_nombre,
                pacienteApellidoP: datosParaEdicion.paciente_apellido_p,
                pacienteApellidoM: datosParaEdicion.paciente_apellido_m,
                
                // Datos de especialidad
                especialidadDoctor: datosParaEdicion.especialidad_doctor || consulta.especialidad_doctor,
                especialidadNombre: datosParaEdicion.especialidad_nombre,
                
                // Datos de consulta
                tipo: datosParaEdicion.tipo_consulta || consulta.tipo_consulta,
                precio: parseFloat(datosParaEdicion.precio || consulta.precio || 0),
                detalles: datosParaEdicion.Detalles || consulta.Detalles,
                fecha: datosParaEdicion.Fecha || consulta.fecha
            }
            
            // ✅ CONFIGURAR MODO EDICIÓN ANTES DE ABRIR DIALOG
            isEditMode = true
            editingIndex = consultaIndex
            
            // ✅ ABRIR DIALOG (esto disparará onVisibleChanged)
            showNewConsultationDialog = true
            
            console.log("✅ Modo edición configurado para consulta:", consultaId)
            
        } catch (error) {
            console.log("❌ Error en editarConsulta:", error.message)
            showNotification("Error", "Error iniciando edición: " + error.message)
        }
    }

    function eliminarConsulta(consultaIndex) {
        try {
            if (consultaIndex < 0 || consultaIndex >= consultasPaginadasModel.count) {
                showNotification("Error", "Consulta no encontrada")
                return
            }
            
            var consulta = consultasPaginadasModel.get(consultaIndex)
            var consultaId = consulta.id
            
            console.log("🗑️ Intentando eliminar consulta:", consultaId)
            
            // Verificar permisos específicos
            if (!puedeEliminarConsulta(consultaId)) {
                var mensaje = obtenerMensajePermiso(consultaId)
                showNotification("Acceso Denegado", mensaje)
                return
            }
            
            // Confirmar eliminación
            consultaIdToDelete = consultaId
            showConfirmDeleteDialog = true
            
            console.log("✅ Consulta marcada para eliminación:", consultaId)
            
        } catch (error) {
            console.log("❌ Error en eliminarConsulta:", error.message)
            showNotification("Error", "Error iniciando eliminación: " + error.message)
        }
    }
    // 2. AGREGAR DEBUGGING EN obtenerDatosFormularioConsulta() (línea ~1370)
    function obtenerDatosFormularioConsulta() {
        try {
            if (!consultaModel || !consultaModel.especialidades) {
                throw new Error("No hay especialidades disponibles")
            }
            
            if (consultationFormDialog.selectedEspecialidadIndex < 0 || 
                consultationFormDialog.selectedEspecialidadIndex >= consultaModel.especialidades.length) {
                throw new Error("Índice de especialidad inválido: " + consultationFormDialog.selectedEspecialidadIndex)
            }
            
            var especialidadSeleccionada = consultaModel.especialidades[consultationFormDialog.selectedEspecialidadIndex]
            var especialidadId = especialidadSeleccionada.id
            
            if (!especialidadId || especialidadId <= 0) {
                throw new Error("ID de especialidad inválido: " + especialidadId)
            }
            
            var tipoConsulta = consultationFormDialog.consultationType.toLowerCase()
            
            var resultado = {
                especialidadId: especialidadId,
                tipoConsulta: tipoConsulta,
                detalles: detallesConsulta.text.trim(),
                especialidad_id: especialidadId
            }
            
            return resultado
            
        } catch (error) {
            console.log("❌ FORM DEBUG - Error:", error.message)
            throw error
        }
    }
    
    function obtenerTooltipEliminacion(consultaId) {
        if (!consultaId) return "Consulta no válida"
        
        var permisos = verificarPermisosConsulta(consultaId)
        
        if (permisos.es_administrador) {
            return "Eliminar consulta (Administrador - Sin restricciones)"
        }
        
        if (permisos.es_medico) {
            if (permisos.puede_eliminar) {
                var diasRestantes = Math.max(0, 30 - permisos.dias_antiguedad)
                return `Eliminar (${permisos.dias_antiguedad} días - ${diasRestantes} días restantes)`
            } else {
                return `Bloqueado: ${permisos.dias_antiguedad} días (Límite: 30 días)`
            }
        }
        
        return "Sin permisos para eliminar"
    }

    // ===============================
    // NUEVAS FUNCIONES PRINCIPALES
    // ===============================

    function buscarPacientesUnificado(termino) {
        if (!consultaModel || !termino || termino.length < 2) {
            limpiarResultadosBusqueda()
            return
        }
        
        console.log("Buscando pacientes (unificado):", termino)
        
        try {
            var resultados = consultaModel.buscar_paciente_unificado(termino.trim(), 8)
            
            resultadosBusquedaPacientesModel.clear()
            
            if (resultados && resultados.length > 0) {
                for (var i = 0; i < resultados.length; i++) {
                    var paciente = resultados[i]
                    
                    resultadosBusquedaPacientesModel.append({
                        id: paciente.id,
                        nombre: paciente.nombre,
                        apellido_paterno: paciente.apellido_paterno,
                        apellido_materno: paciente.apellido_materno,
                        cedula: paciente.cedula,
                        nombre_completo: paciente.nombre_completo,
                        relevancia: paciente.relevancia,
                        tipo_coincidencia: paciente.tipo_coincidencia,
                        texto_busqueda: paciente.texto_busqueda
                    })
                }
                
                mostrarResultadosBusqueda = true
                campoBusquedaPaciente.pacienteNoEncontrado = false
                
                console.log("Encontrados", resultados.length, "pacientes")
            } else {
                console.log("No se encontraron pacientes para:", termino)
                mostrarResultadosBusqueda = false
                marcarComoNuevoPaciente(termino)
            }
            
        } catch (error) {
            console.log("Error en búsqueda unificada:", error.message)
            limpiarResultadosBusqueda()
        }
    }

    function seleccionarPacienteEncontrado(index) {
        if (index < 0 || index >= resultadosBusquedaPacientesModel.count) {
            console.log("Índice inválido:", index)
            return
        }
        
        var paciente = resultadosBusquedaPacientesModel.get(index)
        
        console.log("Paciente seleccionado:", paciente.nombre_completo)
        
        // ✅ GUARDAR ID DEL PACIENTE EXISTENTE
        pacienteSeleccionadoId = paciente.id || -1
        esPacienteExistente = (pacienteSeleccionadoId > 0)
        
        console.log("🆔 Paciente existente guardado - ID:", pacienteSeleccionadoId)
        
        // Autocompletar campos
        nombrePaciente.text = paciente.nombre || ""
        apellidoPaterno.text = paciente.apellido_paterno || ""
        apellidoMaterno.text = paciente.apellido_materno || ""
        
        // ✅ MANEJAR CÉDULA NULL/VACÍA CORRECTAMENTE
        var cedulaValue = paciente.cedula
        if (cedulaValue === null || cedulaValue === undefined || cedulaValue === "NULL" || cedulaValue === "") {
            cedulaPaciente.text = ""
            console.log("📋 Paciente sin cédula registrada")
        } else {
            cedulaPaciente.text = cedulaValue.toString()
            console.log("📋 Cédula cargada:", cedulaValue)
        }
        
        // ✅ IMPORTANTE: Actualizar campo de búsqueda SIN disparar nueva búsqueda
        campoBusquedaPaciente.pacienteAutocompletado = true  // MARCAR ANTES de cambiar texto
        campoBusquedaPaciente.text = paciente.nombre_completo
        campoBusquedaPaciente.pacienteNoEncontrado = false
        
        pacienteSeleccionado = true
        pacienteActual = paciente
        
        // Limpiar resultados
        limpiarResultadosBusqueda()
        
        console.log("✅ Paciente autocompletado correctamente (ID:", pacienteSeleccionadoId, ")")
    }

    function marcarComoNuevoPaciente(termino) {
        // ✅ PROTECCIÓN: No marcar como nuevo si ya hay un paciente existente seleccionado
        if (esPacienteExistente && pacienteSeleccionadoId > 0) {
            console.log("🛡️ Paciente existente protegido - no marcar como nuevo")
            return
        }
        
        campoBusquedaPaciente.pacienteNoEncontrado = true
        campoBusquedaPaciente.pacienteAutocompletado = false
        pacienteSeleccionado = false
        pacienteActual = null
        
        // Analizar automáticamente el término para pre-llenar campos
        if (consultaModel && termino.length >= 3) {
            var tipoDetectado = consultaModel.detectar_tipo_busqueda(termino)
            
            if (tipoDetectado === "nombre") {
                // Analizar nombre y pre-llenar campos
                var componentes = consultaModel.analizar_nombre_completo(termino)
                
                if (componentes && componentes.valido) {
                    nombrePaciente.text = componentes.nombre || ""
                    apellidoPaterno.text = componentes.apellido_paterno || ""
                    apellidoMaterno.text = componentes.apellido_materno || ""
                    cedulaPaciente.text = ""
                    
                    console.log("Campos pre-llenados desde análisis:", componentes)
                }
            } else if (tipoDetectado === "cedula") {
                // Pre-llenar cédula y limpiar nombres
                cedulaPaciente.text = termino.replace(/\D/g, '')
                nombrePaciente.text = ""
                apellidoPaterno.text = ""
                apellidoMaterno.text = ""
            }
        }
        
        console.log("Marcado como nuevo paciente:", termino)
    }

    function limpiarResultadosBusqueda() {
        mostrarResultadosBusqueda = false
        resultadosBusquedaPacientesModel.clear()
    }

    function habilitarNuevoPaciente() {
        console.log("Habilitando creación de nuevo paciente:", campoBusquedaPaciente.text)
        
        var termino = campoBusquedaPaciente.text.trim()
        marcarComoNuevoPaciente(termino)
        
        // Enfocar el primer campo vacío
        if (!nombrePaciente.text) {
            nombrePaciente.forceActiveFocus()
        } else if (!apellidoPaterno.text) {
            apellidoPaterno.forceActiveFocus()
        } else {
            detallesConsulta.forceActiveFocus()
        }
    }

    // ===============================
    // FUNCIÓN LIMPIAR ACTUALIZADA
    // ===============================

    function limpiarDatosPaciente() {
        // No limpiar si estamos en modo edición
        if (isEditMode) {
            console.log("Modo edición activo - NO limpiar datos")
            return
        }
        
        campoBusquedaPaciente.text = ""
        cedulaPaciente.text = ""
        nombrePaciente.text = ""
        apellidoPaterno.text = ""
        apellidoMaterno.text = ""
        
        // ✅ RESETEAR NUEVOS CAMPOS
        pacienteSeleccionadoId = -1
        esPacienteExistente = false
        
        // Resetear estados
        campoBusquedaPaciente.pacienteAutocompletado = false
        campoBusquedaPaciente.pacienteNoEncontrado = false
        campoBusquedaPaciente.tipoDetectado = ""
        pacienteSeleccionado = false
        pacienteActual = null
        
        limpiarResultadosBusqueda()
        
        console.log("Datos del paciente limpiados completamente")
    }

    function forzarLimpiezaPaciente() {
        console.log("🧹 Forzando limpieza completa del paciente")
        
        // Forzar limpieza incluso si hay paciente existente
        pacienteSeleccionadoId = -1
        esPacienteExistente = false
        
        campoBusquedaPaciente.text = ""
        cedulaPaciente.text = ""
        nombrePaciente.text = ""
        apellidoPaterno.text = ""
        apellidoMaterno.text = ""
        
        // Resetear estados
        campoBusquedaPaciente.pacienteAutocompletado = false
        campoBusquedaPaciente.pacienteNoEncontrado = false
        campoBusquedaPaciente.tipoDetectado = ""
        pacienteSeleccionado = false
        pacienteActual = null
        
        limpiarResultadosBusqueda()
        
        console.log("✅ Limpieza forzada completada")
    }
    // ===============================
    // FUNCIÓN BUSCAR O CREAR ACTUALIZADA
    // ===============================

    function buscarOCrearPaciente() {
        if (!consultaModel) {
            throw new Error("ConsultaModel no disponible")
        }
        
        // ✅ NUEVA LÓGICA: Si es paciente existente seleccionado, usar su ID directamente
        if (esPacienteExistente && pacienteSeleccionadoId > 0) {
            console.log("🎯 Usando paciente existente seleccionado - ID:", pacienteSeleccionadoId)
            return pacienteSeleccionadoId
        }
        
        // ✅ LÓGICA ORIGINAL: Buscar o crear paciente nuevo
        var nombre = nombrePaciente.text.trim()
        var apellidoP = apellidoPaterno.text.trim()
        var apellidoM = apellidoMaterno.text.trim()
        var cedula = cedulaPaciente.text.trim()
        
        // Validaciones básicas
        if (!nombre || nombre.length < 2) {
            throw new Error("Nombre inválido: " + nombre)
        }
        if (!apellidoP || apellidoP.length < 2) {
            throw new Error("Apellido paterno inválido: " + apellidoP)
        }
        
        console.log("🔍 Buscando/creando paciente nuevo:", nombre, apellidoP, "- Cedula:", cedula || "vacía")
        
        // Usar el método mejorado del modelo
        var pacienteId = consultaModel.buscar_o_crear_paciente_inteligente(
            nombre, apellidoP, apellidoM, cedula
        )
        
        if (!pacienteId || pacienteId <= 0) {
            throw new Error("Error: ID de paciente inválido: " + pacienteId)
        }
        
        console.log("✅ Paciente gestionado correctamente - ID:", pacienteId)
        return pacienteId
    }

    // ===============================
    // FUNCIÓN VALIDAR ACTUALIZADA
    // ===============================

    function validarFormularioConsulta() {
        if (consultationFormDialog.selectedEspecialidadIndex < 0) {
            showNotification("Error", "Debe seleccionar una especialidad")
            return false
        }
        
        if (nombrePaciente.text.length < 2) {
            showNotification("Error", "Nombre del paciente es obligatorio")
            return false
        }
        
        if (apellidoPaterno.text.length < 2) {
            showNotification("Error", "Apellido paterno es obligatorio")
            return false
        }
        
        if (detallesConsulta.text.length < 10) {
            showNotification("Error", "Los detalles son obligatorios (mínimo 10 caracteres)")
            return false
        }
        
        // Validación específica para nuevos pacientes
        if (campoBusquedaPaciente.pacienteNoEncontrado) {
            var cedula = cedulaPaciente.text.trim()
            var tipoDetectado = campoBusquedaPaciente.tipoDetectado
            
            // Si el tipo detectado era cédula, debe tener cédula válida
            if (tipoDetectado === "cedula" && (!cedula || cedula.length < 6)) {
                showNotification("Error", "Debe ingresar una cédula válida")
                return false
            }
        }
        
        return true
    }

    // ===============================
    // FUNCIÓN LIMPIAR Y CERRAR ACTUALIZADA
    // ===============================

    function limpiarYCerrarDialogoConsulta() {
        // Cerrar diálogo
        showNewConsultationDialog = false
        
        // Limpiar datos del paciente usando nueva función
        limpiarDatosPaciente()
        
        // Limpiar campos de consulta
        detallesConsulta.text = ""
        especialidadCombo.currentIndex = 0
        
        // Resetear radiobuttons de tipo de consulta
        normalRadio.checked = true
        emergenciaRadio.checked = false
        
        // Resetear propiedades del dialog
        consultationFormDialog.selectedEspecialidadIndex = -1
        consultationFormDialog.calculatedPrice = 0.0
        consultationFormDialog.consultationType = "Normal"
        consultationFormDialog.consultaParaEditar = null
        
        // Resetear estados de la interfaz
        selectedRowIndex = -1
        isEditMode = false
        editingIndex = -1
        
        // ✅ RESETEAR NUEVOS CAMPOS
        pacienteSeleccionadoId = -1
        esPacienteExistente = false
        
        console.log("Formulario de consulta limpiado completamente y diálogo cerrado")
    }

    // ===============================
    // FUNCIONES DE AUTOCOMPLETADO LEGACY SIMPLIFICADAS
    // ===============================

    function autocompletarDatosPaciente(paciente) {
        // Redirigir al nuevo sistema
        console.log("LEGACY: Redirigiendo autocompletado al nuevo sistema")
        
        nombrePaciente.text = paciente.Nombre || ""
        apellidoPaterno.text = paciente.Apellido_Paterno || ""
        apellidoMaterno.text = paciente.Apellido_Materno || ""
        cedulaPaciente.text = paciente.Cedula || ""
        
        campoBusquedaPaciente.text = paciente.nombre_completo || 
            (paciente.Nombre + " " + paciente.Apellido_Paterno + " " + (paciente.Apellido_Materno || "")).trim()
        
        campoBusquedaPaciente.pacienteAutocompletado = true
        campoBusquedaPaciente.pacienteNoEncontrado = false
        pacienteSeleccionado = true
        
        console.log("Paciente autocompletado (legacy):", paciente.nombre_completo || "")
    }

    // ===============================
    // COMPATIBILIDAD CON FUNCIONES EXISTENTES
    // ===============================

    // Mantener para compatibilidad pero redirigir al nuevo sistema
    function buscarPacientes(termino_busqueda, limite) {
        console.log("LEGACY: Redirigiendo búsqueda al sistema unificado")
        return buscarPacientesUnificado(termino_busqueda)
    }

    // ===============================
    // FUNCIONES DE DEBUGGING Y UTILIDADES
    // ===============================

    function verificarEstadoPaciente() {
        console.log("=== ESTADO ACTUAL DEL PACIENTE ===")
        console.log("Campo búsqueda:", campoBusquedaPaciente.text)
        console.log("Autocompletado:", campoBusquedaPaciente.pacienteAutocompletado)
        console.log("No encontrado:", campoBusquedaPaciente.pacienteNoEncontrado)
        console.log("Tipo detectado:", campoBusquedaPaciente.tipoDetectado)
        console.log("Paciente seleccionado:", pacienteSeleccionado)
        console.log("Nombre:", nombrePaciente.text)
        console.log("Apellido P:", apellidoPaterno.text)
        console.log("Apellido M:", apellidoMaterno.text)
        console.log("Cédula:", cedulaPaciente.text)
        console.log("Resultados visibles:", mostrarResultadosBusqueda)
        console.log("Cantidad resultados:", resultadosBusquedaPacientesModel.count)
        console.log("=================================")
    }

    function reiniciarBusquedaPaciente() {
        console.log("Reiniciando búsqueda de paciente...")
        limpiarDatosPaciente()
        campoBusquedaPaciente.forceActiveFocus()
    }
}