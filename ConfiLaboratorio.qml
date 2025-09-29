import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ClinicaModels 1.0

Item {
    id: configAnalisisRoot
    
    // ===== CONEXIÓN CON EL MODELO =====
    property var confiLaboratorioModel: appController ? appController.confi_laboratorio_model_instance : null
    
    // ===== SEÑALES PARA VOLVER =====
    signal volverClicked()
    signal backToMain()
    
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
    readonly property string primaryColor: "#e91e63"
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
    
    // ===== CONEXIONES CON EL MODELO =====
    Connections {
        target: confiLaboratorioModel
        
        function onTipoAnalisisCreado(success, message) {
            if (success) {
                limpiarFormulario()
                mostrarNotificacion("Éxito", message, "success")
            } else {
                mostrarNotificacion("Error", message, "error")
            }
        }
        
        function onTipoAnalisisActualizado(success, message) {
            if (success) {
                limpiarFormulario()
                mostrarNotificacion("Éxito", message, "success")
            } else {
                mostrarNotificacion("Error", message, "error")
            }
        }
        
        function onTipoAnalisisEliminado(success, message) {
            if (success) {
                mostrarNotificacion("Éxito", message, "success")
            } else {
                mostrarNotificacion("Error", message, "error")
            }
        }
        
        function onErrorOccurred(title, message) {
            mostrarNotificacion(title, message, "error")
        }
        
        function onWarningMessage(message) {
            mostrarNotificacion("Advertencia", message, "warning")
        }
    }
    
    // ===== FUNCIONES MODIFICADAS PARA USAR EL MODELO =====
    function limpiarFormulario() {
        nuevoAnalisisNombre.text = ""
        nuevoAnalisisTipo.text = ""
        nuevoAnalisisPrecioNormal.text = ""
        nuevoAnalisisPrecioEmergencia.text = ""
        isEditMode = false
        editingId = -1
        editingIndex = -1
    }
    
    function editarAnalisis(index) {
        if (!confiLaboratorioModel || !confiLaboratorioModel.tiposAnalisis) return
        
        var tiposAnalisis = confiLaboratorioModel.tiposAnalisis
        if (index >= 0 && index < tiposAnalisis.length) {
            var analisis = tiposAnalisis[index]
            nuevoAnalisisNombre.text = analisis.Nombre || ""
            nuevoAnalisisTipo.text = analisis.Descripcion || ""
            nuevoAnalisisPrecioNormal.text = analisis.Precio_Normal ? analisis.Precio_Normal.toString() : "0"
            nuevoAnalisisPrecioEmergencia.text = analisis.Precio_Emergencia ? analisis.Precio_Emergencia.toString() : "0"
            isEditMode = true
            editingId = analisis.id || -1
            editingIndex = index
            
            console.log("✏️ Editando tipo de análisis:", JSON.stringify(analisis))
        }
    }
    
    function eliminarAnalisis(index) {
        if (!confiLaboratorioModel || !confiLaboratorioModel.tiposAnalisis) return
        
        var tiposAnalisis = confiLaboratorioModel.tiposAnalisis
        if (index >= 0 && index < tiposAnalisis.length) {
            var analisis = tiposAnalisis[index]
            var analisisId = analisis.id
            
            // Mostrar diálogo de confirmación
            confirmarEliminacion(analisisId, analisis.Nombre || "")
        }
    }
    
    function confirmarEliminacion(analisisId, nombre) {
        // Proceder con eliminación directa
        if (confiLaboratorioModel) {
            console.log("🗑️ Eliminando tipo de análisis ID:", analisisId)
            confiLaboratorioModel.eliminarTipoAnalisis(analisisId)
        }
    }
    
    function guardarAnalisis() {
        if (!confiLaboratorioModel) return
        
        var nombre = nuevoAnalisisNombre.text.trim()
        var descripcion = nuevoAnalisisTipo.text.trim()
        var precioNormal = parseFloat(nuevoAnalisisPrecioNormal.text) || 0
        var precioEmergencia = parseFloat(nuevoAnalisisPrecioEmergencia.text) || 0
        
        // Validaciones básicas
        if (!nombre) {
            mostrarNotificacion("Error de validación", "El nombre es obligatorio", "error")
            return
        }
        
        if (precioNormal < 0 || precioEmergencia < 0) {
            mostrarNotificacion("Error de validación", "Los precios no pueden ser negativos", "error")
            return
        }
        
        if (isEditMode && editingId > 0) {
            // Editar tipo de análisis existente
            console.log("✏️ Actualizando tipo de análisis ID:", editingId)
            confiLaboratorioModel.actualizarTipoAnalisis(editingId, nombre, descripcion, precioNormal, precioEmergencia)
        } else {
            // Crear nuevo tipo de análisis
            console.log("➕ Creando nuevo tipo de análisis:", nombre)
            confiLaboratorioModel.crearTipoAnalisis(nombre, descripcion, precioNormal, precioEmergencia)
        }
    }
    
    function refrescarDatos() {
        if (confiLaboratorioModel) {
            confiLaboratorioModel.refrescarDatosInmediato()
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
    
    // ===== LAYOUT PRINCIPAL =====
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        
        // ===== HEADER PRINCIPAL UNIFICADO =====
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
                            configAnalisisRoot.volverClicked()
                            configAnalisisRoot.backToMain()
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
                        text: "🧪"
                        font.pixelSize: fontBase * 1.8
                    }
                }
                
                // ===== INFORMACIÓN DEL MÓDULO =====
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: marginSmall * 0.5
                    
                    Label {
                        text: "Configuración de Tipos de Análisis de Laboratorio"
                        color: backgroundColor
                        font.pixelSize: fontBase * 1.4
                        font.bold: true
                        font.family: "Segoe UI"
                    }
                    
                    Label {
                        text: "Gestiona los tipos de análisis de laboratorio, categorías y precios del sistema"
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
                    enabled: confiLaboratorioModel && !confiLaboratorioModel.loading
                    
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
                    Layout.minimumHeight: baseUnit * 30
                    title: "" // QUITAR EL TÍTULO DEL GROUPBOX
                    enabled: confiLaboratorioModel && !confiLaboratorioModel.loading
                    
                    background: Rectangle {
                        color: backgroundColor
                        border.color: borderColor
                        border.width: 1
                        radius: radiusMedium
                    }
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: marginMedium  
                        spacing: marginMedium
                        
                        // TÍTULO PERSONALIZADO
                        Label {
                            text: isEditMode ? "✏️ Editar Tipo de Análisis" : "➕ Agregar Nuevo Tipo de Análisis"
                            font.pixelSize: fontLarge
                            font.bold: true
                            color: primaryColor
                            font.family: "Segoe UI"
                            Layout.fillWidth: true
                        }
                        
                        // ===== PRIMERA FILA: NOMBRE Y DESCRIPCIÓN =====
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: marginLarge
                            
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.preferredWidth: parent.width * 0.5
                                spacing: marginSmall
                                
                                Label {
                                    text: "Nombre del Análisis: *"
                                    font.bold: true
                                    color: textColor
                                    font.pixelSize: fontBase
                                    font.family: "Segoe UI"
                                }

                                TextField {
                                    id: nuevoAnalisisNombre
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: baseUnit * 4.5
                                    placeholderText: "Ej: Hemograma Completo"
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
                                    text: "Descripción:"
                                    font.bold: true
                                    color: textColor
                                    font.pixelSize: fontBase
                                    font.family: "Segoe UI"
                                }
                                TextField {
                                    id: nuevoAnalisisTipo
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: baseUnit * 4.5
                                    placeholderText: "Descripción del análisis (opcional)"
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
                        
                        // ===== SEGUNDA FILA: PRECIOS Y BOTONES =====
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: marginMedium
                            
                            // PRECIO NORMAL
                            ColumnLayout {
                                Layout.preferredWidth: 120
                                spacing: marginSmall
                                
                                Label {
                                    text: "Precio Normal: *"
                                    font.bold: true
                                    color: textColor
                                    font.pixelSize: fontSmall
                                    font.family: "Segoe UI"
                                }
                                TextField {
                                    id: nuevoAnalisisPrecioNormal
                                    Layout.preferredWidth: 120
                                    Layout.preferredHeight: baseUnit * 4.5
                                    placeholderText: "0.00"
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
                            
                            // PRECIO EMERGENCIA
                            ColumnLayout {
                                Layout.preferredWidth: 120
                                spacing: marginSmall
                                
                                Label {
                                    text: "Precio Emergencia: *"
                                    font.bold: true
                                    color: textColor
                                    font.pixelSize: fontSmall
                                    font.family: "Segoe UI"
                                }
                                TextField {
                                    id: nuevoAnalisisPrecioEmergencia
                                    Layout.preferredWidth: 120
                                    Layout.preferredHeight: baseUnit * 4.5
                                    placeholderText: "0.00"
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
                            
                            // ESPACIADOR
                            Item {
                                Layout.fillWidth: true
                            }
                            
                            // BOTONES
                            ColumnLayout {
                                Layout.preferredWidth: baseUnit * 20
                                spacing: marginSmall
                                
                                Label {
                                    text: " " // Espaciador para alinear con otros campos
                                    font.pixelSize: fontSmall
                                }
                                
                                RowLayout {
                                    spacing: marginSmall
                                    
                                    Button {
                                        text: "Cancelar"
                                        Layout.preferredWidth: baseUnit * 8
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
                                            font.pixelSize: fontTiny
                                            font.bold: true
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            font.family: "Segoe UI"
                                        }
                                        
                                        onClicked: limpiarFormulario()
                                    }
                                    
                                    Button {
                                        text: isEditMode ? "💾 Actualizar" : "➕ Agregar"
                                        enabled: nuevoAnalisisNombre.text.trim() !== "" && 
                                                nuevoAnalisisPrecioNormal.text.trim() !== "" && 
                                                nuevoAnalisisPrecioEmergencia.text.trim() !== ""
                                        Layout.preferredWidth: baseUnit * 10
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
                                            font.pixelSize: fontTiny
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            font.family: "Segoe UI"
                                        }
                                        
                                        onClicked: guardarAnalisis()
                                    }
                                }
                            }
                        }
                    }
                }
                
                // ===== TABLA DE ANÁLISIS =====
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
                                    text: "🧪 Tipos de Análisis Registrados"
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
                                        text: confiLaboratorioModel ? confiLaboratorioModel.totalTiposAnalisis.toString() : "0"
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
                                    visible: confiLaboratorioModel && confiLaboratorioModel.loading
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "⏳"
                                        font.pixelSize: fontBase
                                        
                                        RotationAnimation {
                                            target: parent
                                            from: 0
                                            to: 360
                                            duration: 1000
                                            running: confiLaboratorioModel && confiLaboratorioModel.loading
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
                                    Layout.preferredWidth: parent.width * 0.22
                                    Layout.fillHeight: true
                                    text: "ANÁLISIS"
                                    font.bold: true
                                    font.pixelSize: fontTiny
                                    color: textColor
                                    font.family: "Segoe UI"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    wrapMode: Text.WordWrap
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 1
                                    Layout.fillHeight: true
                                    color: borderColor
                                }
                                
                                Label {
                                    Layout.preferredWidth: parent.width * 0.25
                                    Layout.fillHeight: true
                                    text: "DESCRIPCIÓN"
                                    font.bold: true
                                    font.pixelSize: fontTiny
                                    color: textColor
                                    font.family: "Segoe UI"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    wrapMode: Text.WordWrap
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 1
                                    Layout.fillHeight: true
                                    color: borderColor
                                }
                                
                                Label {
                                    Layout.preferredWidth: parent.width * 0.12
                                    Layout.fillHeight: true
                                    text: "P. NORMAL"
                                    font.bold: true
                                    font.pixelSize: fontTiny
                                    color: textColor
                                    font.family: "Segoe UI"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    wrapMode: Text.WordWrap
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 1
                                    Layout.fillHeight: true
                                    color: borderColor
                                }
                                
                                Label {
                                    Layout.preferredWidth: parent.width * 0.12
                                    Layout.fillHeight: true
                                    text: "P. EMERG."
                                    font.bold: true
                                    font.pixelSize: fontTiny
                                    color: textColor
                                    font.family: "Segoe UI"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    wrapMode: Text.WordWrap
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 1
                                    Layout.fillHeight: true
                                    color: borderColor
                                }
                                
                                Label {
                                    Layout.preferredWidth: parent.width * 0.17
                                    Layout.fillHeight: true
                                    text: "ACCIONES"
                                    font.bold: true
                                    font.pixelSize: fontTiny
                                    color: textColor
                                    font.family: "Segoe UI"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                        
                        // CONTENIDO
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            
                            ListView {
                                id: analisisList
                                model: confiLaboratorioModel ? confiLaboratorioModel.tiposAnalisis : []
                                
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
                                        
                                        Label {
                                            Layout.preferredWidth: parent.width * 0.22
                                            Layout.fillHeight: true
                                            text: modelData.Nombre || "Sin nombre"
                                            font.bold: true
                                            color: primaryColor
                                            font.pixelSize: fontSmall
                                            font.family: "Segoe UI"
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            wrapMode: Text.WordWrap
                                            elide: Text.ElideRight
                                            maximumLineCount: 2
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 1
                                            Layout.fillHeight: true
                                            color: borderColor
                                        }
                                        
                                        Label {
                                            Layout.preferredWidth: parent.width * 0.25
                                            Layout.fillHeight: true
                                            text: modelData.Descripcion || "Sin descripción"
                                            color: modelData.Descripcion ? textColor : textSecondaryColor
                                            font.pixelSize: fontTiny
                                            font.family: "Segoe UI"
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            wrapMode: Text.WordWrap
                                            elide: Text.ElideRight
                                            maximumLineCount: 3
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 1
                                            Layout.fillHeight: true
                                            color: borderColor
                                        }
                                        
                                        Label {
                                            Layout.preferredWidth: parent.width * 0.12
                                            Layout.fillHeight: true
                                            text: "Bs " + (modelData.Precio_Normal ? modelData.Precio_Normal.toFixed(2) : "0.00")
                                            color: successColor
                                            font.bold: true
                                            font.pixelSize: fontTiny
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
                                            Layout.preferredWidth: parent.width * 0.12
                                            Layout.fillHeight: true
                                            text: "Bs " + (modelData.Precio_Emergencia ? modelData.Precio_Emergencia.toFixed(2) : "0.00")
                                            color: warningColor
                                            font.bold: true
                                            font.pixelSize: fontTiny
                                            font.family: "Segoe UI"
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 1
                                            Layout.fillHeight: true
                                            color: borderColor
                                        }
                                        
                                        RowLayout {
                                            Layout.preferredWidth: parent.width * 0.17
                                            Layout.fillHeight: true
                                            spacing: marginTiny
                                            
                                            Button {
                                                Layout.preferredWidth: baseUnit * 3
                                                Layout.preferredHeight: baseUnit * 3
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
                                                
                                                onClicked: editarAnalisis(index)
                                            }
                                            
                                            Button {
                                                Layout.preferredWidth: baseUnit * 3
                                                Layout.preferredHeight: baseUnit * 3
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
                                                
                                                onClicked: eliminarAnalisis(index)
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
                            visible: confiLaboratorioModel && confiLaboratorioModel.totalTiposAnalisis === 0 && !confiLaboratorioModel.loading
                            
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: marginMedium
                                
                                Label {
                                    text: "🧪"
                                    font.pixelSize: fontTitle * 2
                                    color: textSecondaryColor
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                
                                Label {
                                    text: "No hay tipos de análisis registrados"
                                    color: textColor
                                    font.bold: true
                                    font.pixelSize: fontMedium
                                    Layout.alignment: Qt.AlignHCenter
                                    font.family: "Segoe UI"
                                }
                                
                                Label {
                                    text: "Agrega el primer tipo de análisis usando el formulario superior"
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
}