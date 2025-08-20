import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

import QtQml 2.15

Item {
    id: consultasRoot
    objectName: "consultasRoot"

    property var consultaModel: null
    
    // ===== NUEVA SEÑAL PARA IR A CONFIGURACIÓN =====
    signal irAConfiguracion()
    
    // ACCESO A PROPIEDADES ADAPTATIVAS DEL MAIN
    readonly property real baseUnit: parent.baseUnit || Math.max(8, Screen.height / 100)
    readonly property real fontBaseSize: parent.fontBaseSize || Math.max(12, Screen.height / 70)
    readonly property real scaleFactor: parent.scaleFactor || Math.min(width / 1400, height / 900)
    
    // Colores modernos
    readonly property color primaryColor: "#3498DB"
    readonly property color successColor: "#10B981"
    readonly property color successColorLight: "#D1FAE5"
    readonly property color dangerColor: "#E74C3C"
    readonly property color dangerColorLight: "#FEE2E2"
    readonly property color warningColor: "#f39c12"
    readonly property color warningColorLight: "#FEF3C7"
    readonly property color lightGrayColor: "#F8F9FA"
    readonly property color textColor: "#2c3e50"
    readonly property color textColorLight: "#6B7280"
    readonly property color whiteColor: "#FFFFFF"
    readonly property color borderColor: "#e0e0e0"
    readonly property color accentColor: "#10B981"
    readonly property color lineColor: "#D1D5DB" // Color para líneas verticales
    
    // Propiedades para los diálogos
    property bool showNewConsultationDialog: false
    property bool isEditMode: false
    property int editingIndex: -1
    property int selectedRowIndex: -1
    
    // PAGINACIÓN ADAPTATIVA
    property int itemsPerPageConsultas: calcularElementosPorPagina()
    property int currentPageConsultas: 0
    property int totalPagesConsultas: 0

    // Agregar después de las otras propiedades
    property var especialidades: [
        {nombre: "Cardiología", doctor: "Dr. Juan Pérez", precioNormal: 150, precioEmergencia: 250},
        {nombre: "Pediatría", doctor: "Dra. Elena López", precioNormal: 120, precioEmergencia: 200},
        {nombre: "Neurología", doctor: "Dr. Ricardo Sánchez", precioNormal: 180, precioEmergencia: 300}
    ]
    
    
    // Distribución de columnas responsive
    readonly property real colId: 0.06
    readonly property real colPaciente: 0.18
    readonly property real colDetalle: 0.22
    readonly property real colEspecialidad: 0.24
    readonly property real colTipo: 0.10
    readonly property real colPrecio: 0.10
    readonly property real colFecha: 0.10

    ListModel {
        id: consultasPaginadasModel
    }

    ListModel {
        id: consultasListModel
    }

    property var consultasOriginales: []

    Connections {
        target: consultaModel
        
        function onConsultasRecientesChanged() {
            console.log("📋 Consultas recientes actualizadas")
            updatePaginatedModel()
        }
        
        function onConsultaCreada(consulta_id, paciente_nombre) {
            console.log(`✅ Nueva consulta creada: ${consulta_id} - ${paciente_nombre}`)
            showNotification("Éxito", `Consulta creada para ${paciente_nombre}`)
        }
        
        function onConsultaActualizada(consulta_id) {
            console.log(`✅ Consulta actualizada: ${consulta_id}`)
            showNotification("Éxito", "Consulta actualizada correctamente")
        }
        
        function onOperacionError(mensaje) {
            console.log(`❌ Error: ${mensaje}`)
            showNotification("Error", mensaje)
        }
        
        function onOperacionExitosa(mensaje) {
            console.log(`✅ Éxito: ${mensaje}`)
        }
    }


    // FUNCIÓN PARA CALCULAR ELEMENTOS POR PÁGINA ADAPTATIVAMENTE
    function calcularElementosPorPagina() {
        var alturaDisponible = height - baseUnit * 25
        var alturaFila = baseUnit * 7
        var elementosCalculados = Math.floor(alturaDisponible / alturaFila)
        
        return Math.max(6, Math.min(elementosCalculados, 15))
    }

    // RECALCULAR PAGINACIÓN CUANDO CAMBIE EL TAMAÑO
    onHeightChanged: {
        var nuevosElementos = calcularElementosPorPagina()
        if (nuevosElementos !== itemsPerPageConsultas) {
            itemsPerPageConsultas = nuevosElementos
            updatePaginatedModel()
        }
    }

    function aplicarFiltros() {
        console.log("🔍 Aplicando filtros...")
        
        var termino = campoBusqueda.text
        if (termino.length >= 2) {
            consultaModel.buscar_consultas(termino)
        } else {
            // Usar consultas recientes si no hay búsqueda
            updatePaginatedModel()
        }
    }

    function updatePaginatedModel() {
        console.log("🔄 Consultas: Actualizando paginación - Página:", currentPageConsultas + 1)
        
        consultasPaginadasModel.clear()
        
        if (!consultaModel || !consultaModel.consultas_recientes) {
            console.log("⚠️ ConsultaModel no disponible")
            return
        }
        
        var consultas = consultaModel.consultas_recientes
        var totalItems = consultas.length
        totalPagesConsultas = Math.ceil(totalItems / itemsPerPageConsultas)
        
        if (totalPagesConsultas === 0) {
            totalPagesConsultas = 1
        }
        
        if (currentPageConsultas >= totalPagesConsultas && totalPagesConsultas > 0) {
            currentPageConsultas = totalPagesConsultas - 1
        }
        if (currentPageConsultas < 0) {
            currentPageConsultas = 0
        }
        
        var startIndex = currentPageConsultas * itemsPerPageConsultas
        var endIndex = Math.min(startIndex + itemsPerPageConsultas, totalItems)
        
        for (var i = startIndex; i < endIndex; i++) {
            var consulta = consultas[i]
            
            // Adaptar datos del model a formato esperado por UI
            var consultaUI = {
                consultaId: consulta.id.toString(),
                paciente: consulta.paciente_completo || "Sin nombre",
                especialidadDoctor: consulta.especialidad_nombre + " - " + consulta.doctor_completo,
                tipo: determinarTipoConsulta(consulta.Precio_Normal, consulta.Precio_Emergencia),
                precio: (consulta.Precio_Normal || 0).toFixed(2),
                fecha: formatearFecha(consulta.Fecha),
                detalles: consulta.Detalles || "Sin detalles"
            }
            
            consultasPaginadasModel.append(consultaUI)
        }
        
        console.log("🔄 Consultas: Página", currentPageConsultas + 1, "de", totalPagesConsultas,
                    "- Mostrando", consultasPaginadasModel.count, "de", totalItems, 
                    "- Elementos por página:", itemsPerPageConsultas)
    }

    function determinarTipoConsulta(precioNormal, precioEmergencia) {
        // Lógica simple para determinar tipo (puede mejorarse)
        return (precioEmergencia > precioNormal) ? "Normal" : "Normal"
    }

    function formatearFecha(fechaISO) {
        if (!fechaISO) return "Sin fecha"
        
        try {
            var fecha = new Date(fechaISO)
            return fecha.toLocaleDateString("es-ES")
        } catch (e) {
            return "Fecha inválida"
        }
    }

    function showNotification(tipo, mensaje) {
        // Conectar con sistema de notificaciones del main
        if (typeof appController !== 'undefined') {
            appController.showNotification(tipo, mensaje)
        } else {
            console.log(`${tipo}: ${mensaje}`)
        }
    }

    // LAYOUT PRINCIPAL ADAPTATIVO
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
                
                // HEADER ADAPTATIVO
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: baseUnit * 8
                    color: lightGrayColor
                    border.color: borderColor
                    border.width: 1
                    
                    Rectangle {
                        anchors.fill: parent
                        anchors.bottomMargin: baseUnit * 2
                        color: parent.color
                        radius: parent.radius
                    }
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: baseUnit * 1.5
                        
                        RowLayout {
                            spacing: baseUnit
                            
                            Label {
                                text: "🩺"
                                font.pixelSize: fontBaseSize * 1.8
                                color: primaryColor
                            }
                            
                            Label {
                                text: "Registro de Consultas Médicas"
                                font.pixelSize: fontBaseSize * 1.4
                                font.bold: true
                                font.family: "Segoe UI, Arial, sans-serif"
                                color: textColor
                            }
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        Button {
                            objectName: "newConsultationButton"
                            text: "➕ Nueva Consulta"
                            Layout.preferredHeight: baseUnit * 4.5
                            
                            background: Rectangle {
                                color: primaryColor
                                radius: baseUnit
                            }
                            
                            contentItem: Label {
                                text: parent.text
                                color: whiteColor
                                font.bold: true
                                font.pixelSize: fontBaseSize * 0.9
                                font.family: "Segoe UI, Arial, sans-serif"
                                horizontalAlignment: Text.AlignHCenter
                            }
                            
                            onClicked: {
                                isEditMode = false
                                editingIndex = -1
                                showNewConsultationDialog = true
                            }
                        }
                    }
                }
                
                // FILTROS ADAPTATIVOS
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
                                text: "Especialidad:"
                                font.bold: true
                                color: textColor
                                font.pixelSize: fontBaseSize * 0.9
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                            
                            ComboBox {
                                id: filtroEspecialidad
                                Layout.fillWidth: true
                                Layout.preferredHeight: baseUnit * 4
                                model: {
                                    var especialidades = ["Todas"]
                                    if (consultaModel && consultaModel.especialidades) {
                                        for (var i = 0; i < consultaModel.especialidades.length; i++) {
                                            var esp = consultaModel.especialidades[i]
                                            if (esp && esp.text) {
                                                especialidades.push(esp.text)
                                            }
                                        }
                                    }
                                    return especialidades
}
                                currentIndex: 0
                                onCurrentIndexChanged: aplicarFiltros()
                                
                                contentItem: Label {
                                    text: filtroEspecialidad.displayText
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
                            placeholderText: "Buscar por paciente..."
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
                
                // TABLA MODERNA CON LÍNEAS VERTICALES
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
                        
                        // HEADER CON LÍNEAS VERTICALES
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
                                
                                // DETALLE COLUMN
                                Item {
                                    Layout.preferredWidth: parent.width * colDetalle
                                    Layout.fillHeight: true
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "DETALLE"
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
                                
                                // ESPECIALIDAD COLUMN
                                Item {
                                    Layout.preferredWidth: parent.width * colEspecialidad
                                    Layout.fillHeight: true
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "ESPECIALIDAD - DOCTOR"
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
                                id: consultasListView
                                model: consultasPaginadasModel
                                
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
                                                text: model.consultaId
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
                                            
                                            Rectangle {
                                                anchors.right: parent.right
                                                width: 1
                                                height: parent.height
                                                color: lineColor
                                            }
                                        }
                                        
                                        // DETALLE COLUMN
                                        Item {
                                            Layout.preferredWidth: parent.width * colDetalle
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                anchors.rightMargin: baseUnit
                                                text: model.detalles
                                                color: textColor // Mismo color que paciente
                                                font.bold: false
                                                font.pixelSize: fontBaseSize * 0.85
                                                font.family: "Segoe UI, Arial, sans-serif"
                                                wrapMode: Text.WordWrap
                                                elide: Text.ElideRight
                                                maximumLineCount: 2
                                            }
                                            
                                            Rectangle {
                                                anchors.right: parent.right
                                                width: 1
                                                height: parent.height
                                                color: lineColor
                                            }
                                        }
                                        
                                        // ESPECIALIDAD COLUMN
                                        Item {
                                            Layout.preferredWidth: parent.width * colEspecialidad
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                anchors.rightMargin: baseUnit
                                                text: model.especialidadDoctor
                                                color: primaryColor
                                                font.bold: false
                                                font.pixelSize: fontBaseSize * 0.85
                                                font.family: "Segoe UI, Arial, sans-serif"
                                                wrapMode: Text.WordWrap
                                                elide: Text.ElideRight
                                                maximumLineCount: 2
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
                                                text: "Bs "+ model.precio
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
                                                color: textColor // Mismo color que paciente
                                                font.bold: false
                                                font.pixelSize: fontBaseSize * 0.85
                                                font.family: "Segoe UI, Arial, sans-serif"
                                            }
                                        }
                                    }
                                    
                                    // LÍNEAS VERTICALES CONTINUAS
                                    Repeater {
                                        model: 6 // Número de líneas verticales (todas menos la última columna)
                                        Rectangle {
                                            property real xPos: {
                                                var w = parent.width - baseUnit * 3
                                                switch(index) {
                                                    case 0: return baseUnit * 1.5 + w * colId
                                                    case 1: return baseUnit * 1.5 + w * (colId + colPaciente)
                                                    case 2: return baseUnit * 1.5 + w * (colId + colPaciente + colDetalle)
                                                    case 3: return baseUnit * 1.5 + w * (colId + colPaciente + colDetalle + colEspecialidad)
                                                    case 4: return baseUnit * 1.5 + w * (colId + colPaciente + colDetalle + colEspecialidad + colTipo)
                                                    case 5: return baseUnit * 1.5 + w * (colId + colPaciente + colDetalle + colEspecialidad + colTipo + colPrecio)
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
                                            console.log("Seleccionada consulta ID:", model.consultaId)
                                        }
                                    }
                                    
                                    // BOTONES DE ACCIÓN MODERNOS
                                    RowLayout {
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: baseUnit * 0.8
                                        spacing: baseUnit * 0.5
                                        visible: selectedRowIndex === index
                                        z: 10
                                        
                                        Button {
                                            id: editButton
                                            width: baseUnit * 3.5
                                            height: baseUnit * 3.5
                                            text: "✏️"
                                            
                                            background: Rectangle {
                                                color: warningColor
                                                radius: baseUnit * 0.8
                                                border.color: "#e67e22"
                                                border.width: 1
                                            }
                                            
                                            contentItem: Label {
                                                text: parent.text
                                                color: whiteColor
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                                font.pixelSize: fontBaseSize * 0.85
                                            }
                                            
                                            onClicked: {
                                                var consultaId = model.consultaId
                                                var realIndex = -1
                                                
                                                for (var i = 0; i < consultasListModel.count; i++) {
                                                    if (consultasListModel.get(i).consultaId === consultaId) {
                                                        realIndex = i
                                                        break
                                                    }
                                                }
                                                
                                                isEditMode = true
                                                editingIndex = realIndex
                                                
                                                console.log("Editando consulta ID:", consultaId, "índice real:", realIndex)
                                                showNewConsultationDialog = true
                                            }
                                        }
                                        
                                        Button {
                                            id: deleteButton
                                            width: baseUnit * 3.5
                                            height: baseUnit * 3.5
                                            text: "🗑️"
                                            
                                            background: Rectangle {
                                                color: dangerColor
                                                radius: baseUnit * 0.8
                                                border.color: "#c0392b"
                                                border.width: 1
                                            }
                                            
                                            contentItem: Label {
                                                text: parent.text
                                                color: whiteColor
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                                font.pixelSize: fontBaseSize * 0.85
                                            }
                                            
                                            onClicked: {
                                                var consultaId = model.consultaId
                                                
                                                for (var i = 0; i < consultasListModel.count; i++) {
                                                    if (consultasListModel.get(i).consultaId === consultaId) {
                                                        consultasListModel.remove(i)
                                                        break
                                                    }
                                                }
                                                
                                                for (var j = 0; j < consultasOriginales.length; j++) {
                                                    if (consultasOriginales[j].consultaId === consultaId) {
                                                        consultasOriginales.splice(j, 1)
                                                        break
                                                    }
                                                }
                                                
                                                selectedRowIndex = -1
                                                updatePaginatedModel()
                                                console.log("Consulta eliminada ID:", consultaId)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                // PAGINACIÓN MODERNA
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
                            enabled: currentPageConsultas > 0
                            
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
                                if (currentPageConsultas > 0) {
                                    currentPageConsultas--
                                    updatePaginatedModel()
                                }
                            }
                        }
                        
                        Label {
                            text: "Página " + (currentPageConsultas + 1) + " de " + Math.max(1, totalPagesConsultas)
                            color: textColor
                            font.pixelSize: fontBaseSize * 0.9
                            font.family: "Segoe UI, Arial, sans-serif"
                            font.weight: Font.Medium
                        }
                        
                        Button {
                            Layout.preferredWidth: baseUnit * 11
                            Layout.preferredHeight: baseUnit * 4
                            text: "Siguiente →"
                            enabled: currentPageConsultas < totalPagesConsultas - 1
                            
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
                                if (currentPageConsultas < totalPagesConsultas - 1) {
                                    currentPageConsultas++
                                    updatePaginatedModel()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ===== DIÁLOGO DE NUEVA CONSULTA (MANTENER) =====
    
    // Fondo del diálogo
    Rectangle {
        id: newConsultationDialog
        anchors.fill: parent
        color: "black"
        opacity: showNewConsultationDialog ? 0.5 : 0
        visible: opacity > 0
        
        MouseArea {
            anchors.fill: parent
            onClicked: {
                showNewConsultationDialog = false
                selectedRowIndex = -1
            }
        }
        
        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }
    }
    
    // Diálogo de consulta adaptativo
    Rectangle {
        id: consultationForm
        anchors.centerIn: parent
        width: Math.min(500, parent.width * 0.9)
        height: Math.min(650, parent.height * 0.9)
        color: whiteColor
        radius: baseUnit * 2
        border.color: lightGrayColor
        border.width: 2
        visible: showNewConsultationDialog
        
        property int selectedEspecialidadIndex: -1
        property string consultationType: "Normal"
        property real calculatedPrice: 0.0
        
        function loadEditData() {
            if (isEditMode && editingIndex >= 0) {
                var consulta = consultasListModel.get(editingIndex)
                
                var nombreCompleto = consulta.paciente.split(" ")
                nombrePaciente.text = nombreCompleto[0] || ""
                apellidoPaterno.text = nombreCompleto[1] || ""
                apellidoMaterno.text = nombreCompleto.slice(2).join(" ") || ""
                
                var especialidadDoctor = consulta.especialidadDoctor
                for (var i = 0; i < especialidades.length; i++) {
                    var espStr = especialidades[i].nombre + " - " + especialidades[i].doctor
                    if (espStr === especialidadDoctor) {
                        especialidadCombo.currentIndex = i + 1
                        consultationForm.selectedEspecialidadIndex = i
                        break
                    }
                }
                
                if (consulta.tipo === "Normal") {
                    normalRadio.checked = true
                    consultationForm.consultationType = "Normal"
                } else {
                    emergenciaRadio.checked = true
                    consultationForm.consultationType = "Emergencia"
                }
                
                consultationForm.calculatedPrice = parseFloat(consulta.precio)
                detallesConsulta.text = consulta.detalles
            }
        }
        
        onVisibleChanged: {
            if (visible && isEditMode) {
                loadEditData()
            } else if (visible && !isEditMode) {
                nombrePaciente.text = ""
                apellidoPaterno.text = ""
                apellidoMaterno.text = ""
                edadPaciente.text = ""
                especialidadCombo.currentIndex = 0
                normalRadio.checked = true
                detallesConsulta.text = ""
                consultationForm.selectedEspecialidadIndex = -1
                consultationForm.calculatedPrice = 0.0
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: baseUnit * 3
            spacing: baseUnit * 2
            
            Label {
                Layout.fillWidth: true
                text: isEditMode ? "Editar Consulta" : "Nueva Consulta"
                font.pixelSize: fontBaseSize * 1.6
                font.bold: true
                font.family: "Segoe UI, Arial, sans-serif"
                color: textColor
                horizontalAlignment: Text.AlignHCenter
            }
            
            GroupBox {
                Layout.fillWidth: true
                title: "Datos del Paciente"
                
                background: Rectangle {
                    color: lightGrayColor
                    border.color: borderColor
                    border.width: 1
                    radius: baseUnit
                }
                
                ColumnLayout {
                    anchors.fill: parent
                    spacing: baseUnit
                    
                    TextField {
                        id: nombrePaciente
                        Layout.fillWidth: true
                        Layout.preferredHeight: baseUnit * 4
                        placeholderText: "Nombre del paciente"
                        font.pixelSize: fontBaseSize * 0.9
                        font.family: "Segoe UI, Arial, sans-serif"
                        background: Rectangle {
                            color: whiteColor
                            border.color: borderColor
                            border.width: 1
                            radius: baseUnit * 0.6
                        }
                    }
                    
                    RowLayout {
                        Layout.fillWidth: true                       
                        TextField {
                            id: apellidoPaterno
                            Layout.fillWidth: true
                            Layout.preferredHeight: baseUnit * 4
                            placeholderText: "Apellido paterno"
                            font.pixelSize: fontBaseSize * 0.9
                            font.family: "Segoe UI, Arial, sans-serif"
                            background: Rectangle {
                                color: whiteColor
                                border.color: borderColor
                                border.width: 1
                                radius: baseUnit * 0.6
                            }
                        }
                        
                        TextField {
                            id: apellidoMaterno
                            Layout.fillWidth: true
                            Layout.preferredHeight: baseUnit * 4
                            placeholderText: "Apellido materno"
                            font.pixelSize: fontBaseSize * 0.9
                            font.family: "Segoe UI, Arial, sans-serif"
                            background: Rectangle {
                                color: whiteColor
                                border.color: borderColor
                                border.width: 1
                                radius: baseUnit * 0.6
                            }
                        }
                    }
                    
                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            Layout.preferredWidth: baseUnit * 12
                            text: "Edad:"
                            font.bold: true
                            color: textColor
                            font.pixelSize: fontBaseSize * 0.9
                            font.family: "Segoe UI, Arial, sans-serif"
                        }
                        TextField {
                            id: edadPaciente
                            Layout.preferredWidth: baseUnit * 10
                            Layout.preferredHeight: baseUnit * 4
                            placeholderText: "0"
                            validator: IntValidator { bottom: 0; top: 120 }
                            font.pixelSize: fontBaseSize * 0.9
                            font.family: "Segoe UI, Arial, sans-serif"
                            background: Rectangle {
                                color: whiteColor
                                border.color: borderColor
                                border.width: 1
                                radius: baseUnit * 0.6
                            }
                        }
                        Label {
                            text: "años"
                            color: textColor
                            font.pixelSize: fontBaseSize * 0.9
                            font.family: "Segoe UI, Arial, sans-serif"
                        }
                        Item { Layout.fillWidth: true }
                    }
                }
            }
            
            RowLayout {
                Layout.fillWidth: true
                Label {
                    Layout.preferredWidth: baseUnit * 12
                    text: "Especialidad:"
                    font.bold: true
                    color: textColor
                    font.pixelSize: fontBaseSize * 0.9
                    font.family: "Segoe UI, Arial, sans-serif"
                }
                ComboBox {
                    id: especialidadCombo
                    Layout.fillWidth: true
                    Layout.preferredHeight: baseUnit * 4
                    model: {
                        var list = ["Seleccionar especialidad..."]
                        for (var i = 0; i < especialidades.length; i++) {
                            list.push(especialidades[i].nombre + " - " + especialidades[i].doctor)
                        }
                        return list
                    }
                    onCurrentIndexChanged: {
                        if (currentIndex > 0) {
                            consultationForm.selectedEspecialidadIndex = currentIndex - 1
                            var especialidad = especialidades[consultationForm.selectedEspecialidadIndex]
                            if (consultationForm.consultationType === "Normal") {
                                consultationForm.calculatedPrice = especialidad.precioNormal
                            } else {
                                consultationForm.calculatedPrice = especialidad.precioEmergencia
                            }
                        } else {
                            consultationForm.selectedEspecialidadIndex = -1
                            consultationForm.calculatedPrice = 0.0
                        }
                    }
                    
                    contentItem: Label {
                        text: especialidadCombo.displayText
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
                Label {
                    Layout.preferredWidth: baseUnit * 12
                    text: "Tipo de Consulta:"
                    font.bold: true
                    color: textColor
                    font.pixelSize: fontBaseSize * 0.9
                    font.family: "Segoe UI, Arial, sans-serif"
                }
                
                RadioButton {
                    id: normalRadio
                    text: "Normal"
                    checked: true
                    onCheckedChanged: {
                        if (checked) {
                            consultationForm.consultationType = "Normal"
                            if (consultationForm.selectedEspecialidadIndex >= 0) {
                                var especialidad = especialidades[consultationForm.selectedEspecialidadIndex]
                                consultationForm.calculatedPrice = especialidad.precioNormal
                            }
                        }
                    }
                    
                    contentItem: Label {
                        text: normalRadio.text
                        font.pixelSize: fontBaseSize * 0.9
                        font.family: "Segoe UI, Arial, sans-serif"
                        color: textColor
                        leftPadding: normalRadio.indicator.width + normalRadio.spacing
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                
                RadioButton {
                    id: emergenciaRadio
                    text: "Emergencia"
                    onCheckedChanged: {
                        if (checked) {
                            consultationForm.consultationType = "Emergencia"
                            if (consultationForm.selectedEspecialidadIndex >= 0) {
                                var especialidad = especialidades[consultationForm.selectedEspecialidadIndex]
                                consultationForm.calculatedPrice = especialidad.precioEmergencia
                            }
                        }
                    }
                    
                    contentItem: Label {
                        text: emergenciaRadio.text
                        font.pixelSize: fontBaseSize * 0.9
                        font.family: "Segoe UI, Arial, sans-serif"
                        color: textColor
                        leftPadding: emergenciaRadio.indicator.width + emergenciaRadio.spacing
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                Item { Layout.fillWidth: true }
            }
            
            RowLayout {
                Layout.fillWidth: true
                Label {
                    Layout.preferredWidth: baseUnit * 12
                    text: "Precio:"
                    font.bold: true
                    color: textColor
                    font.pixelSize: fontBaseSize * 0.9
                    font.family: "Segoe UI, Arial, sans-serif"
                }
                Label {
                    text: consultationForm.selectedEspecialidadIndex >= 0 ? 
                          "Bs" + consultationForm.calculatedPrice.toFixed(2) : "Seleccione especialidad"
                    font.bold: true
                    font.pixelSize: fontBaseSize * 1.1
                    font.family: "Segoe UI, Arial, sans-serif"
                    color: consultationForm.consultationType === "Emergencia" ? "#92400E" : "#047857"
                }
                Item { Layout.fillWidth: true }
            }
            
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                
                Label {
                    text: "Detalles:"
                    font.bold: true
                    color: textColor
                    font.pixelSize: fontBaseSize * 0.9
                    font.family: "Segoe UI, Arial, sans-serif"
                }
                
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: baseUnit * 8
                    
                    TextArea {
                        id: detallesConsulta
                        placeholderText: "Descripción de la consulta, síntomas, observaciones..."
                        wrapMode: TextArea.Wrap
                        font.pixelSize: fontBaseSize * 0.9
                        font.family: "Segoe UI, Arial, sans-serif"
                        background: Rectangle {
                            color: whiteColor
                            border.color: borderColor
                            border.width: 1
                            radius: baseUnit
                        }
                    }
                }
            }
            
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                
                Button {
                    text: "Cancelar"
                    Layout.preferredHeight: baseUnit * 4
                    background: Rectangle {
                        color: lightGrayColor
                        radius: baseUnit
                    }
                    contentItem: Label {
                        text: parent.text
                        color: textColor
                        font.pixelSize: fontBaseSize * 0.9
                        font.family: "Segoe UI, Arial, sans-serif"
                        horizontalAlignment: Text.AlignHCenter
                    }
                    onClicked: {
                        nombrePaciente.text = ""
                        apellidoPaterno.text = ""
                        apellidoMaterno.text = ""
                        edadPaciente.text = ""
                        especialidadCombo.currentIndex = 0
                        normalRadio.checked = true
                        detallesConsulta.text = ""
                        showNewConsultationDialog = false
                        selectedRowIndex = -1
                        isEditMode = false
                        editingIndex = -1
                    }
                }
                
                Button {
                    text: isEditMode ? "Actualizar" : "Guardar"
                    enabled: consultationForm.selectedEspecialidadIndex >= 0 && 
                             nombrePaciente.text.length > 0
                    Layout.preferredHeight: baseUnit * 4
                    background: Rectangle {
                        color: parent.enabled ? primaryColor : "#bdc3c7"
                        radius: baseUnit
                    }
                    contentItem: Label {
                        text: parent.text
                        color: whiteColor
                        font.bold: true
                        font.pixelSize: fontBaseSize * 0.9
                        font.family: "Segoe UI, Arial, sans-serif"
                        horizontalAlignment: Text.AlignHCenter
                    }
                    onClicked: {
                        var nombreCompleto = nombrePaciente.text + " " + 
                                           apellidoPaterno.text + " " + 
                                           apellidoMaterno.text
                        
                        var especialidad = especialidades[consultationForm.selectedEspecialidadIndex]
                        var especialidadDoctor = especialidad.nombre + " - " + especialidad.doctor
                        
                        var consultaData = {
                            paciente: nombreCompleto.trim(),
                            especialidadDoctor: especialidadDoctor,
                            tipo: consultationForm.consultationType,
                            precio: consultationForm.calculatedPrice.toFixed(2),
                            fecha: new Date().toISOString().split('T')[0],
                            detalles: detallesConsulta.text || "Sin detalles adicionales"
                        }
                        
                        if (isEditMode && editingIndex >= 0) {
                            var consultaExistente = consultasListModel.get(editingIndex)
                            consultaData.consultaId = consultaExistente.consultaId
                            
                            consultasListModel.set(editingIndex, consultaData)
                            
                            for (var i = 0; i < consultasOriginales.length; i++) {
                                if (consultasOriginales[i].consultaId === consultaData.consultaId) {
                                    consultasOriginales[i] = consultaData
                                    break
                                }
                            }
                            
                            console.log("Consulta actualizada:", JSON.stringify(consultaData))
                        } else {
                            consultaData.consultaId = (getTotalConsultasCount() + 1).toString()
                            
                            consultasListModel.append(consultaData)
                            consultasOriginales.push(consultaData)
                            
                            console.log("Nueva consulta guardada:", JSON.stringify(consultaData))
                        }
                        
                        updatePaginatedModel()
                        
                        nombrePaciente.text = ""
                        apellidoPaterno.text = ""
                        apellidoMaterno.text = ""
                        edadPaciente.text = ""
                        especialidadCombo.currentIndex = 0
                        normalRadio.checked = true
                        detallesConsulta.text = ""
                        showNewConsultationDialog = false
                        selectedRowIndex = -1
                        isEditMode = false
                        editingIndex = -1
                    }
                }
            }
        }
    }
    function getTotalConsultasCount() {
        return consultasOriginales.length
    }
    
    Component.onCompleted: {
        console.log("🩺 Módulo Consultas iniciado - versión conectada")
        
        // Buscar ConsultaModel del AppController
        if (typeof appController !== 'undefined' && appController.consulta_model_instance) {
            consultaModel = appController.consulta_model_instance
            console.log("✅ ConsultaModel conectado")
            
            // Cargar datos iniciales
            Qt.createTimer(consultasRoot, function() {
                updatePaginatedModel()
            }, 500)
        } else {
            console.log("⚠️ ConsultaModel no disponible, esperando...")
            
            // Reintentar conexión cada segundo hasta encontrar el model
            var retryTimer = Qt.createQmlObject("import QtQuick 2.15; Timer { interval: 1000; running: true; repeat: true }", consultasRoot, "retryTimer")
            retryTimer.triggered.connect(function() {
                if (typeof appController !== 'undefined' && appController.consulta_model_instance) {
                    consultaModel = appController.consulta_model_instance
                    console.log("✅ ConsultaModel conectado (reintento)")
                    retryTimer.destroy()
                    
                    Qt.callLater(function() {
                        updatePaginatedModel()
                    })
                }
            })
        }
        
        console.log("📱 Elementos por página calculados:", itemsPerPageConsultas)
    }
    function obtenerEspecialidades() {
        var especialidades = ["Todas"]
        
        if (consultaModel && consultaModel.especialidades) {
            for (var i = 0; i < consultaModel.especialidades.length; i++) {
                var esp = consultaModel.especialidades[i]
                if (esp.text) {
                    especialidades.push(esp.text)
                }
            }
        }
        
        return especialidades
}
}