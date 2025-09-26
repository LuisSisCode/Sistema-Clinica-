import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import ClinicaModels 1.0

Item {
    id: configProcedimientosRoot
    
    // ===== SEÑALES PARA VOLVER =====
    signal volverClicked()
    signal backToMain()
    
    // ===== ACCESO AL MODEL =====
    property var confiEnfermeriaModel: appController.confi_enfermeria_model_instance
    
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
    
    // ===== FUNCIONES INTEGRADAS CON MODEL =====
    function limpiarFormulario() {
        nuevoProcedimientoNombre.text = ""
        nuevoProcedimientoDescripcion.text = ""
        nuevoProcedimientoPrecioNormal.text = ""
        nuevoProcedimientoPrecioEmergencia.text = ""
        isEditMode = false
        editingId = -1
    }
    
    function editarProcedimiento(procedimientoData) {
        if (procedimientoData && procedimientoData.id) {
            nuevoProcedimientoNombre.text = procedimientoData.Nombre || ""
            nuevoProcedimientoDescripcion.text = procedimientoData.Descripcion || ""
            nuevoProcedimientoPrecioNormal.text = procedimientoData.Precio_Normal ? procedimientoData.Precio_Normal.toString() : "0.00"
            nuevoProcedimientoPrecioEmergencia.text = procedimientoData.Precio_Emergencia ? procedimientoData.Precio_Emergencia.toString() : "0.00"
            isEditMode = true
            editingId = procedimientoData.id
            console.log("Editando procedimiento ID:", editingId)
        }
    }
    
    function eliminarProcedimiento(procedimientoId) {
        if (procedimientoId && confiEnfermeriaModel) {
            console.log("Eliminando procedimiento ID:", procedimientoId)
            confiEnfermeriaModel.eliminarTipoProcedimiento(procedimientoId)
        }
    }
    
    function guardarProcedimiento() {
        if (!confiEnfermeriaModel) {
            console.log("❌ ConfiEnfermeriaModel no disponible")
            return
        }
        
        var nombre = nuevoProcedimientoNombre.text.trim()
        var descripcion = nuevoProcedimientoDescripcion.text.trim()
        var precioNormal = parseFloat(nuevoProcedimientoPrecioNormal.text) || 0.0
        var precioEmergencia = parseFloat(nuevoProcedimientoPrecioEmergencia.text) || 0.0
        
        if (!nombre) {
            console.log("❌ Nombre es requerido")
            return
        }
        
        var success = false
        
        if (isEditMode && editingId > 0) {
            // Actualizar procedimiento existente
            console.log("Actualizando procedimiento ID:", editingId)
            success = confiEnfermeriaModel.actualizarTipoProcedimiento(
                editingId, nombre, descripcion, precioNormal, precioEmergencia
            )
        } else {
            // Crear nuevo procedimiento
            console.log("Creando nuevo procedimiento:", nombre)
            success = confiEnfermeriaModel.crearTipoProcedimiento(
                nombre, descripcion, precioNormal, precioEmergencia
            )
        }
        
        if (success) {
            limpiarFormulario()
            // Refrescar datos
            if (confiEnfermeriaModel.refrescarDatosInmediato) {
                confiEnfermeriaModel.refrescarDatosInmediato()
            }
        }
    }
    
    function aplicarFiltros() {
        if (confiEnfermeriaModel && confiEnfermeriaModel.aplicarFiltros) {
            confiEnfermeriaModel.aplicarFiltros("", 0.0, -1.0)
        }
    }
    
    // ===== CONEXIONES CON EL MODEL =====
    Connections {
        target: confiEnfermeriaModel
        
        function onTipoProcedimientoCreado(success, message) {
            console.log("Procedimiento creado:", success, message)
            if (success) {
                limpiarFormulario()
            }
        }
        
        function onTipoProcedimientoActualizado(success, message) {
            console.log("Procedimiento actualizado:", success, message)
            if (success) {
                limpiarFormulario()
            }
        }
        
        function onTipoProcedimientoEliminado(success, message) {
            console.log("Procedimiento eliminado:", success, message)
        }
        
        function onTiposProcedimientosChanged() {
            console.log("Lista de procedimientos actualizada")
        }
        
        function onErrorOccurred(title, message) {
            console.log("Error en ConfiEnfermeriaModel:", title, message)
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
                            configProcedimientosRoot.volverClicked()
                            configProcedimientosRoot.backToMain()
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
                        text: "🩹"
                        font.pixelSize: fontBase * 1.8
                    }
                }
                
                // ===== INFORMACIÓN DEL MÓDULO =====
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: marginSmall * 0.5
                    
                    Label {
                        text: "Configuración de Procedimientos de Enfermería"
                        color: backgroundColor
                        font.pixelSize: fontBase * 1.4
                        font.bold: true
                        font.family: "Segoe UI"
                    }
                    
                    Label {
                        text: "Gestiona los tipos de procedimientos, descripciones y precios de enfermería del sistema"
                        color: backgroundColor
                        font.pixelSize: fontBase * 0.9
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        opacity: 0.95
                        font.family: "Segoe UI"
                    }
                }
                
                // ===== INDICADOR DE CARGA =====
                Rectangle {
                    Layout.preferredWidth: baseUnit * 8
                    Layout.preferredHeight: baseUnit * 8
                    color: "transparent"
                    visible: confiEnfermeriaModel ? confiEnfermeriaModel.loading : false
                    
                    BusyIndicator {
                        anchors.centerIn: parent
                        width: baseUnit * 4
                        height: baseUnit * 4
                        running: parent.visible
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
                
                // ===== FORMULARIO =====
                GroupBox {
                    Layout.fillWidth: true
                    Layout.minimumHeight: baseUnit * 30  // AGREGAR ALTURA
                    title: ""  // QUITAR EL TÍTULO
                    
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
                            text: isEditMode ? "✏️ Editar Procedimiento" : "➕ Agregar Nuevo Procedimiento"
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
                            
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: marginSmall
                                
                                Label {
                                    text: "Nombre del Procedimiento:"  // ESTE VA DESPUÉS DEL TÍTULO
                                    font.bold: true
                                    color: textColor
                                    font.pixelSize: fontBase
                                    font.family: "Segoe UI"
                                }
                                TextField {
                                    id: nuevoProcedimientoNombre
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: baseUnit * 4.5
                                    placeholderText: "Ej: Curación Simple"
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
                                    id: nuevoProcedimientoDescripcion
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: baseUnit * 4.5
                                    placeholderText: "Ej: Limpieza y vendaje básico"
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
                        
                        // PRECIOS Y BOTONES
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: marginMedium
                            
                            ColumnLayout {
                                spacing: marginSmall
                                
                                Label {
                                    text: "Precio Normal:"
                                    font.bold: true
                                    color: textColor
                                    font.pixelSize: fontSmall
                                    font.family: "Segoe UI"
                                }
                                TextField {
                                    id: nuevoProcedimientoPrecioNormal
                                    Layout.preferredWidth: baseUnit * 15
                                    Layout.preferredHeight: baseUnit * 4.5
                                    placeholderText: "0.00"
                                    validator: DoubleValidator { bottom: 0.0; decimals: 2 }
                                    font.pixelSize: fontBase
                                    font.family: "Segoe UI"
                                    horizontalAlignment: TextInput.AlignHCenter
                                    background: Rectangle {
                                        color: backgroundColor
                                        border.color: borderColor
                                        border.width: 1
                                        radius: radiusSmall
                                    }
                                }
                            }
                            
                            ColumnLayout {
                                spacing: marginSmall
                                
                                Label {
                                    text: "Precio Emergencia:"
                                    font.bold: true
                                    color: textColor
                                    font.pixelSize: fontSmall
                                    font.family: "Segoe UI"
                                }
                                TextField {
                                    id: nuevoProcedimientoPrecioEmergencia
                                    Layout.preferredWidth: baseUnit * 15
                                    Layout.preferredHeight: baseUnit * 4.5
                                    placeholderText: "0.00"
                                    validator: DoubleValidator { bottom: 0.0; decimals: 2 }
                                    font.pixelSize: fontBase
                                    font.family: "Segoe UI"
                                    horizontalAlignment: TextInput.AlignHCenter
                                    background: Rectangle {
                                        color: backgroundColor
                                        border.color: borderColor
                                        border.width: 1
                                        radius: radiusSmall
                                    }
                                }
                            }
                            
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
                                    enabled: nuevoProcedimientoNombre.text.trim() !== ""
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
                                    
                                    onClicked: guardarProcedimiento()
                                }
                            }
                        }
                    }
                }
                
                // ===== TABLA DE PROCEDIMIENTOS =====
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
                                    text: "🩹 Procedimientos Registrados"
                                    font.pixelSize: fontMedium
                                    font.bold: true
                                    color: textColor
                                    font.family: "Segoe UI"
                                }
                                
                                Item { Layout.fillWidth: true }
                                
                                Rectangle {
                                    Layout.preferredWidth: baseUnit * 8
                                    Layout.preferredHeight: baseUnit * 4
                                    color: primaryColor
                                    radius: radiusSmall
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: confiEnfermeriaModel ? confiEnfermeriaModel.totalTiposProcedimientos.toString() : "0"
                                        color: backgroundColor
                                        font.bold: true
                                        font.pixelSize: fontSmall
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
                                    Layout.preferredWidth: parent.width * 0.25
                                    text: "PROCEDIMIENTO"
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
                                    Layout.preferredWidth: parent.width * 0.30
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
                                    Layout.preferredWidth: parent.width * 0.15
                                    text: "PRECIO NORMAL"
                                    font.bold: true
                                    font.pixelSize: fontTiny
                                    color: textColor
                                    font.family: "Segoe UI"
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 1
                                    Layout.fillHeight: true
                                    color: borderColor
                                }
                                
                                Label {
                                    Layout.preferredWidth: parent.width * 0.15
                                    text: "PRECIO EMERGENCIA"
                                    font.bold: true
                                    font.pixelSize: fontTiny
                                    color: textColor
                                    font.family: "Segoe UI"
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 1
                                    Layout.fillHeight: true
                                    color: borderColor
                                }
                                
                                Label {
                                    Layout.preferredWidth: parent.width * 0.15
                                    text: "ACCIONES"
                                    font.bold: true
                                    font.pixelSize: fontSmall
                                    color: textColor
                                    font.family: "Segoe UI"
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }
                        
                        // CONTENIDO DE LA TABLA
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            
                            ListView {
                                id: procedimientosList
                                model: confiEnfermeriaModel ? confiEnfermeriaModel.tiposProcedimientos : []
                                
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
                                            Layout.preferredWidth: parent.width * 0.25
                                            text: modelData.Nombre || "Sin nombre"
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
                                            Layout.preferredWidth: parent.width * 0.30
                                            text: modelData.Descripcion || "Sin descripción"
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
                                        
                                        Label {
                                            Layout.preferredWidth: parent.width * 0.15
                                            text: "Bs " + (modelData.Precio_Normal ? modelData.Precio_Normal.toFixed(2) : "0.00")
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
                                        
                                        Label {
                                            Layout.preferredWidth: parent.width * 0.15
                                            text: "Bs " + (modelData.Precio_Emergencia ? modelData.Precio_Emergencia.toFixed(2) : "0.00")
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
                                        
                                        RowLayout {
                                            Layout.preferredWidth: parent.width * 0.15
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
                                                
                                                onClicked: editarProcedimiento(modelData)
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
                                                
                                                onClicked: eliminarProcedimiento(modelData.id)
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
                            visible: confiEnfermeriaModel ? confiEnfermeriaModel.totalTiposProcedimientos === 0 : true
                            
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: marginMedium
                                
                                Label {
                                    text: "🩹"
                                    font.pixelSize: fontTitle * 2
                                    color: textSecondaryColor
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                
                                Label {
                                    text: "No hay procedimientos registrados"
                                    color: textColor
                                    font.bold: true
                                    font.pixelSize: fontMedium
                                    Layout.alignment: Qt.AlignHCenter
                                    font.family: "Segoe UI"
                                }
                                
                                Label {
                                    text: "Agrega el primer procedimiento usando el formulario superior"
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
        //console.log("🩹 Componente de configuración de procedimientos iniciado")
        
        // Verificar que el modelo esté disponible
        if (confiEnfermeriaModel) {
            console.log("✅ ConfiEnfermeriaModel conectado correctamente")
            // Aplicar filtros iniciales si es necesario
            aplicarFiltros()
        } else {
            console.log("❌ ConfiEnfermeriaModel no está disponible")
        }
    }
}