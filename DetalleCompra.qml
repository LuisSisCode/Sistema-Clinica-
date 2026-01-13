import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: detalleCompraDialog
    anchors.fill: parent
    visible: false
    color: "transparent"
    z: 1000
    
    // ============================================================================
    // PROPERTIES
    // ============================================================================
    property var compraData: null
    property int compraId: 0
    
    // Colores (basados en DetalleProducto - paleta profesional)
    readonly property color overlayColor: "#99000000"
    readonly property color backgroundColor: "#ffffff"
    readonly property color headerColor: "#1976d2"
    readonly property color cardBackgroundColor: "#f5f5f5"
    readonly property color borderColor: "#e0e0e0"
    readonly property color textColor: "#333333"
    readonly property color secondaryTextColor: "#666666"
    readonly property color successColor: "#4caf50"
    readonly property color warningColor: "#ff9800"
    readonly property color hoverColor: "#e3f2fd"
    readonly property color deleteHoverColor: "#ffebee"
    
    // Espaciados
    readonly property int spacing4: 4
    readonly property int spacing8: 8
    readonly property int spacing16: 16
    readonly property int spacing24: 24
    
    // Tipografía
    readonly property int fontSmall: 11
    readonly property int fontNormal: 13
    readonly property int fontMedium: 14
    readonly property int fontLarge: 16
    readonly property int fontXLarge: 20
    
    // ============================================================================
    // FUNCIONES
    // ============================================================================
    function abrir(compra_id) {
        if (!compraModel) {
            console.log("❌ CompraModel no disponible")
            return
        }
        
        compraId = compra_id
        console.log("📋 Abriendo detalle de compra:", compra_id)
        
        // Cargar detalle completo desde el modelo
        compraModel.cargar_detalle_compra(compra_id)
        compraData = compraModel.compra_actual
        
        if (compraData && compraData.id) {
            visible = true
            console.log("✅ Detalle cargado:", compraData.total_items, "productos")
        } else {
            console.log("⚠️ No se pudo cargar el detalle")
        }
    }
    
    function cerrar() {
        visible = false
        compraData = null
        compraId = 0
    }
    
    function abrirEditarLote(productoData) {
        console.log("✏️ Editar lote:", productoData.Producto_Nombre)
        // Aquí se integrará con EditarLoteDialog.qml
        // editarLoteDialog.abrir(productoData)
    }
    
    // ============================================================================
    // UI - OVERLAY SEMI-TRANSPARENTE
    // ============================================================================
    MouseArea {
        anchors.fill: parent
        onClicked: cerrar()
        
        Rectangle {
            anchors.fill: parent
            color: overlayColor
        }
    }
    
    // ============================================================================
    // UI - MODAL PRINCIPAL
    // ============================================================================
    Rectangle {
        id: modalContainer
        width: 1000
        height: 700
        anchors.centerIn: parent
        color: backgroundColor
        radius: 8
        border.color: borderColor
        border.width: 1
        
        // Prevenir que el click cierre el modal
        MouseArea {
            anchors.fill: parent
            onClicked: {} // Consumir evento
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 0
            spacing: 0
            
            // ========================================================================
            // HEADER
            // ========================================================================
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                color: headerColor
                radius: 8
                
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 8
                    color: headerColor
                }
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: spacing16
                    spacing: spacing16
                    
                    Label {
                        text: "📦 DETALLE DE COMPRA"
                        color: "white"
                        font.pixelSize: fontLarge
                        font.bold: true
                    }
                    
                    Label {
                        text: compraData ? "#" + compraData.id : ""
                        color: "white"
                        font.pixelSize: fontMedium
                        opacity: 0.9
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    Button {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        
                        background: Rectangle {
                            color: parent.hovered ? "#1565c0" : "transparent"
                            radius: 4
                        }
                        
                        contentItem: Label {
                            text: "✖"
                            color: "white"
                            font.pixelSize: fontLarge
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: cerrar()
                    }
                }
            }
            
            // ========================================================================
            // CONTENIDO SCROLLEABLE
            // ========================================================================
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                
                ColumnLayout {
                    width: modalContainer.width - 48
                    spacing: spacing16
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.margins: spacing24
                    
                    Item { height: spacing8 }
                    
                    // ================================================================
                    // SECCIÓN 1: INFORMACIÓN DE LA COMPRA
                    // ================================================================
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: infoCompraLayout.height + spacing24
                        color: cardBackgroundColor
                        radius: 8
                        border.color: borderColor
                        border.width: 1
                        
                        ColumnLayout {
                            id: infoCompraLayout
                            anchors.fill: parent
                            anchors.margins: spacing16
                            spacing: spacing8
                            
                            Label {
                                text: "📦 INFORMACIÓN DE LA COMPRA"
                                color: textColor
                                font.pixelSize: fontMedium
                                font.bold: true
                            }
                            
                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: borderColor
                            }
                            
                            // Grid de información
                            GridLayout {
                                Layout.fillWidth: true
                                columns: 4
                                rowSpacing: spacing8
                                columnSpacing: spacing24
                                
                                // Fila 1
                                Label {
                                    text: "ID Compra:"
                                    color: secondaryTextColor
                                    font.pixelSize: fontSmall
                                }
                                Label {
                                    text: compraData ? "#" + compraData.id : ""
                                    color: textColor
                                    font.pixelSize: fontNormal
                                    font.bold: true
                                }
                                
                                Label {
                                    text: "Fecha:"
                                    color: secondaryTextColor
                                    font.pixelSize: fontSmall
                                }
                                Label {
                                    text: compraData ? formatearFecha(compraData.Fecha) : ""
                                    color: textColor
                                    font.pixelSize: fontNormal
                                }
                                
                                // Fila 2
                                Label {
                                    text: "Proveedor:"
                                    color: secondaryTextColor
                                    font.pixelSize: fontSmall
                                }
                                Label {
                                    text: compraData ? compraData.Proveedor_Nombre : ""
                                    color: textColor
                                    font.pixelSize: fontNormal
                                    Layout.columnSpan: 1
                                }
                                
                                Label {
                                    text: "Hora:"
                                    color: secondaryTextColor
                                    font.pixelSize: fontSmall
                                }
                                Label {
                                    text: compraData ? formatearHora(compraData.Fecha) : ""
                                    color: textColor
                                    font.pixelSize: fontNormal
                                }
                                
                                // Fila 3
                                Label {
                                    text: "Usuario:"
                                    color: secondaryTextColor
                                    font.pixelSize: fontSmall
                                }
                                Label {
                                    text: compraData ? compraData.Usuario : ""
                                    color: textColor
                                    font.pixelSize: fontNormal
                                }
                                
                                Label {
                                    text: "Total:"
                                    color: secondaryTextColor
                                    font.pixelSize: fontSmall
                                }
                                Label {
                                    text: compraData ? "Bs " + compraData.Total.toFixed(2) : ""
                                    color: successColor
                                    font.pixelSize: fontNormal
                                    font.bold: true
                                }
                            }
                        }
                    }
                    
                    // ================================================================
                    // SECCIÓN 2: TABLA DE PRODUCTOS
                    // ================================================================
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 400
                        color: cardBackgroundColor
                        radius: 8
                        border.color: borderColor
                        border.width: 1
                        
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: spacing16
                            spacing: spacing8
                            
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: spacing8
                                
                                Label {
                                    text: "🛒 PRODUCTOS COMPRADOS"
                                    color: textColor
                                    font.pixelSize: fontMedium
                                    font.bold: true
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: 40
                                    Layout.preferredHeight: 24
                                    color: headerColor
                                    radius: 12
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: compraData ? compraData.total_items : "0"
                                        color: "white"
                                        font.pixelSize: fontSmall
                                        font.bold: true
                                    }
                                }
                                
                                Item { Layout.fillWidth: true }
                            }
                            
                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: borderColor
                            }
                            
                            // ENCABEZADOS
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 35
                                color: headerColor
                                radius: 4
                                
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: spacing8
                                    spacing: spacing8
                                    
                                    Label {
                                        text: "CÓDIGO"
                                        color: "white"
                                        font.pixelSize: fontSmall
                                        font.bold: true
                                        Layout.preferredWidth: 80
                                    }
                                    
                                    Label {
                                        text: "PRODUCTO"
                                        color: "white"
                                        font.pixelSize: fontSmall
                                        font.bold: true
                                        Layout.fillWidth: true
                                    }
                                    
                                    Label {
                                        text: "CANT."
                                        color: "white"
                                        font.pixelSize: fontSmall
                                        font.bold: true
                                        Layout.preferredWidth: 60
                                        horizontalAlignment: Text.AlignRight
                                    }
                                    
                                    Label {
                                        text: "COSTO C/U"
                                        color: "white"
                                        font.pixelSize: fontSmall
                                        font.bold: true
                                        Layout.preferredWidth: 90
                                        horizontalAlignment: Text.AlignRight
                                    }
                                    
                                    Label {
                                        text: "VENCIMIENTO"
                                        color: "white"
                                        font.pixelSize: fontSmall
                                        font.bold: true
                                        Layout.preferredWidth: 100
                                        horizontalAlignment: Text.AlignCenter
                                    }
                                    
                                    Label {
                                        text: "TOTAL"
                                        color: "white"
                                        font.pixelSize: fontSmall
                                        font.bold: true
                                        Layout.preferredWidth: 90
                                        horizontalAlignment: Text.AlignRight
                                    }
                                    
                                    Item {
                                        Layout.preferredWidth: 40
                                    }
                                }
                            }
                            
                            // LISTA DE PRODUCTOS
                            ListView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                spacing: 2
                                
                                model: compraData ? compraData.detalles : []
                                
                                delegate: Rectangle {
                                    width: parent ? parent.width : 0
                                    height: 50
                                    color: index % 2 === 0 ? "#ffffff" : "#fafafa"
                                    radius: 4
                                    
                                    // Hover effect
                                    Rectangle {
                                        anchors.fill: parent
                                        color: hoverColor
                                        radius: 4
                                        opacity: mouseArea.containsMouse ? 0.5 : 0
                                        
                                        Behavior on opacity {
                                            NumberAnimation { duration: 150 }
                                        }
                                    }
                                    
                                    MouseArea {
                                        id: mouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onDoubleClicked: abrirEditarLote(modelData)
                                    }
                                    
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: spacing8
                                        spacing: spacing8
                                        
                                        // CÓDIGO
                                        Label {
                                            text: modelData.Producto_Codigo || ""
                                            color: textColor
                                            font.pixelSize: fontSmall
                                            font.bold: true
                                            Layout.preferredWidth: 80
                                            elide: Text.ElideRight
                                        }
                                        
                                        // NOMBRE
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2
                                            
                                            Label {
                                                text: modelData.Producto_Nombre || ""
                                                color: textColor
                                                font.pixelSize: fontNormal
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }
                                            
                                            Label {
                                                text: modelData.Marca_Nombre ? "Marca: " + modelData.Marca_Nombre : ""
                                                color: secondaryTextColor
                                                font.pixelSize: 10
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }
                                        }
                                        
                                        // CANTIDAD
                                        Label {
                                            text: modelData.Cantidad_Total || "0"
                                            color: headerColor
                                            font.pixelSize: fontNormal
                                            font.bold: true
                                            Layout.preferredWidth: 60
                                            horizontalAlignment: Text.AlignRight
                                        }
                                        
                                        // COSTO UNITARIO
                                        Label {
                                            text: "Bs " + (modelData.Precio_Unitario_Compra || 0).toFixed(2)
                                            color: textColor
                                            font.pixelSize: fontSmall
                                            Layout.preferredWidth: 90
                                            horizontalAlignment: Text.AlignRight
                                        }
                                        
                                        // VENCIMIENTO
                                        Label {
                                            text: modelData.Fecha_Vencimiento ? formatearFecha(modelData.Fecha_Vencimiento) : "Sin venc."
                                            color: modelData.Fecha_Vencimiento ? warningColor : secondaryTextColor
                                            font.pixelSize: 10
                                            Layout.preferredWidth: 100
                                            horizontalAlignment: Text.AlignCenter
                                        }
                                        
                                        // TOTAL
                                        Label {
                                            text: "Bs " + (modelData.Costo_Total || 0).toFixed(2)
                                            color: successColor
                                            font.pixelSize: fontNormal
                                            font.bold: true
                                            Layout.preferredWidth: 90
                                            horizontalAlignment: Text.AlignRight
                                        }
                                        
                                    }
                                }
                                
                                // Mensaje si no hay productos
                                Label {
                                    visible: !compraData || !compraData.detalles || compraData.detalles.length === 0
                                    anchors.centerIn: parent
                                    text: "📭 No hay productos en esta compra"
                                    color: secondaryTextColor
                                    font.pixelSize: fontNormal
                                }
                            }
                            
                        }
                    }
                    
                    // ================================================================
                    // SECCIÓN 3: RESUMEN FINANCIERO
                    // ================================================================
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: resumenLayout.height + spacing24
                        color: cardBackgroundColor
                        radius: 8
                        border.color: borderColor
                        border.width: 1
                        Label {
                                text: "   💰 RESUMEN FINANCIERO"
                                color: textColor
                                font.pixelSize: fontMedium
                                font.bold: true
                                Layout.alignment: Qt.AlignLeft
                        }
                        
                        ColumnLayout {
                            id: resumenLayout
                            anchors.fill: parent
                            anchors.margins: spacing16
                            spacing: spacing8
                            
                            
                            
                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: borderColor
                            }
                            
                            // Contenedor para los valores del resumen
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: spacing8
                                
                                // Fila 1: Subtotal
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: spacing24
                                    
                                    Label {
                                        text: "Subtotal:"
                                        color: secondaryTextColor
                                        font.pixelSize: fontNormal
                                        Layout.preferredWidth: 150
                                    }
                                    
                                    Label {
                                        text: compraData ? "Bs " + compraData.Total.toFixed(2) : ""
                                        color: textColor
                                        font.pixelSize: fontNormal
                                        font.bold: true
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }
                                
                                // Fila 2: Items comprados
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: spacing24
                                    
                                    Label {
                                        text: "Items comprados:"
                                        color: secondaryTextColor
                                        font.pixelSize: fontNormal
                                        Layout.preferredWidth: 150
                                    }
                                    
                                    Label {
                                        text: compraData ? compraData.total_items + " productos" : ""
                                        color: textColor
                                        font.pixelSize: fontNormal
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }
                                
                                // Fila 3: Unidades totales
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: spacing24
                                    
                                    Label {
                                        text: "Unidades totales:"
                                        color: secondaryTextColor
                                        font.pixelSize: fontNormal
                                        Layout.preferredWidth: 150
                                    }
                                    
                                    Label {
                                        text: compraData ? compraData.total_unidades + " unidades" : ""
                                        color: textColor
                                        font.pixelSize: fontNormal
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }
                                
                                Item { Layout.preferredHeight: spacing8 }
                                
                                // TOTAL DESTACADO - MÁS LARGO
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 60
                                    // MÁRGENES NEGATIVOS PARA HACERLO MÁS LARGO
                                    Layout.leftMargin: -spacing24   // Cambiado de -spacing16
                                    Layout.rightMargin: -spacing24  // Cambiado de -spacing16
                                    color: successColor
                                    radius: 8
                                    
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: spacing16
                                        spacing: spacing16
                                        
                                        Label {
                                            text: "TOTAL COMPRA:"
                                            color: "white"
                                            font.pixelSize: fontLarge
                                            font.bold: true
                                        }
                                        
                                        Item { Layout.fillWidth: true }
                                        
                                        Label {
                                            text: compraData ? "Bs " + compraData.Total.toFixed(2) : ""
                                            color: "white"
                                            font.pixelSize: fontXLarge
                                            font.bold: true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    function formatearFecha(fechaStr) {
        if (!fechaStr) return "N/A"
        
        try {
            // Si ya es una fecha formateada dd/mm/yyyy, retornarla
            if (typeof fechaStr === 'string' && fechaStr.includes('/')) {
                return fechaStr
            }
            
            // Si es un string ISO (2024-01-15 o 2024-01-15T10:30:00)
            if (typeof fechaStr === 'string') {
                // Extraer solo la parte de la fecha (sin hora)
                var fechaPart = fechaStr.split('T')[0].split(' ')[0]
                var partes = fechaPart.split('-')
                
                if (partes.length === 3) {
                    var dia = partes[2]
                    var mes = partes[1]
                    var anio = partes[0]
                    return dia + "/" + mes + "/" + anio
                }
            }
            
            // Intentar como objeto Date
            var fecha = new Date(fechaStr)
            if (isNaN(fecha.getTime())) return "N/A"
            
            var dia = ("0" + fecha.getDate()).slice(-2)
            var mes = ("0" + (fecha.getMonth() + 1)).slice(-2)
            var anio = fecha.getFullYear()
            return dia + "/" + mes + "/" + anio
        } catch (e) {
            console.log("❌ Error formateando fecha:", fechaStr, e)
            return "N/A"
        }
    }

    function formatearHora(fechaStr) {
        if (!fechaStr) return "N/A"
        
        try {
            // Si es un string ISO con hora
            if (typeof fechaStr === 'string' && fechaStr.includes('T')) {
                var horaPart = fechaStr.split('T')[1]
                if (horaPart) {
                    var partesHora = horaPart.split(':')
                    if (partesHora.length >= 2) {
                        return partesHora[0] + ":" + partesHora[1]
                    }
                }
            }
            
            // Intentar como objeto Date
            var fecha = new Date(fechaStr)
            if (isNaN(fecha.getTime())) return "N/A"
            
            var hora = ("0" + fecha.getHours()).slice(-2)
            var min = ("0" + fecha.getMinutes()).slice(-2)
            return hora + ":" + min
        } catch (e) {
            console.log("❌ Error formateando hora:", fechaStr, e)
            return "N/A"
        }
    }
    
    // ============================================================================
    // SHORTCUTS
    // ============================================================================
    Shortcut {
        sequence: "Esc"
        onActivated: cerrar()
    }
}