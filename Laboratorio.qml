import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import Clinica.Models 1.0
import "./components/laboratory"
import "./components/shared"

Item {
    id: laboratorioRoot
    objectName: "laboratorioRoot"

    //property var pacienteModel: appController ? appController.paciente_model_instance : null
    property var pacienteModel: null
    // Estados de UI
    property bool isCreatingExam: false
    property bool showLoadingAnimation: false
    property bool showNewLabTestDialog: false
    property bool isEditMode: false
    property int editingIndex: -1
    property int selectedRowIndex: -1

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
    readonly property color lineColor: "#D1D5DB"

    // PAGINACION ADAPTATIVA
    property int itemsPerPageLaboratorio: calcularElementosPorPagina()
    property int currentPageLaboratorio: 0
    property int totalPagesLaboratorio: 0

    // Datos originales
    property var analisisOriginales: []
    property var tiposAnalisisDB: []
    property var trabajadoresDB: []
  
    // Distribución de columnas responsive
    readonly property real colId: 0.04
    readonly property real colPaciente: 0.15
    readonly property real colAnalisis: 0.25
    readonly property real colTipo: 0.10
    readonly property real colPrecio: 0.10
    readonly property real colTrabajador: 0.15
    readonly property real colRegistradoPor: 0.15
    readonly property real colFecha: 0.06
    
    // MODELO DE LABORATORIO PYTHON
    LaboratorioModel {
        id: laboratorioModel
        
        onExamenesActualizados: {
            console.log("📊 Exámenes actualizados desde base de datos")
            cargarDatosDesdeModelo()
        }
        
        onOperacionExitosa: function(mensaje) {
            console.log("✅", mensaje)
            showSuccessMessage(mensaje)
        }
        
        onErrorOcurrido: function(mensaje, codigo) {
            console.error("❌", mensaje, codigo)
            showErrorMessage(mensaje)
        }
        
        onExamenCreado: function(datos) {
            console.log("🆕 Examen creado:", datos)
            cargarDatosDesdeModelo()
        }
        
        onExamenActualizado: function(datos) {
            console.log("📄 Examen actualizado:", datos)
            cargarDatosDesdeModelo()
        }
        
        onExamenEliminado: function(examenId) {
            console.log("🗑️ Examen eliminado:", examenId)
            cargarDatosDesdeModelo()
        }
    }

    // Modelos
    ListModel {
        id: analisisListModel
    }
    
    ListModel {
        id: analisisPaginadosModel
    }

    // RECALCULAR PAGINACION CUANDO CAMBIE EL TAMAÑO
    onHeightChanged: {
        var nuevosElementos = calcularElementosPorPagina()
        if (nuevosElementos !== itemsPerPageLaboratorio) {
            itemsPerPageLaboratorio = nuevosElementos
            updatePaginatedModel()
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
                
                // HEADER ACTUALIZADO
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: baseUnit * 12
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
                            
                            // Contenedor del icono con tamaño fijo
                            Rectangle {
                                Layout.preferredWidth: baseUnit * 8
                                Layout.preferredHeight: baseUnit * 8
                                color: "transparent"
                                
                                Image {
                                    id: laboratorioIcon
                                    anchors.centerIn: parent
                                    width: Math.min(baseUnit * 8, parent.width * 10)
                                    height: Math.min(baseUnit * 8, parent.height * 10)
                                    source: "Resources/iconos/Laboratorio.png"
                                    fillMode: Image.PreserveAspectFit
                                    antialiasing: true
                                    
                                    onStatusChanged: {
                                        if (status === Image.Error) {
                                            console.log("Error cargando PNG laboratorio:", source)
                                        } else if (status === Image.Ready) {
                                            console.log("PNG laboratorio cargado correctamente:", source)
                                        }
                                    }
                                }
                            }
                            
                            Label {
                                text: "Gestión de Análisis de Laboratorio"
                                font.pixelSize: fontBaseSize * 1.4
                                font.bold: true
                                font.family: "Segoe UI, Arial, sans-serif"
                                color: textColor
                            }
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        Button {
                            id: newLabTestBtn
                            objectName: "newLabTestButton"
                            Layout.preferredHeight: baseUnit * 5
                            Layout.preferredWidth: Math.max(baseUnit * 20, implicitWidth + baseUnit * 2)
                            Layout.alignment: Qt.AlignVCenter
                            
                            background: Rectangle {
                                color: newLabTestBtn.pressed ? Qt.darker(primaryColor, 1.1) : 
                                    newLabTestBtn.hovered ? Qt.lighter(primaryColor, 1.1) : primaryColor
                                radius: baseUnit * 1.2
                                border.width: 0
                                
                                // Animación suave del color
                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                            
                            contentItem: RowLayout {
                                spacing: baseUnit
                                
                                // Contenedor del icono del botón
                                Rectangle {
                                    Layout.preferredWidth: baseUnit * 3
                                    Layout.preferredHeight: baseUnit * 3
                                    color: "transparent"
                                    
                                    Image {
                                        id: addLabIcon
                                        anchors.centerIn: parent
                                        width: baseUnit * 2.5
                                        height: baseUnit * 2.5
                                        source: "Resources/iconos/Nueva_Consulta.png"
                                        fillMode: Image.PreserveAspectFit
                                        antialiasing: true
                                        
                                        onStatusChanged: {
                                            if (status === Image.Error) {
                                                console.log("Error cargando PNG del botón laboratorio:", source)
                                                // Mostrar un "+" si no hay icono
                                                visible = false
                                                fallbackText.visible = true
                                            } else if (status === Image.Ready) {
                                                console.log("PNG del botón laboratorio cargado correctamente:", source)
                                            }
                                        }
                                    }
                                    
                                    // Texto fallback si no hay icono
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
                                
                                // Texto del botón
                                Label {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: "Nuevo Análisis"
                                    color: whiteColor
                                    font.bold: true
                                    font.pixelSize: fontBaseSize
                                    font.family: "Segoe UI, Arial, sans-serif"
                                }
                            }
                            
                            onClicked: {
                                isEditMode = false
                                editingIndex = -1
                                showNewLabTestDialog = true
                            }
                            
                            // Efecto hover mejorado
                            HoverHandler {
                                id: labButtonHover
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }
                }
                
                // FILTROS
                LaboratoryFilters {
                    id: laboratoryFilters
                    Layout.fillWidth: true
                    Layout.preferredHeight: width < 800 ? baseUnit * 12 : baseUnit * 8
                    
                    // Propiedades pasadas
                    baseUnit: laboratorioRoot.baseUnit
                    fontBaseSize: laboratorioRoot.fontBaseSize
                    textColor: laboratorioRoot.textColor
                    borderColor: laboratorioRoot.borderColor
                    whiteColor: laboratorioRoot.whiteColor
                    
                    onFiltersChanged: function(fechaFilter, tipoFilter, searchText) {
                        aplicarFiltros(fechaFilter, tipoFilter, searchText)
                    }
                }
                
                // TABLA
                LaboratoryTable {
                    id: laboratoryTable
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.margins: baseUnit * 3
                    Layout.topMargin: 0
                    
                    // Propiedades pasadas
                    model: analisisPaginadosModel
                    selectedRowIndex: laboratorioRoot.selectedRowIndex
                    baseUnit: laboratorioRoot.baseUnit
                    fontBaseSize: laboratorioRoot.fontBaseSize
                    
                    // Colores
                    primaryColor: laboratorioRoot.primaryColor
                    successColorLight: laboratorioRoot.successColorLight
                    warningColorLight: laboratorioRoot.warningColorLight
                    dangerColor: laboratorioRoot.dangerColor
                    whiteColor: laboratorioRoot.whiteColor
                    textColor: laboratorioRoot.textColor
                    textColorLight: laboratorioRoot.textColorLight
                    borderColor: laboratorioRoot.borderColor
                    lightGrayColor: laboratorioRoot.lightGrayColor
                    lineColor: laboratorioRoot.lineColor
                    accentColor: laboratorioRoot.accentColor
                    warningColor: laboratorioRoot.warningColor
                    
                    // Columnas
                    colId: laboratorioRoot.colId
                    colPaciente: laboratorioRoot.colPaciente
                    colAnalisis: laboratorioRoot.colAnalisis
                    colTipo: laboratorioRoot.colTipo
                    colPrecio: laboratorioRoot.colPrecio
                    colTrabajador: laboratorioRoot.colTrabajador
                    colRegistradoPor: laboratorioRoot.colRegistradoPor
                    colFecha: laboratorioRoot.colFecha
                    
                    onRowSelected: function(index) {
                        selectedRowIndex = selectedRowIndex === index ? -1 : index
                    }
                    
                    onEditRequested: function(realIndex, analisisId) {
                        // Cambiar analisisId por parseInt(analisisId) si viene como string
                        var analisisIdNum = parseInt(analisisId)
                        
                        // Buscar en analisisListModel en lugar de analisisPaginadosModel
                        for (var i = 0; i < analisisListModel.count; i++) {
                            if (parseInt(analisisListModel.get(i).analisisId) === analisisIdNum) {
                                isEditMode = true
                                editingIndex = i
                                showNewLabTestDialog = true
                                return
                            }
                        }
                        showErrorMessage("No se pudo encontrar el análisis")
                    }
                    
                    onDeleteRequested: function(analisisId) {
                        deleteAnalisis(analisisId)
                    }
                }
                
                // PAGINACION
                LaboratoryPagination {
                    id: laboratoryPagination
                    Layout.fillWidth: true
                    Layout.preferredHeight: baseUnit * 6
                    Layout.margins: baseUnit * 3
                    Layout.topMargin: 0
                    
                    // Propiedades pasadas
                    currentPage: currentPageLaboratorio
                    totalPages: totalPagesLaboratorio
                    baseUnit: laboratorioRoot.baseUnit
                    fontBaseSize: laboratorioRoot.fontBaseSize
                    successColor: laboratorioRoot.successColor
                    whiteColor: laboratorioRoot.whiteColor
                    textColor: laboratorioRoot.textColor
                    lightGrayColor: laboratorioRoot.lightGrayColor
                    borderColor: laboratorioRoot.borderColor
                    
                    onPreviousPage: {
                        if (currentPageLaboratorio > 0) {
                            currentPageLaboratorio--
                            updatePaginatedModel()
                        }
                    }
                    
                    onNextPage: {
                        if (currentPageLaboratorio < totalPagesLaboratorio - 1) {
                            currentPageLaboratorio++
                            updatePaginatedModel()
                        }
                    }
                }
            }
        }
    }

    // DIÁLOGO ACTUALIZADO CON NUEVO DISEÑO
    
    // Fondo del diálogo (sin oscurecer)
    Rectangle {
        id: dialogBackground
        anchors.fill: parent
        color: "transparent"
        opacity: showNewLabTestDialog ? 1 : 0
        visible: opacity > 0
        z: 1000
        
        MouseArea {
            anchors.fill: parent
            onClicked: {
                limpiarYCerrarDialogo()
            }
        }
        
        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }
    }
    
    // Diálogo de análisis adaptativo - Diseño IDÉNTICO a Consulta
    Rectangle {
        id: labTestForm
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.95, 700)  // Más ancho para mejor uso del espacio
        height: Math.min(parent.height * 0.95, 800)  // Más alto pero con mejor distribución
        color: whiteColor
        radius: baseUnit * 1.5  // Bordes más redondeados
        border.color: "#DDD"
        border.width: 1
        visible: showNewLabTestDialog

        // Efecto de sombra simple
        Rectangle {
            anchors.fill: parent
            anchors.margins: -baseUnit
            color: "transparent"
            radius: parent.radius + baseUnit
            border.color: "#20000000"
            border.width: baseUnit
            z: -1
        }
        
        property int selectedTipoAnalisisIndex: -1
        property string analisisType: "Normal"
        property real calculatedPrice: 0.0
        
        function loadEditData() {
            if (isEditMode && editingIndex >= 0) {
                var analisis = analisisListModel.get(editingIndex)
                // Cargar datos del paciente
                nombrePaciente.text = analisis.pacienteNombre || ""
                apellidoPaterno.text = analisis.pacienteApellidoP || ""
                apellidoMaterno.text = analisis.pacienteApellidoM || ""
                edadPaciente.text = analisis.pacienteEdad ? analisis.pacienteEdad.toString() : "0"
                
                var tienePatiente = nombrePaciente.text.length > 0
                apellidoPaterno.pacienteAutocompletado = tienePatiente
                apellidoMaterno.pacienteAutocompletado = tienePatiente
                edadPaciente.pacienteAutocompletado = tienePatiente
                
                // Limpiar overlay
                patientOverlay.close()
                
                // Cargar detalles específicos del examen
                if (analisis.detallesExamen !== undefined && analisis.detallesExamen !== "") {
                    detallesConsulta.text = analisis.detallesExamen
                } else {
                    detallesConsulta.text = ""
                }
                
                // Cargar tipo de análisis
                var tipoAnalisisNombre = analisis.tipoAnalisis
                var encontrado = false
                for (var i = 0; i < tiposAnalisisDB.length; i++) {
                    if (tiposAnalisisDB[i].nombre === tipoAnalisisNombre) {
                        tipoAnalisisCombo.currentIndex = i + 1
                        labTestForm.selectedTipoAnalisisIndex = i
                        encontrado = true
                        break
                    }
                }
                
                if (!encontrado) {
                    tipoAnalisisCombo.currentIndex = 0
                    labTestForm.selectedTipoAnalisisIndex = -1
                }
                
                // Cargar tipo de servicio
                if (analisis.tipo === "Normal") {
                    normalRadio.checked = true
                    labTestForm.analisisType = "Normal"
                } else {
                    emergenciaRadio.checked = true
                    labTestForm.analisisType = "Emergencia"
                }
                
                // Calcular precio
                updatePrice()
                
                // Cargar trabajador asignado
                var trabajadorEncontrado = false
                for (var j = 0; j < trabajadoresDB.length; j++) {
                    if (trabajadoresDB[j].nombre === analisis.trabajadorAsignado) {
                        trabajadorCombo.currentIndex = j + 1
                        trabajadorEncontrado = true
                        break
                    }
                }
                
                if (!trabajadorEncontrado) {
                    trabajadorCombo.currentIndex = 0
                }
            }
        }
        
        function updatePrice() {
            if (labTestForm.selectedTipoAnalisisIndex >= 0) {
                var tipoAnalisis = tiposAnalisisDB[labTestForm.selectedTipoAnalisisIndex]
                if (labTestForm.analisisType === "Normal") {
                    labTestForm.calculatedPrice = tipoAnalisis.precioNormal
                } else {
                    labTestForm.calculatedPrice = tipoAnalisis.precioEmergencia
                }
            } else {
                labTestForm.calculatedPrice = 0.0
            }
        }
        
        onVisibleChanged: {
            if (visible) {
                if (isEditMode) {
                    loadEditData()
                } else {
                    clearAllFields()
                }
            }
        }
        
        // HEADER MEJORADO CON CIERRE - IDÉNTICO A CONSULTA
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
                text: isEditMode ? "EDITAR ANÁLISIS" : "NUEVO ANÁLISIS"
                font.pixelSize: fontBaseSize * 1.2
                font.bold: true
                color: whiteColor
                font.family: "Segoe UI, Arial, sans-serif"
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
                    limpiarYCerrarDialogo()
                }
            }
        }
        
        // SCROLLVIEW PRINCIPAL CON MÁRGENES ADECUADOS - IDÉNTICO A CONSULTA
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
            
            // CONTENEDOR PRINCIPAL DEL FORMULARIO - IDÉNTICO A CONSULTA
            ColumnLayout {
                width: scrollView.width - (baseUnit * 1)
                spacing: baseUnit * 2
                
                // DATOS DEL PACIENTE - IDÉNTICO A CONSULTA
                GroupBox {
                    Layout.fillWidth: true
                    title: "DATOS DEL PACIENTE"
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
                        anchors.fill: parent
                        spacing: baseUnit
                        
                        // Campo de búsqueda principal
                        TextField {
                            id: nombrePaciente
                            Layout.fillWidth: true
                            Layout.preferredHeight: baseUnit * 4
                            placeholderText: "Escriba el nombre del paciente para buscar..."
                            font.pixelSize: fontBaseSize * 0.9
                            font.family: "Segoe UI, Arial, sans-serif"
                            
                            background: Rectangle {
                                color: whiteColor
                                border.color: nombrePaciente.activeFocus ? primaryColor : "#ddd"
                                border.width: 1
                                radius: baseUnit * 0.5
                                
                                Text {
                                    anchors.right: parent.right
                                    anchors.rightMargin: baseUnit
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "🔍"
                                    font.pixelSize: fontBaseSize * 1.2
                                    visible: nombrePaciente.text.length >= 2
                                }
                            }
                            padding: baseUnit
                            
                            onTextChanged: {
                                if (text.length >= 2) {
                                    patientOverlay.search(text)
                                } else {
                                    patientOverlay.close()
                                }
                            }
                            
                            onFocusChanged: {
                                if (focus && text.length >= 2) {
                                    patientOverlay.search(text)
                                }
                            }
                            
                            Keys.onPressed: (event) => {
                                if (patientOverlay.visible) {
                                    if (event.key === Qt.Key_Down) {
                                        event.accepted = true
                                        patientOverlay.navigateDown()
                                    } else if (event.key === Qt.Key_Up) {
                                        event.accepted = true
                                        patientOverlay.navigateUp()
                                    } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                                        event.accepted = true
                                        patientOverlay.selectCurrent()
                                    } else if (event.key === Qt.Key_Escape) {
                                        event.accepted = true
                                        patientOverlay.close()
                                    }
                                } else if (event.key === Qt.Key_Down && text.length >= 2) {
                                    event.accepted = true
                                    patientOverlay.search(text)
                                    patientOverlay.navigateDown()
                                }
                            }
                        }
                        
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: baseUnit * 2
                            rowSpacing: baseUnit * 1.5
                            
                            Label {
                                text: "Apellido Paterno:"
                                font.bold: true
                                color: textColor
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                            
                            TextField {
                                id: apellidoPaterno
                                Layout.fillWidth: true
                                placeholderText: "Apellido paterno"
                                font.pixelSize: fontBaseSize
                                font.family: "Segoe UI, Arial, sans-serif"
                                readOnly: pacienteAutocompletado
                                
                                property bool pacienteAutocompletado: false
                                
                                background: Rectangle {
                                    color: apellidoPaterno.pacienteAutocompletado ? "#F0F8FF" : whiteColor
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
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                            
                            TextField {
                                id: apellidoMaterno
                                Layout.fillWidth: true
                                placeholderText: "Apellido materno"
                                font.pixelSize: fontBaseSize
                                font.family: "Segoe UI, Arial, sans-serif"
                                readOnly: pacienteAutocompletado
                                
                                property bool pacienteAutocompletado: false
                                
                                background: Rectangle {
                                    color: apellidoMaterno.pacienteAutocompletado ? "#F0F8FF" : whiteColor
                                    border.color: "#ddd"
                                    border.width: 1
                                    radius: baseUnit * 0.5
                                }
                                padding: baseUnit
                            }
                            
                            Label {
                                text: "Edad:"
                                font.bold: true
                                color: textColor
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                            
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: baseUnit
                                
                                TextField {
                                    id: edadPaciente
                                    Layout.preferredWidth: baseUnit * 10
                                    placeholderText: "0"
                                    font.pixelSize: fontBaseSize
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    validator: IntValidator { bottom: 0; top: 120 }
                                    readOnly: pacienteAutocompletado
                                    
                                    property bool pacienteAutocompletado: false
                                    
                                    background: Rectangle {
                                        color: edadPaciente.pacienteAutocompletado ? "#F0F8FF" : whiteColor
                                        border.color: "#ddd"
                                        border.width: 1
                                        radius: baseUnit * 0.5
                                    }
                                    padding: baseUnit
                                }
                                
                                Label {
                                    text: "años"
                                    color: textColorLight
                                    font.family: "Segoe UI, Arial, sans-serif"
                                }
                                
                                TextField {
                                    id: cedulaPaciente
                                    visible: false
                                }
                                
                                Item { Layout.fillWidth: true }
                                
                                Button {
                                    text: "Nuevo Paciente"
                                    visible: !apellidoPaterno.pacienteAutocompletado && nombrePaciente.text.length > 0
                                    Layout.preferredHeight: baseUnit * 3
                                    
                                    background: Rectangle {
                                        color: "#D1FAE5"
                                        border.color: "#10B981"
                                        border.width: 1
                                        radius: baseUnit * 0.5
                                    }
                                    
                                    contentItem: Label {
                                        text: parent.text
                                        color: "#047857"
                                        font.pixelSize: fontBaseSize * 0.8
                                        font.family: "Segoe UI, Arial, sans-serif"
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    
                                    onClicked: {
                                        limpiarSeleccionPaciente()
                                        edadPaciente.forceActiveFocus()
                                    }
                                }
                                
                                Button {
                                    text: "Limpiar"
                                    visible: apellidoPaterno.pacienteAutocompletado
                                    Layout.preferredHeight: baseUnit * 3
                                    
                                    background: Rectangle {
                                        color: "#FEE2E2"
                                        border.color: "#F87171"
                                        border.width: 1
                                        radius: baseUnit * 0.5
                                    }
                                    
                                    contentItem: Label {
                                        text: parent.text
                                        color: "#B91C1C"
                                        font.pixelSize: fontBaseSize * 0.8
                                        font.family: "Segoe UI, Arial, sans-serif"
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    
                                    onClicked: limpiarSeleccionPaciente()
                                }
                            }
                        }
                    }
                }
                
                // INFORMACIÓN DEL ANÁLISIS - IDÉNTICO A CONSULTA
                GroupBox {
                    Layout.fillWidth: true
                    title: "INFORMACIÓN DEL ANÁLISIS"
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
                        
                        // Tipo de Análisis
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit * 2
                            
                            Label {
                                text: "Análisis:"
                                font.bold: true
                                Layout.preferredWidth: baseUnit * 15
                                color: textColor
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                            
                            ComboBox {
                                id: tipoAnalisisCombo
                                Layout.fillWidth: true
                                font.pixelSize: fontBaseSize
                                font.family: "Segoe UI, Arial, sans-serif"
                                model: {
                                    var list = ["Seleccionar análisis..."]
                                    for (var i = 0; i < tiposAnalisisDB.length; i++) {
                                        list.push(tiposAnalisisDB[i].nombre)
                                    }
                                    return list
                                }
                                onCurrentIndexChanged: {
                                    if (currentIndex > 0) {
                                        labTestForm.selectedTipoAnalisisIndex = currentIndex - 1
                                        labTestForm.updatePrice()
                                    } else {
                                        labTestForm.selectedTipoAnalisisIndex = -1
                                        labTestForm.calculatedPrice = 0.0
                                    }
                                }
                                
                                contentItem: Label {
                                    text: tipoAnalisisCombo.displayText
                                    font.pixelSize: fontBaseSize
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    color: textColor
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: baseUnit
                                    elide: Text.ElideRight
                                }
                                
                                background: Rectangle {
                                    color: whiteColor
                                    border.color: "#ddd"
                                    border.width: 1
                                    radius: baseUnit * 0.5
                                }
                                
                                popup: Popup {
                                    width: tipoAnalisisCombo.width
                                    implicitHeight: contentItem.implicitHeight + baseUnit
                                    padding: 1
                                    
                                    contentItem: ListView {
                                        clip: true
                                        implicitHeight: contentHeight
                                        model: tipoAnalisisCombo.popup.visible ? tipoAnalisisCombo.delegateModel : null
                                        currentIndex: tipoAnalisisCombo.highlightedIndex
                                        
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
                        
                        // Realizado por
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit * 2
                            
                            Label {
                                text: "Realizado por:"
                                font.bold: true
                                Layout.preferredWidth: baseUnit * 15
                                color: textColor
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                            
                            ComboBox {
                                id: trabajadorCombo
                                Layout.fillWidth: true
                                font.pixelSize: fontBaseSize
                                font.family: "Segoe UI, Arial, sans-serif"

                                property var trabajadoresDisponibles: trabajadoresDB

                                model: {
                                    var list = ["Seleccionar trabajador..."]
                                    for (var i = 0; i < trabajadoresDisponibles.length; i++) {
                                        var nombre = trabajadoresDisponibles[i].nombre || "Sin nombre"
                                        list.push(nombre)
                                    }
                                    list.push("Sin asignar")
                                    return list
                                }
                                onTrabajadoresDisponiblesChanged: {
                                    var currentModel = model
                                }
                                
                                contentItem: Label {
                                    text: trabajadorCombo.displayText
                                    font.pixelSize: fontBaseSize
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    color: textColor
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: baseUnit
                                    elide: Text.ElideRight
                                }
                                
                                background: Rectangle {
                                    color: whiteColor
                                    border.color: "#ddd"
                                    border.width: 1
                                    radius: baseUnit * 0.5
                                }
                                
                                popup: Popup {
                                    width: trabajadorCombo.width
                                    implicitHeight: contentItem.implicitHeight + baseUnit
                                    padding: 1
                                    
                                    contentItem: ListView {
                                        clip: true
                                        implicitHeight: contentHeight
                                        model: trabajadorCombo.popup.visible ? trabajadorCombo.delegateModel : null
                                        currentIndex: trabajadorCombo.highlightedIndex
                                        
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
                        
                        // Tipo de análisis
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit * 2
                            
                            Label {
                                text: "Tipo:"
                                font.bold: true
                                Layout.preferredWidth: baseUnit * 15
                                color: textColor
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                            
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: baseUnit * 3
                                
                                RadioButton {
                                    id: normalRadio
                                    text: "Normal"
                                    font.pixelSize: fontBaseSize
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    checked: true
                                    onCheckedChanged: {
                                        if (checked) {
                                            labTestForm.analisisType = "Normal"
                                            labTestForm.updatePrice()
                                        }
                                    }
                                    
                                    contentItem: Label {
                                        text: normalRadio.text
                                        font.pixelSize: fontBaseSize
                                        font.family: "Segoe UI, Arial, sans-serif"
                                        color: textColor
                                        leftPadding: normalRadio.indicator.width + normalRadio.spacing
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                                
                                RadioButton {
                                    id: emergenciaRadio
                                    text: "Emergencia"
                                    font.pixelSize: fontBaseSize
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    onCheckedChanged: {
                                        if (checked) {
                                            labTestForm.analisisType = "Emergencia"
                                            labTestForm.updatePrice()
                                        }
                                    }
                                    
                                    contentItem: Label {
                                        text: emergenciaRadio.text
                                        font.pixelSize: fontBaseSize
                                        font.family: "Segoe UI, Arial, sans-serif"
                                        color: textColor
                                        leftPadding: emergenciaRadio.indicator.width + emergenciaRadio.spacing
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                                
                                Item { Layout.fillWidth: true }
                            }
                        }
                    }
                }
                
                // INFORMACIÓN DE PRECIO - IDÉNTICO A CONSULTA
                GroupBox {
                    Layout.fillWidth: true
                    title: "INFORMACIÓN DE PRECIO"
                    font.bold: true
                    font.pixelSize: fontBaseSize
                    font.family: "Segoe UI, Arial, sans-serif"
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
                        
                        Label {
                            text: labTestForm.selectedTipoAnalisisIndex >= 0 ? 
                                "Bs " + labTestForm.calculatedPrice.toFixed(2) : "Seleccione análisis"
                            font.bold: true
                            font.pixelSize: fontBaseSize * 1.1
                            font.family: "Segoe UI, Arial, sans-serif"
                            color: labTestForm.analisisType === "Emergencia" ? warningColor : successColor
                            padding: baseUnit
                            background: Rectangle {
                                color: labTestForm.analisisType === "Emergencia" ? warningColorLight : successColorLight
                                radius: baseUnit * 0.8
                            }
                        }
                    }
                }
                
                // DETALLES ADICIONALES - IDÉNTICO A CONSULTA
                GroupBox {
                    Layout.fillWidth: true
                    title: "DETALLES ADICIONALES"
                    font.bold: true
                    font.pixelSize: fontBaseSize
                    font.family: "Segoe UI, Arial, sans-serif"
                    padding: baseUnit * 1.5
                    
                    background: Rectangle {
                        color: "#f8f9fa"
                        border.color: "#e0e0e0"
                        radius: baseUnit * 0.8
                    }
                    
                    TextArea {
                        id: detallesConsulta
                        Layout.fillWidth: true
                        Layout.preferredHeight: baseUnit * 12
                        placeholderText: "Descripción adicional del análisis, observaciones especiales..."
                        font.pixelSize: fontBaseSize
                        font.family: "Segoe UI, Arial, sans-serif"
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
        
        // BOTONES INFERIORES - IDÉNTICO A CONSULTA
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
                    font.family: "Segoe UI, Arial, sans-serif"
                    color: textColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: {
                    limpiarYCerrarDialogo()
                }
            }
            
            Button {
                id: saveButton
                text: {
                    if (isCreatingExam) return "Procesando..."
                    return isEditMode ? "Actualizar" : "Guardar"
                }
                enabled: labTestForm.selectedTipoAnalisisIndex >= 0 && 
                    nombrePaciente.text.length >= 2 && 
                    apellidoPaterno.text.length >= 2 &&
                    edadPaciente.text.length > 0 && 
                    !isCreatingExam
                Layout.preferredWidth: baseUnit * 15
                Layout.preferredHeight: baseUnit * 4.5
                
                background: Rectangle {
                    color: {
                        if (!parent.enabled) return "#bdc3c7"
                        if (isCreatingExam) return "#3498DB" 
                        return primaryColor
                    }
                    radius: baseUnit * 0.8
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
                    guardarAnalisis()
                }
            }
        }
    }

    // Overlay de búsqueda de pacientes
    PatientSearchOverlay {
        id: patientOverlay
        pacienteModel: laboratorioRoot.pacienteModel
        parent: labTestForm
        x: nombrePaciente.x
        y: nombrePaciente.y + nombrePaciente.height + 5
        width: nombrePaciente.width
        z: 2000
        
        onPatientSelected: function(patientData) {
            console.log("Paciente seleccionado:", patientData.nombre_completo)
            
            // Auto-completar campos
            nombrePaciente.text = patientData.nombre
            apellidoPaterno.text = patientData.apellido_paterno
            apellidoMaterno.text = patientData.apellido_materno
            edadPaciente.text = patientData.edad.toString()
            cedulaPaciente.text = patientData.cedula || ""
            
            // Marcar como autocompletado
            apellidoPaterno.pacienteAutocompletado = true
            apellidoMaterno.pacienteAutocompletado = true
            edadPaciente.pacienteAutocompletado = true
            
            // Focus al siguiente campo
            tipoAnalisisCombo.forceActiveFocus()
            
            showSuccessMessage("Paciente seleccionado: " + patientData.nombre_completo)
        }
        
        onNewPatientRequested: function(searchTerm) {
            var partes = searchTerm.split(' ')
            var nombre = partes[0] || ""
            var apellidoP = partes[1] || ""
            var apellidoM = partes.length > 2 ? partes.slice(2).join(' ') : ""
            
            nombrePaciente.text = nombre
            apellidoPaterno.text = apellidoP
            apellidoMaterno.text = apellidoM
            
            apellidoPaterno.pacienteAutocompletado = false
            apellidoMaterno.pacienteAutocompletado = false
            edadPaciente.pacienteAutocompletado = false
            
            edadPaciente.forceActiveFocus()
        }
    }

    // ===== FUNCIONES JAVASCRIPT =====
    
    function calcularElementosPorPagina() {
        var alturaDisponible = height - baseUnit * 25
        var alturaFila = baseUnit * 6
        var elementosCalculados = Math.floor(alturaDisponible / alturaFila)
        
        return Math.max(8, Math.min(elementosCalculados, 20))
    }
    
    function aplicarFiltros(fechaFilter, tipoFilter, searchText) {
        console.log("🔍 Aplicando filtros en laboratorio...")
        
        analisisListModel.clear()
        
        var hoy = new Date()
        var textoBusqueda = searchText ? searchText.toLowerCase() : ""
        
        for (var i = 0; i < analisisOriginales.length; i++) {
            var analisis = analisisOriginales[i]
            var mostrar = true
            
            // Filtro por fecha
            if (fechaFilter > 0) {
                var fechaAnalisis = new Date(analisis.fecha)
                var diferenciaDias = Math.floor((hoy - fechaAnalisis) / (1000 * 60 * 60 * 24))
                
                switch(fechaFilter) {
                    case 1: // Hoy
                        if (diferenciaDias !== 0) mostrar = false
                        break
                    case 2: // Esta Semana
                        if (diferenciaDias > 7) mostrar = false
                        break
                    case 3: // Este Mes
                        if (diferenciaDias > 30) mostrar = false
                        break
                }
            }
            
            // Filtro por tipo
            if (tipoFilter > 0 && mostrar) {
                var tipoSeleccionado = tipoFilter === 1 ? "Normal" : "Emergencia"
                if (analisis.tipo !== tipoSeleccionado) {
                    mostrar = false
                }
            }
            
            // Filtro por texto de búsqueda
            if (textoBusqueda.length > 0 && mostrar) {
                if (!analisis.paciente.toLowerCase().includes(textoBusqueda)) {
                    mostrar = false
                }
            }
            
            if (mostrar) {
                analisisListModel.append(analisis)
            }
        }
        
        currentPageLaboratorio = 0
        updatePaginatedModel()
        
        console.log("✅ Filtros aplicados. Análisis mostrados:", analisisListModel.count)
    }

    function updatePaginatedModel() {
        console.log("📄 Laboratorio: Actualizando paginación - Página:", currentPageLaboratorio + 1)
        
        analisisPaginadosModel.clear()
        
        var totalItems = analisisListModel.count
        totalPagesLaboratorio = Math.ceil(totalItems / itemsPerPageLaboratorio)
        
        if (totalPagesLaboratorio === 0) {
            totalPagesLaboratorio = 1
        }
        
        if (currentPageLaboratorio >= totalPagesLaboratorio && totalPagesLaboratorio > 0) {
            currentPageLaboratorio = totalPagesLaboratorio - 1
        }
        if (currentPageLaboratorio < 0) {
            currentPageLaboratorio = 0
        }
        
        var startIndex = currentPageLaboratorio * itemsPerPageLaboratorio
        var endIndex = Math.min(startIndex + itemsPerPageLaboratorio, totalItems)
        
        for (var i = startIndex; i < endIndex; i++) {
            var analisis = analisisListModel.get(i)
            analisisPaginadosModel.append(analisis)
        }
        
        console.log("📄 Laboratorio: Página", currentPageLaboratorio + 1, "de", totalPagesLaboratorio,
                    "- Mostrando", analisisPaginadosModel.count, "de", totalItems,
                    "- Elementos por página:", itemsPerPageLaboratorio)
    }

    function openEditDialog(realIndex, analisisId) {
        // Buscar por ID numérico, no string
        var idToFind = parseInt(analisisId)
        var realIndex = -1
        
        for (var i = 0; i < analisisListModel.count; i++) {
            if (parseInt(analisisListModel.get(i).analisisId) === idToFind) {
                realIndex = i
                break
            }
        }
        
        if (realIndex >= 0) {
            isEditMode = true
            editingIndex = realIndex
            showNewLabTestDialog = true
        } else {
            console.error("Análisis no encontrado:", idToFind)
            showErrorMessage("No se encontró el análisis")
        }
    }

    function deleteAnalisis(analisisId) {
        var analisisIdInt = parseInt(analisisId)
        var exito = laboratorioModel.eliminarExamen(analisisIdInt)
        
        if (exito) {
            selectedRowIndex = -1
            console.log("✅ Análisis eliminado exitosamente:", analisisIdInt)
        } else {
            console.error("❌ Error eliminando análisis:", analisisIdInt)
        }
    }

    function guardarAnalisis() {
        if (labTestForm.selectedTipoAnalisisIndex < 0) {
            showErrorMessage("Debe seleccionar un tipo de análisis")
            return
        }
        if (nombrePaciente.text.trim().length < 2) {
            showErrorMessage("Nombre del paciente es obligatorio")
            return
        }
        if (!edadPaciente.text || parseInt(edadPaciente.text) < 0) {
            showErrorMessage("Edad del paciente es obligatoria") 
            return
        }

        isCreatingExam = true
        
        function finalizarProceso(exito, mensaje) {
            isCreatingExam = false
            if (exito) {
                showSuccessMessage(mensaje)
                limpiarYCerrarDialogo()
            } else {
                showErrorMessage(mensaje)
            }
        }
        
        try {
            if (isEditMode && editingIndex >= 0) {
                // Actualizar examen existente
                var analisisExistente = analisisListModel.get(editingIndex)
                var tipoAnalisisId = tiposAnalisisDB[labTestForm.selectedTipoAnalisisIndex].id
                
                var trabajadorId = (trabajadorCombo.currentIndex > 0) ? 
                    trabajadoresDB[trabajadorCombo.currentIndex - 1].id : 0
                
                var resultado = laboratorioModel.actualizarExamen(
                    parseInt(analisisExistente.analisisId),
                    tipoAnalisisId,
                    labTestForm.analisisType,
                    trabajadorId,
                    detallesConsulta.text
                )
                
                var data = JSON.parse(resultado)
                finalizarProceso(data.exito, data.exito ? "Examen actualizado exitosamente" : "Error: " + data.error)
            } else {
                // Crear nuevo examen
                var nombre = nombrePaciente.text.trim()
                var apellidoP = apellidoPaterno.text.trim()
                var apellidoM = apellidoMaterno.text.trim()
                var edad = parseInt(edadPaciente.text) || 0
                
                var pacienteId = buscarOCrearPacienteSeguro(nombre, apellidoP, apellidoM, edad)
                
                if (pacienteId <= 0) {
                    finalizarProceso(false, "Error gestionando datos del paciente")
                    return
                }
                
                var tipoAnalisisId = tiposAnalisisDB[labTestForm.selectedTipoAnalisisIndex].id
                var trabajadorId = (trabajadorCombo.currentIndex > 0) ? 
                    trabajadoresDB[trabajadorCombo.currentIndex - 1].id : 0
                
                var resultado = laboratorioModel.crearExamen(
                    pacienteId,
                    tipoAnalisisId,
                    labTestForm.analisisType,
                    trabajadorId,
                    detallesConsulta.text
                )
                
                var data = JSON.parse(resultado)
                finalizarProceso(data.exito, data.exito ? "Examen creado exitosamente" : "Error: " + data.error)
            }
        } catch (error) {
            finalizarProceso(false, "Error inesperado: " + error)
        }
    }

    function buscarOCrearPacienteSeguro(nombre, apellidoP, apellidoM, edad) {
        console.log("Buscando/creando paciente:", nombre, apellidoP, apellidoM, edad)
        
        if (!nombre || nombre.trim().length < 2) {
            showErrorMessage("Nombre es obligatorio para análisis de laboratorio")
            return -1
        }
        if (!edad || edad < 0) {
            showErrorMessage("Edad es obligatoria para análisis de laboratorio")
            return -1
        }

        // Intentar reconectar si no está disponible
        if (!pacienteModel && typeof appController !== 'undefined') {
            pacienteModel = appController.paciente_model_instance
            console.log("Reconectando a PacienteModel:", pacienteModel ? "éxito" : "falló")
        }

        // Usar pacienteModel si está disponible
        if (pacienteModel && typeof pacienteModel.buscarOCrearPacienteInteligente === 'function') {
            console.log("Usando PacienteModel para crear/buscar paciente")
            var pacienteId = pacienteModel.buscarOCrearPacienteInteligente(
                nombre, apellidoP, apellidoM, edad
            )
            console.log("Paciente ID obtenido:", pacienteId)
            return pacienteId
        }
        
        // Fallback - buscar en los pacientes existentes
        for (var i = 0; i < analisisOriginales.length; i++) {
            var analisis = analisisOriginales[i]
            if (analisis.paciente.toLowerCase().includes(nombre.toLowerCase()) &&
                analisis.paciente.toLowerCase().includes(apellidoP.toLowerCase())) {
                console.log("Paciente existente encontrado:", analisis.pacienteId)
                return analisis.pacienteId
            }
        }
        
        console.log("Creando paciente temporal con ID negativo")
        return -9999
    }

    function limpiarYCerrarDialogo() {
        showNewLabTestDialog = false
        selectedRowIndex = -1
        isEditMode = false
        editingIndex = -1
    }
    
    function clearAllFields() {
        nombrePaciente.text = ""
        apellidoPaterno.text = ""
        apellidoMaterno.text = ""
        edadPaciente.text = ""
        detallesConsulta.text = ""
        cedulaPaciente.text = ""
        tipoAnalisisCombo.currentIndex = 0
        trabajadorCombo.currentIndex = 0
        normalRadio.checked = true
        
        labTestForm.selectedTipoAnalisisIndex = -1
        labTestForm.calculatedPrice = 0.0
        
        apellidoPaterno.pacienteAutocompletado = false
        apellidoMaterno.pacienteAutocompletado = false
        edadPaciente.pacienteAutocompletado = false
        
        patientOverlay.close()
        nombrePaciente.forceActiveFocus()
    }
    
    function limpiarSeleccionPaciente() {
        nombrePaciente.text = ""
        apellidoPaterno.text = ""
        apellidoMaterno.text = ""
        edadPaciente.text = ""
        cedulaPaciente.text = ""
        
        apellidoPaterno.pacienteAutocompletado = false
        apellidoMaterno.pacienteAutocompletado = false
        edadPaciente.pacienteAutocompletado = false
        
        patientOverlay.close()
        nombrePaciente.forceActiveFocus()
    }
    
    function getTotalLaboratorioCount() {
        return analisisOriginales.length
    }
    
    function cargarDatosDesdeModelo() {
        try {
            var examenesJson = laboratorioModel.examenesJson
            var examenes = JSON.parse(examenesJson)
            
            analisisOriginales = []
            analisisListModel.clear()
            
            for (var i = 0; i < examenes.length; i++) {
                var examen = examenes[i]
                
                var precio = 0
                if (examen.Tipo === "Emergencia") {
                    precio = examen.Precio_Emergencia || 0
                } else {
                    precio = examen.Precio_Normal || 0
                }
                
                var descripcionCompleta = examen.detalles_analisis || "Sin descripción"
                if (examen.detalles_examen && examen.detalles_examen !== "") {
                    descripcionCompleta += "\nDetalles: " + examen.detalles_examen
                }
                
                var analisisItem = {
                    analisisId: (examen.id || i + 1).toString(),
                    paciente: examen.paciente_completo || "Paciente Desconocido",
                    tipoAnalisis: examen.tipo_analisis || "Análisis General",
                    detalles: descripcionCompleta,
                    detallesTipoAnalisis: examen.detalles_analisis || "Descripción no disponible",
                    detallesExamen: examen.detalles_examen || "",
                    tipo: examen.Tipo || "Normal",
                    precio: precio.toFixed(2),
                    trabajadorAsignado: (examen.trabajador_completo && examen.trabajador_completo !== "Sin asignar") ? 
                                    examen.trabajador_completo : "",
                    fecha: new Date(examen.Fecha).toISOString().split('T')[0],
                    registradoPor: examen.registrado_por || "Usuario Sistema",
                    tipoAnalisisId: examen.Id_Tipo_Analisis,
                    pacienteId: examen.Id_Paciente,
                    pacienteEdad: examen.paciente_edad || 0,
                    pacienteNombre: examen.paciente_nombre || "",
                    pacienteApellidoP: examen.paciente_apellido_p || "",
                    pacienteApellidoM: examen.paciente_apellido_m || ""
                }
                
                analisisOriginales.push(analisisItem)
                analisisListModel.append(analisisItem)
            }
            
            updatePaginatedModel()
            console.log("📊 Datos cargados desde BD:", analisisOriginales.length, "exámenes")
            
        } catch (error) {
            console.error("❌ Error cargando datos:", error)
        }
    }
    
    function cargarTiposAnalisisDB() {
        try {
            var resultado = laboratorioModel.obtenerTiposAnalisisDisponibles()
            console.log("📝 Resultado tipos análisis:", resultado)
            
            var data = JSON.parse(resultado)
            
            if (data.exito && data.tipos) {
                tiposAnalisisDB = data.tipos.map(function(tipo) {
                    return {
                        id: tipo.id,
                        nombre: tipo.Nombre,
                        detalles: tipo.Descripcion || "Análisis de laboratorio",
                        precioNormal: tipo.Precio_Normal,
                        precioEmergencia: tipo.Precio_Emergencia
                    }
                })
                console.log("✅ Tipos análisis cargados:", tiposAnalisisDB.length)
            } else {
                console.log("⚠️ No se pudieron cargar tipos, usando fallback")
                tiposAnalisisDB = []
            }
        } catch (error) {
            console.error("❌ Error cargando tipos análisis:", error)
            tiposAnalisisDB = []
        }
    }
    
    function cargarTrabajadoresDB() {
        try {
            var trabajadoresJson = laboratorioModel.trabajadoresJson;
            console.log("📝 JSON trabajadores raw:", trabajadoresJson);
            
            // Verificar si realmente está vacío
            var isEmpty = !trabajadoresJson || trabajadoresJson.trim() === "" || trabajadoresJson === "[]";
            
            if (isEmpty) {
                console.log("⚠️ No hay trabajadores desde modelo, usando fallback");
                trabajadoresDB = [
                    {id: 1, nombre: "Lic. Carmen Ruiz", tipo: "Laboratorio"},
                    {id: 2, nombre: "Lic. Roberto Silva", tipo: "Laboratorio"}
                ];
            } else {
                var trabajadoresData = JSON.parse(trabajadoresJson);
                console.log("📋 Datos parseados - Total:", trabajadoresData.length);
                
                trabajadoresDB = [];
                for (var i = 0; i < trabajadoresData.length; i++) {
                    var trabajador = trabajadoresData[i];
                    
                    var nombreCompleto = trabajador.nombre_completo || 
                                    trabajador.trabajador_completo ||
                                    (trabajador.Nombre ? 
                                        trabajador.Nombre + " " + (trabajador.Apellido_Paterno || "") : 
                                        "Trabajador " + (i + 1));
                    
                    trabajadoresDB.push({
                        id: trabajador.id || (i + 1),
                        nombre: nombreCompleto.trim(),
                        tipo: trabajador.tipo_trabajador || trabajador.Tipo || "Laboratorio"
                    });
                    
                    console.log("➕ Procesado:", nombreCompleto.trim(), "ID:", trabajador.id);
                }
            }
            
            console.log("✅ Total trabajadores finales:", trabajadoresDB.length);
            actualizarComboBoxTrabajadores()
            // IMPORTANTE: Notificar cambio a ComboBox
            trabajadorCombo.trabajadoresDisponibles = trabajadoresDB;
            
            // DEBUG: Mostrar primeros trabajadores
            for (var j = 0; j < Math.min(3, trabajadoresDB.length); j++) {
                console.log(`👤 Trabajador ${j}:`, trabajadoresDB[j].nombre);
            }
            
        } catch (error) {
            console.error("❌ Error procesando trabajadores:", error);
            trabajadoresDB = [
                {id: 1, nombre: "Error - Lic. Carmen Ruiz", tipo: "Laboratorio"},
                {id: 2, nombre: "Error - Lic. Roberto Silva", tipo: "Laboratorio"}
            ];
            trabajadorCombo.trabajadoresDisponibles = trabajadoresDB;
        }
    }
    
    Component.onCompleted: {
        console.log("🧪 Módulo Laboratorio iniciado")
        
        // LLAMAR la función y continuar con la inicialización
        var modeloConectado = conectarModelos()
        if (!modeloConectado) {
            // Reintentar 3 veces
            for (var i = 0; i < 3; i++) {
                Qt.callLater(function() {
                    if (conectarModelos()) {
                        console.log("📄 Reconexión exitosa del PacienteModel")
                    }
                })
            }
        }
        
        // Cargar datos desde el modelo Python
        laboratorioModel.cargarExamenes()
        laboratorioModel.cargarTiposAnalisis()
        laboratorioModel.cargarTrabajadores()
        
        // Cargar datos iniciales
        cargarTiposAnalisisDB()
        cargarTrabajadoresDB()
        cargarDatosDesdeModelo()

        Qt.callLater(function() {
            console.log("🎯 Forzando actualización final de trabajadores");
            actualizarComboBoxTrabajadores();
        });
        
        console.log("📱 Elementos por página calculados:", itemsPerPageLaboratorio)
        console.log("👥 PacienteModel disponible:", modeloConectado)
    }
    
    function showSuccessMessage(mensaje) {
        Qt.callLater(function() {
            Qt.createQmlObject('import QtQuick.Controls 2.15; Dialog { modal: true; title: "Éxito"; standardButtons: Dialog.Ok; contentItem: Text { text: "' + mensaje + '"; color: "green"; font.pixelSize: 18; } }', laboratorioRoot, "SuccessDialog").open()
        })
    }

    function showErrorMessage(mensaje) {
        Qt.callLater(function() {
            Qt.createQmlObject('import QtQuick.Controls 2.15; Dialog { modal: true; title: "Error"; standardButtons: Dialog.Ok; contentItem: Label { text: "' + mensaje + '"; color: "red"; font.pixelSize: 18; } }', laboratorioRoot, "ErrorDialog").open()
        })
    }
    
    function debugPacienteModel() {
        if (!pacienteModel) {
            console.error("❌ PacienteModel no está disponible")
            return false
        }
        
        console.log("✅ PacienteModel disponible:", typeof pacienteModel)
        console.log("✅ Métodos disponibles:", 
                    "buscarSugerenciasPacientes:" + typeof pacienteModel.buscarSugerenciasPacientes,
                    "buscarOCrearPacienteInteligente:" + typeof pacienteModel.buscarOCrearPacienteInteligente)
        
        pacienteModel.buscarSugerenciasPacientes("test")
        return true
    }

    function debugDatabaseConnection() {
        if (laboratorioModel) {
            console.log("📝 Probando conexión a base de datos...")
            
            var tiposResult = laboratorioModel.obtenerTiposAnalisisDisponibles()
            console.log("✅ Tipos de análisis:", tiposResult)
            
            var testPacientes = pacienteModel ? pacienteModel.buscarSugerenciasPacientes("a") : "No disponible"
            console.log("✅ Test pacientes:", testPacientes)
        }
    }
    
    Connections {
        target: pacienteModel
        enabled: !!pacienteModel
        
        function onSugerenciasPacientesDisponibles(sugerencias) {
            console.log("📝 Sugerencias recibidas:", sugerencias.length, "pacientes")
            if (sugerencias.length > 0) {
                console.log("📋 Primer paciente:", sugerencias[0].nombre)
            }
        }
        
        function onErrorOccurred(titulo, mensaje) {
            console.error("❌ Error en pacienteModel:", titulo, mensaje)
        }
    }
    function actualizarComboBoxTrabajadores() {
        console.log("🎯 Forzando actualización de ComboBox de trabajadores");
        
        // Actualizar la propiedad para forzar el refresh
        trabajadorCombo.trabajadoresDisponibles = trabajadoresDB.slice(); // Crear copia para forzar actualización
        
        // También puedes forzar la reevaluación del modelo
        trabajadorCombo.model = trabajadorCombo.model;
    }
    function conectarModelos() {
            // Intentar múltiples rutas de conexión
            console.log("📝 Intentando conectar PacienteModel...")
            
            if (typeof appController !== 'undefined') {
                console.log("✅ AppController disponible")
                
                // Ruta 1: paciente_model_instance  
                if (appController.paciente_model_instance) {
                    pacienteModel = appController.paciente_model_instance
                    console.log("✅ PacienteModel conectado vía paciente_model_instance")
                    return true
                }
                
                // Ruta 2: pacienteModel (alternativo)
                if (appController.pacienteModel) {
                    pacienteModel = appController.pacienteModel
                    console.log("✅ PacienteModel conectado vía pacienteModel")
                    return true
                }
                
                console.log("❌ Propiedades disponibles en appController:")
                console.log("- paciente_model_instance:", typeof appController.paciente_model_instance)
                console.log("- pacienteModel:", typeof appController.pacienteModel)
            }
            
            console.log("❌ No se pudo conectar PacienteModel")
            return false
        }
}