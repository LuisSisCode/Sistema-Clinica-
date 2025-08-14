import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: configEspecialidadesRoot
    
    // ===== PROPERTY ALIAS PARA COMUNICACIÓN EXTERNA =====
    property alias especialidades: configEspecialidadesRoot.especialidadesData
    
    // ===== DATOS INTERNOS =====
    property var especialidadesData: []
    
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
    property int editingIndex: -1
    
    // ===== FUNCIONES =====
    function limpiarFormulario() {
        nuevaEspecialidadNombre.text = ""
        nuevaEspecialidadDoctor.text = ""
        nuevaEspecialidadPrecioNormal.text = ""
        nuevaEspecialidadPrecioEmergencia.text = ""
        isEditMode = false
        editingIndex = -1
    }
    
    function editarEspecialidad(index) {
        if (index >= 0 && index < especialidadesData.length) {
            var especialidad = especialidadesData[index]
            nuevaEspecialidadNombre.text = especialidad.nombre
            nuevaEspecialidadDoctor.text = especialidad.doctor
            nuevaEspecialidadPrecioNormal.text = especialidad.precioNormal.toString()
            nuevaEspecialidadPrecioEmergencia.text = especialidad.precioEmergencia.toString()
            isEditMode = true
            editingIndex = index
        }
    }
    
    function eliminarEspecialidad(index) {
        if (index >= 0 && index < especialidadesData.length) {
            especialidadesData.splice(index, 1)
            configEspecialidadesRoot.especialidades = especialidadesData
            console.log("🗑️ Especialidad eliminada en índice:", index)
        }
    }
    
    function guardarEspecialidad() {
        var nuevaEspecialidad = {
            nombre: nuevaEspecialidadNombre.text,
            doctor: nuevaEspecialidadDoctor.text,
            precioNormal: parseFloat(nuevaEspecialidadPrecioNormal.text),
            precioEmergencia: parseFloat(nuevaEspecialidadPrecioEmergencia.text)
        }
        
        if (isEditMode && editingIndex >= 0) {
            // Editar especialidad existente
            especialidadesData[editingIndex] = nuevaEspecialidad
            console.log("✏️ Especialidad editada:", JSON.stringify(nuevaEspecialidad))
        } else {
            // Agregar nueva especialidad
            especialidadesData.push(nuevaEspecialidad)
            console.log("➕ Nueva especialidad agregada:", JSON.stringify(nuevaEspecialidad))
        }
        
        // Actualizar el modelo y limpiar
        configEspecialidadesRoot.especialidades = especialidadesData
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
                    text: "🏥"
                    font.pixelSize: fontLarge
                    color: "white"
                }
            }
            
            ColumnLayout {
                Layout.fillWidth: true
                spacing: marginTiny
                
                Label {
                    text: "Configuración de Especialidades Médicas"
                    font.pixelSize: fontTitle
                    font.bold: true
                    color: textColor
                    font.family: "Segoe UI"
                }
                
                Label {
                    text: "Gestiona las especialidades médicas, doctores y precios de consultas"
                    color: textSecondaryColor
                    font.pixelSize: fontBase
                    font.family: "Segoe UI"
                }
            }
        }
        
        // ===== FORMULARIO =====
        GroupBox {
            Layout.fillWidth: true
            title: isEditMode ? "Editar Especialidad" : "Agregar Nueva Especialidad"
            
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
                            text: "Especialidad:"
                            font.bold: true
                            color: textColor
                            font.pixelSize: fontBase
                            font.family: "Segoe UI"
                        }
                        TextField {
                            id: nuevaEspecialidadNombre
                            Layout.fillWidth: true
                            Layout.preferredHeight: baseUnit * 4.5
                            placeholderText: "Ej: Cardiología"
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
                            text: "Doctor:"
                            font.bold: true
                            color: textColor
                            font.pixelSize: fontBase
                            font.family: "Segoe UI"
                        }
                        TextField {
                            id: nuevaEspecialidadDoctor
                            Layout.fillWidth: true
                            Layout.preferredHeight: baseUnit * 4.5
                            placeholderText: "Ej: Dr. Juan Carlos García"
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
                            id: nuevaEspecialidadPrecioNormal
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
                            id: nuevaEspecialidadPrecioEmergencia
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
                            enabled: nuevaEspecialidadNombre.text && nuevaEspecialidadDoctor.text && 
                                    nuevaEspecialidadPrecioNormal.text && nuevaEspecialidadPrecioEmergencia.text
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
                        text: "📋 Especialidades Registradas"
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
                            Layout.preferredWidth: parent.width * 0.25
                            text: "ESPECIALIDAD"
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
                            text: "DOCTOR"
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
                                spacing: marginSmall
                                
                                Label {
                                    Layout.preferredWidth: parent.width * 0.25
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
                                    Layout.preferredWidth: parent.width * 0.30
                                    text: modelData.doctor
                                    color: textColor
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
                                    Layout.preferredWidth: parent.width * 0.15
                                    text: "Bs " + modelData.precioNormal.toFixed(2)
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
                                    text: "Bs " + modelData.precioEmergencia.toFixed(2)
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
                                            font.pixelSize: fontSmall
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
                            text: "No hay especialidades registradas"
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
    
    // ===== EVENTOS =====
    onEspecialidadesChanged: {
        if (especialidades && especialidades !== especialidadesData) {
            especialidadesData = especialidades
            console.log("🔄 Datos de especialidades actualizados desde exterior")
        }
    }
    
    Component.onCompleted: {
        console.log("🏥 Componente de configuración de especialidades iniciado")
    }
}