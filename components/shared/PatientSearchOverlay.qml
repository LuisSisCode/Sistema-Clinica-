import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Popup {
    id: overlayRoot
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
    // Propiedades públicas
    property var pacienteModel: null
    property int selectedIndex: -1
    property string currentSearchTerm: ""
    
    // Propiedades de posicionamiento
    property Item targetTextField: null
    
    // Cache de búsquedas
    property var searchCache: ({})
    property int maxCacheSize: 20
    // Colores y dimensiones
    readonly property real baseUnit: 8
    readonly property color borderColor: "#e0e0e0"
    readonly property color shadowColor: "#40000000"
    readonly property color hoverColor: "#F8F9FA"
    readonly property color selectedColor: "#E3F2FD"
    readonly property color primaryColor: "#3498DB"
    readonly property color successColor: "#10B981"
    
    // Señales
    signal patientSelected(var patientData)
    signal newPatientRequested(string searchTerm)
    
    // Timer de búsqueda con debounce
    Timer {
        id: searchTimer
        interval: 250
        running: false
        repeat: false
        onTriggered: {
            if (currentSearchTerm.length >= 2 && pacienteModel) {
                pacienteModel.buscarSugerenciasPacientes(currentSearchTerm.trim())
            } else {
                suggestionsModel.clear()
                close()
            }
        }
    }
    
    // Modelo de sugerencias
    ListModel {
        id: suggestionsModel
    }
    
    // Configuración del popup
    modal: true
    focus: true

    padding: 0
    margins: 0
    
    // Dimensiones y posición
    width: targetTextField ? targetTextField.width : 400
    height: Math.min(suggestionsModel.count * 50 + (suggestionsModel.count === 0 ? 100 : 0), 300)
    y: targetTextField ? targetTextField.height + 5 : 0
    
    // Fondo con sombra
    background: Rectangle {
        color: "white"
        border.color: borderColor
        border.width: 1
        radius: 8
        
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 2
            anchors.leftMargin: 2
            color: shadowColor
            radius: parent.radius
            z: -1
        }
    }
    
    contentItem: ColumnLayout {
        spacing: 0
        
        // Header del overlay
        Rectangle {
            id: headerRect
            Layout.fillWidth: true
            height: 35
            color: primaryColor
            radius: 8
            
            Row {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                
                Text {
                    text: searchTimer.running ? "🔄" : "👤"
                    font.pixelSize: 16
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                Text {
                    text: {
                        if (searchTimer.running) return "Buscando..."
                        if (suggestionsModel.count === 0 && currentSearchTerm.length >= 2) 
                            return "No se encontraron pacientes"
                        else 
                            return "Pacientes encontrados: " + suggestionsModel.count
                    }
                    color: "white"
                    font.pixelSize: 12
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            
            // Botón cerrar
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 20
                radius: 10
                color: "white"
                opacity: closeMouseArea.containsMouse ? 0.8 : 0.6
                
                Text {
                    anchors.centerIn: parent
                    text: "×"
                    font.pixelSize: 14
                    font.bold: true
                    color: primaryColor
                }
                
                MouseArea {
                    id: closeMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: overlayRoot.close()
                }
            }
        }
        
        // Lista de sugerencias
        ListView {
            id: suggestionsList
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: suggestionsModel.count * 50
            model: suggestionsModel
            currentIndex: selectedIndex
            clip: true
            visible: suggestionsModel.count > 0
            
            delegate: Rectangle {
                width: ListView.view.width
                height: 45
                color: {
                    if (ListView.isCurrentItem) return selectedColor
                    if (mouseArea.containsMouse) return hoverColor
                    return "transparent"
                }
                
                // Indicador de selección
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 3
                    color: primaryColor
                    visible: ListView.isCurrentItem
                }
                
                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    
                    // Avatar/Icono
                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        color: primaryColor
                        anchors.verticalCenter: parent.verticalCenter
                        
                        Text {
                            anchors.centerIn: parent
                            text: model.nombre ? model.nombre.charAt(0).toUpperCase() : "P"
                            color: "white"
                            font.bold: true
                            font.pixelSize: 14
                        }
                    }
                    
                    // Información del paciente
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        
                        Text {
                            text: (model.nombre || "") + " " + (model.apellido_paterno || "") + " " + (model.apellido_materno || "")
                            font.pixelSize: 13
                            font.bold: true
                            color: "#2c3e50"
                        }
                        
                        Row {
                            spacing: 15
                            
                            Text {
                                text: "CI: " + (model.cedula || "Sin cédula")
                                font.pixelSize: 11
                                color: "#6B7280"
                            }
                            
                            Text {
                                text: (model.edad || "0") + " años"
                                font.pixelSize: 11
                                color: "#6B7280"
                            }
                            
                            Text {
                                text: "ID: " + (model.id || "")
                                font.pixelSize: 11
                                color: "#6B7280"
                            }
                        }
                    }
                }
                
                // Indicador de Enter
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: ListView.isCurrentItem ? "↵" : ""
                    font.pixelSize: 16
                    color: primaryColor
                    font.bold: true
                }
                
                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    
                    onClicked: {
                        selectedIndex = index
                        selectPatient(index)
                    }
                    
                    onEntered: {
                        selectedIndex = index
                        suggestionsList.currentIndex = index
                    }
                }
            }
            onVisibleChanged: {
                if (visible && suggestionsModel.count > 0) {
                    selectedIndex = 0
                    suggestionsList.currentIndex = 0
                    suggestionsList.forceActiveFocus()
                }
            }
            Keys.onReturnPressed: {
                if (selectedIndex >= 0 && selectedIndex < suggestionsModel.count) {
                    selectPatient(selectedIndex)
                }
            }
        }
        
        // Panel para agregar nuevo paciente cuando no hay resultados
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            color: "#F9FAFB"
            visible: suggestionsModel.count === 0 && currentSearchTerm.length >= 2
            
            Column {
                anchors.centerIn: parent
                spacing: 8
                
                Text {
                    text: "¿No encuentras al paciente?"
                    color: "#6B7280"
                    font.pixelSize: 14
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                Button {
                    text: "➕ Agregar nuevo paciente"
                    anchors.horizontalCenter: parent.horizontalCenter
                    
                    background: Rectangle {
                        color: parent.down ? "#0D9488" : successColor
                        radius: 6
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.pixelSize: 12
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        newPatientRequested(currentSearchTerm)
                        close()
                    }
                }
                
                Text {
                    text: "O presiona Enter para agregar"
                    color: "#9CA3AF"
                    font.pixelSize: 11
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
    
    
    // Conexiones con el modelo
    Connections {
        target: pacienteModel
        function onSugerenciasPacientesDisponibles(sugerencias) {
            suggestionsModel.clear()
            
            // Guardar en cache
            if (currentSearchTerm.length >= 2) {
                searchCache[currentSearchTerm] = sugerencias.slice(0, 8)
                // Limpiar cache si es muy grande
                if (Object.keys(searchCache).length > maxCacheSize) {
                    var keys = Object.keys(searchCache)
                    delete searchCache[keys[0]]
                }
            }
            
            for (var i = 0; i < Math.min(sugerencias.length, 8); i++) {
                suggestionsModel.append(sugerencias[i])
            }
            
            selectedIndex = suggestionsModel.count > 0 ? 0 : -1
            if (suggestionsList) {
                suggestionsList.currentIndex = selectedIndex
            }
            
            if (suggestionsModel.count > 0 || currentSearchTerm.length >= 2) {
                open()
            } else {
                close()
            }
        }
    }
    
    // Manejo de teclado global
    Keys.onPressed: (event) => {
        if (!visible) return
        
        if (event.key === Qt.Key_Down) {
            event.accepted = true
            selectedIndex = Math.min(selectedIndex + 1, suggestionsModel.count - 1)
            suggestionsList.currentIndex = selectedIndex
        } else if (event.key === Qt.Key_Up) {
            event.accepted = true
            selectedIndex = Math.max(selectedIndex - 1, 0)
            suggestionsList.currentIndex = selectedIndex
        } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
            event.accepted = true
            if (selectedIndex >= 0 && selectedIndex < suggestionsModel.count) {
                selectPatient(selectedIndex)
            } else if (suggestionsModel.count === 0 && currentSearchTerm.length >= 2) {
                newPatientRequested(currentSearchTerm)
                close()
            }
        } else if (event.key === Qt.Key_Escape) {
            event.accepted = true
            close()
        }
    }
    
    
    // Funciones principales
    function search(term) {
        currentSearchTerm = term
        console.log("🔍 PatientSearchOverlay.search() - Término:", term, "Modelo:", !!pacienteModel)
        
        if (term.length >= 2) {
            if (pacienteModel) {
                // Verificar cache primero
                if (searchCache[term]) {
                    console.log("💾 Usando cache para:", term)
                    _loadFromCache(term)
                    return
                }
                
                console.log("📞 Llamando buscarSugerenciasPacientes...")
                searchTimer.restart()
                open()
            } else {
                console.log("❌ pacienteModel no disponible")
                close()
            }
        } else {
            suggestionsModel.clear()
            close()
        }
    }

    function _loadFromCache(term) {
        var cachedResults = searchCache[term]
        suggestionsModel.clear()
        for (var i = 0; i < cachedResults.length; i++) {
            suggestionsModel.append(cachedResults[i])
        }
        selectedIndex = 0
        open()
}
    
    function selectPatient(index) {
        if (index < 0 || index >= suggestionsModel.count) return
        
        var patient = suggestionsModel.get(index)
        
        // Emitir datos del paciente seleccionado
        patientSelected({
            id: patient.id,
            nombre: patient.nombre,
            apellido_paterno: patient.apellido_paterno,
            apellido_materno: patient.apellido_materno,
            edad: patient.edad,
            cedula: patient.cedula || "",
            nombre_completo: patient.nombre_completo
        })
        
        close()
        console.log("✅ Paciente enviado:", patient.nombre_completo)
    }
    
    // Navegación con flechas externa
    function navigateDown() {
        if (visible && suggestionsModel.count > 0) {
            selectedIndex = Math.min(selectedIndex + 1, suggestionsModel.count - 1)
            suggestionsList.currentIndex = selectedIndex
        }
    }
    
    function navigateUp() {
        if (visible && suggestionsModel.count > 0) {
            selectedIndex = Math.max(selectedIndex - 1, 0)
            suggestionsList.currentIndex = selectedIndex
        }
    }
    
    function selectCurrent() {
        if (visible && selectedIndex >= 0) {
            selectPatient(selectedIndex)
        } else if (visible && suggestionsModel.count === 0 && currentSearchTerm.length >= 2) {
            newPatientRequested(currentSearchTerm)
            close()
        }
    }
    function showOverlay() {
        open()
    }

    function hideOverlay() {
        close()
    }

    function isVisible() {
        return visible
}
}