import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

Item {
    id: ingresosExtrasRoot
    
    // Propiedades básicas
    readonly property real baseUnit: Math.min(width, height) / 40
    readonly property real fontBase: Math.max(14, 16 * Math.max(1.0, height / 700))
    readonly property color primaryColor: "#27ae60"
    readonly property color whiteColor: "#FFFFFF"
    readonly property color textColor: "#2c3e50"
    
    Rectangle {
        anchors.fill: parent
        color: whiteColor
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            
            // Header
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                color: primaryColor
                radius: 10
                
                Label {
                    anchors.centerIn: parent
                    text: "💰 GESTIÓN DE INGRESOS EXTRAS"
                    color: whiteColor
                    font.bold: true
                    font.pixelSize: fontBase * 1.2
                }
            }
            
            // Contenido principal
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                
                Label {
                    anchors.centerIn: parent
                    text: "Módulo de Ingresos Extras en construcción..."
                    color: textColor
                    font.pixelSize: fontBase
                }
            }
        }
    }
}