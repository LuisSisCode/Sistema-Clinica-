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
    
    // ✅ NUEVO: Mapeo de íconos por área funcional
    function obtenerIconoArea(area) {
        const iconos = {
            'MEDICO': '⚕️',
            'LABORATORIO': '🔬',
            'ENFERMERIA': '💉',
            'ADMINISTRATIVO': '📋',
            'FARMACIA': '💊'
        }
        return iconos[area] || '👷'
    }
    
    function obtenerColorArea(area) {
        const colores = {
            'MEDICO': '#3B82F6',
            'LABORATORIO': '#8B5CF6',
            'ENFERMERIA': '#EC4899',
            'ADMINISTRATIVO': '#6B7280',
            'FARMACIA': '#10B981'
        }
        return colores[area] || '#9CA3AF'
    }
    
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
        areaFuncionalCombo.currentIndex = 0  // ✅ NUEVO
        isEditMode = false
        editingIndex = -1
        editingId = -1
    }
    
    function editarTipoTrabajador(index, tipoData) {
        nuevoTipoNombre.text = tipoData.Tipo || ""
        nuevoTipoDescripcion.text = tipoData.descripcion || ""
        
        // ✅ NUEVO: Seleccionar área funcional
        var area = tipoData.area_funcional
        if (area) {
            var areasDisponibles = ['MEDICO', 'LABORATORIO', 'ENFERMERIA', 'FARMACIA', 'ADMINISTRATIVO']
            var indexArea = areasDisponibles.indexOf(area)
            if (indexArea !== -1) {
                areaFuncionalCombo.currentIndex = indexArea + 1
            } else {
                areaFuncionalCombo.currentIndex = 0
            }
        } else {
            areaFuncionalCombo.currentIndex = 0
        }
        
        isEditMode = true
        editingIndex = index
        editingId = tipoData.id
    }
    
    function guardarTipoTrabajador() {
        var tipo = nuevoTipoNombre.text.trim()
        var descripcion = nuevoTipoDescripcion.text.trim()
        
        // ✅ NUEVO: Obtener área funcional seleccionada
        var areaIndex = areaFuncionalCombo.currentIndex
        var areaFuncional = ""
        if (areaIndex > 0) {
            var areasDisponibles = ['MEDICO', 'LABORATORIO', 'ENFERMERIA', 'FARMACIA', 'ADMINISTRATIVO']
            areaFuncional = areasDisponibles[areaIndex - 1]
        }
        
        if (tipo.length === 0) {
            showErrorMessage("El nombre del tipo es obligatorio")
            return
        }
        
        // ✅ NUEVO: Validar que se haya seleccionado un área
        if (areaFuncional === "") {
            showErrorMessage("Debe seleccionar una categoría funcional")
            return
        }
        
        if (confiTrabajadoresModel) {
            if (isEditMode && editingId > 0) {
                // ✅ ACTUALIZADO: Incluir área funcional
                confiTrabajadoresModel.actualizarTipoTrabajador(editingId, tipo, descripcion, areaFuncional)
            } else {
                // ✅ ACTUALIZADO: Incluir área funcional
                confiTrabajadoresModel.crearTipoTrabajador(tipo, descripcion, areaFuncional)
            }
        }
    }
    
    function aplicarFiltros() {
        var busqueda = campoBusqueda.text.trim()
        if (confiTrabajadoresModel) {
            confiTrabajadoresModel.aplicarFiltros(busqueda)
        }
    }
    
    function eliminarTipoTrabajador(tipoId, tipoNombre) {
        // Verificar si tiene trabajadores asociados
        if (confiTrabajadoresModel) {
            var count = confiTrabajadoresModel.obtenerTrabajadoresAsociados(tipoId)
            if (count > 0) {
                showErrorMessage("No se puede eliminar el tipo '" + tipoNombre + "' porque tiene " + count + " trabajadores asociados")
                return
            }
        }
        
        confirmDeleteDialog.tipoId = tipoId
        confirmDeleteDialog.tipoNombre = tipoNombre
        confirmDeleteDialog.open()
    }
    
    function confirmarEliminacion() {
        if (confiTrabajadoresModel && confirmDeleteDialog.tipoId > 0) {
            confiTrabajadoresModel.eliminarTipoTrabajador(confirmDeleteDialog.tipoId)
        }
    }
    
    // ===== FUNCIONES DE MENSAJES =====
    property alias messageText: messageLabel.text
    property alias messageColor: messageRect.color
    property bool showMessage: false
    
    function showSuccessMessage(msg) {
        messageLabel.text = "✅ " + msg
        messageRect.color = successColor
        showMessage = true
        messageTimer.restart()
    }
    
    function showErrorMessage(msg) {
        messageLabel.text = "❌ " + msg
        messageRect.color = dangerColor
        showMessage = true
        messageTimer.restart()
    }
    
    Timer {
        id: messageTimer
        interval: 3000
        onTriggered: showMessage = false
    }
    
    // ===== LAYOUT PRINCIPAL =====
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        
        // ===== ENCABEZADO MODERNO =====
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: baseUnit * 14
            color: primaryColor
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: marginMedium
                spacing: marginMedium
                
                // ===== BOTÓN VOLVER =====
                Button {
                    Layout.preferredWidth: baseUnit * 8
                    Layout.preferredHeight: baseUnit * 8
                    
                    background: Rectangle {
                        color: parent.pressed ? Qt.lighter(primaryColor, 1.3) : Qt.lighter(primaryColor, 1.1)
                        radius: radiusMedium
                        opacity: parent.hovered ? 1.0 : 0.9
                    }
                    
                    contentItem: Label {
                        text: "←"
                        font.pixelSize: fontMedium * 1.5
                        color: backgroundColor
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
                        text: "Gestiona los tipos de personal y sus categorías funcionales"
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
                    Layout.minimumHeight: baseUnit * 32  // ✅ AUMENTADO PARA EL NUEVO CAMPO
                    title: ""
                    
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
                            text: isEditMode ? "✏️ Editar Tipo de Trabajador" : "➕ Agregar Nuevo Tipo de Trabajador"
                            font.pixelSize: fontLarge
                            font.bold: true
                            color: primaryColor
                            font.family: "Segoe UI"
                            Layout.fillWidth: true
                        }
                        
                        // CAMPOS PRINCIPALES
                        GridLayout {
                            Layout.fillWidth: true
                            columns: width < baseUnit * 80 ? 1 : 2
                            rowSpacing: marginMedium
                            columnSpacing: marginLarge
                            
                            // ✅ CAMPO: Nombre del Tipo
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: marginSmall
                                
                                Label {
                                    text: "Nombre del Tipo: *"
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
                                        border.color: nuevoTipoNombre.activeFocus ? primaryColor : borderColor
                                        border.width: nuevoTipoNombre.activeFocus ? 2 : 1
                                        radius: radiusSmall
                                    }
                                }
                            }
                            
                            // ✅ NUEVO: Campo Categoría Funcional
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: marginSmall
                                
                                RowLayout {
                                    spacing: marginSmall
                                    
                                    Label {
                                        text: "Categoría Funcional: *"
                                        font.bold: true
                                        color: textColor
                                        font.pixelSize: fontBase
                                        font.family: "Segoe UI"
                                    }
                                    
                                    Label {
                                        text: "ⓘ"
                                        font.pixelSize: fontSmall
                                        color: textSecondaryColor
                                        
                                        ToolTip {
                                            text: "Esta categoría determina en qué módulos del sistema aparecerá este tipo de trabajador"
                                            visible: parent.hovered
                                            delay: 500
                                        }
                                        
                                        MouseArea {
                                            id: tooltipArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            property bool hovered: false
                                            onEntered: hovered = true
                                            onExited: hovered = false
                                        }
                                    }
                                }
                                
                                ComboBox {
                                    id: areaFuncionalCombo
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: baseUnit * 4.5
                                    font.pixelSize: fontBase
                                    font.family: "Segoe UI"
                                    
                                    model: [
                                        "Seleccionar categoría...",
                                        "⚕️  Médico (Consultas)",
                                        "🔬 Laboratorista",
                                        "💉 Enfermero",
                                        "💊 Farmacia",
                                        "📋 Administrativo"
                                    ]
                                    
                                    delegate: ItemDelegate {
                                        width: areaFuncionalCombo.width
                                        contentItem: Text {
                                            text: modelData
                                            color: textColor
                                            font: areaFuncionalCombo.font
                                            elide: Text.ElideRight
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        highlighted: areaFuncionalCombo.highlightedIndex === index
                                        
                                        background: Rectangle {
                                            color: highlighted ? primaryColor : (parent.hovered ? surfaceColor : backgroundColor)
                                            opacity: highlighted ? 0.1 : 1
                                        }
                                    }
                                    
                                    contentItem: Text {
                                        leftPadding: baseUnit
                                        rightPadding: areaFuncionalCombo.indicator.width + baseUnit
                                        text: areaFuncionalCombo.displayText
                                        font: areaFuncionalCombo.font
                                        color: areaFuncionalCombo.currentIndex === 0 ? textSecondaryColor : textColor
                                        verticalAlignment: Text.AlignVCenter
                                        elide: Text.ElideRight
                                    }
                                    
                                    background: Rectangle {
                                        color: backgroundColor
                                        border.color: areaFuncionalCombo.activeFocus ? primaryColor : borderColor
                                        border.width: areaFuncionalCombo.activeFocus ? 2 : 1
                                        radius: radiusSmall
                                    }
                                    
                                    popup: Popup {
                                        y: areaFuncionalCombo.height
                                        width: areaFuncionalCombo.width
                                        implicitHeight: contentItem.implicitHeight
                                        padding: 1
                                        
                                        contentItem: ListView {
                                            clip: true
                                            implicitHeight: contentHeight
                                            model: areaFuncionalCombo.popup.visible ? areaFuncionalCombo.delegateModel : null
                                            currentIndex: areaFuncionalCombo.highlightedIndex
                                            
                                            ScrollBar.vertical: ScrollBar {}
                                        }
                                        
                                        background: Rectangle {
                                            color: backgroundColor
                                            border.color: borderColor
                                            radius: radiusSmall
                                        }
                                    }
                                }
                            }
                            
                            // ✅ CAMPO: Descripción (ahora ocupa toda la fila)
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.columnSpan: width < baseUnit * 80 ? 1 : 2
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
                                        border.color: nuevoTipoDescripcion.activeFocus ? primaryColor : borderColor
                                        border.width: nuevoTipoDescripcion.activeFocus ? 2 : 1
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
                                enabled: nuevoTipoNombre.text.trim().length > 0 && 
                                        areaFuncionalCombo.currentIndex > 0 &&  // ✅ NUEVO: Validar categoría
                                        !confiTrabajadoresModel.loading
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
                        
                        // ✅ ACTUALIZADO: ENCABEZADOS CON COLUMNA DE CATEGORÍA
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
                                    Layout.preferredWidth: parent.width * 0.25
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
                                    Layout.preferredWidth: parent.width * 0.15
                                    text: "CATEGORÍA"
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
                                    Layout.preferredWidth: parent.width * 0.40
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
                        
                        // ✅ ACTUALIZADO: LISTVIEW CON COLUMNA DE CATEGORÍA
                        ListView {
                            id: tiposListView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            
                            model: confiTrabajadoresModel ? confiTrabajadoresModel.tiposTrabajadores : []
                            
                            delegate: Rectangle {
                                width: tiposListView.width
                                height: baseUnit * 7
                                color: index % 2 === 0 ? backgroundColor : surfaceColor
                                border.color: borderColor
                                border.width: 0.5
                                
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: marginSmall
                                    spacing: marginSmall
                                    
                                    // Tipo
                                    Label {
                                        Layout.preferredWidth: parent.width * 0.25
                                        text: modelData.Tipo || "Sin nombre"
                                        font.pixelSize: fontBase
                                        color: textColor
                                        elide: Text.ElideRight
                                        horizontalAlignment: Text.AlignLeft
                                        verticalAlignment: Text.AlignVCenter
                                        font.family: "Segoe UI"
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: 1
                                        Layout.fillHeight: true
                                        color: borderColor
                                    }
                                    
                                    // ✅ NUEVO: Categoría con ícono
                                    RowLayout {
                                        Layout.preferredWidth: parent.width * 0.15
                                        spacing: marginSmall
                                        
                                        Rectangle {
                                            Layout.preferredWidth: baseUnit * 3.5
                                            Layout.preferredHeight: baseUnit * 3.5
                                            radius: baseUnit * 0.5
                                            color: obtenerColorArea(modelData.area_funcional)
                                            opacity: 0.15
                                            
                                            Label {
                                                anchors.centerIn: parent
                                                text: obtenerIconoArea(modelData.area_funcional)
                                                font.pixelSize: fontBase * 1.2
                                            }
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: 1
                                        Layout.fillHeight: true
                                        color: borderColor
                                    }
                                    
                                    // Descripción
                                    Label {
                                        Layout.preferredWidth: parent.width * 0.40
                                        text: modelData.descripcion || "Sin descripción"
                                        font.pixelSize: fontSmall
                                        color: textSecondaryColor
                                        elide: Text.ElideRight
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 2
                                        verticalAlignment: Text.AlignVCenter
                                        font.family: "Segoe UI"
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: 1
                                        Layout.fillHeight: true
                                        color: borderColor
                                    }
                                    
                                    // Acciones
                                    RowLayout {
                                        Layout.preferredWidth: parent.width * 0.20
                                        spacing: marginSmall
                                        Layout.alignment: Qt.AlignHCenter
                                        
                                        Button {
                                            text: "✏️"
                                            Layout.preferredWidth: baseUnit * 4
                                            Layout.preferredHeight: baseUnit * 4
                                            
                                            background: Rectangle {
                                                color: parent.pressed ? Qt.darker(primaryColor, 1.2) : primaryColor
                                                radius: radiusSmall
                                                opacity: parent.hovered ? 1.0 : 0.9
                                            }
                                            
                                            contentItem: Label {
                                                text: parent.text
                                                color: backgroundColor
                                                font.pixelSize: fontSmall
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            
                                            ToolTip.visible: hovered
                                            ToolTip.text: "Editar tipo"
                                            
                                            onClicked: editarTipoTrabajador(index, modelData)
                                        }
                                        
                                        Button {
                                            text: "🗑️"
                                            Layout.preferredWidth: baseUnit * 4
                                            Layout.preferredHeight: baseUnit * 4
                                            
                                            background: Rectangle {
                                                color: parent.pressed ? Qt.darker(dangerColor, 1.2) : dangerColor
                                                radius: radiusSmall
                                                opacity: parent.hovered ? 1.0 : 0.9
                                            }
                                            
                                            contentItem: Label {
                                                text: parent.text
                                                color: backgroundColor
                                                font.pixelSize: fontSmall
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            
                                            ToolTip.visible: hovered
                                            ToolTip.text: "Eliminar tipo"
                                            
                                            onClicked: eliminarTipoTrabajador(modelData.id, modelData.Tipo)
                                        }
                                    }
                                }
                            }
                            
                            ScrollBar.vertical: ScrollBar {
                                policy: ScrollBar.AsNeeded
                            }
                        }
                    }
                }
            }
        }
    }
    
    // ===== MENSAJE FLOTANTE =====
    Rectangle {
        id: messageRect
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: marginLarge
        width: Math.min(parent.width * 0.5, baseUnit * 60)
        height: baseUnit * 6
        radius: radiusMedium
        visible: showMessage
        opacity: showMessage ? 1.0 : 0.0
        
        Behavior on opacity {
            NumberAnimation { duration: 300 }
        }
        
        RowLayout {
            anchors.fill: parent
            anchors.margins: marginMedium
            spacing: marginMedium
            
            Label {
                id: messageLabel
                Layout.fillWidth: true
                font.pixelSize: fontBase
                font.bold: true
                color: backgroundColor
                wrapMode: Text.WordWrap
                verticalAlignment: Text.AlignVCenter
                font.family: "Segoe UI"
            }
            
            Button {
                text: "✕"
                Layout.preferredWidth: baseUnit * 3
                Layout.preferredHeight: baseUnit * 3
                
                background: Rectangle {
                    color: "transparent"
                }
                
                contentItem: Label {
                    text: parent.text
                    color: backgroundColor
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: showMessage = false
            }
        }
    }
    
    // ===== DIÁLOGO DE CONFIRMACIÓN DE ELIMINACIÓN =====
    Dialog {
        id: confirmDeleteDialog
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.4, baseUnit * 60)
        modal: true
        title: "Confirmar Eliminación"
        
        property int tipoId: 0
        property string tipoNombre: ""
        
        background: Rectangle {
            color: backgroundColor
            radius: radiusMedium
            border.color: borderColor
            border.width: 1
        }
        
        header: Rectangle {
            width: parent.width
            height: baseUnit * 8
            color: dangerColor
            radius: radiusMedium
            
            Rectangle {
                anchors.fill: parent
                anchors.topMargin: radiusMedium
                color: parent.color
            }
            
            Label {
                anchors.centerIn: parent
                text: "⚠️ Confirmar Eliminación"
                font.pixelSize: fontLarge
                font.bold: true
                color: backgroundColor
                font.family: "Segoe UI"
            }
        }
        
        contentItem: ColumnLayout {
            spacing: marginMedium
            
            Label {
                Layout.fillWidth: true
                text: "¿Estás seguro de que deseas eliminar el tipo de trabajador '" + confirmDeleteDialog.tipoNombre + "'?"
                wrapMode: Text.WordWrap
                font.pixelSize: fontBase
                color: textColor
                font.family: "Segoe UI"
            }
            
            Label {
                Layout.fillWidth: true
                text: "Esta acción no se puede deshacer."
                wrapMode: Text.WordWrap
                font.pixelSize: fontSmall
                color: dangerColor
                font.bold: true
                font.family: "Segoe UI"
            }
        }
        
        footer: RowLayout {
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
                
                onClicked: confirmDeleteDialog.close()
            }
            
            Button {
                text: "🗑️ Eliminar"
                Layout.preferredWidth: baseUnit * 15
                Layout.preferredHeight: baseUnit * 4.5
                
                background: Rectangle {
                    color: parent.pressed ? Qt.darker(dangerColor, 1.2) : dangerColor
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
                
                onClicked: {
                    confirmarEliminacion()
                    confirmDeleteDialog.close()
                }
            }
        }
    }
}
