import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: configTrabajadoresRoot
    
    // ===== PASO 1: PROPERTY ALIAS PARA COMUNICACIÓN EXTERNA =====
    property var tiposTrabajadores: tiposTrabajadoresData
    
    // ===== SEÑALES PARA VOLVER =====
    signal volverClicked()
    signal backToMain()
    
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
        isEditMode = false
        editingIndex = -1
    }
    
    function editarTipoTrabajador(index) {
        if (index >= 0 && index < tiposTrabajadoresData.length) {
            var tipo = tiposTrabajadoresData[index]
            nuevoTipoNombre.text = tipo.nombre
            nuevoTipoDescripcion.text = tipo.descripcion
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
        var nuevoTipo = {
            nombre: nuevoTipoNombre.text,
            descripcion: nuevoTipoDescripcion.text
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
        spacing: 0
        
        // ===== HEADER PRINCIPAL UNIFICADO (ESTILO CONSISTENTE) =====
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
                        // Emitir señal para volver a la vista principal
                        if (typeof changeView !== "undefined") {
                            changeView("main")
                        } else {
                            configTrabajadoresRoot.volverClicked()
                            configTrabajadoresRoot.backToMain()
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
                                            Layout.preferredWidth: parent.width * 0.35
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
                                            Layout.preferredWidth: parent.width * 0.45
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
        }
    }
    
    // ===== EVENTOS =====
    function actualizarTiposTrabajadores(nuevosTipos) {
        tiposTrabajadoresData = nuevosTipos
        tiposTrabajadores = nuevosTipos
    }
    
    Component.onCompleted: {
        console.log("👥 Componente de configuración de tipos de trabajadores iniciado")
    }
}