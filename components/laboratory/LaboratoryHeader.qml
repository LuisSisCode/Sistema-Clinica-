import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: headerRoot
    
    // Propiedades recibidas del padre
    property real baseUnit: 8
    property real fontBaseSize: 12
    property color primaryColor: "#3498DB"
    property color textColor: "#2c3e50"
    property color lightGrayColor: "#F8F9FA"
    property color whiteColor: "#FFFFFF"
    property color borderColor: "#e0e0e0"
    
    // Señales
    signal newLabTestRequested()
    
    // Configuración visual
    color: lightGrayColor
    border.color: borderColor
    border.width: 1
    
    Rectangle {
        anchors.fill: parent
        anchors.bottomMargin: baseUnit * 2
        color: parent.color
        radius: parent.radius
    }
    
    RowLayout {
        anchors.fill: parent
        anchors.margins: baseUnit * 1.5
        
        RowLayout {
            spacing: baseUnit
            
            Label {
                text: "🧪"
                font.pixelSize: fontBaseSize * 1.8
                color: primaryColor
            }
            
            Label {
                text: "Gestión de Análisis de Laboratorio"
                font.pixelSize: fontBaseSize * 1.4
                font.bold: true
                font.family: "Segoe UI, Arial, sans-serif"
                color: textColor
            }
        }
        
        Item { Layout.fillWidth: true }
        
        Button {
            objectName: "newLabTestButton"
            text: "➕ Nuevo Análisis"
            Layout.preferredHeight: baseUnit * 4.5
            
            background: Rectangle {
                color: primaryColor
                radius: baseUnit
            }
            
            contentItem: Label {
                text: parent.text
                color: whiteColor
                font.bold: true
                font.pixelSize: fontBaseSize * 0.9
                font.family: "Segoe UI, Arial, sans-serif"
                horizontalAlignment: Text.AlignHCenter
            }
            
            onClicked: {
                newLabTestRequested()
            }
        }
    }
}