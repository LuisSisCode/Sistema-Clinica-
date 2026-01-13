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
    readonly property real fontScale: Math.max(0.8, screenHeight / 900) // Reducido de 1.0 a 0.8

    // Márgenes escalables (sin cambio)
    readonly property real marginSmall: baseUnit * 0.5
    readonly property real marginMedium: baseUnit * 1
    readonly property real marginLarge: baseUnit * 1.5

    // ✅ TAMAÑOS DE FUENTE AJUSTADOS - MÁS PEQUEÑOS COMO USUARIOS.QML
    readonly property real fontTiny: Math.max(10, 11 * fontScale)      // Reducido
    readonly property real fontSmall: Math.max(11, 13 * fontScale)     // Reducido
    readonly property real fontBase: Math.max(13, 15 * fontScale)      // Reducido
    readonly property real fontMedium: Math.max(15, 17 * fontScale)    // Reducido
    readonly property real fontLarge: Math.max(17, 19 * fontScale)     // Reducido
    readonly property real fontTitle: Math.max(20, 25 * fontScale)     // Reducido

    // ✅ TAMAÑOS AJUSTADOS PARA ELEMENTOS ESPECÍFICOS
    readonly property real fontHeader: Math.max(14, 16 * fontScale)    // Reducido
    readonly property real fontButton: Math.max(12, 14 * fontScale)    // Reducido
    readonly property real fontInput: Math.max(12, 14 * fontScale)     // Reducido
    
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
    
    // Agregar después de las propiedades existentes:
    property int currentSubsection: 0
    readonly property var subsectionTitles: ["Gastos Operativos", "Ingresos Extras", "Egresos Extras"]
    readonly property var subsectionIcons: [
        "Resources/iconos/ServiciosBasicos.png",
        "Resources/iconos/ingresos.png", 
        "Resources/iconos/egresos.png"
    ]

    property ListModel proveedoresGastosModel: ListModel {}
    property bool showNewProveedorDialog: false
    property string nuevoProveedorNombre: ""

    readonly property var coloresDisponibles: [
    "#E74C3C", "#3498DB", "#2ECC71", "#F39C12", "#9B59B6",
    "#1ABC9C", "#E67E22", "#34495E", "#16A085", "#27AE60",
    "#2980B9", "#8E44AD", "#C0392B", "#D35400", "#00BCD4",
    "#4CAF50", "#FF5722", "#673AB7", "#3F51B5", "#009688",
    "#795548", "#FFC107", "#FF9800", "#F44336", "#E91E63",
    "#9C27B0", "#673AB7", "#3F51B5", "#2196F3", "#00BCD4",
    "#009688", "#4CAF50", "#8BC34A", "#CDDC39", "#FFEB3B",
    "#FFC107", "#FF9800", "#FF5722", "#795548", "#9E9E9E",
    "#607D8B", "#F48FB1", "#BA68C8", "#7E57C2", "#5C6BC0"
    ]

    function getColorForTipo(nombreTipo) {
        if (!nombreTipo) return "#95a5a6"
        
        // Buscar el tipo en tiposGastosModel
        for (var i = 0; i < tiposGastosModel.count; i++) {
            var tipo = tiposGastosModel.get(i)
            if (tipo.nombre && tipo.nombre.toLowerCase() === nombreTipo.toLowerCase()) {
                // Asignar color basado en posición en el modelo
                var colorIndex = i % coloresDisponibles.length
                return coloresDisponibles[colorIndex]
            }
        }
        
        return "#95a5a6"
    }

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
            if (appController && appController.gasto_model_instance) {
                gastoModelInstance = appController.gasto_model_instance
                Qt.callLater(function() {
                    loadTiposGastosFromModel()
                    loadProveedoresFromModel()
                    loadProveedoresGastosFromModel()  // ✅ AGREGAR ESTA LÍNEA
                    cargarPaginaDesdeBD()
                })
            } else {
                console.log("⚠️ GastoModel no disponible aún")
                delayedInitTimer.start()
            }
        }
        // Agregar esta señal al Connections del GastoModel:
        function onProveedoresGastosChanged() {
            console.log("🔄 Proveedores de gastos actualizados desde señal")
            Qt.callLater(loadProveedoresGastosFromModel)
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
                loadProveedoresGastosFromModel()  // ✅ AGREGAR ESTA LÍNEA
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
    
    function loadTiposGastosFromModel() {
        if (!gastoModelInstance) {
            console.log("⚠️ GastoModel no disponible para cargar tipos")
            return
        }
        
        console.log("🏷️ Cargando tipos desde modelo...")
        
        // LIMPIAR MODELO
        tiposGastosModel.clear()
        
        // ✅ CORREGIDO: Usar la property tipografía correcta
        try {
            // Opción 1: Intentar con la property tiposGastos
            if (gastoModelInstance.tiposGastos) {
                var tipos = gastoModelInstance.tiposGastos
                console.log("📊 Tipos obtenidos via property:", tipos.length)
                
                for (var i = 0; i < tipos.length; i++) {
                    var tipo = tipos[i]
                    
                    // Extraer nombre correctamente
                    var nombreTipo = tipo.Nombre || tipo.nombre || tipo.text || "Sin nombre"
                    
                    var tipoFormatted = {
                        id: parseInt(tipo.id || 0),
                        nombre: String(nombreTipo),
                        descripcion: String(tipo.descripcion || tipo.descripcion || "Tipo de gasto"),
                        color: String(getColorForTipo(nombreTipo))
                    }
                    
                    console.log("🏷️ Tipo cargado:", nombreTipo, "Color:", tipoFormatted.color)
                    tiposGastosModel.append(tipoFormatted)
                }
            } 
            // Opción 2: Si no funciona, usar el método
            else {
                var tiposArray = gastoModelInstance.obtenerTiposParaComboBox()
                console.log("📊 Tipos obtenidos via método:", tiposArray.length)
                
                for (var j = 0; j < tiposArray.length; j++) {
                    var tipo2 = tiposArray[j]
                    var nombreTipo2 = tipo2.Nombre || tipo2.nombre || tipo2.text || "Sin nombre"
                    
                    tiposGastosModel.append({
                        id: parseInt(tipo2.id || 0),
                        nombre: String(nombreTipo2),
                        descripcion: String(tipo2.descripcion || "Tipo de gasto"),
                        color: String(getColorForTipo(nombreTipo2))
                    })
                }
            }
        } catch (error) {
            console.log("❌ Error cargando tipos:", error)
        }
        
        console.log("✅ Tipos de gastos cargados:", tiposGastosModel.count)
        
        // Actualizar ComboBoxes
        Qt.callLater(function() {
            filtroTipoServicio.model = getTiposGastosNombres()
            if (tipoGastoCombo) {
                tipoGastoCombo.model = getTiposGastosParaCombo()
            }
        })
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
    function crearGastoDirecto(gastoData, proveedorId) {
        if (!gastoModelInstance) {
            console.log("⚠️ GastoModel no disponible para crear gasto")
            showErrorMessage("Error", "Sistema no disponible")
            return false
        }
        
        console.log("💰 Creando gasto con modelo real...")
        console.log("📊 Datos recibidos:", JSON.stringify(gastoData))
        console.log("🏢 Proveedor ID:", proveedorId)
        
        // Obtener ID del tipo de gasto seleccionado
        var tipoGastoId = 0
        if (gastoForm.selectedTipoGastoIndex >= 0) {
            var tipoSeleccionado = tiposGastosModel.get(gastoForm.selectedTipoGastoIndex)
            tipoGastoId = tipoSeleccionado.id
            console.log("🏷️ Tipo de gasto seleccionado:", tipoSeleccionado.nombre, "ID:", tipoGastoId)
        }
        
        // LLAMADA ACTUALIZADA CON proveedor_id
        var success = gastoModelInstance.crearGasto(
            tipoGastoId,                    // tipo_gasto_id
            parseFloat(gastoData.monto),    // monto
            gastoData.descripcion,          // descripcion
            gastoData.fechaGasto,          // fecha_gasto
            proveedorId                     // proveedor_id (puede ser 0)
        )
        
        console.log("📝 Resultado creación:", success)
        return success
    }

    // ✅ FUNCIÓN PARA ACTUALIZAR GASTO - LLAMADA DIRECTA AL MODEL
    function actualizarGastoDirecto(gastoId, gastoData, proveedorId) {
        if (!gastoModelInstance) {
            console.log("⚠️ GastoModel no disponible para actualizar gasto")
            showErrorMessage("Error", "Sistema no disponible")
            return false
        }
        
        console.log("✏️ Actualizando gasto con modelo real...")
        console.log("📊 Datos recibidos:", JSON.stringify(gastoData))
        console.log("🏢 Proveedor ID:", proveedorId)
        
        // Obtener ID del tipo de gasto seleccionado
        var tipoGastoId = 0
        if (gastoForm.selectedTipoGastoIndex >= 0) {
            var tipoSeleccionado = tiposGastosModel.get(gastoForm.selectedTipoGastoIndex)
            tipoGastoId = tipoSeleccionado.id
            console.log("🏷️ Tipo de gasto seleccionado:", tipoSeleccionado.nombre, "ID:", tipoGastoId)
        }
        
        // LLAMADA ACTUALIZADA CON proveedor_id
        var success = gastoModelInstance.actualizarGasto(
            parseInt(gastoId),              // gasto_id
            parseFloat(gastoData.monto),    // monto
            tipoGastoId,                    // tipo_gasto_id
            gastoData.descripcion,          // descripcion
            proveedorId,                    // proveedor_id (0 para quitar, -1 para no cambiar)
            gastoData.fechaGasto            // fecha_gasto
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
  
    function cargarPaginaDesdeBD() {
        if (!gastoModelInstance) {
            console.log("GastoModel no disponible aún")
            return
        }
        
        loadingIndicator.visible = true;
        
        console.log("🔍 Cargando página de gastos...")
        
        // Validar y obtener el año correctamente
        var añoValor = 0;
        if (filtroAño.currentText && !isNaN(parseInt(filtroAño.currentText))) {
            añoValor = parseInt(filtroAño.currentText);
        } else {
            añoValor = new Date().getFullYear();
        }
        
        // CORREGIDO: Inicializar siempre con año seleccionado, pero también manejar el caso cuando no se quiere filtrar por año
        var filtrosActuales = {
            tipo_id: filtroTipoServicio.currentIndex > 0 ? 
                tiposGastosModel.get(filtroTipoServicio.currentIndex - 1).id : 0
        };
        
        // Solo incluir mes si no es "Todos los períodos" y hay un año seleccionado
        if (filtroMes.currentIndex > 0 && añoValor > 0) {
            filtrosActuales.mes = filtroMes.currentIndex;
            filtrosActuales.año = añoValor;
        }
        // Si hay año pero no mes, solo filtrar por año
        else if (añoValor > 0) {
            filtrosActuales.año = añoValor;
            filtrosActuales.mes = -1;  // Valor especial para indicar "solo año, sin mes específico"
        }
        
        console.log("📊 Aplicando filtros:", JSON.stringify(filtrosActuales));
        
        var offset = currentPageServicios * itemsPerPageServicios;
        
        // LLAMADA DIRECTA
        var gastosPagina = gastoModelInstance.obtenerGastosPaginados(offset, itemsPerPageServicios, filtrosActuales);
        var totalGastos = gastoModelInstance.obtenerTotalGastos(filtrosActuales);
        
        // Limpiar modelo
        gastosPaginadosModel.clear();
        
        console.log("📦 Gastos recibidos del backend:", gastosPagina.length);
        
        // Poblar modelo
        for (var i = 0; i < gastosPagina.length; i++) {
            var gasto = gastosPagina[i];
            
            // DEBUG detallado
            console.log("📄 Gasto", i, ":", {
                id: gasto.id,
                tipo_nombre: gasto.tipo_nombre,
                proveedor_nombre: gasto.proveedor_nombre,
                Proveedor: gasto.Proveedor,
                proveedor: gasto.proveedor
            });
            
            // ✅ CORRECCIÓN: Usar el campo que el backend definitivamente retorna
            var nombreProveedor = gasto.Proveedor || gasto.proveedor_nombre || gasto.proveedor || "Sin proveedor";
            console.log("🏢 Proveedor extraído:", nombreProveedor, "desde campos:", {
                Proveedor: gasto.Proveedor,
                proveedor_nombre: gasto.proveedor_nombre,
                proveedor: gasto.proveedor
            });
            
            gastosPaginadosModel.append({
                gastoId: gasto.id || 0,
                tipoGasto: gasto.tipo_nombre || "Sin tipo",
                descripcion: gasto.Descripcion || gasto.descripcion || "Sin descripción",
                monto: parseFloat(gasto.Monto || gasto.monto || 0).toFixed(2),
                fechaGasto: gasto.Fecha || gasto.fechaGasto || "",
                proveedor: nombreProveedor,
                registradoPor: gasto.usuario_nombre || gasto.registradoPor || "Usuario desconocido"
            });
        }
        
        totalPagesServicios = Math.ceil(totalGastos / itemsPerPageServicios);
        loadingIndicator.visible = false;
        
        console.log("✅ Página cargada:", gastosPaginadosModel.count, "gastos, Total páginas:", totalPagesServicios);
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
        
        // STACKLAYOUT PARA SUBSECCIONES
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: currentSubsection
            
            // Subsección 0: Gastos Operativos (contenido actual)
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
                                    
                                    // En el header, cambiar el Label del título:
                                    Label {
                                        text: "Gestión de " + subsectionTitles[currentSubsection]
                                        font.pixelSize: fontMedium // Reducido de fontLarge
                                        font.bold: true
                                        font.family: "Segoe UI, Arial, sans-serif"
                                        color: textColor
                                    }
                                    
                                    Label {
                                        text: "y Gastos Operativos"
                                        font.pixelSize: fontBase // Reducido de fontMedium
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
                                        font.pixelSize: fontButton // Reducido
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
                                    font.pixelSize: fontBase // Reducido
                                    color: textColor
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                
                                ComboBox {
                                    id: filtroTipoServicio
                                    width: Math.max(160, screenWidth * 0.15)
                                    font.pixelSize: fontBase // Reducido
                                    
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

                            // FILTRO MES CON "TODOS LOS PERÍODOS"
                            Row {
                                spacing: marginSmall
                                Layout.alignment: Qt.AlignVCenter
                                
                                Label {
                                    text: "Mes:"
                                    font.bold: true
                                    font.pixelSize: fontBase // Reducido
                                    color: textColor
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                
                                ComboBox {
                                    id: filtroMes
                                    width: Math.max(140, screenWidth * 0.14)
                                    font.pixelSize: fontBase // Reducido
                                    model: ["Todos los períodos", "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
                                            "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"]
                                    currentIndex: 0
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
                                    font.pixelSize: fontBase // Reducido
                                    color: textColor
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: filtroAño.visible
                                }
                                
                                ComboBox {
                                    id: filtroAño
                                    width: Math.max(80, screenWidth * 0.08)
                                    font.pixelSize: fontBase // Reducido
                                    
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
                                font.pixelSize: fontButton // Reducido
                                
                                background: Rectangle {
                                    color: warningColor
                                    radius: 5
                                }
                                
                                contentItem: Label {
                                    text: parent.text
                                    color: whiteColor
                                    font.bold: true
                                    font.pixelSize: fontButton // Reducido
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
                                            font.pixelSize: fontSmall // Reducido
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
                                            font.pixelSize: fontHeader // Reducido
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
                                            font.pixelSize: fontSmall // Reducido
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
                                            font.pixelSize: fontSmall // Reducido
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
                                            font.pixelSize: fontSmall // Reducido
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
                                            font.pixelSize: fontSmall // Reducido
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
                                            font.pixelSize: fontSmall // Reducido
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
                                                    font.pixelSize: fontSmall // Reducido
                                                }
                                            }
                                            
                                            // COLUMNA TIPO - AUMENTADO EL TAMAÑO
                                            Rectangle {
                                                Layout.preferredWidth: parent.width * 0.16
                                                Layout.fillHeight: true
                                                color: "transparent"
                                                border.color: "#d0d0d0"
                                                border.width: 1
                                                
                                                Rectangle {
                                                    anchors.centerIn: parent
                                                    width: Math.min(parent.width * 0.9, baseUnit * 8) // Aumentado de 6 a 8
                                                    height: Math.min(parent.height * 0.6, baseUnit * 2) // Aumentado de 1 a 2
                                                    color: getColorForTipo(model.tipoGasto)
                                                    radius: height / 2
                                                    
                                                    Label {
                                                        anchors.centerIn: parent
                                                        text: model.tipoGasto
                                                        color: whiteColor
                                                        font.pixelSize: fontSmall // Reducido pero más visible por el tamaño aumentado
                                                        font.bold: true
                                                        padding: 4
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
                                                    font.pixelSize: fontSmall // Reducido
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
                                                    font.pixelSize: fontSmall // Reducido
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
                                                    font.pixelSize: fontSmall // Reducido
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
                                                    // CORRECCIÓN: Cambiar 'proveedor_nombre' por 'proveedor'
                                                    text: model.proveedor || "Sin proveedor"
                                                    color: model.proveedor ? textColor : "#95a5a6"
                                                    font.pixelSize: fontTiny
                                                    font.italic: !model.proveedor
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
                                                    font.pixelSize: fontTiny // Reducido
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
                                            font.pixelSize: fontLarge // Reducido
                                            Layout.alignment: Qt.AlignHCenter
                                            font.family: "Segoe UI"
                                        }
                                        
                                        Label {
                                            text: "Registra el primer gasto haciendo clic en \"➕ Nuevo Gasto\""
                                            color: "#6B7280"
                                            font.pixelSize: fontBase // Reducido
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
                                font.pixelSize: fontBase // Reducido
                                
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
                                    font.pixelSize: fontBase // Reducido
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
                                font.pixelSize: fontBase // Reducido
                                font.weight: Font.Medium
                            }
                            
                            // Botón Siguiente
                            Button {
                                Layout.preferredWidth: Math.max(90, screenWidth * 0.09)
                                Layout.preferredHeight: Math.max(32, screenHeight * 0.05)
                                text: "Siguiente →"
                                enabled: currentPageServicios < totalPagesServicios - 1
                                font.pixelSize: fontBase // Reducido
                                
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
                                    font.pixelSize: fontBase // Reducido
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
            
            // Subsección 1: Ingresos Extras
            Loader {
                Layout.fillWidth: true
                Layout.fillHeight: true
                source: "IngresosExtras.qml"
            }
        }
    }

    // ✅ DIÁLOGO DE NUEVO GASTO - CON BLOQUEO TOTAL COMO EL DE ELIMINAR
    Dialog {
        id: gastoForm
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.7, 500)
        height: Math.min(parent.height * 0.75, 700)
        modal: true
        closePolicy: Popup.NoAutoClose
        visible: showNewGastoDialog
        
        property int selectedTipoGastoIndex: -1
        property string selectedProveedorId: "0"
        
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
                                font.pixelSize: fontInput // Reducido
                            }
                            
                            ComboBox {
                                id: tipoGastoCombo
                                width: parent.width
                                height: 40
                                font.pixelSize: fontInput // Reducido
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
                                font.pixelSize: fontInput
                            }
                            
                            TextField {
                                id: montoField
                                width: parent.width
                                height: 40
                                placeholderText: "0,00"
                                font.pixelSize: fontInput
                                
                                // ✅ VALIDADOR SIMPLIFICADO
                                validator: RegularExpressionValidator {
                                    regularExpression: /^[0-9]*[,]?[0-9]{0,2}$/
                                }
                                
                                // ✅ NORMALIZACIÓN AL PERDER FOCO
                                onEditingFinished: {
                                    if (text.length > 0) {
                                        // Reemplazar punto por coma si existe
                                        var textoNormalizado = text.replace('.', ',')
                                        
                                        // Asegurar formato decimal
                                        if (!textoNormalizado.includes(',')) {
                                            textoNormalizado += ',00'
                                        } else {
                                            var partes = textoNormalizado.split(',')
                                            if (partes[1].length === 1) {
                                                textoNormalizado += '0'
                                            } else if (partes[1].length === 0) {
                                                textoNormalizado += '00'
                                            }
                                        }
                                        
                                        text = textoNormalizado
                                    }
                                }
                                
                                // ✅ FILTRO DE TECLAS BÁSICO
                                Keys.onPressed: function(event) {
                                    var allowedKeys = [
                                        Qt.Key_0, Qt.Key_1, Qt.Key_2, Qt.Key_3, Qt.Key_4,
                                        Qt.Key_5, Qt.Key_6, Qt.Key_7, Qt.Key_8, Qt.Key_9,
                                        Qt.Key_Comma, Qt.Key_Period, Qt.Key_Backspace, 
                                        Qt.Key_Delete, Qt.Key_Left, Qt.Key_Right, Qt.Key_Tab,
                                        Qt.Key_Home, Qt.Key_End
                                    ]
                                    
                                    if (!allowedKeys.includes(event.key)) {
                                        event.accepted = false
                                    } else if (event.key === Qt.Key_Period) {
                                        // Convertir punto a coma
                                        event.accepted = false
                                        insert(text.length, ',')
                                    }
                                }
                            }
                            
                            // ✅ Label de validación
                            Label {
                                id: montoValidationLabel
                                text: "⚠️ Ingresa un monto válido mayor a 0"
                                font.pixelSize: fontTiny
                                color: dangerColor
                                visible: false
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
                                font.pixelSize: fontInput // Reducido
                            }
                            
                            TextField {
                                id: fechaGastoField
                                width: parent.width
                                height: 40
                                placeholderText: "YYYY-MM-DD"
                                text: Qt.formatDate(new Date(), "yyyy-MM-dd")
                                inputMethodHints: Qt.ImhDate  
                                font.pixelSize: fontInput // Reducido

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
                            
                            RowLayout {
                                width: parent.width
                                spacing: 8
                                
                                Label {
                                    text: "Proveedor:"
                                    font.bold: true
                                    color: textColor
                                    font.pixelSize: fontInput
                                }
                                
                                Label {
                                    text: "(opcional)"
                                    font.pixelSize: fontTiny
                                    color: "#7f8c8d"
                                    font.italic: true
                                }
                                
                                Item { Layout.fillWidth: true }
                                
                                // ✅ BOTÓN PARA CREAR NUEVO PROVEEDOR
                                Button {
                                    Layout.preferredWidth: 120
                                    Layout.preferredHeight: 28
                                    
                                    background: Rectangle {
                                        color: parent.pressed ? Qt.darker(successColor, 1.1) : successColor
                                        radius: 6
                                    }
                                    
                                    contentItem: RowLayout {
                                        spacing: 6
                                        
                                        Label {
                                            text: "+"
                                            color: "white"
                                            font.pixelSize: 14
                                            font.bold: true
                                        }
                                        
                                        Label {
                                            text: "Nuevo"
                                            color: "white"
                                            font.pixelSize: 11
                                            font.bold: true
                                        }
                                    }
                                    
                                    onClicked: {
                                        dialogoNuevoProveedor.open()
                                    }
                                }
                            }
                            
                            // ComboBox simplificado
                            ProveedorComboBox {
                                id: proveedorComboBox
                                width: parent.width
                                height: 45
                                
                                // ✅ FIX: Convertir ListModel a Array
                                proveedoresModel: {
                                    try {
                                        if (!proveedoresGastosModel || proveedoresGastosModel.count === undefined) {
                                            console.log("⚠️ proveedoresGastosModel no disponible")
                                            return []
                                        }
                                        
                                        var array = []
                                        for (var i = 0; i < proveedoresGastosModel.count; i++) {
                                            array.push(proveedoresGastosModel.get(i))
                                        }
                                        
                                        // console.log("📦 Proveedores convertidos a array:", array.length)
                                        return array
                                    } catch (e) {
                                        console.log("❌ Error convirtiendo proveedores a array:", e)
                                        return []
                                    }
                                }
                                
                                // ✅ PROPERTY WATCHER para depuración
                                onProveedoresModelChanged: {
                                    console.log("🔄 ProveedorComboBox.proveedoresModel cambiado, longitud:", proveedoresModel.length)
                                }
                                
                                onProveedorCambiado: function(proveedor, proveedorId) {
                                    gastoForm.selectedProveedorId = String(proveedorId)
                                    console.log("🏢 Proveedor seleccionado:", proveedor, "ID:", proveedorId, "Tipo:", typeof proveedorId)
                                }
                                
                                onNuevoProveedorCreado: function(nombreProveedor) {
                                    console.log("🆕 Creando nuevo proveedor:", nombreProveedor)
                                    crearNuevoProveedorGasto(nombreProveedor)
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
                                font.pixelSize: fontInput // Reducido
                            }
                            
                            TextArea {
                                id: descripcionField
                                width: parent.width
                                height: 100
                                font.pixelSize: fontInput // Reducido
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
                Layout.preferredHeight: 20
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
                        font.pixelSize: fontButton // Reducido
                        
                        background: Rectangle {
                            color: cancelButton.pressed ? "#e0e0e0" : "#f8f9fa"
                            border.color: "#ddd"
                            border.width: 1
                            radius: 5
                        }
                        
                        contentItem: Label {
                            text: parent.text
                            font.pixelSize: fontButton // Reducido
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
                        font.pixelSize: fontButton
                        
                        enabled: {
                            // Validaciones base
                            var tipoValido = gastoForm.selectedTipoGastoIndex >= 0
                            var montoValido = montoField.text.length > 0 && parseFloat(montoField.text) > 0
                            var fechaValida = fechaGastoField.text.length >= 10
                            
                            // Validación condicional de descripción
                            var tieneProveedor = proveedorComboBox.selectedId > 0
                            var descripcionValida = tieneProveedor ? 
                                descripcionField.text.trim().length > 0 :
                                descripcionField.text.trim().length >= 10
                            
                            return tipoValido && montoValido && fechaValida && descripcionValida
                        }
                        
                        background: Rectangle {
                            color: !saveButton.enabled ? "#bdc3c7" : 
                                (saveButton.pressed ? Qt.darker(primaryColor, 1.1) : primaryColor)
                            radius: 5
                            
                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }
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

                            // ✅ PARSEO MEJORADO - USAR TEXTO NORMALIZADO
                            var montoTexto = montoField.text.replace(/,/g, '.')
                            var montoNumero = parseFloat(montoTexto)

                            if (isNaN(montoNumero) || montoNumero <= 0) {
                                showErrorMessage("Error de validación", "El monto debe ser un número válido mayor a 0")
                                return
                            }

                            // Resto del código sin cambios...
                            if (!fechaGastoField.text || fechaGastoField.text.length < 10) {
                                showErrorMessage("Error de validación", "Ingresa una fecha válida (YYYY-MM-DD)")
                                return
                            }

                            // Obtener ID del proveedor seleccionado
                            var proveedorId = parseInt(gastoForm.selectedProveedorId || "0")

                            // Validación condicional de descripción
                            if (proveedorId === 0 && descripcionField.text.trim().length < 10) {
                                showErrorMessage(
                                    "Validación requerida",
                                    "Si no hay proveedor, la descripción debe tener al menos 10 caracteres"
                                )
                                return
                            }

                            var gastoData = {
                                descripcion: descripcionField.text.trim(),
                                monto: montoNumero.toFixed(2),  // ✅ Usar el valor parseado y formateado
                                fechaGasto: fechaGastoField.text
                            }

                            console.log("📝 Enviando datos del formulario:", JSON.stringify(gastoData))
                            console.log("💰 Monto procesado:", montoNumero.toFixed(2))
                            console.log("🏢 Proveedor ID:", proveedorId)

                            var success = false

                            if (isEditMode && editingGastoData) {
                                success = actualizarGastoDirecto(editingGastoData.gastoId, gastoData, proveedorId)
                            } else {
                                success = crearGastoDirecto(gastoData, proveedorId)
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
            if (visible && isEditMode && editingGastoData) {
                console.log("✏️ Cargando datos para edición:", JSON.stringify(editingGastoData))
                
                // Cargar tipo de gasto
                var tipoGastoNombre = editingGastoData.tipoGasto
                for (var i = 0; i < tiposGastosModel.count; i++) {
                    if (tiposGastosModel.get(i).nombre === tipoGastoNombre) {
                        tipoGastoCombo.currentIndex = i + 1
                        gastoForm.selectedTipoGastoIndex = i
                        console.log("🏷️ Tipo de gasto cargado:", tipoGastoNombre, "índice:", i)
                        break
                    }
                }
                
                // ✅ CORRECCIÓN: Cargar proveedor - COMPARAR MEJOR
                var proveedorNombre = editingGastoData.proveedor
                console.log("🏢 Buscando proveedor para edición:", proveedorNombre)
                
                if (proveedorNombre && proveedorNombre !== "Sin proveedor" && proveedorNombre !== "Ninguno") {
                    console.log("🔍 Buscando proveedor en modelo:", proveedorNombre)
                    
                    // Buscar el proveedor por nombre en el modelo
                    for (var j = 0; j < proveedoresGastosModel.count; j++) {
                        var prov = proveedoresGastosModel.get(j)
                        if (prov && prov.nombre === proveedorNombre) {
                            console.log("✅ Proveedor encontrado:", prov.nombre, "ID:", prov.id)
                            // ✅ LLAMAR A setProveedorById CON RETRASO PARA ASEGURAR QUE EL COMBOBOX ESTÉ LISTO
                            Qt.callLater(function() {
                                proveedorComboBox.setProveedorById(prov.id)
                            })
                            gastoForm.selectedProveedorId = String(prov.id)
                            break
                        }
                    }
                } else {
                    // ✅ CORRECCIÓN: Si es "Ninguno", usar ID 1, no 0
                    if (proveedorNombre === "Ninguno") {
                        console.log("🏢 Usando proveedor 'Ninguno' (ID: 1)")
                        Qt.callLater(function() {
                            proveedorComboBox.setProveedorById(1)
                        })
                        gastoForm.selectedProveedorId = "1"
                    } else {
                        console.log("🏢 Sin proveedor (ID: 0)")
                        Qt.callLater(function() {
                            proveedorComboBox.reset()
                        })
                        gastoForm.selectedProveedorId = "0"
                    }
                }
                
                // Cargar resto de campos
                descripcionField.text = editingGastoData.descripcion || ""
                
                // ✅ CORRECCIÓN: Convertir mato a formato válido
                var montoValor = parseFloat(editingGastoData.monto || 0)
                montoField.text = montoValor.toFixed(2).replace('.', ',')
                console.log("💰 Monto cargado:", montoValor, "->", montoField.text)
                
                // ✅ CORRECCIÓN: Formato de fecha
                if (editingGastoData.fechaGasto) {
                    var fechaStr = String(editingGastoData.fechaGasto)
                    if (fechaStr.includes(' ')) {
                        fechaGastoField.text = fechaStr.split(' ')[0]
                    } else {
                        fechaGastoField.text = fechaStr
                    }
                    console.log("📅 Fecha cargada:", editingGastoData.fechaGasto, "->", fechaGastoField.text)
                } else {
                    fechaGastoField.text = Qt.formatDate(new Date(), "yyyy-MM-dd")
                }
                
            } else if (visible && !isEditMode) {
                // Limpiar formulario
                tipoGastoCombo.currentIndex = 0
                Qt.callLater(function() {
                    proveedorComboBox.reset()
                })
                descripcionField.text = ""
                montoField.text = ""
                fechaGastoField.text = Qt.formatDate(new Date(), "yyyy-MM-dd")
                gastoForm.selectedTipoGastoIndex = -1
                gastoForm.selectedProveedorId = "0"
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
                            font.pixelSize: fontLarge // Reducido
                        }
                    }
                    
                    ColumnLayout {
                        spacing: marginSmall * 0.25
                        
                        Label {
                            text: "Confirmar Eliminación"
                            font.pixelSize: fontLarge // Reducido
                            font.bold: true
                            color: "#dc2626"
                            Layout.alignment: Qt.AlignLeft
                        }
                        
                        Label {
                            text: "Acción irreversible"
                            font.pixelSize: fontSmall // Reducido
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
                        font.pixelSize: fontMedium // Reducido
                        font.bold: true
                        color: textColor
                        Layout.alignment: Qt.AlignHCenter
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                    
                    Label {
                        text: "Esta acción no se puede deshacer y el registro se eliminará permanentemente."
                        font.pixelSize: fontBase // Reducido
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
                            font.pixelSize: fontBase // Reducido
                            
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
                                    font.pixelSize: fontSmall // Reducido
                                    Layout.alignment: Qt.AlignVCenter
                                }
                                
                                Label {
                                    text: "Cancelar"
                                    color: "#374151"
                                    font.bold: true
                                    font.pixelSize: fontBase // Reducido
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
                            font.pixelSize: fontBase // Reducido
                            
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
                                    font.pixelSize: fontSmall // Reducido
                                    Layout.alignment: Qt.AlignVCenter
                                }
                                
                                Label {
                                    text: "Eliminar"
                                    color: whiteColor
                                    font.bold: true
                                    font.pixelSize: fontBase // Reducido
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
                font.pixelSize: fontLarge // Reducido
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
            font.pixelSize: fontBase // Reducido
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
                font.pixelSize: fontLarge // Reducido
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
                    font.pixelSize: fontBase // Reducido
                    color: textColor
                }
            }
            
            Button {
                text: "Cerrar"
                Layout.alignment: Qt.AlignHCenter
                font.pixelSize: fontBase // Reducido
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

    Dialog {
        id: dialogoNuevoProveedor
        anchors.centerIn: parent
        width: Math.min(380, parent.width * 0.65)
        height: Math.min(300, parent.height * 0.45)
        modal: true
        title: ""
        
        background: Rectangle {
            color: whiteColor
            radius: 14
            border.color: "#E5E7EB"
            border.width: 1
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 0
            spacing: 0
            
            // Header mejorado
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 65
                color: successColor
                radius: 14
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 12
                    
                    Label {
                        text: "🏢"
                        font.pixelSize: 28
                    }
                    
                    Column {
                        Layout.fillWidth: true
                        spacing: 3
                        
                        Label {
                            text: "Nuevo Proveedor"
                            font.pixelSize: 16
                            font.bold: true
                            color: whiteColor
                        }
                        
                        Label {
                            text: "Agrega un nuevo proveedor de servicios"
                            font.pixelSize: 11
                            color: "#F0F9FF"
                            opacity: 0.9
                        }
                    }
                    
                    Button {
                        Layout.alignment: Qt.AlignRight | Qt.AlignTop
                        width: 36
                        height: 36
                        text: "✕"
                        
                        background: Rectangle {
                            color: "transparent"
                            radius: 8
                        }
                        
                        contentItem: Label {
                            text: parent.text
                            color: whiteColor
                            font.pixelSize: 20
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: dialogoNuevoProveedor.close()
                        
                        HoverHandler {
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                }
            }
            
            // Contenido
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 25
                spacing: 18
                
                Column {
                    Layout.fillWidth: true
                    spacing: 10
                    
                    Label {
                        text: "Nombre del Proveedor *"
                        font.bold: true
                        font.pixelSize: 13
                        color: textColor
                    }
                    
                    TextField {
                        id: nuevoProvNombre
                        width: parent.width
                        height: 44
                        placeholderText: "Ej: Empresa Eléctrica, Agua Potable..."
                        font.pixelSize: 12
                        
                        background: Rectangle {
                            color: "#F9FAFB"
                            border.color: nuevoProvNombre.activeFocus ? primaryColor : "#E5E7EB"
                            border.width: 2
                            radius: 8
                        }
                        
                        onTextChanged: {
                            validationMessage.visible = text.length > 0 && text.length < 3
                        }
                        
                        Keys.onReturnPressed: {
                            if (nuevoProvNombre.text.trim().length >= 3) {
                                crearProveedorAction()
                            }
                        }
                    }
                }
                
                Label {
                    id: validationMessage
                    text: "⚠️ Mínimo 3 caracteres"
                    font.pixelSize: 11
                    color: dangerColor
                    visible: false
                }
                
                Item { Layout.fillHeight: true }
            }
            
            // Botones
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 70
                color: "#F9FAFB"
                radius: 14
                
                RowLayout {
                    anchors.centerIn: parent
                    anchors.margins: 15
                    spacing: 12
                    
                    Button {
                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 40
                        text: "Cancelar"
                        
                        background: Rectangle {
                            color: "#F3F4F6"
                            radius: 8
                            border.color: "#D1D5DB"
                            border.width: 1
                        }
                        
                        contentItem: Label {
                            text: parent.text
                            color: textColor
                            font.pixelSize: 12
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: {
                            nuevoProvNombre.text = ""
                            dialogoNuevoProveedor.close()
                        }
                        
                        HoverHandler {
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                    
                    Button {
                        id: crearProvButton
                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 40
                        text: "Crear"
                        enabled: nuevoProvNombre.text.trim().length >= 3
                        
                        background: Rectangle {
                            color: parent.enabled ? 
                                (parent.hovered ? Qt.darker(successColor, 1.05) : successColor) : 
                                "#D1D5DB"
                            radius: 8
                        }
                        
                        contentItem: Label {
                            text: parent.text
                            color: whiteColor
                            font.pixelSize: 12
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: crearProveedorAction()
                        
                        HoverHandler {
                            cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        }
                    }
                }
            }
        }
        
        onOpened: {
            nuevoProvNombre.focus = true
            nuevoProvNombre.text = ""
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
            console.log("❌ Error en eliminacion: -- ", error.message)
            //mostrarNotificacion("Error", "Error eliminando gasto: " + error.message)
            return false
        }
    }
    function mostrarNotificacion(titulo, mensaje) {
        console.log("📢 " + titulo + ": " + mensaje)
    }
    
    Component.onCompleted: {
        console.log("=== INICIALIZANDO SERVICIOS BÁSICOS ===")
        
        // ✅ PASO 1: Esperar a que gastoModelInstance esté disponible
        var intentos = 0
        var timer = null
        
        function verificarGastoModel() {
            intentos++
            console.log("Intento", intentos, "- GastoModel disponible?", gastoModelInstance ? "✅ SÍ" : "❌ NO")
            
            if (gastoModelInstance) {
                console.log("✅ GastoModel encontrado")
                
                // ✅ PASO 2: Cargar tipos de gastos
                if (typeof loadTiposGastosFromModel === 'function') {
                    loadTiposGastosFromModel()
                    console.log("✅ Tipos de gastos cargados")
                }
                
                // ✅ PASO 3: Cargar proveedores de gastos
                if (typeof loadProveedoresGastosFromModel === 'function') {
                    loadProveedoresGastosFromModel()
                    console.log("✅ Proveedores cargados")
                } else {
                    console.log("⚠️ loadProveedoresGastosFromModel no está definida")
                }
                
                // ✅ PASO 4: Cargar datos de gastos con pequeño delay
                Qt.callLater(function() {
                    if (typeof cargarPaginaDesdeBD === 'function') {
                        cargarPaginaDesdeBD()
                        console.log("✅ Gastos cargados")
                    }
                }, 200)
                
                // Detener timer
                if (timer) timer.stop()
            } else if (intentos < 10) {
                // Reintentar
                if (!timer) {
                    timer = Qt.createQmlObject("import QtQuick 2.15; Timer { interval: 100; repeat: true }", serviciosBasicosRoot)
                    timer.triggered.connect(verificarGastoModel)
                }
                if (!timer.running) timer.start()
            } else {
                console.log("❌ GastoModel no se encontró después de 10 intentos")
                if (timer) timer.stop()
            }
        }
        
        // Iniciar verificación
        verificarGastoModel()
        
        console.log("=== FIN INICIALIZACIÓN ===")
    }
    // Agregar después del Component.onCompleted:
    onCurrentSubsectionChanged: {
        console.log("📋 Cambiando a subsección:", subsectionTitles[currentSubsection])
        // Aquí puedes cargar datos específicos según la subsección
    }

    function loadProveedoresGastosFromModel() {
        if (!gastoModelInstance) {
            console.log("⚠️ GastoModel no disponible")
            return
        }
        
        console.log("🏢 Cargando proveedores de gastos...")
        
        try {
            // ✅ LLAMAR AL SLOT REGISTRADO
            var proveedores = gastoModelInstance.obtenerProveedoresGastosParaComboBox()
            console.log("📊 Proveedores obtenidos del backend:", proveedores ? proveedores.length : 0)
            
            // ✅ VALIDAR QUE SEA UN ARRAY
            if (!Array.isArray(proveedores)) {
                console.log("⚠️ proveedores no es array, intentando convertir")
                if (proveedores && typeof proveedores === 'object') {
                    proveedores = Object.values(proveedores)
                } else {
                    proveedores = []
                }
            }
            
            // ✅ LIMPIAR Y POBLAR EL MODELO
            proveedoresGastosModel.clear()
            
            if (proveedores && proveedores.length > 0) {
                for (var i = 0; i < proveedores.length; i++) {
                    var prov = proveedores[i]
                    if (prov && prov.id !== undefined) {
                        proveedoresGastosModel.append({
                            id: parseInt(prov.id || 0),
                            nombre: String(prov.nombre || prov.Nombre || "Sin nombre"),
                            displayText: String(prov.display_text || prov.displayText || prov.nombre || "Sin nombre")
                        })
                        console.log("✅ Proveedor agregado:", prov.nombre, "ID:", prov.id)
                    }
                }
            } else {
                console.log("⚠️ No hay proveedores, agregando proveedor por defecto")
                proveedoresGastosModel.append({
                    id: 0,
                    nombre: "Sin proveedor",
                    displayText: "Sin proveedor"
                })
            }
            
            console.log("✅ Proveedores cargados en modelo:", proveedoresGastosModel.count)
            
            // ✅ ACTUALIZAR COMBOBOX SI EXISTE
            if (typeof proveedorComboBox !== 'undefined' && proveedorComboBox) {
                Qt.callLater(function() {
                    var proveedoresArray = []
                    for (var j = 0; j < proveedoresGastosModel.count; j++) {
                        var p = proveedoresGastosModel.get(j)
                        if (p) proveedoresArray.push(p)
                    }
                    proveedorComboBox.proveedoresModel = proveedoresArray
                    console.log("🔄 ProveedorComboBox actualizado con", proveedoresArray.length, "proveedores")
                })
            }
            
        } catch (error) {
            console.log("❌ Error cargando proveedores:", error)
        }
    }

    function buscarProveedorGasto(termino) {
        if (!gastoModelInstance) return
        
        if (!termino || termino.length < 2) {
            loadProveedoresGastosFromModel()
            return
        }
        
        var resultados = gastoModelInstance.buscarProveedorGasto(termino)
        
        proveedoresGastosModel.clear()
        for (var i = 0; i < resultados.length; i++) {
            var prov = resultados[i]
            proveedoresGastosModel.append({
                id: prov.id,
                nombre: prov.nombre,
                displayText: prov.display_text,
                usoFrecuencia: prov.uso_frecuencia
                // ✅ ELIMINADOS: telefono, direccion
            })
        }
    }

    // En el Connections para el ProveedorComboBox:
    Connections {
        target: proveedorComboBox
        
        function onNuevoProveedorCreado(nombreProveedor) {
            console.log("📱 Señal: Crear nuevo proveedor:", nombreProveedor)
            crearNuevoProveedorGasto(nombreProveedor)
        }
    }

    // En la función crearNuevoProveedorGasto, AGREGAR validación de existencia:
    function crearNuevoProveedorGasto(nombre) {
        if (!gastoModelInstance) {
            console.log("❌ GastoModel no disponible")
            return
        }
        
        if (!nombre || nombre.length < 3) {
            showErrorMessage("Error", "El nombre del proveedor debe tener al menos 3 caracteres")
            return
        }
        
        console.log("🏢 Verificando si proveedor ya existe:", nombre)
        
        // ✅ PRIMERO VERIFICAR SI YA EXISTE
        var existe = gastoModelInstance.proveedorGastoExiste(nombre)
        if (existe) {
            console.log("⚠️ Proveedor ya existe:", nombre)
            showErrorMessage("Error", `El proveedor "${nombre}" ya existe`)
            return
        }
        
        console.log("🏢 Creando proveedor:", nombre)
        
        // Llamar al modelo para crear proveedor
        var proveedorId = gastoModelInstance.crearProveedorGasto(nombre)
        
        console.log("✅ Proveedor creado con ID:", proveedorId)
        
        if (proveedorId > 0) {
            // ✅ FORZAR RECARGA INMEDIATA
            Qt.callLater(function() {
                console.log("🔄 Recargando proveedores...")
                loadProveedoresGastosFromModel()
                
                // ✅ SELECCIONAR EL PROVEEDOR CREADO
                Qt.callLater(function() {
                    if (proveedorComboBox && typeof proveedorComboBox.setProveedorById === 'function') {
                        proveedorComboBox.setProveedorById(proveedorId)
                        console.log("✅ Proveedor seleccionado automáticamente:", proveedorId)
                    }
                    showSuccessMessage("Proveedor '" + nombre + "' creado exitosamente")
                }, 300)
            }, 100)
        } else {
            showErrorMessage("Error", "No se pudo crear el proveedor")
        }
    }

    function crearProveedorAction() {
        var nombre = nuevoProvNombre.text.trim()
        
        if (nombre.length < 3) {
            showErrorMessage("Error", "El nombre debe tener al menos 3 caracteres")
            return
        }
        
        console.log("🏢 Creando proveedor:", nombre)
        var proveedorId = gastoModelInstance.crearProveedorGasto(nombre)
        
        if (proveedorId > 0) {
            console.log("✅ Proveedor creado ID:", proveedorId)
            
            // Limpiar y cerrar inmediatamente
            nuevoProvNombre.text = ""
            dialogoNuevoProveedor.close()
            
            // Actualizar lista
            Qt.callLater(function() {
                loadProveedoresGastosFromModel()
                
                Qt.callLater(function() {
                    if (proveedorComboBox && typeof proveedorComboBox.setProveedorById === 'function') {
                        proveedorComboBox.setProveedorById(proveedorId)
                    }
                    showSuccessMessage("✅ Proveedor '" + nombre + "' creado")
                }, 300)
            }, 100)
        } else {
            showErrorMessage("Error", "No se pudo crear el proveedor")
        }
    }
}