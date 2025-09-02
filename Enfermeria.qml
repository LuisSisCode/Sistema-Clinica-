import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

Item {
    id: enfermeriaRoot
    objectName: "enfermeriaRoot"
    
    // ===============================
    // 1. SECCIÓN DE PROPIEDADES
    // ===============================
    
    // PROPIEDADES BÁSICAS
    property var enfermeriaModel: null
    
    // PROPIEDADES DE ESTILO ADAPTATIVO
    readonly property real baseUnit: parent.baseUnit || Math.max(8, Screen.height / 100)
    readonly property real fontBaseSize: parent.fontBaseSize || Math.max(12, Screen.height / 70)
    readonly property real scaleFactor: parent.scaleFactor || Math.min(width / 1400, height / 900)
    readonly property real iconSize: Math.max(baseUnit * 3, 24)
    readonly property real buttonIconSize: Math.max(baseUnit * 2, 18)
    
    // PROPIEDADES DE COLOR
    readonly property color primaryColor: "#e91e63"
    readonly property color primaryColorHover: "#d81b60"
    readonly property color primaryColorPressed: "#c2185b"
    readonly property color successColor: "#27ae60"
    readonly property color successColorLight: "#D1FAE5"
    readonly property color dangerColor: "#E74C3C"
    readonly property color dangerColorLight: "#FEE2E2"
    readonly property color warningColor: "#f39c12"
    readonly property color warningColorLight: "#FEF3C7"
    readonly property color lightGrayColor: "#F8F9FA"
    readonly property color textColor: "#2c3e50"
    readonly property color textColorLight: "#6B7280"
    readonly property color whiteColor: "#FFFFFF"
    readonly property color borderColor: "#E5E7EB"
    readonly property color accentColor: "#10B981"
    readonly property color lineColor: "#D1D5DB"
    
    // DISTRIBUCIÓN DE COLUMNAS
    readonly property real colId: 0.05
    readonly property real colPaciente: 0.18
    readonly property real colProcedimiento: 0.16
    readonly property real colCantidad: 0.07
    readonly property real colTipo: 0.09
    readonly property real colPrecio: 0.10
    readonly property real colTotal: 0.10
    readonly property real colFecha: 0.10
    readonly property real colTrabajador: 0.15
    
    // PROPIEDADES DE PAGINACIÓN
    property int itemsPerPageEnfermeria: calcularElementosPorPagina()
    property int currentPageEnfermeria: 0
    property int totalPagesEnfermeria: 0
    
    // PROPIEDADES DEL FORMULARIO
    property bool showNewProcedureDialog: false
    property bool isEditMode: false
    property int editingIndex: -1
    property int selectedRowIndex: -1
    
    // PROPIEDADES DE FILTROS
    property var filtrosActivos: ({
        "busqueda": "",
        "tipo_procedimiento": "",
        "tipo": "",
        "fecha_desde": "",
        "fecha_hasta": ""
    })
    
    // DATOS DEL MODELO
    property var trabajadoresDisponibles: enfermeriaModel ? enfermeriaModel.trabajadoresEnfermeria : []
    property var tiposProcedimientos: enfermeriaModel ? enfermeriaModel.tiposProcedimientos : []
    
    // ===============================
    // 2. SECCIÓN DE CONEXIONES
    // ===============================
    
    Connections {
        target: appController
        function onModelsReady() {
            console.log("Modelos listos, conectando EnfermeriaModel...")
            conectarModelo()
        }
    }
    
    Connections {
        target: enfermeriaModel
        enabled: enfermeriaModel !== null
        
        function onProcedimientoCreado(datosJson) {
            console.log("Procedimiento creado:", datosJson)
            showNewProcedureDialog = false
            selectedRowIndex = -1
            isEditMode = false  // Resetear modo
            editingIndex = -1   // Resetear índice
            cargarPagina()
        }
        
        // NUEVA CONEXIÓN PARA ACTUALIZACIÓN
        function onProcedimientoActualizado(datosJson) {
            console.log("Procedimiento actualizado:", datosJson)
            showNewProcedureDialog = false
            selectedRowIndex = -1
            isEditMode = false  // Resetear modo
            editingIndex = -1   // Resetear índice
            cargarPagina()
        }
        
        function onProcedimientoEliminado(procedimientoId) {
            console.log("Procedimiento eliminado:", procedimientoId)
            selectedRowIndex = -1
            cargarPagina()
        }
        
        function onPacienteEncontradoPorCedula(pacienteData) {
            console.log("Paciente encontrado:", pacienteData.nombreCompleto)
            autocompletarDatosPaciente(pacienteData)
        }
        
        function onPacienteNoEncontrado(cedula) {
            console.log("Paciente no encontrado:", cedula)
            marcarPacienteNoEncontrado(cedula)
        }
        
        function onEstadoCambiado(nuevoEstado) {
            console.log("Estado enfermería:", nuevoEstado)
        }
        
        function onErrorOcurrido(mensaje, codigo) {
            console.log("Error enfermería:", mensaje)
            showNotification("Error", mensaje)
        }
        
        function onOperacionExitosa(mensaje) {
            console.log("Éxito enfermería:", mensaje)
            showNotification("Éxito", mensaje)
        }
    }
    // ===============================
    // 3. SECCIÓN DE MODELOS
    // ===============================
    
    ListModel {
        id: procedimientosPaginadosModel
    }
    
    // ===============================
    // 4. LAYOUT PRINCIPAL
    // ===============================
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: baseUnit * 4
        spacing: baseUnit * 3
        
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
                                color: "transparent"
                                
                                Image {
                                    anchors.centerIn: parent
                                    width: Math.min(baseUnit * 8, parent.width * 0.8)
                                    height: Math.min(baseUnit * 8, parent.height * 0.8)
                                    source: "Resources/iconos/Enfermeria.png"
                                    fillMode: Image.PreserveAspectFit
                                    antialiasing: true
                                }
                            }
                            
                            Label {
                                Layout.alignment: Qt.AlignVCenter
                                text: "Registro de Procedimientos de Enfermería"
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
                            id: newProcedureBtn
                            Layout.preferredHeight: baseUnit * 5
                            Layout.preferredWidth: Math.max(baseUnit * 20, implicitWidth + baseUnit * 2)
                            Layout.alignment: Qt.AlignVCenter
                            
                            background: Rectangle {
                                color: newProcedureBtn.pressed ? primaryColorPressed : 
                                    newProcedureBtn.hovered ? primaryColorHover : primaryColor
                                radius: baseUnit * 1.2
                                
                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                            
                            contentItem: RowLayout {
                                spacing: baseUnit
                                
                                Rectangle {
                                    Layout.preferredWidth: baseUnit * 3
                                    Layout.preferredHeight: baseUnit * 3
                                    color: "transparent"
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "+"
                                        color: whiteColor
                                        font.pixelSize: fontBaseSize * 1.5
                                        font.bold: true
                                    }
                                }
                                
                                Label {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: "Nuevo Procedimiento"
                                    color: whiteColor
                                    font.bold: true
                                    font.pixelSize: fontBaseSize
                                    font.family: "Segoe UI, Arial, sans-serif"
                                }
                            }
                            
                            onClicked: {
                                isEditMode = false
                                editingIndex = -1
                                showNewProcedureDialog = true
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
                    Layout.preferredHeight: width < 1000 ? baseUnit * 16 : baseUnit * 8
                    color: "transparent"
                    z: 10
                    
                    GridLayout {
                        anchors.fill: parent
                        anchors.margins: baseUnit * 3
                        anchors.bottomMargin: baseUnit * 1.5
                        
                        columns: width < 1000 ? 2 : 5
                        rowSpacing: baseUnit
                        columnSpacing: baseUnit * 2
                        
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
                                Layout.preferredWidth: Math.max(120, width * 0.15)
                                Layout.preferredHeight: baseUnit * 4
                                model: ["Todas", "Hoy", "Esta Semana", "Este Mes"]
                                currentIndex: 0
                                onCurrentIndexChanged: aplicarFiltros()
                                
                                contentItem: Label {
                                    text: filtroFecha.displayText
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
                                text: "Procedimiento:"
                                font.bold: true
                                color: textColor
                                font.pixelSize: fontBaseSize * 0.9
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                            
                            ComboBox {
                                id: filtroProcedimiento
                                Layout.fillWidth: true
                                Layout.preferredHeight: baseUnit * 4
                                model: {
                                    var modelData = ["Todos"]
                                    if (enfermeriaModel && enfermeriaModel.tiposProcedimientos) {
                                        for (var i = 0; i < enfermeriaModel.tiposProcedimientos.length; i++) {
                                            var nombre = enfermeriaModel.tiposProcedimientos[i].nombre || ""
                                            if (nombre) modelData.push(nombre)
                                        }
                                    }
                                    return modelData
                                }
                                currentIndex: 0
                                onCurrentIndexChanged: aplicarFiltros()
                                
                                contentItem: Label {
                                    text: filtroProcedimiento.displayText
                                    font.pixelSize: fontBaseSize * 0.8
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    color: textColor
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: baseUnit
                                    elide: Text.ElideRight
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
                                Layout.preferredWidth: Math.max(100, width * 0.12)
                                Layout.preferredHeight: baseUnit * 4
                                model: ["Todos", "Normal", "Emergencia"]
                                currentIndex: 0
                                onCurrentIndexChanged: aplicarFiltros()
                                
                                contentItem: Label {
                                    text: filtroTipo.displayText
                                    font.pixelSize: fontBaseSize * 0.8
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    color: textColor
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: baseUnit
                                }
                            }
                        }
                        
                        TextField {
                            id: campoBusqueda
                            Layout.fillWidth: true
                            Layout.preferredHeight: baseUnit * 4
                            placeholderText: "Buscar por paciente o cédula..."
                            onTextChanged: aplicarFiltros()
                            
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
                        
                        Button {
                            id: limpiarFiltrosBtn
                            text: "Limpiar Filtros"
                            Layout.preferredHeight: baseUnit * 4
                            Layout.fillWidth: true
                            
                            background: Rectangle {
                                color: limpiarFiltrosBtn.pressed ? "#E5E7EB" : 
                                    limpiarFiltrosBtn.hovered ? "#D1D5DB" : "#F3F4F6"
                                border.color: "#D1D5DB"
                                border.width: 1
                                radius: baseUnit * 0.8
                            }
                            
                            contentItem: Label {
                                text: limpiarFiltrosBtn.text
                                color: "#374151"
                                font.pixelSize: fontBaseSize * 0.9
                                font.family: "Segoe UI, Arial, sans-serif"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: limpiarFiltros()
                            
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
                    Layout.margins: baseUnit * 3
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
                                    Layout.preferredWidth: parent.width * colId
                                    Layout.fillHeight: true
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "ID"
                                        font.bold: true
                                        font.pixelSize: fontBaseSize * 0.85
                                        font.family: "Segoe UI, Arial, sans-serif"
                                        color: textColor
                                    }
                                    
                                    Rectangle {
                                        anchors.right: parent.right
                                        width: 1
                                        height: parent.height
                                        color: lineColor
                                    }
                                }
                                
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
                                    }
                                    
                                    Rectangle {
                                        anchors.right: parent.right
                                        width: 1
                                        height: parent.height
                                        color: lineColor
                                    }
                                }
                                
                                Item {
                                    Layout.preferredWidth: parent.width * colProcedimiento
                                    Layout.fillHeight: true
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "PROCEDIMIENTO"
                                        font.bold: true
                                        font.pixelSize: fontBaseSize * 0.85
                                        font.family: "Segoe UI, Arial, sans-serif"
                                        color: textColor
                                    }
                                    
                                    Rectangle {
                                        anchors.right: parent.right
                                        width: 1
                                        height: parent.height
                                        color: lineColor
                                    }
                                }
                                
                                Item {
                                    Layout.preferredWidth: parent.width * colCantidad
                                    Layout.fillHeight: true
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "CANT."
                                        font.bold: true
                                        font.pixelSize: fontBaseSize * 0.85
                                        font.family: "Segoe UI, Arial, sans-serif"
                                        color: textColor
                                    }
                                    
                                    Rectangle {
                                        anchors.right: parent.right
                                        width: 1
                                        height: parent.height
                                        color: lineColor
                                    }
                                }
                                
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
                                    }
                                    
                                    Rectangle {
                                        anchors.right: parent.right
                                        width: 1
                                        height: parent.height
                                        color: lineColor
                                    }
                                }
                                
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
                                    }
                                    
                                    Rectangle {
                                        anchors.right: parent.right
                                        width: 1
                                        height: parent.height
                                        color: lineColor
                                    }
                                }
                                
                                Item {
                                    Layout.preferredWidth: parent.width * colTotal
                                    Layout.fillHeight: true
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "TOTAL"
                                        font.bold: true
                                        font.pixelSize: fontBaseSize * 0.85
                                        font.family: "Segoe UI, Arial, sans-serif"
                                        color: textColor
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
                                    }
                                    
                                    Rectangle {
                                        anchors.right: parent.right
                                        width: 1
                                        height: parent.height
                                        color: lineColor
                                    }
                                }
                                
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
                                    }
                                }
                            }
                        }
                        
                        // CONTENIDO DE LA TABLA
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            
                            ListView {
                                id: procedimientosListView
                                model: procedimientosPaginadosModel
                                
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
                                    
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: baseUnit * 0.4
                                        color: selectedRowIndex === index ? accentColor : "transparent"
                                        radius: baseUnit * 0.2
                                        visible: selectedRowIndex === index
                                    }
                                    
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: baseUnit * 1.5
                                        anchors.rightMargin: baseUnit * 1.5
                                        spacing: 0
                                        
                                        Item {
                                            Layout.preferredWidth: parent.width * colId
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                text: model.procedimientoId
                                                color: textColor
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
                                            Layout.preferredWidth: parent.width * colPaciente
                                            Layout.fillHeight: true
                                            
                                            Column {
                                                anchors.fill: parent
                                                anchors.margins: baseUnit * 0.5
                                                
                                                Label {
                                                    width: parent.width - baseUnit
                                                    text: model.paciente
                                                    color: textColor
                                                    font.pixelSize: fontBaseSize * 0.85
                                                    font.family: "Segoe UI, Arial, sans-serif"
                                                    elide: Text.ElideRight
                                                }
                                                
                                                Label {
                                                    width: parent.width - baseUnit
                                                    text: model.cedula ? "C.I: " + model.cedula : ""
                                                    color: textColorLight
                                                    font.pixelSize: fontBaseSize * 0.75
                                                    font.family: "Segoe UI, Arial, sans-serif"
                                                    elide: Text.ElideRight
                                                    visible: model.cedula !== ""
                                                }
                                            }
                                            
                                            Rectangle {
                                                anchors.right: parent.right
                                                width: 1
                                                height: parent.height
                                                color: lineColor
                                            }
                                        }
                                        
                                        Item {
                                            Layout.preferredWidth: parent.width * colProcedimiento
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                anchors.rightMargin: baseUnit
                                                text: model.tipoProcedimiento
                                                color: primaryColor
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
                                            Layout.preferredWidth: parent.width * colCantidad
                                            Layout.fillHeight: true
                                            
                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: baseUnit * 2.5
                                                height: baseUnit * 2.5
                                                color: model.cantidad > 1 ? warningColor : successColor
                                                radius: height / 2
                                                
                                                Label {
                                                    anchors.centerIn: parent
                                                    text: model.cantidad
                                                    color: whiteColor
                                                    font.pixelSize: fontBaseSize * 0.75
                                                    font.bold: true
                                                    font.family: "Segoe UI, Arial, sans-serif"
                                                }
                                            }
                                            
                                            Rectangle {
                                                anchors.right: parent.right
                                                width: 1
                                                height: parent.height
                                                color: lineColor
                                            }
                                        }
                                        
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
                                                    font.family: "Segoe UI, Arial, sans-serif"
                                                }
                                            }
                                            
                                            Rectangle {
                                                anchors.right: parent.right
                                                width: 1
                                                height: parent.height
                                                color: lineColor
                                            }
                                        }
                                        
                                        Item {
                                            Layout.preferredWidth: parent.width * colPrecio
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                text: "Bs " + model.precioUnitario
                                                color: model.tipo === "Emergencia" ? "#92400E" : "#047857"
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
                                            Layout.preferredWidth: parent.width * colTotal
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                text: "Bs " + model.precioTotal
                                                color: model.tipo === "Emergencia" ? "#92400E" : "#047857"
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
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                text: model.fecha
                                                color: textColor
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
                                            Layout.preferredWidth: parent.width * colTrabajador
                                            Layout.fillHeight: true
                                            
                                            Column {
                                                anchors.fill: parent
                                                anchors.margins: baseUnit * 0.5
                                                
                                                Label {
                                                    width: parent.width
                                                    text: model.trabajadorRealizador
                                                    color: textColor
                                                    font.pixelSize: fontBaseSize * 0.85
                                                    font.family: "Segoe UI, Arial, sans-serif"
                                                    elide: Text.ElideRight
                                                }
                                                
                                                Label {
                                                    width: parent.width
                                                    text: "Por: " + (model.registradoPor || "Sistema")
                                                    color: textColorLight
                                                    font.pixelSize: fontBaseSize * 0.75
                                                    font.family: "Segoe UI, Arial, sans-serif"
                                                    elide: Text.ElideRight
                                                }
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
                                                color: "transparent"
                                            }
                                            
                                            Label {
                                                anchors.centerIn: parent
                                                text: "✏️"
                                                font.pixelSize: fontBaseSize * 1.2
                                            }
                                            
                                            onClicked: editarProcedimiento(index)
                                        }

                                        Button {
                                            width: baseUnit * 3.5
                                            height: baseUnit * 3.5
                                            
                                            background: Rectangle {
                                                color: "transparent"
                                            }
                                            
                                            Label {
                                                anchors.centerIn: parent
                                                text: "🗑️"
                                                font.pixelSize: fontBaseSize * 1.2
                                            }
                                            
                                            onClicked: eliminarProcedimiento(model.procedimientoId)
                                        }
                                    }
                                }
                            }
                        }
                        
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: procedimientosPaginadosModel.count === 0
                            spacing: baseUnit * 3
                            
                            Item { Layout.fillHeight: true }
                            
                            ColumnLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: baseUnit * 2
                                
                                Label {
                                    text: "🩹"
                                    font.pixelSize: fontBaseSize * 3
                                    color: "#E5E7EB"
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                
                                Label {
                                    text: "No hay procedimientos registrados"
                                    color: textColor
                                    font.bold: true
                                    font.pixelSize: fontBaseSize * 1.5
                                    Layout.alignment: Qt.AlignHCenter
                                    font.family: "Segoe UI, Arial, sans-serif"
                                }
                                
                                Label {
                                    text: "Registra el primer procedimiento haciendo clic en \"Nuevo Procedimiento\""
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
                    Layout.margins: baseUnit * 3
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
                            enabled: currentPageEnfermeria > 0
                            
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
                            
                            onClicked: cambiarPagina(currentPageEnfermeria - 1)
                        }

                        Label {
                            text: "Página " + (currentPageEnfermeria + 1) + " de " + Math.max(1, totalPagesEnfermeria)
                            color: textColor
                            font.pixelSize: fontBaseSize * 0.9
                            font.family: "Segoe UI, Arial, sans-serif"
                            font.weight: Font.Medium
                        }

                        Button {
                            Layout.preferredWidth: baseUnit * 11
                            Layout.preferredHeight: baseUnit * 4
                            text: "Siguiente →"
                            enabled: currentPageEnfermeria < totalPagesEnfermeria - 1
                            
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
                            
                            onClicked: cambiarPagina(currentPageEnfermeria + 1)
                        }
                    }
                }
            }
        }
    }

    // ===============================
    // 5. FORMULARIO DE NUEVO PROCEDIMIENTO
    // ===============================

    Rectangle {
        id: newProcedureDialog
        anchors.fill: parent
        color: "black"
        opacity: showNewProcedureDialog ? 0.5 : 0
        visible: opacity > 0
        
        MouseArea {
            anchors.fill: parent
            onClicked: {
                showNewProcedureDialog = false
                selectedRowIndex = -1
            }
        }
        
        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }
    }

    Rectangle {
        id: procedureForm
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.95, 700)
        height: Math.min(parent.height * 0.95, 800)
        color: whiteColor
        radius: baseUnit * 1.5
        border.color: "#DDD"
        border.width: 1
        visible: showNewProcedureDialog

        Rectangle {
            anchors.fill: parent
            anchors.margins: -baseUnit
            color: "transparent"
            radius: parent.radius + baseUnit
            border.color: "#20000000"
            border.width: baseUnit
            z: -1
        }
        property var procedimientoParaEditar: null
        property int selectedProcedureIndex: -1
        property string procedureType: "Normal"
        property real calculatedUnitPrice: 0.0
        property real calculatedTotalPrice: 0.0
        
        function updatePrices() {
            if (procedureForm.selectedProcedureIndex >= 0 && tiposProcedimientos.length > 0) {
                var procedimiento = tiposProcedimientos[procedureForm.selectedProcedureIndex]
                
                var precioUnitario = 0
                if (procedureForm.procedureType === "Emergencia") {
                    precioUnitario = procedimiento.precioEmergencia || 0
                } else {
                    precioUnitario = procedimiento.precioNormal || 0
                }
                
                var cantidadActual = cantidadSpinBox.value || 1
                var precioTotal = precioUnitario * cantidadActual
                
                procedureForm.calculatedUnitPrice = precioUnitario
                procedureForm.calculatedTotalPrice = precioTotal
            } else {
                procedureForm.calculatedUnitPrice = 0.0
                procedureForm.calculatedTotalPrice = 0.0
            }
        }
        
        onVisibleChanged: {
            if (visible) {
                if (isEditMode && procedureForm.procedimientoParaEditar) {
                    loadEditData()  // Cargar datos para edición
                } else if (!isEditMode) {
                    // Limpiar formulario para nuevo procedimiento
                    nombrePaciente.text = ""
                    apellidoPaterno.text = ""
                    apellidoMaterno.text = ""
                    cedulaPaciente.text = "" 
                    procedimientoCombo.currentIndex = 0
                    trabajadorCombo.currentIndex = 0
                    normalRadio.checked = true
                    cantidadSpinBox.value = 1
                    observacionesProcedimiento.text = ""
                    procedureForm.selectedProcedureIndex = -1
                    procedureForm.calculatedUnitPrice = 0.0
                    procedureForm.calculatedTotalPrice = 0.0
                    procedureForm.procedimientoParaEditar = null
                }
            }
        }
        function loadEditData() {
            if (!isEditMode || !procedureForm.procedimientoParaEditar) {
                console.log("No hay datos para cargar en edición")
                return
            }
            
            var proc = procedureForm.procedimientoParaEditar
            console.log("Cargando datos para edición:", JSON.stringify(proc))
            
            // Cargar datos del paciente
            cedulaPaciente.text = proc.cedula || ""
            if (cedulaPaciente.text.length >= 5) {
                buscarPacientePorCedula(cedulaPaciente.text)
            }
            
            // Cargar procedimiento
            if (proc.tipoProcedimiento && tiposProcedimientos) {
                for (var i = 0; i < tiposProcedimientos.length; i++) {
                    if (tiposProcedimientos[i].nombre === proc.tipoProcedimiento) {
                        procedimientoCombo.currentIndex = i + 1
                        procedureForm.selectedProcedureIndex = i
                        break
                    }
                }
            }
            
            // Cargar trabajador
            if (proc.trabajadorRealizador && trabajadoresDisponibles) {
                for (var j = 0; j < trabajadoresDisponibles.length; j++) {
                    if (trabajadoresDisponibles[j] === proc.trabajadorRealizador) {
                        trabajadorCombo.currentIndex = j + 1
                        break
                    }
                }
            }
            
            // Cargar tipo
            if (proc.tipo === "Normal") {
                normalRadio.checked = true
                emergenciaRadio.checked = false
                procedureForm.procedureType = "Normal"
            } else {
                normalRadio.checked = false
                emergenciaRadio.checked = true
                procedureForm.procedureType = "Emergencia"
            }
            
            // Cargar cantidad
            cantidadSpinBox.value = parseInt(proc.cantidad) || 1
            
            // Actualizar precios
            procedureForm.calculatedUnitPrice = parseFloat(proc.precioUnitario) || 0.0
            procedureForm.calculatedTotalPrice = parseFloat(proc.precioTotal) || 0.0
            
            console.log("Datos de edición cargados correctamente")
        }
        
        Rectangle {
            id: dialogHeader
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: baseUnit * 7
            color: primaryColor
            radius: baseUnit * 1.5
            
            Label {
                anchors.centerIn: parent
                text: isEditMode ? "EDITAR PROCEDIMIENTO" : "NUEVO PROCEDIMIENTO"
                font.pixelSize: fontBaseSize * 1.2
                font.bold: true
                color: whiteColor
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
                
                onClicked: cancelarFormulario()  // Usar función mejorada
            }
        }
        ScrollView {
            id: scrollView
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
                width: scrollView.width - (baseUnit * 1)
                spacing: baseUnit * 2
                
                GroupBox {
                    Layout.fillWidth: true
                    title: "DATOS DEL PACIENTE"
                    font.bold: true
                    font.pixelSize: fontBaseSize
                    padding: baseUnit * 1.5
                    
                    background: Rectangle {
                        color: "#f8f9fa"
                        border.color: "#e0e0e0"
                        radius: baseUnit * 0.8
                    }
                    
                    GridLayout {
                        width: parent.width
                        columns: 2
                        columnSpacing: baseUnit * 2
                        rowSpacing: baseUnit * 1.5
                        
                        Label {
                            text: "Cédula:"
                            font.bold: true
                            color: textColor
                        }
                        
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit
                            
                            TextField {
                                id: cedulaPaciente
                                Layout.preferredWidth: baseUnit * 25 
                                placeholderText: "Ej: 12345678 LP"
                                font.pixelSize: fontBaseSize
                                validator: RegularExpressionValidator { 
                                    regularExpression: /^[0-9]{1,12}(\s*[A-Z]{0,3})?$/
                                }
                                maximumLength: 15
                                
                                property bool pacienteAutocompletado: false
                                property bool pacienteNoEncontrado: false
                                property bool buscandoPaciente: false
                                
                                background: Rectangle {
                                    color: {
                                        if (cedulaPaciente.pacienteAutocompletado) return "#F0F8FF"
                                        if (cedulaPaciente.pacienteNoEncontrado) return "#FEF3C7"
                                        if (cedulaPaciente.buscandoPaciente) return "#F3F4F6"
                                        return whiteColor
                                    }
                                    border.color: cedulaPaciente.activeFocus ? primaryColor : borderColor
                                    border.width: cedulaPaciente.activeFocus ? 2 : 1
                                    radius: baseUnit * 0.6
                                    
                                    Row {
                                        anchors.right: parent.right
                                        anchors.rightMargin: baseUnit
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: baseUnit * 0.5
                                        
                                        Text {
                                            text: {
                                                if (cedulaPaciente.buscandoPaciente) return "🔄"
                                                if (cedulaPaciente.pacienteAutocompletado) return "✅"
                                                if (cedulaPaciente.pacienteNoEncontrado) return "⚠️"
                                                return cedulaPaciente.text.length >= 5 ? "🔍" : "🔒"
                                            }
                                            font.pixelSize: fontBaseSize
                                            visible: cedulaPaciente.text.length > 0
                                        }
                                        
                                        Button {
                                            width: baseUnit * 2
                                            height: baseUnit * 2
                                            visible: cedulaPaciente.text.length > 0
                                            
                                            background: Rectangle {
                                                color: "transparent"
                                                radius: width / 2
                                            }
                                            
                                            contentItem: Text {
                                                text: "×"
                                                color: "#666"
                                                font.pixelSize: fontBaseSize
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            
                                            onClicked: limpiarDatosPaciente()
                                        }
                                    }
                                }
                                
                                onTextChanged: {
                                    if (text.length >= 5 && !pacienteAutocompletado) {
                                        pacienteNoEncontrado = false
                                        buscandoPaciente = true
                                        buscarTimer.restart()
                                    } else if (text.length === 0) {
                                        limpiarDatosPaciente()
                                    }
                                }
                                
                                Keys.onReturnPressed: {
                                    if (cedulaPaciente.text.length >= 5) {
                                        buscarPacientePorCedula(cedulaPaciente.text)
                                    }
                                }
                                
                                padding: baseUnit
                            }

                            Timer {
                                id: buscarTimer
                                interval: 600
                                running: false
                                repeat: false
                                onTriggered: buscarPacientePorCedula(cedulaPaciente.text.trim())
                            }
                        }
                        
                        Label {
                            text: "Nombre:"
                            font.bold: true
                            color: textColor
                        }
                        
                        TextField {
                            id: nombrePaciente
                            Layout.fillWidth: true
                            placeholderText: "Nombre del paciente"
                            font.pixelSize: fontBaseSize
                            background: Rectangle {
                                color: whiteColor
                                border.color: "#ddd"
                                border.width: 1
                                radius: baseUnit * 0.5
                            }
                            padding: baseUnit
                        }
                        
                        Label {
                            text: "Apellido Paterno:"
                            font.bold: true
                            color: textColor
                        }
                        
                        TextField {
                            id: apellidoPaterno
                            Layout.fillWidth: true
                            placeholderText: "Apellido paterno"
                            font.pixelSize: fontBaseSize
                            background: Rectangle {
                                color: whiteColor
                                border.color: "#ddd"
                                border.width: 1
                                radius: baseUnit * 0.5
                            }
                            padding: baseUnit
                        }
                        
                        Label {
                            text: "Apellido Materno:"
                            font.bold: true
                            color: textColor
                        }
                        
                        TextField {
                            id: apellidoMaterno
                            Layout.fillWidth: true
                            placeholderText: "Apellido materno"
                            font.pixelSize: fontBaseSize
                            background: Rectangle {
                                color: whiteColor
                                border.color: "#ddd"
                                border.width: 1
                                radius: baseUnit * 0.5
                            }
                            padding: baseUnit
                        }
                    }
                }
                
                GroupBox {
                    Layout.fillWidth: true
                    title: "INFORMACIÓN DEL PROCEDIMIENTO"
                    font.bold: true
                    font.pixelSize: fontBaseSize
                    padding: baseUnit * 1.5
                    
                    background: Rectangle {
                        color: "#f8f9fa"
                        border.color: "#e0e0e0"
                        radius: baseUnit * 0.8
                    }
                    
                    ColumnLayout {
                        width: parent.width
                        spacing: baseUnit * 2
                        
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit * 2
                            
                            Label {
                                text: "Procedimiento:"
                                font.bold: true
                                Layout.preferredWidth: baseUnit * 15
                                color: textColor
                            }
                            
                            ComboBox {
                                id: procedimientoCombo
                                Layout.fillWidth: true
                                font.pixelSize: fontBaseSize
                                model: {
                                    var list = ["Seleccionar procedimiento..."]
                                    for (var i = 0; i < tiposProcedimientos.length; i++) {
                                        list.push(tiposProcedimientos[i].nombre)
                                    }
                                    return list
                                }
                                onCurrentIndexChanged: {
                                    if (currentIndex > 0) {
                                        procedureForm.selectedProcedureIndex = currentIndex - 1
                                        descripcionProcedimiento.text = tiposProcedimientos[procedureForm.selectedProcedureIndex].descripcion
                                    } else {
                                        procedureForm.selectedProcedureIndex = -1
                                        descripcionProcedimiento.text = ""
                                    }
                                    procedureForm.updatePrices()
                                }
                                
                                background: Rectangle {
                                    color: whiteColor
                                    border.color: "#ddd"
                                    border.width: 1
                                    radius: baseUnit * 0.5
                                }
                            }
                        }
                        
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit * 2
                            visible: descripcionProcedimiento.text !== ""
                            
                            Label {
                                text: "Descripción:"
                                font.bold: true
                                Layout.preferredWidth: baseUnit * 15
                                color: textColor
                            }
                            
                            Label {
                                id: descripcionProcedimiento
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                color: textColorLight
                                font.italic: true
                            }
                        }
                        
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit * 2
                            
                            Label {
                                text: "Realizado por:"
                                font.bold: true
                                Layout.preferredWidth: baseUnit * 15
                                color: textColor
                            }
                            
                            ComboBox {
                                id: trabajadorCombo
                                Layout.fillWidth: true
                                font.pixelSize: fontBaseSize
                                model: {
                                    var modelData = ["Seleccionar trabajador..."]
                                    if (trabajadoresDisponibles && trabajadoresDisponibles.length > 0) {
                                        for (var i = 0; i < trabajadoresDisponibles.length; i++) {
                                            var nombre = typeof trabajadoresDisponibles[i] === 'string' ? 
                                                        trabajadoresDisponibles[i] : 
                                                        (trabajadoresDisponibles[i].nombre || trabajadoresDisponibles[i].text || "")
                                            if (nombre) modelData.push(nombre)
                                        }
                                    }
                                    return modelData
                                }
                                
                                background: Rectangle {
                                    color: whiteColor
                                    border.color: "#ddd"
                                    border.width: 1
                                    radius: baseUnit * 0.5
                                }
                            }
                        }
                        
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit * 2
                            
                            Label {
                                text: "Tipo:"
                                font.bold: true
                                Layout.preferredWidth: baseUnit * 15
                                color: textColor
                            }
                            
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: baseUnit * 3
                                
                                RadioButton {
                                    id: normalRadio
                                    text: "Normal"
                                    font.pixelSize: fontBaseSize
                                    checked: true
                                    onCheckedChanged: {
                                        if (checked) {
                                            procedureForm.procedureType = "Normal"
                                            procedureForm.updatePrices()
                                        }
                                    }
                                }
                                
                                RadioButton {
                                    id: emergenciaRadio
                                    text: "Emergencia"
                                    font.pixelSize: fontBaseSize
                                    onCheckedChanged: {
                                        if (checked) {
                                            procedureForm.procedureType = "Emergencia"
                                            procedureForm.updatePrices()
                                        }
                                    }
                                }
                                
                                Item { Layout.fillWidth: true }
                            }
                        }
                        
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit * 2
                            
                            Label {
                                text: "Cantidad:"
                                font.bold: true
                                Layout.preferredWidth: baseUnit * 15
                                color: textColor
                            }
                            
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: baseUnit
                                
                                SpinBox {
                                    id: cantidadSpinBox
                                    Layout.preferredWidth: baseUnit * 12
                                    Layout.preferredHeight: baseUnit * 4
                                    
                                    from: 1
                                    to: 50
                                    value: 1
                                    stepSize: 1
                                    
                                    textFromValue: function(value, locale) {
                                        return value.toString()
                                    }
                                    
                                    valueFromText: function(text, locale) {
                                        var num = parseInt(text)
                                        return isNaN(num) ? 1 : Math.max(1, Math.min(50, num))
                                    }
                                    
                                    onValueChanged: {
                                        procedureForm.updatePrices()
                                    }
                                    
                                    font.pixelSize: fontBaseSize
                                    font.bold: true
                                    
                                    background: Rectangle {
                                        color: whiteColor
                                        border.color: cantidadSpinBox.activeFocus ? primaryColor : borderColor
                                        border.width: cantidadSpinBox.activeFocus ? 2 : 1
                                        radius: baseUnit * 0.5
                                    }
                                }
                                
                                Label {
                                    text: "procedimiento(s)"
                                    color: textColor
                                    font.pixelSize: fontBaseSize * 0.9
                                }
                                
                                Item { Layout.fillWidth: true }
                            }
                        }
                    }
                }
                
                GroupBox {
                    Layout.fillWidth: true
                    title: "INFORMACIÓN DE PRECIO"
                    font.bold: true
                    font.pixelSize: fontBaseSize
                    padding: baseUnit * 1.5
                    
                    background: Rectangle {
                        color: "#f8f9fa"
                        border.color: "#e0e0e0"
                        radius: baseUnit * 0.8
                    }
                    
                    GridLayout {
                        width: parent.width
                        columns: 2
                        columnSpacing: baseUnit * 2
                        rowSpacing: baseUnit * 1.5
                        
                        Label {
                            text: "Precio Unitario:"
                            font.bold: true
                            color: textColor
                            font.family: "Segoe UI, Arial, sans-serif"
                        }
                        
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: baseUnit * 3
                            color: procedureForm.procedureType === "Emergencia" ? warningColorLight : successColorLight
                            radius: baseUnit * 0.8
                            border.color: procedureForm.procedureType === "Emergencia" ? warningColor : successColor
                            border.width: 1
                            
                            Label {
                                anchors.centerIn: parent
                                text: procedureForm.selectedProcedureIndex >= 0 ? 
                                    "Bs " + procedureForm.calculatedUnitPrice.toFixed(2) : "Seleccione procedimiento"
                                font.bold: true
                                font.pixelSize: fontBaseSize
                                font.family: "Segoe UI, Arial, sans-serif"
                                color: procedureForm.procedureType === "Emergencia" ? "#92400E" : "#047857"
                            }
                        }
                        
                        Label {
                            text: "Cantidad:"
                            font.bold: true
                            color: textColor
                            font.family: "Segoe UI, Arial, sans-serif"
                        }
                        
                        Label {
                            text: (cantidadSpinBox.value || 1) + " procedimiento" + 
                                ((cantidadSpinBox.value || 1) > 1 ? "s" : "")
                            font.bold: true
                            color: textColor
                            font.family: "Segoe UI, Arial, sans-serif"
                        }
                        
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.columnSpan: 2
                            Layout.preferredHeight: 1
                            color: borderColor
                        }
                        
                        Label {
                            text: "Total a Pagar:"
                            font.bold: true
                            font.pixelSize: fontBaseSize * 1.2
                            color: textColor
                            font.family: "Segoe UI, Arial, sans-serif"
                        }
                        
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: baseUnit * 4
                            color: procedureForm.procedureType === "Emergencia" ? warningColorLight : successColorLight
                            radius: baseUnit * 0.8
                            border.color: procedureForm.procedureType === "Emergencia" ? warningColor : successColor
                            border.width: 2
                            
                            Label {
                                anchors.centerIn: parent
                                text: procedureForm.selectedProcedureIndex >= 0 ? 
                                    "Bs " + procedureForm.calculatedTotalPrice.toFixed(2) : "Bs 0.00"
                                font.bold: true
                                font.pixelSize: fontBaseSize * 1.4
                                font.family: "Segoe UI, Arial, sans-serif"
                                color: procedureForm.procedureType === "Emergencia" ? "#92400E" : "#047857"
                            }
                        }
                        
                        Label {
                            Layout.columnSpan: 2
                            Layout.fillWidth: true
                            text: procedureForm.selectedProcedureIndex >= 0 ? 
                                "(" + procedureForm.calculatedUnitPrice.toFixed(2) + " × " + 
                                (cantidadSpinBox.value || 1) + " = " + 
                                procedureForm.calculatedTotalPrice.toFixed(2) + ")" : ""
                            color: textColorLight
                            font.pixelSize: fontBaseSize * 0.8
                            font.family: "Segoe UI, Arial, sans-serif"
                            horizontalAlignment: Text.AlignHCenter
                            visible: procedureForm.selectedProcedureIndex >= 0
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
            height: baseUnit * 5
            
            Button {
                id: cancelButton
                text: "Cancelar"
                Layout.preferredWidth: baseUnit * 15
                Layout.preferredHeight: baseUnit * 4.5
                
                background: Rectangle {
                    color: cancelButton.pressed ? "#e0e0e0" : 
                        (cancelButton.hovered ? "#f0f0f0" : "#f8f9fa")
                    border.color: "#ddd"
                    border.width: 1
                    radius: baseUnit * 0.8
                }
                
                contentItem: Label {
                    text: parent.text
                    font.pixelSize: fontBaseSize
                    font.bold: true
                    color: textColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: cancelarFormulario()  // Usar función mejorada
            }
            
            Button {
                id: saveButton
                text: isEditMode ? "Actualizar Procedimiento" : "Guardar Procedimiento"
                enabled: procedureForm.selectedProcedureIndex >= 0 && 
                        nombrePaciente.text.length >= 2 &&
                        apellidoPaterno.text.length >= 2 &&
                        trabajadorCombo.currentIndex > 0 &&
                        cantidadSpinBox.value > 0 &&
                        cedulaPaciente.text.length >= 5
                
                Layout.preferredWidth: baseUnit * 20
                Layout.preferredHeight: baseUnit * 4.5
                
                background: Rectangle {
                    color: !saveButton.enabled ? "#bdc3c7" : 
                        (saveButton.pressed ? primaryColorPressed : 
                        (saveButton.hovered ? primaryColorHover : primaryColor))
                    radius: baseUnit * 0.8
                }
                
                contentItem: Label {
                    text: parent.text
                    font.pixelSize: fontBaseSize * 0.9
                    font.bold: true
                    color: whiteColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: guardarProcedimiento()
            }
        }
    }

    // ===============================
    // 6. SECCIÓN DE FUNCIONES
    // ===============================
    
    // GRUPO A - INICIALIZACIÓN
    
    Component.onCompleted: {
        console.log("Módulo Enfermería iniciado")
        conectarModelo()
    }
    
    function initializarModelo() {
        console.log("EnfermeriaModel disponible, inicializando datos...")
        
        if (enfermeriaModel) {
            enfermeriaModel.actualizar_procedimientos()
            enfermeriaModel.actualizar_tipos_procedimientos()
            enfermeriaModel.actualizar_trabajadores_enfermeria()
            
            aplicarFiltros()
        }
    }
    
    function conectarModelo() {
        if (typeof appController !== 'undefined' && appController.enfermeria_model_instance) {
            enfermeriaModel = appController.enfermeria_model_instance
            
            if (enfermeriaModel) {
                console.log("EnfermeriaModel conectado exitosamente")
                initializarModelo()
                return true
            }
        }
        return false
    }
    
    // GRUPO B - PAGINACIÓN
    
    function cargarPagina() {
        if (!enfermeriaModel) {
            console.log("EnfermeriaModel no disponible")
            return
        }
        
        console.log("Cargando página", currentPageEnfermeria + 1, "desde repositorio...")
        
        var resultado = enfermeriaModel.obtener_procedimientos_paginados(
            currentPageEnfermeria, 
            itemsPerPageEnfermeria, 
            filtrosActivos
        )
        
        if (resultado && resultado.procedimientos) {
            procedimientosPaginadosModel.clear()
            
            for (var i = 0; i < resultado.procedimientos.length; i++) {
                var proc = resultado.procedimientos[i]
                procedimientosPaginadosModel.append(proc)
            }
            
            totalPagesEnfermeria = resultado.total_pages || 1
            
            console.log("Página cargada: " + (currentPageEnfermeria + 1) + " de " + totalPagesEnfermeria + 
                        " - " + procedimientosPaginadosModel.count + " procedimientos")
        } else {
            console.log("No se recibieron datos del repositorio")
            procedimientosPaginadosModel.clear()
            totalPagesEnfermeria = 1
        }
    }
    
    function cambiarPagina(nuevaPagina) {
        if (nuevaPagina >= 0 && nuevaPagina < totalPagesEnfermeria) {
            currentPageEnfermeria = nuevaPagina
            cargarPagina()
        }
    }
    
    function actualizarPaginacion() {
        itemsPerPageEnfermeria = calcularElementosPorPagina()
        cargarPagina()
    }
    
    onHeightChanged: {
        var nuevosElementos = calcularElementosPorPagina()
        if (nuevosElementos !== itemsPerPageEnfermeria) {
            actualizarPaginacion()
        }
    }
    
    // GRUPO C - FILTROS
    
    function aplicarFiltros() {
        console.log("Aplicando filtros desde repositorio...")
        
        var nuevosFiltros = {
            "busqueda": campoBusqueda.text.trim(),
            "tipo_procedimiento": filtroProcedimiento.currentIndex > 0 ? 
                                filtroProcedimiento.currentText : "",
            "tipo": filtroTipo.currentIndex > 0 ? 
                    filtroTipo.currentText : "",
            "fecha_desde": obtenerFiltroFechaDesde(),
            "fecha_hasta": obtenerFiltroFechaHasta()
        }
        
        filtrosActivos = nuevosFiltros
        currentPageEnfermeria = 0
        cargarPagina()
    }
    
    function limpiarFiltros() {
        console.log("Limpiando todos los filtros...")
        
        filtroFecha.currentIndex = 0
        filtroProcedimiento.currentIndex = 0
        filtroTipo.currentIndex = 0
        campoBusqueda.text = ""
        
        currentPageEnfermeria = 0
        aplicarFiltros()
        
        showNotification("Info", "Filtros restablecidos")
    }
    
    function obtenerFiltroFechaDesde() {
        switch(filtroFecha.currentIndex) {
            case 1: // Hoy
                return new Date().toISOString().split('T')[0]
            case 2: // Esta Semana
                var hoy = new Date()
                var lunes = new Date(hoy)
                lunes.setDate(hoy.getDate() - hoy.getDay() + 1)
                return lunes.toISOString().split('T')[0]
            case 3: // Este Mes
                var hoy = new Date()
                return hoy.getFullYear() + "-" + (hoy.getMonth() + 1).toString().padStart(2, '0') + "-01"
            default:
                return ""
        }
    }
    
    function obtenerFiltroFechaHasta() {
        switch(filtroFecha.currentIndex) {
            case 1: // Hoy
                return new Date().toISOString().split('T')[0]
            case 2: // Esta Semana
                var hoy = new Date()
                var domingo = new Date(hoy)
                domingo.setDate(hoy.getDate() + (7 - hoy.getDay()))
                return domingo.toISOString().split('T')[0]
            case 3: // Este Mes
                var hoy = new Date()
                var ultimoDia = new Date(hoy.getFullYear(), hoy.getMonth() + 1, 0)
                return ultimoDia.toISOString().split('T')[0]
            default:
                return ""
        }
    }
    
    // GRUPO D - BÚSQUEDA DE PACIENTES
    
    function buscarPacientePorCedula(cedula) {
        if (!enfermeriaModel || cedula.length < 5) {
            cedulaPaciente.buscandoPaciente = false
            return
        }
        
        console.log("Búsqueda inteligente de paciente:", cedula)
        
        var pacienteEncontrado = enfermeriaModel.buscar_paciente_por_cedula(cedula)
        
        cedulaPaciente.buscandoPaciente = false
    }
    
    function autocompletarDatosPaciente(paciente) {
        console.log("Autocompletando datos del paciente:", paciente.nombreCompleto)
        
        var nombres = paciente.nombreCompleto.split(" ")
        
        nombrePaciente.text = nombres[0] || ""
        apellidoPaterno.text = nombres[1] || ""
        apellidoMaterno.text = nombres.slice(2).join(" ") || ""
        
        cedulaPaciente.pacienteAutocompletado = true
        cedulaPaciente.pacienteNoEncontrado = false
        cedulaPaciente.buscandoPaciente = false
        
        nombrePaciente.readOnly = true
        apellidoPaterno.readOnly = true
        apellidoMaterno.readOnly = true
        
        showNotification("Éxito", "Paciente encontrado: " + paciente.nombreCompleto)
    }
    
    function marcarPacienteNoEncontrado(cedula) {
        console.log("Paciente no encontrado. Habilitando creación:", cedula)
        
        cedulaPaciente.pacienteNoEncontrado = true
        cedulaPaciente.pacienteAutocompletado = false
        cedulaPaciente.buscandoPaciente = false
        
        nombrePaciente.text = ""
        apellidoPaterno.text = ""
        apellidoMaterno.text = ""
        
        nombrePaciente.readOnly = false
        apellidoPaterno.readOnly = false
        apellidoMaterno.readOnly = false
        
        nombrePaciente.forceActiveFocus()
        
        showNotification("Info", "Paciente no encontrado. Complete los datos para crear nuevo paciente.")
    }
    
    function limpiarDatosPaciente() {
        if (nombrePaciente.text === "" && apellidoPaterno.text === "" && apellidoMaterno.text === "") {
            return
        }
        
        nombrePaciente.text = ""
        apellidoPaterno.text = ""
        apellidoMaterno.text = ""
        
        cedulaPaciente.pacienteAutocompletado = false
        cedulaPaciente.pacienteNoEncontrado = false
        cedulaPaciente.buscandoPaciente = false
        
        nombrePaciente.readOnly = false
        apellidoPaterno.readOnly = false
        apellidoMaterno.readOnly = false
    }
    
    // GRUPO E - OPERACIONES CRUD
    
    function guardarProcedimiento() {
        if (!enfermeriaModel) {
            console.log("ERROR: enfermeriaModel no disponible")
            return
        }
        
        console.log("Iniciando guardado de procedimiento...")
        console.log("Modo edición:", isEditMode)
        
        var trabajadorIdReal = -1
        if (trabajadorCombo.currentIndex > 0) {
            // Los trabajadores en la BD empiezan desde ID 1
            // El combo tiene índice 0 = "Seleccionar...", índice 1 = primer trabajador real
            trabajadorIdReal = trabajadorCombo.currentIndex
        }
        if (trabajadorIdReal <= 0) {
            showNotification("Error", "Debe seleccionar un trabajador válido")
            return
        }

        var datosProcedimiento = {
            paciente: (nombrePaciente.text + " " + apellidoPaterno.text + " " + apellidoMaterno.text).trim(),
            cedula: cedulaPaciente.text.trim(),
            idProcedimiento: procedureForm.selectedProcedureIndex + 1,
            cantidad: cantidadSpinBox.value,
            tipo: procedureForm.procedureType,
            idTrabajador: trabajadorIdReal,
            precioUnitario: procedureForm.calculatedUnitPrice,
            precioTotal: procedureForm.calculatedTotalPrice
        }
        
        console.log("Datos del procedimiento:", JSON.stringify(datosProcedimiento, null, 2))
        
        // LÓGICA SEPARADA: CREAR vs ACTUALIZAR
        if (isEditMode && procedureForm.procedimientoParaEditar) {
            // MODO EDICIÓN - Llamar actualizar_procedimiento
            var procedimientoId = parseInt(procedureForm.procedimientoParaEditar.procedimientoId)
            
            console.log("=== MODO EDICIÓN ===")
            console.log("Actualizando procedimiento ID:", procedimientoId)
            
            var resultado = enfermeriaModel.actualizar_procedimiento(datosProcedimiento, procedimientoId)
            console.log("Resultado actualización:", resultado)
            
        } else {
            // MODO CREACIÓN - Llamar crear_procedimiento
            console.log("=== MODO CREACIÓN ===")
            console.log("Creando nuevo procedimiento")
            
            var resultado = enfermeriaModel.crear_procedimiento(datosProcedimiento)
            console.log("Resultado creación:", resultado)
        }
    }
    
    function editarProcedimiento(index) {
        try {
            console.log("Editando procedimiento en index:", index)
            
            if (index < 0 || index >= procedimientosPaginadosModel.count) {
                console.log("Índice inválido para edición:", index)
                return
            }
            
            // Obtener datos del procedimiento seleccionado
            var procedimiento = procedimientosPaginadosModel.get(index)
            console.log("Cargando datos para edición:", JSON.stringify(procedimiento))
            
            // Crear objeto con datos para edición
            procedureForm.procedimientoParaEditar = {
                procedimientoId: procedimiento.procedimientoId,
                paciente: procedimiento.paciente,
                cedula: procedimiento.cedula,
                tipoProcedimiento: procedimiento.tipoProcedimiento,
                cantidad: procedimiento.cantidad,
                tipo: procedimiento.tipo,
                precioUnitario: procedimiento.precioUnitario,
                precioTotal: procedimiento.precioTotal,
                trabajadorRealizador: procedimiento.trabajadorRealizador,
                fecha: procedimiento.fecha
            }
            
            // Activar modo edición
            isEditMode = true
            editingIndex = index
            
            // Abrir el diálogo
            showNewProcedureDialog = true
            
            console.log("Modo edición activado para procedimiento ID:", procedimiento.procedimientoId)
            
        } catch (error) {
            console.log("Error al iniciar edición:", error)
            showNotification("Error", "No se pudo cargar el procedimiento para editar")
        }
    }
    
    function eliminarProcedimiento(procedimientoId) {
        var intId = parseInt(procedimientoId)
        enfermeriaModel.eliminar_procedimiento(intId)
        selectedRowIndex = -1
    }
    
    // GRUPO F - AUXILIARES
    
    function showNotification(tipo, mensaje) {
        if (typeof appController !== 'undefined' && appController.showNotification) {
            appController.showNotification(tipo, mensaje)
        } else {
            console.log(`${tipo}: ${mensaje}`)
        }
    }
    
    function calcularElementosPorPagina() {
        var alturaDisponible = height - baseUnit * 25
        var alturaFila = baseUnit * 7
        var elementosCalculados = Math.floor(alturaDisponible / alturaFila)
        
        return Math.max(6, Math.min(elementosCalculados, 15))
    }
    function cancelarFormulario() {
        showNewProcedureDialog = false
        selectedRowIndex = -1
        isEditMode = false
        editingIndex = -1
        procedureForm.procedimientoParaEditar = null
    }
}