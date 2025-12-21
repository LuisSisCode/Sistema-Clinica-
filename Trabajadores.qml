import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import ClinicaModels 1.0

Item {
    id: trabajadoresRoot
    objectName: "trabajadoresRoot"
    
    readonly property real baseUnit: parent.baseUnit || Math.max(8, Screen.height / 100)
    readonly property real fontBaseSize: parent.fontBaseSize || Math.max(12, Screen.height / 70)
    readonly property real scaleFactor: parent.scaleFactor || Math.min(width / 1400, height / 900)

    property string trabajadorIdToDelete: ""
    property bool showConfirmDeleteDialog: false
    
    readonly property var trabajadorModel: appController.trabajador_model_instance
    
    readonly property string primaryColor: "#3498DB"
    readonly property string successColor: "#10B981"
    readonly property string successColorLight: "#D1FAE5"
    readonly property string dangerColor: "#E74C3C"
    readonly property string dangerColorLight: "#FEE2E2"
    readonly property string warningColor: "#f39c12"
    readonly property string warningColorLight: "#FEF3C7"
    readonly property string lightGrayColor: "#F8F9FA"
    readonly property string textColor: "#2c3e50"
    readonly property string textColorLight: "#6B7280"
    readonly property string whiteColor: "#FFFFFF"
    readonly property string borderColor: "#e0e0e0"
    readonly property string accentColor: "#10B981"
    readonly property string lineColor: "#D1D5DB"
    readonly property string violetColor: "#9b59b6"
    readonly property string infoColor: "#17a2b8"

    function obtenerIconoArea(areaFuncional) {
        if (!areaFuncional) return '👷'
        
        const iconos = {
            'MEDICO': '⚕️',
            'LABORATORIO': '🔬',
            'ENFERMERIA': '💉',
            'ADMINISTRATIVO': '📋',
            'FARMACIA': '💊'
        }
        
        var areaUpper = areaFuncional.toString().toUpperCase().trim()
        return iconos[areaUpper] || '👷'
    }

    property var tiposParaFiltro: ["Todos los tipos"]
    property var tiposParaCombo: ["Seleccionar tipo..."]

    readonly property string usuarioActualRol: authModel ? authModel.userRole || "" : ""
    readonly property bool esAdministrador: usuarioActualRol === "Administrador" 
    readonly property bool esMedico: usuarioActualRol === "Médico"

    Timer {
        id: updateTimer
        interval: 500
        repeat: false
        onTriggered: {
            console.log("⏰ Timer ejecutado - Aplicando filtros automáticamente")
            aplicarFiltros()
            
            if (trabajadoresListView) {
                trabajadoresListView.forceLayout()
                console.log("🔄 ListView forzadamente actualizado por timer")
            }
        }
    }
    
    function actualizarInmediato() {
        console.log("🚀 Iniciando actualización inmediata...")
        
        updateTimer.stop()
        
        // ✅ RECARGAR DATOS DESDE LA BASE DE DATOS
        if (trabajadorModel) {
            console.log("🔄 Recargando trabajadores desde BD...")
            trabajadorModel.recargarTrabajadores()
        }
        
        aplicarFiltros()
        updateTimer.start()
    }
    
    property bool showNewWorkerDialog: false
    property bool isEditMode: false
    property int editingIndex: -1
    property int selectedRowIndex: -1

    property var tiposDataFiltro: []
    property var tiposDataCombo: []
    
    signal irAConfigPersonal()
    
    readonly property real colId: 0.08
    readonly property real colNombre: 0.25
    readonly property real colTipo: 0.22
    readonly property real colEspecialidad: 0.20
    readonly property real colMatricula: 0.15
    readonly property real colFecha: 0.10

    function actualizarTiposParaFiltro() {
        console.log("🔍 actualizarTiposParaFiltro - INICIO")
        
        if (!trabajadorModel) {
            console.log("❌ TrabajadorModel no disponible")
            tiposParaFiltro = ["Todos los tipos"]
            tiposDataFiltro = [{id: 0, nombre: "Todos los tipos"}]
            return
        }
        
        try {
            var tipos = trabajadorModel.tiposTrabajador
            
            if (!tipos) {
                console.log("❌ tipos es null/undefined")
                tiposParaFiltro = ["Todos los tipos"]
                tiposDataFiltro = [{id: 0, nombre: "Todos los tipos"}]
                return
            }
        
        var length = tipos.length || 0
        
        if (length === 0) {
            console.log("❌ tipos.length es 0")
            tiposParaFiltro = ["Todos los tipos"]
            tiposDataFiltro = [{id: 0, nombre: "Todos los tipos"}]
            return
        }
        
        var nombres = ["Todos los tipos"]
        var tiposData = []

        tiposData.push({id: 0, nombre: "Todos los tipos"})

        console.log("📋 Procesando", length, "tipos de trabajador:")
        for (var i = 0; i < length; i++) {
            var tipo = tipos[i]
            if (tipo && tipo.Tipo) {
                var areaFuncional = tipo.area_funcional || null
                var icono = obtenerIconoArea(areaFuncional)
                var nombreConIcono = icono + " " + tipo.Tipo
                nombres.push(nombreConIcono)
                tiposData.push({
                    id: tipo.id, 
                    nombre: tipo.Tipo,
                    area_funcional: areaFuncional
                })
                console.log("   ", i + 1, "-", tipo.Tipo, 
                          "(ID:", tipo.id, 
                          "Área Funcional:", areaFuncional, 
                          "Icono:", icono, ")")
            }
        }

        tiposParaFiltro = nombres
        tiposDataFiltro = tiposData
        console.log("✅ Tipos cargados para filtro:", nombres.length - 1, "tipos")
        
        } catch (error) {
            console.log("❌ ERROR en actualizarTiposParaFiltro:", error)
            tiposParaFiltro = ["Todos los tipos"]
            tiposDataFiltro = [{id: 0, nombre: "Todos los tipos"}]
        }
    }

    function actualizarTiposParaCombo() {
        console.log("🔍 actualizarTiposParaCombo - INICIO")
        
        if (!trabajadorModel) {
            console.log("❌ TrabajadorModel no disponible")
            tiposParaCombo = ["Seleccionar tipo..."]
            return
        }
        
        try {
            var tipos = trabajadorModel.tiposTrabajador
            
            if (!tipos) {
                console.log("❌ tipos es null/undefined")
                tiposParaCombo = ["Seleccionar tipo..."]
                return
            }
            
            var length = tipos.length || 0
            
            if (length === 0) {
                console.log("❌ tipos.length es 0")
                tiposParaCombo = ["Seleccionar tipo..."]
                return
            }
            
            var nombres = ["Seleccionar tipo..."]
            
            console.log("📋 Procesando tipos para combo:")
            for (var i = 0; i < length; i++) {
                try {
                    var tipo = tipos[i]
                    if (tipo && tipo.Tipo) {
                        var areaFuncional = tipo.area_funcional || null
                        var icono = obtenerIconoArea(areaFuncional)
                        nombres.push(icono + " " + tipo.Tipo)
                        console.log("   ", i + 1, "-", tipo.Tipo, 
                                "(Área Funcional:", areaFuncional, 
                                "Icono:", icono, ")")
                    }
                } catch (err) {
                    console.log("⚠️ Error procesando tipo en índice", i)
                }
            }
            
            tiposParaCombo = nombres
            console.log("✅ Tipos cargados para combo:", nombres.length - 1, "tipos")
            
        } catch (error) {
            console.log("❌ ERROR en actualizarTiposParaCombo:", error)
            tiposParaCombo = ["Seleccionar tipo..."]
        }
    }

    function isModeloListo() {
        if (!trabajadorModel) {
            console.log("❌ TrabajadorModel no disponible")
            return false
        }
        
        var tipos = trabajadorModel.tiposTrabajador
        
        if (!tipos) {
            console.log("❌ Tipos es null/undefined")
            return false
        }
        
        var length = tipos.length || 0
        if (length === 0) {
            console.log("❌ Tipos no disponibles o vacíos (length=0)")
            return false
        }
        
        try {
            var primerTipo = tipos[0]
            if (!primerTipo || typeof primerTipo !== 'object') {
                console.log("❌ Estructura de tipos inválida")
                return false
            }
            
            if (!primerTipo.hasOwnProperty('Tipo')) {
                console.log("❌ Primer tipo no tiene propiedad 'Tipo'")
                return false
            }
        } catch (e) {
            console.log("❌ Error accediendo al primer tipo:", e)
            return false
        }
        
        return true
    }

    function actualizarCombosSiEsNecesario() {
        if (!isModeloListo()) {
            console.log("🔄 Modelo aún no listo para actualizar combos")
            return
        }
        
        try {
            if (filtroTipo && filtroTipo.model) {
                var newModelFiltro = tiposParaFiltro
                if (JSON.stringify(filtroTipo.model) !== JSON.stringify(newModelFiltro)) {
                    filtroTipo.model = newModelFiltro
                    console.log("🔄 Filtro combo actualizado")
                }
            }
            
            if (tipoTrabajadorCombo && tipoTrabajadorCombo.model) {
                var newModelCombo = tiposParaCombo
                if (JSON.stringify(tipoTrabajadorCombo.model) !== JSON.stringify(newModelCombo)) {
                    tipoTrabajadorCombo.model = newModelCombo
                    console.log("🔄 Tipo trabajador combo actualizado")
                }
            }
        } catch (error) {
            console.log("⚠️ Error actualizando combos:", error)
        }
    }

    function aplicarFiltros() {
        console.log("🔍 Aplicando filtros...")
        
        if (!trabajadorModel) {
            console.warn("⚠️ TrabajadorModel no disponible")
            return
        }
        
        trabajadoresListModel.clear()
        
        var textoBusqueda = campoBusqueda ? campoBusqueda.text.toLowerCase() : ""
        var tipoSeleccionado = filtroTipo ? filtroTipo.currentIndex : 0
        
        var trabajadores = trabajadorModel.trabajadores || []
        
        console.log("📊 Total trabajadores a filtrar:", trabajadores.length)
        console.log("🎯 Filtro tipo seleccionado:", tipoSeleccionado, "Texto búsqueda:", textoBusqueda)
        
        for (var i = 0; i < trabajadores.length; i++) {
            var trabajador = trabajadores[i]
            var mostrar = true
            
            if (tipoSeleccionado > 0 && tiposDataFiltro.length > tipoSeleccionado) {
                var tipoData = tiposDataFiltro[tipoSeleccionado]
                console.log("🔍 Filtrando por tipo:", tipoData.nombre, "vs trabajador:", trabajador.tipo_nombre)
                
                if (trabajador.tipo_nombre !== tipoData.nombre) {
                    mostrar = false
                    console.log("❌ Trabajador filtrado por tipo:", trabajador.nombre_completo)
                }
            }
            
            if (mostrar && textoBusqueda.length > 0) {
                var nombreCompleto = trabajador.nombre_completo || ""
                var matricula = trabajador.Matricula || ""
                var especialidades = trabajador.especialidades_nombres || ""
                
                var nombreMatch = nombreCompleto.toLowerCase().includes(textoBusqueda)
                var matriculaMatch = matricula.toLowerCase().includes(textoBusqueda)
                var especialidadesMatch = especialidades.toLowerCase().includes(textoBusqueda)
                
                if (!nombreMatch && !matriculaMatch && !especialidadesMatch) {
                    mostrar = false
                    console.log("❌ Trabajador filtrado por búsqueda:", trabajador.nombre_completo)
                }
            }
            
            if (mostrar) {
                var trabajadorFormateado = {
                    trabajadorId: trabajador.id.toString(),
                    nombreCompleto: trabajador.nombre_completo || "",
                    tipoTrabajador: trabajador.tipo_nombre || "",
                    especialidades_nombres: trabajador.especialidades_nombres || "",
                    matricula: trabajador.Matricula || "Sin matrícula",
                    fechaRegistro: trabajador.fecha_registro || new Date().toISOString().split('T')[0]
                }
                trabajadoresListModel.append(trabajadorFormateado)
                console.log("✅ Mostrando trabajador:", trabajador.nombre_completo, "- Tipo:", trabajador.tipo_nombre)
            }
        }
        
        console.log("✅ Filtros aplicados - Mostrando:", trabajadoresListModel.count, "de", trabajadores.length)
        
        if (trabajadoresListView) {
            trabajadoresListView.forceLayout()
        }
    }

    function debugTiposTrabajador() {
        console.log("🐛 DEBUG DETALLADO - Tipos de Trabajador:")
        if (!trabajadorModel) {
            console.log("   ❌ trabajadorModel no disponible")
            return
        }
        
        var tipos = trabajadorModel.tiposTrabajador
        console.log("   📋 Total tipos en modelo:", tipos.length)
        
        if (tipos.length === 0) {
            console.log("   ⚠️ No hay tipos disponibles")
            return
        }
        
        for (var i = 0; i < tipos.length; i++) {
            var tipo = tipos[i]
            console.log("   " + (i + 1) + ". ID: " + tipo.id + 
                    " | Tipo: '" + tipo.Tipo + 
                    "' | Área: '" + (tipo.area_funcional || "NO DISPONIBLE") + "'")
        }
        
        console.log("   🎯 COMBO ACTUAL:")
        console.log("      Índice seleccionado:", tipoTrabajadorCombo.currentIndex)
        
        if (tipoTrabajadorCombo.currentIndex > 0) {
            var tipoIndex = tipoTrabajadorCombo.currentIndex - 1
            if (tipoIndex < tipos.length) {
                var tipoActual = tipos[tipoIndex]
                console.log("      Tipo seleccionado:", tipoActual.Tipo)
                console.log("      Área funcional:", "'" + (tipoActual.area_funcional || "NO DISPONIBLE") + "'")
                console.log("      Es médico?", tipoActual.area_funcional === "MEDICO")
            } else {
                console.log("      ❌ Índice fuera de rango")
            }
        } else {
            console.log("      No hay tipo seleccionado")
        }
    }

    function debugTrabajadorCompleto(trabajadorId) {
        if (!trabajadorModel) {
            console.log("❌ trabajadorModel no disponible")
            return
        }
        
        var trabajadorCompleto = trabajadorModel.obtenerTrabajadorPorId(trabajadorId)
        console.log("🔍 DEBUG TRABAJADOR COMPLETO ID:", trabajadorId)
        console.log("   Datos completos:", JSON.stringify(trabajadorCompleto))
        
        if (trabajadorCompleto && trabajadorCompleto.Id_Tipo_Trabajador) {
            var areaFuncional = trabajadorModel.obtenerAreaFuncionalDeTipo(trabajadorCompleto.Id_Tipo_Trabajador)
            console.log("   Área funcional del tipo:", "'" + areaFuncional + "'")
            console.log("   Es médico?", areaFuncional === "MEDICO")
        }
    }

    ListModel {
        id: trabajadoresListModel
    }

    Connections {
        target: trabajadorModel
        
        function onTrabajadorEliminado(success, mensaje) {
            console.log("📡 Señal trabajadorEliminado recibida:", success, mensaje)
            
            if (success) {
                showConfirmDeleteDialog = false
                trabajadorIdToDelete = ""
                selectedRowIndex = -1
                
                actualizarInmediato()
            } else {
                confirmDeleteDialog.dialogMode = "info"
                confirmDeleteDialog.infoMessage = mensaje
            }
        }
        
        function onTrabajadorActualizado(success, mensaje) {
            console.log("📡 Señal trabajadorActualizado recibida:", success, mensaje)
            if (success) {
                actualizarInmediato()
            }
        }
        
        function onTrabajadorCreado(success, mensaje) {
            console.log("📡 Señal trabajadorCreado recibida:", success, mensaje)
            if (success) {
                actualizarInmediato()
            }
        }
        
        // ✅ NUEVAS SEÑALES PARA ESPECIALIDADES
        function onEspecialidadesActualizadas() {
            console.log("📡 Señal especialidadesActualizadas recibida - Actualizando tabla")
            actualizarInmediato()
        }
        
        function onEspecialidadAsignada(success, mensaje) {
            console.log("📡 Señal especialidadAsignada recibida:", success, mensaje)
            if (success) {
                actualizarInmediato()
            }
        }
        
        function onEspecialidadDesasignada(success, mensaje) {
            console.log("📡 Señal especialidadDesasignada recibida:", success, mensaje)
            if (success) {
                actualizarInmediato()
            }
        }
    }

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
                        
                        Item { 
                            Layout.fillWidth: true 
                            Layout.minimumWidth: baseUnit * 2
                        }
                        
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
                                                visible = false
                                                fallbackText.visible = true
                                            } else if (status === Image.Ready) {
                                                console.log("PNG del botón cargado correctamente:", source)
                                            }
                                        }
                                    }
                                    
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
                            
                            HoverHandler {
                                id: buttonHover
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }
                }
                
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
                                model: tiposParaFiltro
                                currentIndex: 0
                                onCurrentIndexChanged: aplicarFiltros()
                                
                                onModelChanged: {
                                    console.log("📋 Modelo de filtro actualizado:", model.length, "items")
                                }
                                
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
                                
                                Item {
                                    Layout.preferredWidth: parent.width * colEspecialidad
                                    Layout.fillHeight: true
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "ESPECIALIDADES"
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
                                        
                                        Item {
                                            Layout.preferredWidth: parent.width * colEspecialidad
                                            Layout.fillHeight: true
                                            
                                            Label {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: baseUnit
                                                anchors.rightMargin: baseUnit
                                                text: model.especialidades_nombres || "Sin especialidades"
                                                color: model.especialidades_nombres ? textColorLight : "#95a5a6"
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
                                    
                                    Repeater {
                                        model: 5
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
                                                confirmDeleteDialog.dialogMode = "confirm"
                                                showConfirmDeleteDialog = true
                                            }
                                            
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

    Dialog {
        id: workerForm
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.95, 700)
        height: Math.min(parent.height * 0.95, 800)
        modal: true
        closePolicy: Popup.NoAutoClose
        visible: showNewWorkerDialog
        
        title: ""
        
        property int selectedTipoTrabajadorIndex: -1
        
        background: Rectangle {
            color: whiteColor
            radius: baseUnit * 1.5
            border.color: "#DDD"
            border.width: 1
            
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
        
        function loadEditData() {
            if (isEditMode && editingIndex >= 0 && trabajadorModel) {
                var trabajadorData = trabajadoresListModel.get(editingIndex)
                var trabajadorId = parseInt(trabajadorData.trabajadorId)
                
                var trabajadorCompleto = trabajadorModel.obtenerTrabajadorPorId(trabajadorId)
                
                if (trabajadorCompleto && Object.keys(trabajadorCompleto).length > 0) {
                    if (nombreTrabajador) nombreTrabajador.text = trabajadorCompleto.Nombre || ""
                    if (apellidoPaterno) apellidoPaterno.text = trabajadorCompleto.Apellido_Paterno || ""
                    if (apellidoMaterno) apellidoMaterno.text = trabajadorCompleto.Apellido_Materno || ""
                    if (matriculaField) matriculaField.text = trabajadorCompleto.Matricula || ""
                    
                    var tipos = trabajadorModel.tiposTrabajador || []
                    for (var i = 0; i < tipos.length; i++) {
                        if (tipos[i].id === trabajadorCompleto.Id_Tipo_Trabajador) {
                            if (tipoTrabajadorCombo) tipoTrabajadorCombo.currentIndex = i + 1
                            workerForm.selectedTipoTrabajadorIndex = i
                            break
                        }
                    }
                    
                    if (especialidadesSection) {
                        console.log("🩺 Cargando especialidades del trabajador ID:", trabajadorId)
                        
                        var especialidadesExistentes = trabajadorModel.obtenerEspecialidadesDeTrabajador(trabajadorId)
                        console.log("📋 Especialidades encontradas:", especialidadesExistentes.length)
                        
                        if (especialidadesSection.cargarEspecialidadesExistentes) {
                            especialidadesSection.cargarEspecialidadesExistentes(especialidadesExistentes)
                        } else if (especialidadesSection.especialidades) {
                            especialidadesSection.especialidades = especialidadesExistentes
                        }
                    }
                }
            }
        }
        
        onVisibleChanged: {
            if (visible && isEditMode) {
                loadEditData()
            } else if (visible && !isEditMode) {
                if (nombreTrabajador) nombreTrabajador.text = ""
                if (apellidoPaterno) apellidoPaterno.text = ""
                if (apellidoMaterno) apellidoMaterno.text = ""
                if (matriculaField) matriculaField.text = ""
                if (tipoTrabajadorCombo) tipoTrabajadorCombo.currentIndex = 0
                workerForm.selectedTipoTrabajadorIndex = -1
            }

            Qt.callLater(function() {
                debugTiposTrabajador()
            })
        }
        
        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            
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
            
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "transparent"
                
                ScrollView {
                    id: scrollView
                    anchors.fill: parent
                    anchors.margins: baseUnit * 3
                    anchors.topMargin: baseUnit * 2
                    anchors.bottomMargin: baseUnit * 10
                    clip: true
                    
                    ColumnLayout {
                        width: scrollView.width - (baseUnit * 1)
                        spacing: baseUnit * 2
                        
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
                                        model: tiposParaCombo
                                        
                                        onModelChanged: {
                                            console.log("📋 Modelo de tipo trabajador actualizado:", model.length, "items")
                                        }
                                        
                                        onCurrentIndexChanged: {
                                            console.log("🔄 Combo de tipo cambiado a índice:", currentIndex)
                                            if (currentIndex > 0) {
                                                workerForm.selectedTipoTrabajadorIndex = currentIndex - 1
                                                var tipos = trabajadorModel ? trabajadorModel.tiposTrabajador : []
                                                if (currentIndex - 1 < tipos.length) {
                                                    var tipoSeleccionado = tipos[currentIndex - 1]
                                                    console.log("🎯 Tipo seleccionado cambiado:")
                                                    console.log("   Tipo:", tipoSeleccionado.Tipo)
                                                    console.log("   Área:", "'" + (tipoSeleccionado.area_funcional || "NO DISPONIBLE") + "'")
                                                    console.log("   Mostrar especialidades?", tipoSeleccionado.area_funcional === "MEDICO")
                                                }
                                            } else {
                                                workerForm.selectedTipoTrabajadorIndex = -1
                                                console.log("🔘 Tipo seleccionado: Ninguno (índice 0)")
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

                        EspecialidadesMedicasSection {
                            id: especialidadesSection
                            Layout.fillWidth: true
                            
                            trabajadorModel: trabajadoresRoot.trabajadorModel
                            trabajadorId: isEditMode && editingIndex >= 0 ? 
                                        parseInt(trabajadoresListModel.get(editingIndex).trabajadorId) : -1
                            isEditMode: workerForm.isEditMode || false
                            
                            baseUnit: trabajadoresRoot.baseUnit
                            fontBaseSize: trabajadoresRoot.fontBaseSize
                            primaryColor: trabajadoresRoot.primaryColor
                            successColor: trabajadoresRoot.successColor
                            dangerColor: trabajadoresRoot.dangerColor
                            whiteColor: trabajadoresRoot.whiteColor
                            textColor: trabajadoresRoot.textColor
                            textColorLight: trabajadoresRoot.textColorLight
                            
                            visible: {
                                console.log("🔍 INICIO - Evaluando visibilidad de especialidades médicas...")
                                console.log("   Combo currentIndex:", tipoTrabajadorCombo.currentIndex)
                                
                                if (tipoTrabajadorCombo.currentIndex <= 0) {
                                    console.log("❌ No mostrar: Combo en índice", tipoTrabajadorCombo.currentIndex)
                                    return false
                                }
                                
                                var tipos = trabajadorModel ? trabajadorModel.tiposTrabajador : []
                                if (!tipos || tipos.length === 0) {
                                    console.log("❌ No mostrar: Lista de tipos vacía o nula")
                                    console.log("   Tipos disponible:", !!trabajadorModel, "Longitud:", tipos ? tipos.length : 0)
                                    return false
                                }
                                
                                var tipoIndex = tipoTrabajadorCombo.currentIndex - 1
                                console.log("   Índice calculado:", tipoIndex, "de", tipos.length - 1)
                                
                                if (tipoIndex < 0 || tipoIndex >= tipos.length) {
                                    console.log("❌ No mostrar: Índice fuera de rango", tipoIndex, "de", tipos.length)
                                    return false
                                }
                                
                                var tipoSeleccionado = tipos[tipoIndex]
                                var areaFuncional = tipoSeleccionado.area_funcional || ""
                                
                                console.log("🔍 INFORMACIÓN DEL TIPO SELECCIONADO:")
                                console.log("   Tipo:", tipoSeleccionado.Tipo)
                                console.log("   ID:", tipoSeleccionado.id)
                                console.log("   Área funcional:", "'" + areaFuncional + "'")
                                console.log("   Es médico?", areaFuncional === "MEDICO")
                                console.log("   Mostrar especialidades?", areaFuncional === "MEDICO")
                                
                                return areaFuncional === "MEDICO"
                            }
                        }
                        
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
                            console.log("💾 Botón Guardar/Actualizar presionado...")
                            
                            if (!trabajadorModel) {
                                console.error("❌ ERROR: TrabajadorModel no disponible")
                                return
                            }
                            
                            var nombre = nombreTrabajador && nombreTrabajador.text ? nombreTrabajador.text.trim() : ""
                            var apellidoPat = apellidoPaterno && apellidoPaterno.text ? apellidoPaterno.text.trim() : ""
                            var apellidoMat = apellidoMaterno && apellidoMaterno.text ? apellidoMaterno.text.trim() : ""
                            var matricula = matriculaField && matriculaField.text ? matriculaField.text.trim() : ""
                            
                            if (!nombre || !apellidoPat || !apellidoMat) {
                                console.error("❌ ERROR: Faltan campos obligatorios")
                                return
                            }
                            
                            var tipoIndex = workerForm.selectedTipoTrabajadorIndex
                            if (tipoIndex < 0) {
                                console.error("❌ ERROR: Tipo de trabajador no seleccionado")
                                return
                            }
                            
                            var tipos = trabajadorModel.tiposTrabajador || []
                            if (!tipos || tipos.length === 0 || tipoIndex >= tipos.length) {
                                console.error("❌ ERROR: Lista de tipos de trabajador no disponible")
                                return
                            }
                            
                            var tipoSeleccionado = tipos[tipoIndex]
                            var idTipoTrabajador = tipoSeleccionado.id
                            var esMedico = (tipoSeleccionado.area_funcional === "MEDICO")
                            
                            console.log("📋 Datos del formulario:")
                            console.log("   Nombre:", nombre, apellidoPat, apellidoMat)
                            console.log("   Tipo:", tipoSeleccionado.Tipo, "(ID:", idTipoTrabajador, ")")
                            console.log("   Matrícula:", matricula || "N/A")
                            console.log("   Es médico:", esMedico)
                            
                            var especialidadesPendientes = []
                            
                            if (esMedico && especialidadesSection && especialidadesSection.visible) {
                                if (especialidadesSection.obtenerEspecialidadesPendientes) {
                                    especialidadesPendientes = especialidadesSection.obtenerEspecialidadesPendientes()
                                }
                                console.log("📋 Especialidades pendientes:", especialidadesPendientes.length)
                            }
                            
                            if (isEditMode && editingIndex >= 0) {
                                console.log("🔄 Modo EDICIÓN - Actualizando trabajador...")
                                
                                var trabajadorData = trabajadoresListModel.get(editingIndex)
                                var trabajadorId = parseInt(trabajadorData.trabajadorId)
                                
                                var success = trabajadorModel.actualizarTrabajador(
                                    trabajadorId,
                                    nombre,
                                    apellidoPat,
                                    apellidoMat,
                                    idTipoTrabajador,
                                    matricula
                                )
                                
                                if (success) {
                                    console.log("✅ Trabajador actualizado exitosamente")
                                    
                                    if (esMedico) {
                                        console.log("⚕️ Gestionando especialidades...")
                                        
                                        var especialidadesActuales = trabajadorModel.obtenerEspecialidadesDeTrabajador(trabajadorId)
                                        if (especialidadesActuales && especialidadesActuales.length > 0) {
                                            console.log("🗑️ Eliminando", especialidadesActuales.length, "especialidades antiguas")
                                            for (var j = 0; j < especialidadesActuales.length; j++) {
                                                trabajadorModel.removerEspecialidadDeMedico(
                                                    trabajadorId,
                                                    especialidadesActuales[j].id
                                                )
                                            }
                                        }
                                        
                                        if (especialidadesPendientes.length > 0) {
                                            console.log("➕ Asignando", especialidadesPendientes.length, "especialidades nuevas")
                                            for (var i = 0; i < especialidadesPendientes.length; i++) {
                                                var esp = especialidadesPendientes[i]
                                                
                                                console.log("   Asignando:", esp.nombre, "(Principal:", esp.es_principal, ")")
                                                
                                                var asignacionExitosa = trabajadorModel.asignarEspecialidadAMedico(
                                                    trabajadorId,
                                                    esp.id,
                                                    esp.es_principal || false
                                                )
                                                
                                                if (asignacionExitosa) {
                                                    console.log("   ✅ Especialidad asignada:", esp.nombre)
                                                } else {
                                                    console.error("   ❌ Error asignando:", esp.nombre)
                                                }
                                            }
                                        }
                                    }
                                    
                                    showNewWorkerDialog = false
                                    isEditMode = false
                                    editingIndex = -1
                                    selectedRowIndex = -1
                                    actualizarInmediato()
                                } else {
                                    console.error("❌ Error actualizando trabajador")
                                }
                            } else {
                                console.log("➕ Modo CREACIÓN - Creando nuevo trabajador...")
                                
                                var success = trabajadorModel.crearTrabajador(
                                    nombre,
                                    apellidoPat,
                                    apellidoMat,
                                    idTipoTrabajador,
                                    matricula
                                )
                                
                                if (success) {
                                    console.log("✅ Trabajador creado exitosamente")
                                    
                                    if (esMedico && especialidadesPendientes.length > 0) {
                                        console.log("⚕️ Asignando especialidades al médico recién creado...")
                                        
                                        trabajadorModel.trabajadoresChanged.connect(function() {
                                            var trabajadores = trabajadorModel.trabajadores || []
                                            if (trabajadores.length > 0) {
                                                var ultimoTrabajador = trabajadores[trabajadores.length - 1]
                                                var nuevoMedicoId = ultimoTrabajador.id
                                                
                                                console.log("🆔 ID del médico recién creado:", nuevoMedicoId)
                                                
                                                for (var i = 0; i < especialidadesPendientes.length; i++) {
                                                    var esp = especialidadesPendientes[i]
                                                    
                                                    console.log("   Asignando:", esp.nombre, "(Principal:", esp.es_principal, ")")
                                                    
                                                    var asignacionExitosa = trabajadorModel.asignarEspecialidadAMedico(
                                                        nuevoMedicoId,
                                                        esp.id,
                                                        esp.es_principal || false
                                                    )
                                                    
                                                    if (asignacionExitosa) {
                                                        console.log("   ✅ Especialidad asignada:", esp.nombre)
                                                    } else {
                                                        console.error("   ❌ Error asignando:", esp.nombre)
                                                    }
                                                }
                                                
                                                console.log("✅ Proceso de asignación completado")
                                                trabajadorModel.trabajadoresChanged.disconnect(arguments.callee)
                                            }
                                        })
                                    }
                                    
                                    showNewWorkerDialog = false
                                    selectedRowIndex = -1
                                    actualizarInmediato()
                                } else {
                                    console.error("❌ Error creando trabajador")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: toastNotification
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: baseUnit * 3
        width: Math.min(parent.width * 0.9, 500)
        height: toastLayout.implicitHeight + baseUnit * 2
        radius: baseUnit * 0.8
        visible: opacity > 0
        opacity: 0
        z: 9999
        
        property string mensaje: ""
        property string tipo: "success"
        
        color: {
            switch(tipo) {
                case "success": return successColor
                case "error": return dangerColor
                case "warning": return warningColor
                case "info": return infoColor
                default: return successColor
            }
        }
        
        Behavior on opacity {
            NumberAnimation { duration: 300 }
        }
        
        function mostrar(msg, tipoMsg) {
            mensaje = msg || ""
            tipo = tipoMsg || "success"
            opacity = 1
            hideTimer.restart()
        }
        
        function ocultar() {
            opacity = 0
        }
        
        Timer {
            id: hideTimer
            interval: 4000
            repeat: false
            onTriggered: toastNotification.ocultar()
        }
        
        RowLayout {
            id: toastLayout
            anchors.fill: parent
            anchors.margins: baseUnit * 1.5
            spacing: baseUnit
            
            Label {
                text: {
                    switch(toastNotification.tipo) {
                        case "success": return "✅"
                        case "error": return "❌"
                        case "warning": return "⚠️"
                        case "info": return "ℹ️"
                        default: return "✅"
                    }
                }
                font.pixelSize: fontBaseSize * 1.5
                color: whiteColor
            }
            
            Label {
                text: toastNotification.mensaje
                font.pixelSize: fontBaseSize
                color: whiteColor
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                font.family: "Segoe UI, Arial, sans-serif"
            }
            
            Button {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                
                background: Rectangle {
                    color: parent.pressed ? "#40FFFFFF" : 
                        (parent.hovered ? "#30FFFFFF" : "transparent")
                    radius: 15
                }
                
                contentItem: Label {
                    text: "✕"
                    color: whiteColor
                    font.pixelSize: fontBaseSize * 1.2
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: toastNotification.ocultar()
                
                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
        
        MouseArea {
            anchors.fill: parent
            onClicked: toastNotification.ocultar()
        }
    }

    Dialog {
        id: confirmDeleteDialog
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.6, 450)
        height: 350
        modal: true
        closePolicy: Popup.NoAutoClose
        visible: showConfirmDeleteDialog
        
        title: ""
        
        property string dialogMode: "confirm"
        property string infoMessage: ""
        
        background: Rectangle {
            color: whiteColor
            radius: baseUnit * 0.8
            border.color: "#e0e0e0"
            border.width: 1
            
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
            
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 75
                color: confirmDeleteDialog.dialogMode === "confirm" ? "#fff5f5" : warningColorLight
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
                        color: confirmDeleteDialog.dialogMode === "confirm" ? "#fee2e2" : warningColorLight
                        radius: 22
                        border.color: confirmDeleteDialog.dialogMode === "confirm" ? "#fecaca" : warningColor
                        border.width: 2
                        
                        Label {
                            anchors.centerIn: parent
                            text: confirmDeleteDialog.dialogMode === "confirm" ? "⚠️" : "🛡️"
                            font.pixelSize: fontBaseSize * 1.8
                        }
                    }
                    
                    ColumnLayout {
                        spacing: baseUnit * 0.25
                        
                        Label {
                            text: confirmDeleteDialog.dialogMode === "confirm" ? 
                                "Confirmar Eliminación" : 
                                "No se puede eliminar"
                            font.pixelSize: fontBaseSize * 1.3
                            font.bold: true
                            color: confirmDeleteDialog.dialogMode === "confirm" ? "#dc2626" : warningColor
                            Layout.alignment: Qt.AlignLeft
                        }
                        
                        Label {
                            text: confirmDeleteDialog.dialogMode === "confirm" ? 
                                "Acción irreversible" : 
                                "Registros protegidos"
                            font.pixelSize: fontBaseSize * 0.9
                            color: "#7f8c8d"
                            Layout.alignment: Qt.AlignLeft
                        }
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
                    spacing: baseUnit * 1.5
                    
                    Item { Layout.preferredHeight: baseUnit * 0.5 }
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: baseUnit
                        visible: confirmDeleteDialog.dialogMode === "confirm"
                        
                        Label {
                            text: "¿Estás seguro de eliminar este trabajador?"
                            font.pixelSize: fontBaseSize * 1.1
                            font.bold: true
                            color: textColor
                            Layout.alignment: Qt.AlignHCenter
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                            Layout.fillWidth: true
                            font.family: "Segoe UI, Arial, sans-serif"
                        }
                        
                        Label {
                            text: "Esta acción no se puede deshacer y el registro del trabajador se eliminará permanentemente."
                            font.pixelSize: fontBaseSize
                            color: "#6b7280"
                            Layout.alignment: Qt.AlignHCenter
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                            Layout.fillWidth: true
                            Layout.leftMargin: baseUnit 
                            Layout.rightMargin: baseUnit 
                            font.family: "Segoe UI, Arial, sans-serif"
                        }
                    }
                    
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 200
                        clip: true
                        visible: confirmDeleteDialog.dialogMode === "info"
                        
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded
                        ScrollBar.vertical.interactive: true
                        
                        Label {
                            width: confirmDeleteDialog.width - baseUnit * 6
                            text: confirmDeleteDialog.infoMessage
                            font.pixelSize: fontBaseSize * 0.95
                            color: textColor
                            wrapMode: Text.WordWrap
                            lineHeight: 1.5
                            font.family: "Segoe UI, Arial, sans-serif"
                        }
                    }
                    
                    Item { Layout.fillHeight: true }
                    
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: baseUnit * 3
                        Layout.bottomMargin: baseUnit
                        Layout.topMargin: baseUnit
                        
                        Button {
                            visible: confirmDeleteDialog.dialogMode === "confirm"
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
                                confirmDeleteDialog.dialogMode = "confirm"
                            }
                            
                            HoverHandler {
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                        
                        Button {
                            Layout.preferredWidth: 130
                            Layout.preferredHeight: 45
                            
                            background: Rectangle {
                                color: {
                                    if (confirmDeleteDialog.dialogMode === "confirm") {
                                        return parent.pressed ? "#dc2626" : 
                                            (parent.hovered ? "#ef4444" : "#f87171")
                                    } else {
                                        return parent.pressed ? "#2563eb" : 
                                            (parent.hovered ? "#3b82f6" : primaryColor)
                                    }
                                }
                                radius: baseUnit * 0.6
                                border.width: 0
                                
                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                            
                            contentItem: RowLayout {
                                spacing: baseUnit * 0.5
                                
                                Label {
                                    text: confirmDeleteDialog.dialogMode === "confirm" ? "🗑️" : "✓"
                                    color: whiteColor
                                    font.pixelSize: fontBaseSize * 0.9
                                    Layout.alignment: Qt.AlignVCenter
                                }
                                
                                Label {
                                    text: confirmDeleteDialog.dialogMode === "confirm" ? "Eliminar" : "Entendido"
                                    color: whiteColor
                                    font.bold: true
                                    font.pixelSize: fontBaseSize
                                    Layout.alignment: Qt.AlignVCenter
                                    font.family: "Segoe UI, Arial, sans-serif"
                                }
                            }
                            
                            onClicked: {
                                if (confirmDeleteDialog.dialogMode === "confirm") {
                                    console.log("🗑️ Confirmando eliminación de trabajador...")
                                    
                                    if (!trabajadorModel) {
                                        console.error("❌ TrabajadorModel no disponible para eliminación")
                                        return
                                    }
                                    
                                    var trabajadorId = parseInt(trabajadorIdToDelete)
                                    trabajadorModel.eliminarTrabajador(trabajadorId)
                                } else {
                                    showConfirmDeleteDialog = false
                                    trabajadorIdToDelete = ""
                                    confirmDeleteDialog.dialogMode = "confirm"
                                }
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

    Component.onCompleted: {
        console.log("💥 Módulo Trabajadores iniciado")
        console.log("🔗 Señal irAConfigPersonal configurada para navegación")
        
        if (typeof appController === "undefined") {
            console.error("❌ CRÍTICO: appController no está disponible")
            return
        }
        
        console.log("✅ AppController disponible")

        function inicializarModelo(reintentos) {
            reintentos = reintentos || 0
            const MAX_REINTENTOS = 5
            
            if (trabajadorModel) {
                console.log("✅ TrabajadorModel disponible")

                actualizarTiposParaFiltro()
                actualizarTiposParaCombo()
                
                console.log("🔍 Verificando autenticación inicial:")
                console.log("   - trabajadorModel.usuario_actual_id:", trabajadorModel.usuario_actual_id || "undefined")
                console.log("   - trabajadorModel.esAdministrador():", trabajadorModel.esAdministrador ? trabajadorModel.esAdministrador() : "undefined")
                
                if (isModeloListo()) {
                    console.log("✅ Modelo ya está listo con", trabajadorModel.tiposTrabajador.length, "tipos")
                    
                    actualizarCombosSiEsNecesario()
                    aplicarFiltros()
                    
                    console.log("🎯 Inicialización completa inmediata")
                } else {
                    console.log("🔄 Modelo disponible pero datos aún cargando, esperando...")
                    
                    if (trabajadorModel.recargarDatos) {
                        trabajadorModel.recargarDatos()
                    }
                    
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
                                    
                                    actualizarCombosSiEsNecesario()
                                    aplicarFiltros()
                                    
                                    console.log("🎯 Inicialización completa diferida")
                                    
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
        
        Qt.callLater(function() {
            inicializarModelo(0)
        })
    }
}