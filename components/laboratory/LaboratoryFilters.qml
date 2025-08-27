import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: filtersRoot
    
    // Propiedades recibidas del padre
    property real baseUnit: 8
    property real fontBaseSize: 12
    property color textColor: "#2c3e50"
    property color borderColor: "#e0e0e0"
    property color whiteColor: "#FFFFFF"
    
    // Señales
    signal filtersChanged(int fechaFilter, int tipoFilter, string searchText)
    
    // Referencias internas a los controles
    property alias filtroFecha: filtroFecha
    property alias filtroTipo: filtroTipo
    property alias campoBusqueda: campoBusqueda
    
    // Configuración visual
    color: "transparent"
    z: 10
    
    // Layout adaptativo: una fila en pantallas grandes, dos en pequeñas
    GridLayout {
        anchors.fill: parent
        anchors.margins: baseUnit * 3
        anchors.bottomMargin: baseUnit * 1.5
        
        columns: width < 800 ? 2 : 3
        rowSpacing: baseUnit
        columnSpacing: baseUnit * 2
        
        // Primera fila/grupo de filtros
        RowLayout {
            Layout.fillWidth: true
            spacing: baseUnit
            
            Label {
                text: "Filtrar por:"
                font.bold: true
                color: textColor
                font.pixelSize: fontBaseSize * 0.9
                font.family: "Segoe UI, Arial, sans-serif"
            }
            
            ComboBox {
                id: filtroFecha
                Layout.preferredWidth: Math.max(120, filtersRoot.width * 0.15)
                Layout.preferredHeight: baseUnit * 4
                model: ["Todas", "Hoy", "Esta Semana", "Este Mes"]
                currentIndex: 0
                
                onCurrentIndexChanged: {
                    filtersRoot.emitFilterChange()
                }
                
                contentItem: Label {
                    text: filtroFecha.displayText
                    font.pixelSize: fontBaseSize * 0.8
                    font.family: "Segoe UI, Arial, sans-serif"
                    color: textColor
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: baseUnit
                }
                
                background: Rectangle {
                    color: whiteColor
                    border.color: borderColor
                    border.width: 1
                    radius: baseUnit * 0.8
                }
            }
        }
        
        RowLayout {
            Layout.fillWidth: true
            spacing: baseUnit
            
            Label {
                text: "Tipo:"
                font.bold: true
                color: textColor
                font.pixelSize: fontBaseSize * 0.9
                font.family: "Segoe UI, Arial, sans-serif"
            }
            
            ComboBox {
                id: filtroTipo
                Layout.fillWidth: true
                Layout.preferredHeight: baseUnit * 4
                model: ["Todos", "Normal", "Emergencia"]
                currentIndex: 0
                
                onCurrentIndexChanged: {
                    filtersRoot.emitFilterChange()
                }
                
                contentItem: Label {
                    text: filtroTipo.displayText
                    font.pixelSize: fontBaseSize * 0.8
                    font.family: "Segoe UI, Arial, sans-serif"
                    color: textColor
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: baseUnit
                }
                
                background: Rectangle {
                    color: whiteColor
                    border.color: borderColor
                    border.width: 1
                    radius: baseUnit * 0.8
                }
            }
        }
        
        // Campo de búsqueda
        TextField {
            id: campoBusqueda
            Layout.fillWidth: true
            Layout.preferredHeight: baseUnit * 4
            placeholderText: "Buscar por paciente..."
            
            onTextChanged: {
                filtersRoot.emitFilterChange()
            }
            
            background: Rectangle {
                color: whiteColor
                border.color: borderColor
                border.width: 1
                radius: baseUnit * 0.8
            }
            
            leftPadding: baseUnit * 1.5
            rightPadding: baseUnit * 1.5
            font.pixelSize: fontBaseSize * 0.9
            font.family: "Segoe UI, Arial, sans-serif"
        }
    }
    
    // Función para emitir cambios de filtros
    function emitFilterChange() {
        filtersChanged(filtroFecha.currentIndex, filtroTipo.currentIndex, campoBusqueda.text)
    }
    
    // Función para resetear filtros
    function resetFilters() {
        filtroFecha.currentIndex = 0
        filtroTipo.currentIndex = 0
        campoBusqueda.text = ""
    }
}