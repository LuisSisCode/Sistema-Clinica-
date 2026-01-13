// Interfaz de enfermeria
import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

Item {
    id: enfermeriaRoot
    objectName: "enfermeriaRoot"
    
    // ===============================
    // 1. PROPIEDADES CORREGIDAS
    // ===============================
    
    // PROPIEDADES BÁSICAS
    property var enfermeriaModel: null
    property bool modeloConectado: false
    
    // PROPIEDADES DE ESTILO ADAPTATIVO
    readonly property real baseUnit: parent.baseUnit || Math.max(8, Screen.height / 100)
    readonly property real fontBaseSize: parent.fontBaseSize || Math.max(12, Screen.height / 70)
    readonly property real scaleFactor: parent.scaleFactor || Math.min(width / 1400, height / 900)
    readonly property real iconSize: Math.max(baseUnit * 3, 24)
    readonly property real buttonIconSize: Math.max(baseUnit * 2, 18)
    
    // PROPIEDADES PARA DIÁLOGO DE CONFIRMACIÓN DE ELIMINACIÓN
    property string procedimientoIdToDelete: ""
    property bool showConfirmDeleteDialog: false

    // PROPIEDADES DE COLOR (sin cambios)
    readonly property color primaryColor: "#e91e63"
    readonly property color primaryColorHover: "#d81b60"
    readonly property color primaryColorPressed: "#c2185b"
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
    
    // DISTRIBUCIÓN DE COLUMNAS (sin cambios)
    readonly property real colCodigo: 0.06        
    readonly property real colPaciente: 0.18      
    readonly property real colProcedimiento: 0.18  
    readonly property real colDetalles: 0.16      
    readonly property real colEjecutadoPor: 0.14   
    readonly property real colTipo: 0.08          
    readonly property real colPrecio: 0.10        
    readonly property real colFecha: 0.10
    
    // ✅ PROPIEDADES DE PAGINACIÓN CORREGIDAS
    readonly property int currentPageEnfermeria: enfermeriaModel && modeloConectado ? 
        (enfermeriaModel.currentPageProperty || 0) : 0
    readonly property int totalPagesEnfermeria: enfermeriaModel && modeloConectado ? 
        (enfermeriaModel.totalPagesProperty || 1) : 1
    readonly property int itemsPerPageEnfermeria: enfermeriaModel && modeloConectado ? 
        (enfermeriaModel.itemsPerPageProperty || 6) : 6
    readonly property int totalItemsEnfermeria: enfermeriaModel && modeloConectado ? 
        (enfermeriaModel.totalRecordsProperty || 0) : 0
    
    // PROPIEDADES DEL FORMULARIO
    property bool showNewProcedureDialog: false
    property bool isEditMode: false
    property int editingIndex: -1
    property int selectedRowIndex: -1
    property bool formEnabled: true
    
    // ✅ PROPIEDADES DE FILTROS ESTANDARIZADAS
    property var filtrosActivos: ({
        "busqueda": "",
        "tipo_procedimiento": "",
        "tipo": "",
        "fecha_desde": "",
        "fecha_hasta": ""
    })
    // PROPIEDADES GLOBALES ADICIONALES NECESARIAS (agregar después de las propiedades existentes)
    property int pacienteSeleccionadoId: -1
    property bool esPacienteExistente: false
    property bool pacienteAutocompletado: false

    // Propiedades para búsqueda unificada
    property bool mostrarResultadosBusqueda: false
    property bool pacienteSeleccionado: false
    property var pacienteActual: null
    property string tipoDetectado: ""
    // propiedad para paciente anonimo
    property bool modoAnonimo: false
    
    // ✅ DATOS DEL MODELO CON PARSING SEGURO
    property var trabajadoresDisponibles: []
    property var tiposProcedimientos: []

    // Agregar propiedades de rol al inicio, después de enfermeriaRoot
    readonly property string usuarioActualRol: {
        if (typeof authModel !== 'undefined' && authModel) {
            return authModel.userRole || ""
        }
        return ""
    }
    readonly property bool esAdministrador: usuarioActualRol === "Administrador"
    readonly property bool esMedico: usuarioActualRol === "Médico" || usuarioActualRol === "MÃ©dico"
    
    ListModel {
        id: resultadosBusquedaPacientesModel
    }
    
    // ✅ FUNCIÓN PARA PARSING SEGURO DE JSON
    function parseJsonSafe(jsonString, defaultValue) {
        try {
            if (!jsonString || jsonString === "" || jsonString === "[]") {
                return defaultValue || []
            }
            
            var parsed = JSON.parse(jsonString)
            return Array.isArray(parsed) ? parsed : defaultValue || []
        } catch (error) {
            console.log("⚠️ Error parsing JSON:", error, "- String:", jsonString)
            return defaultValue || []
        }
    }
    
    // ✅ ACTUALIZAR DATOS DESDE MODELO DE FORMA SEGURA
    function actualizarDatosModelo() {
        if (enfermeriaModel && modeloConectado) {
            try {
                trabajadoresDisponibles = parseJsonSafe(enfermeriaModel.trabajadoresJson, [])
                tiposProcedimientos = parseJsonSafe(enfermeriaModel.tiposProcedimientosJson, [])
                
                console.log("📊 Datos actualizados - Trabajadores:", trabajadoresDisponibles.length, 
                           "Tipos:", tiposProcedimientos.length)
            } catch (error) {
                console.log("❌ Error actualizando datos del modelo:", error)
                trabajadoresDisponibles = []
                tiposProcedimientos = []
            }
        } else {
            trabajadoresDisponibles = []
            tiposProcedimientos = []
        }
    }
    
    // ===============================
    // 2. CONEXIONES MEJORADAS
    // ===============================
    
    Connections {
        target: appController
        function onModelsReady() {
            //console.log("🔗 Modelos listos, conectando EnfermeriaModel...")
            conectarModelo()
        }
    }
    
    // ✅ TIMER SIMPLIFICADO PARA ACTUALIZACIÓN
    Timer {
        id: updateTimer
        interval: 200
        running: false
        repeat: false
        onTriggered: {
            if (modeloConectado && enfermeriaModel) {
                updatePaginatedModel()
            }
        }
    }
    
    // ✅ TIMER PARA PARSING DE DATOS
    Timer {
        id: dataParseTimer
        interval: 100
        running: false
        repeat: false
        onTriggered: actualizarDatosModelo()
    }
    
    // ✅ CONEXIONES CORREGIDAS CON VALIDACIONES
    Connections {
        target: enfermeriaModel
        enabled: enfermeriaModel !== null && modeloConectado

        function onCurrentPagePropertyChanged() {
            console.log("📄 Página actual cambiada:", currentPageEnfermeria)
            updateTimer.restart()
        }
        
        function onTotalPagesPropertyChanged() {
            console.log("📊 Total de páginas cambiado:", totalPagesEnfermeria)
        }
        
        function onTotalRecordsPropertyChanged() {
            console.log("📈 Total de registros cambiado:", totalItemsEnfermeria)
        }
        
        function onProcedimientosRecientesChanged() {

            updateTimer.restart()
        }
        
        function onTiposProcedimientosChanged() {

            dataParseTimer.restart()
        }
        
        function onTrabajadoresChanged() {

            dataParseTimer.restart()
        }
        
        function onProcedimientoCreado(datosJson) {
            console.log("✅ Procedimiento creado:", datosJson)
            limpiarYCerrarDialogo()
            updateTimer.restart()
        }
        
        function onProcedimientoActualizado(datosJson) {
            console.log("✅ Procedimiento actualizado:", datosJson)
            limpiarYCerrarDialogo()
            updateTimer.restart()
        }
        
        function onProcedimientoEliminado(procedimientoId) {
            console.log("🗑️ Procedimiento eliminado:", procedimientoId)
            selectedRowIndex = -1
            updateTimer.restart()
        }
        
        function onPacienteEncontradoPorCedula(pacienteData) {
            console.log("👤 Paciente encontrado:", pacienteData.nombreCompleto)
            autocompletarDatosPaciente(pacienteData)
        }
        
        function onPacienteNoEncontrado(cedula) {
            console.log("❓ Paciente no encontrado:", cedula)
            marcarPacienteNoEncontrado(cedula)
        }
        
        function onEstadoCambiado(nuevoEstado) {
            if (nuevoEstado === "listo") {
                formEnabled = true
            } else if (nuevoEstado === "cargando") {
                formEnabled = false
            }
        }
        
        function onErrorOcurrido(mensaje, codigo) {
            console.log("❌ Error enfermería:", mensaje)
            showNotification("Error", mensaje)
            formEnabled = true
        }
        
        function onOperacionExitosa(mensaje) {
            console.log("✅ Éxito enfermería:", mensaje)
            showNotification("Éxito", mensaje)
            
            // ✅ CERRAR DIÁLOGO AUTOMÁTICAMENTE SOLO SI ES CREACIÓN/ACTUALIZACIÓN
            if (showNewProcedureDialog && (mensaje.includes("creado") || mensaje.includes("actualizado"))) {
                Qt.callLater(function() {
                    limpiarYCerrarDialogo()
                })
            }
        }
    }
    
    // ===============================
    // 3. MODELO CORREGIDO
    // ===============================
    
    ListModel {
        id: procedimientosPaginadosModel
    }
    
    // ===============================
    // 4. LAYOUT PRINCIPAL (SIN CAMBIOS CRÍTICOS)
    // ===============================
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: baseUnit * 4
        spacing: baseUnit * 3
        
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
                
                // HEADER (sin cambios)
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
                        
                        RowLayout {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: baseUnit * 1.5
                            
                            Rectangle {
                                Layout.preferredWidth: baseUnit * 10
                                Layout.preferredHeight: baseUnit * 10
                                color: "transparent"
                                
                                Image {
                                    anchors.centerIn: parent
                                    width: Math.min(baseUnit * 8, parent.width * 0.8)
                                    height: Math.min(baseUnit * 8, parent.height * 0.8)
                                    source: "Resources/iconos/Enfermeria.png"
                                    fillMode: Image.PreserveAspectFit
                                    antialiasing: true
                                }
                            }
                            
                            Label {
                                Layout.alignment: Qt.AlignVCenter
                                text: "Registro de Procedimientos de Enfermería"
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
                        
                        Button {
                            id: newProcedureBtn
                            Layout.preferredHeight: baseUnit * 5
                            Layout.preferredWidth: Math.max(baseUnit * 20, implicitWidth + baseUnit * 2)
                            Layout.alignment: Qt.AlignVCenter
                            enabled: enfermeriaRoot.esAdministrador || enfermeriaRoot.esMedico
                            visible: enfermeriaRoot.esAdministrador || enfermeriaRoot.esMedico
                            background: Rectangle {
                                color: newProcedureBtn.pressed ? primaryColorPressed : 
                                    newProcedureBtn.hovered ? primaryColorHover : primaryColor
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
                                        id: procedureIcon
                                        anchors.centerIn: parent
                                        width: baseUnit * 2.5
                                        height: baseUnit * 2.5
                                        source: "Resources/iconos/Nueva_Consulta.png"
                                        fillMode: Image.PreserveAspectFit
                                        antialiasing: true
                                        
                                        onStatusChanged: {
                                            if (status === Image.Error) {
                                                console.log("Error cargando icono de procedimiento:", source)
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
                                    text: "Nuevo Procedimiento"
                                    color: whiteColor
                                    font.bold: true
                                    font.pixelSize: fontBaseSize
                                    font.family: "Segoe UI, Arial, sans-serif"
                                }
                            }
                            
                            onClicked: {
                                if (!enfermeriaRoot.esAdministrador && !enfermeriaRoot.esMedico) {
                                    mostrarNotificacion("Error", "No tiene permisos para crear procedimientos")
                                    return
                                }
                                
                                isEditMode = false
                                editingIndex = -1
                                showNewProcedureDialog = true
                            }
                            
                            HoverHandler {
                                cursorShape: Qt.PointingHandCursor
                            }
                            ToolTip {
                                visible: parent.hovered
                                text: "Crear nuevo procedimiento de enfermería"
                            }
                        }
                    }
                }
                
                // ✅ FILTROS CORREGIDOS
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
                                text: "Procedimiento:"
                                font.bold: true
                                color: textColor
                                font.pixelSize: fontBaseSize * 0.9
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                            
                            ComboBox {
                                id: filtroProcedimiento
                                Layout.fillWidth: true
                                Layout.preferredHeight: baseUnit * 4

                                model: {
                                    var modelData = ["Todos"]
                                    if (tiposProcedimientos && tiposProcedimientos.length > 0) {
                                        for (var i = 0; i < tiposProcedimientos.length; i++) {
                                            var procedimiento = tiposProcedimientos[i]
                                            var nombre = procedimiento.nombre || ""
                                            if (nombre && nombre !== "Todos" && nombre.trim().length > 0) {
                                                modelData.push(nombre)
                                            }
                                        }
                                    }
                                    return modelData
                                }
                                
                                currentIndex: 0
                                onCurrentIndexChanged: {
                                    
                                    
                                    // ✅ VALIDACIÓN ADICIONAL
                                    if (currentIndex >= 0 && currentIndex < model.length) {
                                        console.log("   - Texto esperado:", model[currentIndex])
                                        console.log("   - Texto actual:", currentText)
                                        
                                        // ✅ DELAY PARA ASEGURAR SINCRONIZACIÓN
                                        aplicarFiltrosTimer.restart()
                                    } else {
                                        console.log("   - ⚠️ Índice fuera de rango")
                                    }
                                }
                                
                                contentItem: Label {
                                    text: filtroProcedimiento.displayText
                                    font.pixelSize: fontBaseSize * 0.8
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    color: textColor
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: baseUnit
                                    elide: Text.ElideRight
                                }
                            }
                            Timer {
                                id: aplicarFiltrosTimer
                                interval: 100  // 100ms delay
                                running: false
                                repeat: false
                                onTriggered: {
                                    console.log("⏰ Timer ejecutado - Aplicando filtros con delay")
                                    aplicarFiltros()
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
                                onCurrentIndexChanged: {
                                    console.log("🎯 TIPO FILTER CHANGED:")
                                    console.log("   - currentIndex:", currentIndex)
                                    console.log("   - currentText:", currentText) 
                                    console.log("   - model:", model)
                                    aplicarFiltros()
                                }
                                
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
                            
                            // ✅ TRIGGER MEJORADO CON TIMER
                            onTextChanged: {
                                filtroTimer.restart()
                            }
                            
                            Timer {
                                id: filtroTimer
                                interval: 500
                                running: false
                                repeat: false
                                onTriggered: aplicarFiltros()
                            }
                            
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
                            
                            onClicked: limpiarFiltros()
                            
                            HoverHandler {
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }
                }
                
                // TABLA (headers sin cambios, contenido corregido)
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
                                    }
                                    
                                    Rectangle {
                                        anchors.right: parent.right
                                        width: 1
                                        height: parent.height
                                        color: lineColor
                                    }
                                }
                                
                                // PROCEDIMIENTO COLUMN
                                Item {
                                    Layout.preferredWidth: parent.width * colProcedimiento
                                    Layout.fillHeight: true
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "PROCEDIMIENTO"
                                        font.bold: true
                                        font.pixelSize: fontBaseSize * 0.85
                                        font.family: "Segoe UI, Arial, sans-serif"
                                        color: textColor
                                    }
                                    
                                    Rectangle {
                                        anchors.right: parent.right
                                        width: 1
                                        height: parent.height
                                        color: lineColor
                                    }
                                }
                                
                                // DETALLES COLUMN (NUEVA)
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
                                    }
                                    
                                    Rectangle {
                                        anchors.right: parent.right
                                        width: 1
                                        height: parent.height
                                        color: lineColor
                                    }
                                }
                                
                                // EJECUTADO POR COLUMN (REUBICADO)
                                Item {
                                    Layout.preferredWidth: parent.width * colEjecutadoPor
                                    Layout.fillHeight: true
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "EJECUTADO POR"
                                        font.bold: true
                                        font.pixelSize: fontBaseSize * 0.85
                                        font.family: "Segoe UI, Arial, sans-serif"
                                        color: textColor
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
                                    }
                                    
                                    Rectangle {
                                        anchors.right: parent.right
                                        width: 1
                                        height: parent.height
                                        color: lineColor
                                    }
                                }
                                
                                // PRECIO COLUMN (CONSOLIDADO)
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
                                    }
                                }
                            }
                        }
                        
                        // CONTENIDO DE LA TABLA MEJORADO CON NUEVA ESTRUCTURA
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            
                            ListView {
                                id: procedimientosListView
                                model: procedimientosPaginadosModel
                                
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
                                                text: model.procedimientoId || "N/A"
                                                color: textColor
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
                                                    font.pixelSize: fontBaseSize * 0.85
                                                    font.family: "Segoe UI, Arial, sans-serif"
                                                    elide: Text.ElideRight
                                                }
                                                
                                                Label {
                                                    width: parent.width - baseUnit
                                                    text: model.cedula ? "C.I: " + model.cedula : "Sin cédula"
                                                    color: textColorLight
                                                    font.pixelSize: fontBaseSize * 0.75
                                                    font.family: "Segoe UI, Arial, sans-serif"
                                                    elide: Text.ElideRight
                                                    visible: model.cedula !== ""
                                                }
                                            }
                                            
                                            Rectangle {
                                                anchors.right: parent.right
                                                width: 1
                                                height: parent.height
                                                color: lineColor
                                            }
                                        }
                                        
                                        // PROCEDIMIENTO COLUMN
                                        Item {
                                            Layout.preferredWidth: parent.width * colProcedimiento
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                anchors.rightMargin: baseUnit
                                                text: model.tipoProcedimiento || "Procedimiento General"
                                                color: primaryColor
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
                                    
                                        // DETALLES COLUMN (ADAPTADA PARA ENFERMERÍA)
                                        Item {
                                            Layout.preferredWidth: parent.width * colDetalles
                                            Layout.fillHeight: true
                                            
                                            Column {
                                                anchors.fill: parent
                                                anchors.margins: baseUnit * 0.5
                                                spacing: baseUnit * 0.2
                                                
                                                Label {
                                                    width: parent.width - baseUnit
                                                    text: {
                                                        var cantidad = model.cantidad || 1
                                                        var info = ""
                                                        
                                                        if (cantidad > 1) {
                                                            info = "Cantidad: " + cantidad + " unidades"
                                                        } else {
                                                            info = "Procedimiento único"
                                                        }
                                                        
                                                        return info
                                                    }
                                                    color: textColor
                                                    font.pixelSize: fontBaseSize * 0.85
                                                    font.family: "Segoe UI, Arial, sans-serif"
                                                    elide: Text.ElideRight
                                                }
                                                
                                                Label {
                                                    width: parent.width - baseUnit
                                                    text: {
                                                        // Mostrar información adicional según el tipo
                                                        var tipo = model.tipo || "Normal"
                                                        var precioUnit = parseFloat(model.precioUnitario || 0)
                                                        
                                                        if (tipo === "Emergencia") {
                                                            return "🚨 Atención urgente"
                                                        } else if (precioUnit > 50) {
                                                            return "Procedimiento especializado"  
                                                        } else {
                                                            return "Atención estándar"
                                                        }
                                                    }
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
                                        
                                        // EJECUTADO POR COLUMN (REUBICADO Y CONSOLIDADO)
                                        Item {
                                            Layout.preferredWidth: parent.width * colEjecutadoPor
                                            Layout.fillHeight: true
                                            
                                            Column {
                                                anchors.fill: parent
                                                anchors.margins: baseUnit * 0.5
                                                
                                                Label {
                                                    width: parent.width
                                                    text: model.trabajadorRealizador || "Sin asignar"
                                                    color: textColor
                                                    font.pixelSize: fontBaseSize * 0.85
                                                    font.family: "Segoe UI, Arial, sans-serif"
                                                    elide: Text.ElideRight
                                                }
                                                
                                                Label {
                                                    width: parent.width
                                                    text: "Por: " + (model.registradoPor || "Sistema")
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
                                        
                                        // TIPO COLUMN
                                        Item {
                                            Layout.preferredWidth: parent.width * colTipo
                                            Layout.fillHeight: true
                                            
                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: baseUnit * 7
                                                height: baseUnit * 2.5
                                                color: (model.tipo || "Normal") === "Emergencia" ? warningColorLight : successColorLight
                                                radius: height / 2
                                                
                                                Label {
                                                    anchors.centerIn: parent
                                                    text: model.tipo || "Normal"
                                                    color: (model.tipo || "Normal") === "Emergencia" ? "#92400E" : "#047857"
                                                    font.pixelSize: fontBaseSize * 0.75
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
                                        
                                        // PRECIO COLUMN (CONSOLIDADO - MUESTRA TOTAL)
                                        Item {
                                            Layout.preferredWidth: parent.width * colPrecio
                                            Layout.fillHeight: true
                                            
                                            Column {
                                                anchors.fill: parent
                                                anchors.margins: baseUnit * 0.5
                                                
                                                Label {
                                                    width: parent.width
                                                    text: "Bs " + (model.precioTotal || model.precioUnitario || "0.00")
                                                    color: model.tipo === "Emergencia" ? "#92400E" : "#047857"
                                                    font.bold: true
                                                    font.pixelSize: fontBaseSize * 0.9
                                                    font.family: "Segoe UI, Arial, sans-serif"
                                                    elide: Text.ElideRight
                                                }
                                                
                                                Label {
                                                    width: parent.width
                                                    text: {
                                                        var cantidad = model.cantidad || 1
                                                        var precioUnit = model.precioUnitario || "0.00"
                                                        return cantidad > 1 ? cantidad + " x Bs " + precioUnit : ""
                                                    }
                                                    color: textColorLight
                                                    font.pixelSize: fontBaseSize * 0.75
                                                    font.family: "Segoe UI, Arial, sans-serif"
                                                    elide: Text.ElideRight
                                                    visible: (model.cantidad || 1) > 1
                                                }
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
                                                font.pixelSize: fontBaseSize * 0.85
                                                font.family: "Segoe UI, Arial, sans-serif"
                                            }
                                        }
                                    }
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            selectedRowIndex = selectedRowIndex === index ? -1 : index
                                        }
                                    }
                                    
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
                                            visible: enfermeriaRoot.esAdministrador || enfermeriaRoot.esMedico
                                            
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
                                            
                                            onClicked: editarProcedimiento(index)
                                            
                                            onHoveredChanged: {
                                                editIcon.opacity = hovered ? 0.7 : 1.0
                                            }
                                        }

                                        Button {
                                            id: deleteButton
                                            width: baseUnit * 3.5
                                            height: baseUnit * 3.5
                                            visible: {
                                                if (enfermeriaRoot.esAdministrador) return true
                                                if (enfermeriaRoot.esMedico) {
                                                    var permisos = verificarPermisosProcedimiento(parseInt(model.procedimientoId))
                                                    return permisos.puede_eliminar
                                                }
                                                return false
                                            }
                                            enabled: visible
                                            
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
                                                var procId = model.procedimientoId
                                                if (procId && procId !== "N/A") {
                                                    procedimientoIdToDelete = procId
                                                    showConfirmDeleteDialog = true
                                                }
                                            }
                                            
                                            onHoveredChanged: {
                                                deleteIcon.opacity = hovered ? 0.7 : 1.0
                                            }
                                            ToolTip {
                                                visible: deleteButton.hovered
                                                text: obtenerTooltipEliminacion(parseInt(model.procedimientoId))
                                                delay: 500
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // ✅ MENSAJE DE "NO HAY DATOS" MEJORADO
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: procedimientosPaginadosModel.count === 0 && modeloConectado
                            spacing: baseUnit * 3
                            
                            Item { Layout.fillHeight: true }
                            
                            ColumnLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: baseUnit * 2
                                
                                Label {
                                    text: "🩹"
                                    font.pixelSize: fontBaseSize * 3
                                    color: "#E5E7EB"
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                
                                Label {
                                    text: modeloConectado ? "No hay procedimientos registrados" : "Conectando con la base de datos..."
                                    color: textColor
                                    font.bold: true
                                    font.pixelSize: fontBaseSize * 1.5
                                    Layout.alignment: Qt.AlignHCenter
                                    font.family: "Segoe UI, Arial, sans-serif"
                                }
                                
                                Label {
                                    text: modeloConectado ? "Registra el primer procedimiento haciendo clic en \"Nuevo Procedimiento\"" : 
                                                           "Espere mientras se cargan los datos..."
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
                
                // ✅ PAGINACIÓN CORREGIDA
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
                            enabled: modeloConectado && currentPageEnfermeria > 0
                            
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
                            
                            onClicked: irAPaginaAnterior()
                        }

                        Label {
                            text:"Página " + (currentPageEnfermeria + 1) + " de " + Math.max(1, totalPagesEnfermeria)+ ""
                            color: textColor
                            font.pixelSize: fontBaseSize * 0.9
                            font.family: "Segoe UI, Arial, sans-serif"
                            font.weight: Font.Medium
                        }

                        Button {
                            Layout.preferredWidth: baseUnit * 11
                            Layout.preferredHeight: baseUnit * 4
                            text: "Siguiente →"
                            enabled: modeloConectado && currentPageEnfermeria < (totalPagesEnfermeria - 1)
                            
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
                            
                            onClicked: irAPaginaSiguiente()
                        }
                    }
                }
            }
        }
    }

    // DIÁLOGO MODAL COMPLETO DE NUEVO/EDITAR PROCEDIMIENTO
    Dialog {
        id: procedureFormDialog
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.95, 800)
        height: Math.min(parent.height * 0.95, 900)
        modal: true
        closePolicy: Popup.NoAutoClose
        visible: showNewProcedureDialog
        
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
        
        // PROPIEDADES DEL DIÁLOGO
        property var procedimientoParaEditar: null
        property int selectedProcedureIndex: -1
        property string procedureType: "Normal"
        property real calculatedUnitPrice: 0.0
        property real calculatedTotalPrice: 0.0
        
        // FUNCIONES DEL DIÁLOGO
        function updatePrices() {
            if (procedureFormDialog.selectedProcedureIndex >= 0 && 
                procedureFormDialog.selectedProcedureIndex < tiposProcedimientos.length) {
                
                try {
                    var procedimiento = tiposProcedimientos[procedureFormDialog.selectedProcedureIndex]
                    
                    console.log("💰 ACTUALIZANDO PRECIOS:")
                    console.log("   - Procedimiento:", procedimiento.nombre)
                    console.log("   - Tipo seleccionado:", procedureFormDialog.procedureType)
                    console.log("   - Precio Normal:", procedimiento.precioNormal)
                    console.log("   - Precio Emergencia:", procedimiento.precioEmergencia)
                    
                    var precioUnitario = 0
                    if (procedureFormDialog.procedureType === "Emergencia") {
                        precioUnitario = parseFloat(procedimiento.precioEmergencia) || 0
                        console.log("   - Usando precio EMERGENCIA:", precioUnitario)
                    } else {
                        precioUnitario = parseFloat(procedimiento.precioNormal) || 0
                        console.log("   - Usando precio NORMAL:", precioUnitario)
                    }
                    
                    var cantidadActual = parseInt(cantidadTextField.text) || 1
                    var precioTotal = precioUnitario * cantidadActual
                    
                    procedureFormDialog.calculatedUnitPrice = precioUnitario
                    procedureFormDialog.calculatedTotalPrice = precioTotal
                    
                    console.log("   - Cantidad:", cantidadActual)
                    console.log("   - Precio Unitario:", precioUnitario)
                    console.log("   - Precio Total:", precioTotal)
                    
                } catch (e) {
                    console.log("❌ Error calculando precios:", e)
                    procedureFormDialog.calculatedUnitPrice = 0.0
                    procedureFormDialog.calculatedTotalPrice = 0.0
                }
            } else {
                console.log("⚠️ No hay procedimiento seleccionado válido")
                procedureFormDialog.calculatedUnitPrice = 0.0
                procedureFormDialog.calculatedTotalPrice = 0.0
            }
        }  
        function loadEditData() {
            if (!isEditMode || !procedureFormDialog.procedimientoParaEditar) {
                console.log("No hay datos para cargar en edición")
                return
            }
            
            var proc = procedureFormDialog.procedimientoParaEditar
            console.log("Cargando datos para edición:", JSON.stringify(proc))
            
            try {
                // ✅ DETECTAR SI ES PROCEDIMIENTO ANÓNIMO
                var esAnonimo = proc.paciente && 
                            (proc.paciente.includes("ANÓNIMO") || 
                                proc.paciente.includes("SIN DATOS") ||
                                proc.pacienteNombre === "ANÓNIMO")
                
                if (esAnonimo) {
                    console.log("🎭 Procedimiento ANÓNIMO detectado - Configurando modo anónimo")
                    modoAnonimo = true
                    modoAnonimoRadio.checked = true
                    modoNormalRadio.checked = false
                    
                    // ✅ NO cargar datos de paciente en modo anónimo
                    campoBusquedaPaciente.text = ""
                    cedulaPaciente.text = ""
                    nombrePaciente.text = ""
                    apellidoPaterno.text = ""
                    apellidoMaterno.text = ""
                    
                    pacienteAutocompletado = false
                    esPacienteExistente = false
                    pacienteSeleccionadoId = -1
                } else {
                    console.log("👤 Procedimiento NORMAL detectado")
                    modoAnonimo = false
                    modoNormalRadio.checked = true
                    modoAnonimoRadio.checked = false
                    
                    // CONFIGURACIÓN PARA PACIENTE NORMAL
                    pacienteAutocompletado = true
                    
                    if (proc.pacienteId && proc.pacienteId > 0) {
                        pacienteSeleccionadoId = proc.pacienteId
                    } else {
                        pacienteSeleccionadoId = -1
                    }
                    esPacienteExistente = true
                    
                    // GESTIÓN DE DATOS DEL PACIENTE NORMAL
                    var tieneCedula = proc.cedula && 
                                    proc.cedula !== "Sin cedula" && 
                                    proc.cedula !== "Sin cédula" &&
                                    proc.cedula !== "NULL" && 
                                    proc.cedula !== null &&
                                    proc.cedula.trim() !== ""
                    
                    if (tieneCedula) {
                        campoBusquedaPaciente.text = proc.cedula || ""
                        cedulaPaciente.text = proc.cedula || ""
                    } else {
                        var nombreCompleto = ""
                        if (proc.pacienteNombre) {
                            nombreCompleto = (proc.pacienteNombre || "") + " " + 
                                        (proc.pacienteApellidoP || "") + " " + 
                                        (proc.pacienteApellidoM || "")
                        } else {
                            nombreCompleto = proc.paciente || ""
                        }
                        campoBusquedaPaciente.text = nombreCompleto.trim()
                        cedulaPaciente.text = ""
                    }
                    
                    // COMPLETAR CAMPOS INDIVIDUALES DEL PACIENTE
                    if (proc.pacienteNombre) {
                        nombrePaciente.text = proc.pacienteNombre || ""
                        apellidoPaterno.text = proc.pacienteApellidoP || ""
                        apellidoMaterno.text = proc.pacienteApellidoM || ""
                    } else {
                        var nombrePartes = (proc.paciente || "").split(" ")
                        nombrePaciente.text = nombrePartes[0] || ""
                        apellidoPaterno.text = nombrePartes[1] || ""
                        apellidoMaterno.text = nombrePartes.slice(2).join(" ") || ""
                    }
                    
                    // CONFIGURAR ESTADOS DEL CAMPO DE BÚSQUEDA
                    campoBusquedaPaciente.pacienteAutocompletado = true
                    campoBusquedaPaciente.pacienteNoEncontrado = false
                    campoBusquedaPaciente.tipoDetectado = ""
                }
                
                // ✅ CARGAR DATOS DEL PROCEDIMIENTO (COMÚN PARA AMBOS MODOS)
                
                // CARGAR TIPO DE PROCEDIMIENTO
                if (proc.tipoProcedimiento) {
                    try {
                        var tiposData = parseJsonSafe(enfermeriaModel.tiposProcedimientosJson, [])
                        for (var i = 0; i < tiposData.length; i++) {
                            var nombre = tiposData[i].nombre || ""
                            if (nombre === proc.tipoProcedimiento) {
                                procedimientoCombo.currentIndex = i + 1
                                procedureFormDialog.selectedProcedureIndex = i
                                break
                            }
                        }
                    } catch(e) {
                        console.log("Error parseando tipos de procedimientos:", e)
                    }
                }
                
                // CARGAR TRABAJADOR
                if (proc.trabajadorRealizador) {
                    try {
                        var trabajadoresData = parseJsonSafe(enfermeriaModel.trabajadoresJson, [])
                        for (var j = 0; j < trabajadoresData.length; j++) {
                            var trabajador = trabajadoresData[j]
                            var nombreTrabajador = trabajador.nombreCompleto || ""
                            if (nombreTrabajador === proc.trabajadorRealizador) {
                                trabajadorCombo.currentIndex = j + 1
                                break
                            }
                        }
                    } catch(e) {
                        console.log("Error cargando trabajador:", e)
                    }
                }
                
                // CARGAR TIPO DE SERVICIO
                if (proc.tipo === "Normal") {
                    normalRadio.checked = true
                    emergenciaRadio.checked = false
                    procedureFormDialog.procedureType = "Normal"
                } else {
                    normalRadio.checked = false
                    emergenciaRadio.checked = true
                    procedureFormDialog.procedureType = "Emergencia"
                }
                
                cantidadTextField.text = (parseInt(proc.cantidad) || 1).toString()
                procedureFormDialog.updatePrices()
                
                console.log("✅ Datos cargados - Modo:", modoAnonimo ? "ANÓNIMO" : "NORMAL")
                
            } catch (e) {
                console.log("Error cargando datos de edición:", e)
            }
        }
        
        onVisibleChanged: {
            if (visible) {
                if (isEditMode && procedureFormDialog.procedimientoParaEditar) {
                    loadEditData()
                } else if (!isEditMode) {
                    limpiarDatosPaciente()
                    procedimientoCombo.currentIndex = 0
                    trabajadorCombo.currentIndex = 0
                    normalRadio.checked = true
                    emergenciaRadio.checked = false
                    cantidadTextField.text = ""
                    descripcionProcedimiento.text = ""
                    procedureFormDialog.selectedProcedureIndex = -1
                    procedureFormDialog.calculatedUnitPrice = 0.0
                    procedureFormDialog.calculatedTotalPrice = 0.0
                    procedureFormDialog.procedimientoParaEditar = null
                    campoBusquedaPaciente.forceActiveFocus()
                }
            }
        }
        
        // HEADER DEL DIÁLOGO
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
                text: isEditMode ? "EDITAR PROCEDIMIENTO" : "NUEVO PROCEDIMIENTO"
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
                    limpiarYCerrarDialogo()
                }
            }
        }
        
        // MENSAJE INFORMATIVO EN MODO EDICIÓN
        Rectangle {
            id: modoEdicionInfo
            anchors.top: dialogHeader.bottom
            anchors.topMargin: baseUnit
            anchors.left: parent.left
            anchors.leftMargin: baseUnit * 3
            anchors.right: parent.right
            anchors.rightMargin: baseUnit * 3
            visible: isEditMode
            height: isEditMode ? baseUnit * 4 : 0
            color: "#F9FAFB"
            border.color: "#E5E7EB"
            border.width: 1
            radius: baseUnit * 0.5
            
            Behavior on height {
                NumberAnimation { duration: 200 }
            }
            
            RowLayout {
                anchors.centerIn: parent
                spacing: baseUnit
                
                Text {
                    text: "i"
                    color: "#6B7280"
                    font.pixelSize: fontBaseSize
                    font.bold: true
                    font.family: "monospace"
                }
                
                Label {
                    text: "🔒 En modo edición solo se pueden modificar los datos del procedimiento, no del paciente"
                    color: "#4B5563"
                    font.pixelSize: fontBaseSize * 0.85
                    font.family: "Segoe UI, Arial, sans-serif"
                }
            }
        }
        
        // CONTENIDO PRINCIPAL DEL DIÁLOGO
        ScrollView {
            id: scrollView
            anchors.top: modoEdicionInfo.visible ? modoEdicionInfo.bottom : dialogHeader.bottom
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
                
                // SECCIÓN DE DATOS DEL PACIENTE CON BÚSQUEDA UNIFICADA
                GroupBox {
                    Layout.fillWidth: true
                    title: modoAnonimo ? "PROCEDIMIENTO ANÓNIMO" : "DATOS DEL PACIENTE"
                    font.bold: true
                    font.pixelSize: fontBaseSize
                    font.family: "Segoe UI, Arial, sans-serif"
                    padding: baseUnit * 1.5
                    
                    background: Rectangle {
                        color: modoAnonimo ? "#FFF8E1" : "#f8f9fa"
                        border.color: modoAnonimo ? "#FFC107" : "#e0e0e0"
                        radius: baseUnit * 0.8
                    }
                    
                    ColumnLayout {
                        width: parent.width
                        spacing: baseUnit * 1.5
                        
                        // SELECTOR DE MODO
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit * 2
                            
                            Label {
                                text: "Tipo de Registro:"
                                font.bold: true
                                color: textColor
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                            
                            RowLayout {
                                spacing: baseUnit * 3
                                
                                RadioButton {
                                    id: modoNormalRadio
                                    text: "Con Datos de Paciente"
                                    checked: !modoAnonimo
                                    font.pixelSize: fontBaseSize * 0.9
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    
                                    onCheckedChanged: {
                                        if (checked) {
                                            modoAnonimo = false
                                            limpiarDatosPaciente()
                                        }
                                    }
                                    
                                    contentItem: RowLayout {
                                        spacing: baseUnit * 0.5
                                        
                                        Rectangle {
                                            Layout.preferredWidth: baseUnit * 2
                                            Layout.preferredHeight: baseUnit * 2
                                            radius: width / 2
                                            border.color: primaryColor
                                            border.width: 2
                                            color: modoNormalRadio.checked ? primaryColor : "transparent"
                                            
                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: parent.width * 0.5
                                                height: parent.height * 0.5
                                                radius: width / 2
                                                color: whiteColor
                                                visible: modoNormalRadio.checked
                                            }
                                        }
                                        
                                        Label {
                                            text: modoNormalRadio.text
                                            font.pixelSize: fontBaseSize * 0.9
                                            font.family: "Segoe UI, Arial, sans-serif"
                                            color: textColor
                                        }
                                    }
                                }
                                
                                RadioButton {
                                    id: modoAnonimoRadio
                                    text: "Procedimiento Anónimo"
                                    checked: modoAnonimo
                                    font.pixelSize: fontBaseSize * 0.9
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    
                                    onCheckedChanged: {
                                        if (checked) {
                                            modoAnonimo = true
                                            limpiarDatosPaciente()
                                        }
                                    }
                                    
                                    contentItem: RowLayout {
                                        spacing: baseUnit * 0.5
                                        
                                        Rectangle {
                                            Layout.preferredWidth: baseUnit * 2
                                            Layout.preferredHeight: baseUnit * 2
                                            radius: width / 2
                                            border.color: "#FF9800"
                                            border.width: 2
                                            color: modoAnonimoRadio.checked ? "#FF9800" : "transparent"
                                            
                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: parent.width * 0.5
                                                height: parent.height * 0.5
                                                radius: width / 2
                                                color: whiteColor
                                                visible: modoAnonimoRadio.checked
                                            }
                                        }
                                        
                                        Label {
                                            text: modoAnonimoRadio.text
                                            font.pixelSize: fontBaseSize * 0.9
                                            font.family: "Segoe UI, Arial, sans-serif"
                                            color: "#F57F17"
                                            font.bold: modoAnonimoRadio.checked
                                        }
                                    }
                                }
                            }
                            
                            Item { Layout.fillWidth: true }
                        }
                        
                        // MENSAJE INFORMATIVO EN MODO ANÓNIMO
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: baseUnit * 3
                            visible: modoAnonimo
                            color: "#FFF3CD"
                            border.color: "#FFEAA7"
                            border.width: 1
                            radius: baseUnit * 0.5
                            
                            RowLayout {
                                anchors.centerIn: parent
                                spacing: baseUnit
                                
                                Label {
                                    text: "ℹ️"
                                    font.pixelSize: fontBaseSize * 1.2
                                }
                                
                                Label {
                                    text: "Se registrará el procedimiento sin asociar datos específicos del paciente"
                                    color: "#856404"
                                    font.pixelSize: fontBaseSize * 0.85
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    font.bold: true
                                }
                            }
                        }
                        
                        // CAMPOS DE PACIENTE (VISIBLES SOLO EN MODO NORMAL)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit * 1.5
                            visible: !modoAnonimo
                            enabled: !modoAnonimo
                            
                            // CAMPO DE BÚSQUEDA UNIFICADO
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: baseUnit
                                
                                Label {
                                    text: "Buscar Paciente:"
                                    font.bold: true
                                    color: textColor
                                    font.family: "Segoe UI, Arial, sans-serif"
                                }
                                
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: baseUnit
                                    
                                    TextField {
                                        id: campoBusquedaPaciente
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: baseUnit * 4
                                        
                                        placeholderText: isEditMode ? "Paciente asignado a este procedimiento" : "Buscar por cédula o nombre del paciente..."
                                        readOnly: isEditMode
                                        enabled: !isEditMode && !modoAnonimo
                                        
                                        property bool pacienteAutocompletado: false
                                        property bool pacienteNoEncontrado: false
                                        property string tipoDetectado: ""
                                        property bool pacienteEncontrado: false
                                        property bool esPacienteNuevo: false
                                        property var resultadosBusqueda: []
                                        property int resultadoSeleccionado: -1
                                        property bool buscandoPaciente: false
                                        
                                        background: Rectangle {
                                            color: {
                                                if (modoAnonimo) return "#F5F5F5"
                                                if (isEditMode) return "#F8F9FA"
                                                if (campoBusquedaPaciente.pacienteAutocompletado) return "#F0F8FF"
                                                if (campoBusquedaPaciente.pacienteNoEncontrado) return "#FEF3C7"
                                                return whiteColor
                                            }
                                            border.color: {
                                                if (modoAnonimo || isEditMode) return "#D1D5DB"
                                                return campoBusquedaPaciente.activeFocus ? primaryColor : borderColor
                                            }
                                            border.width: campoBusquedaPaciente.activeFocus && !modoAnonimo ? 2 : 1
                                            radius: baseUnit * 0.6
                                            
                                            Row {
                                                anchors.right: parent.right
                                                anchors.rightMargin: baseUnit
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: baseUnit * 0.5
                                                visible: !isEditMode && !modoAnonimo
                                                
                                                Text {
                                                    text: {
                                                        if (modoAnonimo) return "🚫"
                                                        if (isEditMode) return "🔒"
                                                        if (campoBusquedaPaciente.pacienteAutocompletado) return "✅"
                                                        if (campoBusquedaPaciente.pacienteNoEncontrado) return "⚠️"
                                                        
                                                        if (campoBusquedaPaciente.tipoDetectado === "cedula") return "🆔"
                                                        if (campoBusquedaPaciente.tipoDetectado === "nombre") return "👤"
                                                        if (campoBusquedaPaciente.tipoDetectado === "mixto") return "🔍"
                                                        
                                                        return campoBusquedaPaciente.text.length > 0 ? "🔍" : ""
                                                    }
                                                    font.pixelSize: fontBaseSize * 1.1
                                                    visible: campoBusquedaPaciente.text.length > 0 || isEditMode || modoAnonimo
                                                }
                                                
                                                Text {
                                                    text: {
                                                        if (modoAnonimo) return "Deshabilitado"
                                                        if (isEditMode) return "Solo lectura"
                                                        if (campoBusquedaPaciente.pacienteAutocompletado) return "Encontrado"
                                                        if (campoBusquedaPaciente.pacienteNoEncontrado) return "Nuevo"
                                                        if (campoBusquedaPaciente.tipoDetectado === "cedula") return "Cédula"
                                                        if (campoBusquedaPaciente.tipoDetectado === "nombre") return "Nombre"
                                                        if (campoBusquedaPaciente.tipoDetectado === "mixto") return "Mixto"
                                                        return ""
                                                    }
                                                    font.pixelSize: fontBaseSize * 0.7
                                                    color: textColorLight
                                                    visible: (campoBusquedaPaciente.text.length > 1 && text.length > 0) || isEditMode || modoAnonimo
                                                }
                                            }
                                        }
                                        
                                        onTextChanged: {
                                            if (isEditMode || modoAnonimo) return
                                            
                                            if (pacienteAutocompletado) {
                                                console.log("Campo autocompletado - no buscar")
                                                return
                                            }
                                            
                                            if (esPacienteExistente && pacienteSeleccionadoId > 0) {
                                                console.log("Paciente existente seleccionado - no realizar búsqueda automática")
                                                return
                                            }
                                            
                                            if (!pacienteAutocompletado) {
                                                pacienteNoEncontrado = false
                                                mostrarResultadosBusqueda = false
                                            }
                                            
                                            if (text.length >= 1) {
                                                tipoDetectado = enfermeriaModel ? enfermeriaModel.detectar_tipo_busqueda(text) : ""
                                            } else {
                                                tipoDetectado = ""
                                            }
                                            
                                            if (text.length >= 2 && !pacienteAutocompletado) {
                                                buscarTimer.restart()
                                            } else if (text.length < 2) {
                                                limpiarResultadosBusqueda()
                                            }
                                            
                                            if (text.length === 0 && !isEditMode && !esPacienteExistente) {
                                                limpiarDatosPaciente()
                                            }
                                        }
                                        
                                        // Resto de eventos del TextField...
                                        Keys.onReturnPressed: {
                                            if (!isEditMode && !modoAnonimo && text.length >= 2) {
                                                buscarPacientesUnificado(text)
                                            }
                                        }
                                        
                                        Keys.onEscapePressed: {
                                            if (!isEditMode && !modoAnonimo) {
                                                limpiarDatosPaciente()
                                            }
                                        }
                                    }
                                    
                                    Button {
                                        text: "Limpiar"
                                        visible: !isEditMode && !modoAnonimo && (campoBusquedaPaciente.pacienteAutocompletado || 
                                                esPacienteExistente ||
                                                nombrePaciente.text.length > 0 ||
                                                campoBusquedaPaciente.text.length > 0)

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
                                    }
                                }
                                
                                // Timer para búsqueda con delay
                                Timer {
                                    id: buscarTimer
                                    interval: 500
                                    running: false
                                    repeat: false
                                    onTriggered: {
                                        if (modoAnonimo) return
                                        var termino = campoBusquedaPaciente.text.trim()
                                        if (termino.length >= 2) {
                                            buscarPacientesUnificado(termino)
                                        }
                                    }
                                }
                                
                                // PANEL DE RESULTADOS (igual que antes, pero con visible: !modoAnonimo)
                                Rectangle {
                                    id: panelResultadosPacientes
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: mostrarResultadosBusqueda && !isEditMode ? Math.min(230, resultadosBusquedaPacientesModel.count * 55 + 60) : 0
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
                                        
                                    }
                                }
                            }
                            
                            // CAMPOS INDIVIDUALES DE PACIENTE
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
                                    readOnly: campoBusquedaPaciente.pacienteAutocompletado || isEditMode
                                    enabled: !modoAnonimo
                                    font.pixelSize: fontBaseSize
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    
                                    background: Rectangle {
                                        color: (campoBusquedaPaciente.pacienteAutocompletado || isEditMode || modoAnonimo) ? "#F8F9FA" : whiteColor
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
                                    readOnly: campoBusquedaPaciente.pacienteAutocompletado || isEditMode
                                    enabled: !modoAnonimo
                                    font.pixelSize: fontBaseSize
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    property bool esCampoNuevoPaciente: !campoBusquedaPaciente.pacienteAutocompletado && 
                                        campoBusquedaPaciente.pacienteNoEncontrado &&
                                        !isEditMode && !modoAnonimo
                                    background: Rectangle {
                                        color: {
                                            if (modoAnonimo || campoBusquedaPaciente.pacienteAutocompletado || isEditMode) return "#F8F9FA"
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
                                    readOnly: campoBusquedaPaciente.pacienteAutocompletado || isEditMode
                                    enabled: !modoAnonimo
                                    font.pixelSize: fontBaseSize
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    
                                    property bool esCampoNuevoPaciente: !campoBusquedaPaciente.pacienteAutocompletado && 
                                        campoBusquedaPaciente.pacienteNoEncontrado &&
                                        !isEditMode && !modoAnonimo
                                    
                                    background: Rectangle {
                                        color: {
                                            if (modoAnonimo || campoBusquedaPaciente.pacienteAutocompletado || isEditMode) return "#F8F9FA"
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
                                    readOnly: campoBusquedaPaciente.pacienteAutocompletado || isEditMode
                                    enabled: !modoAnonimo
                                    font.pixelSize: fontBaseSize
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    
                                    property bool esCampoNuevoPaciente: !campoBusquedaPaciente.pacienteAutocompletado && 
                                        campoBusquedaPaciente.pacienteNoEncontrado &&
                                        !isEditMode && !modoAnonimo
                                    
                                    background: Rectangle {
                                        color: {
                                            if (modoAnonimo || campoBusquedaPaciente.pacienteAutocompletado || isEditMode) return "#F8F9FA"
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
                }
                
                // RESTO DE GROUPBOXES (INFORMACIÓN DEL PROCEDIMIENTO, PRECIO, ETC.) - SIN CAMBIOS
                GroupBox {
                    Layout.fillWidth: true
                    title: "INFORMACIÓN DEL PROCEDIMIENTO"
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
                                text: "Procedimiento:"
                                font.bold: true
                                Layout.preferredWidth: baseUnit * 15
                                color: textColor
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                            
                            ComboBox {
                                id: procedimientoCombo
                                Layout.fillWidth: true
                                font.pixelSize: fontBaseSize
                                font.family: "Segoe UI, Arial, sans-serif"
                                model: {
                                    var list = ["Seleccionar procedimiento..."]
                                    if (tiposProcedimientos && tiposProcedimientos.length > 0) {
                                        for (var i = 0; i < tiposProcedimientos.length; i++) {
                                            var nombre = tiposProcedimientos[i].nombre || ""
                                            if (nombre) {
                                                list.push(nombre)
                                            }
                                        }
                                    }
                                    return list
                                }
                                
                                onCurrentIndexChanged: {
                                    if (currentIndex > 0 && tiposProcedimientos.length > 0) {
                                        try {
                                            if (currentIndex - 1 < tiposProcedimientos.length) {
                                                procedureFormDialog.selectedProcedureIndex = currentIndex - 1
                                                descripcionProcedimiento.text = tiposProcedimientos[procedureFormDialog.selectedProcedureIndex].descripcion || ""
                                            }
                                        } catch (e) {
                                            console.log("Error en cambio de procedimiento:", e)
                                        }
                                    } else {
                                        procedureFormDialog.selectedProcedureIndex = -1
                                        descripcionProcedimiento.text = ""
                                    }
                                    procedureFormDialog.updatePrices()
                                }
                                
                                contentItem: Label {
                                    text: procedimientoCombo.displayText
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
                            visible: descripcionProcedimiento.text !== ""
                            
                            Label {
                                text: "Descripción:"
                                font.bold: true
                                Layout.preferredWidth: baseUnit * 15
                                color: textColor
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                            
                            Label {
                                id: descripcionProcedimiento
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                color: textColorLight
                                font.italic: true
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                        }
                        
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit * 2
                            
                            Label {
                                text: "Realizado por:"
                                font.bold: true
                                Layout.preferredWidth: baseUnit * 15
                                color: textColor
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                            
                            ComboBox {
                                id: trabajadorCombo
                                Layout.fillWidth: true
                                font.pixelSize: fontBaseSize
                                font.family: "Segoe UI, Arial, sans-serif"
                                model: {
                                    var modelData = ["Seleccionar trabajador..."]
                                    if (trabajadoresDisponibles && trabajadoresDisponibles.length > 0) {
                                        for (var i = 0; i < trabajadoresDisponibles.length; i++) {
                                            var trabajador = trabajadoresDisponibles[i]
                                            var nombre = trabajador.nombreCompleto || ""
                                            if (nombre) {
                                                modelData.push(nombre)
                                            }
                                        }
                                    }
                                    return modelData
                                }
                                
                                contentItem: Label {
                                    text: trabajadorCombo.displayText
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
                                text: "Tipo de Servicio:"
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
                                            procedureFormDialog.procedureType = "Normal"
                                            procedureFormDialog.updatePrices()
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
                                            procedureFormDialog.procedureType = "Emergencia"
                                            procedureFormDialog.updatePrices()
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
                        
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit * 2
                            
                            Label {
                                text: "Cantidad:"
                                font.bold: true
                                Layout.preferredWidth: baseUnit * 15
                                color: textColor
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                            
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: baseUnit
                                
                                TextField {
                                    id: cantidadTextField
                                    Layout.preferredWidth: baseUnit * 12
                                    Layout.preferredHeight: baseUnit * 4
                                    placeholderText: "0"
                                    inputMethodHints: Qt.ImhDigitsOnly
                                    validator: IntValidator { bottom: 1; top: 50 }
                                    font.pixelSize: fontBaseSize
                                    font.bold: true
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    
                                    background: Rectangle {
                                        color: whiteColor
                                        border.color: cantidadTextField.activeFocus ? primaryColor : borderColor
                                        border.width: cantidadTextField.activeFocus ? 2 : 1
                                        radius: baseUnit * 0.6
                                    }
                                    
                                    onTextChanged: {
                                        procedureFormDialog.updatePrices()
                                    }
                                    
                                    onFocusChanged: {
                                        if (!focus) {
                                            var num = parseInt(text)
                                            if (isNaN(num) || num < 1) {
                                                text = "1"
                                            } else if (num > 50) {
                                                text = "50"
                                            }
                                        }
                                    }
                                    
                                    padding: baseUnit
                                    horizontalAlignment: Text.AlignHCenter
                                }
                                
                                Label {
                                    text: {
                                        var cantidad = parseInt(cantidadTextField.text) || 1
                                        return cantidad === 1 ? "procedimiento" : "procedimientos"
                                    }
                                    color: textColor
                                    font.pixelSize: fontBaseSize * 0.9
                                    font.family: "Segoe UI, Arial, sans-serif"
                                }
                                
                                Item { Layout.fillWidth: true }
                            }
                        }
                    }
                }
                
                // SECCIÓN DE INFORMACIÓN DE PRECIO
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
                            text: "Precio Unitario:"
                            font.bold: true
                            color: textColor
                            font.family: "Segoe UI, Arial, sans-serif"
                        }
                        
                        Label {
                            text: procedureFormDialog.selectedProcedureIndex >= 0 ? 
                                "Bs " + procedureFormDialog.calculatedUnitPrice.toFixed(2) : "Seleccione procedimiento"
                            font.bold: true
                            font.pixelSize: fontBaseSize
                            font.family: "Segoe UI, Arial, sans-serif"
                            color: procedureFormDialog.procedureType === "Emergencia" ? "#92400E" : "#047857"
                            padding: baseUnit
                            background: Rectangle {
                                color: procedureFormDialog.procedureType === "Emergencia" ? warningColorLight : successColorLight
                                radius: baseUnit * 0.8
                            }
                        }
                        
                        Label {
                            text: "Cantidad:"
                            font.bold: true
                            color: textColor
                            font.family: "Segoe UI, Arial, sans-serif"
                        }
                        
                        Label {
                            text: {
                                var cantidad = parseInt(cantidadTextField.text) || 1
                                return cantidad + " procedimiento" + (cantidad > 1 ? "s" : "")
                            }
                            font.bold: true
                            color: textColor
                            font.family: "Segoe UI, Arial, sans-serif"
                        }
                        
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.columnSpan: 2
                            Layout.preferredHeight: 1
                            color: borderColor
                        }
                        
                        Label {
                            text: "Total a Pagar:"
                            font.bold: true
                            font.pixelSize: fontBaseSize * 1.2
                            color: textColor
                            font.family: "Segoe UI, Arial, sans-serif"
                        }
                        
                        Label {
                            text: procedureFormDialog.selectedProcedureIndex >= 0 ? 
                                "Bs " + procedureFormDialog.calculatedTotalPrice.toFixed(2) : "Bs 0.00"
                            font.bold: true
                            font.pixelSize: fontBaseSize * 1.4
                            font.family: "Segoe UI, Arial, sans-serif"
                            color: procedureFormDialog.procedureType === "Emergencia" ? "#92400E" : "#047857"
                            padding: baseUnit * 1.5
                            background: Rectangle {
                                color: procedureFormDialog.procedureType === "Emergencia" ? warningColorLight : successColorLight
                                radius: baseUnit * 0.8
                                border.color: procedureFormDialog.procedureType === "Emergencia" ? warningColor : successColor
                                border.width: 2
                            }
                        }
                        
                        Label {
                            Layout.columnSpan: 2
                            Layout.fillWidth: true
                            text: {
                                if (procedureFormDialog.selectedProcedureIndex >= 0) {
                                    var cantidad = parseInt(cantidadTextField.text) || 1
                                    return "(" + procedureFormDialog.calculatedUnitPrice.toFixed(2) + " × " + 
                                        cantidad + " = " + procedureFormDialog.calculatedTotalPrice.toFixed(2) + ")"
                                }
                                return ""
                            }
                            color: textColorLight
                            font.pixelSize: fontBaseSize * 0.8
                            font.family: "Segoe UI, Arial, sans-serif"
                            horizontalAlignment: Text.AlignHCenter
                            visible: procedureFormDialog.selectedProcedureIndex >= 0
                        }
                    }
                }
            }
        }
        
        // BOTONES DEL DIÁLOGO
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
                    limpiarYCerrarDialogo()
                }
            }
            
            Button {
                text: isEditMode ? "Actualizar" : "Guardar"
                enabled: {
                    var tieneProcedimiento = procedureFormDialog.selectedProcedureIndex >= 0
                    var tieneTrabajador = trabajadorCombo.currentIndex > 0
                    var cantidadValida = (parseInt(cantidadTextField.text) || 0) > 0
                    
                    // ✅ NUEVA LÓGICA: Si es modo anónimo, NO validar datos de paciente
                    var validacionPaciente = true
                    if (!modoAnonimo) {
                        var tieneNombre = nombrePaciente.text.length >= 2
                        var apellidoPValido = apellidoPaterno.text.length >= 2
                        validacionPaciente = tieneNombre && apellidoPValido
                    }
                    
                    return tieneProcedimiento && tieneTrabajador && cantidadValida && validacionPaciente && enfermeriaModel && formEnabled
                }
                Layout.preferredHeight: baseUnit * 4
                
                background: Rectangle {
                    color: {
                        if (!parent.enabled) return "#bdc3c7"
                        if (!formEnabled) return "#95a5a6"
                        return primaryColor
                    }
                    radius: baseUnit
                }
                
                contentItem: Label {
                    text: !formEnabled ? "Guardando..." : parent.text
                    color: whiteColor
                    font.bold: true
                    font.pixelSize: fontBaseSize * 0.9
                    font.family: "Segoe UI, Arial, sans-serif"
                    horizontalAlignment: Text.AlignHCenter
                }
                
                onClicked: {
                    if (formEnabled) {
                        guardarProcedimiento()
                    }
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
                        text: "¿Estás seguro de eliminar este procedimiento?"
                        font.pixelSize: fontBaseSize * 1.1
                        font.bold: true
                        color: textColor
                        Layout.alignment: Qt.AlignHCenter
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        font.family: "Segoe UI, Arial, sans-serif"
                    }
                    
                    Label {
                        text: "Esta acción no se puede deshacer y el registro del procedimiento se eliminará permanentemente."
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
                                procedimientoIdToDelete = ""
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
                                console.log("🗑️ Confirmando eliminación de procedimiento...")
                                
                                var procedimientoId = parseInt(procedimientoIdToDelete)
                                
                                showConfirmDeleteDialog = false
                                procedimientoIdToDelete = ""
                                var exitoso = eliminarProcedimiento(procedimientoId)
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

    // ===============================
    // 6. FUNCIONES CORREGIDAS
    // ===============================
    
    // GRUPO A - INICIALIZACIÓN MEJORADA
    
    Component.onCompleted: {
        console.log("🩹 Módulo Enfermería iniciado")
        conectarModelo()
    }
    
    function conectarModelo() {
        if (typeof appController !== 'undefined' && appController.enfermeria_model_instance) {
            enfermeriaModel = appController.enfermeria_model_instance
            
            if (enfermeriaModel) {
                modeloConectado = true
                //console.log("✅ EnfermeriaModel conectado exitosamente")
                initializarModelo()
                return true
            }
        }
        
        // Retry timer si no se conecta inmediatamente
        if (!modeloConectado) {
            retryTimer.start()
        }
        return false
    }
    
    Timer {
        id: retryTimer
        interval: 1000
        running: false
        repeat: false
        onTriggered: {
            if (!modeloConectado) {
                console.log("🔄 Reintentando conectar EnfermeriaModel...")
                conectarModelo()
            }
        }
    }
    
    function initializarModelo() {
        if (!enfermeriaModel || !modeloConectado) {
            console.log("❌ Modelo no disponible para inicialización")
            return
        }
        
        try {
            // Configurar elementos por página
            var elementosPorPagina = 8
            if (enfermeriaModel.itemsPerPageProperty !== elementosPorPagina) {
                enfermeriaModel.itemsPerPageProperty = elementosPorPagina
            }
            
            // Cargar datos iniciales
            enfermeriaModel.actualizar_procedimientos()
            enfermeriaModel.actualizar_tipos_procedimientos()
            enfermeriaModel.actualizar_trabajadores_enfermeria()
            
            // Actualizar datos del modelo
            actualizarDatosModelo()
            
            // Aplicar filtros iniciales
            aplicarFiltros()
            
            //console.log("✅ Modelo inicializado correctamente")
        } catch (error) {
            console.log("❌ Error inicializando modelo:", error)
        }
    }
    
    // ✅ FUNCIÓN CRÍTICA: updatePaginatedModel CORREGIDA
    function updatePaginatedModel() {
        if (!enfermeriaModel || !modeloConectado) {
            console.log("❌ Modelo no disponible para actualización")
            return
        }
        
        try {
            // Limpiar modelo actual
            procedimientosPaginadosModel.clear()
            
            // Obtener datos actuales del modelo
            var procedimientos = enfermeriaModel.procedimientos || []
            
            if (procedimientos && procedimientos.length > 0) {
                for (var i = 0; i < procedimientos.length; i++) {
                    var proc = procedimientos[i]
                    
                    // Validar y agregar datos defensivamente
                    procedimientosPaginadosModel.append({
                        procedimientoId: proc.procedimientoId || "N/A",
                        paciente: proc.paciente || "Sin nombre",
                        cedula: proc.cedula || "",
                        tipoProcedimiento: proc.tipoProcedimiento || "Procedimiento General",
                        descripcion: proc.descripcion || "",
                        cantidad: proc.cantidad || 1,
                        tipo: proc.tipo || "Normal",
                        precioUnitario: proc.precioUnitario || "0.00",
                        precioTotal: proc.precioTotal || "0.00",
                        fecha: proc.fecha || "Sin fecha",
                        trabajadorRealizador: proc.trabajadorRealizador || "Sin asignar",
                        registradoPor: proc.registradoPor || "Sistema",
                        pacienteNombre: proc.pacienteNombre || "",
                        pacienteApellidoP: proc.pacienteApellidoP || "",
                        pacienteApellidoM: proc.pacienteApellidoM || ""
                    })
                }
            } else {
                console.log("ℹ️ No hay procedimientos disponibles")
            }
        } catch (error) {
            console.log("❌ Error actualizando modelo:", error)
        }
    }
    
    // GRUPO B - PAGINACIÓN CORREGIDA
    
    function irAPaginaAnterior() {
        if (enfermeriaModel && modeloConectado && currentPageEnfermeria > 0) {
            console.log("⬅️ Navegando a página anterior:", currentPageEnfermeria - 1)
            
            var filtros = construirFiltrosActuales()
            enfermeriaModel.obtener_procedimientos_paginados(currentPageEnfermeria - 1, 8, filtros)
        }
    }

    function irAPaginaSiguiente() {
        if (enfermeriaModel && modeloConectado && currentPageEnfermeria < (totalPagesEnfermeria - 1)) {
            console.log("➡️ Navegando a página siguiente:", currentPageEnfermeria + 1)
            
            var filtros = construirFiltrosActuales()
            enfermeriaModel.obtener_procedimientos_paginados(currentPageEnfermeria + 1, 8, filtros)
        }
    }
    
    // GRUPO C - FILTROS ESTANDARIZADOS
    
    function aplicarFiltros() {
        if (!enfermeriaModel || !modeloConectado) {
            console.log("❌ Modelo no disponible para aplicar filtros")
            return
        }

        //console.log("🔍 Aplicando filtros...")
        

        
        try {
            // ✅ CONSTRUIR FILTROS CORRECTAMENTE (como en consultas)
            var filtros = construirFiltrosActuales()
            console.log("📋 Filtros construidos:", JSON.stringify(filtros))
            
            // Resetear a primera página cuando cambien filtros
            // currentPageEnfermeria = 0  // Esta propiedad es readonly, se maneja en el modelo
            
            // ✅ APLICAR FILTROS CON NOMBRES ESTANDARIZADOS
            enfermeriaModel.aplicar_filtros_y_recargar(
                filtros.busqueda || "",
                filtros.tipo_procedimiento || "",
                filtros.tipo || "",
                filtros.fecha_desde || "",
                filtros.fecha_hasta || ""
            )
        } catch (error) {
            console.log("❌ Error aplicando filtros:", error)
        }
    }   


    function construirFiltrosActuales() {
        var filtros = {}
        
        // Filtro por búsqueda
        if (campoBusqueda.text.trim().length >= 2) {
            filtros.busqueda = campoBusqueda.text.trim()
        }
        
        // ✅ FILTRO POR TIPO DE PROCEDIMIENTO - VALIDACIÓN MEJORADA
        if (filtroProcedimiento.currentIndex > 0) {
            var textoActual = filtroProcedimiento.currentText
            var modeloActual = filtroProcedimiento.model
            
            console.log("🔍 VALIDANDO PROCEDIMIENTO:")
            console.log("   - currentIndex:", filtroProcedimiento.currentIndex)
            console.log("   - currentText:", textoActual)
            console.log("   - modelo length:", modeloActual ? modeloActual.length : 0)
            
            // Validar que el texto no sea "Todos" y que el índice sea válido
            if (textoActual && 
                textoActual !== "Todos" && 
                textoActual.trim().length > 0 &&
                filtroProcedimiento.currentIndex < modeloActual.length) {
                
                filtros.tipo_procedimiento = textoActual
                console.log("✅ Procedimiento válido aplicado:", textoActual)
            } else {
                console.log("⚠️ Procedimiento inválido ignorado:", textoActual)
            }
        }
        
        // ✅ FILTRO POR TIPO - MAPEO CORRECTO DE ÍNDICES
        if (filtroTipo.currentIndex > 0) {
            if (filtroTipo.currentIndex === 1) {
                filtros.tipo = "Normal"
            } else if (filtroTipo.currentIndex === 2) {
                filtros.tipo = "Emergencia"
            }
            
            console.log("🎯 TIPO MAPEO:")
            console.log("   - currentIndex:", filtroTipo.currentIndex)
            console.log("   - Valor mapeado:", filtros.tipo)
        }
        
        // ✅ CORRECCIÓN: Usar currentIndex en lugar de currentText para fechas
        if (filtroFecha && filtroFecha.currentIndex > 0) {
            var hoy = new Date()
            var fechaDesde, fechaHasta
            
            // ✅ USAR ÍNDICE EN LUGAR DE TEXTO
            switch(filtroFecha.currentIndex) {
                case 1: // "Hoy"
                    fechaDesde = new Date(hoy.getFullYear(), hoy.getMonth(), hoy.getDate())
                    fechaHasta = new Date(hoy.getFullYear(), hoy.getMonth(), hoy.getDate())
                    console.log("✅ Aplicando filtro: Hoy")
                    break
                case 2: // "Esta Semana"
                    var primerDiaSemana = new Date(hoy)
                    primerDiaSemana.setDate(hoy.getDate() - hoy.getDay() + 1)
                    fechaDesde = new Date(primerDiaSemana.getFullYear(), primerDiaSemana.getMonth(), primerDiaSemana.getDate())
                    fechaHasta = new Date(hoy.getFullYear(), hoy.getMonth(), hoy.getDate())
                    console.log("✅ Aplicando filtro: Esta Semana")
                    break
                case 3: // "Este Mes"
                    fechaDesde = new Date(hoy.getFullYear(), hoy.getMonth(), 1)
                    fechaHasta = new Date(hoy.getFullYear(), hoy.getMonth() + 1, 0)
                    console.log("✅ Aplicando filtro: Este Mes")
                    break
                default:
                    console.log("⚠️ Índice de fecha no reconocido:", filtroFecha.currentIndex)
                    return filtros // ✅ RETORNAR SIN FECHAS SI HAY ERROR
            }
            
            // ✅ VALIDAR QUE LAS FECHAS EXISTAN ANTES DE CONVERTIR
            if (fechaDesde && fechaHasta) {
                try {
                    filtros.fecha_desde = fechaDesde.toISOString().split('T')[0]
                    filtros.fecha_hasta = fechaHasta.toISOString().split('T')[0]
                    console.log("📅 Fechas aplicadas:", filtros.fecha_desde, "al", filtros.fecha_hasta)
                } catch (error) {
                    console.log("❌ Error convirtiendo fechas:", error)
                    // No agregar fechas si hay error
                }
            }
        }
        
        return filtros
    }
    
    function limpiarFiltros() {
        console.log("🧹 Limpiando todos los filtros...")
        
        try {
            // ✅ RESETEAR TODOS LOS COMBOS A ÍNDICE 0
            if (filtroFecha) {
                filtroFecha.currentIndex = 0
            }
            if (filtroProcedimiento) {
                filtroProcedimiento.currentIndex = 0  
            }
            if (filtroTipo) {
                filtroTipo.currentIndex = 0
            }
            if (campoBusqueda) {
                campoBusqueda.text = ""
            }
            
            // Aplicar filtros (ahora todos estarán vacíos/por defecto)
            aplicarFiltros()
            
            showNotification("Info", "Filtros restablecidos")
            console.log("✅ Filtros limpiados correctamente")
            
        } catch (error) {
            console.log("❌ Error limpiando filtros:", error)
        }
    }
    
    // GRUPO D - BÚSQUEDA DE PACIENTES MEJORADA
    
    function buscarPacientePorCedula(cedula) {
        if (!enfermeriaModel || cedula.length < 5) return
        console.log("🔍 Búsqueda inteligente de paciente:", cedula)
        campoBusquedaPaciente.pacienteNoEncontrado = false
        var pacienteData = enfermeriaModel.buscar_paciente_por_cedula(cedula.trim())
        if(pacienteData && pacienteData.id){
            autocompletarDatosPaciente(pacienteData)
        } else {
            console.log("❓ Paciente no encontrado en búsqueda:", cedula)
            marcarPacienteNoEncontrado(cedula)
        }
    }

    
    function autocompletarDatosPaciente(paciente) {
        cedulaPaciente.text = paciente.cedula || ""
        nombrePaciente.text = paciente.nombre || ""
        apellidoPaterno.text = paciente.apellidoPaterno || ""
        apellidoMaterno.text = paciente.apellidoMaterno || ""
        campoBusquedaPaciente.text = paciente.cedula || ""
        
        campoBusquedaPaciente.pacienteAutocompletado = true
        campoBusquedaPaciente.pacienteNoEncontrado = false
        
        console.log("✅ Paciente encontrado y autocompletado:", paciente.cedula || "")
    }
    function autocompletarDatosPacientePorNombre(paciente) {
        cedulaPaciente.text = paciente.cedula || ""
        nombrePaciente.text = paciente.nombre || ""
        apellidoPaterno.text = paciente.apellidoPaterno || ""
        apellidoMaterno.text = paciente.apellidoMaterno || ""
        // ✅ ACTUALIZAR CAMPO DE BÚSQUEDA CON NOMBRE COMPLETO
        campoBusquedaPaciente.text = paciente.nombreCompleto || ""
        
        campoBusquedaPaciente.pacienteAutocompletado = true
        campoBusquedaPaciente.pacienteNoEncontrado = false
        
        console.log("✅ Paciente encontrado por nombre:", paciente.nombreCompleto || "")
    }
    
    function marcarPacienteNoEncontrado(cedula) {
        // ✅ SOLO cuando realmente NO se encuentra
        campoBusquedaPaciente.pacienteNoEncontrado = true
        campoBusquedaPaciente.pacienteAutocompletado = false
        
        campoBusquedaPaciente.text = cedula
        nombrePaciente.text = ""
        apellidoPaterno.text = ""
        apellidoMaterno.text = ""
        
        console.log("❌ Paciente NO encontrado con cédula:", cedula)
    }
    function marcarPacienteNoEncontradoPorNombre(nombreCompleto) {
        campoBusquedaPaciente.pacienteNoEncontrado = true
        campoBusquedaPaciente.pacienteAutocompletado = false
        
        var palabras = nombreCompleto.trim().split(' ')
        nombrePaciente.text = palabras[0] || ""
        apellidoPaterno.text = palabras[1] || ""
        apellidoMaterno.text = palabras.slice(2).join(' ')
        campoBusquedaPaciente.text = ""
        
        console.log("❌ Paciente NO encontrado por nombre. Habilitando modo crear nuevo.")
    }
    
    // GRUPO E - OPERACIONES CRUD MEJORADAS
    
    function guardarProcedimiento() {
        try {
            console.log("🎯 Iniciando guardado - Modo:", isEditMode ? "EDITAR" : "CREAR")
            
            // Desactivar formulario mientras se procesa
            formEnabled = false
            
            if (isEditMode && editingIndex >= 0) {
                actualizarProcedimiento()
            } else {
                crearNuevoProcedimiento()
            }
            
        } catch (error) {
            console.log("❌ Error en coordinador de guardado:", error.message)
            formEnabled = true
            showNotification("Error", "Error procesando solicitud: " + error.message)
        }
    }
    function crearNuevoProcedimiento() {
        try {
            console.log("💉 === INICIANDO CREACIÓN DE NUEVO PROCEDIMIENTO ===")
            console.log("🎭 Modo anónimo activo:", modoAnonimo)
            
            // Validar formulario
            if (!validarFormularioProcedimiento()) {
                formEnabled = true
                return
            }
            
            // Obtener datos del formulario
            var datosProcedimiento = obtenerDatosFormulario()
            console.log("📋 Datos del procedimiento:", JSON.stringify(datosProcedimiento))
            
            // Crear procedimiento en el backend
            console.log("💾 Enviando al modelo...")
            var resultado = enfermeriaModel.crear_procedimiento(datosProcedimiento)
            
            // Procesar resultado
            procesarResultadoCreacion(resultado)
            
        } catch (error) {
            console.log("⚠️ Error creando procedimiento:", error.message)
            formEnabled = true
            showNotification("Error", error.message)
        }
    }
    function actualizarProcedimiento() {
        try {
            console.log("📝 === INICIANDO ACTUALIZACIÓN DE PROCEDIMIENTO ===")
            
            // Validar formulario
            if (!validarFormularioProcedimiento()) {
                formEnabled = true
                return
            }
            
            // Validar que estamos en modo edición
            if (!procedureFormDialog.procedimientoParaEditar) {
                formEnabled = true
                showNotification("Error", "No hay procedimiento seleccionado para editar")
                return
            }
            
            var procedimientoId = parseInt(procedureFormDialog.procedimientoParaEditar.procedimientoId)
            console.log("   - Procedimiento ID a actualizar:", procedimientoId)
            
            // Obtener datos del formulario
            var datosProcedimiento = obtenerDatosFormulario()
            
            console.log("📝 Actualizando procedimiento ID:", procedimientoId)
            console.log("   - Procedimiento tipo ID:", datosProcedimiento.idProcedimiento)
            console.log("   - Tipo servicio:", datosProcedimiento.tipo)
            console.log("   - Trabajador ID:", datosProcedimiento.idTrabajador)
            console.log("   - Cantidad:", datosProcedimiento.cantidad)
            
            // Actualizar en el backend
            var resultado = enfermeriaModel.actualizar_procedimiento(datosProcedimiento, procedimientoId)
            
            // Procesar resultado
            procesarResultadoActualizacion(resultado)
            
        } catch (error) {
            console.log("❌ Error actualizando procedimiento:", error.message)
            formEnabled = true
            showNotification("Error", error.message)
        }
    }
    function validarFormularioProcedimiento() {
        console.log("✅ Validando formulario...")
        
        // Validar procedimiento seleccionado (siempre obligatorio)
        if (procedureFormDialog.selectedProcedureIndex < 0) {
            showNotification("Error", "Debe seleccionar un tipo de procedimiento")
            return false
        }
        
        // Validar trabajador (siempre obligatorio)
        if (trabajadorCombo.currentIndex <= 0) {
            showNotification("Error", "Debe seleccionar un trabajador")
            return false
        }
        
        // Validar cantidad (siempre obligatoria)
        if (parseInt(cantidadTextField.text) <= 0) {
            showNotification("Error", "La cantidad debe ser mayor a 0")
            return false
        }
        
        // ✅ NUEVA LÓGICA: Validar datos del paciente SOLO si NO es modo anónimo
        if (!modoAnonimo) {
            // Validar nombre del paciente
            if (nombrePaciente.text.length < 2) {
                showNotification("Error", "Nombre del paciente es obligatorio")
                return false
            }
            
            // Validar apellido paterno para pacientes nuevos
            if (campoBusquedaPaciente.pacienteNoEncontrado) {
                if (apellidoPaterno.text.length < 2) {
                    showNotification("Error", "Apellido paterno es obligatorio para nuevo paciente")
                    return false
                }
            }
            
            console.log("✅ Validación NORMAL exitosa")
        } else {
            console.log("✅ Validación ANÓNIMO exitosa")
        }
        
        console.log("✅ Formulario válido")
        return true
    }

    function obtenerDatosFormulario() {
        try {
            var trabajadorId = 0
            if (trabajadorCombo.currentIndex > 0 && trabajadoresDisponibles.length > 0) {
                if (trabajadorCombo.currentIndex - 1 < trabajadoresDisponibles.length) {
                    trabajadorId = trabajadoresDisponibles[trabajadorCombo.currentIndex - 1].id
                }
            }
            
            // ✅ CORRECCIÓN CRÍTICA: Obtener el ID REAL del procedimiento
            var procedimientoId = 0
            if (procedureFormDialog.selectedProcedureIndex >= 0 && 
                procedureFormDialog.selectedProcedureIndex < tiposProcedimientos.length) {
                
                var procedimientoSeleccionado = tiposProcedimientos[procedureFormDialog.selectedProcedureIndex]
                procedimientoId = procedimientoSeleccionado.id || 0
                
                console.log("🔍 PROCEDIMIENTO SELECCIONADO:")
                console.log("   - Índice:", procedureFormDialog.selectedProcedureIndex)
                console.log("   - Nombre:", procedimientoSeleccionado.nombre)
                console.log("   - ID Real:", procedimientoId)
                console.log("   - Precio Normal:", procedimientoSeleccionado.precioNormal)
                console.log("   - Precio Emergencia:", procedimientoSeleccionado.precioEmergencia)
            } else {
                console.log("❌ ERROR: Índice de procedimiento inválido:", procedureFormDialog.selectedProcedureIndex)
            }
            
            var datosPaciente = obtenerDatosPacienteParaProcedimiento()
            
            return {
                paciente: datosPaciente.paciente,
                cedula: datosPaciente.cedula,
                esAnonimo: datosPaciente.esAnonimo,
                idProcedimiento: procedimientoId,  // ✅ Usar ID REAL, no índice + 1
                cantidad: parseInt(cantidadTextField.text) || 1,
                tipo: procedureFormDialog.procedureType,
                idTrabajador: trabajadorId,
                precioUnitario: procedureFormDialog.calculatedUnitPrice,
                precioTotal: procedureFormDialog.calculatedTotalPrice
            }
        } catch (error) {
            console.log("⚠️ Error obteniendo datos del formulario:", error.message)
            throw error
        }
    }

    function procesarResultadoCreacion(resultado) {
        try {
            console.log("🔄 Procesando resultado de creación:", resultado)
            
            // Verificar si fue exitoso
            if (typeof resultado === 'string') {
                var resultadoObj = JSON.parse(resultado)
                if (!resultadoObj.exito) {
                    throw new Error(resultadoObj.error || "Error desconocido en la creación")
                }
            }
            
            console.log("✅ Procedimiento creado exitosamente")
            
            // Limpiar y cerrar formulario
            Qt.callLater(function() {
                if (showNewProcedureDialog) {
                    limpiarYCerrarDialogo()
                }
            })
            
            formEnabled = true
            
        } catch (error) {
            console.log("❌ Error procesando resultado de creación:", error.message)
            formEnabled = true
            throw error
        }
    }

    function procesarResultadoActualizacion(resultado) {
        try {
            console.log("🔄 Procesando resultado de actualización:", resultado)
            
            // Verificar si fue exitoso
            if (typeof resultado === 'string') {
                var resultadoObj = JSON.parse(resultado)
                if (!resultadoObj.exito) {
                    throw new Error(resultadoObj.error || "Error desconocido en la actualización")
                }
            }
            
            console.log("✅ Procedimiento actualizado exitosamente")
            
            // Limpiar y cerrar formulario
            Qt.callLater(function() {
                if (showNewProcedureDialog) {
                    limpiarYCerrarDialogo()
                }
            })
            
            formEnabled = true
            
        } catch (error) {
            console.log("❌ Error procesando resultado de actualización:", error.message)
            formEnabled = true
            throw error
        }
    }
        
    function editarProcedimiento(index) {
        try {
            console.log("✏️ Editando procedimiento en index:", index)
            
            if (index < 0 || index >= procedimientosPaginadosModel.count) {
                console.log("❌ Índice inválido para edición:", index)
                return
            }
            
            var procedimiento = procedimientosPaginadosModel.get(index)
            console.log("📋 Cargando datos para edición:", JSON.stringify(procedimiento))
            
            // Crear objeto para editar con validaciones
            procedureFormDialog.procedimientoParaEditar = {
                procedimientoId: procedimiento.procedimientoId || "N/A",
                paciente: procedimiento.paciente || "Sin nombre",
                cedula: procedimiento.cedula || "",
                tipoProcedimiento: procedimiento.tipoProcedimiento || "",
                cantidad: procedimiento.cantidad || 1,
                tipo: procedimiento.tipo || "Normal",
                precioUnitario: procedimiento.precioUnitario || "0.00",
                precioTotal: procedimiento.precioTotal || "0.00",
                trabajadorRealizador: procedimiento.trabajadorRealizador || "",
                fecha: procedimiento.fecha || ""
            }
            
            isEditMode = true
            editingIndex = index
            showNewProcedureDialog = true
            
            console.log("✅ Modo edición activado para procedimiento ID:", procedimiento.procedimientoId)
            
        } catch (error) {
            console.log("❌ Error al iniciar edición:", error)
            showNotification("Error", "No se pudo cargar el procedimiento para editar")
        }
    }
    
    function eliminarProcedimiento(procedimientoId) {
        try {
            var intId = parseInt(procedimientoId)
            if (intId > 0 && enfermeriaModel && modeloConectado) {
                console.log("🗑️ Eliminando procedimiento ID:", intId)
                
                // ✅ VERIFICAR PERMISOS ANTES DE ELIMINAR
                if (!enfermeriaRoot.esAdministrador) {
                    showNotification("Error", "Solo administradores pueden eliminar procedimientos")
                    return false
                }
                
                var resultado = enfermeriaModel.eliminar_procedimiento(intId)
                
                if (resultado) {
                    selectedRowIndex = -1
                    showNotification("Éxito", "Procedimiento eliminado correctamente")
                    
                    // ✅ CERRAR DIÁLOGO AUTOMÁTICAMENTE
                    showConfirmDeleteDialog = false
                    procedimientoIdToDelete = ""
                    
                    return true
                } else {
                    showNotification("Error", "Error eliminando procedimiento")
                    return false
                }
            }
        } catch (error) {
            console.log("❌ Error eliminando procedimiento:", error)
            showNotification("Error", "Error eliminando procedimiento")
            return false
        }
    }
    
    function cancelarFormulario() {
        try {
            showNewProcedureDialog = false
            selectedRowIndex = -1
            isEditMode = false
            editingIndex = -1
            procedureForm.procedimientoParaEditar = null
            formEnabled = true
        } catch (error) {
            console.log("❌ Error cancelando formulario:", error)
        }
    }
    
    function limpiarYCerrarDialogo() {
        console.log("🚪 Cerrando diálogo de procedimiento...")
        
        try {
            formEnabled = true
            showNewProcedureDialog = false
            selectedRowIndex = -1
            isEditMode = false
            editingIndex = -1
            procedureFormDialog.procedimientoParaEditar = null
            
            // RESETEAR MODO ANÓNIMO
            modoAnonimo = false
            modoNormalRadio.checked = true
            modoAnonimoRadio.checked = false
            
            clearAllFields()
            console.log("✅ Diálogo cerrado y limpiado correctamente")
        } catch (error) {
            console.log("⚠️ Error limpiando diálogo:", error)
            showNewProcedureDialog = false
            formEnabled = true
            modoAnonimo = false
        }
    }

    function clearAllFields() {
        console.log("🧹 Limpiando todos los campos del formulario...")
        
        try {
            // ✅ CORREGIR: Limpiar cédula también
            if (campoBusquedaPaciente) {
                campoBusquedaPaciente.text = ""
                campoBusquedaPaciente.pacienteAutocompletado = false
                campoBusquedaPaciente.pacienteNoEncontrado = false
                //campoBusquedaPaciente.buscandoPaciente = false
            }
            
            // Limpiar datos del paciente
            if (nombrePaciente) nombrePaciente.text = ""
            if (apellidoPaterno) apellidoPaterno.text = ""
            if (apellidoMaterno) apellidoMaterno.text = ""
            
            // Resetear combos
            if (procedimientoCombo) procedimientoCombo.currentIndex = 0
            if (trabajadorCombo) trabajadorCombo.currentIndex = 0
            
            // Resetear radio buttons
            if (normalRadio) normalRadio.checked = true
            if (emergenciaRadio) emergenciaRadio.checked = false
            
            // Resetear cantidad
            if (cantidadTextField) cantidadTextField.text = ""
            
            // Resetear propiedades del formulario
            if (procedureFormDialog) {
                procedureFormDialog.selectedProcedureIndex = -1
                procedureFormDialog.calculatedUnitPrice = 0.0
                procedureFormDialog.calculatedTotalPrice = 0.0
                procedureFormDialog.procedureType = "Normal"
                procedureFormDialog.procedimientoParaEditar = null
            }
            
            console.log("✅ Campos limpiados correctamente (incluyendo cédula)")
        } catch (error) {
            console.log("⚠️ Error limpiando campos:", error)
        }
    }
    
    // GRUPO F - UTILIDADES
    
    function showNotification(tipo, mensaje) {
        if (typeof appController !== 'undefined' && appController.showNotification) {
            appController.showNotification(tipo, mensaje)
        } else {
            console.log(`${tipo}: ${mensaje}`)
        }
    }
    
    function calcularElementosPorPagina() {
        var alturaDisponible = height - baseUnit * 25
        var alturaFila = baseUnit * 7
        var elementosCalculados = Math.floor(alturaDisponible / alturaFila)
        
        return Math.max(6, Math.min(elementosCalculados, 15))
    }
    function habilitarNuevoPacientePorNombre() {
        console.log("✅ Habilitando creación de nuevo paciente por nombre:", campoBusquedaPaciente.text)
        
        campoBusquedaPaciente.pacienteNoEncontrado = true
        campoBusquedaPaciente.pacienteAutocompletado = false
        
        nombrePaciente.forceActiveFocus()
    }

    function verificarPermisosProcedimiento(procedimientoId) {
        try {
            if (!enfermeriaModel || !procedimientoId) {
                return {
                    puede_eliminar: false,
                }
            }
            
            var permisos = enfermeriaModel.verificar_permisos_procedimiento(parseInt(procedimientoId))
            return permisos
            
        } catch (error) {
            console.log("⚠️ Error verificando permisos:", error.message)
            return {
                puede_eliminar: false
            }
        }
    }

    function obtenerTooltipEliminacion(procedimientoId) {
        if (!procedimientoId) return "Procedimiento no válido"
        
        var permisos = verificarPermisosProcedimiento(procedimientoId)
        
        if (permisos.es_administrador) {
            return "Eliminar procedimiento (Administrador - Sin restricciones)"
        }
        
        if (permisos.es_medico) {
            if (permisos.puede_eliminar) {
                var diasRestantes = Math.max(0, 30 - permisos.dias_antiguedad)
                return `Eliminar (${permisos.dias_antiguedad} días - ${diasRestantes} días restantes)`
            } else {
                return `Bloqueado: ${permisos.dias_antiguedad} días (Límite: 30 días)`
            }
        }
        
        return "Eliminar procedimiento"
    }

    // Metodos nuevos
    function detectarTipoBusqueda(termino) {
        try {
            if (!termino || termino.length < 2) return "desconocido"
            
            // Detectar cédula (principalmente números)
            var soloNumeros = termino.replace(/[^\d]/g, '')
            if (soloNumeros.length >= 5 && soloNumeros.length >= termino.length * 0.7) {
                return "cedula"
            }
            
            // Detectar nombre (múltiples palabras o letras)
            if (termino.split(' ').length >= 2 || /^[a-zA-ZáéíóúñüÁÉÍÓÚÑÜ\s]+$/.test(termino)) {
                return "nombre"
            }
            
            return "mixto"
        } catch (error) {
            console.log("Error detectando tipo de búsqueda:", error)
            return "desconocido"
        }
    }

    function buscarPacienteUnificado(termino) {
        if (!enfermeriaModel || !modeloConectado || termino.length < 2) return
        
        try {
            console.log("🔍 Búsqueda unificada:", termino)
            
            campoBusquedaPaciente.buscandoPaciente = true
            campoBusquedaPaciente.resultadosBusqueda = []
            
            var resultados = enfermeriaModel.buscar_paciente_unificado(termino.trim(), 5)
            
            campoBusquedaPaciente.buscandoPaciente = false
            
            if (resultados && resultados.length > 0) {
                console.log("✅ Encontrados", resultados.length, "pacientes")
                campoBusquedaPaciente.resultadosBusqueda = resultados
                campoBusquedaPaciente.resultadoSeleccionado = 0
                campoBusquedaPaciente.pacienteEncontrado = true
                campoBusquedaPaciente.esPacienteNuevo = false
            } else {
                console.log("❌ No se encontraron pacientes")
                campoBusquedaPaciente.resultadosBusqueda = []
                campoBusquedaPaciente.pacienteEncontrado = false
                campoBusquedaPaciente.esPacienteNuevo = true
            }
            
        } catch (error) {
            console.log("Error en búsqueda unificada:", error)
            campoBusquedaPaciente.buscandoPaciente = false
            campoBusquedaPaciente.resultadosBusqueda = []
            campoBusquedaPaciente.pacienteEncontrado = false
            campoBusquedaPaciente.esPacienteNuevo = true
        }
    }

    function seleccionarPacienteEncontrado(index) {
        try {
            if (!resultadosBusquedaPacientesModel || 
                index < 0 || index >= resultadosBusquedaPacientesModel.count) {
                return
            }
            
            var paciente = resultadosBusquedaPacientesModel.get(index)
            console.log("👤 Seleccionando paciente:", paciente.nombre_completo)
            
            // ✅ GUARDAR ID Y MARCAR COMO EXISTENTE
            pacienteSeleccionadoId = paciente.id
            esPacienteExistente = true
            pacienteAutocompletado = true
            
            // ✅ AUTOCOMPLETAR CAMPOS CON NOMBRES CORREGIDOS:
            campoBusquedaPaciente.text = paciente.nombre_completo || ""
            cedulaPaciente.text = paciente.cedula || ""
            nombrePaciente.text = paciente.nombre || ""
            apellidoPaterno.text = paciente.apellido_paterno || ""
            apellidoMaterno.text = paciente.apellido_materno || ""
            
            // ✅ ACTUALIZAR ESTADOS CORREGIDOS:
            campoBusquedaPaciente.pacienteAutocompletado = true
            campoBusquedaPaciente.pacienteNoEncontrado = false
            campoBusquedaPaciente.pacienteEncontrado = true      // ✅ USAR PROPIEDAD EXISTENTE
            campoBusquedaPaciente.esPacienteNuevo = false        // ✅ USAR PROPIEDAD EXISTENTE
            
            // ✅ LIMPIAR RESULTADOS:
            limpiarResultadosBusqueda()
            
            console.log("✅ Paciente autocompletado - ID:", pacienteSeleccionadoId)
            
        } catch (error) {
            console.log("Error seleccionando paciente:", error)
        }
    }

    function navegarResultados(direccion) {
        if (!campoBusquedaPaciente.resultadosBusqueda || 
            campoBusquedaPaciente.resultadosBusqueda.length === 0) return
        
        var nuevoIndex = campoBusquedaPaciente.resultadoSeleccionado + direccion
        
        if (nuevoIndex < 0) {
            nuevoIndex = campoBusquedaPaciente.resultadosBusqueda.length - 1
        } else if (nuevoIndex >= campoBusquedaPaciente.resultadosBusqueda.length) {
            nuevoIndex = 0
        }
        
        campoBusquedaPaciente.resultadoSeleccionado = nuevoIndex
    }

    function seleccionarResultadoActual() {
        if (campoBusquedaPaciente.resultadoSeleccionado >= 0 && 
            campoBusquedaPaciente.resultadosBusqueda && 
            campoBusquedaPaciente.resultadosBusqueda.length > 0) {
            
            seleccionarPacienteEncontrado(campoBusquedaPaciente.resultadoSeleccionado)
        }
    }

    function limpiarDatosPaciente() {
        // ✅ NO limpiar en modo edición
        if (isEditMode) {
            console.log("🔒 Modo edición activo - NO limpiar datos")
            return
        }
        
        try {
            // ✅ RESETEAR PROPIEDADES NUEVAS
            pacienteSeleccionadoId = -1
            esPacienteExistente = false
            pacienteAutocompletado = false
            
            // Limpiar campos
            campoBusquedaPaciente.text = ""
            cedulaPaciente.text = ""
            nombrePaciente.text = ""
            apellidoPaterno.text = ""
            apellidoMaterno.text = ""
            
            // ✅ RESETEAR ESTADOS CORREGIDOS:
            if (campoBusquedaPaciente) {
                campoBusquedaPaciente.pacienteAutocompletado = false
                campoBusquedaPaciente.pacienteNoEncontrado = false
                campoBusquedaPaciente.pacienteEncontrado = false
                campoBusquedaPaciente.esPacienteNuevo = false
                campoBusquedaPaciente.buscandoPaciente = false
                campoBusquedaPaciente.resultadosBusqueda = []
                campoBusquedaPaciente.resultadoSeleccionado = -1
                campoBusquedaPaciente.tipoDetectado = ""
            }
            
            console.log("🧹 Datos del paciente limpiados")
        } catch (error) {
            console.log("Error limpiando datos paciente:", error)
        }
    }

    function forzarLimpiezaPaciente() {
        // ✅ LIMPIEZA COMPLETA INCLUSO CON PACIENTE EXISTENTE
        console.log("🧹 Forzando limpieza completa de paciente")
        
        pacienteSeleccionadoId = -1
        esPacienteExistente = false
        pacienteAutocompletado = false
        
        campoBusquedaPaciente.text = ""
        cedulaPaciente.text = ""
        nombrePaciente.text = ""
        apellidoPaterno.text = ""
        apellidoMaterno.text = ""
        
        campoBusquedaPaciente.pacienteEncontrado = false
        campoBusquedaPaciente.esPacienteNuevo = false
        campoBusquedaPaciente.resultadosBusqueda = []
        campoBusquedaPaciente.resultadoSeleccionado = -1
    }


    function analizarNombreCompleto(nombreCompleto) {
        try {
            if (!enfermeriaModel || !nombreCompleto) {
                return {nombre: "", apellidoPaterno: "", apellidoMaterno: ""}
            }
            
            return enfermeriaModel.analizar_nombre_completo(nombreCompleto.trim())
        } catch (error) {
            console.log("Error analizando nombre:", error)
            return {nombre: "", apellidoPaterno: "", apellidoMaterno: ""}
        }
    }

    // ===============================
    // MODIFICAR FUNCIÓN buscarOCrearPaciente EXISTENTE
    // ===============================

    function buscarOCrearPaciente() {
        try {
            // ✅ SI ES PACIENTE EXISTENTE Y TENEMOS ID, USAR DIRECTAMENTE
            if (esPacienteExistente && pacienteSeleccionadoId > 0) {
                console.log("✅ Usando paciente existente con ID:", pacienteSeleccionadoId)
                return pacienteSeleccionadoId
            }
            
            // ✅ SOLO BUSCAR/CREAR SI NO HAY PACIENTE SELECCIONADO
            var nombre = nombrePaciente.text.trim()
            var apellidoP = apellidoPaterno.text.trim()
            var apellidoM = apellidoMaterno.text.trim()
            var cedula = cedulaPaciente.text.trim()
            
            if (!nombre || !apellidoP) {
                showNotification("Error", "Nombre y apellido paterno son obligatorios")
                return -1
            }
            
            console.log("🔄 Buscando/creando paciente:", nombre, apellidoP)
            
            var pacienteId = enfermeriaModel.buscar_o_crear_paciente_inteligente(
                nombre, apellidoP, apellidoM, cedula
            )
            
            if (pacienteId > 0) {
                // Actualizar estado
                pacienteSeleccionadoId = pacienteId
                esPacienteExistente = true
                return pacienteId
            }
            
            return -1
            
        } catch (error) {
            console.log("Error en buscarOCrearPaciente:", error)
            return -1
        }
    }
    function limpiarResultadosBusqueda() {
        try {
            mostrarResultadosBusqueda = false
            resultadosBusquedaPacientesModel.clear()
            
            // ✅ RESETEAR ESTADOS DEL CAMPO:
            if (campoBusquedaPaciente) {
                campoBusquedaPaciente.pacienteEncontrado = false
                campoBusquedaPaciente.esPacienteNuevo = false
                campoBusquedaPaciente.resultadoSeleccionado = -1
            }
            
            console.log("🧹 Resultados de búsqueda limpiados")
        } catch (error) {
            console.log("Error limpiando resultados:", error)
        }
    }

    function buscarPacientesUnificado(termino) {
        if (!enfermeriaModel || !termino || termino.length < 2) {
            limpiarResultadosBusqueda()
            return
        }
        
        console.log("Buscando pacientes (unificado):", termino)
        
        try {
            var resultados = enfermeriaModel.buscar_paciente_unificado(termino.trim(), 8)
            
            resultadosBusquedaPacientesModel.clear()
            
            if (resultados && resultados.length > 0) {
                for (var i = 0; i < resultados.length; i++) {
                    var paciente = resultados[i]
                    
                    // ✅ DEPURACIÓN: Imprimir qué datos están llegando
                    console.log("DEBUG Paciente " + i + ":", JSON.stringify(paciente))
                    
                    // ✅ MAPEO CORREGIDO Y EXHAUSTIVO:
                    var nombreCompleto = paciente.nombreCompleto || 
                                    paciente.nombre_completo ||
                                    paciente.NombreCompleto ||
                                    ""
                    
                    // Si no viene nombreCompleto, construirlo
                    if (!nombreCompleto || nombreCompleto.trim() === "") {
                        var partes = []
                        var nombre = paciente.nombre || paciente.Nombre || ""
                        var apellidoP = paciente.apellidoPaterno || paciente.apellido_paterno || paciente.Apellido_Paterno || ""
                        var apellidoM = paciente.apellidoMaterno || paciente.apellido_materno || paciente.Apellido_Materno || ""
                        
                        if (nombre) partes.push(nombre)
                        if (apellidoP) partes.push(apellidoP)
                        if (apellidoM) partes.push(apellidoM)
                        
                        nombreCompleto = partes.join(" ")
                    }
                    
                    resultadosBusquedaPacientesModel.append({
                        id: paciente.id || 0,
                        nombre: paciente.nombre || paciente.Nombre || "",
                        apellido_paterno: paciente.apellidoPaterno || paciente.apellido_paterno || paciente.Apellido_Paterno || "",
                        apellido_materno: paciente.apellidoMaterno || paciente.apellido_materno || paciente.Apellido_Materno || "",
                        cedula: paciente.cedula || paciente.Cedula || "",
                        nombreCompleto: nombreCompleto,  // ✅ ESTA ES LA CLAVE
                        nombre_completo: nombreCompleto, // ✅ DOBLE MAPEO POR SEGURIDAD
                        relevancia: paciente.score || paciente.relevancia || 1.0,
                        tipo_coincidencia: paciente.tipo_coincidencia || "",
                        texto_busqueda: termino
                    })
                    
                    console.log("DEBUG Paciente agregado al modelo:", nombreCompleto)
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
    
    function marcarComoNuevoPaciente(termino) {
        try {
            console.log("⚠️ Marcando como nuevo paciente:", termino)
            
            campoBusquedaPaciente.pacienteNoEncontrado = true
            campoBusquedaPaciente.pacienteAutocompletado = false
            campoBusquedaPaciente.pacienteEncontrado = false
            campoBusquedaPaciente.esPacienteNuevo = true
            
            // Analizar si es cédula o nombre
            var esCedula = enfermeriaModel ? enfermeriaModel.detectar_tipo_busqueda(termino) === "cedula" : false
            
            if (esCedula) {
                // Si es cédula, dejarla en el campo de cédula
                cedulaPaciente.text = termino
                campoBusquedaPaciente.text = ""
                nombrePaciente.forceActiveFocus()
            } else {
                // Si es nombre, analizarlo
                var componentes = enfermeriaModel ? enfermeriaModel.analizar_nombre_completo(termino) : null
                if (componentes) {
                    nombrePaciente.text = componentes.nombre || ""
                    apellidoPaterno.text = componentes.apellidoPaterno || ""
                    apellidoMaterno.text = componentes.apellidoMaterno || ""
                }
                campoBusquedaPaciente.text = termino
            }
            
            console.log("✅ Modo nuevo paciente habilitado")
            
        } catch (error) {
            console.log("Error marcando nuevo paciente:", error)
        }
    }

    function obtenerDatosPacienteParaProcedimiento() {
        if (modoAnonimo) {
            console.log("🎭 Obteniendo datos de paciente ANÓNIMO")
            return {
                paciente: "ANÓNIMO",
                cedula: "",
                esAnonimo: true
            }
        } else {
            console.log("👤 Obteniendo datos de paciente NORMAL")
            return {
                paciente: (nombrePaciente.text + " " + apellidoPaterno.text + " " + apellidoMaterno.text).trim(),
                cedula: cedulaPaciente.text.trim() || campoBusquedaPaciente.text.trim(),
                esAnonimo: false
            }
        }
    }
}