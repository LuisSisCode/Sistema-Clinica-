import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: tableRoot
    
    // Propiedades recibidas del padre
    property var model: null
    property int selectedRowIndex: -1
    property real baseUnit: 8
    property real fontBaseSize: 12
    
    // Colores
    property color primaryColor: "#3498DB"
    property color successColorLight: "#D1FAE5"
    property color warningColorLight: "#FEF3C7"
    property color dangerColor: "#E74C3C"
    property color whiteColor: "#FFFFFF"
    property color textColor: "#2c3e50"
    property color textColorLight: "#6B7280"
    property color borderColor: "#e0e0e0"
    property color lightGrayColor: "#F8F9FA"
    property color lineColor: "#D1D5DB"
    property color accentColor: "#10B981"
    property color warningColor: "#f39c12"
    
    // Distribución de columnas
    property real colId: 0.06      
    property real colPaciente: 0.18 
    property real colAnalisis: 0.22 
    property real colTipo: 0.08     
    property real colPrecio: 0.09   
    property real colTrabajador: 0.14 
    property real colRegistradoPor: 0.15 
    property real colFecha: 0.08
    
    // Señales
    signal rowSelected(int index)
    signal editRequested(int realIndex, int analisisId)
    signal deleteRequested(int analisisId)
    
    // Configuración visual
    color: whiteColor
    border.color: borderColor
    border.width: 1
    radius: baseUnit
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 0
        spacing: 0
        
        // HEADER CON LÍNEAS VERTICALES
        ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: baseUnit * 5
            
          
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: borderColor
            }
            
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: baseUnit * 1.5
                anchors.rightMargin: baseUnit * 1.5
                spacing: 0
                
                // ID COLUMN
                Item {
                    Layout.preferredWidth: parent.width * colId
                    Layout.fillHeight: true
                    
                    Label {
                        anchors.centerIn: parent
                        text: "CÓDIGO"
                        font.bold: true
                        font.pixelSize: fontBaseSize * 0.85
                        font.family: "Segoe UI, Arial, sans-serif"
                        color: textColor
                        horizontalAlignment: Text.AlignHCenter
                    }
                    
                    Rectangle {
                        anchors.right: parent.right
                        width: 1
                        height: parent.height
                        color: lineColor
                    }
                }
                
                // PACIENTE COLUMN
                Item {
                    Layout.preferredWidth: parent.width * colPaciente
                    Layout.fillHeight: true
                    
                    Label {
                        anchors.centerIn: parent
                        text: "PACIENTE"
                        font.bold: true
                        font.pixelSize: fontBaseSize * 0.85
                        font.family: "Segoe UI, Arial, sans-serif"
                        color: textColor
                        horizontalAlignment: Text.AlignHCenter
                    }
                    
                    Rectangle {
                        anchors.right: parent.right
                        width: 1
                        height: parent.height
                        color: lineColor
                    }
                }
                
                // ANÁLISIS COLUMN
                Item {
                    Layout.preferredWidth: parent.width * colAnalisis
                    Layout.fillHeight: true
                    
                    Label {
                        anchors.centerIn: parent
                        text: "ANÁLISIS"
                        font.bold: true
                        font.pixelSize: fontBaseSize * 0.85
                        font.family: "Segoe UI, Arial, sans-serif"
                        color: textColor
                        horizontalAlignment: Text.AlignHCenter
                    }
                    
                    Rectangle {
                        anchors.right: parent.right
                        width: 1
                        height: parent.height
                        color: lineColor
                    }
                }
                
                // TIPO COLUMN
                Item {
                    Layout.preferredWidth: parent.width * colTipo
                    Layout.fillHeight: true
                    
                    Label {
                        anchors.centerIn: parent
                        text: "TIPO"
                        font.bold: true
                        font.pixelSize: fontBaseSize * 0.85
                        font.family: "Segoe UI, Arial, sans-serif"
                        color: textColor
                        horizontalAlignment: Text.AlignHCenter
                    }
                    
                    Rectangle {
                        anchors.right: parent.right
                        width: 1
                        height: parent.height
                        color: lineColor
                    }
                }
                
                // PRECIO COLUMN
                Item {
                    Layout.preferredWidth: parent.width * colPrecio
                    Layout.fillHeight: true
                    
                    Label {
                        anchors.centerIn: parent
                        text: "PRECIO"
                        font.bold: true
                        font.pixelSize: fontBaseSize * 0.85
                        font.family: "Segoe UI, Arial, sans-serif"
                        color: textColor
                        horizontalAlignment: Text.AlignHCenter
                    }
                    
                    Rectangle {
                        anchors.right: parent.right
                        width: 1
                        height: parent.height
                        color: lineColor
                    }
                }
                
                // TRABAJADOR COLUMN
                Item {
                    Layout.preferredWidth: parent.width * colTrabajador
                    Layout.fillHeight: true
                    
                    Label {
                        anchors.centerIn: parent
                        text: "TRABAJADOR"
                        font.bold: true
                        font.pixelSize: fontBaseSize * 0.85
                        font.family: "Segoe UI, Arial, sans-serif"
                        color: textColor
                        horizontalAlignment: Text.AlignHCenter
                    }
                    
                    Rectangle {
                        anchors.right: parent.right
                        width: 1
                        height: parent.height
                        color: lineColor
                    }
                }
                
                // REGISTRADO POR COLUMN
                Item {
                    Layout.preferredWidth: parent.width * colRegistradoPor
                    Layout.fillHeight: true
                    
                    Label {
                        anchors.centerIn: parent
                        text: "REGISTRADO POR"
                        font.bold: true
                        font.pixelSize: fontBaseSize * 0.85
                        font.family: "Segoe UI, Arial, sans-serif"
                        color: textColor
                        horizontalAlignment: Text.AlignHCenter
                    }
                    
                    Rectangle {
                        anchors.right: parent.right
                        width: 1
                        height: parent.height
                        color: lineColor
                    }
                }
                
                // FECHA COLUMN
                Item {
                    Layout.preferredWidth: parent.width * colFecha
                    Layout.fillHeight: true
                    
                    Label {
                        anchors.centerIn: parent
                        text: "FECHA"
                        font.bold: true
                        font.pixelSize: fontBaseSize * 0.85
                        font.family: "Segoe UI, Arial, sans-serif"
                        color: textColor
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
        
        // CONTENIDO DE TABLA CON SCROLL Y LÍNEAS VERTICALES
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            
            ListView {
                id: analisisListView
                model: tableRoot.model
                
                delegate: Rectangle {
                    width: ListView.view.width
                    height: baseUnit * 5
                    color: {
                        if (selectedRowIndex === index) return "#F8F9FA"
                        return index % 2 === 0 ? whiteColor : "#FAFAFA"
                    }
                    
                    // Borde horizontal inferior
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: borderColor
                    }
                    
                    // Borde vertical de selección (izquierdo)
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: baseUnit * 0.4
                        color: selectedRowIndex === index ? accentColor : "transparent"
                        radius: baseUnit * 0.2
                        visible: selectedRowIndex === index
                        z: 3
                    }
                    
                    // CONTENEDOR PRINCIPAL DE COLUMNAS
                    RowLayout {
                        id: columnsContainer
                        anchors.fill: parent
                        anchors.leftMargin: baseUnit * 1.5
                        anchors.rightMargin: baseUnit * 1.5
                        spacing: 0
                        
                        // ID COLUMN
                        Item {
                            Layout.preferredWidth: parent.width * colId
                            Layout.fillHeight: true
                            
                            Label {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: baseUnit
                                text: model.analisisId
                                color: textColor
                                font.bold: false
                                font.pixelSize: fontBaseSize * 0.9
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                        }
                        
                        // PACIENTE COLUMN
                        Item {
                            Layout.preferredWidth: parent.width * colPaciente
                            Layout.fillHeight: true
                            
                            Label {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: baseUnit
                                anchors.rightMargin: baseUnit
                                text: model.paciente
                                color: textColor
                                font.bold: false
                                font.pixelSize: fontBaseSize * 0.9
                                font.family: "Segoe UI, Arial, sans-serif"
                                elide: Text.ElideRight
                            }
                        }
                        
                        // ANÁLISIS COLUMN
                        Item {
                            Layout.preferredWidth: parent.width * colAnalisis
                            Layout.fillHeight: true
                            
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: baseUnit * 0.6
                                spacing: baseUnit * 0.1
                                
                                Label { 
                                    Layout.fillWidth: true
                                    text: model.tipoAnalisis
                                    color: primaryColor
                                    font.bold: true
                                    font.pixelSize: fontBaseSize * 0.75
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                    verticalAlignment: Text.AlignVCenter
                                    font.family: "Segoe UI, Arial, sans-serif"
                                }
                                
                                Label { 
                                    Layout.fillWidth: true
                                    text: model.detalles
                                    color: textColorLight
                                    font.pixelSize: fontBaseSize * 0.65
                                    wrapMode: Text.WordWrap
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    visible: model.detalles && model.detalles !== "Sin detalles específicos"
                                }
                            }
                        }
                        
                        // TIPO COLUMN
                        Item {
                            Layout.preferredWidth: parent.width * colTipo
                            Layout.fillHeight: true
                            
                            Rectangle {
                                anchors.centerIn: parent
                                width: baseUnit * 7
                                height: baseUnit * 2.5
                                color: model.tipo === "Emergencia" ? warningColorLight : successColorLight
                                radius: height / 2
                                
                                Label {
                                    anchors.centerIn: parent
                                    text: model.tipo
                                    color: model.tipo === "Emergencia" ? "#92400E" : "#047857"
                                    font.pixelSize: fontBaseSize * 0.75
                                    font.bold: false
                                    font.family: "Segoe UI, Arial, sans-serif"
                                }
                            }
                        }
                        
                        // PRECIO COLUMN
                        Item {
                            Layout.preferredWidth: parent.width * colPrecio
                            Layout.fillHeight: true
                            
                            Label {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: baseUnit
                                text: "Bs "+ model.precio
                                color: model.tipo === "Emergencia" ? "#92400E" : "#047857"
                                font.bold: false
                                font.pixelSize: fontBaseSize * 0.9
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                        }
                        
                        // TRABAJADOR COLUMN
                        Item {
                            Layout.preferredWidth: parent.width * colTrabajador
                            Layout.fillHeight: true
                            
                            Label {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: baseUnit
                                anchors.rightMargin: baseUnit
                                text: model.trabajadorAsignado || "Sin asignar"
                                color: model.trabajadorAsignado ? textColor : textColorLight
                                font.pixelSize: fontBaseSize * 0.9
                                font.family: "Segoe UI, Arial, sans-serif"
                                elide: Text.ElideRight
                            }
                        }
                        
                        // REGISTRADO POR COLUMN
                        Item {
                            Layout.preferredWidth: parent.width * colRegistradoPor
                            Layout.fillHeight: true
                            
                            Label {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: baseUnit
                                anchors.rightMargin: baseUnit
                                text: model.registradoPor || "Luis López"
                                color: textColorLight
                                font.pixelSize: fontBaseSize * 0.9
                                font.family: "Segoe UI, Arial, sans-serif"
                                elide: Text.ElideRight
                            }
                        }
                        
                        // FECHA COLUMN
                        Item {
                            Layout.preferredWidth: parent.width * colFecha
                            Layout.fillHeight: true
                            
                            Label {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: baseUnit
                                text: {
                                    var fecha = new Date(model.fecha)
                                    return fecha.toLocaleDateString("es-ES", {
                                        day: "2-digit",
                                        month: "2-digit", 
                                        year: "numeric"
                                    })
                                }
                                color: textColor
                                font.bold: false
                                font.pixelSize: fontBaseSize * 0.85
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                        }
                    }
                    
                    // LÍNEAS VERTICALES PERFECTAMENTE ALINEADAS
                    Repeater {
                        model: 7 // 7 líneas entre 8 columnas
                        delegate: Rectangle {
                            property real columnPosition: {
                                switch(index) {
                                    case 0: return colId;
                                    case 1: return colId + colPaciente;
                                    case 2: return colId + colPaciente + colAnalisis;
                                    case 3: return colId + colPaciente + colAnalisis + colTipo;
                                    case 4: return colId + colPaciente + colAnalisis + colTipo + colPrecio;
                                    case 5: return colId + colPaciente + colAnalisis + colTipo + colPrecio + colTrabajador;
                                    case 6: return colId + colPaciente + colAnalisis + colTipo + colPrecio + colTrabajador + colRegistradoPor;
                                }
                            }
                            
                            x: columnsContainer.x + columnsContainer.width * columnPosition
                            width: 1
                            height: parent.height
                            color: lineColor
                            z: 2
                        }
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            rowSelected(index)
                        }
                    }

                    // BOTONES DE ACCIÓN - Posicionados en columna fecha
                    Rectangle {
                        x: parent.width * (colId + colPaciente + colAnalisis + colTipo + colPrecio + colTrabajador + colRegistradoPor + colFecha/2) - width/2
                        y: parent.height/2 - height/2
                        width: baseUnit * 7.5
                        height: baseUnit * 3.5
                        color: "#F0FFFFFF"
                        radius: baseUnit * 0.5
                        visible: selectedRowIndex === index
                        z: 10
                        
                        Row {
                            anchors.centerIn: parent
                            spacing: baseUnit * 0.5
                            
                            Button {
                                width: baseUnit * 3.5
                                height: baseUnit * 3.5
                                text: "✏️"
                                
                                background: Rectangle {
                                    color: warningColor
                                    radius: baseUnit * 0.8
                                }
                                
                                contentItem: Label {
                                    text: parent.text
                                    color: whiteColor
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                
                                onClicked: editRequested(index, model.analisisId)
                            }
                            
                            Button {
                                width: baseUnit * 3.5
                                height: baseUnit * 3.5
                                text: "🗑️"
                                
                                background: Rectangle {
                                    color: dangerColor
                                    radius: baseUnit * 0.8
                                }
                                
                                contentItem: Label {
                                    text: parent.text
                                    color: whiteColor
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                
                                onClicked: deleteRequested(parseInt(model.analisisId))
                            }
                        }
                    }
                }
            }
        }
    }
}