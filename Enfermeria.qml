import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

Item {
    id: enfermeriaRoot
    objectName: "enfermeriaRoot"
    // ✅ ACCESO AL MODELO DE BACKEND
    property var enfermeriaModel: null
    // ✅ SISTEMA DE ESTILOS ADAPTABLES INTEGRADO
    // ACCESO A PROPIEDADES ADAPTATIVAS DEL MAIN (COMO EN CONSULTAS)
    readonly property real baseUnit: parent.baseUnit || Math.max(8, Screen.height / 100)
    readonly property real fontBaseSize: parent.fontBaseSize || Math.max(12, Screen.height / 70)
    readonly property real scaleFactor: parent.scaleFactor || Math.min(width / 1400, height / 900)
    
    // PROPIEDADES DE TAMAÑO MEJORADAS (COMO EN CONSULTAS)
    readonly property real iconSize: Math.max(baseUnit * 3, 24)
    readonly property real buttonIconSize: Math.max(baseUnit * 2, 18)

    // PROPIEDADES DE COLOR MEJORADAS (COMO EN CONSULTAS)
    readonly property color primaryColor: "#e91e63"  // Rosa para enfermería
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

    // Distribución de columnas responsive (COMO EN CONSULTAS PERO PARA ENFERMERÍA)
    readonly property real colId: 0.05
    readonly property real colPaciente: 0.18
    readonly property real colProcedimiento: 0.16
    readonly property real colCantidad: 0.07
    readonly property real colTipo: 0.09
    readonly property real colPrecio: 0.10
    readonly property real colTotal: 0.10
    readonly property real colFecha: 0.10
    readonly property real colTrabajador: 0.15


    
    // Usuario actual del sistema (simulado - en producción vendría del login)
    readonly property string currentUser: "Enfermera Ana María González"
    readonly property string currentUserRole: "Enfermera Jefe"
    
    // ✅ SEÑAL PARA NAVEGACIÓN A CONFIGURACIÓN (REFACTORIZADO)
    signal irAConfigEnfermeria()
    
    // Propiedades para los diálogos del procedimiento
    property bool isEditMode: false
    property int editingIndex: -1
    property int selectedRowIndex: -1
    property bool showNewProcedureDialog: false

    // ✅ PROPIEDADES DE PAGINACIÓN CORREGIDAS
    property int itemsPerPageEnfermeria: calcularElementosPorPagina()
    property int currentPageEnfermeria: 0
    property int totalPagesEnfermeria: 0

    // ✅ NUEVA PROPIEDAD PARA DATOS ORIGINALES
    property var procedimientosOriginales: []

    // ✅ DATOS DESDE EL BACKEND
    property var trabajadoresDisponibles: enfermeriaModel ? enfermeriaModel.trabajadoresEnfermeria : []
    property var tiposProcedimientos: enfermeriaModel ? enfermeriaModel.tiposProcedimientos : []

    // ✅ DATOS LIMPIOS - SIN EJEMPLOS
    property var procedimientosModelData: []
    // ✅ PROPIEDADES PARA FILTROS
    property var filtrosActivos: ({
        "busqueda": "",
        "tipo_procedimiento": "",
        "tipo": "",
        "fecha_desde": "",
        "fecha_hasta": ""
    })
    // AGREGAR ESTA CONEXIÓN:
    Connections {
        target: appController
        function onModelsReady() {
            console.log("📡 Modelos listos, conectando EnfermeriaModel...")
            enfermeriaModel = appController.enfermeria_model_instance
            if (enfermeriaModel) {
                initializarModelo()
            }
        }
    }
    // ✅ CONEXIONES CON EL MODELO
    Connections {
        target: enfermeriaModel
        enabled: enfermeriaModel !== null
        
        function onProcedimientoCreado(success, message) {
            if (success) {
                console.log("Procedimiento creado:", message)
                showNewProcedureDialog = false
                aplicarFiltros() // Recargar datos después de crear
            } else {
                console.log("Error creando procedimiento:", message)
            }
        }
        
        function onOperacionError(mensaje) {
            console.log("Error en operación:", mensaje)
        }
        
        function onProcedimientoActualizado(success, message) {
            if (success) {
                console.log("Procedimiento actualizado:", message)
                showNewProcedureDialog = false
                selectedRowIndex = -1
                aplicarFiltros() // Recargar datos después de actualizar
            } else {
                console.log("Error actualizando procedimiento:", message)
            }
        }

        function onProcedimientoEliminado(success, message) {
            if (success) {
                console.log("Procedimiento eliminado:", message)
                aplicarFiltros() // Recargar datos después de eliminar
            } else {
                console.log("Error eliminando procedimiento:", message)
            }
        }

        function onProcedimientosActualizados() {
            aplicarFiltros() // Recargar cuando el modelo emite esta señal
        }
    }

    // ✅ MODELOS SEPARADOS PARA PAGINACIÓN
    ListModel {
        id: procedimientosListModel // Modelo filtrado (todos los resultados del filtro)
    }
    
    ListModel {
        id: procedimientosPaginadosModel // Modelo para la página actual
    }

        // FUNCIÓN PARA CALCULAR ELEMENTOS POR PÁGINA ADAPTATIVAMENTE (COMO EN CONSULTAS)
    function calcularElementosPorPagina() {
        var alturaDisponible = height - baseUnit * 25
        var alturaFila = baseUnit * 7
        var elementosCalculados = Math.floor(alturaDisponible / alturaFila)
        
        return Math.max(6, Math.min(elementosCalculados, 15))
    }

    // RECALCULAR PAGINACIÓN CUANDO CAMBIE EL TAMAÑO (COMO EN CONSULTAS)
    onHeightChanged: {
        var nuevosElementos = calcularElementosPorPagina()
        if (nuevosElementos !== itemsPerPageEnfermeria) {
            itemsPerPageEnfermeria = nuevosElementos
            cargarPaginaActual()
        }
    }

    // ✅ LAYOUT PRINCIPAL RESPONSIVO (COMO EN CONSULTAS)
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: baseUnit * 4
        spacing: baseUnit * 3
        
        // ✅ CONTENEDOR PRINCIPAL (COMO EN CONSULTAS)
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
                
                // ✅ HEADER ADAPTATIVO - CORREGIDO PARA COINCIDIR EXACTAMENTE CON CONSULTAS
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
                        
                        // SECCIÓN DEL LOGO Y TÍTULO (IGUAL QUE CONSULTAS)
                        RowLayout {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: baseUnit * 1.5
                            
                            // Contenedor del icono con tamaño fijo (IGUAL QUE CONSULTAS)
                            Rectangle {
                                Layout.preferredWidth: baseUnit * 10
                                Layout.preferredHeight: baseUnit * 10
                                color: "transparent"
                                
                                Image {
                                    id: enfermeriaIcon
                                    anchors.centerIn: parent
                                    width: Math.min(baseUnit * 8, parent.width * 0.8)
                                    height: Math.min(baseUnit * 8, parent.height * 0.8)
                                    source: "Resources/iconos/Enfermeria.png"
                                    fillMode: Image.PreserveAspectFit
                                    antialiasing: true
                                    
                                    onStatusChanged: {
                                        if (status === Image.Error) {
                                            console.log("Error cargando PNG de enfermería:", source)
                                        } else if (status === Image.Ready) {
                                            console.log("PNG de enfermería cargado correctamente:", source)
                                        }
                                    }
                                }
                            }
                            
                            // Título (IGUAL QUE CONSULTAS)
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
                        
                        // ESPACIADOR FLEXIBLE (IGUAL QUE CONSULTAS)
                        Item { 
                            Layout.fillWidth: true 
                            Layout.minimumWidth: baseUnit * 2
                        }
                        
                        // BOTÓN NUEVO PROCEDIMIENTO (IGUAL QUE CONSULTAS)
                        Button {
                            id: newProcedureBtn
                            objectName: "newProcedureButton"
                            Layout.preferredHeight: baseUnit * 5
                            Layout.preferredWidth: Math.max(baseUnit * 20, implicitWidth + baseUnit * 2)
                            Layout.alignment: Qt.AlignVCenter
                            
                            background: Rectangle {
                                color: newProcedureBtn.pressed ? primaryColorPressed : 
                                    newProcedureBtn.hovered ? primaryColorHover : primaryColor
                                radius: baseUnit * 1.2
                                border.width: 0
                                
                                // Animación suave del color (IGUAL QUE CONSULTAS)
                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                            
                            contentItem: RowLayout {
                                spacing: baseUnit
                                
                                // Contenedor del icono del botón (IGUAL QUE CONSULTAS)
                                Rectangle {
                                    Layout.preferredWidth: baseUnit * 3
                                    Layout.preferredHeight: baseUnit * 3
                                    color: "transparent"
                                    
                                    Image {
                                        id: addIcon
                                        anchors.centerIn: parent
                                        width: baseUnit * 2.5
                                        height: baseUnit * 2.5
                                        source: "Resources/iconos/Nueva_Consulta.png"
                                        fillMode: Image.PreserveAspectFit
                                        antialiasing: true
                                        
                                        onStatusChanged: {
                                            if (status === Image.Error) {
                                                console.log("Error cargando PNG del botón:", source)
                                                // Mostrar un "+" si no hay icono
                                                visible = false
                                                fallbackText.visible = true
                                            } else if (status === Image.Ready) {
                                                console.log("PNG del botón cargado correctamente:", source)
                                            }
                                        }
                                    }
                                    
                                    // Texto fallback si no hay icono (IGUAL QUE CONSULTAS)
                                    Label {
                                        id: fallbackText
                                        anchors.centerIn: parent
                                        text: "+"
                                        color: whiteColor
                                        font.pixelSize: fontBaseSize * 1.5
                                        font.bold: true
                                        visible: false
                                    }
                                }
                                
                                // Texto del botón (IGUAL QUE CONSULTAS)
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
                            
                            // Efecto hover mejorado (IGUAL QUE CONSULTAS)
                            HoverHandler {
                                id: buttonHover
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }
                }

                // ✅ FILTROS ADAPTATIVOS (COMO EN CONSULTAS)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: width < 1000 ? baseUnit * 16 : baseUnit * 8
                    color: "transparent"
                    z: 10
                    
                    GridLayout {
                        anchors.fill: parent
                        anchors.margins: baseUnit * 3
                        anchors.bottomMargin: baseUnit * 1.5
                        
                        columns: width < 1000 ? 2 : 4
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
                                    if (tiposProcedimientos && tiposProcedimientos.length > 0) {
                                        for (var i = 0; i < tiposProcedimientos.length; i++) {
                                            // Asegurarnos de que estamos extrayendo solo el texto
                                            var nombre = tiposProcedimientos[i].nombre || tiposProcedimientos[i].text || ""
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
                            placeholderText: "Buscar por paciente o cédula... "
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
                    }
                }
                
                // ✅ TABLA MODERNA CON LÍNEAS VERTICALES (COMO EN CONSULTAS)
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
                        
                        // HEADER CON LÍNEAS VERTICALES (COMO EN CONSULTAS)
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
                                
                                // ID COLUMN
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
                                
                                // PROCEDIMIENTO COLUMN
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
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    
                                    Rectangle {
                                        anchors.right: parent.right
                                        width: 1
                                        height: parent.height
                                        color: lineColor
                                    }
                                }
                                
                                // CANTIDAD COLUMN
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
                                
                                // TOTAL COLUMN
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
                                        text: "TRABAJADOR / REGISTRADO"
                                        font.bold: true
                                        font.pixelSize: fontBaseSize * 0.85
                                        font.family: "Segoe UI, Arial, sans-serif"
                                        color: textColor
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }
                            }
                        }
                        
                        // CONTENIDO DE TABLA CON SCROLL Y LÍNEAS VERTICALES (COMO EN CONSULTAS)
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
                                    
                                    // Borde horizontal sutil
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        height: 1
                                        color: borderColor
                                    }
                                    
                                    // Borde vertical de selección
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
                                        
                                        // ID COLUMN
                                        Item {
                                            Layout.preferredWidth: parent.width * colId
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                text: model.procedimientoId
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
                                        
                                        // PACIENTE COLUMN
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
                                                    font.bold: false
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
                                        
                                        // PROCEDIMIENTO COLUMN
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
                                        
                                        // CANTIDAD COLUMN
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
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                text: "Bs "+ model.precioUnitario
                                                color: model.tipo === "Emergencia" ? "#92400E" : "#047857"
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
                                        
                                        // TOTAL COLUMN
                                        Item {
                                            Layout.preferredWidth: parent.width * colTotal
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                text: "Bs "+ model.precioTotal
                                                color: model.tipo === "Emergencia" ? "#92400E" : "#047857"
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
                                        
                                        // FECHA COLUMN
                                        Item {
                                            Layout.preferredWidth: parent.width * colFecha
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                text: model.fecha
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
                                        
                                        // TRABAJADOR COLUMN
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
                                                    font.bold: false
                                                    font.pixelSize: fontBaseSize * 0.85
                                                    font.family: "Segoe UI, Arial, sans-serif"
                                                    elide: Text.ElideRight
                                                }
                                                
                                                Label {
                                                    width: parent.width
                                                    text: "Por: " + (model.registradoPor || "Luis López")
                                                    color: textColorLight
                                                    font.pixelSize: fontBaseSize * 0.75
                                                    font.family: "Segoe UI, Arial, sans-serif"
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }
                                    }
                                    
                                    // LÍNEAS VERTICALES CONTINUAS (COMO EN CONSULTAS)
                                    Repeater {
                                        model: 8 // Número de líneas verticales (todas menos la última columna)
                                        Rectangle {
                                            property real xPos: {
                                                var w = parent.width - baseUnit * 3
                                                switch(index) {
                                                    case 0: return baseUnit * 1.5 + w * colId
                                                    case 1: return baseUnit * 1.5 + w * (colId + colPaciente)
                                                    case 2: return baseUnit * 1.5 + w * (colId + colPaciente + colProcedimiento)
                                                    case 3: return baseUnit * 1.5 + w * (colId + colPaciente + colProcedimiento + colCantidad)
                                                    case 4: return baseUnit * 1.5 + w * (colId + colPaciente + colProcedimiento + colCantidad + colTipo)
                                                    case 5: return baseUnit * 1.5 + w * (colId + colPaciente + colProcedimiento + colCantidad + colTipo + colPrecio)
                                                    case 6: return baseUnit * 1.5 + w * (colId + colPaciente + colProcedimiento + colCantidad + colTipo + colPrecio + colTotal)
                                                    case 7: return baseUnit * 1.5 + w * (colId + colPaciente + colProcedimiento + colCantidad + colTipo + colPrecio + colTotal + colFecha)
                                                }
                                            }
                                            x: xPos
                                            width: 1
                                            height: parent.height
                                            color: lineColor
                                            z: 1
                                        }
                                    }
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            selectedRowIndex = selectedRowIndex === index ? -1 : index
                                            console.log("Seleccionado procedimiento ID:", model.procedimientoId)
                                        }
                                    }
                                    
                                    // BOTONES DE ACCIÓN MODERNOS (COMO EN CONSULTAS)
                                    RowLayout {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.right: parent.right
                                        anchors.margins: baseUnit * 0.8
                                        spacing: baseUnit * 0.8
                                        visible: selectedRowIndex === index
                                        z: 10
                                        
                                        Button {
                                            id: editButton
                                            width: baseUnit * 3.5
                                            height: baseUnit * 3.5
                                            
                                            background: Rectangle {
                                                color: "transparent"
                                            }
                                            
                                            Image {
                                                id: editIcon
                                                anchors.centerIn: parent
                                                width: baseUnit * 2.5
                                                height: baseUnit * 2.5
                                                source: "Resources/iconos/editar.svg"
                                                fillMode: Image.PreserveAspectFit
                                            }
                                            
                                            onClicked: {
                                                var procedimientoId = parseInt(model.procedimientoId)
                                                enfermeriaModel.eliminar_procedimiento(procedimientoId)
                                                selectedRowIndex = -1
                                            }
                                            
                                            // Efecto hover
                                            onHoveredChanged: {
                                                editIcon.opacity = hovered ? 0.7 : 1.0
                                            }
                                        }

                                        Button {
                                            id: deleteButton
                                            width: baseUnit * 3.5
                                            height: baseUnit * 3.5
                                            
                                            background: Rectangle {
                                                color: "transparent"
                                            }
                                            
                                            Image {
                                                id: deleteIcon
                                                anchors.centerIn: parent
                                                width: baseUnit * 2.5
                                                height: baseUnit * 2.5
                                                source: "Resources/iconos/eliminar.svg"
                                                fillMode: Image.PreserveAspectFit
                                            }
                                            
                                            onClicked: {
                                                var procedimientoId = model.procedimientoId
                                                
                                                // Eliminar de procedimientosListModel
                                                for (var i = 0; i < procedimientosListModel.count; i++) {
                                                    if (procedimientosListModel.get(i).procedimientoId === procedimientoId) {
                                                        procedimientosListModel.remove(i)
                                                        break
                                                    }
                                                }
                                                
                                                // Eliminar de procedimientosOriginales
                                                for (var j = 0; j < procedimientosOriginales.length; j++) {
                                                    if (procedimientosOriginales[j].procedimientoId === procedimientoId) {
                                                        procedimientosOriginales.splice(j, 1)
                                                        break
                                                    }
                                                }
                                                
                                                selectedRowIndex = -1
                                                aplicarFiltros()
                                                console.log("Procedimiento eliminado ID:", procedimientoId)
                                            }
                                            
                                            // Efecto hover
                                            onHoveredChanged: {
                                                deleteIcon.opacity = hovered ? 0.7 : 1.0
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // ✅ ESTADO VACÍO PARA TABLA SIN DATOS
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
                
                // ✅ PAGINACIÓN MODERNA (COMO EN CONSULTAS)
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
                            
                            onClicked: {
                                if (currentPageEnfermeria > 0) {
                                    currentPageEnfermeria--
                                    cargarPaginaActual()
                                }
                            }
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
                            
                            onClicked: {
                                if (currentPageEnfermeria < totalPagesEnfermeria - 1) {
                                    currentPageEnfermeria++
                                    cargarPaginaActual()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ✅ DIÁLOGO RESPONSIVO MEJORADO - OCUPA MEJOR EL ESPACIO
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
        width: Math.min(parent.width * 0.95, 700)  // ✅ Más ancho para mejor uso del espacio
        height: Math.min(parent.height * 0.95, 800)  // ✅ Más alto pero con mejor distribución
        color: whiteColor
        radius: baseUnit * 1.5  // ✅ Bordes más redondeados
        border.color: "#DDD"
        border.width: 1
        visible: showNewProcedureDialog

        // ✅ EFECTO DE SOMBRA SIMPLE (ALTERNATIVA)
        Rectangle {
            anchors.fill: parent
            anchors.margins: -baseUnit
            color: "transparent"
            radius: parent.radius + baseUnit
            border.color: "#20000000"
            border.width: baseUnit
            z: -1
        }
        
        property int selectedProcedureIndex: -1
        property string procedureType: "Normal"
        property real calculatedUnitPrice: 0.0
        property real calculatedTotalPrice: 0.0
        
        // Función para cargar datos en modo edición
        function loadEditData() {
            if (isEditMode && editingIndex >= 0) {
                var procedimiento = procedimientosListModel.get(editingIndex)
                
                // Extraer nombres del paciente completo
                var nombreCompleto = procedimiento.paciente.split(" ")
                nombrePaciente.text = nombreCompleto[0] || ""
                apellidoPaterno.text = nombreCompleto[1] || ""
                apellidoMaterno.text = nombreCompleto.slice(2).join(" ") || ""
                
                // Buscar el tipo de procedimiento correspondiente
                for (var i = 0; i < tiposProcedimientos.length; i++) {
                    if (tiposProcedimientos[i].nombre === procedimiento.tipoProcedimiento) {
                        procedimientoCombo.currentIndex = i + 1
                        procedureForm.selectedProcedureIndex = i
                        break
                    }
                }
                
                // Buscar trabajador
                for (var j = 0; j < trabajadoresDisponibles.length; j++) {
                    if (trabajadoresDisponibles[j] === procedimiento.trabajadorRealizador) {
                        trabajadorCombo.currentIndex = j + 1
                        break
                    }
                }
                
                // Configurar tipo de procedimiento
                if (procedimiento.tipo === "Normal") {
                    normalRadio.checked = true
                    procedureForm.procedureType = "Normal"
                } else {
                    emergenciaRadio.checked = true
                    procedureForm.procedureType = "Emergencia"
                }
                
                // Cargar cantidad
                cantidadSpinBox.value = parseInt(procedimiento.cantidad)
                
                // Calcular precios
                if (procedureForm.selectedProcedureIndex >= 0) {
                    var proc = tiposProcedimientos[procedureForm.selectedProcedureIndex]
                    procedureForm.calculatedUnitPrice = procedureForm.procedureType === "Normal" ? 
                                                    proc.precioNormal : proc.precioEmergencia
                    procedureForm.calculatedTotalPrice = procedureForm.calculatedUnitPrice * cantidadSpinBox.value
                }
                
                // Cargar observaciones
                observacionesProcedimiento.text = procedimiento.observaciones
                
                // Cargar edad si existe
                if (procedimiento.cedula) {
                    cedulaPaciente.text = procedimiento.cedula
                }
            }
        }
        
        function updatePrices() {
            if (procedureForm.selectedProcedureIndex >= 0) {
                var proc = tiposProcedimientos[procedureForm.selectedProcedureIndex]
                procedureForm.calculatedUnitPrice = procedureForm.procedureType === "Normal" ? 
                                                proc.precioNormal : proc.precioEmergencia
                procedureForm.calculatedTotalPrice = procedureForm.calculatedUnitPrice * cantidadSpinBox.value
            } else {
                procedureForm.calculatedUnitPrice = 0.0
                procedureForm.calculatedTotalPrice = 0.0
            }
        }
        
        onVisibleChanged: {
            if (visible && isEditMode) {
                loadEditData()
            } else if (visible && !isEditMode) {
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
            }
        }
        
    // ✅ HEADER MEJORADO CON CIERRE
    Rectangle {
        id: dialogHeader
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: baseUnit * 7
        color: primaryColor
        radius: baseUnit * 1.5  // ✅ SOLO UNA VEZ ESTA PROPIEDAD
        
        Label {
            anchors.centerIn: parent
            text: isEditMode ? "EDITAR PROCEDIMIENTO" : "NUEVO PROCEDIMIENTO"
            font.pixelSize: fontBaseSize * 1.2
            font.bold: true
            color: whiteColor
        }
        
        // Botón de cerrar
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
                showNewProcedureDialog = false
                selectedRowIndex = -1
            }
        }
    }
        
        // ✅ SCROLLVIEW PRINCIPAL CON MÁRGENES ADECUADOS
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
            
            // ✅ CONTENEDOR PRINCIPAL DEL FORMULARIO
            ColumnLayout {
                width: scrollView.width - (baseUnit * 1)
                spacing: baseUnit * 2
                
                // ✅ DATOS DEL PACIENTE - MEJOR DISPOSICIÓN
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
                        
                        Label {
                            text: "Cédula I:"
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
                                
                                // REEMPLAZAR onTextChanged por esto:
                                onTextChanged: {
                                    // Solo buscar si la cédula tiene al menos 6 caracteres
                                    if (text.trim().length >= 6) {
                                        buscarTimer.restart()
                                    } else if (text.trim().length === 0) {
                                        // Limpiar campos si se borra la cédula
                                        limpiarCamposPaciente()
                                    }
                                }
                                
                                background: Rectangle {
                                    color: whiteColor
                                    border.color: "#ddd"
                                    border.width: 1
                                    radius: baseUnit * 0.5
                                }
                                padding: baseUnit
                            }

                            // AGREGAR TIMER PARA EVITAR CONSULTAS EXCESIVAS
                            Timer {
                                id: buscarTimer
                                interval: 500 // 500ms de delay
                                running: false
                                repeat: false
                                onTriggered: buscarPacientePorCedula(cedulaPaciente.text.trim())
                            }
                        }
                    }
                }
                
                // ✅ INFORMACIÓN DEL PROCEDIMIENTO
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
                        
                        // Procedimiento
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
                                
                                popup: Popup {
                                    width: procedimientoCombo.width
                                    implicitHeight: contentItem.implicitHeight + baseUnit
                                    
                                    contentItem: ListView {
                                        clip: true
                                        implicitHeight: contentHeight
                                        model: procedimientoCombo.popup.visible ? procedimientoCombo.delegateModel : null
                                        currentIndex: procedimientoCombo.highlightedIndex
                                        
                                        ScrollIndicator.vertical: ScrollIndicator { }
                                    }
                                    
                                    background: Rectangle {
                                        color: whiteColor
                                        border.color: "#ddd"
                                        radius: baseUnit * 0.5
                                    }
                                }
                            }
                        }
                        
                        // Descripción del procedimiento
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
                        
                        // Trabajador
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
                                            // Extraer solo el nombre si es un objeto, o usar directamente si es string
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
                        
                        // Tipo de procedimiento
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
                        
                        // Cantidad
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
                                
                                TextField {
                                    id: cantidadSpinBox
                                    Layout.preferredWidth: baseUnit * 12
                                    Layout.preferredHeight: baseUnit * 4
                                    text: "1"
                                    font.pixelSize: fontBaseSize
                                    horizontalAlignment: Text.AlignHCenter
                                    validator: IntValidator { bottom: 1; top: 50 }
                                    
                                    // Propiedad value para compatibilidad con el código existente
                                    property int value: parseInt(text) || 1
                                    
                                    onTextChanged: {
                                        if (text && !isNaN(parseInt(text))) {
                                            procedureForm.updatePrices()
                                        }
                                    }
                                    
                                    background: Rectangle {
                                        color: whiteColor
                                        border.color: "#ddd"
                                        border.width: 1
                                        radius: baseUnit * 0.5
                                    }
                                    
                                    // Filtrar solo números
                                    Keys.onPressed: function(event) {
                                        if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
                                            // Permitir números
                                            return
                                        } else if (event.key === Qt.Key_Backspace || 
                                                event.key === Qt.Key_Delete || 
                                                event.key === Qt.Key_Left || 
                                                event.key === Qt.Key_Right) {
                                            // Permitir teclas de edición
                                            return
                                        } else {
                                            // Bloquear otras teclas
                                            event.accepted = true
                                        }
                                    }
                                }
                                
                                Label {
                                    text: "procedimiento(s)"
                                    color: textColor
                                }
                                
                                Item { Layout.fillWidth: true }
                            }
                        }
                    }
                }
                
                // ✅ INFORMACIÓN DE PRECIOS
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
                        }
                        
                        Label {
                            text: procedureForm.selectedProcedureIndex >= 0 ? 
                                "Bs " + procedureForm.calculatedUnitPrice.toFixed(2) : "Seleccione procedimiento"
                            font.bold: true
                            color: procedureForm.procedureType === "Emergencia" ? "#92400E" : "#047857"
                        }
                        
                        Label {
                            text: "Total a Pagar:"
                            font.bold: true
                            font.pixelSize: fontBaseSize * 1.1
                            color: textColor
                        }
                        
                        Label {
                            text: procedureForm.selectedProcedureIndex >= 0 ? 
                                "Bs " + procedureForm.calculatedTotalPrice.toFixed(2) : "Bs 0.00"
                            font.bold: true
                            font.pixelSize: fontBaseSize * 1.3
                            color: procedureForm.procedureType === "Emergencia" ? "#92400E" : "#047857"
                        }
                    }
                }
                
                // ✅ OBSERVACIONES
                GroupBox {
                    Layout.fillWidth: true
                    title: "OBSERVACIONES"
                    font.bold: true
                    font.pixelSize: fontBaseSize
                    padding: baseUnit * 1.5
                    
                    background: Rectangle {
                        color: "#f8f9fa"
                        border.color: "#e0e0e0"
                        radius: baseUnit * 0.8
                    }
                    
                    TextArea {
                        id: observacionesProcedimiento
                        Layout.fillWidth: true
                        Layout.preferredHeight: baseUnit * 12
                        placeholderText: "Observaciones del procedimiento, resultados, reacciones del paciente..."
                        font.pixelSize: fontBaseSize
                        wrapMode: TextArea.Wrap
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
        }
        
        // ✅ BOTONES INFERIORES MEJOR DISEÑO
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
                
                onClicked: {
                    showNewProcedureDialog = false
                    selectedRowIndex = -1
                    isEditMode = false
                    editingIndex = -1
                }
            }
            
            Button {
                id: saveButton
                text: isEditMode ? "Actualizar" : "Guardar"
                Layout.preferredWidth: baseUnit * 15
                Layout.preferredHeight: baseUnit * 4.5
                enabled: procedureForm.selectedProcedureIndex >= 0 && 
                        nombrePaciente.text.length > 0 &&
                        trabajadorCombo.currentIndex > 0
                
                background: Rectangle {
                    color: !saveButton.enabled ? "#bdc3c7" : 
                        (saveButton.pressed ? primaryColorPressed : 
                        (saveButton.hovered ? primaryColorHover : primaryColor))
                    radius: baseUnit * 0.8
                }
                
                contentItem: Label {
                    text: parent.text
                    font.pixelSize: fontBaseSize
                    font.bold: true
                    color: whiteColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: {
                    var datosProcedimiento = {
                        paciente: (nombrePaciente.text + " " + apellidoPaterno.text + " " + apellidoMaterno.text).trim(),
                        cedula: cedulaPaciente.text.trim(),
                        idProcedimiento: procedureForm.selectedProcedureIndex + 1,
                        cantidad: parseInt(cantidadSpinBox.text) || 1,
                        tipo: procedureForm.procedureType,
                        idTrabajador: trabajadorCombo.currentIndex
                    }
                    
                    console.log("Datos a enviar:", JSON.stringify(datosProcedimiento))
                    
                    // ✅ AGREGAR ESTA LÍNEA CRUCIAL
                    if (enfermeriaModel) {
                        console.log("Llamando a crear_procedimiento...")
                        enfermeriaModel.crear_procedimiento(datosProcedimiento)
                    } else {
                        console.log("ERROR: enfermeriaModel no disponible")
                    }
                }
            }
        }
    }
    // ✅ FUNCIÓN PARA APLICAR FILTROS - AHORA CON BASE DE DATOS
    function aplicarFiltros() {
        console.log("🔍 Aplicando filtros en base de datos...")
        
        // Construir objeto de filtros
        var nuevosFiltros = {
            "busqueda": campoBusqueda.text,
            "tipo_procedimiento": filtroProcedimiento.currentIndex > 0 ? 
                                filtroProcedimiento.currentText : "",
            "tipo": filtroTipo.currentIndex > 0 ? 
                filtroTipo.currentText : "",
            "fecha_desde": obtenerFiltroFechaDesde(),
            "fecha_hasta": obtenerFiltroFechaHasta()
        }
        
        filtrosActivos = nuevosFiltros
        
        // Obtener total de procedimientos con filtros
        var total = enfermeriaModel.contar_procedimientos_filtrados(filtrosActivos)
        console.log("Total de procedimientos con filtros:", total)
        
        // Calcular total de páginas
        totalPagesEnfermeria = Math.ceil(total / itemsPerPageEnfermeria)
        if (totalPagesEnfermeria === 0) totalPagesEnfermeria = 1
        
        // Resetear a la primera página
        currentPageEnfermeria = 0
        
        // Cargar la primera página
        cargarPaginaActual()
    }

    function initializarModelo() {
        console.log("✅ EnfermeriaModel disponible, inicializando datos...")
        
        if (enfermeriaModel) {
            // Cargar datos iniciales del backend
            enfermeriaModel.actualizar_procedimientos()
            enfermeriaModel.actualizar_tipos_procedimientos()
            enfermeriaModel.actualizar_trabajadores_enfermeria()
            
            // Aplicar filtros iniciales
            aplicarFiltros()
        }
    }

    // ✅ FUNCIÓN PARA OBTENER FILTRO DE FECHA DESDE
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
            default: // Todos
                return ""
        }
    }

    // ✅ FUNCIÓN PARA OBTENER FILTRO DE FECHA HASTA
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
            default: // Todos
                return ""
        }
    }

    // ✅ NUEVA FUNCIÓN PARA ACTUALIZAR PAGINACIÓN
    function updatePaginatedModel() {
        console.log("📄 Enfermería: Actualizando paginación - Página:", currentPageEnfermeria + 1)
        
        // Limpiar modelo paginado
        procedimientosPaginadosModel.clear()
        
        // Calcular total de páginas basado en procedimientos filtrados
        var totalItems = procedimientosListModel.count
        totalPagesEnfermeria = Math.ceil(totalItems / itemsPerPageEnfermeria)
        
        // Asegurar que siempre hay al menos 1 página
        if (totalPagesEnfermeria === 0) {
            totalPagesEnfermeria = 1
        }
        
        // Ajustar página actual si es necesario
        if (currentPageEnfermeria >= totalPagesEnfermeria && totalPagesEnfermeria > 0) {
            currentPageEnfermeria = totalPagesEnfermeria - 1
        }
        if (currentPageEnfermeria < 0) {
            currentPageEnfermeria = 0
        }
        
        // Calcular índices
        var startIndex = currentPageEnfermeria * itemsPerPageEnfermeria
        var endIndex = Math.min(startIndex + itemsPerPageEnfermeria, totalItems)
        
        // Agregar elementos de la página actual
        for (var i = startIndex; i < endIndex; i++) {
            var procedimiento = procedimientosListModel.get(i)
            procedimientosPaginadosModel.append(procedimiento)
        }
        
        console.log("📄 Enfermería: Página", currentPageEnfermeria + 1, "de", totalPagesEnfermeria,
                    "- Mostrando", procedimientosPaginadosModel.count, "de", totalItems)
    }
    // ✅ FUNCIÓN PARA CARGAR LA PÁGINA ACTUAL
    function cargarPaginaActual() {
        var offset = currentPageEnfermeria * itemsPerPageEnfermeria
        
        // Obtener procedimientos paginados del modelo
        var procedimientos = enfermeriaModel.obtener_procedimientos_paginados(offset, itemsPerPageEnfermeria, filtrosActivos)
        
        // Limpiar y llenar el modelo paginado
        procedimientosPaginadosModel.clear()
        for (var i = 0; i < procedimientos.length; i++) {
            procedimientosPaginadosModel.append(procedimientos[i])
        }
        
        console.log("📄 Página", currentPageEnfermeria + 1, "de", totalPagesEnfermeria, "-", procedimientos.length, "procedimientos")
    }

    
        // ✅ FUNCIÓN PARA OBTENER TOTAL DE PROCEDIMIENTOS CORREGIDA
    function getTotalEnfermeriaCount() {
        return procedimientosOriginales.length
    }
    
    // ✅ FUNCIÓN PARA CARGAR DATOS DEL BACKEND
    function cargarProcedimientosDesdeBackend() {
        if (!enfermeriaModel) return
        
        // Limpiar datos actuales
        procedimientosListModel.clear()
        procedimientosOriginales = []
        
        // Obtener procedimientos del backend
        var procedimientos = enfermeriaModel.procedimientos
        
        for (var i = 0; i < procedimientos.length; i++) {
            var proc = procedimientos[i]
            procedimientosListModel.append(proc)
            procedimientosOriginales.push(proc)
        }
        
        // Actualizar paginación
        updatePaginatedModel()
        console.log("Cargados", procedimientos.length, "procedimientos desde backend")
    }
    // FUNCIÓN PARA BUSCAR PACIENTE POR CÉDULA
    function buscarPacientePorCedula(cedula) {
        if (!enfermeriaModel || cedula.length < 6) return
        
        console.log("Buscando paciente con cédula:", cedula)
        
        // Usar el método existente buscar_pacientes
        var pacientes = enfermeriaModel.buscar_pacientes(cedula)
        
        if (pacientes && pacientes.length > 0) {
            // Buscar el que coincida exactamente con la cédula
            for (var i = 0; i < pacientes.length; i++) {
                if (pacientes[i].cedula === cedula || pacientes[i].cedula === cedula.replace(/\s/g, '')) {
                    autocompletarDatosPaciente(pacientes[i])
                    return
                }
            }
            // Si no encontró coincidencia exacta, usar el primero
            autocompletarDatosPaciente(pacientes[0])
        } else {
            console.log("No se encontró paciente con cédula:", cedula)
        }
    }

    // FUNCIÓN PARA AUTOCOMPLETAR DATOS
    function autocompletarDatosPaciente(paciente) {
        var nombres = paciente.nombreCompleto.split(" ")
        
        nombrePaciente.text = nombres[0] || ""
        apellidoPaterno.text = nombres[1] || ""
        apellidoMaterno.text = nombres.slice(2).join(" ") || ""
        
        console.log("✅ Paciente encontrado y autocompletado:", paciente.nombreCompleto)
    }

    // FUNCIÓN PARA LIMPIAR CAMPOS
    function limpiarCamposPaciente() {
        if (nombrePaciente.text === "" && apellidoPaterno.text === "" && apellidoMaterno.text === "") {
            return // Ya están limpios
        }
        nombrePaciente.text = ""
        apellidoPaterno.text = ""
        apellidoMaterno.text = ""
    }
    Component.onCompleted: {
        console.log("🩹 Módulo Enfermería iniciado")
        if (enfermeriaModel) {
            initializarModelo()
        }
    }
}