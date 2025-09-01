import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: configAnalisisRoot
    
    // ===== PROPERTY ALIAS PARA COMUNICACIÓN EXTERNA =====
    property alias tiposAnalisis: configAnalisisRoot.tiposAnalisisData
    
    // ===== SEÑAL PARA VOLVER =====
    signal volverClicked()
    signal backToMain()
    
    // ===== DATOS INTERNOS =====
    property var tiposAnalisisData: []
    
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
    property int editingIndex: -1
    
    // ===== FUNCIONES =====
    function limpiarFormulario() {
        nuevoAnalisisNombre.text = ""
        nuevoAnalisisTipo.text = ""
        nuevoAnalisisPrecioNormal.text = ""
        nuevoAnalisisPrecioEmergencia.text = ""
        isEditMode = false
        editingIndex = -1
    }
    
    function editarAnalisis(index) {
        if (index >= 0 && index < tiposAnalisisData.length) {
            var analisis = tiposAnalisisData[index]
            nuevoAnalisisNombre.text = analisis.nombre
            nuevoAnalisisTipo.text = analisis.tipo
            nuevoAnalisisPrecioNormal.text = analisis.precioNormal.toString()
            nuevoAnalisisPrecioEmergencia.text = analisis.precioEmergencia.toString()
            isEditMode = true
            editingIndex = index
        }
    }
    
    function eliminarAnalisis(index) {
        if (!tiposAnalisisData) {
            tiposAnalisisData = []
            return
        }
        
        if (index >= 0 && index < tiposAnalisisData.length) {
            tiposAnalisisData.splice(index, 1)
            configAnalisisRoot.tiposAnalisis = tiposAnalisisData
            console.log("🗑️ Análisis eliminado en índice:", index)
        }
    }
    
    function guardarAnalisis() {
        if (!tiposAnalisisData) {
            tiposAnalisisData = []
        }
        
        var nuevoAnalisis = {
            nombre: nuevoAnalisisNombre.text,
            tipo: nuevoAnalisisTipo.text,
            descripcion: nuevoAnalisisTipo.text, // Usar tipo como descripcion
            precioNormal: parseFloat(nuevoAnalisisPrecioNormal.text),
            precioEmergencia: parseFloat(nuevoAnalisisPrecioEmergencia.text)
        }
        
        if (isEditMode && editingIndex >= 0) {
            tiposAnalisisData[editingIndex] = nuevoAnalisis
            console.log("✏️ Análisis editado:", JSON.stringify(nuevoAnalisis))
        } else {
            tiposAnalisisData.push(nuevoAnalisis)
            console.log("➕ Nuevo análisis agregado:", JSON.stringify(nuevoAnalisis))
        }
        
        configAnalisisRoot.tiposAnalisis = tiposAnalisisData
        limpiarFormulario()
    }
    
    // ===== LAYOUT PRINCIPAL =====
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        
        // ===== HEADER PRINCIPAL UNIFICADO (ESTILO CONSISTENTE CON USUARIOS) =====
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
                    title: isEditMode ? "Editar Tipo de Análisis" : "Agregar Nuevo Tipo de Análisis"
                    
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
                        
                        // ===== PRIMERA FILA: NOMBRE Y TIPO/CATEGORÍA =====
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: marginLarge
                            
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.preferredWidth: parent.width * 0.5
                                spacing: marginSmall
                                
                                Label {
                                    text: "Nombre del Análisis:"
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
                                        border.color: borderColor
                                        border.width: 1
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
                        
                        // ===== SEGUNDA FILA: PRECIOS Y BOTONES =====
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: marginMedium
                            
                            // PRECIO NORMAL (fijo y pequeño)
                            ColumnLayout {
                                Layout.preferredWidth: 120
                                spacing: marginSmall
                                
                                Label {
                                    text: "Precio Normal:"
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
                                        border.color: borderColor
                                        border.width: 1
                                        radius: radiusSmall
                                    }
                                }
                            }
                            
                            // PRECIO EMERGENCIA (fijo y pequeño)
                            ColumnLayout {
                                Layout.preferredWidth: 120
                                spacing: marginSmall
                                
                                Label {
                                    text: "Precio Emergencia:"
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
                                        border.color: borderColor
                                        border.width: 1
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
                                Layout.preferredWidth: baseUnit * 22
                                spacing: marginSmall
                                
                                Label {
                                    text: " " // Espaciador para alinear con otros campos
                                    font.pixelSize: fontSmall
                                }
                                
                                RowLayout {
                                    spacing: marginSmall
                                    
                                    Button {
                                        text: "Cancelar"
                                        Layout.preferredWidth: baseUnit * 10
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
                                        enabled: nuevoAnalisisNombre.text && nuevoAnalisisTipo.text && 
                                                nuevoAnalisisPrecioNormal.text && 
                                                nuevoAnalisisPrecioEmergencia.text
                                        Layout.preferredWidth: baseUnit * 12
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
                                text: "🧪 Tipos de Análisis Registrados"
                                font.pixelSize: fontMedium
                                font.bold: true
                                color: textColor
                                font.family: "Segoe UI"
                            }
                        }
                        
                        // ENCABEZADOS - AJUSTADOS PARA NO DESBORDARSE
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
                                    Layout.preferredWidth: parent.width * 0.18
                                    Layout.fillHeight: true
                                    text: "TIPO"
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
                                    Layout.preferredWidth: parent.width * 0.11
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
                                model: tiposAnalisisData
                                
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
                                            text: modelData.nombre
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
                                            Layout.preferredWidth: parent.width * 0.18
                                            Layout.fillHeight: true
                                            text: modelData.tipo
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
                                            Layout.fillHeight: true
                                            text: modelData.descripcion
                                            color: textColor
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
                                            text: "Bs " + modelData.precioNormal.toFixed(2)
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
                                            text: "Bs " + modelData.precioEmergencia.toFixed(2)
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
                                            Layout.preferredWidth: parent.width * 0.11
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
                            visible: tiposAnalisisData.length === 0
                            
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
    
    // ===== EVENTOS =====
    onTiposAnalisisChanged: {
        if (tiposAnalisis && tiposAnalisis !== tiposAnalisisData) {
            tiposAnalisisData = tiposAnalisis
            console.log("🔄 Datos de tipos de análisis actualizados desde exterior")
        }
    }
    
    Component.onCompleted: {
        console.log("🧪 Componente de configuración de tipos de análisis iniciado")
    }
}