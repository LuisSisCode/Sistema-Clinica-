import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

Item {
    id: serviciosBasicosRoot
    objectName: "serviciosBasicosRoot"
    
    // ✅ SISTEMA DE ESTILOS ADAPTABLES INTEGRADO
    readonly property real screenWidth: width
    readonly property real screenHeight: height
    readonly property real baseUnit: Math.min(screenWidth, screenHeight) / 40  // Unidad base escalable
    readonly property real fontScale: screenHeight / 800  // Factor de escala para fuentes
    
    // Márgenes escalables
    readonly property real marginSmall: baseUnit * 0.5
    readonly property real marginMedium: baseUnit * 1
    readonly property real marginLarge: baseUnit * 1.5
    
    // Tamaños de fuente escalables
    readonly property real fontTiny: Math.max(8, 10 * fontScale)
    readonly property real fontSmall: Math.max(10, 12 * fontScale)
    readonly property real fontBase: Math.max(12, 14 * fontScale)
    readonly property real fontMedium: Math.max(14, 16 * fontScale)
    readonly property real fontLarge: Math.max(16, 18 * fontScale)
    readonly property real fontTitle: Math.max(18, 24 * fontScale)
    
    // ===== NUEVA SEÑAL PARA NAVEGACIÓN A CONFIGURACIÓN =====
    signal irAConfigServiciosBasicos()
    
    // Acceso a colores
    readonly property color primaryColor: "#3498DB"
    readonly property color successColor: "#27ae60"
    readonly property color dangerColor: "#E74C3C"
    readonly property color warningColor: "#f39c12"
    readonly property color lightGrayColor: "#ECF0F1"
    readonly property color textColor: "#2c3e50"
    readonly property color whiteColor: "#FFFFFF"
    readonly property color infoColor: "#17a2b8"
    readonly property color violetColor: "#9b59b6"
    
    // Propiedades para los diálogos
    property bool showNewGastoDialog: false
    property bool isEditMode: false
    property int editingIndex: -1
    property int selectedRowIndex: -1
    
    // ✅ PROPIEDADES DE PAGINACIÓN CORREGIDAS
    property int itemsPerPageServicios: 10
    property int currentPageServicios: 0
    property int totalPagesServicios: 0

    // ✅ NUEVA PROPIEDAD PARA DATOS ORIGINALES (FUENTE DE VERDAD)
    property var gastosOriginales: []

    property var gastoModelInstance: null
    
    // ✅ CONEXIONES CON EL GASTOMODEL VIA APPCONTROLLER
    Connections {
        target: gastoModelInstance
        enabled: gastoModelInstance !== null
        
        function onGastosChanged() {
            if (gastoModelInstance) {
                console.log("🔄 Gastos actualizados desde AppController:", gastoModelInstance.gastos.length)
                // ✅ USAR UN TIMER PARA EVITAR LLAMADAS INMEDIATAS QUE CAUSEN LOOPS
                loadGastosTimer.restart()
            }
        }
        
        function onTiposGastosChanged() {
            if (gastoModelInstance) {
                console.log("🏷️ Tipos de gastos actualizados desde AppController:", gastoModelInstance.tiposGastos.length)
                // ✅ USAR UN TIMER PARA EVITAR LLAMADAS INMEDIATAS
                loadTiposTimer.restart()
            }
        }
        
        // ✅ EL RESTO DE LAS FUNCIONES PERMANECEN IGUAL (no causan loops)
        function onGastoCreado(success, message) {
            console.log("📝 Gasto creado:", success, message)
            if (success) {
                showSuccessMessage(message)
                showNewGastoDialog = false
                selectedRowIndex = -1
                isEditMode = false
                editingIndex = -1
            } else {
                showErrorMessage("Error creando gasto", message)
            }
        }
        
        function onGastoActualizado(success, message) {
            console.log("✏️ Gasto actualizado:", success, message)
            if (success) {
                showSuccessMessage(message)
                showNewGastoDialog = false
                selectedRowIndex = -1
                isEditMode = false
                editingIndex = -1
            } else {
                showErrorMessage("Error actualizando gasto", message)
            }
        }
        
        function onGastoEliminado(success, message) {
            console.log("🗑️ Gasto eliminado:", success, message)
            if (success) {
                showSuccessMessage(message)
                selectedRowIndex = -1
            } else {
                showErrorMessage("Error eliminando gasto", message)
            }
        }
        
        function onErrorOccurred(title, message) {
            console.error("❌ Error:", title, message)
            showErrorMessage(title, message)
        }
        
        function onSuccessMessage(message) {
            console.log("✅ Éxito:", message)
            showSuccessMessage(message)
        }
        
        function onLoadingChanged() {
            if (gastoModelInstance) {
                console.log("⏳ Loading estado:", gastoModelInstance.loading)
                loadingIndicator.visible = gastoModelInstance.loading
            }
        }
    }
    
    // ✅ AGREGAR TIMERS PARA EVITAR LLAMADAS INMEDIATAS
    Timer {
        id: loadGastosTimer
        interval: 100  // 100ms de delay
        repeat: false
        onTriggered: {
            if (gastoModelInstance) {
                loadGastosFromModel()
            }
        }
    }
    
    Timer {
        id: loadTiposTimer
        interval: 100  // 100ms de delay
        repeat: false
        onTriggered: {
            if (gastoModelInstance) {
                loadTiposGastosFromModel()
            }
        }
    }
    // ✅ CONEXIONES CON APPCONTROLLER PARA NOTIFICACIONES
    Connections {
        target: appController
        
        function onModelsReady() {
            console.log("🚀 Models listos desde AppController")
            // Obtener referencia al modelo cuando esté disponible
            if (appController && appController.gasto_model_instance) {
                gastoModelInstance = appController.gasto_model_instance
                console.log("✅ GastoModel disponible")
                loadGastosFromModel()
                loadTiposGastosFromModel()
            } else {
                console.log("⚠️ GastoModel no disponible aún")
                delayedInitTimer.start()
            }
        }
    }
    // ✅ TIMER PARA INICIALIZACIÓN RETRASADA
    Timer {
        id: delayedInitTimer
        interval: 500
        repeat: false
        onTriggered: {
            // ✅ CORREGIR ESTA FUNCIÓN:
            if (appController && appController.gasto_model_instance) {
                gastoModelInstance = appController.gasto_model_instance
                console.log("🔄 Inicialización retrasada exitosa")
                loadGastosFromModel()
                loadTiposGastosFromModel()
            } else {
                console.log("❌ GastoModel aún no disponible")
                // Intentar de nuevo después de más tiempo
                if (interval < 2000) {
                    interval = interval * 2
                    start()
                }
            }
        }
    }
    
    // ✅ FUNCIÓN PARA CARGAR GASTOS DESDE EL MODELO VIA APPCONTROLLER
    function loadGastosFromModel() {
        if (!gastoModelInstance) {
            console.log("⚠️ GastoModel no disponible para cargar gastos")
            return
        }
        
        console.log("📊 Cargando gastos desde modelo...")
        
        gastosOriginales = []
        gastosListModel.clear()
        
        var gastos = gastoModelInstance.gastos
        for (var i = 0; i < gastos.length; i++) {
            var gasto = gastos[i]
            
            var gastoFormatted = {
                gastoId: gasto.id || (i + 1),
                tipoGasto: gasto.tipo_nombre || "Sin tipo",
                descripcion: gasto.descripcion || "Sin descripción",
                monto: parseFloat(gasto.Monto || 0).toFixed(2),
                fechaGasto: formatDateFromModel(gasto.Fecha),
                proveedorEmpresa: gasto.proveedor || "Sin proveedor",
                registradoPor: gasto.usuario_completo || "Usuario desconocido"
            }
            
            gastosOriginales.push(gastoFormatted)
            gastosListModel.append(gastoFormatted)
        }
        
        console.log("📊 Gastos cargados:", gastosOriginales.length)
    }
    
    // ✅ NUEVA FUNCIÓN QUE NO TRIGGEEA SEÑALES DEL MODELO
    function aplicarFiltrosDirecto() {
        console.log("🔍 Aplicando filtros directamente...")
        
        // Limpiar el modelo filtrado
        gastosListModel.clear()
        
        var hoy = new Date()
        var textoBusqueda = campoBusqueda.text.toLowerCase()
        
        for (var i = 0; i < gastosOriginales.length; i++) {
            var gasto = gastosOriginales[i]
            var mostrar = true
            
            // Filtro por tipo de gasto
            if (filtroTipoGasto.currentIndex > 0 && mostrar) {
                var tipoSeleccionado = filtroTipoGasto.model[filtroTipoGasto.currentIndex]
                if (gasto.tipoGasto !== tipoSeleccionado) {
                    mostrar = false
                }
            }
            
            // Filtro por fecha
            if (filtroFecha.currentIndex > 0 && mostrar) {
                var fechaGasto = new Date(gasto.fechaGasto)
                var diferenciaDias = Math.floor((hoy - fechaGasto) / (1000 * 60 * 60 * 24))
                
                switch(filtroFecha.currentIndex) {
                    case 1: // Este mes
                        if (diferenciaDias > 30) mostrar = false
                        break
                    case 2: // Mes anterior
                        if (diferenciaDias <= 30 || diferenciaDias > 60) mostrar = false
                        break
                    case 3: // Últimos 3 meses
                        if (diferenciaDias > 90) mostrar = false
                        break
                }
            }
            
            // Búsqueda por texto
            if (textoBusqueda.length > 0 && mostrar) {
                if (!gasto.descripcion.toLowerCase().includes(textoBusqueda) && 
                    !gasto.proveedorEmpresa.toLowerCase().includes(textoBusqueda)) {
                    mostrar = false
                }
            }
            
            if (mostrar) {
                gastosListModel.append(gasto)
            }
        }
        
        // Resetear a primera página y actualizar paginación
        currentPageServicios = 0
        updatePaginatedModel()
        
        console.log("✅ Filtros aplicados directamente. Gastos mostrados:", gastosListModel.count)
    }
    
    // ✅ FUNCIÓN PARA CARGAR TIPOS DE GASTOS DESDE EL MODELO VIA APPCONTROLLER
    function loadTiposGastosFromModel() {
        if (!gastoModelInstance) {
            console.log("⚠️ GastoModel no disponible para cargar tipos")
            return
        }
        
        console.log("🏷️ Cargando tipos desde modelo...")
        
        // ✅ LIMPIAR COMPLETAMENTE EL MODELO ANTES DE AGREGAR NUEVOS DATOS
        tiposGastosModel.clear()
        
        var tipos = gastoModelInstance.tiposGastos
        for (var i = 0; i < tipos.length; i++) {
            var tipo = tipos[i]
            
            // ✅ CREAR OBJETO CON TIPOS CONSISTENTES
            var tipoFormatted = {
                id: parseInt(tipo.id || 0),
                nombre: String(tipo.Nombre || "Sin nombre"),
                descripcion: String(tipo.descripcion || "Tipo de gasto"),
                ejemplos: [],  // Siempre array vacío para evitar conflictos
                color: String(getColorForTipo(tipo.Nombre || ""))  // ✅ SIEMPRE STRING
            }
            
            tiposGastosModel.append(tipoFormatted)
        }
        
        console.log("🏷️ Tipos de gastos cargados:", tiposGastosModel.count)
        
        // Actualizar ComboBox
        filtroTipoGasto.model = getTiposGastosNombres()
    }
    
    
    // ✅ FUNCIÓN OVERRIDE PARA CREAR GASTO CON MODELO REAL VIA APPCONTROLLER
    function createGastoWithModel(gastoData) {
        if (!gastoModelInstance) {
            console.log("❌ GastoModel no disponible para crear gasto")
            showErrorMessage("Error", "Sistema no disponible")
            return false
        }
        
        console.log("💰 Creando gasto con modelo real via AppController...")
        
        // Obtener ID del tipo de gasto seleccionado
        var tipoGastoId = 0
        if (gastoForm.selectedTipoGastoIndex >= 0) {
            var tipoSeleccionado = tiposGastosModel.get(gastoForm.selectedTipoGastoIndex)
            tipoGastoId = tipoSeleccionado.id
        }
        
        // Llamar al modelo real via AppController
        var success = gastoModelInstance.crearGasto(
            tipoGastoId,                    // tipo_gasto_id
            parseFloat(gastoData.monto),    // monto
            1,                              // usuario_id (temporal - usar usuario actual)
            gastoData.descripcion,          // descripcion
            gastoData.fechaGasto           // fecha_gasto
        )
        
        console.log("📝 Resultado creación:", success)
        return success
    }
    
    // ✅ FUNCIÓN OVERRIDE PARA ACTUALIZAR GASTO CON MODELO REAL VIA APPCONTROLLER
    function updateGastoWithModel(gastoId, gastoData) {
        if (!gastoModelInstance) {
            console.log("❌ GastoModel no disponible para actualizar gasto")
            showErrorMessage("Error", "Sistema no disponible")
            return false
        }
        
        console.log("✏️ Actualizando gasto con modelo real via AppController...")
        
        // Obtener ID del tipo de gasto seleccionado
        var tipoGastoId = 0
        if (gastoForm.selectedTipoGastoIndex >= 0) {
            var tipoSeleccionado = tiposGastosModel.get(gastoForm.selectedTipoGastoIndex)
            tipoGastoId = tipoSeleccionado.id
        }
        
        // Llamar al modelo real via AppController
        var success = gastoModelInstance.actualizarGasto(
            parseInt(gastoId),              // gasto_id
            parseFloat(gastoData.monto),    // monto
            tipoGastoId                     // tipo_gasto_id
        )
        
        console.log("✏️ Resultado actualización:", success)
        return success
    }
    
    // ✅ FUNCIÓN OVERRIDE PARA ELIMINAR GASTO CON MODELO REAL VIA APPCONTROLLER
    function deleteGastoWithModel(gastoId) {
        if (!gastoModelInstance) {
            console.log("❌ GastoModel no disponible para eliminar gasto")
            showErrorMessage("Error", "Sistema no disponible")
            return false
        }
        
        console.log("🗑️ Eliminando gasto con modelo real via AppController...")
        
        var success = gastoModelInstance.eliminarGasto(parseInt(gastoId))
        
        console.log("🗑️ Resultado eliminación:", success)
        return success
    }
    
    // ✅ FUNCIONES HELPER (MANTENER IGUALES)
    function formatDateFromModel(dateValue) {
        if (!dateValue) return Qt.formatDate(new Date(), "yyyy-MM-dd")
        
        if (typeof dateValue === "string") {
            return dateValue.substring(0, 10)
        }
        
        if (dateValue instanceof Date) {
            return Qt.formatDate(dateValue, "yyyy-MM-dd")
        }
        
        return Qt.formatDate(new Date(), "yyyy-MM-dd")
    }
    
    function getColorForTipo(nombreTipo) {
        switch(nombreTipo) {
            case "Servicios Básicos": return infoColor
            case "Personal": return violetColor
            case "Alimentación": return successColor
            case "Mantenimiento": return warningColor
            case "Administrativos": return primaryColor
            case "Suministros Médicos": return "#e67e22"
            default: return "#95a5a6"
        }
    }
    
    function showSuccessMessage(message) {
        successToast.text = message
        successToast.visible = true
        successToast.hideTimer.restart()
    }
    
    function showErrorMessage(title, message) {
        errorDialog.title = title
        errorDialog.text = message
        errorDialog.open()
    }
    // ===== PROPIEDAD PARA EXPONER EL MODELO DE DATOS =====
    property alias tiposGastosModel: tiposGastosModel
    
    // ✅ MODELO DE TIPOS DE GASTOS LOCAL (FALLBACK)
    ListModel {
        id: tiposGastosModel
    }

    // ✅ MODELOS SEPARADOS PARA PAGINACIÓN (PATRÓN DE TRES CAPAS)
    ListModel {
        id: gastosListModel // Modelo filtrado (todos los resultados del filtro)
    }
    
    ListModel {
        id: gastosPaginadosModel // Modelo para la página actual
    }

    // Función helper para obtener nombres de tipos de gastos
    function getTiposGastosNombres() {
        var nombres = ["Todos los tipos"]
        for (var i = 0; i < tiposGastosModel.count; i++) {
            nombres.push(tiposGastosModel.get(i).nombre)
        }
        return nombres
    }

    // Función helper para obtener nombres para ComboBox de nuevo gasto
    function getTiposGastosParaCombo() {
        var nombres = ["Seleccionar tipo..."]
        for (var i = 0; i < tiposGastosModel.count; i++) {
            nombres.push(tiposGastosModel.get(i).nombre)
        }
        return nombres
    }
    // ✅ FUNCIÓN PARA APLICAR FILTROS VIA APPCONTROLLER  
    function aplicarFiltros() {
        // ✅ SI NO HAY DATOS ORIGINALES, NO HACER NADA
        if (gastosOriginales.length === 0) {
            console.log("⚠️ No hay datos originales para filtrar")
            return
        }
        
        // ✅ APLICAR FILTROS DIRECTAMENTE SIN INTERACTUAR CON EL MODELO
        aplicarFiltrosDirecto()
    }
    
    // ✅ FUNCIÓN PARA APLICAR FILTROS VIA MODELO SOLO CUANDO SEA NECESARIO
    function aplicarFiltrosViaModelo() {
        if (!gastoModelInstance) {
            console.log("⚠️ GastoModel no disponible para aplicar filtros")
            return
        }
        
        console.log("🔍 Aplicando filtros via AppController...")
        
        var termino_busqueda = campoBusqueda.text.trim()
        var tipo_gasto_id = 0
        var fecha_desde = ""
        var fecha_hasta = ""
        var monto_min = 0.0
        var monto_max = 0.0
        
        // Obtener tipo de gasto seleccionado
        if (filtroTipoGasto.currentIndex > 0) {
            var tipoSeleccionado = tiposGastosModel.get(filtroTipoGasto.currentIndex - 1)
            tipo_gasto_id = tipoSeleccionado.id
        }
        
        // Calcular fechas según filtro
        var hoy = new Date()
        switch(filtroFecha.currentIndex) {
            case 1: // Este mes
                fecha_desde = Qt.formatDate(new Date(hoy.getFullYear(), hoy.getMonth(), 1), "yyyy-MM-dd")
                fecha_hasta = Qt.formatDate(hoy, "yyyy-MM-dd")
                break
            case 2: // Mes anterior
                var mesAnterior = new Date(hoy.getFullYear(), hoy.getMonth() - 1, 1)
                fecha_desde = Qt.formatDate(mesAnterior, "yyyy-MM-dd")
                fecha_hasta = Qt.formatDate(new Date(hoy.getFullYear(), hoy.getMonth(), 0), "yyyy-MM-dd")
                break
            case 3: // Últimos 3 meses
                fecha_desde = Qt.formatDate(new Date(hoy.getFullYear(), hoy.getMonth() - 3, 1), "yyyy-MM-dd")
                fecha_hasta = Qt.formatDate(hoy, "yyyy-MM-dd")
                break
        }
        
        // ✅ SOLO APLICAR FILTROS VIA MODELO SI ES NECESARIO
        // Por ahora, usar filtros locales para evitar loops
        aplicarFiltrosDirecto()
    }
    
    // ✅ ACTUALIZAR LOS EVENTOS DE LOS FILTROS PARA USAR LA FUNCIÓN CORRECTA
    function onFiltroChanged() {
        // ✅ USAR FILTROS DIRECTOS EN LUGAR DE VIA MODELO
        aplicarFiltrosDirecto()
    }
    // ✅ FUNCIÓN PARA ACTUALIZAR PAGINACIÓN
    function updatePaginatedModel() {
        console.log("🔄 Servicios Básicos: Actualizando paginación - Página:", currentPageServicios + 1)
        
        // Limpiar modelo paginado
        gastosPaginadosModel.clear()
        
        // Calcular total de páginas basado en gastos filtrados
        var totalItems = gastosListModel.count
        totalPagesServicios = Math.ceil(totalItems / itemsPerPageServicios)
        
        // Asegurar que siempre hay al menos 1 página
        if (totalPagesServicios === 0) {
            totalPagesServicios = 1
        }
        
        // Ajustar página actual si es necesario
        if (currentPageServicios >= totalPagesServicios && totalPagesServicios > 0) {
            currentPageServicios = totalPagesServicios - 1
        }
        if (currentPageServicios < 0) {
            currentPageServicios = 0
        }
        
        // Calcular índices
        var startIndex = currentPageServicios * itemsPerPageServicios
        var endIndex = Math.min(startIndex + itemsPerPageServicios, totalItems)
        
        // Agregar elementos de la página actual
        for (var i = startIndex; i < endIndex; i++) {
            var gasto = gastosListModel.get(i)
            gastosPaginadosModel.append(gasto)
        }
        
        console.log("🔄 Servicios Básicos: Página", currentPageServicios + 1, "de", totalPagesServicios,
                    "- Mostrando", gastosPaginadosModel.count, "de", totalItems)
    }

    // ✅ FUNCIÓN PARA OBTENER TOTAL DE GASTOS
    function getTotalServiciosCount() {
        return gastosOriginales.length
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: marginLarge
        spacing: marginLarge
        
        // Contenido principal
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: whiteColor
            radius: 20
            border.color: "#e0e0e0"
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                
                // ✅ HEADER RESPONSIVO
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(60, screenHeight * 0.08)
                    color: "#f8f9fa"
                    border.color: "#e0e0e0"
                    border.width: 1
                    Rectangle {
                        anchors.fill: parent
                        anchors.bottomMargin: marginMedium
                        color: parent.color
                        radius: parent.radius
                    }
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: marginMedium
                        
                        RowLayout {
                            spacing: marginSmall
                            
                            Label {
                                text: "💰"
                                font.pixelSize: fontTitle
                                color: primaryColor
                            }
                            
                            Label {
                                text: "Gestión de Servicios Básicos y Gastos Operativos"
                                font.pixelSize: fontLarge
                                font.bold: true
                                color: textColor
                            }
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        Button {
                            objectName: "newGastoButton"
                            text: "➕ Nuevo Gasto"
                            Layout.preferredHeight: Math.max(36, screenHeight * 0.045)
                            
                            background: Rectangle {
                                color: primaryColor
                                radius: baseUnit * 0.3
                            }
                            
                            contentItem: Label {
                                text: parent.text
                                color: whiteColor
                                font.bold: true
                                font.pixelSize: fontBase
                                horizontalAlignment: Text.AlignHCenter
                            }
                            
                            onClicked: {
                                isEditMode = false
                                editingIndex = -1
                                showNewGastoDialog = true
                            }
                        }
                    }
                }
                
                // ✅ FILTROS RESPONSIVOS
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(70, screenHeight * 0.09)
                    color: "transparent"
                    z: 10
                    
                    // ✅ USAR FLOWLAYOUT PARA ADAPTARSE A DIFERENTES TAMAÑOS
                    Flow {
                        anchors.fill: parent
                        anchors.margins: marginMedium
                        spacing: marginSmall
                        
                        // ✅ PRIMER GRUPO DE FILTROS
                        Row {
                            spacing: marginSmall
                            
                            Label {
                                text: "Filtrar por:"
                                font.bold: true
                                font.pixelSize: fontBase
                                color: textColor
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            
                            ComboBox {
                                id: filtroTipoGasto
                                width: Math.max(160, screenWidth * 0.15)
                                model: getTiposGastosNombres()
                                currentIndex: 0
                                onCurrentIndexChanged: onFiltroChanged()
                            }
                            
                            Label {
                                text: "Fecha:"
                                font.bold: true
                                font.pixelSize: fontBase
                                color: textColor
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            
                            ComboBox {
                                id: filtroFecha
                                width: Math.max(140, screenWidth * 0.14)
                                model: ["Todas", "Este mes", "Mes anterior", "Últimos 3 meses"]
                                currentIndex: 0
                                onCurrentIndexChanged: onFiltroChanged()
                            }
                        }
                        
                        // ✅ SEGUNDO GRUPO DE FILTROS
                        Row {
                            spacing: marginSmall
                            
                            TextField {
                                id: campoBusqueda
                                width: Math.max(180, screenWidth * 0.18)
                                placeholderText: "Buscar gasto..."
                                onTextChanged: onFiltroChanged()
                                
                                background: Rectangle {
                                    color: whiteColor
                                    border.color: "#e0e0e0"
                                    border.width: 1
                                    radius: baseUnit * 0.2
                                }
                            }
                        }
                    }
                }
            
                // ✅ CONTENEDOR DE TABLA COMPLETAMENTE RESPONSIVO
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.margins: marginMedium
                    Layout.topMargin: 0
                    color: "#FFFFFF"
                    border.color: "#D5DBDB"
                    border.width: 1
                    radius: baseUnit * 0.2
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 0
                        spacing: 0
                        
                        // ✅ HEADER DE TABLA CON ANCHOS PROPORCIONALES
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.max(40, screenHeight * 0.06)
                            color: "#f5f5f5"
                            border.color: "#d0d0d0"
                            border.width: 1
                            z: 5
                            
                            RowLayout {
                                anchors.fill: parent
                                spacing: 0
                                
                                Rectangle {
                                    Layout.preferredWidth: parent.width * 0.06
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#d0d0d0"
                                    border.width: 1
                                    
                                    Label { 
                                        anchors.centerIn: parent
                                        text: "ID"
                                        font.bold: true
                                        font.pixelSize: fontSmall
                                        color: textColor
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: parent.width * 0.18
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#d0d0d0"
                                    border.width: 1
                                    
                                    Label { 
                                        anchors.centerIn: parent
                                        text: "TIPO DE GASTO"
                                        font.bold: true
                                        font.pixelSize: fontSmall
                                        color: textColor
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: parent.width * 0.25
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#d0d0d0"
                                    border.width: 1
                                    
                                    Label { 
                                        anchors.centerIn: parent
                                        text: "DESCRIPCIÓN"
                                        font.bold: true
                                        font.pixelSize: fontSmall
                                        color: textColor
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: parent.width * 0.12
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#d0d0d0"
                                    border.width: 1
                                    
                                    Label { 
                                        anchors.centerIn: parent
                                        text: "MONTO"
                                        font.bold: true
                                        font.pixelSize: fontSmall
                                        color: textColor
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: parent.width * 0.14
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#d0d0d0"
                                    border.width: 1
                                    
                                    Label { 
                                        anchors.centerIn: parent
                                        text: "FECHA GASTO"
                                        font.bold: true
                                        font.pixelSize: fontSmall
                                        color: textColor
                                    }
                                }
                                
                                Rectangle {
                                    Layout.preferredWidth: parent.width * 0.17
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#d0d0d0"
                                    border.width: 1
                                    
                                    Label { 
                                        anchors.centerIn: parent
                                        text: "PROVEEDOR"
                                        font.bold: true
                                        font.pixelSize: fontSmall
                                        color: textColor
                                    }
                                }
                                
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#d0d0d0"
                                    border.width: 1
                                    
                                    Label { 
                                        anchors.centerIn: parent
                                        text: "REGISTRADO POR"
                                        font.bold: true
                                        font.pixelSize: fontSmall
                                        color: textColor
                                    }
                                }
                            }
                        }
                        
                        // ✅ CONTENIDO DE TABLA CON ALTURA ADAPTABLE
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            
                            ListView {
                                id: gastosListView
                                model: gastosPaginadosModel // ✅ CAMBIADO PARA USAR EL MODELO PAGINADO
                                
                                delegate: Rectangle {
                                    width: ListView.view.width
                                    height: Math.max(45, screenHeight * 0.06)  // Altura adaptable
                                    color: {
                                        if (selectedRowIndex === index) return "#e3f2fd"
                                        return index % 2 === 0 ? "transparent" : "#fafafa"
                                    }
                                    border.color: selectedRowIndex === index ? primaryColor : "#e8e8e8"
                                    border.width: selectedRowIndex === index ? 2 : 1
                                
                                    RowLayout {
                                        anchors.fill: parent
                                        spacing: 0
                                        
                                        Rectangle {
                                            Layout.preferredWidth: parent.width * 0.06
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Label { 
                                                anchors.centerIn: parent
                                                text: model.gastoId
                                                color: textColor
                                                font.bold: true
                                                font.pixelSize: fontSmall
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: parent.width * 0.18
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: Math.min(parent.width * 0.9, baseUnit * 6)
                                                height: Math.min(parent.height * 0.4, baseUnit * 1)
                                                color: getColorForTipo(model.tipoGasto)
                                                radius: height / 2
                                                
                                                Label {
                                                    anchors.centerIn: parent
                                                    text: model.tipoGasto
                                                    color: whiteColor
                                                    font.pixelSize: fontTiny
                                                    font.bold: true
                                                }
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: parent.width * 0.25
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Label { 
                                                anchors.fill: parent
                                                anchors.margins: marginSmall * 0.5
                                                text: model.descripcion
                                                color: textColor
                                                font.pixelSize: fontTiny
                                                elide: Text.ElideRight
                                                wrapMode: Text.WordWrap
                                                maximumLineCount: 2
                                                verticalAlignment: Text.AlignVCenter
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: parent.width * 0.12
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Label { 
                                                anchors.centerIn: parent
                                                text: "Bs" + model.monto
                                                color: {
                                                    var monto = parseFloat(model.monto)
                                                    if (monto > 1000) return dangerColor
                                                    if (monto > 500) return warningColor
                                                    return successColor
                                                }
                                                font.bold: true
                                                font.pixelSize: fontTiny
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: parent.width * 0.14
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Label { 
                                                anchors.centerIn: parent
                                                text: model.fechaGasto
                                                color: textColor
                                                font.pixelSize: fontTiny
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.preferredWidth: parent.width * 0.17
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Label { 
                                                anchors.fill: parent
                                                anchors.margins: marginSmall * 0.25
                                                text: model.proveedorEmpresa
                                                color: "#7f8c8d"
                                                font.pixelSize: fontTiny
                                                elide: Text.ElideRight
                                                wrapMode: Text.WordWrap
                                                maximumLineCount: 2
                                                verticalAlignment: Text.AlignVCenter
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                        }
                                        
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Label { 
                                                anchors.fill: parent
                                                anchors.margins: marginSmall * 0.25
                                                text: model.registradoPor || "Luis López"
                                                color: "#7f8c8d"
                                                font.pixelSize: fontTiny
                                                elide: Text.ElideRight
                                                wrapMode: Text.WordWrap
                                                maximumLineCount: 2
                                                verticalAlignment: Text.AlignVCenter
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                        }
                                    }
                                
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            selectedRowIndex = index
                                            console.log("Seleccionado gasto ID:", model.gastoId)
                                        }
                                    }
                                    
                                    // ✅ BOTONES DE ACCIÓN ADAPTABLES
                                    RowLayout {
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: marginSmall * 0.5
                                        spacing: marginSmall * 0.25
                                        visible: selectedRowIndex === index
                                        z: 10
                                        
                                        Button {
                                            id: editButton
                                            width: Math.max(20, baseUnit * 1.5)
                                            height: width
                                            text: "✏️"
                                            
                                            background: Rectangle {
                                                color: warningColor
                                                radius: width / 2
                                                border.color: "#f1c40f"
                                                border.width: 1
                                            }
                                            
                                            contentItem: Label {
                                                text: parent.text
                                                color: whiteColor
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                                font.pixelSize: fontTiny
                                            }
                                            
                                            onClicked: {
                                                var gastoId = model.gastoId
                                                var realIndex = -1
                                                
                                                // Buscar el índice real en gastosListModel
                                                for (var i = 0; i < gastosListModel.count; i++) {
                                                    if (gastosListModel.get(i).gastoId === gastoId) {
                                                        realIndex = i
                                                        break
                                                    }
                                                }
                                                
                                                isEditMode = true
                                                editingIndex = realIndex
                                                
                                                console.log("Editando gasto ID:", gastoId, "índice real:", realIndex)
                                                showNewGastoDialog = true
                                            }
                                        }
                                        
                                        Button {
                                            id: deleteButton
                                            width: Math.max(20, baseUnit * 1.5)
                                            height: width
                                            text: "🗑️"
                                            
                                            background: Rectangle {
                                                color: dangerColor
                                                radius: width / 2
                                                border.color: "#c0392b"
                                                border.width: 1
                                            }
                                            
                                            contentItem: Label {
                                                text: parent.text
                                                color: whiteColor
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                                font.pixelSize: fontTiny
                                            }
                                            
                                            onClicked: {
                                                var gastoId = model.gastoId
                                                confirmDeleteDialog.gastoIdToDelete = gastoId
                                                confirmDeleteDialog.open()
                                            } 
                                        }
                                    }
                                }
                            }
                            
                            // ✅ ESTADO VACÍO PARA TABLA SIN DATOS
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                visible: gastosPaginadosModel.count === 0
                                spacing: marginLarge
                                
                                Item { Layout.fillHeight: true }
                                
                                ColumnLayout {
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: marginMedium
                                    
                                    Label {
                                        text: "💰"
                                        font.pixelSize: fontTitle * 3
                                        color: "#E5E7EB"
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                    
                                    Label {
                                        text: "No hay gastos registrados"
                                        color: textColor
                                        font.bold: true
                                        font.pixelSize: fontLarge
                                        Layout.alignment: Qt.AlignHCenter
                                        font.family: "Segoe UI"
                                    }
                                    
                                    Label {
                                        text: "Registra el primer gasto haciendo clic en \"➕ Nuevo Gasto\""
                                        color: "#6B7280"
                                        font.pixelSize: fontBase
                                        Layout.alignment: Qt.AlignHCenter
                                        wrapMode: Text.WordWrap
                                        horizontalAlignment: Text.AlignHCenter
                                        font.family: "Segoe UI"
                                        Layout.maximumWidth: 400
                                    }
                                }
                                
                                Item { Layout.fillHeight: true }
                            }
                        }
                    }
                }
                
                // ✅ CONTROL DE PAGINACIÓN RESPONSIVO - MOVIDO FUERA DE LA TABLA
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(50, screenHeight * 0.08)
                    Layout.margins: marginMedium
                    Layout.topMargin: 0
                    color: "#F8F9FA"
                    border.color: "#D5DBDB"
                    border.width: 1
                    radius: baseUnit * 0.2
                    
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: marginLarge
                        
                        // Botón Anterior
                        Button {
                            Layout.preferredWidth: Math.max(80, screenWidth * 0.08)
                            Layout.preferredHeight: Math.max(32, screenHeight * 0.05)
                            text: "← Anterior"
                            enabled: currentPageServicios > 0
                            
                            background: Rectangle {
                                color: parent.enabled ? 
                                    (parent.pressed ? "#E5E7EB" : "#F3F4F6") : 
                                    "#E5E7EB"
                                radius: height / 2
                                border.color: parent.enabled ? "#D1D5DB" : "#E5E7EB"
                                border.width: 1
                                
                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                            
                            contentItem: Label {
                                text: parent.text
                                color: parent.enabled ? "#374151" : "#9CA3AF"
                                font.bold: true
                                font.pixelSize: fontBase
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: {
                                if (currentPageServicios > 0) {
                                    currentPageServicios--
                                    updatePaginatedModel()
                                }
                            }
                        }
                        
                        // Indicador de página
                        Label {
                            text: "Página " + (currentPageServicios + 1) + " de " + Math.max(1, totalPagesServicios)
                            color: "#374151"
                            font.pixelSize: fontBase
                            font.weight: Font.Medium
                        }
                        
                        // Botón Siguiente
                        Button {
                            Layout.preferredWidth: Math.max(90, screenWidth * 0.09)
                            Layout.preferredHeight: Math.max(32, screenHeight * 0.05)
                            text: "Siguiente →"
                            enabled: currentPageServicios < totalPagesServicios - 1
                            
                            background: Rectangle {
                                color: parent.enabled ? 
                                    (parent.pressed ? Qt.darker("#10B981", 1.1) : "#10B981") : 
                                    "#E5E7EB"
                                radius: height / 2
                                
                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                            
                            contentItem: Label {
                                text: parent.text
                                color: parent.enabled ? "#FFFFFF" : "#9CA3AF"
                                font.bold: true
                                font.pixelSize: fontBase
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: {
                                if (currentPageServicios < totalPagesServicios - 1) {
                                    currentPageServicios++
                                    updatePaginatedModel()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Diálogo Nuevo Gasto / Editar Gasto
    Rectangle {
        id: newGastoDialog
        anchors.fill: parent
        color: "black"
        opacity: showNewGastoDialog ? 0.5 : 0
        visible: opacity > 0
        
        MouseArea {
            anchors.fill: parent
            onClicked: {
                showNewGastoDialog = false
                selectedRowIndex = -1
            }
        }
        
        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }
    }
    
    Rectangle {
        id: gastoForm
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.9, 600)  // ✅ Ancho adaptable
        height: Math.min(parent.height * 0.9, 550)  // ✅ Altura adaptable
        color: whiteColor
        radius: baseUnit * 0.5
        border.color: lightGrayColor
        border.width: 2
        visible: showNewGastoDialog
        
        property int selectedTipoGastoIndex: -1
        
        // ✅ FUNCIÓN PARA CARGAR DATOS EN MODO EDICIÓN ACTUALIZADA
        function loadEditData() {
            if (isEditMode && editingIndex >= 0) {
                var gasto = gastosListModel.get(editingIndex)
                
                // Buscar el tipo de gasto correspondiente
                var tipoGastoNombre = gasto.tipoGasto
                for (var i = 0; i < tiposGastosModel.count; i++) {
                    if (tiposGastosModel.get(i).nombre === tipoGastoNombre) {
                        tipoGastoCombo.currentIndex = i + 1
                        gastoForm.selectedTipoGastoIndex = i
                        break
                    }
                }
                // Cargar descripción
                descripcionField.text = gasto.descripcion
                montoField.text = gasto.monto
                fechaGastoField.text = gasto.fechaGasto
                proveedorField.text = gasto.proveedorEmpresa
            }
        }
        
        onVisibleChanged: {
            if (visible && isEditMode) {
                loadEditData()
            } else if (visible && !isEditMode) {
                // Limpiar formulario para nuevo gasto
                tipoGastoCombo.currentIndex = 0
                tipoGastoCombo.model = getTiposGastosParaCombo()
                descripcionField.text = ""
                montoField.text = ""
                fechaGastoField.text = Qt.formatDate(new Date(), "yyyy-MM-dd")
                proveedorField.text = ""
                gastoForm.selectedTipoGastoIndex = -1
            }
        }
        
        // ✅ SCROLL PARA FORMULARIOS LARGOS
        ScrollView {
            anchors.fill: parent
            anchors.margins: marginLarge
            clip: true
            
            ColumnLayout {
                width: parent.width - marginLarge * 2
                spacing: marginMedium
                
                // Título
                Label {
                    Layout.fillWidth: true
                    text: isEditMode ? "Editar Gasto" : "Nuevo Gasto"
                    font.pixelSize: fontTitle
                    font.bold: true
                    color: textColor
                    horizontalAlignment: Text.AlignHCenter
                }
            
                // Información del Gasto
                GroupBox {
                    Layout.fillWidth: true
                    title: "Información del Gasto"
                    
                    background: Rectangle {
                        color: "#f8f9fa"
                        border.color: lightGrayColor
                        border.width: 1
                        radius: baseUnit * 0.2
                    }
                    
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: marginSmall
                        
                        // Tipo de Gasto
                        GridLayout {
                            Layout.fillWidth: true
                            columns: screenWidth > 400 ? 2 : 1  // ✅ Adaptable
                            columnSpacing: marginSmall
                            
                            Label {
                                text: "Tipo de Gasto:"
                                font.bold: true
                                font.pixelSize: fontBase
                                color: textColor
                            }
                            ComboBox {
                                id: tipoGastoCombo
                                Layout.fillWidth: true
                                font.pixelSize: fontBase
                                model: getTiposGastosParaCombo()
                                onCurrentIndexChanged: {
                                    if (currentIndex > 0) {
                                        gastoForm.selectedTipoGastoIndex = currentIndex - 1
                                    } else {
                                        gastoForm.selectedTipoGastoIndex = -1
                                    }
                                }
                            }
                        }
                        
                        // Descripción
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            
                            Label {
                                text: "Descripción:"
                                font.bold: true
                                font.pixelSize: fontBase
                                color: textColor
                            }
                            
                            ScrollView {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.max(60, screenHeight * 0.08)
                                
                                TextArea {
                                    id: descripcionField
                                    placeholderText: "Descripción detallada del gasto..."
                                    font.pixelSize: fontBase
                                    wrapMode: TextArea.Wrap
                                    background: Rectangle {
                                        color: whiteColor
                                        border.color: lightGrayColor
                                        border.width: 1
                                        radius: baseUnit * 0.15
                                    }
                                }
                            }
                        }
                        
                        // Monto y Fecha
                        GridLayout {
                            Layout.fillWidth: true
                            columns: screenWidth > 400 ? 2 : 1
                            columnSpacing: marginSmall
                            
                            ColumnLayout {
                                Layout.fillWidth: true
                                Label {
                                    text: "Monto (Bs):"
                                    font.bold: true
                                    font.pixelSize: fontBase
                                    color: textColor
                                }
                                TextField {
                                    id: montoField
                                    Layout.fillWidth: true
                                    placeholderText: "0.00"
                                    font.pixelSize: fontBase
                                    validator: DoubleValidator { bottom: 0.0; decimals: 2 }
                                    background: Rectangle {
                                        color: whiteColor
                                        border.color: lightGrayColor
                                        border.width: 1
                                        radius: baseUnit * 0.15
                                    }
                                }
                            }
                            
                            ColumnLayout {
                                Layout.fillWidth: true
                                Label {
                                    text: "Fecha del Gasto:"
                                    font.bold: true
                                    font.pixelSize: fontBase
                                    color: textColor
                                }
                                TextField {
                                    id: fechaGastoField
                                    Layout.fillWidth: true
                                    placeholderText: "YYYY-MM-DD"
                                    font.pixelSize: fontBase
                                    text: Qt.formatDate(new Date(), "yyyy-MM-dd")
                                    background: Rectangle {
                                        color: whiteColor
                                        border.color: lightGrayColor
                                        border.width: 1
                                        radius: baseUnit * 0.15
                                    }
                                }
                            }
                        }
                        
                        // Proveedor/Empresa
                        GridLayout {
                            Layout.fillWidth: true
                            columns: screenWidth > 400 ? 2 : 1
                            columnSpacing: marginSmall
                            
                            Label {
                                text: "Proveedor/Empresa:"
                                font.bold: true
                                font.pixelSize: fontBase
                                color: textColor
                            }
                            TextField {
                                id: proveedorField
                                Layout.fillWidth: true
                                placeholderText: "Nombre del proveedor o empresa"
                                font.pixelSize: fontBase
                                background: Rectangle {
                                    color: whiteColor
                                    border.color: lightGrayColor
                                    border.width: 1
                                    radius: baseUnit * 0.15
                                }
                            }
                        }
                    }
                }
                
                Item { Layout.fillHeight: true }
                
                // Botones
                RowLayout {
                    Layout.fillWidth: true
                    Item { Layout.fillWidth: true }
                    
                    Button {
                        text: "Cancelar"
                        Layout.preferredHeight: Math.max(36, screenHeight * 0.045)
                        font.pixelSize: fontBase
                        background: Rectangle {
                            color: lightGrayColor
                            radius: baseUnit * 0.2
                        }
                        contentItem: Label {
                            text: parent.text
                            font.pixelSize: fontBase
                            color: textColor
                            horizontalAlignment: Text.AlignHCenter
                        }
                        onClicked: {
                            // Limpiar y cerrar
                            showNewGastoDialog = false
                            selectedRowIndex = -1
                            isEditMode = false
                            editingIndex = -1
                        }
                    }
                    
                    Button {
                        text: isEditMode ? "Actualizar" : "Guardar"
                        Layout.preferredHeight: Math.max(36, screenHeight * 0.045)
                        font.pixelSize: fontBase
                        enabled: gastoForm.selectedTipoGastoIndex >= 0 && 
                                descripcionField.text.length > 0 &&
                                montoField.text.length > 0 &&
                                proveedorField.text.length > 0
                        background: Rectangle {
                            color: parent.enabled ? primaryColor : "#bdc3c7"
                            radius: baseUnit * 0.2
                        }
                        contentItem: Label {
                            text: parent.text
                            color: whiteColor
                            font.bold: true
                            font.pixelSize: fontBase
                            horizontalAlignment: Text.AlignHCenter
                        }
                        onClicked: {
                            // Validaciones adicionales
                            if (gastoForm.selectedTipoGastoIndex < 0) {
                                showErrorMessage("Error de validación", "Selecciona un tipo de gasto")
                                return
                            }
                            
                            if (parseFloat(montoField.text) <= 0) {
                                showErrorMessage("Error de validación", "El monto debe ser mayor a 0")
                                return
                            }
                            
                            var gastoData = {
                                descripcion: descripcionField.text.trim(),
                                monto: parseFloat(montoField.text).toFixed(2),
                                fechaGasto: fechaGastoField.text,
                                proveedorEmpresa: proveedorField.text.trim()
                            }
                            
                            var success = false
                            
                            if (isEditMode && editingIndex >= 0) {
                                var gastoExistente = gastosListModel.get(editingIndex)
                                success = updateGastoWithModel(gastoExistente.gastoId, gastoData)
                            } else {
                                success = createGastoWithModel(gastoData)
                            }
                            
                            if (!success) {
                                showErrorMessage("Error", "No se pudo guardar el gasto. Revisa los datos.")
                            }
                        }
                    }
                }
            }
        }
    }
    // ✅ DIÁLOGO DE CONFIRMACIÓN DE ELIMINACIÓN
    Dialog {
        id: confirmDeleteDialog
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.8, 400)
        height: Math.min(parent.height * 0.4, 200)
        modal: true
        title: "Confirmar Eliminación"
        
        property string gastoIdToDelete: ""
        
        background: Rectangle {
            color: whiteColor
            radius: baseUnit * 0.5
            border.color: warningColor
            border.width: 2
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: marginLarge
            spacing: marginLarge
            
            Label {
                text: "⚠️ ¿Estás seguro de eliminar este gasto?"
                font.pixelSize: fontMedium
                font.bold: true
                color: textColor
                Layout.alignment: Qt.AlignHCenter
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
            
            Label {
                text: "Esta acción no se puede deshacer."
                font.pixelSize: fontBase
                color: "#7f8c8d"
                Layout.alignment: Qt.AlignHCenter
            }
            
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: marginMedium
                
                Button {
                    text: "Cancelar"
                    Layout.preferredWidth: 100
                    
                    background: Rectangle {
                        color: lightGrayColor
                        radius: baseUnit * 0.3
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        color: textColor
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                    
                    onClicked: confirmDeleteDialog.close()
                }
                
                Button {
                    text: "Eliminar"
                    Layout.preferredWidth: 100
                    
                    background: Rectangle {
                        color: dangerColor
                        radius: baseUnit * 0.3
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        color: whiteColor
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                    
                    onClicked: {
                        console.log("🗑️ Confirmando eliminación...")
                        
                        var success = deleteGastoWithModel(confirmDeleteDialog.gastoIdToDelete)
                        
                        if (!success) {
                            showErrorMessage("Error", "No se pudo eliminar el gasto.")
                        }
                        
                        selectedRowIndex = -1
                        confirmDeleteDialog.close()
                    }
                }
            }
        }
    }
    
    // ✅ COMPONENTE DE LOADING
    Rectangle {
        id: loadingIndicator
        anchors.fill: parent
        color: "#80000000"
        visible: false
        z: 1000
        
        ColumnLayout {
            anchors.centerIn: parent
            spacing: marginMedium
            
            BusyIndicator {
                Layout.alignment: Qt.AlignHCenter
                running: parent.parent.visible
            }
            
            Label {
                text: "Cargando..."
                color: whiteColor
                font.pixelSize: fontLarge
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }
    
    // ✅ TOAST DE ÉXITO
    Rectangle {
        id: successToast
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: marginLarge
        width: 300
        height: 40
        color: successColor
        radius: baseUnit * 0.5
        visible: false
        z: 1000
        
        property alias text: successLabel.text
        property alias hideTimer: hideTimer
        
        Label {
            id: successLabel
            anchors.centerIn: parent
            color: whiteColor
            font.bold: true
            font.pixelSize: fontBase
        }
        
        Timer {
            id: hideTimer
            interval: 3000
            onTriggered: successToast.visible = false
        }
        
        Behavior on opacity {
            NumberAnimation { duration: 300 }
        }
    }
    
    // ✅ DIÁLOGO DE ERROR
    Dialog {
        id: errorDialog
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.8, 400)
        height: Math.min(parent.height * 0.6, 300)
        modal: true
        
        property alias text: errorText.text
        
        background: Rectangle {
            color: whiteColor
            radius: baseUnit * 0.5
            border.color: dangerColor
            border.width: 2
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: marginLarge
            spacing: marginLarge
            
            Label {
                text: "❌ " + errorDialog.title
                font.pixelSize: fontLarge
                font.bold: true
                color: dangerColor
                Layout.alignment: Qt.AlignHCenter
            }
            
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                
                Label {
                    id: errorText
                    width: parent.width
                    wrapMode: Text.WordWrap
                    font.pixelSize: fontBase
                    color: textColor
                }
            }
            
            Button {
                text: "Cerrar"
                Layout.alignment: Qt.AlignHCenter
                onClicked: errorDialog.close()
                
                background: Rectangle {
                    color: dangerColor
                    radius: baseUnit * 0.3
                }
                
                contentItem: Label {
                    text: parent.text
                    color: whiteColor
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
    // ✅ CORREGIR FUNCIÓN limpiarFiltros
    function limpiarFiltros() {
        console.log("🧹 Limpiando filtros...")
        
        // Limpiar controles de filtros
        filtroTipoGasto.currentIndex = 0
        filtroFecha.currentIndex = 0
        campoBusqueda.text = ""
        
        // Restaurar todos los datos originales
        gastosListModel.clear()
        for (var i = 0; i < gastosOriginales.length; i++) {
            gastosListModel.append(gastosOriginales[i])
        }
        
        // Resetear paginación
        currentPageServicios = 0
        updatePaginatedModel()
        
        console.log("🧹 Filtros limpiados - Mostrando:", gastosListModel.count, "gastos")
    }
    
    // ✅ CORREGIR LA INICIALIZACIÓN DEL COMPONENTE
    Component.onCompleted: {
        console.log("💰 Módulo Servicios Básicos iniciado")
        
        // ✅ NO LLAMAR FUNCIONES QUE PUEDAN CAUSAR LOOPS AL INICIO
        // Solo inicializar paginación con datos vacíos
        updatePaginatedModel()
        
        console.log("⏳ Esperando conexión con AppController...")
    }
    
    // ✅ AGREGAR ESTA FUNCIÓN PARA DEBUGGING
    function debugEstado() {
        console.log("🔍 DEBUG Estado actual:")
        console.log("   - gastoModelInstance:", gastoModelInstance ? "disponible" : "null")
        console.log("   - gastosOriginales.length:", gastosOriginales.length)
        console.log("   - gastosListModel.count:", gastosListModel.count)
        console.log("   - gastosPaginadosModel.count:", gastosPaginadosModel.count)
        console.log("   - tiposGastosModel.count:", tiposGastosModel.count)
    } 
    // ✅ INICIALIZACIÓN MEJORADA CON APPCONTROLLER
}