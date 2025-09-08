import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ClinicaModels 1.0

Item {
    id: confiConsultaRoot
    
    // ===== PROPIEDADES PARA COMUNICACIÓN EXTERNA =====
    property alias especialidades: confiConsultaRoot.especialidadesData
    
    // ===== SEÑALES PARA NAVEGACIÓN =====
    signal volverClicked()
    signal backToMain()
    
    // ===== DATOS INTERNOS =====
    property var especialidadesData: []
    property var doctoresDisponibles: []
    property var estadisticas: ({})
    
    // ===== CONEXIÓN AL MODEL =====
    property var confiConsultaModel: appController.confi_consulta_model_instance
    
    // ===== SISTEMA DE ESCALADO RESPONSIVO =====
    readonly property real baseUnit: Math.min(width, height) / 100
    readonly property real fontTiny: baseUnit * 1.2
    readonly property real fontSmall: baseUnit * 1.5
    readonly property real fontBase: baseUnit * 2.0
    readonly property real fontMedium: baseUnit * 2.5
    readonly property real fontLarge: baseUnit * 3.0
    readonly property real fontTitle: baseUnit * 4.0
    
    readonly property real marginTiny: baseUnit * 0.5
    readonly property real marginSmall: baseUnit * 1
    readonly property real marginMedium: baseUnit * 2
    readonly property real marginLarge: baseUnit * 3
    readonly property real marginExtraLarge: baseUnit * 4
    
    readonly property real radiusSmall: baseUnit * 0.8
    readonly property real radiusMedium: baseUnit * 1.5
    readonly property real radiusLarge: baseUnit * 2
    
    // ===== COLORES =====
    readonly property string primaryColor: "#6366F1"
    readonly property string backgroundColor: "#FFFFFF"
    readonly property string surfaceColor: "#F8FAFC"
    readonly property string borderColor: "#E5E7EB"
    readonly property string textColor: "#111827"
    readonly property string textSecondaryColor: "#6B7280"
    readonly property string successColor: "#059669"
    readonly property string warningColor: "#D97706"
    readonly property string dangerColor: "#DC2626"
    readonly property string lightGrayColor: "#ECF0F1"
    
    // ===== ESTADO DE EDICIÓN =====
    property bool isEditMode: false
    property int editingId: -1
    property bool isLoading: false
    
    // ===== FUNCIONES PRINCIPALES =====
    function limpiarFormulario() {
        nombreField.text = ""
        detallesField.text = ""
        precioNormalField.text = ""
        precioEmergenciaField.text = ""
        doctorComboBox.currentIndex = 0
        isEditMode = false
        editingId = -1
    }
    
    function editarEspecialidad(especialidad) {
        if (especialidad && especialidad.id) {
            nombreField.text = especialidad.Nombre || ""
            detallesField.text = especialidad.Detalles || ""
            precioNormalField.text = especialidad.Precio_Normal ? especialidad.Precio_Normal.toString() : "0"
            precioEmergenciaField.text = especialidad.Precio_Emergencia ? especialidad.Precio_Emergencia.toString() : "0"
            
            // Seleccionar doctor en combo
            if (especialidad.Id_Doctor) {
                for (let i = 0; i < doctorComboBox.model.length; i++) {
                    if (doctorComboBox.model[i].id === especialidad.Id_Doctor) {
                        doctorComboBox.currentIndex = i
                        break
                    }
                }
            } else {
                doctorComboBox.currentIndex = 0
            }
            
            isEditMode = true
            editingId = especialidad.id
            console.log("Editando especialidad ID:", editingId)
        }
    }
    
    function eliminarEspecialidad(especialidadId) {
        if (confiConsultaModel && especialidadId > 0) {
            console.log("Eliminando especialidad ID:", especialidadId)
            confiConsultaModel.eliminarEspecialidad(especialidadId)
        }
    }
    
    function guardarEspecialidad() {
        if (!confiConsultaModel) {
            console.log("Model no disponible")
            return
        }
        
        const nombre = nombreField.text.trim()
        const detalles = detallesField.text.trim()
        const precioNormal = parseFloat(precioNormalField.text) || 0
        const precioEmergencia = parseFloat(precioEmergenciaField.text) || 0
        const idDoctor = doctorComboBox.currentIndex > 0 ? doctorComboBox.model[doctorComboBox.currentIndex].id : 0
        
        if (!nombre) {
            mostrarError("Error de validación", "El nombre de la especialidad es requerido")
            return
        }
        
        if (isEditMode && editingId > 0) {
            // Actualizar especialidad existente
            console.log("Actualizando especialidad:", nombre)
            confiConsultaModel.actualizarEspecialidad(
                editingId,
                nombre,
                detalles,
                precioNormal,
                precioEmergencia,
                idDoctor
            )
        } else {
            // Crear nueva especialidad
            console.log("Creando nueva especialidad:", nombre)
            confiConsultaModel.crearEspecialidad(
                nombre,
                detalles,
                precioNormal,
                precioEmergencia,
                idDoctor
            )
        }
    }
    
    function buscarEspecialidades() {
        if (confiConsultaModel) {
            const termino = busquedaField.text.trim()
            confiConsultaModel.aplicarFiltros(termino)
        }
    }
    
    function limpiarBusqueda() {
        busquedaField.text = ""
        if (confiConsultaModel) {
            confiConsultaModel.limpiarFiltros()
        }
    }
    
    function actualizarDatos() {
        if (confiConsultaModel) {
            console.log("Actualizando datos desde QML...")
            especialidadesData = confiConsultaModel.especialidades || []
            estadisticas = confiConsultaModel.estadisticas || {}
            
            // Cargar doctores disponibles
            doctoresDisponibles = confiConsultaModel.obtenerDoctoresDisponibles() || []
            actualizarModeloDoctores()
        }
    }
    
    function actualizarModeloDoctores() {
        let modeloDoctores = []
        
        // Agregar opción "Sin doctor asignado"
        modeloDoctores.push({
            id: 0,
            nombre: "Sin doctor asignado",
            especialidad: ""
        })
        
        // Agregar doctores disponibles
        for (let doctor of doctoresDisponibles) {
            modeloDoctores.push({
                id: doctor.id || 0,
                nombre: doctor.nombre || "Sin nombre",
                especialidad: doctor.especialidad || ""
            })
        }
        
        doctorComboBox.model = modeloDoctores
    }
    
    function mostrarError(titulo, mensaje) {
        console.log("ERROR:", titulo, "-", mensaje)
        // Aquí puedes agregar notificaciones visuales
    }
    
    function mostrarExito(mensaje) {
        console.log("ÉXITO:", mensaje)
        // Aquí puedes agregar notificaciones visuales
    }
    
    // ===== CONEXIONES AL MODEL =====
    Connections {
        target: confiConsultaModel
        
        function onEspecialidadesChanged() {
            actualizarDatos()
        }
        
        function onEstadisticasChanged() {
            actualizarDatos()
        }
        
        function onEspecialidadCreada(success, message) {
            isLoading = false
            if (success) {
                mostrarExito(message)
                limpiarFormulario()
                confiConsultaModel.refrescarDatosInmediato()
            } else {
                mostrarError("Error creando especialidad", message)
            }
        }
        
        function onEspecialidadActualizada(success, message) {
            isLoading = false
            if (success) {
                mostrarExito(message)
                limpiarFormulario()
                confiConsultaModel.refrescarDatosInmediato()
            } else {
                mostrarError("Error actualizando especialidad", message)
            }
        }
        
        function onEspecialidadEliminada(success, message) {
            isLoading = false
            if (success) {
                mostrarExito(message)
                confiConsultaModel.refrescarDatosInmediato()
            } else {
                mostrarError("Error eliminando especialidad", message)
            }
        }
        
        function onErrorOccurred(title, message) {
            isLoading = false
            mostrarError(title, message)
        }
        
        function onSuccessMessage(message) {
            mostrarExito(message)
        }
        
        function onLoadingChanged() {
            if (confiConsultaModel) {
                isLoading = confiConsultaModel.loading
            }
        }
    }
    
    // ===== LAYOUT PRINCIPAL =====
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        
        // ===== HEADER PRINCIPAL =====
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: baseUnit * 12
            gradient: Gradient {
                GradientStop { position: 0.0; color: primaryColor }
                GradientStop { position: 1.0; color: Qt.darker(primaryColor, 1.1) }
            }
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: marginLarge
                spacing: marginMedium
                
                // ===== BOTÓN DE VOLVER =====
                Button {
                    Layout.preferredWidth: baseUnit * 6
                    Layout.preferredHeight: baseUnit * 6
                    text: "←"
                    
                    background: Rectangle {
                        color: backgroundColor
                        radius: baseUnit * 0.8
                        opacity: parent.pressed ? 0.8 : 1.0
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        color: primaryColor
                        font.pixelSize: baseUnit * 2.5
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        if (typeof changeView !== "undefined") {
                            changeView("main")
                        } else {
                            confiConsultaRoot.volverClicked()
                            confiConsultaRoot.backToMain()
                        }
                    }
                }
                
                // ===== ÍCONO DEL MÓDULO =====
                Rectangle {
                    Layout.preferredWidth: baseUnit * 8
                    Layout.preferredHeight: baseUnit * 8
                    color: backgroundColor
                    radius: baseUnit * 4
                    
                    Label {
                        anchors.centerIn: parent
                        text: "🏥"
                        font.pixelSize: fontBase * 1.8
                    }
                }
                
                // ===== INFORMACIÓN DEL MÓDULO =====
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: marginSmall * 0.5
                    
                    Label {
                        text: "Configuración de Especialidades Médicas"
                        color: backgroundColor
                        font.pixelSize: fontBase * 1.4
                        font.bold: true
                        font.family: "Segoe UI"
                    }
                    
                    Label {
                        text: "Gestiona las especialidades médicas, asigna doctores y configura precios del sistema"
                        color: backgroundColor
                        font.pixelSize: fontBase * 0.9
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        opacity: 0.95
                        font.family: "Segoe UI"
                    }
                }
                
                // ===== ESTADÍSTICAS RÁPIDAS =====
                Rectangle {
                    Layout.preferredWidth: baseUnit * 20
                    Layout.preferredHeight: baseUnit * 8
                    color: backgroundColor
                    radius: radiusMedium
                    opacity: 0.95
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: marginSmall
                        spacing: marginSmall
                        
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: marginTiny
                            
                            Label {
                                text: estadisticas.general ? estadisticas.general.total_especialidades || 0 : 0
                                font.pixelSize: fontLarge
                                font.bold: true
                                color: primaryColor
                                horizontalAlignment: Text.AlignHCenter
                                Layout.fillWidth: true
                            }
                            
                            Label {
                                text: "Especialidades"
                                font.pixelSize: fontTiny
                                color: textSecondaryColor
                                horizontalAlignment: Text.AlignHCenter
                                Layout.fillWidth: true
                            }
                        }
                        
                        Rectangle {
                            Layout.preferredWidth: 1
                            Layout.fillHeight: true
                            color: borderColor
                        }
                        
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: marginTiny
                            
                            Label {
                                text: estadisticas.general ? estadisticas.general.con_doctor_asignado || 0 : 0
                                font.pixelSize: fontLarge
                                font.bold: true
                                color: successColor
                                horizontalAlignment: Text.AlignHCenter
                                Layout.fillWidth: true
                            }
                            
                            Label {
                                text: "Con Doctor"
                                font.pixelSize: fontTiny
                                color: textSecondaryColor
                                horizontalAlignment: Text.AlignHCenter
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }
        
        // ===== ÁREA DE CONTENIDO =====
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: surfaceColor
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: marginLarge
                spacing: marginLarge
                
                // ===== BARRA DE BÚSQUEDA =====
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: baseUnit * 6
                    color: backgroundColor
                    radius: radiusMedium
                    border.color: borderColor
                    border.width: 1
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: marginMedium
                        spacing: marginMedium
                        
                        Label {
                            text: "🔍"
                            font.pixelSize: fontMedium
                        }
                        
                        TextField {
                            id: busquedaField
                            Layout.fillWidth: true
                            placeholderText: "Buscar especialidades por nombre, detalles o doctor..."
                            font.pixelSize: fontBase
                            font.family: "Segoe UI"
                            
                            background: Rectangle {
                                color: "transparent"
                            }
                            
                            onTextChanged: {
                                buscarEspecialidades()
                            }
                            
                            Keys.onPressed: {
                                if (event.key === Qt.Key_Escape) {
                                    limpiarBusqueda()
                                }
                            }
                        }
                        
                        Button {
                            text: "Limpiar"
                            visible: busquedaField.text.length > 0
                            
                            background: Rectangle {
                                color: parent.pressed ? Qt.darker(warningColor, 1.2) : warningColor
                                radius: radiusSmall
                            }
                            
                            contentItem: Label {
                                text: parent.text
                                color: backgroundColor
                                font.pixelSize: fontSmall
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                font.family: "Segoe UI"
                            }
                            
                            onClicked: limpiarBusqueda()
                        }
                        
                        Button {
                            text: "🔄 Actualizar"
                            enabled: !isLoading
                            
                            background: Rectangle {
                                color: parent.enabled ? 
                                       (parent.pressed ? Qt.darker(primaryColor, 1.2) : primaryColor) :
                                       Qt.lighter(primaryColor, 1.5)
                                radius: radiusSmall
                            }
                            
                            contentItem: Label {
                                text: parent.text
                                color: backgroundColor
                                font.pixelSize: fontSmall
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                font.family: "Segoe UI"
                            }
                            
                            onClicked: {
                                if (confiConsultaModel) {
                                    confiConsultaModel.recargarDatos()
                                }
                            }
                        }
                    }
                }
                
                // ===== FORMULARIO =====
                GroupBox {
                    Layout.fillWidth: true
                    title: isEditMode ? "Editar Especialidad" : "Agregar Nueva Especialidad"
                    
                    background: Rectangle {
                        color: backgroundColor
                        border.color: borderColor
                        border.width: 1
                        radius: radiusMedium
                    }
                    
                    label: Label {
                        text: parent.title
                        font.pixelSize: fontMedium
                        font.bold: true
                        color: textColor
                        font.family: "Segoe UI"
                    }
                    
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: marginMedium
                        
                        // PRIMERA FILA: NOMBRE Y DOCTOR
                        GridLayout {
                            Layout.fillWidth: true
                            columns: width < baseUnit * 80 ? 1 : 2
                            rowSpacing: marginMedium
                            columnSpacing: marginLarge
                            
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: marginSmall
                                
                                Label {
                                    text: "Nombre de la Especialidad: *"
                                    font.bold: true
                                    color: textColor
                                    font.pixelSize: fontBase
                                    font.family: "Segoe UI"
                                }
                                TextField {
                                    id: nombreField
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: baseUnit * 4.5
                                    placeholderText: "Ej: Cardiología, Neurología, Pediatría..."
                                    font.pixelSize: fontBase
                                    font.family: "Segoe UI"
                                    background: Rectangle {
                                        color: backgroundColor
                                        border.color: nombreField.focus ? primaryColor : borderColor
                                        border.width: nombreField.focus ? 2 : 1
                                        radius: radiusSmall
                                    }
                                }
                            }
                            
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: marginSmall
                                
                                Label {
                                    text: "Doctor Asignado:"
                                    font.bold: true
                                    color: textColor
                                    font.pixelSize: fontBase
                                    font.family: "Segoe UI"
                                }
                                ComboBox {
                                    id: doctorComboBox
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: baseUnit * 4.5
                                    
                                    model: []
                                    textRole: "nombre"
                                    valueRole: "id"
                                    
                                    background: Rectangle {
                                        color: backgroundColor
                                        border.color: doctorComboBox.pressed ? primaryColor : borderColor
                                        border.width: 1
                                        radius: radiusSmall
                                    }
                                    
                                    contentItem: Label {
                                        text: doctorComboBox.displayText
                                        font.pixelSize: fontBase
                                        font.family: "Segoe UI"
                                        color: textColor
                                        verticalAlignment: Text.AlignVCenter
                                        leftPadding: marginSmall
                                    }
                                    
                                    delegate: ItemDelegate {
                                        width: doctorComboBox.width
                                        height: baseUnit * 4
                                        
                                        background: Rectangle {
                                            color: parent.hovered ? lightGrayColor : backgroundColor
                                            radius: radiusSmall
                                        }
                                        
                                        contentItem: ColumnLayout {
                                            spacing: marginTiny
                                            
                                            Label {
                                                text: modelData.nombre
                                                font.pixelSize: fontBase
                                                font.bold: true
                                                color: textColor
                                                font.family: "Segoe UI"
                                            }
                                            
                                            Label {
                                                text: modelData.especialidad || "Sin especialidad"
                                                font.pixelSize: fontSmall
                                                color: textSecondaryColor
                                                font.family: "Segoe UI"
                                                visible: modelData.especialidad
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // SEGUNDA FILA: PRECIOS
                        GridLayout {
                            Layout.fillWidth: true
                            columns: width < baseUnit * 60 ? 1 : 2
                            rowSpacing: marginMedium
                            columnSpacing: marginLarge
                            
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: marginSmall
                                
                                Label {
                                    text: "Precio Consulta Normal (Bs):"
                                    font.bold: true
                                    color: textColor
                                    font.pixelSize: fontBase
                                    font.family: "Segoe UI"
                                }
                                TextField {
                                    id: precioNormalField
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: baseUnit * 4.5
                                    placeholderText: "0.00"
                                    validator: DoubleValidator { bottom: 0.0; decimals: 2 }
                                    font.pixelSize: fontBase
                                    font.family: "Segoe UI"
                                    horizontalAlignment: TextInput.AlignRight
                                    background: Rectangle {
                                        color: backgroundColor
                                        border.color: precioNormalField.focus ? successColor : borderColor
                                        border.width: precioNormalField.focus ? 2 : 1
                                        radius: radiusSmall
                                    }
                                    
                                    onTextChanged: {
                                        if (text && !isNaN(parseFloat(text))) {
                                            color = successColor
                                        } else {
                                            color = textColor
                                        }
                                    }
                                }
                            }
                            
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: marginSmall
                                
                                Label {
                                    text: "Precio Consulta Emergencia (Bs):"
                                    font.bold: true
                                    color: textColor
                                    font.pixelSize: fontBase
                                    font.family: "Segoe UI"
                                }
                                TextField {
                                    id: precioEmergenciaField
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: baseUnit * 4.5
                                    placeholderText: "0.00"
                                    validator: DoubleValidator { bottom: 0.0; decimals: 2 }
                                    font.pixelSize: fontBase
                                    font.family: "Segoe UI"
                                    horizontalAlignment: TextInput.AlignRight
                                    background: Rectangle {
                                        color: backgroundColor
                                        border.color: precioEmergenciaField.focus ? warningColor : borderColor
                                        border.width: precioEmergenciaField.focus ? 2 : 1
                                        radius: radiusSmall
                                    }
                                    
                                    onTextChanged: {
                                        if (text && !isNaN(parseFloat(text))) {
                                            color = warningColor
                                        } else {
                                            color = textColor
                                        }
                                    }
                                }
                            }
                        }
                        
                        // TERCERA FILA: DETALLES
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: marginSmall
                            
                            Label {
                                text: "Detalles y Descripción:"
                                font.bold: true
                                color: textColor
                                font.pixelSize: fontBase
                                font.family: "Segoe UI"
                            }
                            ScrollView {
                                Layout.fillWidth: true
                                Layout.preferredHeight: baseUnit * 8
                                clip: true
                                
                                TextArea {
                                    id: detallesField
                                    placeholderText: "Descripción detallada de la especialidad, procedimientos que incluye, requisitos especiales, etc..."
                                    font.pixelSize: fontBase
                                    font.family: "Segoe UI"
                                    wrapMode: TextArea.Wrap
                                    selectByMouse: true
                                    
                                    background: Rectangle {
                                        color: backgroundColor
                                        border.color: detallesField.focus ? primaryColor : borderColor
                                        border.width: detallesField.focus ? 2 : 1
                                        radius: radiusSmall
                                    }
                                }
                            }
                        }
                        
                        // CUARTA FILA: BOTONES
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: marginMedium
                            
                            Item {
                                Layout.fillWidth: true
                            }
                            
                            Button {
                                text: "Cancelar"
                                Layout.preferredWidth: baseUnit * 15
                                Layout.preferredHeight: baseUnit * 5
                                
                                background: Rectangle {
                                    color: parent.pressed ? Qt.darker(surfaceColor, 1.1) : surfaceColor
                                    radius: radiusSmall
                                    border.color: borderColor
                                    border.width: 1
                                }
                                
                                contentItem: Label {
                                    text: parent.text
                                    color: textColor
                                    font.pixelSize: fontBase
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    font.family: "Segoe UI"
                                }
                                
                                onClicked: limpiarFormulario()
                            }
                            
                            Button {
                                text: isEditMode ? "💾 Actualizar Especialidad" : "➕ Crear Especialidad"
                                enabled: nombreField.text.trim() !== "" && !isLoading
                                Layout.preferredWidth: baseUnit * 25
                                Layout.preferredHeight: baseUnit * 5
                                
                                background: Rectangle {
                                    color: parent.enabled ? 
                                           (parent.pressed ? Qt.darker(successColor, 1.2) : successColor) :
                                           Qt.lighter(successColor, 1.5)
                                    radius: radiusSmall
                                }
                                
                                contentItem: Label {
                                    text: isLoading ? "⏳ Procesando..." : parent.text
                                    color: backgroundColor
                                    font.bold: true
                                    font.pixelSize: fontBase
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    font.family: "Segoe UI"
                                }
                                
                                onClicked: {
                                    isLoading = true
                                    guardarEspecialidad()
                                }
                            }
                        }
                    }
                }
                
                // ===== TABLA DE ESPECIALIDADES =====
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: backgroundColor
                    radius: radiusMedium
                    border.color: borderColor
                    border.width: 1
                    
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0
                        
                        // TÍTULO CON CONTADOR
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: baseUnit * 6
                            color: "#f8f9fa"
                            radius: radiusMedium
                            
                            Rectangle {
                                anchors.fill: parent
                                anchors.bottomMargin: radiusMedium
                                color: parent.color
                            }
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: marginMedium
                                
                                Label {
                                    text: "🏥 Especialidades Médicas Registradas"
                                    font.pixelSize: fontMedium
                                    font.bold: true
                                    color: textColor
                                    font.family: "Segoe UI"
                                }
                                
                                Item {
                                    Layout.fillWidth: true
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: baseUnit * 12
                                    Layout.preferredHeight: baseUnit * 4
                                    color: primaryColor
                                    radius: radiusLarge
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "Total: " + especialidadesData.length
                                        color: backgroundColor
                                        font.pixelSize: fontSmall
                                        font.bold: true
                                        font.family: "Segoe UI"
                                    }
                                }
                            }
                        }
                        
                        // ENCABEZADOS
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: baseUnit * 6
                            color: "#e9ecef"
                            border.color: borderColor
                            border.width: 1
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: marginSmall
                                spacing: marginSmall
                                
                                Label {
                                    Layout.preferredWidth: parent.width * 0.18
                                    text: "ESPECIALIDAD"
                                    font.bold: true
                                    font.pixelSize: fontSmall
                                    color: textColor
                                    font.family: "Segoe UI"
                                    horizontalAlignment: Text.AlignHCenter
                                }
                                
                                Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: borderColor }
                                
                                Label {
                                    Layout.preferredWidth: parent.width * 0.18
                                    text: "DOCTOR ASIGNADO"
                                    font.bold: true
                                    font.pixelSize: fontSmall
                                    color: textColor
                                    font.family: "Segoe UI"
                                    horizontalAlignment: Text.AlignHCenter
                                }
                                
                                Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: borderColor }
                                
                                Label {
                                    Layout.preferredWidth: parent.width * 0.22
                                    text: "DETALLES"
                                    font.bold: true
                                    font.pixelSize: fontSmall
                                    color: textColor
                                    font.family: "Segoe UI"
                                    horizontalAlignment: Text.AlignHCenter
                                }
                                
                                Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: borderColor }
                                
                                Label {
                                    Layout.preferredWidth: parent.width * 0.12
                                    text: "PRECIO NORMAL"
                                    font.bold: true
                                    font.pixelSize: fontTiny
                                    color: textColor
                                    font.family: "Segoe UI"
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                }
                                
                                Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: borderColor }
                                
                                Label {
                                    Layout.preferredWidth: parent.width * 0.12
                                    text: "PRECIO EMERGENCIA"
                                    font.bold: true
                                    font.pixelSize: fontTiny
                                    color: textColor
                                    font.family: "Segoe UI"
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                }
                                
                                Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: borderColor }
                                
                                Label {
                                    Layout.preferredWidth: parent.width * 0.18
                                    text: "ACCIONES"
                                    font.bold: true
                                    font.pixelSize: fontSmall
                                    color: textColor
                                    font.family: "Segoe UI"
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }
                        
                        // CONTENIDO
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            
                            ListView {
                                id: especialidadesList
                                model: especialidadesData
                                
                                delegate: Rectangle {
                                    width: ListView.view.width
                                    height: baseUnit * 12
                                    color: index % 2 === 0 ? backgroundColor : "#f8f9fa"
                                    border.color: borderColor
                                    border.width: 1
                                    
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: marginSmall
                                        spacing: marginSmall
                                        
                                        // ESPECIALIDAD
                                        ColumnLayout {
                                            Layout.preferredWidth: parent.width * 0.18
                                            spacing: marginTiny
                                            
                                            Label {
                                                text: modelData.Nombre || "Sin nombre"
                                                font.bold: true
                                                color: primaryColor
                                                font.pixelSize: fontBase
                                                font.family: "Segoe UI"
                                                wrapMode: Text.WordWrap
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                            
                                            Label {
                                                text: "ID: " + (modelData.id || 0)
                                                color: textSecondaryColor
                                                font.pixelSize: fontTiny
                                                font.family: "Segoe UI"
                                            }
                                        }
                                        
                                        Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: borderColor }
                                        
                                        // DOCTOR
                                        ColumnLayout {
                                            Layout.preferredWidth: parent.width * 0.18
                                            spacing: marginTiny
                                            
                                            Label {
                                                text: modelData.nombre_doctor || "Sin doctor asignado"
                                                color: modelData.nombre_doctor ? textColor : textSecondaryColor
                                                font.pixelSize: fontBase
                                                font.family: "Segoe UI"
                                                font.italic: !modelData.nombre_doctor
                                                wrapMode: Text.WordWrap
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }
                                        
                                        Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: borderColor }
                                        
                                        // DETALLES
                                        ScrollView {
                                            Layout.preferredWidth: parent.width * 0.22
                                            Layout.fillHeight: true
                                            clip: true
                                            
                                            Label {
                                                text: modelData.Detalles || "Sin detalles"
                                                color: modelData.Detalles ? textColor : textSecondaryColor
                                                font.pixelSize: fontSmall
                                                font.family: "Segoe UI"
                                                font.italic: !modelData.Detalles
                                                wrapMode: Text.WordWrap
                                                width: parent.width
                                            }
                                        }
                                        
                                        Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: borderColor }
                                        
                                        // PRECIO NORMAL
                                        ColumnLayout {
                                            Layout.preferredWidth: parent.width * 0.12
                                            spacing: marginTiny
                                            
                                            Label {
                                                text: "Bs " + (modelData.Precio_Normal ? modelData.Precio_Normal.toFixed(2) : "0.00")
                                                color: successColor
                                                font.bold: true
                                                font.pixelSize: fontBase
                                                font.family: "Segoe UI"
                                                horizontalAlignment: Text.AlignHCenter
                                                Layout.fillWidth: true
                                            }
                                        }
                                        
                                        Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: borderColor }
                                        
                                        // PRECIO EMERGENCIA
                                        ColumnLayout {
                                            Layout.preferredWidth: parent.width * 0.12
                                            spacing: marginTiny
                                            
                                            Label {
                                                text: "Bs " + (modelData.Precio_Emergencia ? modelData.Precio_Emergencia.toFixed(2) : "0.00")
                                                color: warningColor
                                                font.bold: true
                                                font.pixelSize: fontBase
                                                font.family: "Segoe UI"
                                                horizontalAlignment: Text.AlignHCenter
                                                Layout.fillWidth: true
                                            }
                                        }
                                        
                                        Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: borderColor }
                                        
                                        // ACCIONES
                                        RowLayout {
                                            Layout.preferredWidth: parent.width * 0.18
                                            spacing: marginSmall
                                            Layout.alignment: Qt.AlignHCenter
                                            
                                            Button {
                                                Layout.preferredWidth: baseUnit * 4
                                                Layout.preferredHeight: baseUnit * 4
                                                text: "✏️"
                                                
                                                background: Rectangle {
                                                    color: parent.pressed ? Qt.darker(warningColor, 1.2) : warningColor
                                                    radius: radiusSmall
                                                }
                                                
                                                contentItem: Label {
                                                    text: parent.text
                                                    color: backgroundColor
                                                    font.pixelSize: fontSmall
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                }
                                                
                                                onClicked: editarEspecialidad(modelData)
                                            }
                                            
                                            Button {
                                                Layout.preferredWidth: baseUnit * 4
                                                Layout.preferredHeight: baseUnit * 4
                                                text: "🗑️"
                                                
                                                background: Rectangle {
                                                    color: parent.pressed ? Qt.darker(dangerColor, 1.2) : dangerColor
                                                    radius: radiusSmall
                                                }
                                                
                                                contentItem: Label {
                                                    text: parent.text
                                                    color: backgroundColor
                                                    font.pixelSize: fontSmall
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                }
                                                
                                                onClicked: eliminarEspecialidad(modelData.id)
                                            }
                                            
                                            Button {
                                                Layout.preferredWidth: baseUnit * 4
                                                Layout.preferredHeight: baseUnit * 4
                                                text: "📊"
                                                
                                                background: Rectangle {
                                                    color: parent.pressed ? Qt.darker(primaryColor, 1.2) : primaryColor
                                                    radius: radiusSmall
                                                }
                                                
                                                contentItem: Label {
                                                    text: parent.text
                                                    color: backgroundColor
                                                    font.pixelSize: fontSmall
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                }
                                                
                                                onClicked: {
                                                    if (confiConsultaModel) {
                                                        const consultas = confiConsultaModel.obtenerConsultasAsociadas(modelData.id)
                                                        console.log("Consultas asociadas:", consultas)
                                                        mostrarExito("Consultas asociadas: " + consultas)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // ESTADO VACÍO
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: "transparent"
                            visible: especialidadesData.length === 0
                            
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: marginMedium
                                
                                Label {
                                    text: "🏥"
                                    font.pixelSize: fontTitle * 2
                                    color: textSecondaryColor
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                
                                Label {
                                    text: "No hay especialidades médicas registradas"
                                    color: textColor
                                    font.bold: true
                                    font.pixelSize: fontMedium
                                    Layout.alignment: Qt.AlignHCenter
                                    font.family: "Segoe UI"
                                }
                                
                                Label {
                                    text: "Crea la primera especialidad usando el formulario superior"
                                    color: textSecondaryColor
                                    font.pixelSize: fontBase
                                    Layout.alignment: Qt.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    horizontalAlignment: Text.AlignHCenter
                                    font.family: "Segoe UI"
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // ===== EVENTOS Y INICIALIZACIÓN =====
    Component.onCompleted: {
        console.log("🏥 Componente de configuración de consultas iniciado")
        
        // Inicializar datos si el modelo está disponible
        if (confiConsultaModel) {
            actualizarDatos()
            console.log("✅ Modelo conectado y datos inicializados")
        } else {
            console.log("⚠️ Modelo no disponible al inicializar")
        }
    }
    
    onConfiConsultaModelChanged: {
        if (confiConsultaModel) {
            console.log("🔄 Modelo de consultas disponible, actualizando datos...")
            actualizarDatos()
        }
    }
}