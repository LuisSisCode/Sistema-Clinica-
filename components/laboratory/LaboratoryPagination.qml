import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: paginationRoot
    
    // Propiedades recibidas del padre
    property int currentPage: 0
    property int totalPages: 1
    property real baseUnit: 8
    property real fontBaseSize: 12
    property color successColor: "#10B981"
    property color whiteColor: "#FFFFFF"
    property color textColor: "#2c3e50"
    property color lightGrayColor: "#F8F9FA"
    property color borderColor: "#e0e0e0"
    
    // Señales
    signal previousPage()
    signal nextPage()
    
    // Configuración visual
    color: lightGrayColor
    border.color: borderColor
    border.width: 1
    radius: baseUnit
    
    RowLayout {
        anchors.centerIn: parent
        spacing: baseUnit * 2
        
        Button {
            Layout.preferredWidth: baseUnit * 10
            Layout.preferredHeight: baseUnit * 4
            text: "← Anterior"
            enabled: currentPage > 0
            
            background: Rectangle {
                color: parent.enabled ? 
                    (parent.pressed ? Qt.darker(successColor, 1.1) : successColor) : 
                    "#E5E7EB"
                radius: baseUnit * 2
                
                Behavior on color {
                    ColorAnimation { duration: 150 }
                }
            }
            
            contentItem: Label {
                text: parent.text
                color: parent.enabled ? whiteColor : "#9CA3AF"
                font.bold: true
                font.pixelSize: fontBaseSize * 0.9
                font.family: "Segoe UI, Arial, sans-serif"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            
            onClicked: {
                previousPage()
            }
        }
        
        Label {
            text: "Página " + (currentPage + 1) + " de " + Math.max(1, totalPages)
            color: textColor
            font.pixelSize: fontBaseSize * 0.9
            font.family: "Segoe UI, Arial, sans-serif"
            font.weight: Font.Medium
        }
        
        Button {
            Layout.preferredWidth: baseUnit * 11
            Layout.preferredHeight: baseUnit * 4
            text: "Siguiente →"
            enabled: currentPage < totalPages - 1
            
            background: Rectangle {
                color: parent.enabled ? 
                    (parent.pressed ? Qt.darker(successColor, 1.1) : successColor) : 
                    "#E5E7EB"
                radius: baseUnit * 2
                
                Behavior on color {
                    ColorAnimation { duration: 150 }
                }
            }
            
            contentItem: Label {
                text: parent.text
                color: parent.enabled ? whiteColor : "#9CA3AF"
                font.bold: true
                font.pixelSize: fontBaseSize * 0.9
                font.family: "Segoe UI, Arial, sans-serif"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            
            onClicked: {
                nextPage()
            }
        }
    }
}