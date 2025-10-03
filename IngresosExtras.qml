import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtGraphicalEffects 1.15

Item {
    id: ingresosExtrasRoot
    objectName: "ingresosExtrasRoot"
    
    // ACCESO A PROPIEDADES ADAPTATIVAS DEL MAIN
    readonly property real baseUnit: parent.baseUnit || Math.max(8, Screen.height / 100)
    readonly property real fontBaseSize: parent.fontBaseSize || Math.max(12, Screen.height / 70)
    readonly property real scaleFactor: parent.scaleFactor || Math.min(width / 1400, height / 900)
    
    // PROPIEDADES DE COLOR
    readonly property color primaryColor: "#3498db"
    readonly property color primaryColorHover: "#2980B9"
    readonly property color primaryColorPressed: "#21618C"
    readonly property color successColor: "#10B981"
    readonly property color successColorLight: "#D1FAE5"
    readonly property color dangerColor: "#E74C3C"
    readonly property color lightGrayColor: "#F8F9FA"
    readonly property color textColor: "#2c3e50"
    readonly property color textColorLight: "#6B7280"
    readonly property color whiteColor: "#FFFFFF"
    readonly property color borderColor: "#E5E7EB"
    readonly property color lineColor: "#D1D5DB"
    
    // Distribución de columnas
    readonly property real colID: 0.08
    readonly property real colDescripcion: 0.35
    readonly property real colMonto: 0.15
    readonly property real colFecha: 0.15
    readonly property real colRegistradoPor: 0.20
    readonly property real colAcciones: 0.07
    
    // Propiedades de paginación y edición
    property int itemsPerPage: 8
    property int currentPage: 0
    property int totalPages: Math.ceil(ingresosModel.count / itemsPerPage)
    property int selectedRowIndex: -1
    property bool isEditMode: false
    property int editingIndex: -1
    property bool showConfirmDeleteDialog: false
    property int deleteIndex: -1
    
    // Modelo paginado
    ListModel {
        id: ingresosPaginadosModel
    }
    
    // Modelo completo de datos
    ListModel {
        id: ingresosModel
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
        ListElement {
            id_registro: 4
            descripcion: "Comisión por ventas adicionales"
            monto: 350.00
            fecha: "2025-09-08"
            registradoPor: "Ana Martínez"
        }
        ListElement {
            id_registro: 5
            descripcion: "Ingreso por capacitación externa"
            monto: 600.00
            fecha: "2025-09-05"
            registradoPor: "Luis Ramírez"
        }
        ListElement {
            id_registro: 6
            descripcion: "Bono de productividad"
            monto: 450.00
            fecha: "2025-09-03"
            registradoPor: "Carmen Silva"
        }
        ListElement {
            id_registro: 7
            descripcion: "Servicios profesionales extra"
            monto: 920.30
            fecha: "2025-09-01"
            registradoPor: "Roberto Díaz"
        }
        ListElement {
            id_registro: 8
            descripcion: "Venta de activos"
            monto: 1500.00
            fecha: "2025-08-28"
            registradoPor: "Patricia Rojas"
        }
        ListElement {
            id_registro: 9
            descripcion: "Intereses bancarios"
            monto: 125.80
            fecha: "2025-08-25"
            registradoPor: "Javier Torres"
        }
    }
    
    function updatePaginatedModel() {
        var startIndex = currentPage * itemsPerPage
        var endIndex = Math.min(startIndex + itemsPerPage, ingresosModel.count)
        
        ingresosPaginadosModel.clear()
        
        for (var i = startIndex; i < endIndex; i++) {
            var item = ingresosModel.get(i)
            ingresosPaginadosModel.append({
                id_registro: item.id_registro,
                descripcion: item.descripcion,
                monto: item.monto,
                fecha: item.fecha,
                registradoPor: item.registradoPor,
                originalIndex: i
            })
        }
        
        totalPages = Math.ceil(ingresosModel.count / itemsPerPage)
    }
    
    function editarIngreso(paginatedIndex) {
        var item = ingresosPaginadosModel.get(paginatedIndex)
        var originalIndex = item.originalIndex
        
        console.log("Editando ingreso:", item.id_registro)
        
        isEditMode = true
        editingIndex = originalIndex
        
        txtDescripcion.text = item.descripcion
        txtMonto.text = item.monto.toString()
        txtFecha.text = item.fecha
        
        nuevoIngresoDialog.open()
    }
    
    function eliminarIngreso(paginatedIndex) {
        var item = ingresosPaginadosModel.get(paginatedIndex)
        deleteIndex = item.originalIndex
        showConfirmDeleteDialog = true
    }
    
    function guardarIngreso() {
        if (!txtDescripcion.text || !txtMonto.text) {
            console.log("Faltan campos obligatorios")
            return
        }
        
        if (isEditMode) {
            ingresosModel.set(editingIndex, {
                id_registro: ingresosModel.get(editingIndex).id_registro,
                descripcion: txtDescripcion.text,
                monto: parseFloat(txtMonto.text),
                fecha: txtFecha.text,
                registradoPor: ingresosModel.get(editingIndex).registradoPor
            })
            console.log("Ingreso actualizado")
        } else {
            var maxId = 0
            for (var i = 0; i < ingresosModel.count; i++) {
                if (ingresosModel.get(i).id_registro > maxId) {
                    maxId = ingresosModel.get(i).id_registro
                }
            }
            
            ingresosModel.append({
                id_registro: maxId + 1,
                descripcion: txtDescripcion.text,
                monto: parseFloat(txtMonto.text),
                fecha: txtFecha.text,
                registradoPor: "Usuario Actual"
            })
            console.log("Nuevo ingreso creado")
        }
        
        limpiarFormulario()
        nuevoIngresoDialog.close()
        updatePaginatedModel()
    }
    
    function limpiarFormulario() {
        txtDescripcion.text = ""
        txtMonto.text = ""
        txtFecha.text = Qt.formatDate(new Date(), "yyyy-MM-dd")
        isEditMode = false
        editingIndex = -1
    }
    
    Component.onCompleted: {
        updatePaginatedModel()
    }
    
    // LAYOUT PRINCIPAL
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: baseUnit * 4
        spacing: baseUnit * 3
        
        // CONTENEDOR PRINCIPAL
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: whiteColor
            radius: baseUnit * 2
            border.color: borderColor
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                
                // HEADER
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: baseUnit * 12
                    color: lightGrayColor
                    border.color: borderColor
                    border.width: 1
                    radius: baseUnit * 2
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: baseUnit * 2
                        spacing: baseUnit * 2
                        
                        RowLayout {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: baseUnit * 1.5
                            
                            Rectangle {
                                Layout.preferredWidth: baseUnit * 10
                                Layout.preferredHeight: baseUnit * 10
                                color: primaryColor
                                radius: baseUnit * 1
                                
                                Label {
                                    anchors.centerIn: parent
                                    text: "$"
                                    font.pixelSize: fontBaseSize * 3
                                    font.bold: true
                                    color: whiteColor
                                }
                            }
                            
                            Label {
                                Layout.alignment: Qt.AlignVCenter
                                text: "Gestión de Ingresos Extras"
                                font.pixelSize: fontBaseSize * 1.3
                                font.bold: true
                                font.family: "Segoe UI, Arial, sans-serif"
                                color: textColor
                                wrapMode: Text.WordWrap
                            }
                        }
                        
                        Item { 
                            Layout.fillWidth: true 
                            Layout.minimumWidth: baseUnit * 2
                        }
                        
                        Button {
                            id: newIngresoBtn
                            Layout.preferredHeight: baseUnit * 5
                            Layout.preferredWidth: Math.max(baseUnit * 20, implicitWidth + baseUnit * 2)
                            Layout.alignment: Qt.AlignVCenter
                            
                            background: Rectangle {
                                color: newIngresoBtn.pressed ? Qt.darker(primaryColor, 1.1) : 
                                    newIngresoBtn.hovered ? Qt.lighter(primaryColor, 1.1) : primaryColor
                                radius: baseUnit * 1.2
                                border.width: 0
                                
                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                            
                            contentItem: RowLayout {
                                spacing: baseUnit
                                
                                Label {
                                    text: "+"
                                    color: whiteColor
                                    font.pixelSize: fontBaseSize * 1.5
                                    font.bold: true
                                }
                                
                                Label {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: "Nuevo Ingreso"
                                    color: whiteColor
                                    font.bold: true
                                    font.pixelSize: fontBaseSize
                                    font.family: "Segoe UI, Arial, sans-serif"
                                }
                            }
                            
                            onClicked: {
                                limpiarFormulario()
                                nuevoIngresoDialog.open()
                            }
                            
                            HoverHandler {
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }
                }
                
                // FILTROS
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: baseUnit * 8
                    color: "transparent"
                    
                    GridLayout {
                        anchors.fill: parent
                        anchors.margins: baseUnit * 3
                        anchors.bottomMargin: baseUnit * 1.5
                        columns: 3
                        rowSpacing: baseUnit
                        columnSpacing: baseUnit * 2
                        
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit
                            
                            Label {
                                text: "Mes:"
                                font.bold: true
                                color: textColor
                                font.pixelSize: fontBaseSize * 0.9
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                            
                            ComboBox {
                                id: mesCombo
                                Layout.fillWidth: true
                                Layout.preferredHeight: baseUnit * 4
                                model: ["Todos los periodos", "Enero", "Febrero", "Marzo", "Abril", "Mayo", 
                                        "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"]
                                currentIndex: 0
                                
                                contentItem: Label {
                                    text: mesCombo.displayText
                                    font.pixelSize: fontBaseSize * 0.8
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    color: textColor
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: baseUnit
                                }
                            }
                        }
                        
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit
                            
                            Label {
                                text: "Año:"
                                font.bold: true
                                color: textColor
                                font.pixelSize: fontBaseSize * 0.9
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                            
                            ComboBox {
                                id: anioCombo
                                Layout.fillWidth: true
                                Layout.preferredHeight: baseUnit * 4
                                model: ["2025", "2024", "2023"]
                                currentIndex: 0
                                
                                contentItem: Label {
                                    text: anioCombo.displayText
                                    font.pixelSize: fontBaseSize * 0.8
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    color: textColor
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: baseUnit
                                }
                            }
                        }
                        
                        Button {
                            text: "Limpiar"
                            Layout.preferredHeight: baseUnit * 4
                            Layout.fillWidth: true
                            
                            background: Rectangle {
                                color: parent.pressed ? "#E5E7EB" : 
                                    parent.hovered ? "#D1D5DB" : "#F3F4F6"
                                border.color: "#D1D5DB"
                                border.width: 1
                                radius: baseUnit * 0.8
                            }
                            
                            contentItem: Label {
                                text: parent.text
                                color: "#374151"
                                font.pixelSize: fontBaseSize * 0.9
                                font.family: "Segoe UI, Arial, sans-serif"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: {
                                mesCombo.currentIndex = 0
                                anioCombo.currentIndex = 0
                            }
                            
                            HoverHandler {
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }
                }
                
                // TABLA
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.leftMargin: baseUnit * 3
                    Layout.rightMargin: baseUnit * 3
                    Layout.bottomMargin: baseUnit * 3
                    Layout.topMargin: 0
                    color: whiteColor
                    border.color: borderColor
                    border.width: 1
                    radius: baseUnit
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 0
                        spacing: 0
                        
                        // HEADER DE TABLA
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: baseUnit * 6
                            color: lightGrayColor
                            border.color: borderColor
                            border.width: 1
                            z: 5
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: baseUnit * 1.5
                                anchors.rightMargin: baseUnit * 1.5
                                spacing: 0
                                
                                Item {
                                    Layout.preferredWidth: parent.width * colID
                                    Layout.fillHeight: true
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "ID"
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
                                
                                Item {
                                    Layout.preferredWidth: parent.width * colDescripcion
                                    Layout.fillHeight: true
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "DESCRIPCIÓN"
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
                                
                                Item {
                                    Layout.preferredWidth: parent.width * colMonto
                                    Layout.fillHeight: true
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "MONTO"
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
                                    
                                    Rectangle {
                                        anchors.right: parent.right
                                        width: 1
                                        height: parent.height
                                        color: lineColor
                                    }
                                }
                                
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
                                }
                            }
                        }
                        
                        // CONTENIDO DE TABLA
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            
                            ListView {
                                id: listViewIngresos
                                model: ingresosPaginadosModel
                                
                                delegate: Rectangle {
                                    width: ListView.view.width
                                    height: baseUnit * 5.5
                                    color: {
                                        if (selectedRowIndex === index) return "#F8F9FA"
                                        return index % 2 === 0 ? whiteColor : "#FAFAFA"
                                    }
                                    
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
                                        
                                        Item {
                                            Layout.preferredWidth: parent.width * colID
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                text: model.id_registro || "N/A"
                                                color: textColor
                                                font.bold: false
                                                font.pixelSize: fontBaseSize * 0.9
                                                font.family: "Segoe UI, Arial, sans-serif"
                                            }
                                            
                                            Rectangle {
                                                anchors.right: parent.right
                                                width: 1
                                                height: parent.height
                                                color: lineColor
                                            }
                                        }
                                        
                                        Item {
                                            Layout.preferredWidth: parent.width * colDescripcion
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                anchors.rightMargin: baseUnit
                                                text: model.descripcion || "Sin descripción"
                                                color: textColor
                                                font.bold: false
                                                font.pixelSize: fontBaseSize * 0.85
                                                font.family: "Segoe UI, Arial, sans-serif"
                                                elide: Text.ElideRight
                                            }
                                            
                                            Rectangle {
                                                anchors.right: parent.right
                                                width: 1
                                                height: parent.height
                                                color: lineColor
                                            }
                                        }
                                        
                                        Item {
                                            Layout.preferredWidth: parent.width * colMonto
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.centerIn: parent
                                                text: "Bs " + (model.monto ? model.monto.toFixed(2) : "0.00")
                                                color: successColor
                                                font.bold: true
                                                font.pixelSize: fontBaseSize * 0.9
                                                font.family: "Segoe UI, Arial, sans-serif"
                                            }
                                            
                                            Rectangle {
                                                anchors.right: parent.right
                                                width: 1
                                                height: parent.height
                                                color: lineColor
                                            }
                                        }
                                        
                                        Item {
                                            Layout.preferredWidth: parent.width * colFecha
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.centerIn: parent
                                                text: model.fecha || "Sin fecha"
                                                color: textColor
                                                font.bold: false
                                                font.pixelSize: fontBaseSize * 0.85
                                                font.family: "Segoe UI, Arial, sans-serif"
                                            }
                                            
                                            Rectangle {
                                                anchors.right: parent.right
                                                width: 1
                                                height: parent.height
                                                color: lineColor
                                            }
                                        }
                                        
                                        Item {
                                            Layout.preferredWidth: parent.width * colRegistradoPor
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                anchors.rightMargin: baseUnit
                                                text: model.registradoPor || "Sin registro"
                                                color: textColorLight
                                                font.pixelSize: fontBaseSize * 0.85
                                                font.family: "Segoe UI, Arial, sans-serif"
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            selectedRowIndex = selectedRowIndex === index ? -1 : index
                                        }
                                    }
                                    
                                    RowLayout {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.right: parent.right
                                        anchors.margins: baseUnit * 0.8
                                        spacing: baseUnit * 0.8
                                        visible: selectedRowIndex === index
                                        z: 10
                                        
                                        Button {
                                            width: baseUnit * 3.5
                                            height: baseUnit * 3.5
                                            
                                            background: Rectangle {
                                                color: parent.hovered ? "#E5E7EB" : "transparent"
                                                radius: baseUnit * 0.5
                                            }
                                            
                                            contentItem: Label {
                                                anchors.centerIn: parent
                                                text: "E"
                                                font.pixelSize: fontBaseSize * 1.2
                                                font.bold: true
                                                color: primaryColor
                                            }
                                            
                                            onClicked: {
                                                editarIngreso(index)
                                            }
                                            
                                            HoverHandler {
                                                cursorShape: Qt.PointingHandCursor
                                            }
                                        }
                                        
                                        Button {
                                            width: baseUnit * 3.5
                                            height: baseUnit * 3.5
                                            
                                            background: Rectangle {
                                                color: parent.hovered ? "#FEE2E2" : "transparent"
                                                radius: baseUnit * 0.5
                                            }
                                            
                                            contentItem: Label {
                                                anchors.centerIn: parent
                                                text: "X"
                                                font.pixelSize: fontBaseSize * 1.2
                                                font.bold: true
                                                color: dangerColor
                                            }
                                            
                                            onClicked: {
                                                eliminarIngreso(index)
                                            }
                                            
                                            HoverHandler {
                                                cursorShape: Qt.PointingHandCursor
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // ESTADO VACÍO
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: ingresosModel.count === 0
                            spacing: baseUnit * 3
                            
                            Item { Layout.fillHeight: true }
                            
                            ColumnLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: baseUnit * 2
                                
                                Label {
                                    text: "$"
                                    font.pixelSize: fontBaseSize * 5
                                    color: "#E5E7EB"
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                
                                Label {
                                    text: "No hay ingresos extras registrados"
                                    color: textColor
                                    font.bold: true
                                    font.pixelSize: fontBaseSize * 1.5
                                    Layout.alignment: Qt.AlignHCenter
                                    font.family: "Segoe UI, Arial, sans-serif"
                                }
                                
                                Label {
                                    text: "Registra el primer ingreso haciendo clic en \"Nuevo Ingreso\""
                                    color: textColorLight
                                    font.pixelSize: fontBaseSize
                                    Layout.alignment: Qt.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    horizontalAlignment: Text.AlignHCenter
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    Layout.maximumWidth: baseUnit * 40
                                }
                            }
                            
                            Item { Layout.fillHeight: true }
                        }
                    }
                }
                
                // PAGINACIÓN
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: baseUnit * 6
                    Layout.leftMargin: baseUnit * 3
                    Layout.rightMargin: baseUnit * 3
                    Layout.bottomMargin: baseUnit * 3
                    Layout.topMargin: 0
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
                                if (currentPage > 0) {
                                    currentPage--
                                    updatePaginatedModel()
                                    selectedRowIndex = -1
                                }
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
                                if (currentPage < totalPages - 1) {
                                    currentPage++
                                    updatePaginatedModel()
                                    selectedRowIndex = -1
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // DIÁLOGO NUEVO/EDITAR
    Dialog {
        id: nuevoIngresoDialog
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.6, 700)
        height: Math.min(parent.height * 0.7, 550)
        modal: true
        closePolicy: Popup.NoAutoClose
        
        title: ""
        
        background: Rectangle {
            color: whiteColor
            radius: baseUnit * 1.5
            border.color: borderColor
            border.width: 1
            
            layer.enabled: true
            layer.effect: DropShadow {
                horizontalOffset: 0
                verticalOffset: baseUnit * 0.5
                radius: baseUnit * 2
                samples: 17
                color: "#40000000"
            }
        }
        
        Rectangle {
            id: dialogHeader
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: baseUnit * 7
            color: primaryColor
            radius: baseUnit * 1.5
            
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: baseUnit * 1.5
                color: parent.color
            }
            
            Label {
                anchors.centerIn: parent
                text: isEditMode ? "EDITAR INGRESO EXTRA" : "NUEVO INGRESO EXTRA"
                font.pixelSize: fontBaseSize * 1.2
                font.bold: true
                color: whiteColor
                font.family: "Segoe UI, Arial, sans-serif"
            }
            
            Button {
                anchors.right: parent.right
                anchors.rightMargin: baseUnit * 2
                anchors.verticalCenter: parent.verticalCenter
                width: baseUnit * 4
                height: baseUnit * 4
                
                background: Rectangle {
                    color: "transparent"
                    radius: width / 2
                    border.color: parent.hovered ? whiteColor : "transparent"
                    border.width: 1
                }
                
                contentItem: Text {
                    text: "×"
                    color: whiteColor
                    font.pixelSize: fontBaseSize * 1.8
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: {
                    limpiarFormulario()
                    nuevoIngresoDialog.close()
                }
                
                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
        
        ScrollView {
            anchors.top: dialogHeader.bottom
            anchors.topMargin: baseUnit * 2
            anchors.bottom: buttonRow.top
            anchors.bottomMargin: baseUnit * 2
            anchors.left: parent.left
            anchors.leftMargin: baseUnit * 3
            anchors.right: parent.right
            anchors.rightMargin: baseUnit * 3
            clip: true
            
            ColumnLayout {
                width: parent.width - baseUnit * 2
                spacing: baseUnit * 2
                
                GroupBox {
                    Layout.fillWidth: true
                    title: "INFORMACIÓN DEL INGRESO"
                    font.bold: true
                    font.pixelSize: fontBaseSize
                    font.family: "Segoe UI, Arial, sans-serif"
                    padding: baseUnit * 1.5
                    
                    background: Rectangle {
                        color: "#f8f9fa"
                        border.color: "#e0e0e0"
                        radius: baseUnit * 0.8
                    }
                    
                    ColumnLayout {
                        width: parent.width
                        spacing: baseUnit * 2
                        
                        Label {
                            text: "Descripción:"
                            font.pixelSize: fontBaseSize
                            font.bold: true
                            color: textColor
                            font.family: "Segoe UI, Arial, sans-serif"
                        }
                        
                        TextField {
                            id: txtDescripcion
                            Layout.fillWidth: true
                            Layout.preferredHeight: baseUnit * 4
                            placeholderText: "Descripción del ingreso extra"
                            font.pixelSize: fontBaseSize
                            font.family: "Segoe UI, Arial, sans-serif"
                            
                            background: Rectangle {
                                color: whiteColor
                                border.color: parent.activeFocus ? primaryColor : borderColor
                                border.width: parent.activeFocus ? 2 : 1
                                radius: baseUnit * 0.6
                            }
                        }
                        
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit * 2
                            
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: baseUnit
                                
                                Label {
                                    text: "Monto (Bs):"
                                    font.pixelSize: fontBaseSize
                                    font.bold: true
                                    color: textColor
                                    font.family: "Segoe UI, Arial, sans-serif"
                                }
                                
                                TextField {
                                    id: txtMonto
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: baseUnit * 4
                                    placeholderText: "0.00"
                                    font.pixelSize: fontBaseSize
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    validator: DoubleValidator {
                                        bottom: 0
                                        decimals: 2
                                    }
                                    
                                    background: Rectangle {
                                        color: whiteColor
                                        border.color: parent.activeFocus ? primaryColor : borderColor
                                        border.width: parent.activeFocus ? 2 : 1
                                        radius: baseUnit * 0.6
                                    }
                                }
                            }
                            
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: baseUnit
                                
                                Label {
                                    text: "Fecha:"
                                    font.pixelSize: fontBaseSize
                                    font.bold: true
                                    color: textColor
                                    font.family: "Segoe UI, Arial, sans-serif"
                                }
                                
                                TextField {
                                    id: txtFecha
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: baseUnit * 4
                                    text: Qt.formatDate(new Date(), "yyyy-MM-dd")
                                    font.pixelSize: fontBaseSize
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    
                                    background: Rectangle {
                                        color: whiteColor
                                        border.color: parent.activeFocus ? primaryColor : borderColor
                                        border.width: parent.activeFocus ? 2 : 1
                                        radius: baseUnit * 0.6
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        RowLayout {
            id: buttonRow
            anchors.bottom: parent.bottom
            anchors.bottomMargin: baseUnit * 2
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: baseUnit * 2
            
            Button {
                text: "Cancelar"
                Layout.preferredWidth: baseUnit * 15
                Layout.preferredHeight: baseUnit * 4.5
                
                background: Rectangle {
                    color: parent.pressed ? "#e0e0e0" : 
                        (parent.hovered ? "#f0f0f0" : "#f8f9fa")
                    border.color: "#ddd"
                    border.width: 1
                    radius: baseUnit * 0.8
                }
                
                contentItem: Label {
                    text: parent.text
                    font.pixelSize: fontBaseSize
                    font.bold: true
                    font.family: "Segoe UI, Arial, sans-serif"
                    color: textColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: {
                    limpiarFormulario()
                    nuevoIngresoDialog.close()
                }
                
                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }
            }
            
            Button {
                text: isEditMode ? "Actualizar" : "Guardar"
                Layout.preferredWidth: baseUnit * 15
                Layout.preferredHeight: baseUnit * 4.5
                enabled: txtDescripcion.text.length > 0 && txtMonto.text.length > 0
                
                background: Rectangle {
                    color: {
                        if (!parent.enabled) return "#bdc3c7"
                        if (parent.pressed) return Qt.darker(primaryColor, 1.1)
                        if (parent.hovered) return Qt.lighter(primaryColor, 1.1)
                        return primaryColor
                    }
                    radius: baseUnit * 0.8
                    
                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                }
                
                contentItem: Label {
                    text: parent.text
                    font.pixelSize: fontBaseSize
                    font.bold: true
                    font.family: "Segoe UI, Arial, sans-serif"
                    color: whiteColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: {
                    guardarIngreso()
                }
                
                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
    }
    
    // DIÁLOGO ELIMINAR
    Dialog {
        id: confirmDeleteDialog
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.4, 450)
        height: Math.min(parent.height * 0.4, 280)
        modal: true
        closePolicy: Popup.NoAutoClose
        visible: showConfirmDeleteDialog
        
        title: ""
        
        background: Rectangle {
            color: whiteColor
            radius: baseUnit * 0.8
            border.color: "#e0e0e0"
            border.width: 1
            
            layer.enabled: true
            layer.effect: DropShadow {
                horizontalOffset: 0
                verticalOffset: baseUnit * 0.5
                radius: baseUnit * 2
                samples: 17
                color: "#40000000"
            }
        }
        
        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 75
                color: "#fff5f5"
                radius: baseUnit * 0.8
                
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: baseUnit * 0.8
                    color: parent.color
                }
                
                RowLayout {
                    anchors.centerIn: parent
                    spacing: baseUnit * 2
                    
                    Rectangle {
                        Layout.preferredWidth: 45
                        Layout.preferredHeight: 45
                        color: "#fee2e2"
                        radius: 22
                        border.color: "#fecaca"
                        border.width: 2
                        
                        Label {
                            anchors.centerIn: parent
                            text: "!"
                            font.pixelSize: fontBaseSize * 2
                            font.bold: true
                            color: "#dc2626"
                        }
                    }
                    
                    Label {
                        text: "Confirmar Eliminación"
                        font.pixelSize: fontBaseSize * 1.3
                        font.bold: true
                        color: "#dc2626"
                    }
                }
            }
            
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "transparent"
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: baseUnit * 2
                    spacing: baseUnit * 2
                    
                    Label {
                        text: "¿Está seguro de eliminar este ingreso extra?"
                        font.pixelSize: fontBaseSize * 1.1
                        font.bold: true
                        color: textColor
                        Layout.alignment: Qt.AlignHCenter
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        font.family: "Segoe UI, Arial, sans-serif"
                    }
                    
                    Label {
                        text: "Esta acción no se puede deshacer."
                        font.pixelSize: fontBaseSize * 0.9
                        color: "#6b7280"
                        Layout.alignment: Qt.AlignHCenter
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        font.family: "Segoe UI, Arial, sans-serif"
                    }
                    
                    Item { Layout.fillHeight: true }
                    
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: baseUnit * 3
                        
                        Button {
                            Layout.preferredWidth: 120
                            Layout.preferredHeight: 45
                            
                            background: Rectangle {
                                color: parent.pressed ? "#e5e7eb" : 
                                    (parent.hovered ? "#f3f4f6" : "#f9fafb")
                                radius: baseUnit * 0.6
                                border.color: "#d1d5db"
                                border.width: 1
                            }
                            
                            contentItem: Label {
                                text: "Cancelar"
                                color: "#374151"
                                font.bold: true
                                font.pixelSize: fontBaseSize
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                            
                            onClicked: {
                                showConfirmDeleteDialog = false
                                deleteIndex = -1
                            }
                            
                            HoverHandler {
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                        
                        Button {
                            Layout.preferredWidth: 120
                            Layout.preferredHeight: 45
                            
                            background: Rectangle {
                                color: parent.pressed ? "#dc2626" : 
                                    (parent.hovered ? "#ef4444" : "#f87171")
                                radius: baseUnit * 0.6
                                border.width: 0
                            }
                            
                            contentItem: Label {
                                text: "Eliminar"
                                color: whiteColor
                                font.bold: true
                                font.pixelSize: fontBaseSize
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                            
                            onClicked: {
                                if (deleteIndex >= 0 && deleteIndex < ingresosModel.count) {
                                    console.log("Eliminando ingreso ID:", ingresosModel.get(deleteIndex).id_registro)
                                    ingresosModel.remove(deleteIndex)
                                    updatePaginatedModel()
                                    
                                    if (ingresosPaginadosModel.count === 0 && currentPage > 0) {
                                        currentPage--
                                        updatePaginatedModel()
                                    }
                                }
                                
                                showConfirmDeleteDialog = false
                                deleteIndex = -1
                                selectedRowIndex = -1
                            }
                            
                            HoverHandler {
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }
                }
            }
        }
    }
}