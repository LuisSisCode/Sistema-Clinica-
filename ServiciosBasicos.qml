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
    readonly property real fontScale: Math.max(1.0, screenHeight / 700) // Mejorado: escala mínima de 1.0

    // Márgenes escalables (sin cambio)
    readonly property real marginSmall: baseUnit * 0.5
    readonly property real marginMedium: baseUnit * 1
    readonly property real marginLarge: baseUnit * 1.5

    // ✅ TAMAÑOS DE FUENTE MEJORADOS - MÁS GRANDES Y LEGIBLES
    readonly property real fontTiny: Math.max(11, 13 * fontScale)      // Era: (8, 10 * fontScale)
    readonly property real fontSmall: Math.max(13, 15 * fontScale)     // Era: (10, 12 * fontScale)  
    readonly property real fontBase: Math.max(15, 17 * fontScale)      // Era: (12, 14 * fontScale)
    readonly property real fontMedium: Math.max(17, 19 * fontScale)    // Era: (14, 16 * fontScale)
    readonly property real fontLarge: Math.max(19, 21 * fontScale)     // Era: (16, 18 * fontScale)
    readonly property real fontTitle: Math.max(22, 28 * fontScale)     // Era: (18, 24 * fontScale)

    // ✅ NUEVOS TAMAÑOS PARA ELEMENTOS ESPECÍFICOS
    readonly property real fontHeader: Math.max(16, 18 * fontScale)    // Para headers de tabla
    readonly property real fontButton: Math.max(14, 16 * fontScale)    // Para botones
    readonly property real fontInput: Math.max(14, 16 * fontScale)
    
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

    // Agregar después de las propiedades de color existentes
    readonly property string usuarioActualRol: {
        if (typeof authModel !== 'undefined' && authModel) {
            return authModel.userRole || ""
        }
        return ""
    }
    readonly property bool esAdministrador: usuarioActualRol === "Administrador"
    readonly property bool esMedico: usuarioActualRol === "Médico" || usuarioActualRol === "MÃ©dico"
    
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
        console.log("   - proveedoresModel.count:", proveedoresModel.count)
        console.log("   - currentPageServicios:", currentPageServicios)
        console.log("   - totalPagesServicios:", totalPagesServicios)
    }
    
    // ✅ CONEXIONES DIRECTAS CON EL GASTOMODEL - CORREGIDAS
    Connections {
        target: gastoModelInstance
        enabled: gastoModelInstance !== null
        
        function onGastosChanged() {
            console.log("🔄 Gastos actualizados - recargar página actual")
            Qt.callLater(cargarPaginaDesdeBD)
        }
        
        function onTiposGastosChanged() {
            console.log("🏷️ Tipos de gastos actualizados")
            Qt.callLater(loadTiposGastosFromModel)
        }
        
        function onProveedoresChanged() {
            console.log("🏢 Proveedores actualizados")
            Qt.callLater(loadProveedoresFromModel)
        }
        
        function onGastoCreado(success, message) {
            console.log("💸 Gasto creado:", success, message)
            if (success) {
                showSuccessMessage(message)
                showNewGastoDialog = false
                selectedRowIndex = -1
                isEditMode = false
                editingIndex = -1
                // Recargar datos
                Qt.callLater(cargarPaginaDesdeBD)
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
                // Recargar datos
                Qt.callLater(cargarPaginaDesdeBD)
            } else {
                showErrorMessage("Error actualizando gasto", message)
            }
        }
        
        function onGastoEliminado(success, message) {
            console.log("🗑️ Gasto eliminado:", success, message)
            if (success) {
                showSuccessMessage(message)
                selectedRowIndex = -1
                // Recargar datos
                Qt.callLater(cargarPaginaDesdeBD)
            } else {
                showErrorMessage("Error eliminando gasto", message)
            }
        }
        
        function onErrorOccurred(title, message) {
            console.error("⚠ Error:", title, message)
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
    
    // CONEXIONES CON APPCONTROLLER PARA NOTIFICACIONES
    Connections {
        target: appController
        
        function onModelsReady() {
            console.log("🚀 Models listos desde AppController")
            if (appController && appController.gasto_model_instance) {
                gastoModelInstance = appController.gasto_model_instance
                console.log("✅ GastoModel disponible")
                Qt.callLater(function() {
                    loadTiposGastosFromModel()
                    loadProveedoresFromModel()
                    cargarPaginaDesdeBD()
                })
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
                loadTiposGastosFromModel()
                loadProveedoresFromModel()
                cargarPaginaDesdeBD()
            } else {
                console.log("⚠ GastoModel aún no disponible")
                if (interval < 2000) {
                    interval = interval * 2
                    start()
                }
            }
        }
    }
    
    // ✅ FUNCIÓN PARA CARGAR TIPOS DE GASTOS - CORREGIDA
    function loadTiposGastosFromModel() {
        if (!gastoModelInstance) {
            console.log("⚠️ GastoModel no disponible para cargar tipos")
            return
        }
        
        console.log("🏷️ Cargando tipos desde modelo...")
        
        // LIMPIAR COMPLETAMENTE EL MODELO ANTES DE AGREGAR NUEVOS DATOS
        tiposGastosModel.clear()
        
        // OBTENER TIPOS DIRECTAMENTE DESDE LA PROPERTY
        var tipos = gastoModelInstance.obtenerTiposParaComboBox()
        
        for (var i = 0; i < tipos.length; i++) {
            var tipo = tipos[i]
            
            // CREAR OBJETO CON TIPOS CONSISTENTES
            var tipoFormatted = {
                id: parseInt(tipo.id || 0),
                nombre: String(tipo.text || tipo.Nombre || "Sin nombre"),  // ← USAR 'text' primero
                descripcion: String(tipo.descripcion || "Tipo de gasto"),
                ejemplos: [],
                color: String(getColorForTipo(tipo.text || tipo.Nombre || ""))
            }
            
            tiposGastosModel.append(tipoFormatted)
        }
        
        // Actualizar ComboBox
        filtroTipoServicio.model = getTiposGastosNombres()

        if (tipoGastoCombo) {
            tipoGastoCombo.model = getTiposGastosParaCombo()
        }
    }
    
    // ✅ NUEVA FUNCIÓN PARA CARGAR PROVEEDORES
    function loadProveedoresFromModel() {
        if (!gastoModelInstance) {
            console.log("⚠️ GastoModel no disponible para cargar proveedores")
            return
        }
        
        // LIMPIAR MODELO DE PROVEEDORES
        proveedoresModel.clear()
        
        // OBTENER PROVEEDORES FORMATEADOS PARA COMBOBOX
        var proveedores = gastoModelInstance.obtenerProveedoresParaComboBox()
        
        for (var i = 0; i < proveedores.length; i++) {
            var proveedor = proveedores[i]
            
            proveedoresModel.append({
                id: parseInt(proveedor.id || 0),
                nombre: String(proveedor.nombre || "Sin nombre"),
                direccion: String(proveedor.direccion || ""),
                displayText: String(proveedor.display_text || proveedor.nombre),
                usoFrecuencia: parseInt(proveedor.uso_frecuencia || 0)
            })
        }
        
        //console.log("🏢 Proveedores cargados:", proveedoresModel.count)
    }
    
    // ✅ FUNCIÓN PARA CREAR GASTO - LLAMADA DIRECTA AL MODEL
    function crearGastoDirecto(gastoData) {
        if (!gastoModelInstance) {
            console.log("⚠ GastoModel no disponible para crear gasto")
            showErrorMessage("Error", "Sistema no disponible")
            return false
        }
        
        console.log("💰 Creando gasto con modelo real...")
        console.log("📊 Datos recibidos:", JSON.stringify(gastoData))
        
        // Obtener ID del tipo de gasto seleccionado
        var tipoGastoId = 0
        if (gastoForm.selectedTipoGastoIndex >= 0) {
            var tipoSeleccionado = tiposGastosModel.get(gastoForm.selectedTipoGastoIndex)
            tipoGastoId = tipoSeleccionado.id
            console.log("🏷️ Tipo de gasto seleccionado:", tipoSeleccionado.nombre, "ID:", tipoGastoId)
        }
        
        // ID de usuario por defecto (debe obtenerse del contexto de sesión)
        var usuarioId = 10  // Cambiar por usuario actual
        
        // LLAMADA DIRECTA AL MÉTODO DEL MODEL
        // ✅ CORRECTO
        var success = gastoModelInstance.crearGasto(
            tipoGastoId,                    // tipo_gasto_id
            parseFloat(gastoData.monto),    // monto
            gastoData.descripcion,          // descripcion
            gastoData.fechaGasto,          // fecha_gasto
            gastoData.proveedor            // proveedor
        )
        
        console.log("🔍 Resultado creación:", success)
        return success
    }

    // ✅ FUNCIÓN PARA ACTUALIZAR GASTO - LLAMADA DIRECTA AL MODEL
    function actualizarGastoDirecto(gastoId, gastoData) {
        if (!gastoModelInstance) {
            console.log("⚠ GastoModel no disponible para actualizar gasto")
            showErrorMessage("Error", "Sistema no disponible")
            return false
        }
        
        console.log("✏️ Actualizando gasto con modelo real...")
        console.log("📊 Datos recibidos:", JSON.stringify(gastoData))
        
        // Obtener ID del tipo de gasto seleccionado
        var tipoGastoId = 0
        if (gastoForm.selectedTipoGastoIndex >= 0) {
            var tipoSeleccionado = tiposGastosModel.get(gastoForm.selectedTipoGastoIndex)
            tipoGastoId = tipoSeleccionado.id
            console.log("🏷️ Tipo de gasto seleccionado:", tipoSeleccionado.nombre, "ID:", tipoGastoId)
        }
        
        // ✅ LLAMADA ACTUALIZADA CON FECHA
        var success = gastoModelInstance.actualizarGasto(
            parseInt(gastoId),              // gasto_id
            parseFloat(gastoData.monto),    // monto
            tipoGastoId,                    // tipo_gasto_id
            gastoData.descripcion,          // descripcion
            gastoData.proveedor,            // proveedor
            gastoData.fechaGasto            // ← NUEVO: fecha_gasto
        )
        
        console.log("✏️ Resultado actualización:", success)
        return success
    }
    
    // ✅ FUNCIÓN PARA ELIMINAR GASTO - LLAMADA DIRECTA AL MODEL
    function eliminarGastoDirecto(gastoId) {
        if (!gastoModelInstance) {
            console.log("⚠ GastoModel no disponible para eliminar gasto")
            showErrorMessage("Error", "Sistema no disponible")
            return false
        }
        
        console.log("🗑️ Eliminando gasto con modelo real...")
        
        // LLAMADA DIRECTA AL MÉTODO DEL MODEL
        var success = gastoModelInstance.eliminarGasto(parseInt(gastoId))
        
        console.log("🗑️ Resultado eliminación:", success)
        return success
    }
    
    // FUNCIONES HELPER EXISTENTES
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
    
    // MODELO DE TIPOS DE GASTOS LOCAL (FALLBACK)
    ListModel {
        id: tiposGastosModel
    }

    // ✅ NUEVO MODELO DE PROVEEDORES
    ListModel {
        id: proveedoresModel
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

    // ✅ NUEVA FUNCIÓN HELPER PARA COMBOBOX DE PROVEEDORES
    function getProveedoresParaCombo() {
        var proveedores = ["Seleccionar proveedor..."]
        for (var i = 0; i < proveedoresModel.count; i++) {
            var proveedor = proveedoresModel.get(i)
            proveedores.push(proveedor.displayText)
        }
        return proveedores
    }
  
    // FUNCIÓN PARA ACTUALIZAR PAGINACIÓN - MEJORADA CON FILTRO "TODOS"
    function cargarPaginaDesdeBD() {
        if (!gastoModelInstance) {
            console.log("GastoModel no disponible aún")
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
        
        // ✅ PROCESAR FILTROS MEJORADOS CON "TODOS LOS PERÍODOS"
        var filtrosActuales = {
            tipo_id: filtroTipoServicio.currentIndex > 0 ? 
                tiposGastosModel.get(filtroTipoServicio.currentIndex - 1).id : 0,
            mes: 0,  // Por defecto "todos los períodos"
            año: añoValor
        };
        
        // ✅ NUEVA LÓGICA PARA FILTRO DE MES CON "TODOS LOS PERÍODOS"
        if (filtroMes.currentIndex === 0) {
            // "Todos los períodos" - no filtrar por fecha
            filtrosActuales.mes = 0;
            filtrosActuales.año = 0;
        } else {
            // Mes específico (índice - 1 porque "Todos los períodos" está en posición 0)
            filtrosActuales.mes = filtroMes.currentIndex;
            filtrosActuales.año = añoValor;
        }
        
        console.log("Aplicando filtros:", JSON.stringify(filtrosActuales));
        
        var offset = currentPageServicios * itemsPerPageServicios;
        
        // LLAMADA DIRECTA A LOS MÉTODOS DEL MODEL
        var gastosPagina = gastoModelInstance.obtenerGastosPaginados(offset, itemsPerPageServicios, filtrosActuales);
        var totalGastos = gastoModelInstance.obtenerTotalGastos(filtrosActuales);
        
        // Limpiar modelo local
        gastosPaginadosModel.clear();
        
        // Poblar modelo local con datos del backend
        for (var i = 0; i < gastosPagina.length; i++) {
            var gasto = gastosPagina[i];
            gastosPaginadosModel.append({
                gastoId: gasto.id || gasto.ID,
                tipoGasto: gasto.tipo_nombre,
                descripcion: gasto.Descripcion,
                monto: parseFloat(gasto.Monto || 0).toFixed(2),
                fechaGasto: gasto.Fecha,
                proveedor: gasto.Proveedor,
                registradoPor: gasto.usuario_nombre
            });
        }
        
        totalPagesServicios = Math.ceil(totalGastos / itemsPerPageServicios);
        loadingIndicator.visible = false;
        
        console.log("Página cargada:", gastosPagina.length, "gastos, Total páginas:", totalPagesServicios);
    }

    // FUNCIÓN PARA LIMPIAR FILTROS
    function limpiarFiltros() {
        console.log("🧹 Limpiando filtros...")
        
        filtroTipoServicio.currentIndex = 0
        filtroMes.currentIndex = 0  // ✅ Cambiar a "Todos los períodos"
        
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
                    Layout.preferredHeight: baseUnit * 5
                    color: lightGrayColor
                    border.color: "#e0e0e0"
                    border.width: 1
                    radius: baseUnit * 0.8
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: baseUnit * 0.8
                        spacing: baseUnit * 0.8
                        
                        // SECCIÓN DEL LOGO Y TÍTULO
                        RowLayout {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: baseUnit * 1
                            
                            Rectangle {
                                Layout.preferredWidth: baseUnit * 4
                                Layout.preferredHeight: baseUnit * 4
                                color: "transparent"
                                
                                Image {
                                    id: serviciosIcon
                                    anchors.centerIn: parent
                                    width: Math.min(baseUnit * 3.2, parent.width * 0.9)
                                    height: Math.min(baseUnit * 3.2, parent.height * 0.9)
                                    source: "Resources/iconos/ServiciosBasicos.png"
                                    fillMode: Image.PreserveAspectFit
                                    antialiasing: true
                                    
                                    onStatusChanged: {
                                        if (status === Image.Error) {
                                            console.log("Error cargando PNG de Servicios Básicos:", source)
                                            visible = false
                                            fallbackLabel.visible = true
                                        } else if (status === Image.Ready) {
                                            console.log("PNG de Servicios Básicos cargado correctamente:", source)
                                        }
                                    }
                                }
                                
                                Label {
                                    id: fallbackLabel
                                    anchors.centerIn: parent
                                    text: "💰"
                                    font.pixelSize: baseUnit * 2.5
                                    color: primaryColor
                                    visible: false
                                }
                            }
                            
                            ColumnLayout {
                                Layout.alignment: Qt.AlignVCenter
                                spacing: baseUnit * 0.05
                                
                                Label {
                                    text: "Gestión de Servicios Básicos"
                                    font.pixelSize: fontMedium        // Era: fontBase * 0.85
                                    font.bold: true
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    color: textColor
                                }
                                
                                Label {
                                    text: "y Gastos Operativos"
                                    font.pixelSize: fontBase          // Era: fontBase * 0.7
                                    font.bold: false
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    color: textColor
                                }
                            }
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        // BOTÓN NUEVO GASTO
                        Button {
                            objectName: "newGastoButton"
                            Layout.preferredHeight: baseUnit * 2.8
                            Layout.preferredWidth: Math.max(baseUnit * 10, implicitWidth + baseUnit * 0.8)
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
                                
                                Rectangle {
                                    Layout.preferredWidth: baseUnit * 1.6
                                    Layout.preferredHeight: baseUnit * 1.6
                                    color: "transparent"
                                    
                                    Image {
                                        id: addGastoIcon
                                        anchors.centerIn: parent
                                        width: baseUnit * 1.2
                                        height: baseUnit * 1.2
                                        source: "Resources/iconos/Nueva_Consulta.png"
                                        fillMode: Image.PreserveAspectFit
                                        antialiasing: true
                                        
                                        onStatusChanged: {
                                            if (status === Image.Error) {
                                                console.log("Error cargando PNG del botón Nuevo Gasto:", source)
                                                visible = false
                                                fallbackPlusText.visible = true
                                            }
                                        }
                                    }
                                    
                                    Label {
                                        id: fallbackPlusText
                                        anchors.centerIn: parent
                                        text: "+"
                                        color: whiteColor
                                        font.pixelSize: fontBase * 0.8
                                        font.bold: true
                                        visible: false
                                    }
                                }
                                
                                Label {
                                    text: "Nuevo Gasto"
                                    color: whiteColor
                                    font.bold: true
                                    font.pixelSize: fontButton        // Era: fontBase * 1.1
                                    font.family: "Segoe UI, Arial, sans-serif"
                                }
                            }
                            
                            onClicked: {
                                isEditMode = false
                                editingIndex = -1
                                showNewGastoDialog = true
                            }
                            
                            HoverHandler {
                                id: buttonHover
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }
                }
                
                // PANEL DE FILTROS
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

                        // ✅ FILTRO MES CON "TODOS LOS PERÍODOS"
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
                                width: Math.max(140, screenWidth * 0.14)
                                model: ["Todos los períodos", "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
                                        "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"]
                                currentIndex: 0  // ✅ Por defecto "Todos los períodos"
                                onCurrentIndexChanged: {
                                    console.log("📅 Filtro mes cambiado:", currentIndex, currentText)
                                    currentPageServicios = 0
                                    Qt.callLater(cargarPaginaDesdeBD)
                                }
                            }
                        }

                        // FILTRO AÑO
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
                                
                                model: {
                                    var años = []
                                    var añoActual = new Date().getFullYear()
                                    años.push(añoActual.toString())
                                    for (var i = 1; i <= 5; i++) {
                                        años.push((añoActual - i).toString())
                                    }
                                    return años.sort(function(a, b) { return parseInt(b) - parseInt(a) })
                                }
                                
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
                        
                        // BOTÓN LIMPIAR FILTROS
                        Button {
                            text: "Limpiar"
                            Layout.preferredWidth: 80
                            
                            background: Rectangle {
                                color: warningColor
                                radius: 5
                            }
                            
                            contentItem: Label {
                                text: parent.text
                                color: whiteColor
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: limpiarFiltros()
                        }
                    }
                }

                // CONTENEDOR DE TABLA
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
                        
                        // HEADER DE TABLA
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
                                        font.pixelSize: fontHeader        // Era: fontSmall
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
                        
                        // CONTENIDO DE TABLA
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
                                                    font.pixelSize: fontSmall 
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
                                                font.pixelSize: fontSmall 
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
                                                font.pixelSize: fontSmall
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
                                                font.pixelSize: fontSmall
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
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.right: parent.right
                                        anchors.rightMargin: marginSmall * 0.5
                                        spacing: marginSmall * 0.25
                                        visible: selectedRowIndex === index
                                        z: 10
                                        
                                        Button {
                                            id: editButton
                                            width: baseUnit * 2.2
                                            height: baseUnit * 2.2
                                            visible: serviciosBasicosRoot.esAdministrador || serviciosBasicosRoot.esMedico
                                            enabled: {
                                                if (serviciosBasicosRoot.esAdministrador) return true
                                                if (serviciosBasicosRoot.esMedico) {
                                                    // Verificar fecha para médicos (30 días límite)
                                                    var fechaGasto = new Date(model.fechaGasto || "")
                                                    var fechaActual = new Date()
                                                    var diasDiferencia = Math.floor((fechaActual - fechaGasto) / (1000 * 60 * 60 * 24))
                                                    return diasDiferencia <= 30
                                                }
                                                return false
                                            }
                                            background: Rectangle {
                                                color: "transparent"
                                            }
                                            
                                            Image {
                                                id: editIcon
                                                anchors.centerIn: parent
                                                width: baseUnit * 1.2
                                                height: baseUnit * 1.2
                                                source: "Resources/iconos/editar.svg"
                                                fillMode: Image.PreserveAspectFit
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
                                            
                                            onHoveredChanged: {
                                                editIcon.opacity = hovered ? 0.7 : 1.0
                                            }
                                            ToolTip.text: {
                                                if (serviciosBasicosRoot.esAdministrador) return "Editar gasto"
                                                if (serviciosBasicosRoot.esMedico) {
                                                    var fechaGasto = new Date(model.fechaGasto || "")
                                                    var fechaActual = new Date()
                                                    var diasDiferencia = Math.floor((fechaActual - fechaGasto) / (1000 * 60 * 60 * 24))
                                                    if (diasDiferencia > 30) {
                                                        return "No se puede editar: gasto de más de 30 días"
                                                    }
                                                    return "Editar gasto (máximo 30 días)"
                                                }
                                                return "Sin permisos"
                                            }
                                        }
                                        
                                        Button {
                                            id: deleteButton
                                            width: baseUnit * 2.2
                                            height: baseUnit * 2.2
                                            visible: serviciosBasicosRoot.esAdministrador

                                            background: Rectangle {
                                                color: "transparent"
                                            }
                                            
                                            Image {
                                                id: deleteIcon
                                                anchors.centerIn: parent
                                                width: baseUnit * 1.2
                                                height: baseUnit * 1.2
                                                source: "Resources/iconos/eliminar.svg"
                                                fillMode: Image.PreserveAspectFit
                                            }
                                            
                                            onClicked: {
                                                console.log("🗑️ Botón eliminar presionado")
                                                console.log("🎯 gastoId:", model.gastoId)
                                                
                                                if (model.gastoId && model.gastoId !== "N/A") {
                                                    confirmDeleteDialog.gastoIdToDelete = String(model.gastoId)
                                                    confirmDeleteDialog.open()
                                                } else {
                                                    console.log("❌ ID de gasto inválido")
                                                }
                                            }
                                            
                                            onHoveredChanged: {
                                                deleteIcon.opacity = hovered ? 0.7 : 1.0
                                            }
                                            
                                            ToolTip.text: "Eliminar gasto (solo administradores)"
                                        }
                                        Button {
                                            width: baseUnit * 2.2
                                            height: baseUnit * 2.2
                                            visible: selectedRowIndex === index && !editButton.visible
                                            enabled: false
                                            
                                            background: Rectangle {
                                                color: "transparent"
                                            }
                                            
                                            Image {
                                                anchors.centerIn: parent
                                                width: baseUnit * 1.2
                                                height: baseUnit * 1.2
                                                source: "Resources/iconos/editar.svg"
                                                fillMode: Image.PreserveAspectFit
                                                opacity: 0.3
                                            }
                                            
                                            //ToolTip.visible: parent.hovered
                                            ToolTip.text: {
                                                if (gastoModelInstance && gastoModelInstance.esAdministrador()) {
                                                    return "Sin permisos de edición"
                                                } else {
                                                    return "Solo puedes editar tus gastos dentro de 30 días"
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // ESTADO VACÍO PARA TABLA SIN DATOS
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                visible: gastosPaginadosModel.count === 0 && !loadingIndicator.visible
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
                
                // CONTROL DE PAGINACIÓN
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

    // ✅ DIÁLOGO DE NUEVO GASTO - CON BLOQUEO TOTAL COMO EL DE ELIMINAR
    Dialog {
        id: gastoForm
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.7, 500)
        height: Math.min(parent.height * 0.75, 550)
        modal: true
        closePolicy: Popup.NoAutoClose
        visible: showNewGastoDialog
        
        property int selectedTipoGastoIndex: -1
        property int selectedProveedorIndex: -1
        
        // Remover el título por defecto para usar nuestro diseño personalizado
        title: ""
        
        background: Rectangle {
            color: whiteColor
            radius: 8
            border.color: "#DDD"
            border.width: 1
            
            // Sombra sutil
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
        
        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            
            // HEADER
            Rectangle {
                id: dialogHeader
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                color: primaryColor
                radius: 8
                
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 8
                    color: parent.color
                }
                
                Label {
                    anchors.centerIn: parent
                    text: isEditMode ? "EDITAR GASTO" : "NUEVO GASTO"
                    font.pixelSize: 16
                    font.bold: true
                    color: whiteColor
                }
                
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
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "transparent"
                
                ScrollView {
                    id: scrollView
                    anchors.fill: parent
                    anchors.margins: 20
                    anchors.topMargin: 15
                    anchors.bottomMargin: 70
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
                                font.pixelSize: fontInput
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
                                font.pixelSize: fontInput 
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
                                inputMethodHints: Qt.ImhDate  

                                onTextChanged: {
                                    var datePattern = /^\d{4}-\d{2}-\d{2}$/
                                    if (text.length === 10 && !datePattern.test(text)) {
                                        color = "#e74c3c"
                                    } else {
                                        color = "#2c3e50"
                                    }
                                }
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
                            
                            ComboBox {
                                id: proveedorCombo
                                width: parent.width
                                height: 40
                                model: getProveedoresParaCombo()
                                onCurrentIndexChanged: {
                                    if (currentIndex > 0) {
                                        gastoForm.selectedProveedorIndex = currentIndex - 1
                                    } else {
                                        gastoForm.selectedProveedorIndex = -1
                                    }
                                }
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
                                font.pixelSize: fontInput
                                placeholderText: "Descripción detallada del gasto..."
                                wrapMode: TextArea.Wrap
                            }
                        }
                    }
                }
            }
            
            // BOTONES
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 70
                color: "transparent"
                
                Row {
                    id: buttonRow
                    anchors.centerIn: parent
                    spacing: 15
                    
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
                            font.pixelSize: fontButton 
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
                            gastoForm.selectedProveedorIndex >= 0 &&
                            fechaGastoField.text.length > 0 
                                
                        
                        background: Rectangle {
                            color: !saveButton.enabled ? "#bdc3c7" : 
                                (saveButton.pressed ? Qt.darker(primaryColor, 1.1) : primaryColor)
                            radius: 5
                        }
                        
                        contentItem: Label {
                            text: parent.text
                            font.pixelSize: fontButton
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
                            
                            if (gastoForm.selectedProveedorIndex < 0) {
                                showErrorMessage("Error de validación", "Selecciona un proveedor")
                                return
                            }
                            
                            if (parseFloat(montoField.text) <= 0) {
                                showErrorMessage("Error de validación", "El monto debe ser mayor a 0")
                                return
                            }
                            if (!fechaGastoField.text || fechaGastoField.text.length < 10) {
                                showErrorMessage("Error de validación", "Ingresa una fecha válida (YYYY-MM-DD)")
                                return
                            }
                            
                            var proveedorSeleccionado = proveedoresModel.get(gastoForm.selectedProveedorIndex)
                            var proveedorNombre = proveedorSeleccionado.nombre
                            
                            var gastoData = {
                                descripcion: descripcionField.text.trim(),
                                monto: parseFloat(montoField.text).toFixed(2),
                                fechaGasto: fechaGastoField.text,
                                proveedor: proveedorNombre
                            }
                            
                            console.log("Enviando datos del formulario:", JSON.stringify(gastoData))
                            
                            var success = false
                            
                            if (isEditMode && editingGastoData) {
                                success = actualizarGastoDirecto(editingGastoData.gastoId, gastoData)
                            } else {
                                success = crearGastoDirecto(gastoData)
                            }
                            
                            if (!success) {
                                showErrorMessage("Error", "No se pudo guardar el gasto. Revisa los datos.")
                            }
                        }
                    }
                }
            }
        }
        
        // CARGAR DATOS EN MODO EDICIÓN
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
                
                // Buscar el proveedor correspondiente
                var proveedorNombre = editingGastoData.proveedor
                for (var j = 0; j < proveedoresModel.count; j++) {
                    if (proveedoresModel.get(j).nombre === proveedorNombre) {
                        proveedorCombo.currentIndex = j + 1
                        gastoForm.selectedProveedorIndex = j
                        break
                    }
                }
                
                // Cargar el resto de campos
                descripcionField.text = editingGastoData.descripcion
                montoField.text = editingGastoData.monto
                fechaGastoField.text = editingGastoData.fechaGasto
            } else if (visible && !isEditMode) {
                // Limpiar formulario para nuevo gasto
                tipoGastoCombo.currentIndex = 0
                proveedorCombo.currentIndex = 0
                descripcionField.text = ""
                montoField.text = ""
                fechaGastoField.text = Qt.formatDate(new Date(), "yyyy-MM-dd")
                gastoForm.selectedTipoGastoIndex = -1
                gastoForm.selectedProveedorIndex = -1
            }
        }
    }

    // DIÁLOGO DE CONFIRMACIÓN DE ELIMINACIÓN MEJORADO
    Dialog {
        id: confirmDeleteDialog
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.9, 480)
        height: Math.min(parent.height * 0.55, 320)
        modal: true
        closePolicy: Popup.NoAutoClose
        
        property string gastoIdToDelete: ""
        
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
                    spacing: marginMedium
                    
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
                            font.pixelSize: fontLarge
                        }
                    }
                    
                    ColumnLayout {
                        spacing: marginSmall * 0.25
                        
                        Label {
                            text: "Confirmar Eliminación"
                            font.pixelSize: fontLarge
                            font.bold: true
                            color: "#dc2626"
                            Layout.alignment: Qt.AlignLeft
                        }
                        
                        Label {
                            text: "Acción irreversible"
                            font.pixelSize: fontSmall
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
                    anchors.margins: marginMedium
                    spacing: marginSmall
                    
                    Item { Layout.preferredHeight: marginSmall * 0.5 }
                    
                    Label {
                        text: "¿Estás seguro de eliminar este gasto?"
                        font.pixelSize: fontMedium
                        font.bold: true
                        color: textColor
                        Layout.alignment: Qt.AlignHCenter
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                    
                    Label {
                        text: "Esta acción no se puede deshacer y el registro se eliminará permanentemente."
                        font.pixelSize: fontBase
                        color: "#6b7280"
                        Layout.alignment: Qt.AlignHCenter
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        Layout.maximumWidth: parent.width - marginMedium * 2
                    }
                    
                    Item { Layout.fillHeight: true }
                    
                    // Botones mejorados
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: marginLarge
                        Layout.bottomMargin: marginSmall
                        Layout.topMargin: marginSmall
                        
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
                                spacing: marginSmall * 0.5
                                
                                Label {
                                    text: "✕"
                                    color: "#6b7280"
                                    font.pixelSize: fontSmall
                                    Layout.alignment: Qt.AlignVCenter
                                }
                                
                                Label {
                                    text: "Cancelar"
                                    color: "#374151"
                                    font.bold: true
                                    font.pixelSize: fontBase
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }
                            
                            onClicked: confirmDeleteDialog.close()
                            
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
                                spacing: marginSmall * 0.5
                                
                                Label {
                                    text: "🗑️"
                                    color: whiteColor
                                    font.pixelSize: fontSmall
                                    Layout.alignment: Qt.AlignVCenter
                                }
                                
                                Label {
                                    text: "Eliminar"
                                    color: whiteColor
                                    font.bold: true
                                    font.pixelSize: fontBase
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }
                            
                            onClicked: {
                                console.log("🗑️ Confirmando eliminación de gasto...")
                                console.log("🎯 gastoIdToDelete:", confirmDeleteDialog.gastoIdToDelete)
                                
                                var gastoId = parseInt(confirmDeleteDialog.gastoIdToDelete)
                                console.log("🎯 gastoId parseado:", gastoId)
                                
                                if (eliminarGasto(gastoId)) {
                                    selectedRowIndex = -1
                                    console.log("✅ Gasto eliminado correctamente ID:", gastoId)
                                    mostrarNotificacion("Éxito", "Gasto eliminado correctamente")
                                } else {
                                    console.log("❌ Error eliminando gasto ID:", gastoId)
                                    mostrarNotificacion("Error", "No se pudo eliminar el gasto")
                                }
                                
                                confirmDeleteDialog.close()
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
                text: "⚠ " + errorDialog.title
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
    function eliminarGasto(gastoId) {
        try {
            console.log("🗑️ Iniciando eliminación de gasto ID:", gastoId)
            
            // Verificar permisos de administrador
            if (!serviciosBasicosRoot.esAdministrador) {
                mostrarNotificacion("Error", "Solo administradores pueden eliminar gastos")
                return false
            }
            
            if (!gastoModelInstance) {
                console.log("❌ GastoModel no disponible")
                mostrarNotificacion("Error", "Sistema no disponible")
                return false
            }
            
            var resultado = gastoModelInstance.eliminarGasto(parseInt(gastoId))
            
            if (resultado) {
                console.log("✅ Gasto eliminado exitosamente")
                // Recargar datos
                aplicarFiltros()
                return true
            } else {
                console.log("❌ Error eliminando gasto")
                mostrarNotificacion("Error", "No se pudo eliminar el gasto")
                return false
            }
            
        } catch (error) {
            console.log("❌ Error en eliminación:", error.message)
            //mostrarNotificacion("Error", "Error eliminando gasto: " + error.message)
            return false
        }
    }
    function mostrarNotificacion(titulo, mensaje) {
        console.log("📢 " + titulo + ": " + mensaje)
    }
    
    // INICIALIZACIÓN MEJORADA CON APPCONTROLLER
    Component.onCompleted: {
        console.log("Módulo Servicios Básicos iniciado")
        
        // Verificar si ya tenemos el modelo disponible
        if (appController && appController.gasto_model_instance) {
            gastoModelInstance = appController.gasto_model_instance
            console.log("GastoModel disponible inmediatamente")
            Qt.callLater(function() {
                loadTiposGastosFromModel()
                loadProveedoresFromModel()  // ✅ NUEVA CARGA
                cargarPaginaDesdeBD()
            })
        } else {
            console.log("Esperando inicialización de GastoModel...")
            delayedInitTimer.start()
        }
    }
}