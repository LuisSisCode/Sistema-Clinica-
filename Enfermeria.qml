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
    readonly property real colId: 0.05
    readonly property real colPaciente: 0.18
    readonly property real colProcedimiento: 0.16
    readonly property real colCantidad: 0.07
    readonly property real colTipo: 0.09
    readonly property real colPrecio: 0.10
    readonly property real colTotal: 0.10
    readonly property real colFecha: 0.10
    readonly property real colTrabajador: 0.15
    
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
    
    // ✅ DATOS DEL MODELO CON PARSING SEGURO
    property var trabajadoresDisponibles: []
    property var tiposProcedimientos: []
    
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
            console.log("🔗 Modelos listos, conectando EnfermeriaModel...")
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
            console.log("🩹 Signal: Procedimientos actualizados")
            updateTimer.restart()
        }
        
        function onTiposProcedimientosChanged() {
            console.log("🔧 Signal: Tipos de procedimientos actualizados")
            dataParseTimer.restart()
        }
        
        function onTrabajadoresChanged() {
            console.log("👥 Signal: Trabajadores actualizados")
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
            console.log("🔄 Estado enfermería:", nuevoEstado)
            if (nuevoEstado === "listo") {
                formEnabled = true
            } else if (nuevoEstado === "cargando") {
                formEnabled = false
            }
        }
        
        function onErrorOccurred(mensaje) {
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
                                isEditMode = false
                                editingIndex = -1
                                showNewProcedureDialog = true
                            }
                            
                            HoverHandler {
                                cursorShape: Qt.PointingHandCursor
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
                                    console.log("🏥 Modelo procedimientos actualizado:", modelData.length, "elementos")
                                    return modelData
                                }
                                
                                currentIndex: 0
                                onCurrentIndexChanged: {
                                    console.log("🏥 PROCEDIMIENTO FILTER CHANGED:")
                                    console.log("   - currentIndex:", currentIndex)
                                    console.log("   - currentText:", currentText) 
                                    console.log("   - model length:", model.length)
                                    console.log("   - model:", JSON.stringify(model))
                                    
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
                        
                        // HEADER DE TABLA (sin cambios)
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
                                    }
                                    
                                    Rectangle {
                                        anchors.right: parent.right
                                        width: 1
                                        height: parent.height
                                        color: lineColor
                                    }
                                }
                                
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
                                
                                Item {
                                    Layout.preferredWidth: parent.width * colCantidad
                                    Layout.fillHeight: true
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "CANT."
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
                                
                                Item {
                                    Layout.preferredWidth: parent.width * colTotal
                                    Layout.fillHeight: true
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "TOTAL"
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
                                    
                                    Rectangle {
                                        anchors.right: parent.right
                                        width: 1
                                        height: parent.height
                                        color: lineColor
                                    }
                                }
                                
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
                                    }
                                }
                            }
                        }
                        
                        // ✅ CONTENIDO DE LA TABLA MEJORADO
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
                                        
                                        Item {
                                            Layout.preferredWidth: parent.width * colId
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
                                        
                                        Item {
                                            Layout.preferredWidth: parent.width * colCantidad
                                            Layout.fillHeight: true
                                            
                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: baseUnit * 2.5
                                                height: baseUnit * 2.5
                                                color: (model.cantidad || 1) > 1 ? warningColor : successColor
                                                radius: height / 2
                                                
                                                Label {
                                                    anchors.centerIn: parent
                                                    text: model.cantidad || "0"
                                                    color: whiteColor
                                                    font.pixelSize: fontBaseSize * 0.75
                                                    font.bold: true
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
                                        
                                        Item {
                                            Layout.preferredWidth: parent.width * colPrecio
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                text: "Bs " + (model.precioUnitario || "0.00")
                                                color: model.tipo === "Emergencia" ? "#92400E" : "#047857"
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
                                        
                                        Item {
                                            Layout.preferredWidth: parent.width * colTotal
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                text: "Bs " + (model.precioTotal || "0.00") 
                                                color: model.tipo === "Emergencia" ? "#92400E" : "#047857"
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
                                            
                                            Rectangle {
                                                anchors.right: parent.right
                                                width: 1
                                                height: parent.height
                                                color: lineColor
                                            }
                                        }
                                        
                                        Item {
                                            Layout.preferredWidth: parent.width * colTrabajador
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
                            text: modeloConectado ? 
                                "Página " + (currentPageEnfermeria + 1) + " de " + Math.max(1, totalPagesEnfermeria) +
                                " | Total: " + totalItemsEnfermeria + " registros" :
                                "Conectando..."
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

    // DIÁLOGO MODAL DE NUEVO/EDITAR PROCEDIMIENTO (manteniendo diseño original)
    Dialog {
        id: procedureFormDialog
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.95, 700)
        height: Math.min(parent.height * 0.95, 800)
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
        
        property var procedimientoParaEditar: null
        property int selectedProcedureIndex: -1
        property string procedureType: "Normal"
        property real calculatedUnitPrice: 0.0
        property real calculatedTotalPrice: 0.0
        
        function updatePrices() {
            if (procedureFormDialog.selectedProcedureIndex >= 0 && tiposProcedimientos.length > 0) {
                try {
                    var procedimiento = tiposProcedimientos[procedureFormDialog.selectedProcedureIndex]
                    
                    var precioUnitario = 0
                    if (procedureFormDialog.procedureType === "Emergencia") {
                        precioUnitario = procedimiento.precioEmergencia || 0
                    } else {
                        precioUnitario = procedimiento.precioNormal || 0
                    }
                    
                    var cantidadActual = parseInt(cantidadTextField.text) || 0
                    var precioTotal = precioUnitario * cantidadActual
                    
                    procedureFormDialog.calculatedUnitPrice = precioUnitario
                    procedureFormDialog.calculatedTotalPrice = precioTotal
                } catch (e) {
                    console.log("Error calculando precios:", e)
                    procedureFormDialog.calculatedUnitPrice = 0.0
                    procedureFormDialog.calculatedTotalPrice = 0.0
                }
            } else {
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
            
            cedulaPaciente.text = proc.cedula || ""
            if (cedulaPaciente.text.length >= 5) {
                buscarPacientePorCedula(cedulaPaciente.text)
            }
            
            if (proc.tipoProcedimiento) {
                for (var i = 0; i < tiposProcedimientos.length; i++) {
                    if (tiposProcedimientos[i].nombre === proc.tipoProcedimiento) {
                        procedimientoCombo.currentIndex = i + 1
                        procedureFormDialog.selectedProcedureIndex = i
                        break
                    }
                }
            }
            
            if (proc.trabajadorRealizador) {
                for (var j = 0; j < trabajadoresDisponibles.length; j++) {
                    var trabajador = trabajadoresDisponibles[j]
                    var nombreTrabajador = trabajador.nombreCompleto || ""
                    if (nombreTrabajador === proc.trabajadorRealizador) {
                        trabajadorCombo.currentIndex = j + 1
                        break
                    }
                }
            }
            
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
            
            console.log("Datos de edición cargados correctamente")
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
                                property bool buscandoPaciente: false
                                
                                background: Rectangle {
                                    color: {
                                        if (cedulaPaciente.pacienteAutocompletado) return "#F0F8FF"
                                        if (cedulaPaciente.pacienteNoEncontrado) return "#FEF3C7"
                                        if (cedulaPaciente.buscandoPaciente) return "#F3F4F6"
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
                                            if (cedulaPaciente.buscandoPaciente) return "🔄"
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
                                        buscandoPaciente = true
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
                                    placeholderText: "1"
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
                    var tieneCedula = cedulaPaciente.text.length >= 5
                    var tieneNombre = nombrePaciente.text.length >= 2
                    var tieneTrabajador = trabajadorCombo.currentIndex > 0
                    var cantidadValida = (parseInt(cantidadTextField.text) || 0) > 0
                    
                    if (cedulaPaciente.pacienteAutocompletado) {
                        return tieneProcedimiento && tieneCedula && tieneNombre && tieneTrabajador && cantidadValida && formEnabled
                    } else if (cedulaPaciente.pacienteNoEncontrado) {
                        var tieneApellido = apellidoPaterno.text.length >= 2
                        return tieneProcedimiento && tieneCedula && tieneNombre && tieneApellido && tieneTrabajador && cantidadValida && formEnabled
                    }
                    
                    return false
                }
                Layout.preferredHeight: baseUnit * 4
                
                background: Rectangle {
                    color: {
                        if (!parent.enabled) return "#bdc3c7"
                        if (!formEnabled) return "#95a5a6"
                        return primaryColor
                    }
                    radius: baseUnit
                    
                    Rectangle {
                        anchors.centerIn: parent
                        width: !formEnabled ? 20 : 0
                        height: !formEnabled ? 20 : 0
                        color: "transparent"
                        visible: !formEnabled
                        
                        Rectangle {
                            width: 4
                            height: 4
                            radius: 2
                            color: whiteColor
                            anchors.centerIn: parent
                            
                            SequentialAnimation on rotation {
                                running: parent.visible
                                loops: Animation.Infinite
                                NumberAnimation { to: 360; duration: 1000 }
                            }
                        }
                    }
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
                                eliminarProcedimiento(procedimientoId)
                                
                                showConfirmDeleteDialog = false
                                procedimientoIdToDelete = ""
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
                console.log("✅ EnfermeriaModel conectado exitosamente")
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
        
        console.log("🚀 Inicializando datos de EnfermeriaModel...")
        
        try {
            // Configurar elementos por página
            var elementosPorPagina = 6
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
            
            console.log("✅ Modelo inicializado correctamente")
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
                
                console.log("✅ Modelo actualizado con", procedimientosPaginadosModel.count, "elementos")
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
            enfermeriaModel.obtener_procedimientos_paginados(currentPageEnfermeria - 1, 6, filtros)
        }
    }

    function irAPaginaSiguiente() {
        if (enfermeriaModel && modeloConectado && currentPageEnfermeria < (totalPagesEnfermeria - 1)) {
            console.log("➡️ Navegando a página siguiente:", currentPageEnfermeria + 1)
            
            var filtros = construirFiltrosActuales()
            enfermeriaModel.obtener_procedimientos_paginados(currentPageEnfermeria + 1, 6, filtros)
        }
    }
    
    // GRUPO C - FILTROS ESTANDARIZADOS
    
    function aplicarFiltros() {
        if (!enfermeriaModel || !modeloConectado) {
            console.log("❌ Modelo no disponible para aplicar filtros")
            return
        }

        console.log("🔍 Aplicando filtros...")
        
        // ✅ LOGS DE DEBUG PARA DIAGNOSTICAR
        console.log("🎯 FILTROS DEBUG:")
        console.log("   - filtroFecha.currentIndex:", filtroFecha.currentIndex)
        console.log("   - filtroFecha.currentText:", filtroFecha.currentText)
        console.log("   - filtroProcedimiento.currentIndex:", filtroProcedimiento.currentIndex)
        console.log("   - filtroProcedimiento.currentText:", filtroProcedimiento.currentText)
        console.log("   - filtroTipo.currentIndex:", filtroTipo.currentIndex)
        console.log("   - filtroTipo.currentText:", filtroTipo.currentText)
        console.log("   - campoBusqueda.text:", campoBusqueda.text)
        
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
        if (!enfermeriaModel || !modeloConectado || cedula.length < 5) {
            cedulaPaciente.buscandoPaciente = false
            return
        }
        
        console.log("🔍 Búsqueda inteligente de paciente:", cedula)
        
        try {
            var pacienteEncontrado = enfermeriaModel.buscar_paciente_por_cedula(cedula)
            cedulaPaciente.buscandoPaciente = false
        } catch (error) {
            console.log("❌ Error en búsqueda de paciente:", error)
            cedulaPaciente.buscandoPaciente = false
        }
    }
    
    function autocompletarDatosPaciente(paciente) {
        console.log("👤 Autocompletando datos del paciente:", paciente.nombreCompleto)
        
        try {
            nombrePaciente.text = paciente.nombre || ""
            apellidoPaterno.text = paciente.apellidoPaterno || ""
            apellidoMaterno.text = paciente.apellidoMaterno || ""

            cedulaPaciente.pacienteAutocompletado = true
            cedulaPaciente.pacienteNoEncontrado = false
            cedulaPaciente.buscandoPaciente = false

            nombrePaciente.readOnly = true
            apellidoPaterno.readOnly = true
            apellidoMaterno.readOnly = true

            showNotification("Éxito", "Paciente encontrado: " + paciente.nombreCompleto)
        } catch (error) {
            console.log("❌ Error autocompletando paciente:", error)
        }
    }
    
    function marcarPacienteNoEncontrado(cedula) {
        console.log("❓ Paciente no encontrado. Habilitando creación:", cedula)
        
        try {
            cedulaPaciente.pacienteNoEncontrado = true
            cedulaPaciente.pacienteAutocompletado = false
            cedulaPaciente.buscandoPaciente = false
            
            nombrePaciente.text = ""
            apellidoPaterno.text = ""
            apellidoMaterno.text = ""
            
            nombrePaciente.readOnly = false
            apellidoPaterno.readOnly = false
            apellidoMaterno.readOnly = false
            
            nombrePaciente.forceActiveFocus()
            
            showNotification("Info", "Paciente no encontrado. Complete los datos para crear nuevo paciente.")
        } catch (error) {
            console.log("❌ Error marcando paciente no encontrado:", error)
        }
    }
    
    function limpiarDatosPaciente() {
        try {
            if (nombrePaciente.text === "" && apellidoPaterno.text === "" && apellidoMaterno.text === "") {
                return
            }
            
            nombrePaciente.text = ""
            apellidoPaterno.text = ""
            apellidoMaterno.text = ""
            
            cedulaPaciente.pacienteAutocompletado = false
            cedulaPaciente.pacienteNoEncontrado = false
            cedulaPaciente.buscandoPaciente = false
            
            nombrePaciente.readOnly = false
            apellidoPaterno.readOnly = false
            apellidoMaterno.readOnly = false
        } catch (error) {
            console.log("❌ Error limpiando datos de paciente:", error)
        }
    }
    
    // GRUPO E - OPERACIONES CRUD MEJORADAS
    
    function guardarProcedimiento() {
        if (!enfermeriaModel || !modeloConectado) {
            console.log("❌ EnfermeriaModel no disponible")
            showNotification("Error", "Modelo no disponible")
            return
        }
        
        if (!formEnabled) {
            console.log("⚠️ Formulario deshabilitado")
            return
        }
        
        console.log("💾 Iniciando guardado de procedimiento...")
        console.log("📝 Modo edición:", isEditMode)
        
        try {
            // Validar trabajador
            var trabajadorIdReal = -1
            if (trabajadorCombo.currentIndex > 0 && trabajadoresDisponibles.length > 0) {
                if (trabajadorCombo.currentIndex - 1 < trabajadoresDisponibles.length) {
                    trabajadorIdReal = trabajadoresDisponibles[trabajadorCombo.currentIndex - 1].id
                }
            }
            
            if (trabajadorIdReal <= 0) {
                showNotification("Error", "Debe seleccionar un trabajador válido")
                return
            }

            var datosProcedimiento = {
                paciente: (nombrePaciente.text + " " + apellidoPaterno.text + " " + apellidoMaterno.text).trim(),
                cedula: cedulaPaciente.text.trim(),
                idProcedimiento: procedureFormDialog.selectedProcedureIndex + 1,  // ← CORREGIDO
                cantidad: parseInt(cantidadTextField.text) || 1,
                tipo: procedureFormDialog.procedureType,  // ← CORREGIDO
                idTrabajador: trabajadorIdReal,
                precioUnitario: procedureFormDialog.calculatedUnitPrice,  // ← CORREGIDO
                precioTotal: procedureFormDialog.calculatedTotalPrice  // ← CORREGIDO
            }
            
            console.log("📋 Datos del procedimiento:", JSON.stringify(datosProcedimiento, null, 2))
            
            // Deshabilitar formulario temporalmente
            formEnabled = false
            
            // Lógica separada: CREAR vs ACTUALIZAR
            if (isEditMode && procedureFormDialog.procedimientoParaEditar) {
                // MODO EDICIÓN
                var procedimientoId = parseInt(procedureFormDialog.procedimientoParaEditar.procedimientoId) 
                
                console.log("✏️ Actualizando procedimiento ID:", procedimientoId)
                
                var resultado = enfermeriaModel.actualizar_procedimiento(datosProcedimiento, procedimientoId)
                console.log("📄 Resultado actualización:", resultado)
                
            } else {
                // MODO CREACIÓN
                console.log("➕ Creando nuevo procedimiento")
                
                var resultado = enfermeriaModel.crear_procedimiento(datosProcedimiento)
                console.log("📄 Resultado creación:", resultado)
            }
        } catch (error) {
            console.log("❌ Error en guardarProcedimiento:", error)
            showNotification("Error", "Error guardando procedimiento: " + error.toString())
            formEnabled = true
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
                enfermeriaModel.eliminar_procedimiento(intId)
                selectedRowIndex = -1
                showNotification("Éxito", "Procedimiento eliminado correctamente")
            }
        } catch (error) {
            console.log("❌ Error eliminando procedimiento:", error)
            showNotification("Error", "Error eliminando procedimiento")
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
            clearAllFields()
            console.log("✅ Diálogo cerrado y limpiado correctamente")
        } catch (error) {
            console.log("⚠️ Error limpiando diálogo:", error)
            showNewProcedureDialog = false
            formEnabled = true
        }
    }
    function clearAllFields() {
        console.log("🧹 Limpiando todos los campos del formulario...")
        
        try {
            // Limpiar datos del paciente
            if (typeof limpiarDatosPaciente === 'function') {
                limpiarDatosPaciente()
            }
            
            // Resetear combos
            if (procedimientoCombo) procedimientoCombo.currentIndex = 0
            if (trabajadorCombo) trabajadorCombo.currentIndex = 0
            
            // Resetear radio buttons
            if (normalRadio) normalRadio.checked = true
            if (emergenciaRadio) emergenciaRadio.checked = false
            
            // Resetear cantidad
            if (cantidadTextField) cantidadTextField.text = ""  // ← CORREGIDO
            
            // Resetear propiedades del formulario
            if (procedureFormDialog) {  // ← CORREGIDO
                procedureFormDialog.selectedProcedureIndex = -1  // ← CORREGIDO
                procedureFormDialog.calculatedUnitPrice = 0.0  // ← CORREGIDO
                procedureFormDialog.calculatedTotalPrice = 0.0  // ← CORREGIDO
                procedureFormDialog.procedureType = "Normal"  // ← CORREGIDO
            }
            
            console.log("✅ Campos limpiados correctamente")
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
}