import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: configTiposGastosRoot
    
    // ===== PROPERTY ALIAS PARA COMUNICACIÓN EXTERNA =====
    property alias tiposGastos: configTiposGastosRoot.tiposGastosData
    
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
    readonly property string infoColor: "#17a2b8"
    readonly property string violetColor: "#9b59b6"
    
    // ===== ESTADO DE EDICIÓN =====
    property bool isEditMode: false
    property int editingIndex: -1
    
    // ===== FUNCIONES =====
    function limpiarFormulario() {
        nuevoTipoGastoNombre.text = ""
        nuevoTipoGastoDescripcion.text = ""
        nuevoTipoGastoEjemplos.text = ""
        nuevoTipoGastoColor.currentIndex = 0
        isEditMode = false
        editingIndex = -1
    }
    
    function editarTipoGasto(index) {
        if (index >= 0 && index < tiposGastosData.length) {
            var tipoGasto = tiposGastosData[index]
            nuevoTipoGastoNombre.text = tipoGasto.nombre
            nuevoTipoGastoDescripcion.text = tipoGasto.descripcion
            nuevoTipoGastoEjemplos.text = tipoGasto.ejemplos ? tipoGasto.ejemplos.join(", ") : ""
            
            // Buscar el índice del color en el modelo
            for (var i = 0; i < nuevoTipoGastoColor.model.length; i++) {
                if (nuevoTipoGastoColor.model[i].value === tipoGasto.color) {
                    nuevoTipoGastoColor.currentIndex = i
                    break
                }
            }
            
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
        var ejemplosTexto = nuevoTipoGastoEjemplos.text
        var ejemplosArray = ejemplosTexto.split(',')
        
        // Limpiar espacios de cada ejemplo
        for (var i = 0; i < ejemplosArray.length; i++) {
            ejemplosArray[i] = ejemplosArray[i].trim()
        }
        
        var nuevoTipoGasto = {
            nombre: nuevoTipoGastoNombre.text,
            descripcion: nuevoTipoGastoDescripcion.text,
            ejemplos: ejemplosArray,
            color: nuevoTipoGastoColor.currentValue || "#95a5a6"
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
                    text: "💰"
                    font.pixelSize: fontLarge
                    color: "white"
                }
            }
            
            ColumnLayout {
                Layout.fillWidth: true
                spacing: marginTiny
                
                Label {
                    text: "Configuración de Tipos de Gastos"
                    font.pixelSize: fontTitle
                    font.bold: true
                    color: textColor
                    font.family: "Segoe UI"
                }
                
                Label {
                    text: "Gestiona las categorías de gastos operativos y sus configuraciones"
                    color: textSecondaryColor
                    font.pixelSize: fontBase
                    font.family: "Segoe UI"
                }
            }
        }
        
        // ===== FORMULARIO =====
        GroupBox {
            Layout.fillWidth: true
            title: isEditMode ? "Editar Tipo de Gasto" : "Agregar Nuevo Tipo de Gasto"
            
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
                            text: "Nombre:"
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
                        spacing: marginSmall
                        
                        Label {
                            text: "Color:"
                            font.bold: true
                            color: textColor
                            font.pixelSize: fontBase
                            font.family: "Segoe UI"
                        }
                        
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: marginSmall
                            
                            ComboBox {
                                id: nuevoTipoGastoColor
                                Layout.fillWidth: true
                                Layout.preferredHeight: baseUnit * 4.5
                                model: [
                                    { text: "Azul (Servicios)", value: infoColor },
                                    { text: "Violeta (Personal)", value: violetColor },
                                    { text: "Verde (Alimentación)", value: successColor },
                                    { text: "Amarillo (Mantenimiento)", value: warningColor },
                                    { text: "Azul Oscuro (Administrativos)", value: primaryColor },
                                    { text: "Naranja (Suministros)", value: "#e67e22" },
                                    { text: "Gris (Otros)", value: "#95a5a6" },
                                    { text: "Rojo (Emergencias)", value: dangerColor }
                                ]
                                
                                textRole: "text"
                                valueRole: "value"
                                
                                background: Rectangle {
                                    color: backgroundColor
                                    border.color: borderColor
                                    border.width: 1
                                    radius: radiusSmall
                                }
                            }
                            
                            Rectangle {
                                Layout.preferredWidth: baseUnit * 4
                                Layout.preferredHeight: baseUnit * 4
                                color: nuevoTipoGastoColor.currentValue || "#95a5a6"
                                radius: radiusSmall
                                border.color: borderColor
                                border.width: 1
                            }
                        }
                    }
                }
                
                // DESCRIPCIÓN
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
                    
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: baseUnit * 8
                        
                        TextArea {
                            id: nuevoTipoGastoDescripcion
                            placeholderText: "Descripción del tipo de gasto..."
                            wrapMode: TextArea.Wrap
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
                
                // EJEMPLOS Y BOTONES
                RowLayout {
                    Layout.fillWidth: true
                    spacing: marginMedium
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: marginSmall
                        
                        Label {
                            text: "Ejemplos (separados por comas):"
                            font.bold: true
                            color: textColor
                            font.pixelSize: fontBase
                            font.family: "Segoe UI"
                        }
                        TextField {
                            id: nuevoTipoGastoEjemplos
                            Layout.fillWidth: true
                            Layout.preferredHeight: baseUnit * 4.5
                            placeholderText: "Ej: Agua, Luz, Gas"
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
                            enabled: nuevoTipoGastoNombre.text && nuevoTipoGastoDescripcion.text && 
                                    nuevoTipoGastoEjemplos.text
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
                        text: "📋 Tipos de Gastos Registrados"
                        font.pixelSize: fontMedium
                        font.bold: true
                        color: textColor
                        font.family: "Segoe UI"
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
                        spacing: marginSmall
                        
                        delegate: Rectangle {
                            width: ListView.view.width
                            height: baseUnit * 12
                            color: index % 2 === 0 ? backgroundColor : "#fafafa"
                            border.color: borderColor
                            border.width: 1
                            radius: radiusSmall
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: marginMedium
                                spacing: marginMedium
                                
                                // CONTENIDO PRINCIPAL
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: marginSmall
                                    
                                    RowLayout {
                                        Layout.fillWidth: true
                                        
                                        Rectangle {
                                            Layout.preferredWidth: baseUnit * 20
                                            Layout.preferredHeight: baseUnit * 3
                                            color: modelData.color || "#95a5a6"
                                            radius: radiusMedium
                                            
                                            Label {
                                                anchors.centerIn: parent
                                                text: modelData.nombre
                                                color: backgroundColor
                                                font.bold: true
                                                font.pixelSize: fontSmall
                                                font.family: "Segoe UI"
                                            }
                                        }
                                        
                                        Item { Layout.fillWidth: true }
                                    }
                                    
                                    Label {
                                        Layout.fillWidth: true
                                        text: modelData.descripcion
                                        color: textColor
                                        font.pixelSize: fontSmall
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                        font.family: "Segoe UI"
                                    }
                                    
                                    Label {
                                        Layout.fillWidth: true
                                        text: "Ejemplos: " + (modelData.ejemplos ? modelData.ejemplos.join(", ") : "")
                                        color: textSecondaryColor
                                        font.pixelSize: fontTiny
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 1
                                        elide: Text.ElideRight
                                        font.family: "Segoe UI"
                                    }
                                }
                                
                                // BOTONES DE ACCIÓN
                                RowLayout {
                                    spacing: marginSmall
                                    
                                    Button {
                                        Layout.preferredWidth: baseUnit * 4
                                        Layout.preferredHeight: baseUnit * 4
                                        text: "✏️"
                                        
                                        background: Rectangle {
                                            color: parent.pressed ? Qt.darker(warningColor, 1.2) : warningColor
                                            radius: radiusSmall
                                        }
                                        
                                        contentItem: Label {
                                            text: parent.text
                                            color: backgroundColor
                                            font.pixelSize: fontBase
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        
                                        onClicked: editarTipoGasto(index)
                                    }
                                    
                                    Button {
                                        Layout.preferredWidth: baseUnit * 4
                                        Layout.preferredHeight: baseUnit * 4
                                        text: "🗑️"
                                        
                                        background: Rectangle {
                                            color: parent.pressed ? Qt.darker(dangerColor, 1.2) : dangerColor
                                            radius: radiusSmall
                                        }
                                        
                                        contentItem: Label {
                                            text: parent.text
                                            color: backgroundColor
                                            font.pixelSize: fontBase
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