import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import ClinicaModels 1.0

Item {
    id: trabajadoresRoot
    objectName: "trabajadoresRoot"
    
    // ACCESO A PROPIEDADES ADAPTATIVAS DEL MAIN
    readonly property real baseUnit: parent.baseUnit || Math.max(8, Screen.height / 100)
    readonly property real fontBaseSize: parent.fontBaseSize || Math.max(12, Screen.height / 70)
    readonly property real scaleFactor: parent.scaleFactor || Math.min(width / 1400, height / 900)
    
    // ===== COLORES MODERNOS =====
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
    readonly property color violetColor: "#9b59b6"
    readonly property color infoColor: "#17a2b8"

    // ✅ AGREGAR TIMER PARA ACTUALIZACIÓN AUTOMÁTICA
    Timer {
        id: updateTimer
        interval: 500  // 500ms de delay
        repeat: false
        onTriggered: {
            console.log("⏰ Timer ejecutado - Aplicando filtros automáticamente")
            aplicarFiltros()
            
            // Forzar layout del ListView
            if (trabajadoresListView) {
                trabajadoresListView.forceLayout()
                console.log("🔄 ListView forzadamente actualizado por timer")
            }
        }
    }
    
    // ✅ FUNCIÓN MEJORADA PARA INICIO INMEDIATO CON TIMER
    function actualizarInmediato() {
        console.log("🚀 Iniciando actualización inmediata...")
        
        // Detener timer previo si está corriendo
        updateTimer.stop()
        
        // Aplicar filtros inmediatamente
        aplicarFiltros()
        
        // Iniciar timer como backup
        updateTimer.start()
    }
    
    // ===== MODELO DE DATOS REAL =====
    TrabajadorModel {
        id: trabajadorModel
        
        // ✅ CONEXIÓN MEJORADA - RECARGA INMEDIATA
        onTrabajadoresChanged: {
            console.log("✅ Trabajadores actualizados desde BD:", trabajadorModel.totalTrabajadores)
            // Aplicar filtros inmediatamente cuando cambien los datos
            Qt.callLater(aplicarFiltros)
        }
        
        // ✅ CONEXIÓN MEJORADA - TIPOS ACTUALIZADOS
        onTiposTrabajadorChanged: {
            console.log("🏷️ Tipos de trabajador actualizados:", trabajadorModel.tiposTrabajador.length)
            // Actualizar ComboBoxes
            filtroTipo.model = getTiposTrabajadoresNombres()
            tipoTrabajadorCombo.model = getTiposTrabajadoresParaCombo()
        }
        
        // ✅ CONEXIÓN MEJORADA - TRABAJADOR CREADO
        onTrabajadorCreado: function(success, message) {
            console.log("📋 Signal trabajadorCreado recibido:", success, message)
            
            if (success) {
                // Cerrar diálogo
                showNewWorkerDialog = false
                selectedRowIndex = -1
                isEditMode = false
                editingIndex = -1
                
                // ✅ FORZAR ACTUALIZACIÓN INMEDIATA DEL LISTVIEW
                if (trabajadoresListView) {
                    trabajadoresListView.forceLayout()
                    console.log("🔄 ListView actualizado forzadamente")
                }
                
                // ✅ REFRESCAR MODELO INMEDIATAMENTE
                trabajadorModel.refrescarDatosInmediato()
            }
            
            console.log("Trabajador creado:", success, message)
        }
        
        onTrabajadorActualizado: function(success, message) {
            if (success) {
                showNewWorkerDialog = false
                selectedRowIndex = -1
                isEditMode = false
                editingIndex = -1
                
                // ✅ FORZAR ACTUALIZACIÓN TAMBIÉN PARA EDICIÓN
                if (trabajadoresListView) {
                    trabajadoresListView.forceLayout()
                }
            }
            console.log("Trabajador actualizado:", success, message)
        }
        
        onTrabajadorEliminado: function(success, message) {
            if (success) {
                selectedRowIndex = -1
                
                // ✅ FORZAR ACTUALIZACIÓN PARA ELIMINACIÓN
                if (trabajadoresListView) {
                    trabajadoresListView.forceLayout()
                }
            }
            console.log("Trabajador eliminado:", success, message)
        }
        
        onErrorOccurred: function(title, message) {
            console.error("Error en TrabajadorModel:", title, message)
        }
    }
        
    // ===== PROPIEDADES PARA DIÁLOGOS =====
    property bool showNewWorkerDialog: false
    property bool isEditMode: false
    property int editingIndex: -1
    property int selectedRowIndex: -1
    
    // ===== SEÑAL PARA NAVEGAR A CONFIGURACIÓN PERSONAL =====
    signal irAConfigPersonal()
    
    // Distribución de columnas responsive
    readonly property real colId: 0.08
    readonly property real colNombre: 0.25
    readonly property real colTipo: 0.22
    readonly property real colEspecialidad: 0.20
    readonly property real colMatricula: 0.15
    readonly property real colFecha: 0.10

    // ===== FUNCIONES HELPER =====
    function getTiposTrabajadoresNombres() {
        var nombres = ["Todos los tipos"]
        var tipos = trabajadorModel.tiposTrabajador
        for (var i = 0; i < tipos.length; i++) {
            nombres.push(tipos[i].Tipo)
        }
        return nombres
    }

    function getTiposTrabajadoresParaCombo() {
        var nombres = ["Seleccionar tipo..."]
        var tipos = trabajadorModel.tiposTrabajador
        for (var i = 0; i < tipos.length; i++) {
            nombres.push(tipos[i].Tipo)
        }
        return nombres
    }

    // MODELOS
    ListModel {
        id: trabajadoresListModel
    }

    // ===== LAYOUT PRINCIPAL RESPONSIVO =====
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: baseUnit * 4
        spacing: baseUnit * 3
        
        // ===== CONTENIDO PRINCIPAL =====
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
                
                // ===== HEADER MODERNO CON LOGOS =====
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: baseUnit * 12  // Aumentamos un poco la altura
                    color: lightGrayColor
                    border.color: borderColor
                    border.width: 1
                    radius: baseUnit * 2
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: baseUnit * 2  // Márgenes más generosos
                        spacing: baseUnit * 2
                        
                        // SECCIÓN DEL LOGO Y TÍTULO
                        RowLayout {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: baseUnit * 1.5
                            
                            // Contenedor del icono con tamaño fijo
                            Rectangle {
                                Layout.preferredWidth: baseUnit * 10
                                Layout.preferredHeight: baseUnit * 10
                                color: "transparent"
                                
                                Image {
                                    id: trabajadoresIcon
                                    anchors.centerIn: parent
                                    width: Math.min(baseUnit * 8, parent.width * 10)
                                    height: Math.min(baseUnit * 8, parent.height * 10)
                                    source: "Resources/iconos/Trabajadores.png"
                                    fillMode: Image.PreserveAspectFit
                                    antialiasing: true
                                    
                                    onStatusChanged: {
                                        if (status === Image.Error) {
                                            console.log("Error cargando PNG:", source)
                                        } else if (status === Image.Ready) {
                                            console.log("PNG cargado correctamente:", source)
                                        }
                                    }
                                }
                            }
                            
                            // Título
                            Label {
                                Layout.alignment: Qt.AlignVCenter
                                text: "Gestión de Trabajadores"
                                font.pixelSize: fontBaseSize * 1.3
                                font.bold: true
                                font.family: "Segoe UI, Arial, sans-serif"
                                color: textColor
                                wrapMode: Text.WordWrap
                            }
                        }
                        
                        // ESPACIADOR FLEXIBLE
                        Item { 
                            Layout.fillWidth: true 
                            Layout.minimumWidth: baseUnit * 2
                        }
                        
                        // BOTÓN NUEVO TRABAJADOR CON LOGO
                        Button {
                            id: newWorkerBtn
                            objectName: "newWorkerButton"
                            Layout.preferredHeight: baseUnit * 5
                            Layout.preferredWidth: Math.max(baseUnit * 20, implicitWidth + baseUnit * 2)
                            Layout.alignment: Qt.AlignVCenter
                            
                            background: Rectangle {
                                color: newWorkerBtn.pressed ? Qt.darker(primaryColor, 1.1) : 
                                    newWorkerBtn.hovered ? Qt.lighter(primaryColor, 1.1) : primaryColor
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
                                        id: addWorkerIcon
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
                                    text: "Nuevo Trabajador"
                                    color: whiteColor
                                    font.bold: true
                                    font.pixelSize: fontBaseSize
                                    font.family: "Segoe UI, Arial, sans-serif"
                                }
                            }
                            
                            onClicked: {
                                isEditMode = false
                                editingIndex = -1
                                showNewWorkerDialog = true
                            }
                            
                            // Efecto hover mejorado
                            HoverHandler {
                                id: buttonHover
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }
                }
                
                // ===== FILTROS ADAPTATIVOS =====
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: width < 1000 ? baseUnit * 16 : baseUnit * 8
                    color: "transparent"
                    z: 10
                    
                    GridLayout {
                        anchors.fill: parent
                        anchors.margins: baseUnit * 3
                        anchors.bottomMargin: baseUnit * 1.5
                        
                        columns: width < 1000 ? 2 : 3
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
                                id: filtroTipo
                                Layout.fillWidth: true
                                Layout.preferredHeight: baseUnit * 4
                                model: getTiposTrabajadoresNombres()
                                currentIndex: 0
                                onCurrentIndexChanged: aplicarFiltros()
                                
                                contentItem: Label {
                                    text: filtroTipo.displayText
                                    font.pixelSize: fontBaseSize * 0.8
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    color: textColor
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: baseUnit
                                    elide: Text.ElideRight
                                }
                            }
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        TextField {
                            id: campoBusqueda
                            Layout.fillWidth: true
                            Layout.preferredHeight: baseUnit * 4
                            placeholderText: "Buscar trabajador..."
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
               
                // ===== TABLA MODERNA CON LÍNEAS VERTICALES =====
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
                            Layout.preferredHeight: baseUnit * 5
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
                                
                                // NOMBRE COLUMN
                                Item {
                                    Layout.preferredWidth: parent.width * colNombre
                                    Layout.fillHeight: true
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "NOMBRE COMPLETO"
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
                                        text: "TIPO TRABAJADOR"
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
                                        text: "ESPECIALIDAD"
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
                                
                                // MATRÍCULA COLUMN
                                Item {
                                    Layout.preferredWidth: parent.width * colMatricula
                                    Layout.fillHeight: true
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "MATRÍCULA"
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
                                id: trabajadoresListView
                                model: trabajadoresListModel
                                
                                delegate: Rectangle {
                                    width: ListView.view.width
                                    height: baseUnit * 5
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
                                                text: model.trabajadorId
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
                                        
                                        // NOMBRE COLUMN
                                        Item {
                                            Layout.preferredWidth: parent.width * colNombre
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                anchors.rightMargin: baseUnit
                                                text: model.nombreCompleto
                                                color: primaryColor
                                                font.bold: true
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
                                        
                                        // TIPO COLUMN
                                        Item {
                                            Layout.preferredWidth: parent.width * colTipo
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                anchors.rightMargin: baseUnit
                                                text: model.tipoTrabajador
                                                color: textColor
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
                                                text: model.especialidad
                                                color: textColorLight
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
                                        
                                        // MATRÍCULA COLUMN
                                        Item {
                                            Layout.preferredWidth: parent.width * colMatricula
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                anchors.rightMargin: baseUnit
                                                text: model.matricula || "Sin matrícula"
                                                color: model.matricula ? textColor : "#95a5a6"
                                                font.bold: false
                                                font.pixelSize: fontBaseSize * 0.8
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
                                        
                                        // FECHA COLUMN
                                        Item {
                                            Layout.preferredWidth: parent.width * colFecha
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                text: model.fechaRegistro
                                                color: textColor
                                                font.bold: false
                                                font.pixelSize: fontBaseSize * 0.85
                                                font.family: "Segoe UI, Arial, sans-serif"
                                            }
                                        }
                                    }
                                    
                                    // LÍNEAS VERTICALES CONTINUAS
                                    Repeater {
                                        model: 5 // Número de líneas verticales (todas menos la última columna)
                                        Rectangle {
                                            property real xPos: {
                                                var w = parent.width - baseUnit * 3
                                                switch(index) {
                                                    case 0: return baseUnit * 1.5 + w * colId
                                                    case 1: return baseUnit * 1.5 + w * (colId + colNombre)
                                                    case 2: return baseUnit * 1.5 + w * (colId + colNombre + colTipo)
                                                    case 3: return baseUnit * 1.5 + w * (colId + colNombre + colTipo + colEspecialidad)
                                                    case 4: return baseUnit * 1.5 + w * (colId + colNombre + colTipo + colEspecialidad + colMatricula)
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
                                            console.log("Seleccionado trabajador ID:", model.trabajadorId)
                                        }
                                    }
                                    
                                    // ===== BOTONES DE ACCIÓN MODERNOS CON ICONOS SVG =====
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
                                                isEditMode = true
                                                editingIndex = index
                                                var trabajador = trabajadoresListModel.get(index)
                                                console.log("Editando trabajador:", JSON.stringify(trabajador))
                                                showNewWorkerDialog = true
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
                                                var trabajadorData = trabajadoresListModel.get(index)
                                                var trabajadorId = parseInt(trabajadorData.trabajadorId)
                                                trabajadorModel.eliminarTrabajador(trabajadorId)
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
                    }
                }
            }
        }
    }

    // ✅ MEJORAR LA FUNCIÓN aplicarFiltros() - BUSCA ESTA FUNCIÓN Y REEMPLÁZALA:
    function aplicarFiltros() {
        console.log("🔍 Aplicando filtros...")
        
        // Limpiar modelo actual
        trabajadoresListModel.clear()
        
        var textoBusqueda = campoBusqueda.text.toLowerCase()
        var tipoSeleccionado = filtroTipo.currentIndex
        
        // Obtener trabajadores desde el modelo
        var trabajadores = trabajadorModel.trabajadores
        
        console.log("📊 Total trabajadores disponibles:", trabajadores.length)
        
        for (var i = 0; i < trabajadores.length; i++) {
            var trabajador = trabajadores[i]
            var mostrar = true
            
            // Filtro por tipo
            if (tipoSeleccionado > 0 && mostrar) {
                var tipoNombre = filtroTipo.model[tipoSeleccionado]
                if (trabajador.tipo_nombre !== tipoNombre) {
                    mostrar = false
                }
            }
            
            // Búsqueda por texto en nombre, especialidad o matrícula
            if (textoBusqueda.length > 0 && mostrar) {
                var nombreCompleto = trabajador.nombre_completo || ""
                var especialidad = trabajador.Especialidad || ""
                var matricula = trabajador.Matricula || ""
                
                if (!nombreCompleto.toLowerCase().includes(textoBusqueda) &&
                    !especialidad.toLowerCase().includes(textoBusqueda) &&
                    !matricula.toLowerCase().includes(textoBusqueda)) {
                    mostrar = false
                }
            }
            
            if (mostrar) {
                // Formatear datos para la vista con datos reales
                var trabajadorFormateado = {
                    trabajadorId: trabajador.id.toString(),
                    nombreCompleto: trabajador.nombre_completo || "",
                    tipoTrabajador: trabajador.tipo_nombre || "",
                    especialidad: trabajador.Especialidad || "Sin especialidad",
                    matricula: trabajador.Matricula || "Sin matrícula",
                    fechaRegistro: new Date().toISOString().split('T')[0]
                }
                trabajadoresListModel.append(trabajadorFormateado)
            }
        }
        
        console.log("✅ Filtros aplicados - Mostrando:", trabajadoresListModel.count, "de", trabajadores.length)
        
        // ✅ FORZAR ACTUALIZACIÓN DEL LISTVIEW
        if (trabajadoresListView) {
            trabajadoresListView.forceLayout()
        }
    }

    // ===== DIÁLOGOS =====
    
    // Fondo del diálogo
    Rectangle {
        id: newWorkerDialog
        anchors.fill: parent
        color: "black"
        opacity: showNewWorkerDialog ? 0.5 : 0
        visible: opacity > 0
        
        MouseArea {
            anchors.fill: parent
            onClicked: {
                showNewWorkerDialog = false
                selectedRowIndex = -1
            }
        }
        
        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }
    }
    
    // Diálogo del formulario - Diseño IDÉNTICO a Enfermería
    Rectangle {
        id: workerForm
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.95, 700)  // Más ancho para mejor uso del espacio
        height: Math.min(parent.height * 0.95, 800)  // Más alto pero con mejor distribución
        color: whiteColor
        radius: baseUnit * 1.5  // Bordes más redondeados
        border.color: "#DDD"
        border.width: 1
        visible: showNewWorkerDialog

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
        
        property int selectedTipoTrabajadorIndex: -1
        
        // Función para cargar datos en modo edición
        function loadEditData() {
            if (isEditMode && editingIndex >= 0) {
                var trabajadorData = trabajadoresListModel.get(editingIndex)
                var trabajadorId = parseInt(trabajadorData.trabajadorId)
                
                // Obtener datos completos del modelo
                var trabajadorCompleto = trabajadorModel.obtenerTrabajadorPorId(trabajadorId)
                
                if (trabajadorCompleto && Object.keys(trabajadorCompleto).length > 0) {
                    // Cargar datos de forma segura
                    nombreTrabajador.text = trabajadorCompleto.Nombre || ""
                    apellidoPaterno.text = trabajadorCompleto.Apellido_Paterno || ""
                    apellidoMaterno.text = trabajadorCompleto.Apellido_Materno || ""
                    especialidadField.text = trabajadorCompleto.Especialidad || ""
                    matriculaField.text = trabajadorCompleto.Matricula || ""
                    
                    // Buscar el tipo de trabajador correspondiente
                    var tipos = trabajadorModel.tiposTrabajador
                    for (var i = 0; i < tipos.length; i++) {
                        if (tipos[i].id === trabajadorCompleto.Id_Tipo_Trabajador) {
                            tipoTrabajadorCombo.currentIndex = i + 1
                            workerForm.selectedTipoTrabajadorIndex = i
                            break
                        }
                    }
                }
            }
        }
        
        onVisibleChanged: {
            if (visible && isEditMode) {
                loadEditData()
            } else if (visible && !isEditMode) {
                // Limpiar formulario para nuevo trabajador
                nombreTrabajador.text = ""
                apellidoPaterno.text = ""
                apellidoMaterno.text = ""
                especialidadField.text = ""
                matriculaField.text = ""
                tipoTrabajadorCombo.currentIndex = 0
                workerForm.selectedTipoTrabajadorIndex = -1
            }
        }
        
        // HEADER MEJORADO CON CIERRE - IDÉNTICO A ENFERMERÍA
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
                text: isEditMode ? "EDITAR TRABAJADOR" : "NUEVO TRABAJADOR"
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
                    showNewWorkerDialog = false
                    selectedRowIndex = -1
                    isEditMode = false
                    editingIndex = -1
                }
            }
        }
        
        // SCROLLVIEW PRINCIPAL CON MÁRGENES ADECUADOS - IDÉNTICO A ENFERMERÍA
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
            
            // CONTENEDOR PRINCIPAL DEL FORMULARIO - IDÉNTICO A ENFERMERÍA
            ColumnLayout {
                width: scrollView.width - (baseUnit * 1)
                spacing: baseUnit * 2
                
                // DATOS PERSONALES - IDÉNTICO A ENFERMERÍA
                GroupBox {
                    Layout.fillWidth: true
                    title: "DATOS PERSONALES"
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
                            text: "Nombre:"
                            font.bold: true
                            color: textColor
                            font.family: "Segoe UI, Arial, sans-serif"
                        }
                        
                        TextField {
                            id: nombreTrabajador
                            Layout.fillWidth: true
                            placeholderText: "Nombre del trabajador"
                            font.pixelSize: fontBaseSize
                            font.family: "Segoe UI, Arial, sans-serif"
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
                            font.family: "Segoe UI, Arial, sans-serif"
                        }
                        
                        TextField {
                            id: apellidoPaterno
                            Layout.fillWidth: true
                            placeholderText: "Apellido paterno"
                            font.pixelSize: fontBaseSize
                            font.family: "Segoe UI, Arial, sans-serif"
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
                            font.family: "Segoe UI, Arial, sans-serif"
                        }
                        
                        TextField {
                            id: apellidoMaterno
                            Layout.fillWidth: true
                            placeholderText: "Apellido materno"
                            font.pixelSize: fontBaseSize
                            font.family: "Segoe UI, Arial, sans-serif"
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
                
                // INFORMACIÓN PROFESIONAL - IDÉNTICO A ENFERMERÍA
                GroupBox {
                    Layout.fillWidth: true
                    title: "INFORMACIÓN PROFESIONAL"
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
                        
                        // Tipo de Trabajador
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit * 2
                            
                            Label {
                                text: "Tipo de Trabajador:"
                                font.bold: true
                                Layout.preferredWidth: baseUnit * 18
                                color: textColor
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                            
                            ComboBox {
                                id: tipoTrabajadorCombo
                                Layout.fillWidth: true
                                font.pixelSize: fontBaseSize
                                font.family: "Segoe UI, Arial, sans-serif"
                                model: getTiposTrabajadoresParaCombo()
                                onCurrentIndexChanged: {
                                    if (currentIndex > 0) {
                                        workerForm.selectedTipoTrabajadorIndex = currentIndex - 1
                                    } else {
                                        workerForm.selectedTipoTrabajadorIndex = -1
                                    }
                                }
                                
                                contentItem: Label {
                                    text: tipoTrabajadorCombo.displayText
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
                                    width: tipoTrabajadorCombo.width
                                    implicitHeight: contentItem.implicitHeight + baseUnit
                                    padding: 1
                                    
                                    contentItem: ListView {
                                        clip: true
                                        implicitHeight: contentHeight
                                        model: tipoTrabajadorCombo.popup.visible ? tipoTrabajadorCombo.delegateModel : null
                                        currentIndex: tipoTrabajadorCombo.highlightedIndex
                                        
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
                        
                        // Especialidad
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit * 2
                            
                            Label {
                                text: "Especialidad:"
                                font.bold: true
                                Layout.preferredWidth: baseUnit * 18
                                color: textColor
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                            
                            TextField {
                                id: especialidadField
                                Layout.fillWidth: true
                                placeholderText: "Especialidad del trabajador"
                                font.pixelSize: fontBaseSize
                                font.family: "Segoe UI, Arial, sans-serif"
                                background: Rectangle {
                                    color: whiteColor
                                    border.color: "#ddd"
                                    border.width: 1
                                    radius: baseUnit * 0.5
                                }
                                padding: baseUnit
                            }
                        }
                        
                        // Matrícula
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: baseUnit * 2
                            
                            Label {
                                text: "Matrícula:"
                                font.bold: true
                                Layout.preferredWidth: baseUnit * 18
                                color: textColor
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                            
                            TextField {
                                id: matriculaField
                                Layout.fillWidth: true
                                placeholderText: "Número de matrícula profesional (opcional)"
                                font.pixelSize: fontBaseSize
                                font.family: "Segoe UI, Arial, sans-serif"
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
                
                // INFORMACIÓN ADICIONAL (Opcional) - Para mantener consistencia visual
                GroupBox {
                    Layout.fillWidth: true
                    title: "INFORMACIÓN ADICIONAL"
                    font.bold: true
                    font.pixelSize: fontBaseSize
                    font.family: "Segoe UI, Arial, sans-serif"
                    padding: baseUnit * 1.5
                    
                    background: Rectangle {
                        color: "#f8f9fa"
                        border.color: "#e0e0e0"
                        radius: baseUnit * 0.8
                    }
                    
                    Label {
                        width: parent.width
                        text: "El trabajador será registrado con la fecha actual del sistema. Los campos marcados como opcionales pueden dejarse vacíos."
                        color: textColorLight
                        font.pixelSize: fontBaseSize * 0.9
                        font.family: "Segoe UI, Arial, sans-serif"
                        wrapMode: Text.WordWrap
                        font.italic: true
                    }
                }
            }
        }
        
        // BOTONES INFERIORES - IDÉNTICO A ENFERMERÍA
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
                    // Limpiar y cerrar
                    showNewWorkerDialog = false
                    selectedRowIndex = -1
                    isEditMode = false
                    editingIndex = -1
                }
            }
            
            Button {
                id: saveButton
                text: isEditMode ? "Actualizar" : "Guardar"
                enabled: workerForm.selectedTipoTrabajadorIndex >= 0 && 
                        nombreTrabajador.text.length > 0
                Layout.preferredWidth: baseUnit * 15
                Layout.preferredHeight: baseUnit * 4.5
                
                background: Rectangle {
                    color: !saveButton.enabled ? "#bdc3c7" : 
                        (saveButton.pressed ? Qt.darker(primaryColor, 1.1) : 
                        (saveButton.hovered ? Qt.lighter(primaryColor, 1.1) : primaryColor))
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
                    console.log("Botón Guardar presionado...")
                    
                    // Obtener valores de forma segura
                    var nombre = nombreTrabajador.text ? nombreTrabajador.text.trim() : ""
                    var apellidoPat = apellidoPaterno.text ? apellidoPaterno.text.trim() : ""
                    var apellidoMat = apellidoMaterno.text ? apellidoMaterno.text.trim() : ""
                    var especialidad = especialidadField.text ? especialidadField.text.trim() : ""
                    var matricula = matriculaField.text ? matriculaField.text.trim() : ""
                    
                    // Validaciones
                    if (!nombre || nombre === "") {
                        console.log("Error: Falta el nombre")
                        return
                    }
                    
                    if (!apellidoPat || apellidoPat === "") {
                        console.log("Error: Falta el apellido paterno")
                        return
                    }
                    
                    if (workerForm.selectedTipoTrabajadorIndex < 0) {
                        console.log("Error: Falta seleccionar tipo de trabajador")
                        return
                    }
                    
                    // Obtener ID del tipo de trabajador
                    var tipoTrabajadorId = trabajadorModel.tiposTrabajador[workerForm.selectedTipoTrabajadorIndex].id
                    
                    console.log("Datos a guardar:", {
                        nombre: nombre,
                        apellidoPaterno: apellidoPat,
                        apellidoMaterno: apellidoMat,
                        tipoTrabajadorId: tipoTrabajadorId,
                        especialidad: especialidad,
                        matricula: matricula
                    })
                    
                    // EJECUTAR OPERACIÓN Y MANEJAR RESULTADO
                    var success = false
                    
                    if (isEditMode && editingIndex >= 0) {
                        // Actualizar trabajador existente
                        var trabajadorData = trabajadoresListModel.get(editingIndex)
                        var trabajadorId = parseInt(trabajadorData.trabajadorId)
                        
                        console.log("Actualizando trabajador ID:", trabajadorId)
                        success = trabajadorModel.actualizarTrabajador(
                            trabajadorId,
                            nombre,
                            apellidoPat, 
                            apellidoMat,
                            tipoTrabajadorId,
                            especialidad,
                            matricula
                        )
                    } else {
                        // Crear nuevo trabajador
                        console.log("Creando nuevo trabajador...")
                        success = trabajadorModel.crearTrabajador(
                            nombre,
                            apellidoPat,
                            apellidoMat,
                            tipoTrabajadorId,
                            especialidad,
                            matricula
                        )
                    }
                    
                    // SI LA OPERACIÓN FUE EXITOSA, ACTUALIZAR INMEDIATAMENTE
                    if (success) {
                        console.log("Operación exitosa - Actualizando UI inmediatamente")
                        
                        // Cerrar diálogo inmediatamente
                        showNewWorkerDialog = false
                        selectedRowIndex = -1
                        isEditMode = false
                        editingIndex = -1
                        
                        // FORZAR ACTUALIZACIÓN INMEDIATA
                        Qt.callLater(function() {
                            console.log("Ejecutando actualización diferida...")
                            actualizarInmediato()
                        })
                        
                    } else {
                        console.log("Error en la operación")
                    }
                }
            }
        }
    }

    // ===== INICIALIZACIÓN =====
    Component.onCompleted: {
        console.log("👥 Módulo Trabajadores iniciado")
        console.log("🔗 Señal irAConfigPersonal configurada para navegación")
        
        // ✅ CARGAR DATOS INICIALES
        console.log("📊 Cargando datos iniciales de trabajadores...")
        
        // Esperar a que el modelo esté listo
        Qt.callLater(function() {
            if (trabajadorModel) {
                console.log("✅ TrabajadorModel disponible")
                
                // Recargar datos para asegurar que están actualizados
                trabajadorModel.recargarDatos()
                
                // Configurar ComboBoxes
                if (filtroTipo) {
                    filtroTipo.model = getTiposTrabajadoresNombres()
                }
                
                if (tipoTrabajadorCombo) {
                    tipoTrabajadorCombo.model = getTiposTrabajadoresParaCombo()
                }
                
                // ✅ AGREGAR ESTA LÍNEA:
                aplicarFiltros()
                
                console.log("🎯 Inicialización completa")
            } else {
                console.log("⚠️ TrabajadorModel no disponible")
            }
        })
    }

    // ✅ AGREGAR CONNECTIONS PARA DEBUGGING
    Connections {
        target: trabajadorModel
        
        function onTrabajadoresChanged() {
            console.log("🔄 Signal trabajadoresChanged detectado")
            console.log("📊 Total trabajadores:", trabajadorModel.totalTrabajadores)
            
            // Actualizar automáticamente
            aplicarFiltros()
        }
        
        function onTiposTrabajadorChanged() {
            console.log("🏷️ Signal tiposTrabajadorChanged detectado")
            console.log("📊 Total tipos:", trabajadorModel.tiposTrabajador.length)
            
            // Actualizar ComboBoxes
            filtroTipo.model = getTiposTrabajadoresNombres()
            tipoTrabajadorCombo.model = getTiposTrabajadoresParaCombo()
        }
    }
}