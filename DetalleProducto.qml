import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: detalleProductoComponent
    
    // ===============================
    // PROPIEDADES PÚBLICAS
    // ===============================
    
    property var productoData: null
    property bool mostrarStock: true
    property bool mostrarAcciones: true
    property color primaryColor: "#273746"
    property color successColor: "#27ae60"
    property color dangerColor: "#E74C3C"
    property color warningColor: "#f39c12"
    property color lightGrayColor: "#ECF0F1"
    property color textColor: "#2c3e50"
    property real baseUnit: 8
    property real fontBaseSize: 12
    
    // ===============================
    // SEÑALES
    // ===============================
    
    signal editarSolicitado(var producto)
    signal eliminarSolicitado(var producto)
    signal ajustarStockSolicitado(var producto)
    signal cerrarSolicitado()
    
    // ===============================
    // PROPIEDADES CALCULADAS
    // ===============================
    
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
            case "medio": return "#17a2b8"
            case "alto": return successColor
            default: return textColor
        }
    }
    
    // ===============================
    // CONFIGURACIÓN DEL COMPONENTE
    // ===============================
    
    color: "white"
    radius: baseUnit
    border.color: lightGrayColor
    border.width: 1
    
    // ===============================
    // LAYOUT PRINCIPAL
    // ===============================
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: baseUnit * 2
        spacing: baseUnit * 1.5
        
        // ===============================
        // HEADER CON INFORMACIÓN PRINCIPAL
        // ===============================
        
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: baseUnit * 10
            gradient: Gradient {
                GradientStop { position: 0.0; color: primaryColor }
                GradientStop { position: 1.0; color: Qt.darker(primaryColor, 1.1) }
            }
            radius: baseUnit * 0.5
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: baseUnit * 1.5
                spacing: baseUnit * 1.5
                
                // Icono del producto
                Rectangle {
                    width: baseUnit * 7
                    height: baseUnit * 7
                    color: "white"
                    radius: baseUnit * 3.5
                    
                    Text {
                        anchors.centerIn: parent
                        text: "💊"
                        font.pixelSize: fontBaseSize * 2.5
                    }
                }
                
                // Información principal
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: baseUnit * 0.5
                    
                    Text {
                        text: productoData ? (productoData.Nombre || "Sin nombre") : "Producto"
                        color: "white"
                        font.bold: true
                        font.pixelSize: fontBaseSize * 1.5
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                    
                    Text {
                        text: productoData ? (productoData.Codigo || "Sin código") : "---"
                        color: "#E8F4FD"
                        font.pixelSize: fontBaseSize * 1.1
                        font.bold: true
                    }
                    
                    Text {
                        text: productoData ? (productoData.marca_nombre || "Sin marca") : "---"
                        color: "#E8F4FD"
                        font.pixelSize: fontBaseSize * 0.9
                    }
                }
                
                // Estado del stock
                Rectangle {
                    width: baseUnit * 8
                    height: baseUnit * 6
                    color: "white"
                    radius: baseUnit * 0.5
                    
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: baseUnit * 0.25
                        
                        Text {
                            text: {
                                if (!productoData) return "0"
                                return ((productoData.Stock_Caja || 0) + (productoData.Stock_Unitario || 0)).toString()
                            }
                            color: colorEstadoStock
                            font.bold: true
                            font.pixelSize: fontBaseSize * 1.5
                            Layout.alignment: Qt.AlignHCenter
                        }
                        
                        Text {
                            text: "STOCK TOTAL"
                            color: textColor
                            font.pixelSize: fontBaseSize * 0.7
                            font.bold: true
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
                
                // Botón cerrar
                Button {
                    width: baseUnit * 4
                    height: baseUnit * 4
                    
                    background: Rectangle {
                        color: parent.pressed ? "#40FFFFFF" : "transparent"
                        radius: baseUnit * 2
                    }
                    
                    contentItem: Text {
                        text: "✕"
                        color: "white"
                        font.pixelSize: fontBaseSize * 1.5
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        cerrarSolicitado()
                    }
                }
            }
        }
        
        // ===============================
        // CONTENIDO DETALLADO
        // ===============================
        
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            
            ColumnLayout {
                width: parent.width
                spacing: baseUnit * 2
                
                // ===============================
                // INFORMACIÓN COMERCIAL
                // ===============================
                
                GroupBox {
                    Layout.fillWidth: true
                    title: "💰 Información Comercial"
                    
                    background: Rectangle {
                        color: "#F8F9FA"
                        border.color: lightGrayColor
                        border.width: 1
                        radius: baseUnit * 0.5
                    }
                    
                    label: Rectangle {
                        color: successColor
                        width: comercialLabelText.width + baseUnit * 2
                        height: baseUnit * 3
                        radius: baseUnit * 0.25
                        x: baseUnit
                        y: -baseUnit * 1.5
                        
                        Text {
                            id: comercialLabelText
                            anchors.centerIn: parent
                            text: parent.parent.title
                            color: "white"
                            font.bold: true
                            font.pixelSize: fontBaseSize * 0.9
                        }
                    }
                    
                    GridLayout {
                        anchors.fill: parent
                        anchors.margins: baseUnit * 1.5
                        columns: 3
                        columnSpacing: baseUnit * 2
                        rowSpacing: baseUnit * 1.5
                        
                        // Precio de Compra
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: baseUnit * 8
                            color: "white"
                            border.color: lightGrayColor
                            border.width: 1
                            radius: baseUnit * 0.5
                            
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: baseUnit * 0.5
                                
                                Text {
                                    text: "Precio Compra"
                                    color: textColor
                                    font.pixelSize: fontBaseSize * 0.8
                                    font.bold: true
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                
                                Text {
                                    text: productoData ? 
                                          `Bs ${(productoData.Precio_compra || 0).toFixed(2)}` : 
                                          "Bs 0.00"
                                    color: "#6c757d"
                                    font.pixelSize: fontBaseSize * 1.2
                                    font.bold: true
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }
                        
                        // Precio de Venta
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: baseUnit * 8
                            color: "white"
                            border.color: lightGrayColor
                            border.width: 1
                            radius: baseUnit * 0.5
                            
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: baseUnit * 0.5
                                
                                Text {
                                    text: "Precio Venta"
                                    color: textColor
                                    font.pixelSize: fontBaseSize * 0.8
                                    font.bold: true
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                
                                Text {
                                    text: productoData ? 
                                          `Bs ${(productoData.Precio_venta || 0).toFixed(2)}` : 
                                          "Bs 0.00"
                                    color: successColor
                                    font.pixelSize: fontBaseSize * 1.2
                                    font.bold: true
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }
                        
                        // Margen de Ganancia
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: baseUnit * 8
                            color: {
                                if (margenGanancia >= 30) return "#d4edda"
                                if (margenGanancia >= 15) return "#fff3cd"
                                return "#f8d7da"
                            }
                            border.color: {
                                if (margenGanancia >= 30) return successColor
                                if (margenGanancia >= 15) return warningColor
                                return dangerColor
                            }
                            border.width: 1
                            radius: baseUnit * 0.5
                            
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: baseUnit * 0.5
                                
                                Text {
                                    text: "Margen"
                                    color: textColor
                                    font.pixelSize: fontBaseSize * 0.8
                                    font.bold: true
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                
                                Text {
                                    text: `${margenGanancia.toFixed(1)}%`
                                    color: textColor
                                    font.pixelSize: fontBaseSize * 1.2
                                    font.bold: true
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }
                    }
                }
                
                // ===============================
                // INFORMACIÓN DE STOCK
                // ===============================
                
                GroupBox {
                    Layout.fillWidth: true
                    title: "📦 Stock e Inventario"
                    visible: mostrarStock
                    
                    background: Rectangle {
                        color: "#F8F9FA"
                        border.color: lightGrayColor
                        border.width: 1
                        radius: baseUnit * 0.5
                    }
                    
                    label: Rectangle {
                        color: "#17a2b8"
                        width: stockLabelText.width + baseUnit * 2
                        height: baseUnit * 3
                        radius: baseUnit * 0.25
                        x: baseUnit
                        y: -baseUnit * 1.5
                        
                        Text {
                            id: stockLabelText
                            anchors.centerIn: parent
                            text: parent.parent.title
                            color: "white"
                            font.bold: true
                            font.pixelSize: fontBaseSize * 0.9
                        }
                    }
                    
                    GridLayout {
                        anchors.fill: parent
                        anchors.margins: baseUnit * 1.5
                        columns: 3
                        columnSpacing: baseUnit * 2
                        rowSpacing: baseUnit * 1.5
                        
                        // Stock en Cajas
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: baseUnit * 8
                            color: "white"
                            border.color: lightGrayColor
                            border.width: 1
                            radius: baseUnit * 0.5
                            
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: baseUnit * 0.5
                                
                                Text {
                                    text: "📦"
                                    font.pixelSize: fontBaseSize * 1.5
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                
                                Text {
                                    text: productoData ? (productoData.Stock_Caja || 0).toString() : "0"
                                    color: textColor
                                    font.pixelSize: fontBaseSize * 1.5
                                    font.bold: true
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                
                                Text {
                                    text: "Cajas"
                                    color: "#6c757d"
                                    font.pixelSize: fontBaseSize * 0.8
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }
                        
                        // Stock Unitario
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: baseUnit * 8
                            color: "white"
                            border.color: lightGrayColor
                            border.width: 1
                            radius: baseUnit * 0.5
                            
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: baseUnit * 0.5
                                
                                Text {
                                    text: "🔢"
                                    font.pixelSize: fontBaseSize * 1.5
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                
                                Text {
                                    text: productoData ? (productoData.Stock_Unitario || 0).toString() : "0"
                                    color: textColor
                                    font.pixelSize: fontBaseSize * 1.5
                                    font.bold: true
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                
                                Text {
                                    text: "Unidades"
                                    color: "#6c757d"
                                    font.pixelSize: fontBaseSize * 0.8
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }
                        
                        // Estado del Stock
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: baseUnit * 8
                            color: {
                                switch(estadoStock) {
                                    case "agotado": return "#f8d7da"
                                    case "bajo": return "#fff3cd"
                                    case "medio": return "#d1ecf1"
                                    case "alto": return "#d4edda"
                                    default: return "#f8f9fa"
                                }
                            }
                            border.color: colorEstadoStock
                            border.width: 2
                            radius: baseUnit * 0.5
                            
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: baseUnit * 0.5
                                
                                Text {
                                    text: {
                                        switch(estadoStock) {
                                            case "agotado": return "🔴"
                                            case "bajo": return "🟡"
                                            case "medio": return "🔵"
                                            case "alto": return "🟢"
                                            default: return "⚪"
                                        }
                                    }
                                    font.pixelSize: fontBaseSize * 1.5
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                
                                Text {
                                    text: {
                                        switch(estadoStock) {
                                            case "agotado": return "AGOTADO"
                                            case "bajo": return "STOCK BAJO"
                                            case "medio": return "STOCK MEDIO"
                                            case "alto": return "STOCK ALTO"
                                            default: return "DESCONOCIDO"
                                        }
                                    }
                                    color: colorEstadoStock
                                    font.pixelSize: fontBaseSize * 0.8
                                    font.bold: true
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }
                    }
                }
                
                // ===============================
                // DESCRIPCIÓN (si existe)
                // ===============================
                
                GroupBox {
                    Layout.fillWidth: true
                    title: "📄 Descripción"
                    visible: productoData && productoData.Descripcion && productoData.Descripcion.trim() !== ""
                    
                    background: Rectangle {
                        color: "#F8F9FA"
                        border.color: lightGrayColor
                        border.width: 1
                        radius: baseUnit * 0.5
                    }
                    
                    label: Rectangle {
                        color: "#6c757d"
                        width: descripcionLabelText.width + baseUnit * 2
                        height: baseUnit * 3
                        radius: baseUnit * 0.25
                        x: baseUnit
                        y: -baseUnit * 1.5
                        
                        Text {
                            id: descripcionLabelText
                            anchors.centerIn: parent
                            text: parent.parent.title
                            color: "white"
                            font.bold: true
                            font.pixelSize: fontBaseSize * 0.9
                        }
                    }
                    
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: baseUnit * 1.5
                        color: "white"
                        border.color: lightGrayColor
                        border.width: 1
                        radius: baseUnit * 0.5
                        
                        ScrollView {
                            anchors.fill: parent
                            anchors.margins: baseUnit
                            
                            Text {
                                width: parent.width
                                text: productoData ? (productoData.Descripcion || "") : ""
                                color: textColor
                                font.pixelSize: fontBaseSize * 0.9
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }
        }
        
        // ===============================
        // BOTONES DE ACCIÓN
        // ===============================
        
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: baseUnit * 8
            color: "#F8F9FA"
            border.color: lightGrayColor
            border.width: 1
            radius: baseUnit * 0.5
            visible: mostrarAcciones
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: baseUnit * 1.5
                spacing: baseUnit * 1.5
                
                // Botón Editar
                Button {
                    Layout.fillWidth: true
                    Layout.preferredHeight: baseUnit * 5
                    text: "✏️ Editar"
                    
                    background: Rectangle {
                        color: parent.pressed ? Qt.darker("#007bff", 1.2) : "#007bff"
                        radius: baseUnit * 0.5
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.bold: true
                        font.pixelSize: fontBaseSize
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        editarSolicitado(productoData)
                    }
                }
                
                // Botón Ajustar Stock
                Button {
                    Layout.fillWidth: true
                    Layout.preferredHeight: baseUnit * 5
                    text: "📦 Ajustar Stock"
                    
                    background: Rectangle {
                        color: parent.pressed ? Qt.darker("#17a2b8", 1.2) : "#17a2b8"
                        radius: baseUnit * 0.5
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.bold: true
                        font.pixelSize: fontBaseSize
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        ajustarStockSolicitado(productoData)
                    }
                }
                
                // Botón Eliminar
                Button {
                    Layout.fillWidth: true
                    Layout.preferredHeight: baseUnit * 5
                    text: "🗑️ Eliminar"
                    
                    background: Rectangle {
                        color: parent.pressed ? Qt.darker(dangerColor, 1.2) : dangerColor
                        radius: baseUnit * 0.5
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.bold: true
                        font.pixelSize: fontBaseSize
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        eliminarSolicitado(productoData)
                    }
                }
            }
        }
    }
}