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

    property string trabajadorIdToDelete: ""
    property bool showConfirmDeleteDialog: false
    
    // ✅ USAR INSTANCIA AUTENTICADA DEL APPCONTROLLER
    readonly property var trabajadorModel: appController.trabajador_model_instance
    
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

    // Propiedades de roles y permisos
    readonly property string usuarioActualRol: authModel ? authModel.userRole || "" : ""
    readonly property bool esAdministrador: usuarioActualRol === "Administrador" 
    readonly property bool esMedico: usuarioActualRol === "Médico"

    // ✅ TIMER PARA ACTUALIZACIÓN AUTOMÁTICA
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

    // ===== FUNCIONES HELPER MEJORADAS CON VERIFICACIONES ROBUSTAS =====
    function getTiposTrabajadoresNombres() {
        // ✅ VERIFICACIÓN ROBUSTA: Verificar modelo, propiedad Y que tenga contenido
        if (!trabajadorModel) {
            console.log("🔄 TrabajadorModel aún no disponible (inicializando...)")
            return ["Todos los tipos"]
        }
        
        if (!trabajadorModel.tiposTrabajador) {
            console.log("🔄 tiposTrabajador aún no inicializado (cargando...)")
            return ["Todos los tipos"]
        }
        
        // ✅ VERIFICAR QUE SEA ARRAY Y TENGA LONGITUD
        var tipos = trabajadorModel.tiposTrabajador
        if (!Array.isArray(tipos) || tipos.length === 0) {
            console.log("🔄 tiposTrabajador vacío o no es array (esperando carga...)")
            return ["Todos los tipos"]
        }
        
        // ✅ TODO OK - CONSTRUIR LISTA
        var nombres = ["Todos los tipos"]
        for (var i = 0; i < tipos.length; i++) {
            if (tipos[i] && tipos[i].Tipo) {  // ✅ Verificar que el objeto y la propiedad existan
                nombres.push(tipos[i].Tipo)
            }
        }
        
        console.log("✅ Tipos de trabajador cargados para filtro:", nombres.length - 1, "tipos")
        return nombres
    }

    function getTiposTrabajadoresParaCombo() {
        // ✅ VERIFICACIÓN ROBUSTA: Verificar modelo, propiedad Y que tenga contenido
        if (!trabajadorModel) {
            console.log("🔄 TrabajadorModel aún no disponible para combo (inicializando...)")
            return ["Seleccionar tipo..."]
        }
        
        if (!trabajadorModel.tiposTrabajador) {
            console.log("🔄 tiposTrabajador aún no inicializado para combo (cargando...)")
            return ["Seleccionar tipo..."]
        }
        
        // ✅ VERIFICAR QUE SEA ARRAY Y TENGA LONGITUD
        var tipos = trabajadorModel.tiposTrabajador
        if (!Array.isArray(tipos) || tipos.length === 0) {
            console.log("🔄 tiposTrabajador vacío o no es array para combo (esperando carga...)")
            return ["Seleccionar tipo..."]
        }
        
        // ✅ TODO OK - CONSTRUIR LISTA
        var nombres = ["Seleccionar tipo..."]
        for (var i = 0; i < tipos.length; i++) {
            if (tipos[i] && tipos[i].Tipo) {  // ✅ Verificar que el objeto y la propiedad existan
                nombres.push(tipos[i].Tipo)
            }
        }
        
        console.log("✅ Tipos de trabajador cargados para combo:", nombres.length - 1, "tipos")
        return nombres
    }

    // ✅ NUEVA FUNCIÓN HELPER PARA VERIFICAR SI EL MODELO ESTÁ LISTO
    function isModeloListo() {
        return trabajadorModel && 
               trabajadorModel.tiposTrabajador && 
               Array.isArray(trabajadorModel.tiposTrabajador) && 
               trabajadorModel.tiposTrabajador.length > 0
    }

    // ✅ FUNCIÓN HELPER PARA ACTUALIZACIÓN SEGURA DE COMBOS
    function actualizarCombosSiEsNecesario() {
        if (!isModeloListo()) {
            console.log("🔄 Modelo aún no listo para actualizar combos")
            return
        }
        
        // Actualizar ComboBoxes solo si están disponibles
        try {
            if (filtroTipo && filtroTipo.model) {
                var newModelFiltro = getTiposTrabajadoresNombres()
                if (JSON.stringify(filtroTipo.model) !== JSON.stringify(newModelFiltro)) {
                    filtroTipo.model = newModelFiltro
                    console.log("🔄 Filtro combo actualizado")
                }
            }
            
            if (tipoTrabajadorCombo && tipoTrabajadorCombo.model) {
                var newModelCombo = getTiposTrabajadoresParaCombo()
                if (JSON.stringify(tipoTrabajadorCombo.model) !== JSON.stringify(newModelCombo)) {
                    tipoTrabajadorCombo.model = newModelCombo
                    console.log("🔄 Tipo trabajador combo actualizado")
                }
            }
        } catch (error) {
            console.log("⚠️ Error actualizando combos:", error)
        }
    }

    // MODELOS
    ListModel {
        id: trabajadoresListModel
    }

    // ===== CONEXIONES MEJORADAS CON VERIFICACIÓN DE INSTANCIA Y TIMING =====
    Connections {
        target: trabajadorModel
        enabled: trabajadorModel !== null
        
        function onTrabajadoresChanged() {
            
            // ✅ VERIFICAR QUE EL MODELO ESTÉ COMPLETAMENTE LISTO ANTES DE APLICAR FILTROS
            if (isModeloListo()) {
                Qt.callLater(aplicarFiltros)
            } else {
                console.log("🔄 Esperando a que el modelo esté completamente listo...")
            }
        }
        
        function onTiposTrabajadorChanged() {
            console.log("🏷️ Signal: Tipos de trabajador actualizados:", trabajadorModel ? trabajadorModel.tiposTrabajador.length : 0)
            
            // ✅ ACTUALIZAR COMBOS DE FORMA SEGURA CON DELAY
            Qt.callLater(function() {
                actualizarCombosSiEsNecesario()
            })
        }
        
        function onTrabajadorCreado(success, message) {
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
                if (trabajadorModel && trabajadorModel.refrescarDatosInmediato) {
                    trabajadorModel.refrescarDatosInmediato()
                }
            }
        }
        
        function onTrabajadorActualizado(success, message) {
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
        
        function onTrabajadorEliminado(success, message) {
            if (success) {
                selectedRowIndex = -1
                
                // ✅ FORZAR ACTUALIZACIÓN PARA ELIMINACIÓN
                if (trabajadoresListView) {
                    trabajadoresListView.forceLayout()
                }
            }
            console.log("Trabajador eliminado:", success, message)
        }
        
        function onErrorOccurred(title, message) {
            console.error("Error en TrabajadorModel:", title, message)
        }
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
                            visible: esAdministrador || esMedico
                            enabled: esAdministrador || esMedico
                            
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
                                            visible: selectedRowIndex === index && (esAdministrador || esMedico)
                                            enabled: esAdministrador || (trabajadorModel && trabajadorModel.puedeEditarTrabajador ? trabajadorModel.puedeEditarTrabajador(parseInt(model.trabajadorId)) : false)
    
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
                                            ToolTip.text: {
                                                if (!esAdministrador && !esMedico) return "Sin permisos"
                                                if (esAdministrador) return "Editar trabajador"
                                                if (!enabled) return "No se puede editar: trabajador de más de 30 días"
                                                return "Editar trabajador (máximo 30 días)"
                                            }
                                        }

                                        Button {
                                            id: deleteButton
                                            width: baseUnit * 3.5
                                            height: baseUnit * 3.5
                                            visible: selectedRowIndex === index && esAdministrador
                                            enabled: esAdministrador
                                            
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
                                                trabajadorIdToDelete = trabajadorData.trabajadorId
                                                showConfirmDeleteDialog = true
                                            }
                                            
                                            // Efecto hover
                                            
                                            ToolTip.text: esAdministrador ? "Eliminar trabajador" : "Eliminar trabajador (solo administradores)"
                                            ToolTip.visible: hovered
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

    // ✅ FUNCIÓN aplicarFiltros() MEJORADA CON VERIFICACIONES
    function aplicarFiltros() {
        //console.log("🔍 Aplicando filtros...")
        
        // ✅ VERIFICAR QUE TRABAJADORMODEL ESTÉ DISPONIBLE
        if (!trabajadorModel) {
            console.warn("⚠️ TrabajadorModel no disponible")
            return
        }
        
        // Limpiar modelo actual
        trabajadoresListModel.clear()
        
        var textoBusqueda = campoBusqueda ? campoBusqueda.text.toLowerCase() : ""
        var tipoSeleccionado = filtroTipo ? filtroTipo.currentIndex : 0
        
        // Obtener trabajadores desde el modelo
        var trabajadores = trabajadorModel.trabajadores || []
        
        for (var i = 0; i < trabajadores.length; i++) {
            var trabajador = trabajadores[i]
            var mostrar = true
            
            // Filtro por tipo
            if (tipoSeleccionado > 0 && mostrar && filtroTipo) {
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
    
    // Diálogo del formulario Modal - Bloqueado como Servicios Básicos
    Dialog {
        id: workerForm
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.95, 700)
        height: Math.min(parent.height * 0.95, 800)
        // CORREGIDO: Remover la propiedad color directa del Dialog
        modal: true
        closePolicy: Popup.NoAutoClose
        visible: showNewWorkerDialog
        
        // Remover el título por defecto
        title: ""
        
        property int selectedTipoTrabajadorIndex: -1
        
        background: Rectangle {
            color: whiteColor
            radius: baseUnit * 1.5
            border.color: "#DDD"
            border.width: 1
            
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
        }
        
        // Función para cargar datos en modo edición
        function loadEditData() {
            if (isEditMode && editingIndex >= 0 && trabajadorModel) {
                var trabajadorData = trabajadoresListModel.get(editingIndex)
                var trabajadorId = parseInt(trabajadorData.trabajadorId)
                
                // Obtener datos completos del modelo
                var trabajadorCompleto = trabajadorModel.obtenerTrabajadorPorId(trabajadorId)
                
                if (trabajadorCompleto && Object.keys(trabajadorCompleto).length > 0) {
                    // Cargar datos de forma segura
                    if (nombreTrabajador) nombreTrabajador.text = trabajadorCompleto.Nombre || ""
                    if (apellidoPaterno) apellidoPaterno.text = trabajadorCompleto.Apellido_Paterno || ""
                    if (apellidoMaterno) apellidoMaterno.text = trabajadorCompleto.Apellido_Materno || ""
                    if (especialidadField) especialidadField.text = trabajadorCompleto.Especialidad || ""
                    if (matriculaField) matriculaField.text = trabajadorCompleto.Matricula || ""
                    
                    // Buscar el tipo de trabajador correspondiente
                    var tipos = trabajadorModel.tiposTrabajador || []
                    for (var i = 0; i < tipos.length; i++) {
                        if (tipos[i].id === trabajadorCompleto.Id_Tipo_Trabajador) {
                            if (tipoTrabajadorCombo) tipoTrabajadorCombo.currentIndex = i + 1
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
                if (nombreTrabajador) nombreTrabajador.text = ""
                if (apellidoPaterno) apellidoPaterno.text = ""
                if (apellidoMaterno) apellidoMaterno.text = ""
                if (especialidadField) especialidadField.text = ""
                if (matriculaField) matriculaField.text = ""
                if (tipoTrabajadorCombo) tipoTrabajadorCombo.currentIndex = 0
                workerForm.selectedTipoTrabajadorIndex = -1
            }
        }
        
        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            
            // HEADER MEJORADO CON CIERRE
            Rectangle {
                id: dialogHeader
                Layout.fillWidth: true
                Layout.preferredHeight: baseUnit * 7
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
            
            // CONTENIDO PRINCIPAL
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "transparent"
                
                // SCROLLVIEW PRINCIPAL CON MÁRGENES ADECUADOS
                ScrollView {
                    id: scrollView
                    anchors.fill: parent
                    anchors.margins: baseUnit * 3
                    anchors.topMargin: baseUnit * 2
                    anchors.bottomMargin: baseUnit * 10
                    clip: true
                    
                    // CONTENEDOR PRINCIPAL DEL FORMULARIO
                    ColumnLayout {
                        width: scrollView.width - (baseUnit * 1)
                        spacing: baseUnit * 2
                        
                        // DATOS PERSONALES
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
                        
                        // INFORMACIÓN PROFESIONAL
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
                        
                        // INFORMACIÓN ADICIONAL (Opcional)
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
            }
            
            // BOTONES INFERIORES
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: baseUnit * 8
                color: "transparent"
                
                RowLayout {
                    id: buttonRow
                    anchors.centerIn: parent
                    spacing: baseUnit * 2
                    
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
                                (nombreTrabajador ? nombreTrabajador.text.length > 0 : false)
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
                            console.log("🔐 DEBUG AUTENTICACIÓN - Botón Guardar presionado...")
                            
                            // ✅ VERIFICAR TRABAJADORMODEL Y AUTENTICACIÓN
                            if (!trabajadorModel) {
                                console.error("❌ ERROR: TrabajadorModel no disponible")
                                return
                            }
                            
                            // ✅ DEBUG DE AUTENTICACIÓN
                            console.log("🔍 Estado de autenticación:")
                            console.log("   - trabajadorModel.usuario_actual_id:", trabajadorModel.usuario_actual_id || "undefined")
                            console.log("   - trabajadorModel.esAdministrador():", trabajadorModel.esAdministrador ? trabajadorModel.esAdministrador() : "undefined")
                            
                            // Obtener valores de forma segura
                            var nombre = nombreTrabajador && nombreTrabajador.text ? nombreTrabajador.text.trim() : ""
                            var apellidoPat = apellidoPaterno && apellidoPaterno.text ? apellidoPaterno.text.trim() : ""
                            var apellidoMat = apellidoMaterno && apellidoMaterno.text ? apellidoMaterno.text.trim() : ""
                            var especialidad = especialidadField && especialidadField.text ? especialidadField.text.trim() : ""
                            var matricula = matriculaField && matriculaField.text ? matriculaField.text.trim() : ""
                            
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
                            var tipos = trabajadorModel.tiposTrabajador || []
                            if (tipos.length === 0) {
                                console.error("❌ No hay tipos de trabajador disponibles")
                                return
                            }
                            
                            var tipoTrabajadorId = tipos[workerForm.selectedTipoTrabajadorIndex].id
                            
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
        }
    }

    // DIÁLOGO DE CONFIRMACIÓN DE ELIMINACIÓN
    Dialog {
        id: confirmDeleteDialog
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.9, 480)
        height: Math.min(parent.height * 0.55, 320)
        modal: true
        closePolicy: Popup.NoAutoClose
        visible: showConfirmDeleteDialog
        
        // Remover el título por defecto para usar nuestro diseño personalizado
        title: ""
        
        background: Rectangle {
            color: whiteColor
            radius: baseUnit * 0.8
            border.color: "#e0e0e0"
            border.width: 1
            
            // Sombra sutil
            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                color: "transparent"
                radius: parent.radius + 3
                border.color: "#30000000"
                border.width: 3
                z: -1
            }
        }
        
        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            
            // Header personalizado con ícono
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
                    
                    // Ícono de advertencia
                    Rectangle {
                        Layout.preferredWidth: 45
                        Layout.preferredHeight: 45
                        color: "#fee2e2"
                        radius: 22
                        border.color: "#fecaca"
                        border.width: 2
                        
                        Label {
                            anchors.centerIn: parent
                            text: "⚠️"
                            font.pixelSize: fontBaseSize * 1.8
                        }
                    }
                    
                    ColumnLayout {
                        spacing: baseUnit * 0.25
                        
                        Label {
                            text: "Confirmar Eliminación"
                            font.pixelSize: fontBaseSize * 1.3
                            font.bold: true
                            color: "#dc2626"
                            Layout.alignment: Qt.AlignLeft
                        }
                        
                        Label {
                            text: "Acción irreversible"
                            font.pixelSize: fontBaseSize * 0.9
                            color: "#7f8c8d"
                            Layout.alignment: Qt.AlignLeft
                        }
                    }
                }
            }
            
            // Contenido principal
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "transparent"
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: baseUnit * 2
                    spacing: baseUnit
                    
                    Item { Layout.preferredHeight: baseUnit * 0.5 }
                    
                    Label {
                        text: "¿Estás seguro de eliminar este trabajador?"
                        font.pixelSize: fontBaseSize * 1.1
                        font.bold: true
                        color: textColor
                        Layout.alignment: Qt.AlignHCenter
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        font.family: "Segoe UI, Arial, sans-serif"
                    }
                    
                    Label {
                        text: "Esta acción no se puede deshacer y el registro del trabajador se eliminará permanentemente."
                        font.pixelSize: fontBaseSize
                        color: "#6b7280"
                        Layout.alignment: Qt.AlignHCenter
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        Layout.maximumWidth: parent.width - baseUnit * 4
                        font.family: "Segoe UI, Arial, sans-serif"
                    }
                    
                    Item { Layout.fillHeight: true }
                    
                    // Botones mejorados
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: baseUnit * 3
                        Layout.bottomMargin: baseUnit
                        Layout.topMargin: baseUnit
                        
                        Button {
                            Layout.preferredWidth: 130
                            Layout.preferredHeight: 45
                            
                            background: Rectangle {
                                color: parent.pressed ? "#e5e7eb" : 
                                    (parent.hovered ? "#f3f4f6" : "#f9fafb")
                                radius: baseUnit * 0.6
                                border.color: "#d1d5db"
                                border.width: 1
                                
                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                            
                            contentItem: RowLayout {
                                spacing: baseUnit * 0.5
                                
                                Label {
                                    text: "✕"
                                    color: "#6b7280"
                                    font.pixelSize: fontBaseSize * 0.9
                                    Layout.alignment: Qt.AlignVCenter
                                }
                                
                                Label {
                                    text: "Cancelar"
                                    color: "#374151"
                                    font.bold: true
                                    font.pixelSize: fontBaseSize
                                    Layout.alignment: Qt.AlignVCenter
                                    font.family: "Segoe UI, Arial, sans-serif"
                                }
                            }
                            
                            onClicked: {
                                showConfirmDeleteDialog = false
                                trabajadorIdToDelete = ""
                            }
                            
                            HoverHandler {
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                        
                        Button {
                            Layout.preferredWidth: 130
                            Layout.preferredHeight: 45
                            
                            background: Rectangle {
                                color: parent.pressed ? "#dc2626" : 
                                    (parent.hovered ? "#ef4444" : "#f87171")
                                radius: baseUnit * 0.6
                                border.width: 0
                                
                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                            
                            contentItem: RowLayout {
                                spacing: baseUnit * 0.5
                                
                                Label {
                                    text: "🗑️"
                                    color: whiteColor
                                    font.pixelSize: fontBaseSize * 0.9
                                    Layout.alignment: Qt.AlignVCenter
                                }
                                
                                Label {
                                    text: "Eliminar"
                                    color: whiteColor
                                    font.bold: true
                                    font.pixelSize: fontBaseSize
                                    Layout.alignment: Qt.AlignVCenter
                                    font.family: "Segoe UI, Arial, sans-serif"
                                }
                            }
                            
                            onClicked: {
                                console.log("🗑️ Confirmando eliminación de trabajador...")
                                
                                if (!trabajadorModel) {
                                    console.error("❌ TrabajadorModel no disponible para eliminación")
                                    return
                                }
                                
                                var trabajadorId = parseInt(trabajadorIdToDelete)
                                var success = trabajadorModel.eliminarTrabajador(trabajadorId)
                                
                                if (success) {
                                    console.log("✅ Trabajador eliminado exitosamente")
                                    selectedRowIndex = -1
                                } else {
                                    console.log("❌ Error eliminando trabajador")
                                }
                                
                                showConfirmDeleteDialog = false
                                trabajadorIdToDelete = ""
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

    // ===== INICIALIZACIÓN MEJORADA CON VERIFICACIONES DE TIMING =====
    Component.onCompleted: {
        console.log("💥 Módulo Trabajadores iniciado")
        console.log("🔗 Señal irAConfigPersonal configurada para navegación")
        
        // ✅ VERIFICAR DISPONIBILIDAD DE APPCONTROLLER Y TRABAJADORMODEL
        if (typeof appController === "undefined") {
            console.error("❌ CRÍTICO: appController no está disponible")
            return
        }
        
        console.log("✅ AppController disponible")
        
        // ✅ FUNCIÓN DE INICIALIZACIÓN DIFERIDA CON REINTENTOS
        function inicializarModelo(reintentos) {
            reintentos = reintentos || 0
            const MAX_REINTENTOS = 5
            
            if (trabajadorModel) {
                console.log("✅ TrabajadorModel disponible")
                
                // ✅ DEBUG DE AUTENTICACIÓN AL INICIO
                console.log("🔍 Verificando autenticación inicial:")
                console.log("   - trabajadorModel.usuario_actual_id:", trabajadorModel.usuario_actual_id || "undefined")
                console.log("   - trabajadorModel.esAdministrador():", trabajadorModel.esAdministrador ? trabajadorModel.esAdministrador() : "undefined")
                
                // ✅ VERIFICAR SI LOS DATOS YA ESTÁN LISTOS
                if (isModeloListo()) {
                    console.log("✅ Modelo ya está listo con", trabajadorModel.tiposTrabajador.length, "tipos")
                    
                    // Configurar ComboBoxes inmediatamente
                    actualizarCombosSiEsNecesario()
                    
                    // Aplicar filtros inicial
                    aplicarFiltros()
                    
                    console.log("🎯 Inicialización completa inmediata")
                } else {
                    console.log("🔄 Modelo disponible pero datos aún cargando, esperando...")
                    
                    // Recargar datos para asegurar que estén actualizados
                    if (trabajadorModel.recargarDatos) {
                        trabajadorModel.recargarDatos()
                    }
                    
                    // Timer para verificar cuando estén listos los datos
                    var checkTimer = Qt.createQmlObject(`
                        import QtQuick 2.15
                        Timer {
                            interval: 200
                            repeat: true
                            running: true
                            
                            onTriggered: {
                                if (trabajadorModel && 
                                    trabajadorModel.tiposTrabajador && 
                                    trabajadorModel.tiposTrabajador.length > 0) {
                                    
                                    console.log("✅ Datos finalmente listos -", trabajadorModel.tiposTrabajador.length, "tipos cargados")
                                    
                                    // Configurar ComboBoxes
                                    actualizarCombosSiEsNecesario()
                                    
                                    // Aplicar filtros inicial
                                    aplicarFiltros()
                                    
                                    console.log("🎯 Inicialización completa diferida")
                                    
                                    // Detener timer
                                    running = false
                                    destroy()
                                }
                            }
                        }
                    `, trabajadoresRoot)
                }
                
            } else if (reintentos < MAX_REINTENTOS) {
                console.log(`🔄 TrabajadorModel no disponible, reintento ${reintentos + 1}/${MAX_REINTENTOS}`)
                Qt.callLater(function() {
                    inicializarModelo(reintentos + 1)
                })
            } else {
                console.error("❌ TrabajadorModel no disponible después de", MAX_REINTENTOS, "reintentos")
            }
        }
        
        // ✅ INICIALIZAR CON DELAY MÍNIMO
        Qt.callLater(function() {
            inicializarModelo(0)
        })
    }
}