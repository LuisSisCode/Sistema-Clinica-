import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ClinicaModels 1.0

Item {
    id: configTiposGastosRoot
    
    // ===== CONEXIÓN CON EL MODELO =====
    property var configuracionModel: appController ? appController.configuracion_model_instance : null
    
    // ===== SEÑALES PARA VOLVER =====
    signal volverClicked()
    signal backToMain()
    
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
    property int editingIndex: -1
    
    // ===== CONEXIONES CON EL MODELO =====
    Connections {
        target: configuracionModel
        
        function onTipoGastoCreado(success, message) {
            if (success) {
                limpiarFormulario()
                mostrarNotificacion("Éxito", message, "success")
            } else {
                mostrarNotificacion("Error", message, "error")
            }
        }
        
        function onTipoGastoActualizado(success, message) {
            if (success) {
                limpiarFormulario()
                mostrarNotificacion("Éxito", message, "success")
            } else {
                mostrarNotificacion("Error", message, "error")
            }
        }
        
        function onTipoGastoEliminado(success, message) {
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
        nuevoTipoGastoNombre.text = ""
        nuevoTipoGastoDescripcion.text = ""
        isEditMode = false
        editingId = -1
        editingIndex = -1
    }
    
    function editarTipoGasto(index) {
        if (!configuracionModel || !configuracionModel.tiposGastos) return
        
        var tiposGastos = configuracionModel.tiposGastos
        if (index >= 0 && index < tiposGastos.length) {
            var tipoGasto = tiposGastos[index]
            nuevoTipoGastoNombre.text = tipoGasto.Nombre || ""
            nuevoTipoGastoDescripcion.text = tipoGasto.descripcion || ""
            isEditMode = true
            editingId = tipoGasto.id || -1
            editingIndex = index
            
            console.log("✏️ Editando tipo de gasto:", JSON.stringify(tipoGasto))
        }
    }
    
    function eliminarTipoGasto(index) {
        if (!configuracionModel || !configuracionModel.tiposGastos) return
        
        var tiposGastos = configuracionModel.tiposGastos
        if (index >= 0 && index < tiposGastos.length) {
            var tipoGasto = tiposGastos[index]
            var tipoId = tipoGasto.id
            
            // Mostrar diálogo de confirmación
            confirmarEliminacion(tipoId, tipoGasto.Nombre || "")
        }
    }
    
    function confirmarEliminacion(tipoId, nombre) {
        // Verificar si tiene gastos asociados
        if (configuracionModel) {
            var gastosAsociados = configuracionModel.obtenerGastosAsociados(tipoId)
            
            if (gastosAsociados > 0) {
                mostrarNotificacion(
                    "No se puede eliminar", 
                    "Este tipo de gasto tiene " + gastosAsociados + " gastos asociados",
                    "warning"
                )
                return
            }
            
            // Proceder con eliminación
            console.log("🗑️ Eliminando tipo de gasto ID:", tipoId)
            configuracionModel.eliminarTipoGasto(tipoId)
        }
    }
    
    function guardarTipoGasto() {
        if (!configuracionModel) return
        
        var nombre = nuevoTipoGastoNombre.text.trim()
        var descripcion = nuevoTipoGastoDescripcion.text.trim()
        
        // Validaciones básicas
        if (!nombre) {
            mostrarNotificacion("Error de validación", "El nombre es obligatorio", "error")
            return
        }
        
        if (isEditMode && editingId > 0) {
            // Editar tipo de gasto existente
            console.log("✏️ Actualizando tipo de gasto ID:", editingId)
            configuracionModel.actualizarTipoGasto(editingId, nombre, descripcion)
        } else {
            // Crear nuevo tipo de gasto
            console.log("➕ Creando nuevo tipo de gasto:", nombre)
            configuracionModel.crearTipoGasto(nombre, descripcion)
        }
    }
    
    function refrescarDatos() {
        if (configuracionModel) {
            configuracionModel.refrescarDatosInmediato()
        }
    }
    
    function mostrarNotificacion(titulo, mensaje, tipo) {
        console.log("[" + tipo.toUpperCase() + "] " + titulo + ": " + mensaje)
        
        // Aquí puedes agregar lógica para mostrar notificaciones visuales
        // Por ejemplo, un Toast, ToolTip, o cambiar color de algún elemento
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
                            configTiposGastosRoot.volverClicked()
                            configTiposGastosRoot.backToMain()
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
                        text: "💰"
                        font.pixelSize: fontBase * 1.8
                    }
                }
                
                // ===== INFORMACIÓN DEL MÓDULO =====
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: marginSmall * 0.5
                    
                    Label {
                        text: "Configuración de Tipos de Gastos"
                        color: backgroundColor
                        font.pixelSize: fontBase * 1.4
                        font.bold: true
                        font.family: "Segoe UI"
                    }
                    
                    Label {
                        text: "Gestiona las categorías de gastos operativos y sus configuraciones del sistema"
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
                    enabled: configuracionModel && !configuracionModel.loading
                    
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
                    Layout.minimumHeight: baseUnit * 25  // AGREGAR ALTURA
                    title: ""  // QUITAR EL TÍTULO
                    enabled: configuracionModel && !configuracionModel.loading
                    
                    background: Rectangle {
                        color: backgroundColor
                        border.color: borderColor
                        border.width: 1
                        radius: radiusMedium
                    }
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: marginMedium  // AGREGAR MÁRGENES
                        spacing: marginMedium
                        
                        // TÍTULO PERSONALIZADO
                        Label {
                            text: isEditMode ? "✏️ Editar Tipo de Gasto" : "➕ Agregar Nuevo Tipo de Gasto"
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
                                    text: "Nombre del Tipo de Gasto: *"
                                    font.bold: true
                                    color: textColor
                                    font.pixelSize: fontBase
                                    font.family: "Segoe UI"
                                }
                                TextField {
                                    id: nuevoTipoGastoNombre
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: baseUnit * 4.5
                                    placeholderText: "Ej: Servicios Públicos"
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
                                    id: nuevoTipoGastoDescripcion
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: baseUnit * 4.5
                                    placeholderText: "Descripción del tipo de gasto (opcional)"
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
                        
                        // ===== SEGUNDA FILA: BOTONES =====
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: marginMedium
                            
                            // ESPACIADOR
                            Item {
                                Layout.fillWidth: true
                            }
                            
                            // BOTONES
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
                                    enabled: nuevoTipoGastoNombre.text.trim() !== ""
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
                                    
                                    onClicked: guardarTipoGasto()
                                }
                            }
                        }
                    }
                }
                
                // ===== TABLA DE TIPOS DE GASTOS =====
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
                        
                        // TÍTULO SIN CONTADOR
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
                                    text: "💰 Tipos de Gastos Registrados"
                                    font.pixelSize: fontMedium
                                    font.bold: true
                                    color: textColor
                                    font.family: "Segoe UI"
                                }
                                
                                Item { Layout.fillWidth: true }
                                
                                // INDICADOR DE LOADING
                                Rectangle {
                                    Layout.preferredWidth: baseUnit * 4
                                    Layout.preferredHeight: baseUnit * 4
                                    color: "transparent"
                                    visible: configuracionModel && configuracionModel.loading
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "⏳"
                                        font.pixelSize: fontBase
                                        
                                        RotationAnimation {
                                            target: parent
                                            from: 0
                                            to: 360
                                            duration: 1000
                                            running: configuracionModel && configuracionModel.loading
                                            loops: Animation.Infinite
                                        }
                                    }
                                }
                            }
                        }
                        
                        // ENCABEZADOS SIN COLUMNA GASTOS
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
                                    Layout.preferredWidth: parent.width * 0.1
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
                                    Layout.preferredWidth: parent.width * 0.3
                                    Layout.fillHeight: true
                                    text: "NOMBRE"
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
                                    Layout.preferredWidth: parent.width * 0.4
                                    Layout.fillHeight: true
                                    text: "DESCRIPCIÓN"
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
                                    Layout.preferredWidth: parent.width * 0.2
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
                        
                        // CONTENIDO SIN COLUMNA GASTOS
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            
                            ListView {
                                id: tiposGastosList
                                model: configuracionModel ? configuracionModel.tiposGastos : []
                                
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
                                            Layout.preferredWidth: parent.width * 0.1
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
                                        
                                        Label {
                                            Layout.preferredWidth: parent.width * 0.3
                                            Layout.fillHeight: true
                                            text: modelData.Nombre || "Sin nombre"
                                            font.bold: true
                                            color: primaryColor
                                            font.pixelSize: fontBase
                                            font.family: "Segoe UI"
                                            horizontalAlignment: Text.AlignLeft
                                            verticalAlignment: Text.AlignVCenter
                                            leftPadding: marginSmall
                                            wrapMode: Text.WordWrap
                                            elide: Text.ElideRight
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 1
                                            Layout.fillHeight: true
                                            color: borderColor
                                        }
                                        
                                        Label {
                                            Layout.preferredWidth: parent.width * 0.4
                                            Layout.fillHeight: true
                                            text: modelData.descripcion || "Sin descripción"
                                            color: modelData.descripcion ? textColor : textSecondaryColor
                                            font.pixelSize: fontSmall
                                            font.family: "Segoe UI"
                                            horizontalAlignment: Text.AlignLeft
                                            verticalAlignment: Text.AlignVCenter
                                            leftPadding: marginSmall
                                            wrapMode: Text.WordWrap
                                            elide: Text.ElideRight
                                            maximumLineCount: 2
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 1
                                            Layout.fillHeight: true
                                            color: borderColor
                                        }
                                        
                                        RowLayout {
                                            Layout.preferredWidth: parent.width * 0.2
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
                                                    font.pixelSize: fontSmall
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                }
                                                
                                                onClicked: editarTipoGasto(index)
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
                                                    font.pixelSize: fontSmall
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                }
                                                
                                                onClicked: eliminarTipoGasto(index)
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
                            visible: configuracionModel && configuracionModel.totalTiposGastos === 0 && !configuracionModel.loading
                            
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: marginMedium
                                
                                Label {
                                    text: "💰"
                                    font.pixelSize: fontTitle * 2
                                    color: textSecondaryColor
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                
                                Label {
                                    text: "No hay tipos de gastos registrados"
                                    color: textColor
                                    font.bold: true
                                    font.pixelSize: fontMedium
                                    Layout.alignment: Qt.AlignHCenter
                                    font.family: "Segoe UI"
                                }
                                
                                Label {
                                    text: "Agrega el primer tipo de gasto usando el formulario superior"
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
        //console.log("💰 Componente de configuración de tipos de gastos iniciado")
        if (configuracionModel) {
            console.log("✅ ConfiguracionModel conectado correctamente")
        } else {
            console.log("❌ ConfiguracionModel no disponible")
        }
    }
}