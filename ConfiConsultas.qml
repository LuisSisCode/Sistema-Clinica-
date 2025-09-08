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
    readonly property real baseUnit: Math.min(parent ? parent.width : 800, parent ? parent.height : 600) / 100
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
    property int editingIndex: -1
    property bool isLoading: false
    
    // ===== FUNCIONES PRINCIPALES =====
    function limpiarFormulario() {
        nombreField.text = ""
        precioNormalField.text = ""
        precioEmergenciaField.text = ""
        detallesField.text = ""
        doctorComboBox.currentIndex = 0
        isEditMode = false
        editingId = -1
        editingIndex = -1
    }
    
    function editarEspecialidad(index) {
        if (index >= 0 && index < especialidadesData.length) {
            var especialidad = especialidadesData[index]
            nombreField.text = especialidad.Nombre || ""
            precioNormalField.text = especialidad.Precio_Normal ? especialidad.Precio_Normal.toString() : "150"
            precioEmergenciaField.text = especialidad.Precio_Emergencia ? especialidad.Precio_Emergencia.toString() : "250"
            detallesField.text = especialidad.Detalles || ""
            
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
            editingIndex = index
            console.log("Editando especialidad ID:", editingId)
        }
    }
    
    function eliminarEspecialidad(index) {
        if (index >= 0 && index < especialidadesData.length) {
            var especialidad = especialidadesData[index]
            var especialidadId = especialidad.id
            
            // Eliminar directamente
            if (confiConsultaModel && especialidadId > 0) {
                console.log("Eliminando especialidad ID:", especialidadId)
                confiConsultaModel.eliminarEspecialidad(especialidadId)
            }
        }
    }
    
    function guardarEspecialidad() {
        if (!confiConsultaModel) {
            console.log("Model no disponible")
            return
        }
        
        const nombre = nombreField.text.trim()
        const detalles = detallesField.text.trim()
        const precioNormal = parseFloat(precioNormalField.text) || 150
        const precioEmergencia = parseFloat(precioEmergenciaField.text) || 250
        const idDoctor = doctorComboBox.currentIndex > 0 ? doctorComboBox.model[doctorComboBox.currentIndex].id : 0
        
        if (!nombre) {
            mostrarError("Error de validación", "El nombre de la especialidad es requerido")
            return
        }
        
        if (precioNormal < 0 || precioEmergencia < 0) {
            mostrarError("Error de validación", "Los precios no pueden ser negativos")
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
    
    function refrescarDatos() {
        if (confiConsultaModel) {
            confiConsultaModel.refrescarDatosInmediato()
        }
    }
    
    function mostrarNotificacion(titulo, mensaje, tipo) {
        console.log("[" + tipo.toUpperCase() + "] " + titulo + ": " + mensaje)
        
        // Mostrar notificación visual
        notificacionTexto.text = titulo + ": " + mensaje
        notificacionRectangle.color = tipo === "error" ? dangerColor : 
                                    tipo === "warning" ? warningColor : successColor
        notificacionRectangle.visible = true
        
        // Ocultar después de 3 segundos
        notificacionTimer.restart()
    }
    
    function mostrarError(titulo, mensaje) {
        mostrarNotificacion(titulo, mensaje, "error")
    }
    
    function mostrarExito(mensaje) {
        mostrarNotificacion("Éxito", mensaje, "success")
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
                        text: "Gestiona las especialidades médicas, precios y asigna doctores del sistema"
                        color: backgroundColor
                        font.pixelSize: fontBase * 0.9
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        opacity: 0.95
                        font.family: "Segoe UI"
                    }
                }
                
                // ===== BOTÓN DE REFRESCAR =====
                Button {
                    Layout.preferredWidth: baseUnit * 6
                    Layout.preferredHeight: baseUnit * 6
                    text: "🔄"
                    enabled: confiConsultaModel && !confiConsultaModel.loading
                    
                    background: Rectangle {
                        color: backgroundColor
                        radius: baseUnit * 0.8
                        opacity: parent.pressed ? 0.8 : 1.0
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        color: primaryColor
                        font.pixelSize: baseUnit * 2
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: refrescarDatos()
                }
            }
        }
        
        // ===== NOTIFICACIÓN =====
        Rectangle {
            id: notificacionRectangle
            Layout.fillWidth: true
            Layout.preferredHeight: baseUnit * 4
            color: successColor
            visible: false
            
            Label {
                id: notificacionTexto
                anchors.centerIn: parent
                color: backgroundColor
                font.bold: true
                font.family: "Segoe UI"
            }
            
            Timer {
                id: notificacionTimer
                interval: 3000
                onTriggered: notificacionRectangle.visible = false
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
                
                // ===== FORMULARIO =====
                GroupBox {
                    Layout.fillWidth: true
                    title: isEditMode ? "Editar Especialidad" : "Agregar Nueva Especialidad"
                    enabled: confiConsultaModel && !confiConsultaModel.loading
                    
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
                        
                        // ===== PRIMERA FILA: NOMBRE Y DOCTOR =====
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: marginLarge
                            
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.preferredWidth: parent.width * 0.5
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
                                        border.color: parent.activeFocus ? primaryColor : borderColor
                                        border.width: parent.activeFocus ? 2 : 1
                                        radius: radiusSmall
                                    }
                                }
                            }
                            
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.preferredWidth: parent.width * 0.5
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
                                }
                            }
                        }
                        
                        // ===== SEGUNDA FILA: PRECIOS Y DESCRIPCIÓN =====
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: marginLarge
                            
                            ColumnLayout {
                                Layout.minimumWidth: 120
                                Layout.maximumWidth: 150
                                spacing: marginSmall
                                
                                Label {
                                    text: "Precio Normal: *"
                                    font.bold: true
                                    color: textColor
                                    font.pixelSize: fontBase
                                    font.family: "Segoe UI"
                                }
                                TextField {
                                    id: precioNormalField
                                    Layout.minimumWidth: 120
                                    Layout.maximumWidth: 150
                                    Layout.preferredHeight: baseUnit * 4.5
                                    placeholderText: "150.00"
                                    validator: DoubleValidator { bottom: 0.0; decimals: 2 }
                                    font.pixelSize: fontBase
                                    font.family: "Segoe UI"
                                    horizontalAlignment: TextInput.AlignHCenter
                                    background: Rectangle {
                                        color: backgroundColor
                                        border.color: parent.activeFocus ? primaryColor : borderColor
                                        border.width: parent.activeFocus ? 2 : 1
                                        radius: radiusSmall
                                    }
                                }
                            }
                            
                            ColumnLayout {
                                Layout.minimumWidth: 120
                                Layout.maximumWidth: 150
                                spacing: marginSmall
                                
                                Label {
                                    text: "Precio Emergencia: *"
                                    font.bold: true
                                    color: textColor
                                    font.pixelSize: fontBase
                                    font.family: "Segoe UI"
                                }
                                TextField {
                                    id: precioEmergenciaField
                                    Layout.minimumWidth: 120
                                    Layout.maximumWidth: 150
                                    Layout.preferredHeight: baseUnit * 4.5
                                    placeholderText: "250.00"
                                    validator: DoubleValidator { bottom: 0.0; decimals: 2 }
                                    font.pixelSize: fontBase
                                    font.family: "Segoe UI"
                                    horizontalAlignment: TextInput.AlignHCenter
                                    background: Rectangle {
                                        color: backgroundColor
                                        border.color: parent.activeFocus ? primaryColor : borderColor
                                        border.width: parent.activeFocus ? 2 : 1
                                        radius: radiusSmall
                                    }
                                }
                            }
                            
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: marginSmall
                                
                                Label {
                                    text: "Descripción:"
                                    font.bold: true
                                    color: textColor
                                    font.pixelSize: fontBase
                                    font.family: "Segoe UI"
                                }
                                TextField {
                                    id: detallesField
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: baseUnit * 4.5
                                    placeholderText: "Descripción de la especialidad (opcional)"
                                    font.pixelSize: fontBase
                                    font.family: "Segoe UI"
                                    background: Rectangle {
                                        color: backgroundColor
                                        border.color: parent.activeFocus ? primaryColor : borderColor
                                        border.width: parent.activeFocus ? 2 : 1
                                        radius: radiusSmall
                                    }
                                }
                            }
                        }
                        
                        // ===== TERCERA FILA: BOTONES =====
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: marginMedium
                            
                            Item { Layout.fillWidth: true }
                            
                            RowLayout {
                                spacing: marginMedium
                                
                                Button {
                                    text: "Cancelar"
                                    Layout.preferredWidth: baseUnit * 12
                                    Layout.preferredHeight: baseUnit * 4.5
                                    
                                    background: Rectangle {
                                        color: parent.pressed ? Qt.darker(surfaceColor, 1.1) : surfaceColor
                                        radius: radiusSmall
                                        border.color: borderColor
                                        border.width: 1
                                    }
                                    
                                    contentItem: Label {
                                        text: parent.text
                                        color: textColor
                                        font.pixelSize: fontSmall
                                        font.bold: true
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        font.family: "Segoe UI"
                                    }
                                    
                                    onClicked: limpiarFormulario()
                                }
                                
                                Button {
                                    text: isEditMode ? "💾 Actualizar" : "➕ Agregar"
                                    enabled: nombreField.text.trim() !== "" && 
                                            precioNormalField.text.trim() !== "" && 
                                            precioEmergenciaField.text.trim() !== ""
                                    Layout.preferredWidth: baseUnit * 15
                                    Layout.preferredHeight: baseUnit * 4.5
                                    
                                    background: Rectangle {
                                        color: parent.enabled ? 
                                               (parent.pressed ? Qt.darker(successColor, 1.2) : successColor) :
                                               Qt.lighter(successColor, 1.5)
                                        radius: radiusSmall
                                    }
                                    
                                    contentItem: Label {
                                        text: parent.text
                                        color: backgroundColor
                                        font.bold: true
                                        font.pixelSize: fontSmall
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        font.family: "Segoe UI"
                                    }
                                    
                                    onClicked: guardarEspecialidad()
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
                                
                                Rectangle {
                                    Layout.preferredWidth: baseUnit * 8
                                    Layout.preferredHeight: baseUnit * 3
                                    color: primaryColor
                                    radius: baseUnit * 1.5
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: especialidadesData.length.toString()
                                        color: backgroundColor
                                        font.bold: true
                                        font.pixelSize: fontSmall
                                    }
                                }
                                
                                Item { Layout.fillWidth: true }
                                
                                // INDICADOR DE LOADING
                                Rectangle {
                                    Layout.preferredWidth: baseUnit * 4
                                    Layout.preferredHeight: baseUnit * 4
                                    color: "transparent"
                                    visible: confiConsultaModel && confiConsultaModel.loading
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "⏳"
                                        font.pixelSize: fontBase
                                        
                                        RotationAnimation {
                                            target: parent
                                            from: 0
                                            to: 360
                                            duration: 1000
                                            running: confiConsultaModel && confiConsultaModel.loading
                                            loops: Animation.Infinite
                                        }
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
                                spacing: 1
                                
                                Label {
                                    Layout.preferredWidth: parent.width * 0.08
                                    Layout.fillHeight: true
                                    text: "ID"
                                    font.bold: true
                                    font.pixelSize: fontSmall
                                    color: textColor
                                    font.family: "Segoe UI"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 1
                                    Layout.fillHeight: true
                                    color: borderColor
                                }
                                
                                Label {
                                    Layout.preferredWidth: parent.width * 0.25
                                    Layout.fillHeight: true
                                    text: "ESPECIALIDAD"
                                    font.bold: true
                                    font.pixelSize: fontSmall
                                    color: textColor
                                    font.family: "Segoe UI"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 1
                                    Layout.fillHeight: true
                                    color: borderColor
                                }
                                
                                Label {
                                    Layout.preferredWidth: parent.width * 0.15
                                    Layout.fillHeight: true
                                    text: "P. NORMAL"
                                    font.bold: true
                                    font.pixelSize: fontSmall
                                    color: textColor
                                    font.family: "Segoe UI"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 1
                                    Layout.fillHeight: true
                                    color: borderColor
                                }
                                
                                Label {
                                    Layout.preferredWidth: parent.width * 0.15
                                    Layout.fillHeight: true
                                    text: "P. EMERG."
                                    font.bold: true
                                    font.pixelSize: fontSmall
                                    color: textColor
                                    font.family: "Segoe UI"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 1
                                    Layout.fillHeight: true
                                    color: borderColor
                                }
                                
                                Label {
                                    Layout.preferredWidth: parent.width * 0.22
                                    Layout.fillHeight: true
                                    text: "DETALLES"
                                    font.bold: true
                                    font.pixelSize: fontSmall
                                    color: textColor
                                    font.family: "Segoe UI"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 1
                                    Layout.fillHeight: true
                                    color: borderColor
                                }
                                
                                Label {
                                    Layout.preferredWidth: parent.width * 0.15
                                    Layout.fillHeight: true
                                    text: "ACCIONES"
                                    font.bold: true
                                    font.pixelSize: fontSmall
                                    color: textColor
                                    font.family: "Segoe UI"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
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
                                    height: baseUnit * 8
                                    color: index % 2 === 0 ? backgroundColor : "#f8f9fa"
                                    border.color: borderColor
                                    border.width: 1
                                    
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: marginSmall
                                        spacing: 1
                                        
                                        // ID
                                        Label {
                                            Layout.preferredWidth: parent.width * 0.08
                                            Layout.fillHeight: true
                                            text: modelData.id ? modelData.id.toString() : "N/A"
                                            color: textSecondaryColor
                                            font.pixelSize: fontSmall
                                            font.family: "Segoe UI"
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 1
                                            Layout.fillHeight: true
                                            color: borderColor
                                        }
                                        
                                        // ESPECIALIDAD CON DOCTOR
                                        ColumnLayout {
                                            Layout.preferredWidth: parent.width * 0.25
                                            Layout.fillHeight: true
                                            spacing: marginTiny
                                            
                                            Label {
                                                text: modelData.Nombre || "Sin nombre"
                                                font.bold: true
                                                color: primaryColor
                                                font.pixelSize: fontBase
                                                font.family: "Segoe UI"
                                                horizontalAlignment: Text.AlignLeft
                                                verticalAlignment: Text.AlignVCenter
                                                wrapMode: Text.WordWrap
                                                elide: Text.ElideRight
                                                maximumLineCount: 1
                                                Layout.fillWidth: true
                                                leftPadding: marginSmall
                                            }
                                            
                                            Label {
                                                text: modelData.nombre_doctor || "Sin doctor asignado"
                                                color: modelData.nombre_doctor ? textColor : textSecondaryColor
                                                font.pixelSize: fontTiny
                                                font.family: "Segoe UI"
                                                font.italic: !modelData.nombre_doctor
                                                horizontalAlignment: Text.AlignLeft
                                                verticalAlignment: Text.AlignVCenter
                                                wrapMode: Text.WordWrap
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                                leftPadding: marginSmall
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 1
                                            Layout.fillHeight: true
                                            color: borderColor
                                        }
                                        
                                        // PRECIO NORMAL
                                        Label {
                                            Layout.preferredWidth: parent.width * 0.15
                                            Layout.fillHeight: true
                                            text: "Bs " + (modelData.Precio_Normal ? modelData.Precio_Normal.toFixed(2) : "150.00")
                                            color: successColor
                                            font.bold: true
                                            font.pixelSize: fontSmall
                                            font.family: "Segoe UI"
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 1
                                            Layout.fillHeight: true
                                            color: borderColor
                                        }
                                        
                                        // PRECIO EMERGENCIA
                                        Label {
                                            Layout.preferredWidth: parent.width * 0.15
                                            Layout.fillHeight: true
                                            text: "Bs " + (modelData.Precio_Emergencia ? modelData.Precio_Emergencia.toFixed(2) : "250.00")
                                            color: warningColor
                                            font.bold: true
                                            font.pixelSize: fontSmall
                                            font.family: "Segoe UI"
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 1
                                            Layout.fillHeight: true
                                            color: borderColor
                                        }
                                        
                                        // DETALLES
                                        Label {
                                            Layout.preferredWidth: parent.width * 0.22
                                            Layout.fillHeight: true
                                            text: modelData.Detalles || "Sin detalles"
                                            color: modelData.Detalles ? textColor : textSecondaryColor
                                            font.pixelSize: fontTiny
                                            font.family: "Segoe UI"
                                            font.italic: !modelData.Detalles
                                            horizontalAlignment: Text.AlignLeft
                                            verticalAlignment: Text.AlignVCenter
                                            wrapMode: Text.WordWrap
                                            elide: Text.ElideRight
                                            maximumLineCount: 2
                                            leftPadding: marginSmall
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 1
                                            Layout.fillHeight: true
                                            color: borderColor
                                        }
                                        
                                        // ACCIONES
                                        RowLayout {
                                            Layout.preferredWidth: parent.width * 0.15
                                            Layout.fillHeight: true
                                            spacing: marginSmall
                                            
                                            Button {
                                                Layout.preferredWidth: baseUnit * 3.5
                                                Layout.preferredHeight: baseUnit * 3.5
                                                text: "✏️"
                                                
                                                background: Rectangle {
                                                    color: parent.pressed ? Qt.darker(warningColor, 1.2) : warningColor
                                                    radius: radiusSmall
                                                }
                                                
                                                contentItem: Label {
                                                    text: parent.text
                                                    color: backgroundColor
                                                    font.pixelSize: fontTiny
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                }
                                                
                                                onClicked: editarEspecialidad(index)
                                            }
                                            
                                            Button {
                                                Layout.preferredWidth: baseUnit * 3.5
                                                Layout.preferredHeight: baseUnit * 3.5
                                                text: "🗑️"
                                                
                                                background: Rectangle {
                                                    color: parent.pressed ? Qt.darker(dangerColor, 1.2) : dangerColor
                                                    radius: radiusSmall
                                                }
                                                
                                                contentItem: Label {
                                                    text: parent.text
                                                    color: backgroundColor
                                                    font.pixelSize: fontTiny
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                }
                                                
                                                onClicked: eliminarEspecialidad(index)
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
                            visible: especialidadesData.length === 0 && !isLoading
                            
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
                                    text: "Agrega la primera especialidad usando el formulario superior"
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
    
    // ===== INICIALIZACIÓN =====
    Component.onCompleted: {
        console.log("🏥 Componente de configuración de consultas iniciado")
        console.log("🔍 appController disponible:", appController ? "SÍ" : "NO")
        console.log("🔍 confi_consulta_model_instance disponible:", appController ? (appController.confi_consulta_model_instance ? "SÍ" : "NO") : "N/A")
        console.log("🔍 confiConsultaModel disponible:", confiConsultaModel ? "SÍ" : "NO")
        
        // Inicializar datos si el modelo está disponible
        if (confiConsultaModel) {
            actualizarDatos()
            console.log("✅ Modelo conectado y datos inicializados")
            console.log("🔍 Total especialidades:", especialidadesData.length)
            console.log("🔍 Loading estado:", confiConsultaModel.loading)
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