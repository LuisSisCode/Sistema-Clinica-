import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: detalleProductoComponent
    
    // Propiedades públicas
    property var productoData: null
    property bool mostrarStock: true
    property bool mostrarAcciones: true
    property color primaryColor: "#2c3e50"
    property color successColor: "#27ae60"
    property color dangerColor: "#e74c3c"
    property color warningColor: "#f39c12"
    property color infoColor: "#3498db"
    property color lightGrayColor: "#ecf0f1"
    property color darkGrayColor: "#7f8c8d"
    property color textColor: "#2c3e50"
    property real baseUnit: 8
    property real fontBaseSize: 14
    
    // Señales
    signal editarSolicitado(var producto)
    signal eliminarSolicitado(var producto)
    signal ajustarStockSolicitado(var producto)
    signal cerrarSolicitado()
    
    // Propiedades calculadas
    property real margenGanancia: {
        if (!productoData) return 0
        var compra = productoData.Precio_compra || 0
        var venta = productoData.Precio_venta || 0
        if (compra > 0) {
            return ((venta - compra) / compra) * 100
        }
        return 0
    }
    
    property string estadoStock: {
        if (!productoData) return "unknown"
        var total = (productoData.Stock_Caja || 0) + (productoData.Stock_Unitario || 0)
        if (total === 0) return "agotado"
        if (total <= 5) return "bajo"
        if (total <= 20) return "medio"
        return "alto"
    }
    
    property color colorEstadoStock: {
        switch(estadoStock) {
            case "agotado": return dangerColor
            case "bajo": return warningColor
            case "medio": return infoColor
            case "alto": return successColor
            default: return textColor
        }
    }
    
    property string textoEstadoStock: {
        switch(estadoStock) {
            case "agotado": return "AGOTADO"
            case "bajo": return "STOCK BAJO"
            case "medio": return "STOCK MEDIO"
            case "alto": return "STOCK ALTO"
            default: return "DESCONOCIDO"
        }
    }
    
    // Configuración del componente
    width: 700
    height: 550
    color: "#ffffff"
    radius: 8
    border.color: "#e1e8ed"
    border.width: 1
    
    // Layout principal
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 0
        
        // === HEADER SIMILAR AL DE LA IMAGEN ===
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            color: "#f8f9fa"
            border.color: "#dee2e6"
            border.width: 1
            
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                
                Label {
                    text: "Detalles del Producto: " + (productoData ? (productoData.Codigo || "SIN-CÓDIGO") : "---")
                    color: "#2c3e50"
                    font.bold: true
                    font.pixelSize: 16
                    Layout.fillWidth: true
                }
                
                Button {
                    text: "Cerrar"
                    
                    background: Rectangle {
                        color: parent.pressed ? "#e9ecef" : "#f8f9fa"
                        border.color: "#dee2e6"
                        border.width: 1
                        radius: 4
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        color: "#6c757d"
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: cerrarSolicitado()
                }
            }
        }
        
        // === TABLA DE INFORMACIÓN BÁSICA ===
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 160
            color: "#ffffff"
            border.color: "#dee2e6"
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                
                // Header de la tabla
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    color: "#f8f9fa"
                    border.color: "#dee2e6"
                    border.width: 1
                    
                    RowLayout {
                        anchors.fill: parent
                        spacing: 0
                        
                        Rectangle {
                            Layout.preferredWidth: 120
                            Layout.fillHeight: true
                            color: "transparent"
                            border.color: "#dee2e6"
                            border.width: 1
                            
                            Label {
                                anchors.centerIn: parent
                                text: "CÓDIGO"
                                color: "#495057"
                                font.bold: true
                                font.pixelSize: 12
                            }
                        }
                        
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: "transparent"
                            border.color: "#dee2e6"
                            border.width: 1
                            
                            Label {
                                anchors.centerIn: parent
                                text: "NOMBRE"
                                color: "#495057"
                                font.bold: true
                                font.pixelSize: 12
                            }
                        }
                        
                        Rectangle {
                            Layout.preferredWidth: 100
                            Layout.fillHeight: true
                            color: "transparent"
                            border.color: "#dee2e6"
                            border.width: 1
                            
                            Label {
                                anchors.centerIn: parent
                                text: "MARCA"
                                color: "#495057"
                                font.bold: true
                                font.pixelSize: 12
                            }
                        }
                        
                        Rectangle {
                            Layout.preferredWidth: 100
                            Layout.fillHeight: true
                            color: "transparent"
                            border.color: "#dee2e6"
                            border.width: 1
                            
                            Label {
                                anchors.centerIn: parent
                                text: "ESTADO"
                                color: "#495057"
                                font.bold: true
                                font.pixelSize: 12
                            }
                        }
                    }
                }
                
                // Fila de datos
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 45
                    color: "#ffffff"
                    border.color: "#dee2e6"
                    border.width: 1
                    
                    RowLayout {
                        anchors.fill: parent
                        spacing: 0
                        
                        Rectangle {
                            Layout.preferredWidth: 120
                            Layout.fillHeight: true
                            color: "transparent"
                            border.color: "#dee2e6"
                            border.width: 1
                            
                            Label {
                                anchors.centerIn: parent
                                text: productoData ? (productoData.Codigo || "---") : "---"
                                color: "#007bff"
                                font.bold: true
                                font.pixelSize: 13
                            }
                        }
                        
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: "transparent"
                            border.color: "#dee2e6"
                            border.width: 1
                            
                            Label {
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: productoData ? (productoData.Nombre || "Sin nombre") : "---"
                                color: "#212529"
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }
                        }
                        
                        Rectangle {
                            Layout.preferredWidth: 100
                            Layout.fillHeight: true
                            color: "transparent"
                            border.color: "#dee2e6"
                            border.width: 1
                            
                            Label {
                                anchors.centerIn: parent
                                text: productoData ? (productoData.marca_nombre || "---") : "---"
                                color: "#6c757d"
                                font.pixelSize: 13
                            }
                        }
                        
                        Rectangle {
                            Layout.preferredWidth: 100
                            Layout.fillHeight: true
                            color: "transparent"
                            border.color: "#dee2e6"
                            border.width: 1
                            
                            Rectangle {
                                anchors.centerIn: parent
                                width: 80
                                height: 22
                                color: colorEstadoStock
                                radius: 11
                                
                                Label {
                                    anchors.centerIn: parent
                                    text: textoEstadoStock
                                    color: "#ffffff"
                                    font.bold: true
                                    font.pixelSize: 9
                                }
                            }
                        }
                    }
                }
                
                // Descripción si existe
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 75
                    visible: productoData && productoData.Descripcion && productoData.Descripcion.trim() !== ""
                    color: "#f8f9fa"
                    border.color: "#dee2e6"
                    border.width: 1
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 4
                        
                        Label {
                            text: "DESCRIPCIÓN:"
                            color: "#495057"
                            font.bold: true
                            font.pixelSize: 11
                        }
                        
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            
                            Label {
                                width: parent.width
                                text: productoData ? (productoData.Descripcion || "") : ""
                                color: "#6c757d"
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }
        }
        
        // === TABLA DE INFORMACIÓN COMERCIAL ===
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            color: "#ffffff"
            border.color: "#dee2e6"
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                
                // Header
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 35
                    color: "#f8f9fa"
                    border.color: "#dee2e6"
                    border.width: 1
                    
                    Label {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "INFORMACIÓN COMERCIAL"
                        color: "#495057"
                        font.bold: true
                        font.pixelSize: 13
                    }
                }
                
                // Contenido comercial
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#ffffff"
                    border.color: "#dee2e6"
                    border.width: 1
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 0
                        spacing: 0
                        
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: "transparent"
                            border.color: "#dee2e6"
                            border.width: 1
                            
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 2
                                
                                Label {
                                    text: "PRECIO COMPRA"
                                    color: "#6c757d"
                                    font.pixelSize: 10
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                
                                Label {
                                    text: productoData ? `Bs ${(productoData.Precio_compra || 0).toFixed(2)}` : "Bs 0.00"
                                    color: "#28a745"
                                    font.bold: true
                                    font.pixelSize: 14
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }
                        
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: "transparent"
                            border.color: "#dee2e6"
                            border.width: 1
                            
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 2
                                
                                Label {
                                    text: "PRECIO VENTA"
                                    color: "#6c757d"
                                    font.pixelSize: 10
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                
                                Label {
                                    text: productoData ? `Bs ${(productoData.Precio_venta || 0).toFixed(2)}` : "Bs 0.00"
                                    color: "#ffc107"
                                    font.bold: true
                                    font.pixelSize: 14
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }
                        
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: "transparent"
                            border.color: "#dee2e6"
                            border.width: 1
                            
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 2
                                
                                Label {
                                    text: "MARGEN GANANCIA"
                                    color: "#6c757d"
                                    font.pixelSize: 10
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: margenLabel.implicitWidth + 12
                                    Layout.preferredHeight: 20
                                    Layout.alignment: Qt.AlignHCenter
                                    color: margenGanancia >= 30 ? "#28a745" : 
                                           margenGanancia >= 15 ? "#ffc107" : "#dc3545"
                                    radius: 10
                                    
                                    Label {
                                        id: margenLabel
                                        anchors.centerIn: parent
                                        text: `${margenGanancia.toFixed(1)}%`
                                        color: "#ffffff"
                                        font.bold: true
                                        font.pixelSize: 11
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // === TABLA DE STOCK ===
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            visible: mostrarStock
            color: "#ffffff"
            border.color: "#dee2e6"
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                
                // Header
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 35
                    color: "#f8f9fa"
                    border.color: "#dee2e6"
                    border.width: 1
                    
                    Label {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "INVENTARIO Y STOCK"
                        color: "#495057"
                        font.bold: true
                        font.pixelSize: 13
                    }
                }
                
                // Contenido de stock
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#ffffff"
                    border.color: "#dee2e6"
                    border.width: 1
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 0
                        spacing: 0
                        
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: "transparent"
                            border.color: "#dee2e6"
                            border.width: 1
                            
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 2
                                
                                Label {
                                    text: "CAJAS"
                                    color: "#6c757d"
                                    font.pixelSize: 10
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 40
                                    Layout.preferredHeight: 25
                                    Layout.alignment: Qt.AlignHCenter
                                    color: "#17a2b8"
                                    radius: 12
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: productoData ? (productoData.Stock_Caja || 0).toString() : "0"
                                        color: "#ffffff"
                                        font.bold: true
                                        font.pixelSize: 13
                                    }
                                }
                            }
                        }
                        
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: "transparent"
                            border.color: "#dee2e6"
                            border.width: 1
                            
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 2
                                
                                Label {
                                    text: "UNIDADES"
                                    color: "#6c757d"
                                    font.pixelSize: 10
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 40
                                    Layout.preferredHeight: 25
                                    Layout.alignment: Qt.AlignHCenter
                                    color: "#6f42c1"
                                    radius: 12
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: productoData ? (productoData.Stock_Unitario || 0).toString() : "0"
                                        color: "#ffffff"
                                        font.bold: true
                                        font.pixelSize: 13
                                    }
                                }
                            }
                        }
                        
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: "transparent"
                            border.color: "#dee2e6"
                            border.width: 1
                            
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 2
                                
                                Label {
                                    text: "TOTAL DISPONIBLE"
                                    color: "#6c757d"
                                    font.pixelSize: 10
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                
                                Label {
                                    text: {
                                        if (!productoData) return "0"
                                        var total = (productoData.Stock_Caja || 0) + (productoData.Stock_Unitario || 0)
                                        return total.toString() + " unidades"
                                    }
                                    color: "#212529"
                                    font.bold: true
                                    font.pixelSize: 13
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // Espaciador
        Item {
            Layout.fillHeight: true
            Layout.minimumHeight: 10
        }
        
        // === BOTONES DE ACCIÓN ===
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            visible: mostrarAcciones
            color: "#f8f9fa"
            border.color: "#dee2e6"
            border.width: 1
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8
                
                Button {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    text: "✏️ Editar"
                    
                    background: Rectangle {
                        color: parent.pressed ? "#0056b3" : "#007bff"
                        radius: 4
                        border.color: "#0056b3"
                        border.width: 1
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        color: "#ffffff"
                        font.bold: true
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: editarSolicitado(productoData)
                }
                
                Button {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    text: "📦 Ajustar Stock"
                    
                    background: Rectangle {
                        color: parent.pressed ? "#e0a800" : "#ffc107"
                        radius: 4
                        border.color: "#e0a800"
                        border.width: 1
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        color: "#212529"
                        font.bold: true
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: ajustarStockSolicitado(productoData)
                }
                
                Button {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    text: "🗑️ Eliminar"
                    
                    background: Rectangle {
                        color: parent.pressed ? "#c82333" : "#dc3545"
                        radius: 4
                        border.color: "#c82333"
                        border.width: 1
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        color: "#ffffff"
                        font.bold: true
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: eliminarSolicitado(productoData)
                }
            }
        }
    }
}