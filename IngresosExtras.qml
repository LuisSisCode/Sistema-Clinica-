import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: ingresosExtrasRoot
    
    // SISTEMA DE ESTILOS ADAPTABLES
    readonly property real screenWidth: width
    readonly property real screenHeight: height
    readonly property real baseUnit: Math.min(screenWidth, screenHeight) / 40
    readonly property real fontScale: Math.max(0.8, screenHeight / 900)

    // Márgenes escalables
    readonly property real marginSmall: baseUnit * 0.5
    readonly property real marginMedium: baseUnit * 1
    readonly property real marginLarge: baseUnit * 1.5

    // TAMAÑOS DE FUENTE AJUSTADOS
    readonly property real fontTiny: Math.max(10, 11 * fontScale)
    readonly property real fontSmall: Math.max(11, 13 * fontScale)
    readonly property real fontBase: Math.max(13, 15 * fontScale)
    readonly property real fontMedium: Math.max(15, 17 * fontScale)
    readonly property real fontLarge: Math.max(17, 19 * fontScale)
    readonly property real fontTitle: Math.max(20, 25 * fontScale)
    readonly property real fontHeader: Math.max(14, 16 * fontScale)
    readonly property real fontButton: Math.max(12, 14 * fontScale)
    readonly property real fontInput: Math.max(12, 14 * fontScale)
    
    // PROPIEDADES DE COLOR
    readonly property color primaryColor: "#3498db"
    readonly property color successColor: "#10B981"
    readonly property color dangerColor: "#E74C3C"
    readonly property color warningColor: "#F59E0B"
    readonly property color lightGrayColor: "#F8F9FA"
    readonly property color textColor: "#2c3e50"
    readonly property color textColorLight: "#6B7280"
    readonly property color whiteColor: "#FFFFFF"
    readonly property color borderColor: "#E5E7EB"
    readonly property color lineColor: "#D1D5DB"
    
    // Distribución de columnas
    readonly property real colID: 0.08
    readonly property real colDescripcion: 0.35
    readonly property real colMonto: 0.15
    readonly property real colFecha: 0.15
    readonly property real colRegistradoPor: 0.20
    readonly property real colAcciones: 0.07
    
    // Propiedades de paginación y edición
    property int itemsPerPage: 10
    property int currentPage: 0
    property int totalPages: 1
    property int selectedRowIndex: -1
    property bool isEditMode: false
    property int editingIndex: -1
    property int editingId: -1
    property bool showConfirmDeleteDialog: false
    property int deleteIndex: -1
    property int deleteId: -1
    
    // Propiedades para filtros
    property int filtroMesActual: 0
    property int filtroAnioActual: 0
    
    // Estados de carga
    property bool loading: false
    property bool hasError: false
    property string errorMessage: ""
    
    // Modelo paginado desde base de datos
    ListModel {
        id: ingresosPaginadosModel
    }
    
    // Referencia al modelo de backend
    property var backendModel: appController ? appController.ingreso_extra_model_instance : null
    
    // Conexión con señales del backend
    Connections {
        target: backendModel
        enabled: backendModel !== null  // ✅ AGREGADO
        
        function onIngresoExtraAgregado() {
            console.log("✅ Ingreso extra agregado - actualizando vista")
            aplicarFiltros()
            limpiarFormulario()
            nuevoIngresoDialog.close()
            loading = false
        }
        
        function onIngresoExtraActualizado() {
            console.log("✅ Ingreso extra actualizado - actualizando vista")
            aplicarFiltros()
            limpiarFormulario()
            nuevoIngresoDialog.close()
            loading = false
        }
        
        function onIngresoExtraEliminado() {
            console.log("✅ Ingreso extra eliminado - actualizando vista")
            aplicarFiltros()
            showConfirmDeleteDialog = false
            deleteId = -1
            loading = false
        }
        
        function onErrorOcurrido(mensaje) {
            console.log("❌ Error en modelo:", mensaje)
            errorMessage = mensaje
            hasError = true
            loading = false
            showNotification("Error", mensaje)
        }
        
        function onIngresosActualizados() {
            console.log("📊 Ingresos actualizados desde backend")
            updatePaginatedModel()
        }
    }
    
    function updatePaginatedModel() {
        if (!backendModel) {
            console.warn("❌ Backend model no disponible")
            errorMessage = "Sistema de ingresos no disponible"
            hasError = true
            return
        }
        
        loading = true
        hasError = false  // ✅ AGREGADO
        
        try {
            // Obtener datos paginados del backend
            var datos = backendModel.obtener_ingresos_extras_paginados(currentPage, itemsPerPage)
            
            console.log("📊 Datos obtenidos:", datos.length, "registros")
            
            ingresosPaginadosModel.clear()
            
            for (var i = 0; i < datos.length; i++) {
                var item = datos[i]
                
                // Aplicar filtros locales si están activos
                if (!pasaFiltros(item)) {
                    continue
                }
                
                ingresosPaginadosModel.append({
                    id_registro: item.id,
                    descripcion: item.descripcion,
                    monto: parseFloat(item.monto),
                    fecha: item.fecha,
                    registradoPor: item.registradoPor,
                    originalIndex: i
                })
            }
            
            // Calcular total de páginas
            var totalItems = backendModel.contar_ingresos_extras(filtroMesActual, filtroAnioActual)
            totalPages = Math.max(1, Math.ceil(totalItems / itemsPerPage))
            
            console.log("✅ Modelo actualizado:", ingresosPaginadosModel.count, "items visibles de", totalItems, "total")
            
            loading = false
            
        } catch (error) {
            console.error("❌ Error actualizando modelo paginado:", error)
            errorMessage = "Error al cargar datos: " + error
            hasError = true
            loading = false
        }
    }
    
    function pasaFiltros(item) {
        if (filtroMesActual === 0 && filtroAnioActual === 0) {
            return true
        }
        
        try {
            var fechaItem = new Date(item.fecha)
            var mesItem = fechaItem.getMonth() + 1
            var anioItem = fechaItem.getFullYear()
            
            if (filtroMesActual > 0 && mesItem !== filtroMesActual) {
                return false
            }
            
            if (filtroAnioActual > 0 && anioItem !== filtroAnioActual) {
                return false
            }
            
            return true
        } catch (error) {
            console.warn("⚠️ Error procesando fecha del item:", error)
            return true // En caso de error, mostrar el item
        }
    }
    
    function contarIngresosFiltrados() {
        if (!backendModel) return 0
        
        try {
            return backendModel.contar_ingresos_extras(filtroMesActual, filtroAnioActual)
        } catch (error) {
            console.error("❌ Error contando ingresos:", error)
            return 0
        }
    }
    
    function aplicarFiltros() {
        currentPage = 0
        
        if (filtroMesActual > 0 || filtroAnioActual > 0) {
            // Usar filtros del backend para mejor rendimiento
            cargarDatosFiltrados()
        } else {
            updatePaginatedModel()
        }
    }
    
    function cargarDatosFiltrados() {
        if (!backendModel) return
        
        loading = true
        
        try {
            var datos = backendModel.obtener_ingresos_extras_filtrados(
                filtroMesActual, filtroAnioActual, currentPage, itemsPerPage
            )
            
            ingresosPaginadosModel.clear()
            
            for (var i = 0; i < datos.length; i++) {
                var item = datos[i]
                
                ingresosPaginadosModel.append({
                    id_registro: item.id,
                    descripcion: item.descripcion,
                    monto: parseFloat(item.monto),
                    fecha: item.fecha,
                    registradoPor: item.registradoPor,
                    originalIndex: i
                })
            }
            
            var totalItems = backendModel.contar_ingresos_extras(filtroMesActual, filtroAnioActual)
            totalPages = Math.max(1, Math.ceil(totalItems / itemsPerPage))
            
            loading = false
            
        } catch (error) {
            console.error("❌ Error cargando datos filtrados:", error)
            errorMessage = "Error al aplicar filtros: " + error
            hasError = true
            loading = false
        }
    }
    
    function limpiarFiltros() {
        mesCombo.currentIndex = 0
        anioCombo.currentIndex = 0
        filtroMesActual = 0
        filtroAnioActual = 0
        currentPage = 0
        updatePaginatedModel()
    }
    
    function editarIngreso(paginatedIndex) {
        var item = ingresosPaginadosModel.get(paginatedIndex)
        
        isEditMode = true
        editingId = item.id_registro
        
        txtDescripcion.text = item.descripcion
        txtMonto.text = item.monto.toString()
        txtFecha.text = item.fecha
        
        nuevoIngresoDialog.open()
    }
    
    function eliminarIngreso(paginatedIndex) {
        var item = ingresosPaginadosModel.get(paginatedIndex)
        deleteId = item.id_registro
        showConfirmDeleteDialog = true
    }
    
    function guardarIngreso() {
        // Validar descripción
        if (!txtDescripcion.text || txtDescripcion.text.trim() === "") {
            showNotification("Error", "La descripción es obligatoria")
            return
        }
        
        // Validar monto vacío
        if (!txtMonto.text || txtMonto.text.trim() === "") {
            showNotification("Error", "El monto es obligatorio")
            return
        }
        
        // ✅ CORREGIDO: Usar función de parseo seguro
        console.log("📝 Texto del monto ingresado:", txtMonto.text)
        
        var monto = parsearMonto(txtMonto.text)
        
        console.log("💰 Monto parseado:", monto)
        
        // Validar que el monto sea válido
        if (isNaN(monto) || monto <= 0) {
            showNotification("Error", "El monto debe ser un número válido mayor a 0")
            console.error("❌ Monto inválido:", txtMonto.text, "→", monto)
            return
        }
        
        // Validar monto máximo razonable (opcional)
        if (monto > 1000000) {
            showNotification("Advertencia", "El monto parece muy alto. ¿Es correcto?")
            // Opcional: podríamos pedir confirmación aquí
        }
        
        if (!backendModel) {
            showNotification("Error", "Sistema no disponible")
            return
        }
        
        loading = true
        
        console.log("📤 Enviando al backend:")
        console.log("   Descripción:", txtDescripcion.text)
        console.log("   Monto:", monto)
        console.log("   Fecha:", txtFecha.text)
        
        if (isEditMode) {
            // Actualizar ingreso existente
            console.log("✏️ Actualizando ingreso ID:", editingId)
            var success = backendModel.actualizar_ingreso_extra(
                editingId, 
                txtDescripcion.text, 
                monto, 
                txtFecha.text
            )
            
            if (!success) {
                // El error se manejará en la señal onErrorOcurrido
                return
            }
        } else {
            // Crear nuevo ingreso
            console.log("➕ Creando nuevo ingreso")
            var success = backendModel.agregar_ingreso_extra(
                txtDescripcion.text, 
                monto, 
                txtFecha.text
            )
            
            if (!success) {
                // El error se manejará en la señal onErrorOcurrido
                return
            }
        }
        
        // El cierre del diálogo y limpieza se hará en las señales
    }
    
    function confirmarEliminacion() {
        if (!backendModel || deleteId === -1) {
            showNotification("Error", "No se puede eliminar el ingreso")
            return
        }
        
        loading = true
        
        var success = backendModel.eliminar_ingreso_extra(deleteId)
        
        if (!success) {
            // El error se manejará en la señal onErrorOcurrido
            return
        }
        
        showConfirmDeleteDialog = false
        deleteId = -1
    }
    
    function limpiarFormulario() {
        txtDescripcion.text = ""
        txtMonto.text = ""
        txtFecha.text = Qt.formatDateTime(new Date(), "yyyy-MM-dd hh:mm:ss")
        isEditMode = false
        editingId = -1
        editingIndex = -1
    }
    
    function showNotification(titulo, mensaje) {
        if (appController && typeof appController.showNotification === "function") {
            appController.showNotification(titulo, mensaje)
        } else {
            console.log("📢 " + titulo + ": " + mensaje)
        }
    }
    
    function verificarConexionBackend() {
        console.log("🔍 Verificando disponibilidad del backend...")
        
        if (!appController) {
            console.error("❌ appController no disponible")
            errorMessage = "Sistema principal no disponible"
            hasError = true
            return false
        }
        
        if (!backendModel) {
            console.error("❌ IngresoExtraModel no disponible")
            console.log("   appController existe:", !!appController)
            console.log("   ingreso_extra_model_instance:", appController.ingreso_extra_model_instance)
            errorMessage = "Sistema de ingresos no disponible"
            hasError = true
            return false
        }
        
        console.log("✅ Backend model disponible")
        
        try {
            var conexionOk = backendModel.verificar_conexion()
            if (!conexionOk) {
                errorMessage = "Error de conexión con la base de datos"
                hasError = true
                return false
            }
            
            console.log("✅ Conexión a BD verificada")
            return true
            
        } catch (error) {
            console.error("❌ Error verificando conexión:", error)
            errorMessage = "Error al verificar conexión: " + error
            hasError = true
            return false
        }
    }
    
    Component.onCompleted: {
        console.log("🎯 IngresosExtras QML inicializado")
        
        // Esperar un momento para que el modelo se inicialice completamente
        Qt.callLater(function() {
            if (verificarConexionBackend()) {
                console.log("📊 Cargando datos iniciales...")
                updatePaginatedModel()
            } else {
                console.error("❌ No se pudo verificar la conexión al backend")
            }
        })
    }

    // LAYOUT PRINCIPAL
    Rectangle {
        anchors.fill: parent
        color: whiteColor
        radius: 20
        border.color: "#e0e0e0"
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: marginMedium
            spacing: marginMedium

            // HEADER RESPONSIVO
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
                    
                    RowLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: baseUnit * 1
                        
                        Rectangle {
                            Layout.preferredWidth: baseUnit * 4
                            Layout.preferredHeight: baseUnit * 4
                            color: "transparent"
                            
                            Rectangle {
                                anchors.centerIn: parent
                                width: Math.min(baseUnit * 3.2, parent.width * 0.9)
                                height: Math.min(baseUnit * 3.2, parent.height * 0.9)
                                radius: baseUnit * 0.8
                                color: Qt.lighter(successColor, 1.2)
                                
                                Label {
                                    anchors.centerIn: parent
                                    text: "💰"
                                    font.pixelSize: baseUnit * 1.8
                                }
                            }
                        }
                        
                        ColumnLayout {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: baseUnit * 0.05
                            
                            Label {
                                text: "Gestión de Ingresos Extras"
                                font.pixelSize: fontMedium
                                font.bold: true
                                font.family: "Segoe UI, Arial, sans-serif"
                                color: textColor
                            }
                            
                            Label {
                                text: "Registro y control de ingresos adicionales"
                                font.pixelSize: fontBase
                                font.bold: false
                                font.family: "Segoe UI, Arial, sans-serif"
                                color: textColor
                            }
                        }
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    // Indicador de carga
                    Rectangle {
                        visible: loading
                        Layout.preferredHeight: baseUnit * 2.8
                        Layout.preferredWidth: baseUnit * 10
                        Layout.alignment: Qt.AlignVCenter
                        color: "transparent"
                        
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: marginSmall
                            
                            BusyIndicator {
                                Layout.preferredWidth: baseUnit * 1.5
                                Layout.preferredHeight: baseUnit * 1.5
                                running: loading
                            }
                            
                            Label {
                                text: "Cargando..."
                                color: textColorLight
                                font.pixelSize: fontSmall
                            }
                        }
                    }
                    
                    Rectangle {
                        Layout.preferredHeight: baseUnit * 2.8
                        Layout.preferredWidth: Math.max(baseUnit * 10, implicitWidth + baseUnit * 0.8)
                        Layout.alignment: Qt.AlignVCenter
                        color: successColor
                        radius: baseUnit * 0.6
                        
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                limpiarFormulario()
                                nuevoIngresoDialog.open()
                            }
                            cursorShape: Qt.PointingHandCursor
                            
                            RowLayout {
                                anchors.centerIn: parent
                                spacing: baseUnit * 0.4
                                
                                Label {
                                    text: "+"
                                    color: whiteColor
                                    font.pixelSize: fontBase * 1.2
                                    font.bold: true
                                }
                                
                                Label {
                                    text: "Nuevo Ingreso"
                                    color: whiteColor
                                    font.bold: true
                                    font.pixelSize: fontButton
                                    font.family: "Segoe UI, Arial, sans-serif"
                                }
                            }
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
                    
                    Label {
                        text: "Filtrar por:"
                        font.bold: true
                        color: textColor
                        font.pixelSize: fontBase
                        font.family: "Segoe UI, Arial, sans-serif"
                        Layout.alignment: Qt.AlignVCenter
                    }

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
                        
                        Rectangle {
                            width: Math.max(140, screenWidth * 0.14)
                            height: 40
                            color: whiteColor
                            border.color: borderColor
                            border.width: 1
                            radius: baseUnit * 0.2
                            
                            ComboBox {
                                id: mesCombo
                                anchors.fill: parent
                                anchors.margins: 1
                                font.pixelSize: fontBase
                                model: ["Todos los períodos", "Enero", "Febrero", "Marzo", "Abril", "Mayo", 
                                        "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"]
                                currentIndex: 0
                                
                                onCurrentIndexChanged: {
                                    filtroMesActual = currentIndex
                                    aplicarFiltros()
                                }
                                
                                contentItem: Label {
                                    text: mesCombo.displayText
                                    font.pixelSize: fontBase
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    color: textColor
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: marginSmall
                                }

                                background: Rectangle {
                                    color: "transparent"
                                    border.width: 0
                                }
                            }
                        }
                    }

                    Row {
                        spacing: marginSmall
                        Layout.alignment: Qt.AlignVCenter
                        
                        Label {
                            text: "Año:"
                            font.bold: true
                            font.pixelSize: fontBase
                            color: textColor
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Rectangle {
                            width: Math.max(100, screenWidth * 0.1)
                            height: 40
                            color: whiteColor
                            border.color: borderColor
                            border.width: 1
                            radius: baseUnit * 0.2
                            
                            ComboBox {
                                id: anioCombo
                                anchors.fill: parent
                                anchors.margins: 1
                                font.pixelSize: fontBase
                                model: ["Todos los años", "2025", "2024", "2023"]
                                currentIndex: 0
                                
                                onCurrentIndexChanged: {
                                    if (currentIndex === 0) {
                                        filtroAnioActual = 0
                                    } else {
                                        var textoAnio = model[currentIndex]
                                        filtroAnioActual = parseInt(textoAnio)
                                    }
                                    aplicarFiltros()
                                }
                                
                                contentItem: Label {
                                    text: anioCombo.displayText
                                    font.pixelSize: fontBase
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    color: textColor
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: marginSmall
                                }

                                background: Rectangle {
                                    color: "transparent"
                                    border.width: 0
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: 40
                        color: "#F3F4F6"
                        border.color: "#D1D5DB"
                        border.width: 1
                        radius: baseUnit * 0.2
                        
                        MouseArea {
                            anchors.fill: parent
                            onClicked: limpiarFiltros()
                            cursorShape: Qt.PointingHandCursor
                            
                            Label {
                                anchors.centerIn: parent
                                text: "Limpiar"
                                color: "#374151"
                                font.pixelSize: fontButton
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }
                }
            }

            // CONTENEDOR DE TABLA
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#FFFFFF"
                border.color: "#D5DBDB"
                border.width: 1
                radius: baseUnit * 0.2
                
                ColumnLayout {
                    anchors.fill: parent
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
                                Layout.preferredWidth: parent.width * colID
                                Layout.fillHeight: true
                                color: "transparent"
                                border.color: "#d0d0d0"
                                border.width: 1
                                
                                Label { 
                                    anchors.centerIn: parent
                                    text: "ID"
                                    font.bold: true
                                    font.pixelSize: fontSmall
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    color: textColor
                                }
                            }
                            
                            Rectangle {
                                Layout.preferredWidth: parent.width * colDescripcion
                                Layout.fillHeight: true
                                color: "transparent"
                                border.color: "#d0d0d0"
                                border.width: 1
                                
                                Label { 
                                    anchors.centerIn: parent
                                    text: "DESCRIPCIÓN"
                                    font.bold: true
                                    font.pixelSize: fontSmall
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    color: textColor
                                }
                            }
                            
                            Rectangle {
                                Layout.preferredWidth: parent.width * colMonto
                                Layout.fillHeight: true
                                color: "transparent"
                                border.color: "#d0d0d0"
                                border.width: 1
                                
                                Label { 
                                    anchors.centerIn: parent
                                    text: "MONTO"
                                    font.bold: true
                                    font.pixelSize: fontSmall
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    color: textColor
                                }
                            }
                            
                            Rectangle {
                                Layout.preferredWidth: parent.width * colFecha
                                Layout.fillHeight: true
                                color: "transparent"
                                border.color: "#d0d0d0"
                                border.width: 1
                                
                                Label { 
                                    anchors.centerIn: parent
                                    text: "FECHA"
                                    font.bold: true
                                    font.pixelSize: fontSmall
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    color: textColor
                                }
                            }
                            
                            Rectangle {
                                Layout.preferredWidth: parent.width * colRegistradoPor
                                Layout.fillHeight: true
                                color: "transparent"
                                border.color: "#d0d0d0"
                                border.width: 1
                                
                                Label { 
                                    anchors.centerIn: parent
                                    text: "REGISTRADO POR"
                                    font.bold: true
                                    font.pixelSize: fontSmall
                                    font.family: "Segoe UI, Arial, sans-serif"
                                    color: textColor
                                }
                            }
                            
                            Rectangle {
                                Layout.preferredWidth: parent.width * colAcciones
                                Layout.fillHeight: true
                                color: "transparent"
                                border.color: "#d0d0d0"
                                border.width: 1
                                
                                Label { 
                                    anchors.centerIn: parent
                                    text: "ACCIONES"
                                    font.bold: true
                                    font.pixelSize: fontSmall
                                    font.family: "Segoe UI, Arial, sans-serif"
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
                            id: listView
                            model: ingresosPaginadosModel
                            boundsBehavior: Flickable.StopAtBounds
                            
                            delegate: Rectangle {
                                width: listView.width
                                height: Math.max(45, screenHeight * 0.06)
                                color: {
                                    if (selectedRowIndex === index) return "#e3f2fd"
                                    return index % 2 === 0 ? "transparent" : "#fafafa"
                                }
                                border.color: selectedRowIndex === index ? successColor : "#e8e8e8"
                                border.width: selectedRowIndex === index ? 2 : 1
                                
                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 0
                                    
                                    Rectangle {
                                        Layout.preferredWidth: parent.width * colID
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#d0d0d0"
                                        border.width: 1
                                        
                                        Label { 
                                            anchors.centerIn: parent
                                            text: model.id_registro
                                            color: textColor
                                            font.bold: true
                                            font.pixelSize: fontSmall
                                            font.family: "Segoe UI, Arial, sans-serif"
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: parent.width * colDescripcion
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#d0d0d0"
                                        border.width: 1
                                        
                                        Label { 
                                            anchors.fill: parent
                                            anchors.margins: marginSmall * 0.5
                                            text: model.descripcion
                                            color: textColor
                                            font.pixelSize: fontSmall
                                            font.family: "Segoe UI, Arial, sans-serif"
                                            elide: Text.ElideRight
                                            wrapMode: Text.WordWrap
                                            maximumLineCount: 2
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: parent.width * colMonto
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#d0d0d0"
                                        border.width: 1
                                        
                                        Label { 
                                            anchors.centerIn: parent
                                            text: "Bs " + model.monto.toFixed(2)
                                            color: successColor
                                            font.bold: true
                                            font.pixelSize: fontSmall
                                            font.family: "Segoe UI, Arial, sans-serif"
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: parent.width * colFecha
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#d0d0d0"
                                        border.width: 1
                                        
                                        Label { 
                                            anchors.centerIn: parent
                                            text: model.fecha
                                            color: textColor
                                            font.pixelSize: fontSmall
                                            font.family: "Segoe UI, Arial, sans-serif"
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.preferredWidth: parent.width * colRegistradoPor
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#d0d0d0"
                                        border.width: 1
                                        
                                        Label { 
                                            anchors.fill: parent
                                            anchors.margins: marginSmall * 0.25
                                            text: model.registradoPor
                                            color: textColorLight
                                            font.pixelSize: fontTiny
                                            font.family: "Segoe UI, Arial, sans-serif"
                                            elide: Text.ElideRight
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                    
                                    // COLUMNA DE ACCIONES - SIMPLIFICADA
                                    Rectangle {
                                        Layout.preferredWidth: parent.width * colAcciones
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        border.color: "#d0d0d0"
                                        border.width: 1
                                        
                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: marginSmall * 0.5
                                            
                                            // Botón Editar simplificado
                                            Rectangle {
                                                width: baseUnit * 2.2
                                                height: baseUnit * 2.2
                                                radius: baseUnit * 0.3
                                                color: editarBtnMouseArea.containsMouse ? "#E3F2FD" : "#F0F9FF"
                                                border.color: primaryColor
                                                border.width: 1
                                                
                                                MouseArea {
                                                    id: editarBtnMouseArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: editarIngreso(index)
                                                    
                                                    Label {
                                                        anchors.centerIn: parent
                                                        text: "✏️"
                                                        font.pixelSize: baseUnit * 1
                                                    }
                                                }
                                            }
                                            
                                            // Botón Eliminar simplificado
                                            Rectangle {
                                                width: baseUnit * 2.2
                                                height: baseUnit * 2.2
                                                radius: baseUnit * 0.3
                                                color: eliminarBtnMouseArea.containsMouse ? "#FFEBEE" : "#FEF2F2"
                                                border.color: dangerColor
                                                border.width: 1
                                                
                                                MouseArea {
                                                    id: eliminarBtnMouseArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: eliminarIngreso(index)
                                                    
                                                    Label {
                                                        anchors.centerIn: parent
                                                        text: "🗑️"
                                                        font.pixelSize: baseUnit * 1
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                // MouseArea para seleccionar fila
                                MouseArea {
                                    anchors.fill: parent
                                    propagateComposedEvents: true
                                    onClicked: function(mouse) {
                                        var accionesX = parent.width * (1 - colAcciones)
                                        if (mouse.x < accionesX) {
                                            selectedRowIndex = selectedRowIndex === index ? -1 : index
                                        }
                                        mouse.accepted = false
                                    }
                                }
                            }
                        }
                    }

                    // ESTADO VACÍO
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: ingresosPaginadosModel.count === 0 && !loading && !hasError
                        
                        Column {
                            anchors.centerIn: parent
                            spacing: marginLarge
                            
                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "💰"
                                font.pixelSize: fontTitle * 3
                                color: "#E5E7EB"
                            }
                            
                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "No hay ingresos extras registrados"
                                color: textColor
                                font.bold: true
                                font.pixelSize: fontLarge
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                            
                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Registra el primer ingreso haciendo clic en \"Nuevo Ingreso\""
                                color: textColorLight
                                font.pixelSize: fontBase
                                wrapMode: Text.WordWrap
                                horizontalAlignment: Text.AlignHCenter
                                font.family: "Segoe UI, Arial, sans-serif"
                                width: 400
                            }
                        }
                    }

                    // ESTADO DE ERROR
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: hasError
                        
                        Column {
                            anchors.centerIn: parent
                            spacing: marginLarge
                            
                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "❌"
                                font.pixelSize: fontTitle * 3
                                color: dangerColor
                            }
                            
                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Error al cargar datos"
                                color: textColor
                                font.bold: true
                                font.pixelSize: fontLarge
                                font.family: "Segoe UI, Arial, sans-serif"
                            }
                            
                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: errorMessage
                                color: textColorLight
                                font.pixelSize: fontBase
                                wrapMode: Text.WordWrap
                                horizontalAlignment: Text.AlignHCenter
                                font.family: "Segoe UI, Arial, sans-serif"
                                width: 400
                            }
                            
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 120
                                height: 40
                                color: primaryColor
                                radius: baseUnit * 0.4
                                
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        hasError = false
                                        verificarConexionBackend()
                                        updatePaginatedModel()
                                    }
                                    cursorShape: Qt.PointingHandCursor
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "Reintentar"
                                        color: whiteColor
                                        font.bold: true
                                        font.pixelSize: fontButton
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // PAGINACIÓN
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(50, screenHeight * 0.08)
                color: "#F8F9FA"
                border.color: "#D5DBDB"
                border.width: 1
                radius: baseUnit * 0.2

                RowLayout {
                    anchors.centerIn: parent
                    spacing: marginLarge

                    Rectangle {
                        Layout.preferredWidth: Math.max(80, screenWidth * 0.08)
                        Layout.preferredHeight: Math.max(32, screenHeight * 0.05)
                        radius: height / 2
                        color: currentPage > 0 ? 
                            (anteriorMouseArea.pressed ? "#E5E7EB" : "#F3F4F6") : 
                            "#E5E7EB"
                        border.color: currentPage > 0 ? "#D1D5DB" : "#E5E7EB"
                        border.width: 1
                        
                        MouseArea {
                            id: anteriorMouseArea
                            anchors.fill: parent
                            enabled: currentPage > 0
                            onClicked: {
                                if (currentPage > 0) {
                                    currentPage--
                                    updatePaginatedModel()
                                    selectedRowIndex = -1
                                }
                            }
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            
                            Label {
                                anchors.centerIn: parent
                                text: "← Anterior"
                                color: parent.enabled ? "#374151" : "#9CA3AF"
                                font.bold: true
                                font.pixelSize: fontBase
                            }
                        }
                    }

                    Label {
                        text: "Página " + (currentPage + 1) + " de " + totalPages
                        color: "#374151"
                        font.pixelSize: fontBase
                        font.weight: Font.Medium
                    }

                    Rectangle {
                        Layout.preferredWidth: Math.max(90, screenWidth * 0.09)
                        Layout.preferredHeight: Math.max(32, screenHeight * 0.05)
                        radius: height / 2
                        color: currentPage < totalPages - 1 ? 
                            (siguienteMouseArea.pressed ? Qt.darker(successColor, 1.1) : successColor) : 
                            "#E5E7EB"
                        
                        MouseArea {
                            id: siguienteMouseArea
                            anchors.fill: parent
                            enabled: currentPage < totalPages - 1
                            onClicked: {
                                if (currentPage < totalPages - 1) {
                                    currentPage++
                                    updatePaginatedModel()
                                    selectedRowIndex = -1
                                }
                            }
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            
                            Label {
                                anchors.centerIn: parent
                                text: "Siguiente →"
                                color: parent.enabled ? "#FFFFFF" : "#9CA3AF"
                                font.bold: true
                                font.pixelSize: fontBase
                            }
                        }
                    }
                }
            }
        }
    }

    // DIÁLOGO NUEVO/EDITAR INGRESO - SIMPLIFICADO
    Popup {
        id: nuevoIngresoDialog
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.8, 500)
        height: Math.min(parent.height * 0.7, 450)
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        
        background: Rectangle {
            color: whiteColor
            radius: 12
            border.color: "#DDD"
            border.width: 1
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 15
            
            // Header del diálogo
            Label {
                text: isEditMode ? "EDITAR INGRESO EXTRA" : "NUEVO INGRESO EXTRA"
                font.pixelSize: fontLarge
                font.bold: true
                color: textColor
                Layout.alignment: Qt.AlignHCenter
            }
            
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: borderColor
            }
            
            // Campo Descripción
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5
                
                Label {
                    text: "Descripción *"
                    font.pixelSize: fontBase
                    font.bold: true
                    color: textColor
                }
                
                TextField {
                    id: txtDescripcion
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    font.pixelSize: fontInput
                    placeholderText: "Ingrese una descripción del ingreso"
                    background: Rectangle {
                        color: whiteColor
                        border.color: txtDescripcion.activeFocus ? successColor : borderColor
                        border.width: 1
                        radius: 6
                    }
                }
            }
            
            // Campos Monto y Fecha en fila
            RowLayout {
                Layout.fillWidth: true
                spacing: 15
                
                // Campo Monto
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    
                    Label {
                        text: "Monto (Bs) *"
                        font.pixelSize: fontBase
                        font.bold: true
                        color: textColor
                    }
                    
                    TextField {
                        id: txtMonto
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        font.pixelSize: fontInput
                        placeholderText: "0.00 (use punto o coma para decimales)"
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                        
                        // ✅ MEJORADO: Permitir punto y coma
                        validator: RegularExpressionValidator {
                            regularExpression: /^\d+([.,]\d{0,2})?$/
                        }
                        
                        background: Rectangle {
                            color: whiteColor
                            border.color: txtMonto.activeFocus ? successColor : borderColor
                            border.width: txtMonto.activeFocus ? 2 : 1
                            radius: 6
                        }
                        
                        // ✅ NUEVO: Vista previa del valor mientras escribe
                        onTextChanged: {
                            if (text.length > 0) {
                                var preview = parsearMonto(text)
                                if (!isNaN(preview) && preview > 0) {
                                    montoPreview.visible = true
                                    montoPreview.text = "= Bs " + formatearMonto(preview)
                                } else {
                                    montoPreview.visible = false
                                }
                            } else {
                                montoPreview.visible = false
                            }
                        }
                    }

                    Label {
                        id: montoPreview
                        Layout.fillWidth: true
                        visible: false
                        text: "= Bs 0.00"
                        font.pixelSize: fontSmall
                        font.italic: true
                        color: successColor
                    }
                }
                
                // Campo Fecha
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    
                    Label {
                        text: "Fecha *"
                        font.pixelSize: fontBase
                        font.bold: true
                        color: textColor
                    }
                    
                    TextField {
                        id: txtFecha
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        font.pixelSize: fontInput
                        text: Qt.formatDateTime(new Date(), "yyyy-MM-dd hh:mm:ss")
                        background: Rectangle {
                            color: whiteColor
                            border.color: txtFecha.activeFocus ? successColor : borderColor
                            border.width: 1
                            radius: 6
                        }
                    }
                }
            }
            
            // Nota informativa
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                color: "#F0F9FF"
                border.color: "#BFDBFE"
                border.width: 1
                radius: 6
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8
                    
                    Label {
                        text: "ℹ️"
                        font.pixelSize: 14
                    }
                    
                    Label {
                        Layout.fillWidth: true
                        text: "Los campos marcados con * son obligatorios"
                        font.pixelSize: fontSmall
                        color: "#1E40AF"
                        wrapMode: Text.WordWrap
                    }
                }
            }
            
            Item { Layout.fillHeight: true }
            
            // Footer con botones
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                spacing: 15
                
                // Botón Cancelar
                Button {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 45
                    text: "Cancelar"
                    font.pixelSize: fontButton
                    font.bold: true
                    
                    background: Rectangle {
                        color: parent.down ? "#E5E7EB" : (parent.hovered ? "#F3F4F6" : "#FFFFFF")
                        border.color: "#D1D5DB"
                        border.width: 1
                        radius: 6
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        font: parent.font
                        color: "#374151"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        limpiarFormulario()
                        nuevoIngresoDialog.close()
                    }
                }
                
                // Botón Guardar
                Button {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 45
                    text: isEditMode ? "Actualizar" : "Guardar"
                    font.pixelSize: fontButton
                    font.bold: true
                    enabled: txtDescripcion.text.length > 0 && txtMonto.text.length > 0
                    
                    background: Rectangle {
                        color: {
                            if (!parent.enabled) return "#9CA3AF"
                            if (parent.down) return Qt.darker(successColor, 1.15)
                            if (parent.hovered) return Qt.lighter(successColor, 1.1)
                            return successColor
                        }
                        radius: 6
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        font: parent.font
                        color: whiteColor
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: guardarIngreso()
                }
            }
        }
    }

    // DIÁLOGO CONFIRMAR ELIMINACIÓN - SIMPLIFICADO
    Popup {
        id: confirmDeleteDialog
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.8, 400)
        height: 220
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        visible: showConfirmDeleteDialog
        
        background: Rectangle {
            color: whiteColor
            radius: 12
            border.color: "#DDD"
            border.width: 1
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 15
            
            // Icono de advertencia
            Rectangle {
                Layout.preferredWidth: 60
                Layout.preferredHeight: 60
                color: "#FEF2F2"
                radius: 30
                border.color: "#FECACA"
                border.width: 2
                Layout.alignment: Qt.AlignHCenter
                
                Label {
                    anchors.centerIn: parent
                    text: "⚠️"
                    font.pixelSize: 24
                }
            }
            
            Label {
                text: "Confirmar Eliminación"
                font.pixelSize: fontMedium
                font.bold: true
                color: textColor
                Layout.alignment: Qt.AlignHCenter
            }
            
            Label {
                text: "¿Estás seguro de eliminar este ingreso extra?\nEsta acción no se puede deshacer."
                font.pixelSize: fontBase
                color: textColorLight
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }
            
            Item { Layout.fillHeight: true }
            
            // Botones
            RowLayout {
                Layout.fillWidth: true
                spacing: 15
                
                Button {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 45
                    text: "Cancelar"
                    font.pixelSize: fontButton
                    font.bold: true
                    
                    background: Rectangle {
                        color: parent.down ? "#E5E7EB" : (parent.hovered ? "#F3F4F6" : "#FFFFFF")
                        border.color: "#D1D5DB"
                        border.width: 1
                        radius: 6
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        font: parent.font
                        color: "#374151"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        showConfirmDeleteDialog = false
                        deleteId = -1
                    }
                }
                
                Button {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 45
                    text: "Eliminar"
                    font.pixelSize: fontButton
                    font.bold: true
                    
                    background: Rectangle {
                        color: parent.down ? "#DC2626" : (parent.hovered ? "#EF4444" : "#F87171")
                        radius: 6
                    }
                    
                    contentItem: Label {
                        text: parent.text
                        font: parent.font
                        color: whiteColor
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: confirmarEliminacion()
                }
            }
        }
    }

    // ✅ NUEVA FUNCIÓN: Parseo seguro de montos con decimales
    function parsearMonto(texto) {
        if (!texto || texto.trim() === "") {
            return 0.0
        }
        
        // Remover espacios
        var limpio = texto.trim()
        
        // Reemplazar coma por punto para decimales
        limpio = limpio.replace(',', '.')
        
        // Remover cualquier otro caracter que no sea dígito, punto o signo negativo
        limpio = limpio.replace(/[^\d.-]/g, '')
        
        // Convertir a float
        var numero = parseFloat(limpio)
        
        // Validar que sea un número válido
        if (isNaN(numero)) {
            console.warn("⚠️ Valor no numérico:", texto)
            return 0.0
        }
        
        // Redondear a 2 decimales
        numero = Math.round(numero * 100) / 100
        
        console.log("🔢 Monto parseado:", texto, "→", numero)
        
        return numero
    }

    // ✅ NUEVA FUNCIÓN: Formatear monto para mostrar
    function formatearMonto(numero) {
        if (isNaN(numero) || numero === null || numero === undefined) {
            return "0.00"
        }
        return Number(numero).toFixed(2)
    }

    // ✅ NUEVA FUNCIÓN: Validar formato de monto
    function validarFormatoMonto(texto) {
        if (!texto || texto.trim() === "") {
            return false
        }
        
        // Permitir punto o coma como separador decimal
        var regex = /^\d+([.,]\d{1,2})?$/
        
        var limpio = texto.trim().replace(',', '.')
        
        return regex.test(limpio)
    }
}