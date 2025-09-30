import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

Item {
    id: ingresosExtrasRoot
    
    // Propiedades mejoradas para responsividad
    readonly property real baseUnit: Math.max(Math.min(width, height) / 40, 8)
    readonly property real fontBase: Math.max(12, 14 * Math.min(Math.max(width / 800, height / 600), 1.5))
    readonly property color primaryColor: "#27ae60"
    readonly property color whiteColor: "#FFFFFF"
    readonly property color textColor: "#2c3e50"
    readonly property color borderColor: "#bdc3c7"
    readonly property color hoverColor: "#ecf0f1"
    readonly property color selectedColor: "#d5f4e6"
    
    // Estado para manejar selección
    property int selectedIndex: -1
    property var selectedItem: null
    
    // Funciones de utilidad
    function showNotification(message, isError = false) {
        notificationText.text = message
        notificationPopup.bgColor = isError ? "#e74c3c" : primaryColor
        notificationPopup.open()
    }
    
    function clearSelection() {
        selectedIndex = -1
        selectedItem = null
    }

    Rectangle {
        anchors.fill: parent
        color: whiteColor
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: baseUnit
            spacing: baseUnit
            
            // Header
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: baseUnit * 4
                Layout.minimumHeight: baseUnit * 3
                Layout.maximumHeight: baseUnit * 6
                color: primaryColor
                radius: baseUnit * 0.5
                
                Label {
                    anchors.centerIn: parent
                    text: "GESTIÓN DE INGRESOS EXTRAS"
                    color: whiteColor
                    font.bold: true
                    font.pixelSize: fontBase * 1.2
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
            
            // Formulario de Ingreso
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: baseUnit * 12
                Layout.minimumHeight: baseUnit * 10
                Layout.maximumHeight: baseUnit * 16
                color: "#f8f9fa"
                radius: baseUnit * 0.5
                border.color: borderColor
                border.width: 1
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: baseUnit * 1.5
                    spacing: baseUnit
                    
                    Label {
                        text: "Nuevo Ingreso Extra"
                        font.bold: true
                        font.pixelSize: fontBase * 1.1
                        color: textColor
                        Layout.fillWidth: true
                    }
                    
                    // Fila 1: Descripción
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: baseUnit
                        
                        Label {
                            text: "Descripción:"
                            font.pixelSize: fontBase
                            Layout.preferredWidth: baseUnit * 8
                            Layout.minimumWidth: baseUnit * 6
                            color: textColor
                        }
                        
                        TextField {
                            id: txtDescripcion
                            Layout.fillWidth: true
                            placeholderText: "Ingrese la descripción del ingreso"
                            font.pixelSize: fontBase * 0.9
                            focus: true
                            
                            background: Rectangle {
                                radius: baseUnit * 0.3
                                border.color: parent.activeFocus ? primaryColor : borderColor
                                border.width: parent.activeFocus ? 2 : 1
                            }
                        }
                    }
                    
                    // Fila 2: Monto y Fecha
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: baseUnit
                        
                        Label {
                            text: "Monto:"
                            font.pixelSize: fontBase
                            Layout.preferredWidth: baseUnit * 8
                            Layout.minimumWidth: baseUnit * 6
                            color: textColor
                        }
                        
                        TextField {
                            id: txtMonto
                            Layout.preferredWidth: baseUnit * 10
                            Layout.minimumWidth: baseUnit * 8
                            placeholderText: "0.00"
                            font.pixelSize: fontBase * 0.9
                            validator: DoubleValidator {
                                bottom: 0
                                decimals: 2
                                notation: DoubleValidator.StandardNotation
                            }
                            
                            background: Rectangle {
                                radius: baseUnit * 0.3
                                border.color: parent.activeFocus ? primaryColor : borderColor
                                border.width: parent.activeFocus ? 2 : 1
                            }
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        Label {
                            text: "Fecha:"
                            font.pixelSize: fontBase
                            color: textColor
                            Layout.preferredWidth: baseUnit * 4
                        }
                        
                        TextField {
                            id: txtFecha
                            Layout.preferredWidth: baseUnit * 10
                            Layout.minimumWidth: baseUnit * 8
                            text: Qt.formatDate(new Date(), "yyyy-MM-dd")
                            font.pixelSize: fontBase * 0.9
                            
                            background: Rectangle {
                                radius: baseUnit * 0.3
                                border.color: parent.activeFocus ? primaryColor : borderColor
                                border.width: parent.activeFocus ? 2 : 1
                            }
                        }
                    }
                    
                    // Botones
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: baseUnit
                        
                        Item { Layout.fillWidth: true }
                        
                        Button {
                            text: "Guardar"
                            font.pixelSize: fontBase * 0.9
                            Layout.preferredWidth: baseUnit * 8
                            Layout.minimumWidth: baseUnit * 6
                            
                            background: Rectangle {
                                color: parent.pressed ? "#1e8449" : (parent.hovered ? "#229954" : primaryColor)
                                radius: baseUnit * 0.3
                            }
                            
                            contentItem: Label {
                                text: parent.text
                                color: whiteColor
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                font: parent.font
                            }
                            
                            onClicked: {
                                if (txtDescripcion.text && txtMonto.text) {
                                    console.log("Guardar:", txtDescripcion.text, txtMonto.text, txtFecha.text)
                                    // backend.guardarIngreso(txtDescripcion.text, parseFloat(txtMonto.text), txtFecha.text)
                                    showNotification("¡Ingreso extra guardado exitosamente!")
                                    txtDescripcion.text = ""
                                    txtMonto.text = ""
                                    txtFecha.text = Qt.formatDate(new Date(), "yyyy-MM-dd")
                                } else {
                                    showNotification("Por favor, complete todos los campos", true)
                                }
                            }
                        }
                        
                        Button {
                            text: "Limpiar"
                            font.pixelSize: fontBase * 0.9
                            Layout.preferredWidth: baseUnit * 8
                            Layout.minimumWidth: baseUnit * 6
                            
                            background: Rectangle {
                                color: parent.pressed ? "#7f8c8d" : (parent.hovered ? "#95a5a6" : "#bdc3c7")
                                radius: baseUnit * 0.3
                            }
                            
                            contentItem: Label {
                                text: parent.text
                                color: textColor
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                font: parent.font
                            }
                            
                            onClicked: {
                                txtDescripcion.text = ""
                                txtMonto.text = ""
                                txtFecha.text = Qt.formatDate(new Date(), "yyyy-MM-dd")
                                clearSelection()
                            }
                        }
                    }
                }
            }
            
            // Tabla de Ingresos Extras
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#f8f9fa"
                radius: baseUnit * 0.5
                border.color: borderColor
                border.width: 1
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: baseUnit
                    spacing: baseUnit * 0.5
                    
                    Label {
                        text: "Historial de Ingresos Extras"
                        font.bold: true
                        font.pixelSize: fontBase * 1.1
                        color: textColor
                        Layout.fillWidth: true
                    }
                    
                    // Header de la tabla
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: baseUnit * 2.5
                        color: primaryColor
                        radius: baseUnit * 0.3
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: baseUnit * 0.5
                            spacing: baseUnit * 0.5
                            
                            Label {
                                text: "ID"
                                color: whiteColor
                                font.bold: true
                                font.pixelSize: fontBase * 0.9
                                Layout.preferredWidth: baseUnit * 4
                                Layout.minimumWidth: baseUnit * 3
                                horizontalAlignment: Text.AlignHCenter
                            }
                            
                            Label {
                                text: "DESCRIPCIÓN"
                                color: whiteColor
                                font.bold: true
                                font.pixelSize: fontBase * 0.9
                                Layout.fillWidth: true
                                Layout.minimumWidth: baseUnit * 8
                                elide: Text.ElideRight
                            }
                            
                            Label {
                                text: "MONTO"
                                color: whiteColor
                                font.bold: true
                                font.pixelSize: fontBase * 0.9
                                Layout.preferredWidth: baseUnit * 8
                                Layout.minimumWidth: baseUnit * 6
                                horizontalAlignment: Text.AlignRight
                            }
                            
                            Label {
                                text: "FECHA"
                                color: whiteColor
                                font.bold: true
                                font.pixelSize: fontBase * 0.9
                                Layout.preferredWidth: baseUnit * 8
                                Layout.minimumWidth: baseUnit * 6
                                horizontalAlignment: Text.AlignHCenter
                            }
                            
                            Label {
                                text: "REGISTRADO POR"
                                color: whiteColor
                                font.bold: true
                                font.pixelSize: fontBase * 0.9
                                Layout.preferredWidth: baseUnit * 10
                                Layout.minimumWidth: baseUnit * 8
                                elide: Text.ElideRight
                            }
                        }
                    }
                    
                    // Lista scrolleable
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        
                        ListView {
                            id: listViewIngresos
                            anchors.fill: parent
                            spacing: 1
                            boundsBehavior: Flickable.StopAtBounds
                            
                            // Modelo de ejemplo (conectar con backend Python)
                            model: ListModel {
                                id: ingresosModel
                                // Datos de ejemplo
                                ListElement {
                                    id_registro: 1
                                    descripcion: "Venta extra de productos en línea"
                                    monto: 500.00
                                    fecha: "2025-09-15"
                                    registradoPor: "Juan Perez"
                                }
                                ListElement {
                                    id_registro: 2
                                    descripcion: "Consultoría adicional proyecto X"
                                    monto: 1200.50
                                    fecha: "2025-09-14"
                                    registradoPor: "María García"
                                }
                                ListElement {
                                    id_registro: 3
                                    descripcion: "Bonificación por resultados"
                                    monto: 800.00
                                    fecha: "2025-09-10"
                                    registradoPor: "Carlos López"
                                }
                            }
                            
                            delegate: Rectangle {
                                id: delegateItem
                                width: listViewIngresos.width
                                height: baseUnit * 3
                                color: {
                                    if (ingresosExtrasRoot.selectedIndex === index) 
                                        return selectedColor
                                    else if (mouseArea.containsMouse)
                                        return hoverColor
                                    else 
                                        return index % 2 === 0 ? whiteColor : "#f8f9fa"
                                }
                                border.color: ingresosExtrasRoot.selectedIndex === index ? primaryColor : "transparent"
                                border.width: ingresosExtrasRoot.selectedIndex === index ? 2 : 0
                                
                                // Separador sutil
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: 1
                                    color: borderColor
                                    opacity: 0.5
                                }
                                
                                MouseArea {
                                    id: mouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    
                                    onClicked: function(mouse) {
                                        if (mouse.button === Qt.LeftButton) {
                                            // Selección con clic izquierdo
                                            ingresosExtrasRoot.selectedIndex = index
                                            ingresosExtrasRoot.selectedItem = model
                                        } else if (mouse.button === Qt.RightButton) {
                                            // Selección y menú contextual con clic derecho
                                            if (ingresosExtrasRoot.selectedIndex !== index) {
                                                ingresosExtrasRoot.selectedIndex = index
                                                ingresosExtrasRoot.selectedItem = model
                                            }
                                            contextMenu.popup(mouse.x, mouse.y)
                                        }
                                    }
                                }
                                
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: baseUnit * 0.5
                                    spacing: baseUnit * 0.5
                                    
                                    Label {
                                        text: model.id_registro
                                        font.pixelSize: fontBase * 0.85
                                        color: textColor
                                        Layout.preferredWidth: baseUnit * 4
                                        Layout.minimumWidth: baseUnit * 3
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    
                                    Label {
                                        text: model.descripcion
                                        font.pixelSize: fontBase * 0.85
                                        color: textColor
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: baseUnit * 8
                                        elide: Text.ElideRight
                                    }
                                    
                                    Label {
                                        text: "Bs. " + model.monto.toFixed(2)
                                        font.pixelSize: fontBase * 0.85
                                        color: primaryColor
                                        font.bold: true
                                        Layout.preferredWidth: baseUnit * 8
                                        Layout.minimumWidth: baseUnit * 6
                                        horizontalAlignment: Text.AlignRight
                                    }
                                    
                                    Label {
                                        text: model.fecha
                                        font.pixelSize: fontBase * 0.85
                                        color: textColor
                                        Layout.preferredWidth: baseUnit * 8
                                        Layout.minimumWidth: baseUnit * 6
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    
                                    Label {
                                        text: model.registradoPor
                                        font.pixelSize: fontBase * 0.85
                                        color: textColor
                                        Layout.preferredWidth: baseUnit * 10
                                        Layout.minimumWidth: baseUnit * 8
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Menú contextual para editar/eliminar
    Menu {
        id: contextMenu
        
        MenuItem {
            text: "Editar"
            font.pixelSize: fontBase * 0.9
            
            onTriggered: {
                if (ingresosExtrasRoot.selectedItem) {
                    console.log("Editar ID:", ingresosExtrasRoot.selectedItem.id_registro)
                    // backend.editarIngreso(ingresosExtrasRoot.selectedItem.id_registro)
                }
            }
        }
        
        MenuItem {
            text: "Eliminar"
            font.pixelSize: fontBase * 0.9
            
            onTriggered: {
                if (ingresosExtrasRoot.selectedItem) {
                    deleteConfirmationDialog.open()
                }
            }
        }
    }
    
    // Diálogo de confirmación para eliminar
    Dialog {
        id: deleteConfirmationDialog
        title: "Confirmar Eliminación"
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
        
        Label {
            text: "¿Estás seguro que deseas eliminar este ingreso?"
            font.pixelSize: fontBase
            wrapMode: Text.Wrap
        }
        
        onAccepted: {
            console.log("Eliminar ID:", ingresosExtrasRoot.selectedItem.id_registro)
            // backend.eliminarIngreso(ingresosExtrasRoot.selectedItem.id_registro)
            showNotification("Ingreso extra eliminado.")
            clearSelection()
        }
    }
    
    // Popup de notificación
    Popup {
        id: notificationPopup
        width: parent.width * 0.7
        height: baseUnit * 3
        x: (parent.width - width) / 2
        y: parent.height - height - baseUnit * 2
        modal: false
        closePolicy: Popup.NoAutoClose
        
        property color bgColor: primaryColor
        
        background: Rectangle {
            color: notificationPopup.bgColor
            radius: baseUnit * 0.5
        }
        
        Label {
            id: notificationText
            anchors.centerIn: parent
            color: whiteColor
            font.pixelSize: fontBase
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        
        Timer {
            id: notificationTimer
            interval: 3000
            onTriggered: notificationPopup.close()
        }
        
        onOpened: notificationTimer.start()
        onClosed: notificationTimer.stop()
    }
}