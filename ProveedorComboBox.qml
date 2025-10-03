import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// ComboBox de proveedores - SIN BUCLES NI QOBJECT ERRORS
Item {
    id: root
    
    property var proveedoresModel: []
    property string proveedorSeleccionado: ""
    property int proveedorIdSeleccionado: 0
    property string placeholderText: "Buscar proveedor..."
    property bool cargandoProgramaticamente: false
    
    signal proveedorCambiado(string proveedor, int proveedorId)
    signal nuevoProveedorCreado(string nombreProveedor)
    signal buscarProveedores(string termino)
    
    property color primaryColor: "#2563EB"
    property color successColor: "#059669"
    property color dangerColor: "#DC2626"
    property color lightGray: "#F3F4F6"
    property color darkGray: "#6B7280"
    property color borderColor: "#D1D5DB"
    
    implicitHeight: 45
    
    // ✅ VALIDACIÓN SIMPLE PARA QOBJECTS
    function esProveedorValido(proveedor) {
        if (!proveedor) return false
        
        // QObjects se validan diferente que objetos JS
        try {
            // Intentar acceder a las propiedades directamente
            var id = proveedor.id
            var nombre = proveedor.nombre
            return id !== undefined && nombre !== undefined && nombre !== ""
        } catch (e) {
            return false
        }
    }
    
    // ✅ BANDERA PARA EVITAR BUCLES
    property bool actualizandoModelo: false
    
    Rectangle {
        anchors.fill: parent
        color: "white"
        border.color: {
            if (searchField.activeFocus) return primaryColor
            return borderColor
        }
        border.width: 2
        radius: 8
        
        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10
            
            Label {
                text: proveedorIdSeleccionado > 0 ? "🏢" : "🔍"
                font.pixelSize: 16
                color: darkGray
            }
            
            TextField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: root.placeholderText
                font.pixelSize: 13
                color: "#2c3e50"
                
                background: Rectangle { color: "transparent" }
                
                onTextChanged: {
                    if (cargandoProgramaticamente || actualizandoModelo) return
                    
                    if (text.length === 0) {
                        filtrarProveedores()
                        dropdownPopup.close()
                    } else if (text.length >= 2) {
                        filtrarProveedores()
                        if (!dropdownPopup.opened) {
                            dropdownPopup.open()
                        }
                    }
                }
                
                onActiveFocusChanged: {
                    if (activeFocus && text.length >= 2) {
                        dropdownPopup.open()
                    }
                }
                
                Keys.onEscapePressed: dropdownPopup.close()
            }
            
            Button {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                
                background: Rectangle {
                    color: parent.hovered ? lightGray : "transparent"
                    radius: 4
                }
                
                contentItem: Label {
                    text: dropdownPopup.visible ? "▲" : "▼"
                    color: darkGray
                    font.pixelSize: 10
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: {
                    if (dropdownPopup.visible) {
                        dropdownPopup.close()
                    } else {
                        filtrarProveedores()
                        dropdownPopup.open()
                    }
                }
            }
            
            Button {
                visible: searchField.text.length > 0
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                
                background: Rectangle {
                    color: parent.hovered ? "#FCA5A5" : lightGray
                    radius: 12
                }
                
                contentItem: Label {
                    text: "×"
                    color: parent.parent.hovered ? "white" : darkGray
                    font.pixelSize: 14
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: reset()
            }
        }
    }
    
    Popup {
        id: dropdownPopup
        y: parent.height + 4
        width: parent.width
        height: Math.min(300, dropdownContent.implicitHeight + 20)
        
        background: Rectangle {
            color: "white"
            radius: 8
            border.color: borderColor
            border.width: 1
        }
        
        ColumnLayout {
            id: dropdownContent
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4
            
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                color: lightGray
                radius: 6
                visible: proveedoresFiltrados.length > 0
                
                Label {
                    anchors.centerIn: parent
                    text: proveedoresFiltrados.length === 1 ? 
                          "1 proveedor" : 
                          proveedoresFiltrados.length + " proveedores"
                    font.pixelSize: 11
                    color: darkGray
                    font.bold: true
                }
            }
            
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                
                ListView {
                    id: listView
                    model: proveedoresFiltrados
                    spacing: 2
                    
                    delegate: Rectangle {
                        width: listView.width
                        height: 42
                        color: mouseArea.containsMouse ? lightGray : "transparent"
                        radius: 6
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 10
                            
                            Label {
                                text: "🏢"
                                font.pixelSize: 16
                            }
                            
                            Label {
                                text: modelData && modelData.nombre ? modelData.nombre : "Sin nombre"
                                font.pixelSize: 12
                                font.bold: true
                                color: "#2c3e50"
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            
                            Label {
                                text: "✓"
                                font.pixelSize: 14
                                color: successColor
                                visible: modelData && proveedorIdSeleccionado === modelData.id
                            }
                        }
                        
                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: seleccionarProveedor(index)
                        }
                    }
                    
                    Label {
                        anchors.centerIn: parent
                        text: searchField.text.length >= 2 ? 
                              "No se encontraron proveedores" : 
                              "Escribe para buscar (mín. 2 caracteres)"
                        color: darkGray
                        font.pixelSize: 11
                        visible: listView.count === 0
                    }
                }
            }
            
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: borderColor
                visible: searchField.text.trim().length >= 3
            }
            
            Rectangle {
                visible: searchField.text.trim().length >= 3
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                color: crearHover.containsMouse ? Qt.lighter(successColor, 1.7) : lightGray
                radius: 6
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10
                    
                    Rectangle {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        color: successColor
                        radius: 14
                        
                        Label {
                            anchors.centerIn: parent
                            text: "+"
                            font.pixelSize: 16
                            font.bold: true
                            color: "white"
                        }
                    }
                    
                    Label {
                        text: 'Crear: "' + searchField.text.trim() + '"'
                        font.pixelSize: 11
                        font.bold: true
                        color: successColor
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }
                
                MouseArea {
                    id: crearHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: crearNuevoProveedor()
                }
            }
        }
    }
    
    property var proveedoresFiltrados: []
    
    // ✅ FILTRADO SIMPLIFICADO SIN HASOWNPROPERTY
    function filtrarProveedores() {
        if (actualizandoModelo) return
        
        var texto = searchField.text.toLowerCase().trim()
        var filtradas = []
        
        if (!Array.isArray(proveedoresModel)) {
            console.log("⚠️ proveedoresModel no es array")
            proveedoresFiltrados = []
            return
        }
        
        for (var i = 0; i < proveedoresModel.length; i++) {
            var prov = proveedoresModel[i]
            
            if (!esProveedorValido(prov)) continue
            
            if (texto.length === 0) {
                filtradas.push(prov)
            } else {
                try {
                    var nombre = String(prov.nombre || "").toLowerCase()
                    if (nombre.includes(texto)) {
                        filtradas.push(prov)
                    }
                } catch (e) {
                    console.log("⚠️ Error filtrando proveedor:", e)
                }
            }
        }
        
        proveedoresFiltrados = filtradas
    }
    
    function seleccionarProveedor(index) {
        if (index < 0 || index >= proveedoresFiltrados.length) return
        
        var prov = proveedoresFiltrados[index]
        if (!esProveedorValido(prov)) return
        
        try {
            proveedorSeleccionado = String(prov.nombre)
            proveedorIdSeleccionado = Number(prov.id)
            
            cargandoProgramaticamente = true
            searchField.text = String(prov.nombre)
            Qt.callLater(function() { cargandoProgramaticamente = false })
            
            dropdownPopup.close()
            proveedorCambiado(String(prov.nombre), Number(prov.id))
        } catch (e) {
            console.log("⚠️ Error seleccionando:", e)
        }
    }
    
    function crearNuevoProveedor() {
        var nombre = searchField.text.trim()
        if (nombre.length < 3) return
        
        dropdownPopup.close()
        nuevoProveedorCreado(nombre)
    }
    
    function setProveedorById(proveedorId) {
        if (!proveedorId || proveedorId <= 0) {
            reset()
            return
        }
        
        cargandoProgramaticamente = true
        
        for (var i = 0; i < proveedoresModel.length; i++) {
            var prov = proveedoresModel[i]
            if (esProveedorValido(prov) && prov.id === proveedorId) {
                proveedorSeleccionado = String(prov.nombre)
                proveedorIdSeleccionado = proveedorId
                searchField.text = String(prov.nombre)
                break
            }
        }
        
        Qt.callLater(function() { cargandoProgramaticamente = false })
    }
    
    function reset() {
        cargandoProgramaticamente = true
        searchField.text = ""
        proveedorSeleccionado = ""
        proveedorIdSeleccionado = 0
        proveedorCambiado("", 0)
        dropdownPopup.close()
        Qt.callLater(function() { cargandoProgramaticamente = false })
    }
    
    // ✅ EVITAR BUCLE INFINITO
    onProveedoresModelChanged: {
        if (actualizandoModelo) return
        
        actualizandoModelo = true
        Qt.callLater(function() {
            filtrarProveedores()
            actualizandoModelo = false
        })
    }
    
    Component.onCompleted: {
        Qt.callLater(filtrarProveedores)
    }
}