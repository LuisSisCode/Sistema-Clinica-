import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: configTrabajadoresRoot
    
    // ===== PASO 1: PROPERTY ALIAS PARA COMUNICACIÓN EXTERNA =====
    property alias tiposTrabajadores: listaTiposTrabajadores.model
    
    // ===== DATOS INTERNOS =====
    property var tiposTrabajadoresData: []
    
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
    
    // ===== FUNCIONES =====
    function limpiarFormulario() {
        nuevoTipoNombre.text = ""
        nuevoTipoDescripcion.text = ""
        nuevoTipoEspecialidades.text = ""
        nuevoTipoRequiereMatricula.checked = false
        isEditMode = false
        editingIndex = -1
    }
    
    function editarTipoTrabajador(index) {
        if (index >= 0 && index < tiposTrabajadoresData.length) {
            var tipo = tiposTrabajadoresData[index]
            nuevoTipoNombre.text = tipo.nombre
            nuevoTipoDescripcion.text = tipo.descripcion
            nuevoTipoEspecialidades.text = Array.isArray(tipo.especialidades) ? 
                tipo.especialidades.join(", ") : tipo.especialidades
            nuevoTipoRequiereMatricula.checked = tipo.requiereMatricula
            isEditMode = true
            editingIndex = index
        }
    }
    
    function eliminarTipoTrabajador(index) {
        if (index >= 0 && index < tiposTrabajadoresData.length) {
            tiposTrabajadoresData.splice(index, 1)
            // Actualizar el modelo de la ListView
            configTrabajadoresRoot.tiposTrabajadores = tiposTrabajadoresData
            console.log("🗑️ Tipo de trabajador eliminado en índice:", index)
        }
    }
    
    function guardarTipoTrabajador() {
        // Convertir especialidades de string a array
        var especialidadesArray = nuevoTipoEspecialidades.text
            .split(",")
            .map(function(item) { return item.trim() })
            .filter(function(item) { return item.length > 0 })
        
        var nuevoTipo = {
            nombre: nuevoTipoNombre.text,
            descripcion: nuevoTipoDescripcion.text,
            especialidades: especialidadesArray,
            requiereMatricula: nuevoTipoRequiereMatricula.checked
        }
        
        if (isEditMode && editingIndex >= 0) {
            // Editar tipo existente
            tiposTrabajadoresData[editingIndex] = nuevoTipo
            console.log("✏️ Tipo de trabajador editado:", JSON.stringify(nuevoTipo))
        } else {
            // Agregar nuevo tipo
            tiposTrabajadoresData.push(nuevoTipo)
            console.log("➕ Nuevo tipo de trabajador agregado:", JSON.stringify(nuevoTipo))
        }
        
        // Actualizar el modelo y limpiar
        configTrabajadoresRoot.tiposTrabajadores = tiposTrabajadoresData
        limpiarFormulario()
    }
    
    // ===== LAYOUT PRINCIPAL =====
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: marginLarge
        spacing: marginLarge
        
        // ===== HEADER =====
        RowLayout {
            Layout.fillWidth: true
            spacing: marginMedium
            
            Rectangle {
                Layout.preferredWidth: baseUnit * 6
                Layout.preferredHeight: baseUnit * 6
                color: primaryColor
                radius: baseUnit * 3
                
                Label {
                    anchors.centerIn: parent
                    text: "👥"
                    font.pixelSize: fontLarge
                    color: "white"
                }
            }
            
            ColumnLayout {
                Layout.fillWidth: true
                spacing: marginTiny
                
                Label {
                    text: "Configuración de Tipos de Trabajadores"
                    font.pixelSize: fontTitle
                    font.bold: true
                    color: textColor
                    font.family: "Segoe UI"
                }
                
                Label {
                    text: "Gestiona los tipos de personal, especialidades y requisitos profesionales"
                    color: textSecondaryColor
                    font.pixelSize: fontBase
                    font.family: "Segoe UI"
                }
            }
        }
        
        // ===== FORMULARIO SUPERIOR =====
        GroupBox {
            Layout.fillWidth: true
            title: isEditMode ? "Editar Tipo de Trabajador" : "Agregar Nuevo Tipo de Trabajador"
            
            background: Rectangle {
                color: surfaceColor
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
                
                // ESPECIALIDADES Y CHECKBOX
                RowLayout {
                    Layout.fillWidth: true
                    spacing: marginMedium
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: marginSmall
                        
                        Label {
                            text: "Especialidades (separadas por comas):"
                            font.bold: true
                            color: textColor
                            font.pixelSize: fontSmall
                            font.family: "Segoe UI"
                        }
                        TextField {
                            id: nuevoTipoEspecialidades
                            Layout.fillWidth: true
                            Layout.preferredHeight: baseUnit * 4.5
                            placeholderText: "Ej: Medicina General, Medicina Familiar"
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
                        spacing: marginSmall
                        
                        Label {
                            text: "Requisitos:"
                            font.bold: true
                            color: textColor
                            font.pixelSize: fontSmall
                            font.family: "Segoe UI"
                        }
                        
                        CheckBox {
                            id: nuevoTipoRequiereMatricula
                            text: "Requiere Matrícula Profesional"
                            font.pixelSize: fontSmall
                            font.family: "Segoe UI"
                            
                            indicator: Rectangle {
                                implicitWidth: baseUnit * 2.5
                                implicitHeight: baseUnit * 2.5
                                x: parent.leftPadding
                                y: parent.height / 2 - height / 2
                                radius: radiusSmall
                                border.color: borderColor
                                border.width: 1
                                color: parent.checked ? primaryColor : backgroundColor
                                
                                Label {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    color: backgroundColor
                                    font.pixelSize: fontSmall
                                    visible: parent.parent.checked
                                }
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
                        enabled: nuevoTipoNombre.text && nuevoTipoDescripcion.text
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
                            Layout.preferredWidth: parent.width * 0.20
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
                            Layout.preferredWidth: parent.width * 0.25
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
                            Layout.preferredWidth: parent.width * 0.25
                            text: "ESPECIALIDADES"
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
                            text: "MATRÍCULA"
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
                        model: tiposTrabajadoresData
                        
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
                                    Layout.preferredWidth: parent.width * 0.20
                                    text: modelData.nombre
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
                                    Layout.preferredWidth: parent.width * 0.25
                                    text: modelData.descripcion
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
                                    Layout.preferredWidth: parent.width * 0.25
                                    text: Array.isArray(modelData.especialidades) ? 
                                        modelData.especialidades.join(", ") : modelData.especialidades
                                    color: textSecondaryColor
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
                                    Layout.preferredWidth: parent.width * 0.15
                                    text: modelData.requiereMatricula ? "✓ Sí" : "✗ No"
                                    color: modelData.requiereMatricula ? successColor : dangerColor
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
                                        
                                        onClicked: editarTipoTrabajador(index)
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
                                        
                                        onClicked: eliminarTipoTrabajador(index)
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
                    visible: tiposTrabajadoresData.length === 0
                    
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
            }
        }
    }
    
    // ===== EVENTOS =====
    onTiposTrabajadoresChanged: {
        if (tiposTrabajadores && tiposTrabajadores !== tiposTrabajadoresData) {
            tiposTrabajadoresData = tiposTrabajadores
            console.log("📄 Datos de tipos de trabajadores actualizados desde exterior")
        }
    }
    
    Component.onCompleted: {
        console.log("👥 Componente de configuración de tipos de trabajadores iniciado")
    }
}