import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: autoCompleteRoot
    
    // Propiedades públicas
    property alias text: textField.text
    property alias placeholderText: textField.placeholderText
    property string fieldType: "nombre" // nombre, apellido_paterno, apellido_materno
    property bool showSuggestions: false
    
    // Propiedades internas
    property int selectedIndex: -1
    property int maxSuggestions: 8
    property bool isSelecting: false
    
    // Acceso a modelo
    property var pacienteModel: null
    
    // Colores y dimensiones
    readonly property real baseUnit: Math.max(8, parent.height / 100)
    readonly property color borderColor: "#e0e0e0"
    readonly property color focusColor: "#3498DB"
    readonly property color suggestionHoverColor: "#F8F9FA"
    readonly property color suggestionSelectedColor: "#E3F2FD"
    
    // Señales
    signal suggestionSelected(var pacienteData)
    signal textEdited(string text)
    
    // Debounce timer
    Timer {
        id: searchTimer
        interval: 300
        running: false
        repeat: false
        onTriggered: {
            if (textField.text.length >= 2 && !isSelecting && pacienteModel) {
                pacienteModel.buscarSugerenciasPacientes(textField.text.trim())
            } else {
                suggestionsModel.clear()
                showSuggestions = false
            }
        }
    }
    
    // Modelo para sugerencias
    ListModel {
        id: suggestionsModel
    }
    
    // Layout principal
    implicitHeight: baseUnit * 4
    implicitWidth: 200
    
    Column {
        anchors.fill: parent
        spacing: 0
        
        // Campo de texto principal
        TextField {
            id: textField
            width: parent.width
            height: baseUnit * 4
            
            background: Rectangle {
                color: "white"
                border.color: textField.activeFocus ? focusColor : borderColor
                border.width: textField.activeFocus ? 2 : 1
                radius: baseUnit * 0.6
                
                // Indicador de sugerencias disponibles
                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: baseUnit
                    anchors.verticalCenter: parent.verticalCenter
                    width: baseUnit
                    height: baseUnit
                    radius: width / 2
                    color: showSuggestions ? focusColor : "transparent"
                    visible: showSuggestions && suggestionsModel.count > 0
                    
                    Text {
                        anchors.centerIn: parent
                        text: suggestionsModel.count.toString()
                        color: "white"
                        font.pixelSize: baseUnit * 0.6
                        font.bold: true
                    }
                }
            }
            
            onTextChanged: {
                if (!isSelecting) {
                    searchTimer.restart()
                    autoCompleteRoot.textEdited(text)
                }
                isSelecting = false
            }
            
            onFocusChanged: {
                if (!focus) {
                    // Pequeño delay para permitir clics en sugerencias
                    Qt.callLater(function() {
                        if (!suggestionsList.activeFocus) {
                            showSuggestions = false
                        }
                    })
                }
            }
            
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (suggestionsModel.count > 0 && selectedIndex >= 0) {
                        selectSuggestion(selectedIndex)
                        event.accepted = true
                    } else {
                        showSuggestions = false
                        event.accepted = true
                    }
                } else if (event.key === Qt.Key_Escape) {
                    showSuggestions = false
                    event.accepted = true
                }
            }
        }
        
        // Lista de sugerencias
        Rectangle {
            id: suggestionsContainer
            width: parent.width
            height: visible ? Math.min(suggestionsModel.count * (baseUnit * 3.5), baseUnit * 20) : 0
            visible: showSuggestions && suggestionsModel.count > 0
            
            color: "white"
            border.color: borderColor
            border.width: 1
            radius: baseUnit * 0.6
            z: 1000
            
            // Sombra
            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 2
                anchors.leftMargin: 2
                color: "#40000000"
                radius: parent.radius
                z: -1
            }
            
            ListView {
                id: suggestionsList
                anchors.fill: parent
                anchors.margins: 2
                model: suggestionsModel
                currentIndex: selectedIndex
                clip: true
                
                delegate: Rectangle {
                    width: ListView.view.width
                    height: baseUnit * 3.5
                    color: {
                        if (ListView.isCurrentItem) return suggestionSelectedColor
                        if (mouseArea.containsMouse) return suggestionHoverColor
                        return "transparent"
                    }
                    radius: baseUnit * 0.3
                    
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: baseUnit * 0.1
                        
                        Label { 
                            Layout.fillWidth: true
                            text: {
                                switch(fieldType) {
                                    case "nombre": return model.nombre;
                                    case "apellido_paterno": return model.apellido_paterno;
                                    case "apellido_materno": return model.apellido_materno;
                                    default: return model.nombre_completo;
                                }
                            }
                            color: textColor
                            font.pixelSize: fontBaseSize * 0.9
                            elide: Text.ElideRight
                        }
                        
                        Label {
                            Layout.fillWidth: true
                            text: `ID: ${model.id} • ${model.edad} años`
                            color: textColorLight
                            font.pixelSize: fontBaseSize * 0.7
                            elide: Text.ElideRight
                            visible: fieldType === "nombre" // Solo mostrar info adicional en campo nombre
                        }
}
                    
                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        
                        onClicked: {
                            selectedIndex = index
                            selectSuggestion(index)
                        }
                        
                        onEntered: {
                            selectedIndex = index
                            suggestionsList.currentIndex = index
                        }
                    }
                }
            }
        }
    }
    
    // Conexiones con modelo
    Connections {
        target: pacienteModel
        function onSugerenciasPacientesDisponibles(sugerencias) {
            console.log("🔍 Sugerencias recibidas:", sugerencias.length)
            
            suggestionsModel.clear()
            
            for (var i = 0; i < Math.min(sugerencias.length, maxSuggestions); i++) {
                suggestionsModel.append(sugerencias[i])
            }
            
            showSuggestions = suggestionsModel.count > 0
            selectedIndex = suggestionsModel.count > 0 ? 0 : -1
            
            if (showSuggestions) {
                suggestionsList.currentIndex = 0
            }
        }
    }
    
    // Funciones
    function selectSuggestion(index) {
        if (index < 0 || index >= suggestionsModel.count) return
        
        var suggestion = suggestionsModel.get(index)
        
        // Marcar que estamos seleccionando para evitar nueva búsqueda
        isSelecting = true
        
        // Actualizar texto del campo
        if (fieldType === "nombre") {
            textField.text = suggestion.nombre
        } else if (fieldType === "apellido_paterno") {
            textField.text = suggestion.apellido_paterno
        } else if (fieldType === "apellido_materno") {
            textField.text = suggestion.apellido_materno
        } else {
            textField.text = suggestion.nombre_completo
        }
        
        // Ocultar sugerencias
        showSuggestions = false
        selectedIndex = -1
        
        // Emitir señal con datos completos del paciente
        suggestionSelected({
            id: suggestion.id,
            nombre: suggestion.nombre,
            apellido_paterno: suggestion.apellido_paterno,
            apellido_materno: suggestion.apellido_materno,
            edad: suggestion.edad,
            nombre_completo: suggestion.nombre_completo
        })
        
        console.log("✅ Sugerencia seleccionada:", suggestion.nombre_completo)
    }
    
    function clearSuggestions() {
        suggestionsModel.clear()
        showSuggestions = false
        selectedIndex = -1
    }
    
    function focusField() {
        textField.forceActiveFocus()
    }
}