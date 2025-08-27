import QtQuick 2.15
import QtQuick.Controls.Universal 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

Item {
    id: serviciosBasicosRoot
    objectName: "serviciosBasicosRoot"
    
    // SISTEMA DE ESTILOS ADAPTABLES INTEGRADO
    readonly property real screenWidth: width
    readonly property real screenHeight: height
    readonly property real baseUnit: Math.min(screenWidth, screenHeight) / 40
    readonly property real fontScale: screenHeight / 800
    
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
    
    // NUEVA SEÑAL PARA NAVEGACIÓN A CONFIGURACIÓN
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
    
    // PROPIEDADES DE PAGINACIÓN CORREGIDAS
    property int itemsPerPageServicios: 10
    property int currentPageServicios: 0
    property int totalPagesServicios: 0

    property var editingGastoData: null
    property var gastoModelInstance: null
    
    // FUNCIÓN HELPER MOVIDA AL NIVEL PRINCIPAL
    function obtenerAñosDisponibles() {
        var años = []
        var añoActual = new Date().getFullYear()
        
        // Siempre incluir año actual
        años.push(añoActual.toString())
        
        // Añadir algunos años anteriores para tener opciones
        for (var i = 1; i <= 5; i++) {
            años.push((añoActual - i).toString())
        }
        
        // Ordenar años de mayor a menor
        años.sort(function(a, b) { return parseInt(b) - parseInt(a) })
        
        console.log("📅 Años disponibles:", años)
        return años
    }

    // FUNCIÓN DE DEBUG CORREGIDA
    function debugEstado() {
        console.log("🔍 DEBUG Estado actual:")
        console.log("   - gastoModelInstance:", gastoModelInstance ? "disponible" : "null")
        console.log("   - gastosListModel.count:", gastosListModel.count)
        console.log("   - gastosPaginadosModel.count:", gastosPaginadosModel.count)
        console.log("   - tiposGastosModel.count:", tiposGastosModel.count)
        console.log("   - currentPageServicios:", currentPageServicios)
        console.log("   - totalPagesServicios:", totalPagesServicios)
    }
    
    // CONEXIONES CON EL GASTOMODEL VIA APPCONTROLLER
    Connections {
        target: gastoModelInstance
        enabled: gastoModelInstance !== null
        
        function onGastosChanged() {
            if (gastoModelInstance) {
                console.log("🔄 Gastos actualizados desde AppController:", gastoModelInstance.gastos.length)
                loadGastosTimer.restart()
            }
        }
        
        function onTiposGastosChanged() {
            if (gastoModelInstance) {
                console.log("🏷️ Tipos de gastos actualizados desde AppController:", gastoModelInstance.tiposGastos.length)
                loadTiposTimer.restart()
            }
        }
        
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
    
    // TIMERS PARA EVITAR LLAMADAS INMEDIATAS
    Timer {
        id: loadGastosTimer
        interval: 100
        repeat: false
        onTriggered: {
            if (gastoModelInstance) {
                loadGastosFromModel()
            }
        }
    }

    Timer {
        id: loadTiposTimer
        interval: 100
        repeat: false
        onTriggered: {
            if (gastoModelInstance) {
                loadTiposGastosFromModel()
            }
        }
    }

    // CONEXIONES CON APPCONTROLLER PARA NOTIFICACIONES
    Connections {
        target: appController
        
        function onModelsReady() {
            console.log("🚀 Models listos desde AppController")
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
    
    // TIMER PARA INICIALIZACIÓN RETRASADA
    Timer {
        id: delayedInitTimer
        interval: 500
        repeat: false
        onTriggered: {
            if (appController && appController.gasto_model_instance) {
                gastoModelInstance = appController.gasto_model_instance
                console.log("🔄 Inicialización retrasada exitosa")
                loadGastosFromModel()
                loadTiposGastosFromModel()
            } else {
                console.log("❌ GastoModel aún no disponible")
                if (interval < 2000) {
                    interval = interval * 2
                    start()
                }
            }
        }
    }
    
    // FUNCIÓN PARA CARGAR GASTOS DESDE EL MODELO VIA APPCONTROLLER
    function loadGastosFromModel() {
        if (!gastoModelInstance) {
            console.log("⚠️ GastoModel no disponible para cargar gastos")
            return
        }
        console.log("📊 Recargando página actual desde modelo...")
        cargarPaginaDesdeBD()
    }
    
    // FUNCIÓN PARA CARGAR TIPOS DE GASTOS DESDE EL MODELO VIA APPCONTROLLER
    function loadTiposGastosFromModel() {
        if (!gastoModelInstance) {
            console.log("⚠️ GastoModel no disponible para cargar tipos")
            return
        }
        
        console.log("🏷️ Cargando tipos desde modelo...")
        
        // LIMPIAR COMPLETAMENTE EL MODELO ANTES DE AGREGAR NUEVOS DATOS
        tiposGastosModel.clear()
        
        var tipos = gastoModelInstance.tiposGastos
        for (var i = 0; i < tipos.length; i++) {
            var tipo = tipos[i]
            
            // CREAR OBJETO CON TIPOS CONSISTENTES
            var tipoFormatted = {
                id: parseInt(tipo.id || 0),
                nombre: String(tipo.Nombre || "Sin nombre"),
                descripcion: String(tipo.descripcion || "Tipo de gasto"),
                ejemplos: [],
                color: String(getColorForTipo(tipo.Nombre || ""))
            }
            
            tiposGastosModel.append(tipoFormatted)
        }
        
        console.log("🏷️ Tipos de gastos cargados:", tiposGastosModel.count)
        
        // Actualizar ComboBox
        filtroTipoServicio.model = getTiposGastosNombres()
    }
    
    // FUNCIÓN OVERRIDE PARA CREAR GASTO CON MODELO REAL VIA APPCONTROLLER
    function createGastoWithModel(gastoData) {
        if (!gastoModelInstance) {
            console.log("❌ GastoModel no disponible para crear gasto")
            showErrorMessage("Error", "Sistema no disponible")
            return false
        }
        
        console.log("💰 Creando gasto con modelo real via AppController...")
        console.log("📊 Datos recibidos:", JSON.stringify(gastoData))
        
        // Obtener ID del tipo de gasto seleccionado
        var tipoGastoId = 0
        if (gastoForm.selectedTipoGastoIndex >= 0) {
            var tipoSeleccionado = tiposGastosModel.get(gastoForm.selectedTipoGastoIndex)
            tipoGastoId = tipoSeleccionado.id
            console.log("🏷️ Tipo de gasto seleccionado:", tipoSeleccionado.nombre, "ID:", tipoGastoId)
        }
        
        // CORRECCIÓN: Usar el campo correcto del objeto gastoData
        var proveedorFinal = gastoData.proveedor || gastoData.proveedorEmpresa || ""
        console.log("🏢 Proveedor a guardar:", proveedorFinal)
        
        // Llamar al modelo real via AppController
        var success = gastoModelInstance.crearGasto(
            tipoGastoId,
            parseFloat(gastoData.monto),
            10,
            gastoData.descripcion,
            gastoData.fechaGasto,
            proveedorFinal
        )
        
        console.log("📝 Resultado creación:", success)
        return success
    }

    function updateGastoWithModel(gastoId, gastoData) {
        if (!gastoModelInstance) {
            console.log("❌ GastoModel no disponible para actualizar gasto")
            showErrorMessage("Error", "Sistema no disponible")
            return false
        }
        
        console.log("✏️ Actualizando gasto con modelo real via AppController...")
        console.log("📊 Datos recibidos:", JSON.stringify(gastoData))
        
        // Obtener ID del tipo de gasto seleccionado
        var tipoGastoId = 0
        if (gastoForm.selectedTipoGastoIndex >= 0) {
            var tipoSeleccionado = tiposGastosModel.get(gastoForm.selectedTipoGastoIndex)
            tipoGastoId = tipoSeleccionado.id
            console.log("🏷️ Tipo de gasto seleccionado:", tipoSeleccionado.nombre, "ID:", tipoGastoId)
        }
        
        // CORRECCIÓN: Usar el campo correcto del objeto gastoData
        var proveedorFinal = gastoData.proveedor || gastoData.proveedorEmpresa || ""
        console.log("🏢 Proveedor a actualizar:", proveedorFinal)
        
        // Llamar al modelo real via AppController
        var success = gastoModelInstance.actualizarGasto(
            parseInt(gastoId),
            parseFloat(gastoData.monto),
            tipoGastoId,
            gastoData.descripcion,
            proveedorFinal
        )
        
        console.log("✏️ Resultado actualización:", success)
        return success
    }
    
    // FUNCIÓN OVERRIDE PARA ELIMINAR GASTO CON MODELO REAL VIA APPCONTROLLER
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
    
    // FUNCIONES HELPER
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
    
    // PROPIEDAD PARA EXPONER EL MODELO DE DATOS
    property alias tiposGastosModel: tiposGastosModel
    
    // MODELO DE TIPOS DE GASTOS LOCAL (FALLBACK)
    ListModel {
        id: tiposGastosModel
    }

    // MODELOS SEPARADOS PARA PAGINACIÓN
    ListModel {
        id: gastosListModel
    }
    
    ListModel {
        id: gastosPaginadosModel
    }

    // Función helper para obtener nombres de tipos de gastos
    function getTiposGastosNombres() {
        var nombres = ["Todos los Servicios"]
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
  
    // FUNCIÓN PARA ACTUALIZAR PAGINACIÓN
    function cargarPaginaDesdeBD() {
        if (!gastoModelInstance) {
            console.log("⚠️ GastoModel no disponible aún")
            return
        }
        
        loadingIndicator.visible = true;
        
        // Validar y obtener el año correctamente
        var añoValor = 0;
        if (filtroAño.currentText && !isNaN(parseInt(filtroAño.currentText))) {
            añoValor = parseInt(filtroAño.currentText);
        } else {
            añoValor = new Date().getFullYear();
        }
        
        var filtrosActuales = {
            tipo_id: filtroTipoServicio.currentIndex > 0 ? tiposGastosModel.get(filtroTipoServicio.currentIndex - 1).id : 0,
            mes: filtroMes.currentIndex + 1,
            año: añoValor
        };
        
        console.log("🔍 Aplicando filtros:", JSON.stringify(filtrosActuales));
        
        var offset = currentPageServicios * itemsPerPageServicios;
        
        // Cargar datos paginados desde BD
        var gastosPagina = gastoModelInstance.obtenerGastosPaginados(offset, itemsPerPageServicios, filtrosActuales);
        var totalGastos = gastoModelInstance.obtenerTotalGastos(filtrosActuales);
        
        gastosPaginadosModel.clear();
        
        for (var i = 0; i < gastosPagina.length; i++) {
            var gasto = gastosPagina[i];
            gastosPaginadosModel.append({
                gastoId: gasto.id,
                tipoGasto: gasto.tipo_nombre,
                descripcion: gasto.Descripcion,
                monto: gasto.Monto.toFixed(2),
                fechaGasto: Qt.formatDate(gasto.Fecha, "yyyy-MM-dd"),
                proveedor: gasto.Proveedor,
                registradoPor: gasto.usuario_nombre
            });
        }
        
        totalPagesServicios = Math.ceil(totalGastos / itemsPerPageServicios);
        loadingIndicator.visible = false;
    }

    // FUNCIÓN PARA LIMPIAR FILTROS
    function limpiarFiltros() {
        console.log("🧹 Limpiando filtros...")
        
        filtroTipoServicio.currentIndex = 0
        filtroMes.currentIndex = new Date().getMonth()
        
        // Restablecer el año al año actual
        var añoActual = new Date().getFullYear().toString();
        var index = filtroAño.find(añoActual);
        if (index >= 0) {
            filtroAño.currentIndex = index;
        } else if (filtroAño.model.length > 0) {
            filtroAño.currentIndex = 0;
        }
        
        currentPageServicios = 0
        cargarPaginaDesdeBD()
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
                
                // HEADER RESPONSIVO ACTUALIZADO
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: baseUnit * 5  // Reducido aún más
                    color: lightGrayColor
                    border.color: "#e0e0e0"
                    border.width: 1
                    radius: baseUnit * 0.8  // Radio más pequeño
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: baseUnit * 0.8  // Margen más pequeño
                        spacing: baseUnit * 0.8
                        
                        // SECCIÓN DEL LOGO Y TÍTULO - TAMAÑO REDUCIDO
                        RowLayout {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: baseUnit * 1
                            
                            // Contenedor del icono con tamaño reducido (igual que consultas)
                            Rectangle {
                                Layout.preferredWidth: baseUnit * 4  // Reducido más
                                Layout.preferredHeight: baseUnit * 4  // Reducido más
                                color: "transparent"
                                
                                Image {
                                    id: serviciosIcon
                                    anchors.centerIn: parent
                                    width: Math.min(baseUnit * 3.2, parent.width * 0.9)  // Reducido más
                                    height: Math.min(baseUnit * 3.2, parent.height * 0.9)  // Reducido más
                                    source: "Resources/iconos/ServiciosBasicos.png"
                                    fillMode: Image.PreserveAspectFit
                                    antialiasing: true
                                    
                                    onStatusChanged: {
                                        if (status === Image.Error) {
                                            console.log("Error cargando PNG de Servicios Básicos:", source)
                                            // Fallback al emoji original
                                            visible = false
                                            fallbackLabel.visible = true
                                        } else if (status === Image.Ready) {
                                            console.log("PNG de Servicios Básicos cargado correctamente:", source)
                                        }
                                    }
                                }
                                
                                // Fallback al emoji si no carga la imagen
                                Label {
                                    id: fallbackLabel
                                    anchors.centerIn: parent
                                    text: "💰"
                                    font.pixelSize: baseUnit * 2.5  // Reducido más
                                    color: primaryColor
                                    visible: false
                                }
                            }
                            
                            // Título - Tamaño reducido para igualar consultas
                            ColumnLayout {
                                Layout.alignment: Qt.AlignVCenter
                                spacing: baseUnit * 0.05  // Espaciado mínimo
                                
                                Label {
                                    text: "Gestión de Servicios Básicos"
                                    font.pixelSize: fontBaseSize * 0.85  // Reducido más
                                    font.bold: true
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    color: textColor
                                }
                                
                                Label {
                                    text: "y Gastos Operativos"
                                    font.pixelSize: fontBaseSize * 0.7  // Reducido más
                                    font.bold: false
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    color: textColorLight
                                }
                            }
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        // BOTÓN NUEVO GASTO - MUCHO MÁS COMPACTO
                        Button {
                            objectName: "newGastoButton"
                            Layout.preferredHeight: baseUnit * 2.8  // Reducido drásticamente
                            Layout.preferredWidth: Math.max(baseUnit * 10, implicitWidth + baseUnit * 0.8)  // Mucho más pequeño
                            Layout.alignment: Qt.AlignVCenter
                            
                            background: Rectangle {
                                color: parent.pressed ? Qt.darker(primaryColor, 1.1) : 
                                    (parent.hovered ? Qt.lighter(primaryColor, 1.1) : primaryColor)
                                radius: baseUnit * 0.6
                                border.width: 0
                                
                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                            
                            contentItem: RowLayout {
                                spacing: baseUnit * 0.4
                                
                                // Contenedor del icono del botón - mucho más pequeño
                                Rectangle {
                                    Layout.preferredWidth: baseUnit * 1.6  // Muy reducido
                                    Layout.preferredHeight: baseUnit * 1.6  // Muy reducido
                                    color: "transparent"
                                    
                                    Image {
                                        id: addGastoIcon
                                        anchors.centerIn: parent
                                        width: baseUnit * 1.2  // Muy pequeño
                                        height: baseUnit * 1.2  // Muy pequeño
                                        source: "Resources/iconos/Nueva_Consulta.png"
                                        fillMode: Image.PreserveAspectFit
                                        antialiasing: true
                                        
                                        onStatusChanged: {
                                            if (status === Image.Error) {
                                                console.log("Error cargando PNG del botón Nuevo Gasto:", source)
                                                visible = false
                                                fallbackPlusText.visible = true
                                            } else if (status === Image.Ready) {
                                                console.log("PNG del botón Nuevo Gasto cargado correctamente:", source)
                                            }
                                        }
                                    }
                                    
                                    // Texto fallback si no hay icono
                                    Label {
                                        id: fallbackPlusText
                                        anchors.centerIn: parent
                                        text: "+"
                                        color: whiteColor
                                        font.pixelSize: fontBase * 0.8  // Muy reducido
                                        font.bold: true
                                        visible: false
                                    }
                                }
                                
                                // Texto del botón - letra más grande como en consultas
                                Label {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: "Nuevo Gasto"
                                    color: whiteColor
                                    font.bold: true
                                    font.pixelSize: fontBase * 1.1  // Aumentado para que sea más visible
                                    font.family: "Segoe UI, Arial, sans-serif"
                                }
                            }
                            
                            onClicked: {
                                isEditMode = false
                                editingIndex = -1
                                showNewGastoDialog = true
                            }
                            
                            // Efecto hover mejorado
                            HoverHandler {
                                id: buttonHover
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }
                }
                
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(80, screenHeight * 0.10)
                    color: "transparent"
                    z: 10
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: marginMedium
                        spacing: marginMedium
                        
                        // FILTRO TIPO SERVICIO
                        Row {
                            spacing: marginSmall
                            Layout.alignment: Qt.AlignVCenter
                            
                            Label {
                                text: "Tipo Servicio:"
                                font.bold: true
                                font.pixelSize: fontBase
                                color: textColor
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            
                            ComboBox {
                                id: filtroTipoServicio
                                width: Math.max(160, screenWidth * 0.15)
                                
                                model: {
                                    var tipos = ["Todos los servicios"]
                                    if (tiposGastosModel.count > 0) {
                                        for (var i = 0; i < tiposGastosModel.count; i++) {
                                            var item = tiposGastosModel.get(i)
                                            tipos.push(item.nombre)
                                        }
                                    }
                                    return tipos
                                }
                                
                                currentIndex: 0
                                onCurrentIndexChanged: {
                                    console.log("🔍 Filtro tipo servicio cambiado:", currentIndex)
                                    currentPageServicios = 0
                                    Qt.callLater(cargarPaginaDesdeBD)
                                }
                            }
                        }

                        // FILTRO MES
                        Row {
                            spacing: marginSmall
                            Layout.alignment: Qt.AlignVCenter
                            
                            Label {
                                text: "Mes:"
                                font.bold: true
                                font.pixelSize: fontBase
                                color: textColor
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            
                            ComboBox {
                                id: filtroMes
                                width: Math.max(120, screenWidth * 0.12)
                                model: ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
                                        "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"]
                                currentIndex: new Date().getMonth()
                                onCurrentIndexChanged: {
                                    console.log("📅 Filtro mes cambiado:", currentIndex)
                                    currentPageServicios = 0
                                    Qt.callLater(cargarPaginaDesdeBD)
                                }
                            }
                        }

                        // FILTRO AÑO - CORREGIDO
                        Row {
                            spacing: marginSmall
                            Layout.alignment: Qt.AlignVCenter
                            visible: filtroAño.model.length > 1
                            
                            Label {
                                text: "Año:"
                                font.bold: true
                                font.pixelSize: fontBase
                                color: textColor
                                anchors.verticalCenter: parent.verticalCenter
                                visible: filtroAño.visible
                            }
                            
                            ComboBox {
                                id: filtroAño
                                width: Math.max(80, screenWidth * 0.08)
                                
                                // MODELO INLINE CORREGIDO
                                model: {
                                    var años = []
                                    var añoActual = new Date().getFullYear()
                                    años.push(añoActual.toString())
                                    for (var i = 1; i <= 5; i++) {
                                        años.push((añoActual - i).toString())
                                    }
                                    return años.sort(function(a, b) { return parseInt(b) - parseInt(a) })
                                }
                                
                                // ESTABLECER VALOR POR DEFECTO AL INICIALIZAR
                                Component.onCompleted: {
                                    var añoActual = new Date().getFullYear().toString();
                                    var index = find(añoActual);
                                    if (index >= 0) {
                                        currentIndex = index;
                                    } else if (model.length > 0) {
                                        currentIndex = 0;
                                    }
                                }
                                
                                onCurrentIndexChanged: {
                                    if (visible) {
                                        console.log("📅 Filtro año cambiado:", currentText)
                                        currentPageServicios = 0
                                        Qt.callLater(cargarPaginaDesdeBD)
                                    }
                                }
                            }
                        }
                    }
                }

                // CONTENEDOR DE TABLA COMPLETAMENTE RESPONSIVO
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
                        
                        // HEADER DE TABLA CON ANCHOS PROPORCIONALES
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
                                    Layout.preferredWidth: parent.width * 0.16
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
                                    Layout.preferredWidth: parent.width * 0.22
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
                                    Layout.preferredWidth: parent.width * 0.12
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.color: "#d0d0d0"
                                    border.width: 1
                                    
                                    Label { 
                                        anchors.centerIn: parent
                                        text: "FECHA"
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
                        
                        // CONTENIDO DE TABLA CON ALTURA ADAPTABLE
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            
                            ListView {
                                id: gastosListView
                                model: gastosPaginadosModel
                                
                                delegate: Rectangle {
                                    width: ListView.view.width
                                    height: Math.max(45, screenHeight * 0.06)
                                    color: {
                                        if (selectedRowIndex === index) return "#e3f2fd"
                                        return index % 2 === 0 ? "transparent" : "#fafafa"
                                    }
                                    border.color: selectedRowIndex === index ? primaryColor : "#e8e8e8"
                                    border.width: selectedRowIndex === index ? 2 : 1
                                
                                    RowLayout {
                                        anchors.fill: parent
                                        spacing: 0
                                        
                                        // COLUMNA ID
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
                                        
                                        // COLUMNA TIPO
                                        Rectangle {
                                            Layout.preferredWidth: parent.width * 0.16
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
                                        
                                        // COLUMNA DESCRIPCIÓN
                                        Rectangle {
                                            Layout.preferredWidth: parent.width * 0.22
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Label { 
                                                anchors.fill: parent
                                                anchors.margins: marginSmall * 0.5
                                                text: model.descripcion || "Sin descripción"
                                                color: textColor
                                                font.pixelSize: fontTiny
                                                elide: Text.ElideRight
                                                wrapMode: Text.WordWrap
                                                maximumLineCount: 2
                                                verticalAlignment: Text.AlignVCenter
                                                horizontalAlignment: Text.AlignLeft
                                            }
                                        }
                                        
                                        // COLUMNA MONTO
                                        Rectangle {
                                            Layout.preferredWidth: parent.width * 0.12
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Label { 
                                                anchors.centerIn: parent
                                                text: "Bs " + model.monto
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
                                        
                                        // COLUMNA FECHA
                                        Rectangle {
                                            Layout.preferredWidth: parent.width * 0.12
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
                                        
                                        // COLUMNA PROVEEDOR
                                        Rectangle {
                                            Layout.preferredWidth: parent.width * 0.18
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Label { 
                                                anchors.fill: parent
                                                anchors.margins: marginSmall * 0.25
                                                text: model.proveedor || "Sin proveedor"
                                                color: "#7f8c8d"
                                                font.pixelSize: fontTiny
                                                elide: Text.ElideRight
                                                wrapMode: Text.WordWrap
                                                maximumLineCount: 2
                                                verticalAlignment: Text.AlignVCenter
                                                horizontalAlignment: Text.AlignLeft
                                            }
                                        }
                                        
                                        // COLUMNA REGISTRADO POR
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            color: "transparent"
                                            border.color: "#d0d0d0"
                                            border.width: 1
                                            
                                            Label { 
                                                anchors.fill: parent
                                                anchors.margins: marginSmall * 0.25
                                                text: model.registradoPor || "Usuario desconocido"
                                                color: "#7f8c8d"
                                                font.pixelSize: fontTiny
                                                elide: Text.ElideRight
                                                wrapMode: Text.WordWrap
                                                maximumLineCount: 2
                                                verticalAlignment: Text.AlignVCenter
                                                horizontalAlignment: Text.AlignLeft
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
                                    
                                    // BOTONES DE ACCIÓN
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
                                                isEditMode = true
                                                editingGastoData = {
                                                    gastoId: model.gastoId,
                                                    tipoGasto: model.tipoGasto,
                                                    descripcion: model.descripcion,
                                                    monto: model.monto,
                                                    fechaGasto: model.fechaGasto,
                                                    proveedor: model.proveedor
                                                }
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
                            
                            // ESTADO VACÍO PARA TABLA SIN DATOS
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
                
                // CONTROL DE PAGINACIÓN RESPONSIVO
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
                                    cargarPaginaDesdeBD()
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
                                    cargarPaginaDesdeBD()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Diálogo de nuevo gasto rediseñado - Versión mejorada
    Rectangle {
        id: gastoForm
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.7, 500)
        height: Math.min(parent.height * 0.75, 550)
        color: whiteColor
        radius: 8
        border.color: "#DDD"
        border.width: 1
        visible: showNewGastoDialog

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
        
        property int selectedTipoGastoIndex: -1
        
        // HEADER MEJORADO
        Rectangle {
            id: dialogHeader
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 50
            color: primaryColor
            
            Label {
                anchors.centerIn: parent
                text: isEditMode ? "EDITAR GASTO" : "NUEVO GASTO"
                font.pixelSize: 16
                font.bold: true
                color: whiteColor
            }
            
            // Botón de cerrar (más pequeño y mejor posicionado)
            Button {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 30
                height: 30
                background: Rectangle {
                    color: "transparent"
                    radius: width / 2
                }
                
                contentItem: Text {
                    text: "×"
                    color: whiteColor
                    font.pixelSize: 20
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: {
                    showNewGastoDialog = false
                    selectedRowIndex = -1
                    isEditMode = false
                    editingGastoData = null
                }
            }
        }
        
        // CONTENIDO PRINCIPAL
        ScrollView {
            id: scrollView
            anchors.top: dialogHeader.bottom
            anchors.topMargin: 15
            anchors.bottom: buttonRow.top
            anchors.bottomMargin: 15
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.right: parent.right
            anchors.rightMargin: 20
            clip: true
            
            Column {
                width: scrollView.width - 5
                spacing: 15
                
                // CAMPO TIPO DE GASTO
                Column {
                    width: parent.width
                    spacing: 5
                    
                    Label {
                        text: "Tipo de Gasto:"
                        font.bold: true
                        color: textColor
                        font.pixelSize: 14
                    }
                    
                    ComboBox {
                        id: tipoGastoCombo
                        width: parent.width
                        height: 40
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
                
                // CAMPO MONTO
                Column {
                    width: parent.width
                    spacing: 5
                    
                    Label {
                        text: "Monto (Bs):"
                        font.bold: true
                        color: textColor
                        font.pixelSize: 14
                    }
                    
                    TextField {
                        id: montoField
                        width: parent.width
                        height: 40
                        placeholderText: "0.00"
                        validator: DoubleValidator { bottom: 0.0; decimals: 2 }
                    }
                }
                
                // CAMPO FECHA
                Column {
                    width: parent.width
                    spacing: 5
                    
                    Label {
                        text: "Fecha del Gasto:"
                        font.bold: true
                        color: textColor
                        font.pixelSize: 14
                    }
                    
                    TextField {
                        id: fechaGastoField
                        width: parent.width
                        height: 40
                        placeholderText: "YYYY-MM-DD"
                        text: Qt.formatDate(new Date(), "yyyy-MM-dd")
                    }
                }
                
                // CAMPO PROVEEDOR
                Column {
                    width: parent.width
                    spacing: 5
                    
                    Label {
                        text: "Proveedor/Empresa:"
                        font.bold: true
                        color: textColor
                        font.pixelSize: 14
                    }
                    
                    TextField {
                        id: proveedorField
                        width: parent.width
                        height: 40
                        placeholderText: "Nombre del proveedor o empresa"
                    }
                }
                
                // CAMPO DESCRIPCIÓN
                Column {
                    width: parent.width
                    spacing: 5
                    
                    Label {
                        text: "Descripción:"
                        font.bold: true
                        color: textColor
                        font.pixelSize: 14
                    }
                    
                    TextArea {
                        id: descripcionField
                        width: parent.width
                        height: 100
                        placeholderText: "Descripción detallada del gasto..."
                        wrapMode: TextArea.Wrap
                    }
                }
            }
        }
        
        // BOTONES (más pequeños y mejor organizados)
        Row {
            id: buttonRow
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 15
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 15
            height: 40
            
            Button {
                id: cancelButton
                width: 120
                height: 40
                text: "Cancelar"
                
                background: Rectangle {
                    color: cancelButton.pressed ? "#e0e0e0" : "#f8f9fa"
                    border.color: "#ddd"
                    border.width: 1
                    radius: 5
                }
                
                contentItem: Label {
                    text: parent.text
                    font.pixelSize: 14
                    color: textColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: {
                    showNewGastoDialog = false
                    selectedRowIndex = -1
                    isEditMode = false
                    editingGastoData = null
                }
            }
            
            Button {
                id: saveButton
                width: 120
                height: 40
                text: isEditMode ? "Actualizar" : "Guardar"
                enabled: gastoForm.selectedTipoGastoIndex >= 0 && 
                        descripcionField.text.length > 0 &&
                        montoField.text.length > 0 &&
                        proveedorField.text.length > 0
                
                background: Rectangle {
                    color: !saveButton.enabled ? "#bdc3c7" : 
                        (saveButton.pressed ? Qt.darker(primaryColor, 1.1) : primaryColor)
                    radius: 5
                }
                
                contentItem: Label {
                    text: parent.text
                    font.pixelSize: 14
                    font.bold: true
                    color: whiteColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
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
                        proveedor: proveedorField.text.trim()
                    }
                    
                    console.log("Enviando datos del formulario:", JSON.stringify(gastoData))
                    
                    var success = false
                    
                    if (isEditMode && editingGastoData) {
                        success = updateGastoWithModel(editingGastoData.gastoId, gastoData)
                    } else {
                        success = createGastoWithModel(gastoData)
                    }
                    
                    if (!success) {
                        showErrorMessage("Error", "No se pudo guardar el gasto. Revisa los datos.")
                    }
                }
            }
        }
        
        // Cargar datos en modo edición
        onVisibleChanged: {
            if (visible && isEditMode) {
                // Buscar el tipo de gasto correspondiente
                var tipoGastoNombre = editingGastoData.tipoGasto
                for (var i = 0; i < tiposGastosModel.count; i++) {
                    if (tiposGastosModel.get(i).nombre === tipoGastoNombre) {
                        tipoGastoCombo.currentIndex = i + 1
                        gastoForm.selectedTipoGastoIndex = i
                        break
                    }
                }
                // Cargar el resto de campos
                descripcionField.text = editingGastoData.descripcion
                montoField.text = editingGastoData.monto
                fechaGastoField.text = editingGastoData.fechaGasto
                proveedorField.text = editingGastoData.proveedor
            } else if (visible && !isEditMode) {
                // Limpiar formulario para nuevo gasto
                tipoGastoCombo.currentIndex = 0
                descripcionField.text = ""
                montoField.text = ""
                fechaGastoField.text = Qt.formatDate(new Date(), "yyyy-MM-dd")
                proveedorField.text = ""
                gastoForm.selectedTipoGastoIndex = -1
            }
        }
    }

    // DIÁLOGO DE CONFIRMACIÓN DE ELIMINACIÓN
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
    
    // COMPONENTE DE LOADING
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
    
    // TOAST DE ÉXITO
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
    
    // DIÁLOGO DE ERROR
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
    
    // INICIALIZACIÓN MEJORADA CON APPCONTROLLER
    Component.onCompleted: {
        console.log("💰 Módulo Servicios Básicos iniciado")
        
        // Verificar si ya tenemos el modelo disponible
        if (appController && appController.gasto_model_instance) {
            gastoModelInstance = appController.gasto_model_instance
            loadGastosFromModel()
            loadTiposGastosFromModel()
        } else {
            // Si no, esperar con el timer
            delayedInitTimer.start()
        }
        
        // Cargar datos iniciales
        Qt.callLater(cargarPaginaDesdeBD)
    }
}