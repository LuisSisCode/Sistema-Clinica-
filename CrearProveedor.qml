import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

// Modal para crear/editar proveedores
Rectangle {
    id: modalRoot
    anchors.fill: parent
    color: "#80000000"
    visible: false
    z: 1000
    
    // Propiedades del modal
    property bool editMode: false
    property var proveedorData: null
    property var proveedorModel: null
    
    // Señales
    signal dialogClosed()
    
    // Propiedades de colores
    readonly property color primaryColor: "#273746"
    readonly property color successColor: "#27ae60"
    readonly property color dangerColor: "#E74C3C"
    readonly property color lightGrayColor: "#ECF0F1"
    readonly property color darkGrayColor: "#7f8c8d"
    readonly property color textColor: "#2c3e50"
    readonly property color whiteColor: "#FFFFFF"
    
    // Estados de validación
    property bool nombreValido: nombreField.text.trim().length > 0
    property bool direccionValida: direccionField.text.trim().length > 0
    property bool formularioValido: nombreValido && direccionValida
    
    // Cerrar al hacer clic fuera
    MouseArea {
        anchors.fill: parent
        onClicked: {
            dialogClosed()
        }
    }
    
    // Container del modal
    Rectangle {
        anchors.centerIn: parent
        width: Math.min(600, parent.width * 0.9)
        height: Math.min(500, parent.height * 0.8)
        
        color: whiteColor
        radius: 16
        border.color: "#dee2e6"
        border.width: 2
        
        // Evitar que el clic en el modal lo cierre
        MouseArea {
            anchors.fill: parent
            onClicked: {} // No hacer nada
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 20
            
            // Header del modal
            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                
                Rectangle {
                    Layout.preferredWidth: 50
                    Layout.preferredHeight: 50
                    color: editMode ? "#f39c12" : successColor
                    radius: 25
                    
                    Label {
                        anchors.centerIn: parent
                        text: editMode ? "✏️" : "➕"
                        font.pixelSize: 20
                    }
                }
                
                ColumnLayout {
                    spacing: 4
                    
                    Label {
                        text: editMode ? "Editar Proveedor" : "Nuevo Proveedor"
                        color: textColor
                        font.bold: true
                        font.pixelSize: 24
                    }
                    
                    Label {
                        text: editMode ? "Modifica los datos del proveedor" : "Ingresa los datos del nuevo proveedor"
                        color: darkGrayColor
                        font.pixelSize: 14
                    }
                }
                
                Item { Layout.fillWidth: true }
                
                Button {
                    Layout.preferredWidth: 35
                    Layout.preferredHeight: 35
                    
                    background: Rectangle {
                        color: parent.pressed ? Qt.darker(dangerColor, 1.2) : dangerColor
                        radius: 17
                    }
                    
                    contentItem: Label {
                        text: "✕"
                        color: whiteColor
                        font.bold: true
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: dialogClosed()
                }
            }
            
            // Formulario
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                
                ColumnLayout {
                    width: parent.parent.width - 20
                    spacing: 20
                    
                    // Campo Nombre (obligatorio)
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        
                        RowLayout {
                            Label {
                                text: "Nombre del Proveedor"
                                color: textColor
                                font.bold: true
                                font.pixelSize: 14
                            }
                            
                            Label {
                                text: "*"
                                color: dangerColor
                                font.bold: true
                                font.pixelSize: 16
                            }
                        }
                        
                        TextField {
                            id: nombreField
                            Layout.fillWidth: true
                            Layout.preferredHeight: 45
                            placeholderText: "Ej: Laboratorios DROGUERIA SA"
                            
                            background: Rectangle {
                                color: lightGrayColor
                                radius: 8
                                border.color: {
                                    if (!nombreValido && nombreField.text.length > 0) return dangerColor
                                    if (nombreField.activeFocus) return primaryColor
                                    return darkGrayColor
                                }
                                border.width: nombreField.activeFocus ? 2 : 1
                                
                                Behavior on border.color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                            
                            onTextChanged: {
                                // Validación en tiempo real
                                if (text.trim().length === 0) {
                                    errorNombre.text = "El nombre es obligatorio"
                                    errorNombre.visible = true
                                } else if (text.trim().length < 3) {
                                    errorNombre.text = "El nombre debe tener al menos 3 caracteres"
                                    errorNombre.visible = true
                                } else {
                                    errorNombre.visible = false
                                }
                            }
                        }
                        
                        Label {
                            id: errorNombre
                            text: ""
                            color: dangerColor
                            font.pixelSize: 12
                            visible: false
                        }
                    }
                    
                    // Campo Dirección (obligatorio)
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        
                        RowLayout {
                            Label {
                                text: "Dirección"
                                color: textColor
                                font.bold: true
                                font.pixelSize: 14
                            }
                            
                            Label {
                                text: "*"
                                color: dangerColor
                                font.bold: true
                                font.pixelSize: 16
                            }
                        }
                        
                        TextField {
                            id: direccionField
                            Layout.fillWidth: true
                            Layout.preferredHeight: 45
                            placeholderText: "Ej: Av. Cristo Redentor #123, Santa Cruz"
                            
                            background: Rectangle {
                                color: lightGrayColor
                                radius: 8
                                border.color: {
                                    if (!direccionValida && direccionField.text.length > 0) return dangerColor
                                    if (direccionField.activeFocus) return primaryColor
                                    return darkGrayColor
                                }
                                border.width: direccionField.activeFocus ? 2 : 1
                                
                                Behavior on border.color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                            
                            onTextChanged: {
                                if (text.trim().length === 0) {
                                    errorDireccion.text = "La dirección es obligatoria"
                                    errorDireccion.visible = true
                                } else if (text.trim().length < 5) {
                                    errorDireccion.text = "La dirección debe tener al menos 5 caracteres"
                                    errorDireccion.visible = true
                                } else {
                                    errorDireccion.visible = false
                                }
                            }
                        }
                        
                        Label {
                            id: errorDireccion
                            text: ""
                            color: dangerColor
                            font.pixelSize: 12
                            visible: false
                        }
                    }
                    
                    // Campos opcionales en dos columnas
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 20
                        rowSpacing: 16
                        
                        // Campo Teléfono
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            
                            Label {
                                text: "Teléfono"
                                color: textColor
                                font.bold: true
                                font.pixelSize: 14
                            }
                            
                            TextField {
                                id: telefonoField
                                Layout.fillWidth: true
                                Layout.preferredHeight: 45
                                placeholderText: "Ej: +591 3 1234567"
                                
                                background: Rectangle {
                                    color: lightGrayColor
                                    radius: 8
                                    border.color: telefonoField.activeFocus ? primaryColor : darkGrayColor
                                    border.width: telefonoField.activeFocus ? 2 : 1
                                    
                                    Behavior on border.color {
                                        ColorAnimation { duration: 150 }
                                    }
                                }
                            }
                        }
                        
                        // Campo Email
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            
                            Label {
                                text: "Email"
                                color: textColor
                                font.bold: true
                                font.pixelSize: 14
                            }
                            
                            TextField {
                                id: emailField
                                Layout.fillWidth: true
                                Layout.preferredHeight: 45
                                placeholderText: "Ej: ventas@proveedor.com"
                                
                                background: Rectangle {
                                    color: lightGrayColor
                                    radius: 8
                                    border.color: {
                                        if (emailField.text.length > 0 && !isValidEmail(emailField.text)) return dangerColor
                                        if (emailField.activeFocus) return primaryColor
                                        return darkGrayColor
                                    }
                                    border.width: emailField.activeFocus ? 2 : 1
                                    
                                    Behavior on border.color {
                                        ColorAnimation { duration: 150 }
                                    }
                                }
                                
                                onTextChanged: {
                                    if (text.length > 0 && !isValidEmail(text)) {
                                        errorEmail.text = "Formato de email inválido"
                                        errorEmail.visible = true
                                    } else {
                                        errorEmail.visible = false
                                    }
                                }
                            }
                            
                            Label {
                                id: errorEmail
                                text: ""
                                color: dangerColor
                                font.pixelSize: 12
                                visible: false
                            }
                        }
                    }
                    
                    // Campo Contacto
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        
                        Label {
                            text: "Persona de Contacto"
                            color: textColor
                            font.bold: true
                            font.pixelSize: 14
                        }
                        
                        TextField {
                            id: contactoField
                            Layout.fillWidth: true
                            Layout.preferredHeight: 45
                            placeholderText: "Ej: Juan Pérez - Gerente de Ventas"
                            
                            background: Rectangle {
                                color: lightGrayColor
                                radius: 8
                                border.color: contactoField.activeFocus ? primaryColor : darkGrayColor
                                border.width: contactoField.activeFocus ? 2 : 1
                                
                                Behavior on border.color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                        }
                    }
                    
                    // Nota sobre campos obligatorios
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        color: "#fff3cd"
                        radius: 8
                        border.color: "#ffeaa7"
                        border.width: 1
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8
                            
                            Label {
                                text: "ℹ️"
                                font.pixelSize: 16
                            }
                            
                            Label {
                                text: "Los campos marcados con (*) son obligatorios"
                                color: "#856404"
                                font.pixelSize: 12
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
            
            // Botones de acción
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                
                Item { Layout.fillWidth: true }
                
                Button {
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 45
                    text: "Cancelar"
                    
                    background: Rectangle {
                        color: parent.pressed ? "#e9ecef" : "#f8f9fa"
                        radius: 22
                        border.color: "#dee2e6"
                        border.width: 1
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        color: "#6c757d"
                        font.bold: true
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: dialogClosed()
                }
                
                Button {
                    Layout.preferredWidth: 140
                    Layout.preferredHeight: 45
                    text: editMode ? "Actualizar" : "Crear Proveedor"
                    enabled: formularioValido
                    
                    background: Rectangle {
                        color: {
                            if (!parent.enabled) return "#e9ecef"
                            if (parent.pressed) return Qt.darker(successColor, 1.1)
                            return successColor
                        }
                        radius: 22
                        
                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        color: parent.enabled ? whiteColor : "#9ca3af"
                        font.bold: true
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        if (formularioValido) {
                            procesarFormulario()
                        }
                    }
                }
            }
        }
    }
    
    // Funciones auxiliares
    function isValidEmail(email) {
        if (!email || email.trim().length === 0) return true // Email opcional
        var re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
        return re.test(email)
    }
    
    function procesarFormulario() {
        if (!proveedorModel) {
            console.log("❌ ProveedorModel no disponible")
            return
        }
        
        var nombre = nombreField.text.trim()
        var direccion = direccionField.text.trim()
        var telefono = telefonoField.text.trim()
        var email = emailField.text.trim()
        var contacto = contactoField.text.trim()
        
        console.log("📝 Procesando formulario:", editMode ? "Editar" : "Crear")
        console.log("   Nombre:", nombre)
        console.log("   Dirección:", direccion)
        
        var exito = false
        
        if (editMode && proveedorData) {
            // Modo edición
            exito = proveedorModel.actualizar_proveedor(
                proveedorData.id,
                nombre,
                direccion,
                telefono,
                email,
                contacto
            )
        } else {
            // Modo creación
            exito = proveedorModel.crear_proveedor(
                nombre,
                direccion,
                telefono,
                email,
                contacto
            )
        }
        
        if (exito) {
            console.log("✅ Proveedor procesado exitosamente")
            limpiarFormulario()
        }
    }
    
    function limpiarFormulario() {
        nombreField.text = ""
        direccionField.text = ""
        telefonoField.text = ""
        emailField.text = ""
        contactoField.text = ""
        
        // Ocultar errores
        errorNombre.visible = false
        errorDireccion.visible = false
        errorEmail.visible = false
    }
    
    function cargarDatos() {
        if (editMode && proveedorData) {
            nombreField.text = proveedorData.Nombre || ""
            direccionField.text = proveedorData.Direccion || ""
            telefonoField.text = proveedorData.Telefono || ""
            emailField.text = proveedorData.Email || ""
            contactoField.text = proveedorData.Contacto || ""
            
            console.log("📋 Datos cargados para edición:", proveedorData.Nombre)
        } else {
            limpiarFormulario()
        }
    }
    
    // Cargar datos cuando se abre el modal
    onVisibleChanged: {
        if (visible) {
            cargarDatos()
            nombreField.focus = true
        }
    }
    
    // Manejo de teclas
    Keys.onEscapePressed: {
        dialogClosed()
    }
    
    Keys.onEnterPressed: {
        if (formularioValido) {
            procesarFormulario()
        }
    }
    
    Component.onCompleted: {
        console.log("📝 CrearProveedor modal inicializado")
    }
}