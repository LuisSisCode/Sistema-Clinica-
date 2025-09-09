import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: confiTrabajadoresRoot
    
    // ===== CONEXIÓN CON EL MODELO =====
    property var confiTrabajadoresModel: appController.confi_trabajadores_model_instance
    property var trabajadorModel: appController.trabajador_model_instance
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
    readonly property string primaryColor: "#7C3AED"
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
    property int editingIndex: -1
    property int editingId: -1
    
    // ===== CONEXIONES CON SEÑALES DEL MODELO =====
    Connections {
        target: confiTrabajadoresModel
        
        function onTipoTrabajadorCreado(success, message) {
            if (success) {
                limpiarFormulario()
                showSuccessMessage("Tipo de trabajador creado exitosamente")
            } else {
                showErrorMessage("Error al crear tipo de trabajador: " + message)
            }
        }
        
        function onTipoTrabajadorActualizado(success, message) {
            if (success) {
                limpiarFormulario()
                showSuccessMessage("Tipo de trabajador actualizado exitosamente")
            } else {
                showErrorMessage("Error al actualizar tipo de trabajador: " + message)
            }
        }
        
        function onTipoTrabajadorEliminado(success, message) {
            if (success) {
                showSuccessMessage("Tipo de trabajador eliminado exitosamente")
            } else {
                showErrorMessage("Error al eliminar tipo de trabajador: " + message)
            }
        }
        
        function onErrorOccurred(title, message) {
            showErrorMessage(title + ": " + message)
        }
        
        function onSuccessMessage(message) {
            showSuccessMessage(message)
        }
    }
    
    // ===== FUNCIONES =====
    function limpiarFormulario() {
        nuevoTipoNombre.text = ""
        nuevoTipoDescripcion.text = ""
        isEditMode = false
        editingIndex = -1
        editingId = -1
    }
    
    function editarTipoTrabajador(index, tipoData) {
        nuevoTipoNombre.text = tipoData.Tipo || ""
        nuevoTipoDescripcion.text = tipoData.descripcion || ""
        isEditMode = true
        editingIndex = index
        editingId = tipoData.id || -1
    }
    
    function eliminarTipoTrabajador(tipoData) {
        if (confiTrabajadoresModel) {
            // Verificar si hay trabajadores asociados
            var asociados = confiTrabajadoresModel.obtenerTrabajadoresAsociados(tipoData.id)
            if (asociados > 0) {
                showErrorMessage("No se puede eliminar. Tiene " + asociados + " trabajadores asociados")
                return
            }
            
            confiTrabajadoresModel.eliminarTipoTrabajador(tipoData.id)
        }
    }
    
    function guardarTipoTrabajador() {
        if (!confiTrabajadoresModel) {
            showErrorMessage("Modelo no disponible")
            return
        }
        
        var tipo = nuevoTipoNombre.text.trim()
        var descripcion = nuevoTipoDescripcion.text.trim()
        
        if (!tipo) {
            showErrorMessage("El nombre del tipo es obligatorio")
            return
        }
        
        // Validar tipo único
        if (!confiTrabajadoresModel.validarTipoUnico(tipo, editingId)) {
            showErrorMessage("Ya existe un tipo de trabajador con ese nombre")
            return
        }
        
        if (isEditMode && editingId > 0) {
            // Editar tipo existente
            confiTrabajadoresModel.actualizarTipoTrabajador(editingId, tipo, descripcion)
        } else {
            // Agregar nuevo tipo
            confiTrabajadoresModel.crearTipoTrabajador(tipo, descripcion)
        }
    }
    
    function showSuccessMessage(message) {
        // Implementar notificación de éxito
        console.log("✅ Éxito:", message)
    }
    
    function showErrorMessage(message) {
        // Implementar notificación de error
        console.log("❌ Error:", message)
    }
    
    function aplicarFiltros() {
        if (confiTrabajadoresModel) {
            confiTrabajadoresModel.aplicarFiltros(campoBusqueda.text)
        }
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
                            confiTrabajadoresRoot.volverClicked()
                            confiTrabajadoresRoot.backToMain()
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
                        text: "👥"
                        font.pixelSize: fontBase * 1.8
                    }
                }
                
                // ===== INFORMACIÓN DEL MÓDULO =====
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: marginSmall * 0.5
                    
                    Label {
                        text: "Configuración de Tipos de Trabajadores"
                        color: backgroundColor
                        font.pixelSize: fontBase * 1.4
                        font.bold: true
                        font.family: "Segoe UI"
                    }
                    
                    Label {
                        text: "Gestiona los tipos de personal del sistema"
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
                                text: confiTrabajadoresModel ? confiTrabajadoresModel.totalTiposTrabajadores.toString() : "0"
                                color: primaryColor
                                font.pixelSize: fontMedium
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                Layout.fillWidth: true
                            }
                            
                            Label {
                                text: "Tipos Registrados"
                                color: textColor
                                font.pixelSize: fontTiny
                                horizontalAlignment: Text.AlignHCenter
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
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
                            color: textSecondaryColor
                        }
                        
                        TextField {
                            id: campoBusqueda
                            Layout.fillWidth: true
                            placeholderText: "Buscar tipos de trabajadores..."
                            font.pixelSize: fontBase
                            
                            background: Rectangle {
                                color: "transparent"
                            }
                            
                            onTextChanged: {
                                aplicarFiltros()
                            }
                        }
                        
                        Button {
                            text: "Limpiar"
                            visible: campoBusqueda.text.length > 0
                            
                            background: Rectangle {
                                color: parent.pressed ? Qt.darker(surfaceColor, 1.1) : surfaceColor
                                radius: radiusSmall
                                border.color: borderColor
                                border.width: 1
                            }
                            
                            onClicked: {
                                campoBusqueda.text = ""
                                if (confiTrabajadoresModel) {
                                    confiTrabajadoresModel.limpiarFiltros()
                                }
                            }
                        }
                    }
                }
                
                // ===== FORMULARIO SUPERIOR =====
                GroupBox {
                    Layout.fillWidth: true
                    title: isEditMode ? "Editar Tipo de Trabajador" : "Agregar Nuevo Tipo de Trabajador"
                    
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
                        
                        // CAMPOS PRINCIPALES
                        GridLayout {
                            Layout.fillWidth: true
                            columns: width < baseUnit * 80 ? 1 : 2
                            rowSpacing: marginMedium
                            columnSpacing: marginLarge
                            
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: marginSmall
                                
                                Label {
                                    text: "Nombre del Tipo:"
                                    font.bold: true
                                    color: textColor
                                    font.pixelSize: fontBase
                                    font.family: "Segoe UI"
                                }
                                TextField {
                                    id: nuevoTipoNombre
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: baseUnit * 4.5
                                    placeholderText: "Ej: Médico General"
                                    font.pixelSize: fontBase
                                    font.family: "Segoe UI"
                                    background: Rectangle {
                                        color: backgroundColor
                                        border.color: borderColor
                                        border.width: 1
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
                                    id: nuevoTipoDescripcion
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: baseUnit * 4.5
                                    placeholderText: "Ej: Profesional médico con título universitario"
                                    font.pixelSize: fontBase
                                    font.family: "Segoe UI"
                                    background: Rectangle {
                                        color: backgroundColor
                                        border.color: borderColor
                                        border.width: 1
                                        radius: radiusSmall
                                    }
                                }
                            }
                        }
                        
                        // BOTONES
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: marginMedium
                            
                            Item { Layout.fillWidth: true }
                            
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
                                enabled: nuevoTipoNombre.text.trim().length > 0 && !confiTrabajadoresModel.loading
                                Layout.preferredWidth: baseUnit * 15
                                Layout.preferredHeight: baseUnit * 4.5
                                
                                background: Rectangle {
                                    color: parent.enabled ? 
                                           (parent.pressed ? Qt.darker(successColor, 1.2) : successColor) :
                                           Qt.lighter(successColor, 1.5)
                                    radius: radiusSmall
                                }
                                
                                contentItem: Label {
                                    text: confiTrabajadoresModel && confiTrabajadoresModel.loading ? "⏳ Guardando..." : parent.text
                                    color: backgroundColor
                                    font.bold: true
                                    font.pixelSize: fontSmall
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    font.family: "Segoe UI"
                                }
                                
                                onClicked: guardarTipoTrabajador()
                            }
                        }
                    }
                }
                
                // ===== TABLA INFERIOR =====
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
                        
                        // TÍTULO
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
                            
                            Label {
                                anchors.centerIn: parent
                                text: "👥 Tipos de Trabajadores Registrados"
                                font.pixelSize: fontMedium
                                font.bold: true
                                color: textColor
                                font.family: "Segoe UI"
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
                                    Layout.preferredWidth: parent.width * 0.35
                                    text: "TIPO"
                                    font.bold: true
                                    font.pixelSize: fontSmall
                                    color: textColor
                                    font.family: "Segoe UI"
                                    horizontalAlignment: Text.AlignHCenter
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 1
                                    Layout.fillHeight: true
                                    color: borderColor
                                }
                                
                                Label {
                                    Layout.preferredWidth: parent.width * 0.45
                                    text: "DESCRIPCIÓN"
                                    font.bold: true
                                    font.pixelSize: fontSmall
                                    color: textColor
                                    font.family: "Segoe UI"
                                    horizontalAlignment: Text.AlignHCenter
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 1
                                    Layout.fillHeight: true
                                    color: borderColor
                                }
                                
                                Label {
                                    Layout.preferredWidth: parent.width * 0.20
                                    text: "ACCIONES"
                                    font.bold: true
                                    font.pixelSize: fontSmall
                                    color: textColor
                                    font.family: "Segoe UI"
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }
                        
                        // CONTENIDO CON SCROLLVIEW
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            
                            ListView {
                                id: listaTiposTrabajadores
                                model: confiTrabajadoresModel ? confiTrabajadoresModel.tiposTrabajadores : []
                                
                                delegate: Rectangle {
                                    width: ListView.view.width
                                    height: baseUnit * 8
                                    color: index % 2 === 0 ? backgroundColor : "#f8f9fa"
                                    border.color: borderColor
                                    border.width: 1
                                    
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: marginSmall
                                        spacing: marginSmall
                                        
                                        Label {
                                            Layout.preferredWidth: parent.width * 0.35
                                            text: modelData.Tipo || "Sin nombre"
                                            font.bold: true
                                            color: primaryColor
                                            font.pixelSize: fontBase
                                            font.family: "Segoe UI"
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            wrapMode: Text.WordWrap
                                            elide: Text.ElideRight
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: 1
                                            Layout.fillHeight: true
                                            color: borderColor
                                        }
                                        
                                        Label {
                                            Layout.preferredWidth: parent.width * 0.45
                                            text: modelData.descripcion || "Sin descripción"
                                            color: textColor
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
                                        
                                        RowLayout {
                                            Layout.preferredWidth: parent.width * 0.20
                                            Layout.alignment: Qt.AlignHCenter
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
                                                
                                                onClicked: editarTipoTrabajador(index, modelData)
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
                                                
                                                onClicked: eliminarTipoTrabajador(modelData)
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
                            visible: confiTrabajadoresModel ? confiTrabajadoresModel.totalTiposTrabajadores === 0 : true
                            
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: marginMedium
                                
                                Label {
                                    text: "👥"
                                    font.pixelSize: fontTitle * 2
                                    color: textSecondaryColor
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                
                                Label {
                                    text: "No hay tipos de trabajadores registrados"
                                    color: textColor
                                    font.bold: true
                                    font.pixelSize: fontMedium
                                    Layout.alignment: Qt.AlignHCenter
                                    font.family: "Segoe UI"
                                }
                                
                                Label {
                                    text: "Agrega el primer tipo de trabajador usando el formulario superior"
                                    color: textSecondaryColor
                                    font.pixelSize: fontBase
                                    Layout.alignment: Qt.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    horizontalAlignment: Text.AlignHCenter
                                    font.family: "Segoe UI"
                                }
                            }
                        }
                        
                        // INDICADOR DE CARGA
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: "transparent"
                            visible: confiTrabajadoresModel ? confiTrabajadoresModel.loading : false
                            
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: marginMedium
                                
                                Label {
                                    text: "⏳"
                                    font.pixelSize: fontTitle * 2
                                    color: primaryColor
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                
                                Label {
                                    text: "Cargando tipos de trabajadores..."
                                    color: textColor
                                    font.bold: true
                                    font.pixelSize: fontMedium
                                    Layout.alignment: Qt.AlignHCenter
                                    font.family: "Segoe UI"
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // ===== EVENTOS =====
    Component.onCompleted: {
        console.log("👥 Componente de configuración de tipos de trabajadores iniciado")
        
        // Cargar datos iniciales si el modelo está disponible
        if (confiTrabajadoresModel) {
            confiTrabajadoresModel.recargarDatos()
        }
    }
}