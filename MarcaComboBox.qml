import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// ComboBox inteligente para selección/creación de marcas - VERSIÓN CORREGIDA
Item {
    id: root
    
    // Propiedades públicas
    property var marcasModel: []
    property string marcaSeleccionada: ""
    property int marcaIdSeleccionada: 0
    property bool required: false
    property string placeholderText: "Buscar o crear marca..."
    property bool cargandoProgramaticamente: false
    
    // Señales
    signal marcaCambiada(string marca, int marcaId)
    signal nuevaMarcaCreada(string nombreMarca)
    
    // Colores - Adaptados al estilo de CrearProducto (EDITABLES)
    property color primaryColor: "#2563EB"
    property color successColor: "#059669"
    property color dangerColor: "#DC2626"
    property color lightGray: "#F3F4F6"
    property color darkGray: "#6B7280"
    property color borderColor: "#D1D5DB"
    
    implicitHeight: 40
    
    ColumnLayout {
        anchors.fill: parent
        spacing: 4
        
        // Campo de búsqueda con dropdown
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            color: "white"
            border.color: {
                if (searchField.activeFocus) return primaryColor
                if (required && marcaIdSeleccionada === 0) return dangerColor
                return lightGray
            }
            border.width: 2
            radius: 8
            
            Behavior on border.color {
                ColorAnimation { duration: 200 }
            }
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8
                
                // Icono de búsqueda
                Label {
                    text: "🔍"
                    font.pixelSize: 14
                    color: darkGray
                }
                
                // Campo de texto
                TextField {
                    id: searchField
                    Layout.fillWidth: true
                    placeholderText: root.placeholderText
                    font.pixelSize: 12
                    color: "#2c3e50"
                    
                    background: Rectangle {
                        color: "transparent"
                    }
                    
                    onTextChanged: {
                        filtrarMarcas()
                        if (text.length > 0 && !cargandoProgramaticamente) {
                            dropdownPopup.open()
                        }
                    }
                    
                    onActiveFocusChanged: {
                        if (activeFocus && text.length > 0 && !cargandoProgramaticamente) {
                            dropdownPopup.open()
                        }
                    }
                    
                    Keys.onDownPressed: {
                        if (dropdownListView.count > 0) {
                            dropdownListView.currentIndex = 0
                            dropdownListView.forceActiveFocus()
                        }
                    }
                    
                    Keys.onReturnPressed: {
                        if (dropdownListView.count === 0 && text.trim().length > 0) {
                            crearNuevaMarca()
                        } else if (dropdownListView.currentIndex >= 0) {
                            seleccionarMarca(dropdownListView.currentIndex)
                        }
                    }
                }
                
                // Botón dropdown
                Button {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    text: dropdownPopup.visible ? "▲" : "▼"
                    
                    background: Rectangle {
                        color: parent.pressed ? Qt.darker(lightGray, 1.2) : "transparent"
                        radius: 4
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        color: darkGray
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        if (dropdownPopup.visible) {
                            dropdownPopup.close()
                        } else {
                            filtrarMarcas()
                            dropdownPopup.open()
                        }
                    }
                }
                
                // Botón limpiar
                Button {
                    visible: searchField.text.length > 0
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    text: "✕"
                    
                    background: Rectangle {
                        color: parent.pressed ? Qt.darker(lightGray, 1.2) : lightGray
                        radius: 10
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        color: darkGray
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        searchField.text = ""
                        marcaSeleccionada = ""
                        marcaIdSeleccionada = 0
                        marcaCambiada("", 0)
                    }
                }
            }
        }
    }
    
    // Popup del dropdown
    Popup {
        id: dropdownPopup
        y: parent.height 
        width: parent.width
        height: Math.min(320, dropdownContent.implicitHeight + 20)
        
        background: Rectangle {
            // MODIFICAR DESPUES A
            color: "white"
            radius: 8
            border.color: lightGray
            border.width: 1
            
            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 2
                anchors.leftMargin: 2
                color: "#00000020"
                radius: 8
                z: -1
            }
        }
        
        contentItem: ColumnLayout {
            id: dropdownContent
            spacing: 0
            
            ListView {
                id: dropdownListView
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(250, contentHeight)
                clip: true
                
                model: marcasFiltradas
                
                delegate: Rectangle {
                    width: dropdownListView.width
                    height: 40
                    color: {
                        if (dropdownListView.currentIndex === index) return Qt.lighter(primaryColor, 1.8)
                        if (marcaHover.containsMouse) return lightGray
                        return "transparent"
                    }
                    
                    Behavior on color {
                        ColorAnimation { duration: 100 }
                    }
                    radius: 5
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8
                        
                        Label {
                            text: "🏷️"
                            font.pixelSize: 14
                        }
                        
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            
                            Label {
                                text: modelData.nombre || ""
                                font.pixelSize: 12
                                font.bold: true
                                color: "#2c3e50"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            
                            Label {
                                visible: modelData.detalles && modelData.detalles.length > 0
                                text: modelData.detalles || ""
                                font.pixelSize: 9
                                color: darkGray
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                    
                    MouseArea {
                        id: marcaHover
                        anchors.fill: parent
                        hoverEnabled: true
                        
                        onClicked: {
                            seleccionarMarca(index)
                        }
                    }
                }
                
                Item {
                    anchors.centerIn: parent
                    visible: dropdownListView.count === 0 && searchField.text.length === 0
                    width: 200
                    height: 60
                    
                    Label {
                        anchors.centerIn: parent
                        text: "No hay marcas disponibles"
                        color: darkGray
                        font.pixelSize: 11
                    }
                }
                
                Keys.onUpPressed: {
                    if (currentIndex > 0) currentIndex--
                }
                
                Keys.onDownPressed: {
                    if (currentIndex < count - 1) currentIndex++
                }
                
                Keys.onReturnPressed: {
                    if (currentIndex >= 0) {
                        seleccionarMarca(currentIndex)
                    }
                }
            }
            
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: lightGray
                visible: searchField.text.trim().length > 0
            }
            
            Rectangle {
                visible: searchField.text.trim().length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                color: crearMarcaHover.containsMouse ? Qt.lighter(successColor, 1.8) : "transparent"
                Behavior on color {
                    ColorAnimation { duration: 100 }
                }
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8
                    
                    Label {
                        text: "➕"
                        font.pixelSize: 14
                        color: successColor
                    }
                    
                    Label {
                        text: 'Crear marca: "' + searchField.text.trim() + '"'
                        font.pixelSize: 12
                        font.bold: true
                        color: successColor
                        Layout.fillWidth: true
                    }
                }
                
                MouseArea {
                    id: crearMarcaHover
                    anchors.fill: parent
                    hoverEnabled: true
                    
                    onClicked: {
                        crearNuevaMarca()
                    }
                }
            }

        }
    }
    
    property var marcasFiltradas: []
    
    // ========== FUNCIONES CORREGIDAS CON VALIDACIONES ==========
    
    function filtrarMarcas() {
        // Validación robusta
        if (!marcasModel) {
            console.log("⚠️ marcasModel es null")
            marcasFiltradas = []
            return
        }
        
        if (typeof marcasModel.length === 'undefined') {
            console.log("⚠️ marcasModel no es un array")
            marcasFiltradas = []
            return
        }
        
        if (marcasModel.length === 0) {
            console.log("⚠️ marcasModel está vacío")
            marcasFiltradas = []
            return
        }
        
        var texto = searchField.text.toLowerCase().trim()
        
        if (texto.length === 0) {
            // Mostrar todas las marcas
            marcasFiltradas = marcasModel.slice() // Copia para evitar mutación
            console.log("🔍 Mostrando todas las marcas:", marcasFiltradas.length)
        } else {
            // Filtrar por texto
            var filtradas = []
            for (var i = 0; i < marcasModel.length; i++) {
                var marca = marcasModel[i]
                
                // Validar que la marca tenga la estructura correcta
                if (!marca) continue
                
                var nombreMarca = marca.nombre || marca.Nombre || ""
                
                if (nombreMarca.toLowerCase().includes(texto)) {
                    filtradas.push(marca)
                }
            }
            marcasFiltradas = filtradas
            console.log("🔍 Filtradas:", marcasFiltradas.length, "de", marcasModel.length)
        }
    }
    
    function seleccionarMarca(index) {
        // Validaciones exhaustivas
        if (!marcasFiltradas) {
            console.log("❌ marcasFiltradas no disponible")
            return
        }

        if (index < 0 || index >= marcasFiltradas.length) {
            console.log("❌ Índice inválido:", index, "de", marcasFiltradas.length)
            return
        }

        var marca = marcasFiltradas[index]

        if (!marca) {
            console.log("❌ Marca no encontrada en índice:", index)
            return
        }

        // Validar estructura de marca
        var marcaId = marca.id || 0
        var marcaNombre = marca.nombre || marca.Nombre || ""

        if (marcaId === 0 || marcaNombre === "") {
            console.log("❌ Marca inválida - ID:", marcaId, "Nombre:", marcaNombre)
            return
        }

        // ✅ CORRECCIÓN: Actualizar propiedades PRIMERO y luego emitir señal
        cargandoProgramaticamente = true

        // Actualizar propiedades locales del ComboBox
        marcaSeleccionada = marcaNombre
        marcaIdSeleccionada = marcaId
        searchField.text = marcaNombre

        console.log("✅ Marca seleccionada:", marcaNombre, "ID:", marcaId)

        // Cerrar dropdown
        dropdownPopup.close()

        // ✅ CORRECCIÓN CRÍTICA: Emitir señal con valores DIRECTOS, no propiedades
        Qt.callLater(function() {
            marcaCambiada(marcaNombre, marcaId)  // ← Usar variables locales, no propiedades
            cargandoProgramaticamente = false
            console.log("📢 Señal emitida - Marca:", marcaNombre, "ID:", marcaId)
        })
    }
    
    function crearNuevaMarca() {
        var nombreNuevo = searchField.text.trim()
        
        if (nombreNuevo.length < 2) {
            console.log("❌ Nombre muy corto")
            return
        }
        
        // ✅ VALIDAR marcasModel antes de verificar duplicados
        if (marcasModel && marcasModel.length > 0) {
            for (var i = 0; i < marcasModel.length; i++) {
                var marca = marcasModel[i]
                if (marca && marca.nombre && marca.nombre.toLowerCase() === nombreNuevo.toLowerCase()) {
                    console.log("⚠️ Marca ya existe, seleccionándola")
                    seleccionarMarca(i)
                    return
                }
            }
        }
        
        // Marca nueva - emitir señal
        dropdownPopup.close()
        nuevaMarcaCreada(nombreNuevo)
    }
    
    function setMarcaById(marcaId) {
        console.log("🎯 setMarcaById llamado con ID:", marcaId)
        
        // Validar marcaId
        if (!marcaId || marcaId <= 0) {
            console.log("❌ ID de marca inválido:", marcaId)
            return
        }
        
        // Validar marcasModel
        if (!marcasModel || marcasModel.length === 0) {
            console.log("⚠️ marcasModel vacío, esperando datos...")
            
            // Guardar para intentar después
            Qt.callLater(function() {
                if (marcasModel && marcasModel.length > 0) {
                    console.log("🔄 Reintentando setMarcaById después de cargar marcas")
                    setMarcaById(marcaId)
                }
            })
            return
        }
        
        cargandoProgramaticamente = true
        
        // Buscar marca por ID
        var marcaEncontrada = null
        for (var i = 0; i < marcasModel.length; i++) {
            var marca = marcasModel[i]
            if (marca && marca.id === marcaId) {
                marcaEncontrada = marca
                break
            }
        }
        
        if (marcaEncontrada) {
            var nombreMarca = marcaEncontrada.nombre || marcaEncontrada.Nombre || ""
            
            marcaSeleccionada = nombreMarca
            marcaIdSeleccionada = marcaId
            searchField.text = nombreMarca
            
            console.log("✅ Marca establecida programáticamente:", nombreMarca, "ID:", marcaId)
            
            // Emitir señal para notificar el cambio
            Qt.callLater(function() {
                marcaCambiada(marcaSeleccionada, marcaIdSeleccionada)
                cargandoProgramaticamente = false
            })
        } else {
            console.log("❌ No se encontró marca con ID:", marcaId)
            console.log("   Marcas disponibles:", marcasModel.length)
            cargandoProgramaticamente = false
        }
    }

    function recargarMarcas(nuevoMarcasModel) {
        console.log("🔄 Recargando marcas en ComboBox")
        
        if (nuevoMarcasModel && nuevoMarcasModel.length > 0) {
            marcasModel = nuevoMarcasModel
            filtrarMarcas()
            console.log("✅ Marcas recargadas:", marcasModel.length)
        } else {
            console.log("⚠️ No hay marcas para recargar")
        }
    }
    
    function reset() {
        cargandoProgramaticamente = true
        searchField.text = ""
        marcaSeleccionada = ""
        marcaIdSeleccionada = 0
        Qt.callLater(function() {
            cargandoProgramaticamente = false
        })
    }
    
    // Diálogo crear nueva marca
    Dialog {
        id: dialogoCrearMarca
        anchors.centerIn: parent
        width: Math.min(350, parent.width * 0.9)
        height: Math.min(250, parent.height * 0.7)
        modal: true
        
        property string nombreMarca: ""
        
        background: Rectangle {
            color: "white"
            radius: 12
            border.color: lightGray
            border.width: 1
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16
            
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                
                Label {
                    text: "➕"
                    font.pixelSize: 20
                    color: successColor
                }
                
                Label {
                    text: "Crear Nueva Marca"
                    font.pixelSize: 16
                    font.bold: true
                    color: "#2c3e50"
                }
                
                Item { Layout.fillWidth: true }
                
                Button {
                    text: "✕"
                    
                    background: Rectangle {
                        color: parent.pressed ? Qt.darker(dangerColor, 1.2) : dangerColor
                        radius: 16
                        implicitWidth: 32
                        implicitHeight: 32
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        color: "white"
                        font.bold: true
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: dialogoCrearMarca.close()
                }
            }
            
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                
                Label {
                    text: "Nombre de la marca:"
                    font.bold: true
                    font.pixelSize: 11
                    color: "#2c3e50"
                }
                
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    color: lightGray
                    radius: 6
                    
                    Label {
                        anchors.fill: parent
                        anchors.margins: 8
                        text: dialogoCrearMarca.nombreMarca
                        font.pixelSize: 13
                        font.bold: true
                        color: successColor
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
            
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                
                Label {
                    text: "Descripción (opcional):"
                    font.bold: true
                    font.pixelSize: 11
                    color: "#2c3e50"
                }
                
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    color: "white"
                    border.color: descripcionField.activeFocus ? primaryColor : lightGray
                    border.width: 2
                    radius: 6
                    
                    TextArea {
                        id: descripcionField
                        anchors.fill: parent
                        anchors.margins: 6
                        placeholderText: "Ej: Empresa farmacéutica internacional..."
                        font.pixelSize: 11
                        color: "#2c3e50"
                        wrapMode: TextArea.Wrap
                        
                        background: Rectangle {
                            color: "transparent"
                        }
                    }
                }
            }
            
            Item { Layout.fillHeight: true }
            
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                
                Item { Layout.fillWidth: true }
                
                Button {
                    text: "Cancelar"
                    
                    background: Rectangle {
                        color: parent.pressed ? Qt.darker(darkGray, 1.2) : darkGray
                        radius: 6
                        implicitWidth: 90
                        implicitHeight: 32
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        color: "white"
                        font.bold: true
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: dialogoCrearMarca.close()
                }
                
                Button {
                    text: "Crear Marca"
                    
                    background: Rectangle {
                        color: parent.pressed ? Qt.darker(successColor, 1.2) : successColor
                        radius: 6
                        implicitWidth: 110
                        implicitHeight: 32
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        color: "white"
                        font.bold: true
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        confirmarCreacionMarca()
                    }
                }
            }
        }
    }
    
    function confirmarCreacionMarca() {
        var nombre = dialogoCrearMarca.nombreMarca.trim()
        
        if (nombre.length < 2) {
            console.log("❌ Nombre muy corto")
            return
        }
        
        nuevaMarcaCreada(nombre)
        dialogoCrearMarca.close()
        descripcionField.text = ""
    }
    
    Component.onCompleted: {
        console.log("🎬 MarcaComboBox inicializado")
        console.log("   - Marcas disponibles:", marcasModel ? marcasModel.length : 0)
        
        // Cargar marcas iniciales
        filtrarMarcas()
    }
    
    // ✅ Observar cambios en marcasModel
    onMarcasModelChanged: {
        console.log("🔄 marcasModel cambió, refrescando filtros")
        console.log("   - Marcas disponibles:", marcasModel ? marcasModel.length : 0)
        
        // Forzar actualización inmediata
        Qt.callLater(function() {
            filtrarMarcas()
            
            // Si tenemos marcas y hay una selección pendiente, restaurarla
            if (marcaIdSeleccionada > 0 && marcasModel && marcasModel.length > 0) {
                console.log("🔍 Verificando selección actual ID:", marcaIdSeleccionada)
                var encontrada = false
                
                for (var i = 0; i < marcasModel.length; i++) {
                    if (marcasModel[i].id === marcaIdSeleccionada) {
                        encontrada = true
                        console.log("✅ Marca actual aún válida:", marcasModel[i].nombre)
                        break
                    }
                }
                
                if (!encontrada) {
                    console.log("⚠️ Marca seleccionada ya no existe, limpiando")
                    limpiarSeleccion()
                }
            }
        })
    }

    // Agregar estas funciones para mejor control:
    function limpiarSeleccion() {
        cargandoProgramaticamente = true
        searchField.text = ""
        marcaSeleccionada = ""
        marcaIdSeleccionada = 0
        Qt.callLater(function() {
            cargandoProgramaticamente = false
        })
    }


    function forzarSeleccion(marcaId, nombreMarca) {
        console.log("🎯 Forzando selección - ID:", marcaId, "Nombre:", nombreMarca)
        
        cargandoProgramaticamente = true
        
        // Actualizar propiedades internas
        marcaSeleccionada = nombreMarca || ""
        marcaIdSeleccionada = marcaId || 0
        searchField.text = nombreMarca || ""
        
        // Emitir señal inmediatamente
        if (marcaId > 0 && nombreMarca) {
            marcaCambiada(nombreMarca, marcaId)
        }
        
        Qt.callLater(function() {
            cargandoProgramaticamente = false
            console.log("✅ Selección forzada completada")
        })
    }
}