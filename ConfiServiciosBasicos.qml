import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: configTiposGastosRoot
    
    // ===== PROPERTY ALIAS PARA COMUNICACIÓN EXTERNA =====
    property alias tiposGastos: configTiposGastosRoot.tiposGastosData
    
    // ===== SEÑALES PARA VOLVER =====
    signal volverClicked()
    signal backToMain()
    
    // ===== DATOS INTERNOS =====
    property var tiposGastosData: []
    
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
        nuevoTipoGastoNombre.text = ""
        nuevoTipoGastoDescripcion.text = ""
        isEditMode = false
        editingIndex = -1
    }
    
    function editarTipoGasto(index) {
        if (index >= 0 && index < tiposGastosData.length) {
            var tipoGasto = tiposGastosData[index]
            nuevoTipoGastoNombre.text = tipoGasto.nombre
            nuevoTipoGastoDescripcion.text = tipoGasto.descripcion
            isEditMode = true
            editingIndex = index
        }
    }
    
    function eliminarTipoGasto(index) {
        if (index >= 0 && index < tiposGastosData.length) {
            tiposGastosData.splice(index, 1)
            configTiposGastosRoot.tiposGastos = tiposGastosData
            console.log("🗑️ Tipo de gasto eliminado en índice:", index)
        }
    }
    
    function guardarTipoGasto() {
        var nuevoTipoGasto = {
            nombre: nuevoTipoGastoNombre.text,
            descripcion: nuevoTipoGastoDescripcion.text
        }
        
        if (isEditMode && editingIndex >= 0) {
            // Editar tipo de gasto existente
            tiposGastosData[editingIndex] = nuevoTipoGasto
            console.log("✏️ Tipo de gasto editado:", JSON.stringify(nuevoTipoGasto))
        } else {
            // Agregar nuevo tipo de gasto
            tiposGastosData.push(nuevoTipoGasto)
            console.log("➕ Nuevo tipo de gasto agregado:", JSON.stringify(nuevoTipoGasto))
        }
        
        // Actualizar el modelo y limpiar
        configTiposGastosRoot.tiposGastos = tiposGastosData
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
                    title: isEditMode ? "Editar Tipo de Gasto" : "Agregar Nuevo Tipo de Gasto"
                    
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
                        
                        // ===== PRIMERA FILA: NOMBRE Y DESCRIPCIÓN =====
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: marginLarge
                            
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.preferredWidth: parent.width * 0.5
                                spacing: marginSmall
                                
                                Label {
                                    text: "Nombre del Tipo de Gasto:"
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
                                    id: nuevoTipoGastoDescripcion
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: baseUnit * 4.5
                                    placeholderText: "Descripción del tipo de gasto"
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
                                    enabled: nuevoTipoGastoNombre.text && nuevoTipoGastoDescripcion.text
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
                                text: "💰 Tipos de Gastos Registrados"
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
                                    Layout.preferredWidth: parent.width * 0.45
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
                                id: tiposGastosList
                                model: tiposGastosData
                                
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
                                            text: (index + 1).toString()
                                            color: textSecondaryColor
                                            font.pixelSize: fontBase
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
                                            Layout.fillHeight: true
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
                            visible: tiposGastosData.length === 0
                            
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
    
    // ===== EVENTOS =====
    onTiposGastosChanged: {
        if (tiposGastos && tiposGastos !== tiposGastosData) {
            tiposGastosData = tiposGastos
            console.log("🔄 Datos de tipos de gastos actualizados desde exterior")
        }
    }
    
    Component.onCompleted: {
        console.log("💰 Componente de configuración de tipos de gastos iniciado")
    }
}